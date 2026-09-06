# Database

The data model and database infrastructure for Forger. None of this is implemented yet — it describes the target design agreed on before any schema or migration exists.

---

## Data model

- Tenant — one row per organization; owns a plan that bounds how many Services it may register.
- Service — belongs to exactly one Tenant.
- Incident — the aggregate root. Belongs to exactly one Tenant; associated with one or more Services, each of which must belong to that same Tenant. Carries a status (`investigating`, `identified`, `monitoring`, `resolved`) and a severity (`minor`, `major`, `critical`).
- IncidentUpdate — belongs to exactly one Incident; append-only timeline entries.
- Subscriber (stretch scope) — belongs to exactly one Tenant.

## Schema

Primary keys are UUIDv7 on every table, generated in the application layer before insert rather than by a Postgres default — Postgres core has no native `uuidv7()` function yet. UUIDv7 is time-sortable, which keeps primary-key B-tree index writes append-mostly (unlike random UUIDv4) while still avoiding the guessable-sequence problem of a bare `bigint identity` on entities that cross a public API surface (the status page exposes Incident and Service data to unauthenticated callers).

`incident_status` (`investigating`, `identified`, `monitoring`, `resolved`) and `incident_severity` (`minor`, `major`, `critical`) are Postgres native `ENUM` types. The fixed, small vocabulary favors an enum over a `CHECK`-constrained `text` column, and enum values compare with `<`/`>` in declaration order — the forward-only status transition (see Persistence invariants) is enforced by comparing `NEW.status` against `OLD.status` directly rather than mapping each value to a separate rank column or table.

Every table that depends on a Tenant carries its own `tenant_id` column, regardless of which multi-tenant isolation strategy (RLS or explicit filtering, see Access control) ends up governing reads and writes — both strategies filter on this same column, so the schema below doesn't change depending on which one wins the comparison. Only the RLS branch adds policies on top of it.

### tenants

| Column | Type | Nullable | Default | Constraints |
|---|---|---|---|---|
| `id` | uuid | no | (app-generated UUIDv7) | Primary key |
| `slug` | text | no | | Unique — public identifier used to route the status page |
| `name` | text | no | | |
| `plan` | `tenant_plan` enum (`free`, `pro`, `enterprise`) | no | | |
| `max_services` | integer | no | | `CHECK (max_services > 0)` |
| `created_at` | timestamptz | no | `now()` | |
| `updated_at` | timestamptz | no | `now()` | |

The plan's service cap lives as a column on the tenant itself rather than in a separate `plans` table: there is no billing system or dynamic plan management in scope for this project, so normalizing plan attributes into their own table would add a join with no corresponding need. If a stretch goal later attaches richer plan attributes, this is the point to revisit.

### services

| Column | Type | Nullable | Default | Constraints |
|---|---|---|---|---|
| `id` | uuid | no | (app-generated UUIDv7) | Primary key |
| `tenant_id` | uuid | no | | FK → `tenants(id)` |
| `name` | text | no | | |
| `created_at` | timestamptz | no | `now()` | |
| `updated_at` | timestamptz | no | `now()` | |
| | | | | `UNIQUE (tenant_id, id)` — see incident_services below |
| | | | | `UNIQUE (tenant_id, name)` — a service name is unique within its tenant |

A trigger fires `BEFORE INSERT` on this table, counts the tenant's existing services, and raises an exception if the count would exceed `tenants.max_services`. Enforcing the plan cap at the database level, not only in application code, means a concurrent insert or an application bug can't silently overrun the plan.

### incidents

| Column | Type | Nullable | Default | Constraints |
|---|---|---|---|---|
| `id` | uuid | no | (app-generated UUIDv7) | Primary key |
| `tenant_id` | uuid | no | | FK → `tenants(id)` |
| `title` | text | no | | |
| `status` | `incident_status` enum | no | `investigating` | |
| `severity` | `incident_severity` enum | no | | |
| `created_at` | timestamptz | no | `now()` | |
| `updated_at` | timestamptz | no | `now()` | |
| | | | | `UNIQUE (tenant_id, id)` — see incident_services below |

Two triggers back the status invariants:

- A `BEFORE UPDATE OF status` trigger rejects the update when `NEW.status < OLD.status`, using the enum's declaration order — the forward-only transition invariant, enforced independently of whatever application code calls the update.
- A constraint trigger, `DEFERRABLE INITIALLY DEFERRED`, checks — at commit time, whenever `status` is `resolved` — that at least one `incident_updates` row for that incident carries `status = 'resolved'`. Deferring the check to commit lets the application insert the incident's `resolved` status and its closing IncidentUpdate in either order within the same transaction, rather than forcing one specific statement ordering.

### incident_services

Join table associating an Incident with one or more Services.

| Column | Type | Nullable | Default | Constraints |
|---|---|---|---|---|
| `tenant_id` | uuid | no | | |
| `incident_id` | uuid | no | | |
| `service_id` | uuid | no | | |
| | | | | Primary key `(incident_id, service_id)` |
| | | | | FK `(tenant_id, incident_id)` → `incidents(tenant_id, id)` |
| | | | | FK `(tenant_id, service_id)` → `services(tenant_id, id)` |
| | | | | Index `(service_id, tenant_id)` |

This table is where the cross-entity isolation invariant — every Service an Incident references must belong to that Incident's own Tenant — becomes a database-level guarantee rather than only an application check. Both `incidents` and `services` carry a `UNIQUE (tenant_id, id)` constraint alongside their own primary key, which lets `incident_services` reference each of them through a *composite* foreign key on `(tenant_id, id)` instead of `id` alone. Because a single row in `incident_services` has exactly one `tenant_id` value, and both foreign keys must resolve against that same value, Postgres has no way to satisfy both constraints unless the referenced Incident and Service belong to the same tenant — a row pairing an Incident and a Service from different tenants fails the foreign key check outright.

### incident_updates

Append-only timeline entries for an Incident.

| Column | Type | Nullable | Default | Constraints |
|---|---|---|---|---|
| `id` | uuid | no | (app-generated UUIDv7) | Primary key |
| `tenant_id` | uuid | no | | |
| `incident_id` | uuid | no | | |
| `status` | `incident_status` enum | no | | The status this entry records |
| `message` | text | no | | |
| `created_at` | timestamptz | no | `now()` | |
| | | | | FK `(tenant_id, incident_id)` → `incidents(tenant_id, id)` |
| | | | | Index `(incident_id, created_at)` |

There is no `updated_at` — the row is never expected to change after insert. That expectation is enforced, not just documented: `BEFORE UPDATE` and `BEFORE DELETE` triggers unconditionally raise an exception, and `UPDATE`/`DELETE` privileges on this table are revoked from the application's database role. The trigger and the revoked privilege are deliberately redundant — the trigger catches an attempt from a role that still has the privilege (e.g. a maintenance script running as a more privileged role), the revoked privilege catches an attempt that bypasses ORM-issued statements entirely.

### subscribers (stretch scope)

Placeholder shape only — this entity's full design (per-service subscription granularity, email verification, unsubscribe tokens) is deferred until the Subscriber stretch goal is actually pursued, consistent with `approach.md`.

| Column | Type | Nullable | Default | Constraints |
|---|---|---|---|---|
| `id` | uuid | no | (app-generated UUIDv7) | Primary key |
| `tenant_id` | uuid | no | | FK → `tenants(id)` |
| `email` | text | no | | |
| `created_at` | timestamptz | no | `now()` | |
| | | | | `UNIQUE (tenant_id, email)` |

### Indexing notes

Beyond the indexes that the `UNIQUE` constraints and foreign keys above already create automatically, the following are added for known access patterns:

- `incidents (tenant_id, status)` — the status page's "current non-resolved incidents" query.
- `incidents (tenant_id, created_at desc)` — tenant-scoped incident history, most recent first.
- `incident_updates (incident_id, created_at)` — reading one incident's timeline in order.
- `incident_services (service_id, tenant_id)` — resolving "which incidents affect this service" without a table scan.

When the RLS branch is implemented, its policies are declared on the same `tenant_id` columns documented above — adding an RLS policy doesn't add or change a column in this schema, it only adds a `USING` clause evaluated against columns that already exist for the explicit-filtering branch's own sake.

## Persistence invariants

- An Incident's status only moves forward through `investigating` → `identified` → `monitoring` → `resolved`; it can never move back to an earlier status. If the underlying problem recurs after resolution, that is a new Incident, not a reopened one.
- An Incident cannot be marked `resolved` without at least one associated IncidentUpdate recording that final state.
- Every Service referenced by an Incident must belong to the same Tenant as that Incident. This is a cross-entity isolation invariant that must hold both in the aggregate root's own logic and as a database-level constraint — neither alone is sufficient once multi-tenant isolation and replication are both in play.
- An IncidentUpdate is immutable and append-only: once created, it is never edited or deleted.

## Access control

Two multi-tenant isolation approaches are planned, to be implemented and compared rather than chosen upfront — Row-Level Security scoped by a session-level tenant setting, versus explicit `tenant_id` filtering written into every query. See `structure.md` for the full comparison; the database-specific concern is that whichever approach is used must keep the Service/Incident/Tenant isolation invariant above intact even when reads are served from a replica.

## Infrastructure

Postgres, running as a primary plus one replica connected via streaming replication, provisioned through Docker Compose. Scope is local-only — no remote/staging/production deployment is planned.

## Access patterns

Writes always go through the write repository to the primary; reads always go through the read repository to the replica. These two paths are never mixed within the same adapter: doing so would defeat the point of routing manually between nodes to learn the mechanism, and could silently hide a routing bug behind a client that happens to work against either node.

---

## Non-goals

- No partitioning or materialized views exist yet — both are planned as a later phase (see `approach.md`) once there's enough data volume for the exercise to be meaningful, not part of the current data model.
