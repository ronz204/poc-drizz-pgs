# Structure

Stack choices, how the planned components communicate, and cross-cutting patterns. The data model itself lives in `database.md`, not here; per-component behavior lives in `modules.md`.

---

## Stack

| Layer | Choice | Rationale |
|---|---|---|
| Runtime/language | Bun + TypeScript | Chosen as the practice runtime for this project; its compatibility with the ORM below is an explicit early risk to validate rather than an assumed given. |
| API framework | Elysia | The HTTP layer for both the internal panel and the public status page. |
| Database | Postgres, primary + replica via streaming replication | The core subject of practice — multi-tenant isolation and replica read routing only mean anything with a real primary/replica pair. |
| ORM | Drizzle | Selected pending a Bun-compatibility check, the same kind of early validation this project's predecessors have applied to other library choices before committing. |
| Infrastructure | Docker Compose | Runs the primary, the replica, and the app locally. Scope is deliberately local-only — no staging/production environment is planned for this project. |

## Topology

The system has two API surfaces, each pinned to one Postgres node:

- The internal panel (authenticated, per-tenant) always writes through the write repository to the primary.
- The public status page (unauthenticated, tenant-scoped, expected to be the higher-read-volume surface) always reads through the read repository from the replica.

Routing between primary and replica is manual — two separate Postgres/Drizzle client instances, one per node, with no third-party read-routing library in between. This is deliberate: the goal is to understand the primary/replica mechanism end to end rather than delegate it to a library.

## Cross-cutting patterns

Two multi-tenant isolation approaches are planned to be implemented and compared against each other, rather than picking one upfront:

- **Row-Level Security (RLS)**: Postgres policies that filter rows automatically based on a session-scoped `app.current_tenant` setting. Isolation is guaranteed by the database engine itself, not by application code discipline.
- **Explicit tenant filtering**: every query includes a `tenant_id` predicate written by hand in the repository layer.

Both are meant to be built (the second possibly on a separate branch) so their trade-offs — real security guarantee, performance, maintenance burden, and behavior under replication — can be compared directly rather than assumed.

## Open architecture decisions

Which strategy resolves read-replica lag is not yet decided — it depends on first observing the lag in practice once read-replica routing exists. The candidates under consideration:

- Read-your-writes: force reads to the primary for a short window after a tenant's own recent write (sticky by session/tenant).
- Accepted eventual consistency, surfaced to the user via a staleness indicator (e.g. "updated N seconds ago").
- Timestamp-based versioning to detect and explicitly communicate staleness.

This will be decided and documented once the read-replica routing exists and the lag can be measured directly.

---

## Non-goals

- No connection-pooling library (e.g. PgBouncer) is part of the current design — it's noted only as a stretch-scope idea in `approach.md`, not a committed part of the topology above.
