# persistence-layer — Spec

> The relational foundation of Forger's data model: the Postgres schema, native enums, tenant-isolation policy, and DB-level triggers that back the Tenant/Service/Incident/IncidentUpdate domain.

## Intent

Forger's incident-management domain needs a persistence layer where tenant isolation and the Incident lifecycle are guarantees the database itself holds, not rules application code is merely trusted to respect. This slice is that foundation: the tables, constraints, and triggers that make a cross-tenant Incident/Service pairing, a backward status transition, or an edited append-only record fail at the database layer regardless of which application code issues the query.

## Scope

In scope:
- The `core` Postgres schema: tables for Tenant, Service, Incident, the Incident/Service join table, IncidentUpdate, and a placeholder-shape Subscriber table.
- The native Postgres enums backing tenant plan, incident status, and incident severity.
- The Row-Level-Security policy providing tenant isolation on every tenant-scoped table.
- The DB-level triggers enforcing invariants a foreign key or `CHECK` constraint alone can't express.
- The migrations that create all of the above.

Out of scope:
- Explicit `tenant_id`-filtering as an alternative multi-tenant isolation strategy. This slice implements Row-Level Security only; explicit filtering is a separate future slice (likely on its own branch) so the two can be compared directly.
- The write/read repository adapters that will actually query this schema from application code. This slice is the schema and its DB-level contract only — the calling discipline those adapters must follow (in particular, setting the tenant context in the same transaction as any RLS-scoped query) is assumed by this slice's design but is not something this slice implements or enforces itself.
- Subscriber's full design — verification flow, unsubscribe tokens, per-service subscription granularity. Only its placeholder shape (id, tenant, email, uniqueness per tenant) is in scope; the rest is deferred until that stretch goal is actually pursued.
- Verifying this schema against a live, running Postgres instance. The infrastructure to do that isn't in place yet (see Deferred / Open questions).

## Contract

### Tables

| Table | Tenant-scoped | Key shape |
|---|---|---|
| Tenant | No (it's the root) | Unique public slug; a plan; a positive integer service cap. |
| Service | Yes | Unique per tenant by name; a composite uniqueness on (tenant, id) so it can be the target of a composite foreign key. |
| Incident | Yes | A title, a status, a severity; a composite uniqueness on (tenant, id) for the same reason as Service. |
| Incident↔Service join | Yes | Composite primary key on (incident, service); composite foreign keys into both Incident and Service scoped through the tenant column, not just the entity's own id. |
| IncidentUpdate | Yes | Append-only timeline entry: a status snapshot, a message, a creation timestamp — no update timestamp, since the row is never expected to change. |
| Subscriber (placeholder) | Yes | An email, unique per tenant. |

### Enums

| Enum | Values (declaration order) | Order is semantic? |
|---|---|---|
| Tenant plan | free, pro, enterprise | No — see Invariants. |
| Incident status | investigating, identified, monitoring, resolved | Yes — declaration order is the forward-only ordering. |
| Incident severity | minor, major, critical | No. |

### Isolation

Every tenant-scoped table has row-level security enabled, with exactly one restrictive policy applied for the application's query-issuing database role. The policy's predicate compares the row's tenant column against a session-level tenant setting, and applies to every operation (select/insert/update/delete) identically.

### Triggers

| Trigger | Fires on | Purpose |
|---|---|---|
| Service cap enforcement | BEFORE INSERT on Service | Rejects an insert that would exceed the owning tenant's service cap; locks the tenant row first so two concurrent inserts for the same tenant can't both read the same under-cap count. |
| Incident status forward-only | BEFORE UPDATE of status on Incident | Rejects a status update that would move backward through the status enum's declaration order. |
| Incident resolved requires update | Deferred constraint trigger, AFTER INSERT OR UPDATE of status on Incident | At commit time, if status is resolved, requires at least one IncidentUpdate row for that incident carrying the resolved status. Deferred so the incident and its closing update can be written in either order within one transaction. |
| IncidentUpdate immutable (update) | BEFORE UPDATE on IncidentUpdate | Unconditionally rejects any update. |
| IncidentUpdate immutable (delete) | BEFORE DELETE on IncidentUpdate | Unconditionally rejects any delete. |

The two IncidentUpdate immutability triggers are each paired with an explicit revocation of the corresponding privilege (UPDATE, DELETE) from the application's query-issuing role, deliberately redundant with the trigger itself.

### Indexes beyond what constraints create automatically

Four indexes back specific known access patterns rather than any constraint: Incident by tenant and status (the "current non-resolved incidents" query), Incident by tenant and creation time descending (tenant-scoped history, most recent first), IncidentUpdate by incident and creation time (reading one incident's timeline in order), and the Incident↔Service join by service and tenant (resolving which incidents affect a given service without a table scan).

## Invariants

- Every table that depends on a Tenant carries its own tenant column; Tenant itself does not, and has no row-level-security policy — it's the isolation boundary's root, not a subject of it.
- An Incident's status only ever moves forward through its lifecycle (investigating → identified → monitoring → resolved), compared by the Incident status enum's declaration order — it can never move to an earlier status.
- An Incident cannot be marked resolved without at least one IncidentUpdate row recording that final state, checked at commit time so either write order within the transaction is accepted.
- Every Service an Incident references must belong to that Incident's own Tenant — enforced structurally: the join table's foreign keys are composite on (tenant, entity id), not on the entity's id alone, so a row pairing entities from different tenants cannot satisfy both foreign keys at once regardless of any application-level check.
- An IncidentUpdate row is immutable and append-only: once created, it is never edited or deleted, enforced both by trigger and by revoked write privileges on that table for the application's query-issuing role — two independent enforcement paths so a bypass of one (a differently-privileged role, a non-ORM write) is still caught by the other.
- Row-level security's tenant-scoping predicate is only correct if the caller sets the session-level tenant value inside the same transaction as the query it's meant to scope — a value set in an earlier call on a pooled connection cannot be assumed still active. This slice defines the policy; the calling discipline that keeps it correct is enforced by the code that will eventually query this schema, not by this slice itself.
- A tenant's service cap is enforced at insert time by counting that tenant's existing services under a row lock, not by a bare count-then-insert — so a concurrent insert for the same tenant cannot slip past the cap.
- Primary keys across every table are generated by the application before insert, never by a database default — this schema has no native database-generated identifier of its own.
- Tenant plan's enum declaration order carries no meaning — unlike incident status, plan values are never compared with `<`/`>`, and a future change to add or reorder plan tiers is safe to make without touching any invariant.

## Deferred / Open questions

- Explicit `tenant_id`-filtering as the alternative isolation strategy is intentionally not designed yet. It gets its own spec once that branch of work actually starts, so it can be compared against the Row-Level-Security approach on its own terms rather than being bolted onto this slice.
- This schema and its triggers have not been verified against a running Postgres instance — that's blocked on infrastructure that doesn't exist yet (see this slice's plan). Until then, correctness rests on static verification only (type-checking and generated-DDL inspection).
- Subscriber's full design (verification, unsubscribe tokens, per-service granularity) stays undecided until that stretch goal is actually taken up.

## Acceptance criteria

Currently satisfied:
- The schema type-checks cleanly end to end.
- Generating migrations from the schema definition produces the expected DDL — every table, enum, constraint, index, and policy described above, generated exactly once each (no duplicate constraint or policy names).

Not yet satisfied, blocked on infrastructure:
- Migrations apply cleanly against a running Postgres primary with no errors.
- Each trigger, exercised directly, actually rejects the case it exists to reject: an insert past a tenant's service cap, a backward Incident status update, marking an Incident resolved with no matching IncidentUpdate, and an update or delete against an IncidentUpdate row.

---

Last updated: 2026-09-20.
