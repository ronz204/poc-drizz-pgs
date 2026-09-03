# Forger — Database

Schema, roles, and access-control design for Forger's Postgres database: tables, enums, constraints, row-level security policies, and the role/permission split used to run migrations separately from runtime queries. Nothing here is provisioned yet — this is planned design, not as-built fact.

---

## Schema

Every application object lives in a dedicated `core` schema, never in `public`. Relying on the default `public` schema mixes application objects with whatever a client/extension might also dump there and makes per-object grants harder to reason about as a single, deliberate surface — a dedicated schema keeps that surface explicit and lets ownership/grants be set up once, in one place, rather than per object.

## Roles

Three roles exist on the cluster, each with a deliberately narrow purpose — the migration path and the runtime query path never share credentials, so a compromised application connection can never alter schema or grant itself new access.

| Role | Purpose | Used by |
|---|---|---|
| `root` | Cluster bootstrap only: creates the two roles below and the `core` schema (owned by `sampler`). Never used again afterward. | The bootstrap process, once, during initial provisioning. |
| `sampler` | DDL — owns `core` and everything created inside it, runs every migration (`CREATE`/`ALTER`/`DROP TABLE`, `CREATE TYPE`, `CREATE POLICY`). | The migration tool only. Never the running application. |
| `runner` | DML — all runtime reads and writes the application performs, against both the primary (writes) and the replica (reads). | The application, through both the write and read persistence adapters. |

```sql
-- idempotent — safe to run against every database that needs `core`
SELECT format('CREATE ROLE sampler WITH LOGIN PASSWORD %L NOBYPASSRLS', :'sampler_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sampler') \gexec

SELECT format('CREATE ROLE runner WITH LOGIN PASSWORD %L NOBYPASSRLS', :'runner_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'runner') \gexec

CREATE SCHEMA IF NOT EXISTS core AUTHORIZATION sampler;

GRANT USAGE ON SCHEMA core TO runner;

-- Applies to every table sampler creates in `core` from this point on, so a
-- migration never needs its own per-table GRANT. DELETE is deliberately
-- never included — see Soft delete below — and the two append-only tables
-- additionally REVOKE UPDATE right after creation, as part of their own
-- migration, since a default can only set the common case.
ALTER DEFAULT PRIVILEGES FOR ROLE sampler IN SCHEMA core
  GRANT SELECT, INSERT, UPDATE ON TABLES TO runner;
```

`NOBYPASSRLS` on both roles is a deliberate choice, not a default left alone: the powerful, cluster-wide `BYPASSRLS` attribute is never granted to either role. `sampler` still bypasses RLS specifically on the tables it owns — that's a separate mechanism, table-owner bypass, covered under Row-level security below — which is enough for migrations without handing out a blanket bypass.

**Replication note:** roles are cluster-level, not database-level. Physical streaming replication copies the primary's roles to the replica as part of the byte-for-byte copy, so `runner` does not need to be created separately on the replica — the same role and password authenticate on both nodes; only the host/port the application connects to differs between the write and read adapters.

## Enums

```sql
CREATE TYPE core.incident_status   AS ENUM ('investigating', 'identified', 'monitoring', 'resolved');
CREATE TYPE core.incident_severity AS ENUM ('minor', 'major', 'critical');
CREATE TYPE core.service_status    AS ENUM ('operational', 'degraded', 'partial_outage', 'major_outage');
CREATE TYPE core.tenant_plan_tier  AS ENUM ('free', 'pro', 'enterprise');
```

`tenant_plan_tier` only records which tier a Tenant is on — the Service-count limit each tier implies is application logic, not a database value, so adding or adjusting a tier's limit never requires a migration.

## Primary keys: UUIDv7, generated in application code

Every table's primary key is a native `uuid` column with **no database-side default** (no `gen_random_uuid()`, no extension). The application generates the value as a UUIDv7 before insert. Two consequences that shape the schema below:

- Every `INSERT` must supply `id` explicitly — a migration or seed script that omits it fails, by design, rather than silently falling back to a DB-generated value.
- Because UUIDv7 is time-ordered, primary-key index inserts stay roughly sequential instead of scattering randomly across the btree the way a fully random key would.

## Soft delete

`tenants` and `services` carry a nullable `deleted_at timestamptz` so they can be deactivated without a physical `DELETE` — `runner` is never granted `DELETE` on any table, anywhere. `incidents` and `incident_updates` do **not** get this column: an Incident's lifecycle is already represented by its `status` reaching `resolved`, and its updates are an append-only audit trail — neither is ever deactivated, only advanced forward. Filtering out soft-deleted rows (`WHERE deleted_at IS NULL`) is an application/query-level concern, not something folded into the RLS policies below, to keep those policies scoped to exactly one thing: tenant isolation.

## Tables

```sql
CREATE TABLE core.tenants (
  id          uuid PRIMARY KEY,
  name        text NOT NULL,
  plan_tier   core.tenant_plan_tier NOT NULL DEFAULT 'free',
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz
);
```

```sql
CREATE TABLE core.services (
  id          uuid PRIMARY KEY,
  tenant_id   uuid NOT NULL REFERENCES core.tenants (id),
  name        text NOT NULL,
  status      core.service_status NOT NULL DEFAULT 'operational',
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz,
  UNIQUE (id, tenant_id)
);
CREATE INDEX ON core.services (tenant_id);
```

```sql
CREATE TABLE core.incidents (
  id            uuid PRIMARY KEY,
  tenant_id     uuid NOT NULL REFERENCES core.tenants (id),
  title         text NOT NULL,
  status        core.incident_status NOT NULL DEFAULT 'investigating',
  severity      core.incident_severity NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  resolved_at   timestamptz, -- set once, when status reaches 'resolved'
  UNIQUE (id, tenant_id)
);
CREATE INDEX ON core.incidents (tenant_id);
CREATE INDEX ON core.incidents (tenant_id, status);
```

```sql
-- Join table: which Service(s) an Incident affects. Both sides must belong
-- to the same tenant as the incident — enforced below, not just assumed.
CREATE TABLE core.incident_services (
  tenant_id   uuid NOT NULL,
  incident_id uuid NOT NULL,
  service_id  uuid NOT NULL,
  PRIMARY KEY (incident_id, service_id),
  FOREIGN KEY (incident_id, tenant_id) REFERENCES core.incidents (id, tenant_id),
  FOREIGN KEY (service_id, tenant_id)  REFERENCES core.services (id, tenant_id)
);
CREATE INDEX ON core.incident_services (service_id, tenant_id);

-- Append-only association: REVOKE the UPDATE this table otherwise inherits
-- from the schema-wide default (see Roles above).
REVOKE UPDATE ON core.incident_services FROM runner;
```

```sql
-- Append-only timeline. No updated_at, no deleted_at: an entry is written
-- once and never touched again.
CREATE TABLE core.incident_updates (
  id               uuid PRIMARY KEY,
  tenant_id        uuid NOT NULL,
  incident_id      uuid NOT NULL,
  body             text NOT NULL,
  status_at_update core.incident_status NOT NULL, -- the incident's status as of this entry
  created_at       timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (incident_id, tenant_id) REFERENCES core.incidents (id, tenant_id)
);
CREATE INDEX ON core.incident_updates (incident_id, created_at);

REVOKE UPDATE ON core.incident_updates FROM runner;
```

`Subscriber` is explicitly deferred and has no table yet.

### The tenant-consistency pattern

`services.tenant_id` and `incidents.tenant_id` alone don't stop an `incident_services` row from pairing an Incident with a Service from a *different* tenant — a plain pair of single-column foreign keys can't see each other. Carrying `tenant_id` redundantly on the join table and using **composite foreign keys** (`(incident_id, tenant_id)` and `(service_id, tenant_id)`, each referencing the parent's own `(id, tenant_id)` unique pair) closes that gap: the same `tenant_id` value must simultaneously satisfy both foreign keys, so a cross-tenant pairing is rejected by the database itself, not just by application code. This is the database-level half of the Service-Incident-Tenant isolation invariant — the domain aggregate is the other half.

## Row-level security

RLS is enabled on every table that carries a `tenant_id` — `services`, `incidents`, `incident_services`, `incident_updates`. `tenants` itself is not RLS-scoped: a row there *is* a tenant, not data belonging to one, so isolation for it is the application's job (resolving which tenant a request is for before it ever touches per-tenant data), not a row filter.

```sql
ALTER TABLE core.services ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON core.services
  USING      (tenant_id = current_setting('app.current_tenant')::uuid)
  WITH CHECK (tenant_id = current_setting('app.current_tenant')::uuid);

ALTER TABLE core.incidents ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON core.incidents
  USING      (tenant_id = current_setting('app.current_tenant')::uuid)
  WITH CHECK (tenant_id = current_setting('app.current_tenant')::uuid);

ALTER TABLE core.incident_services ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON core.incident_services
  USING      (tenant_id = current_setting('app.current_tenant')::uuid)
  WITH CHECK (tenant_id = current_setting('app.current_tenant')::uuid);

ALTER TABLE core.incident_updates ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON core.incident_updates
  USING      (tenant_id = current_setting('app.current_tenant')::uuid)
  WITH CHECK (tenant_id = current_setting('app.current_tenant')::uuid);
```

**Deliberately not `FORCE ROW LEVEL SECURITY`.** A table's owner (`sampler`) bypasses its own RLS policies by default — only a non-owner, non-superuser role is subject to them without `FORCE`. `runner` is neither the owner nor a superuser, so it is already fully bound by these policies with plain `ENABLE`. Leaving out `FORCE` is what lets `sampler` seed or inspect data across every tenant during migrations without having to set `app.current_tenant` first — forcing it would make routine migration work adversarial against the exact policies migrations are supposed to install.

`app.current_tenant` is a session-scoped setting the application must set once per request/connection (`SET app.current_tenant = '<tenant-id>'`) before running any `runner`-authenticated query. Under connection pooling, this must be reset on every connection checkout — a stale value from a previous request is a silent cross-tenant leak.

---

## Non-goals

This document doesn't cover partitioning or materialized views — those belong to a later stage of the project and get documented here once the base schema above is actually in place and their design is decided against real data volume, not guessed at now.
