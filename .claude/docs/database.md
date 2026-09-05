# Database

The data model and database infrastructure for Forger. None of this is implemented yet — it describes the target design agreed on before any schema or migration exists.

---

## Data model

- Tenant — one row per organization; owns a plan that bounds how many Services it may register.
- Service — belongs to exactly one Tenant.
- Incident — the aggregate root. Belongs to exactly one Tenant; associated with one or more Services, each of which must belong to that same Tenant. Carries a status (`investigating`, `identified`, `monitoring`, `resolved`) and a severity (`minor`, `major`, `critical`).
- IncidentUpdate — belongs to exactly one Incident; append-only timeline entries.
- Subscriber (stretch scope) — belongs to exactly one Tenant.

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
