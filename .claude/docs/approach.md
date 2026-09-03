# Forger — Build Approach

The build plan for Forger: what gets built, in what order, and what "done" means. Domain vision lives in `overview.md`; architecture and stack live in `structure.md`; underlying mechanisms live in `expertise.md`.

---

## Technical pillars

The project exists to build these together, because the domain genuinely needs all of them at once rather than any one being bolted on artificially:

| Pillar | What it means here |
|---|---|
| Database-level multi-tenant isolation | Comparing row-level security against explicit application-level `tenant_id` filtering, both enforcing that a Service referenced by an Incident always belongs to that Incident's own Tenant. |
| Primary/replica read-write routing | Writes always go through the write port to the primary; reads for the public status page go through a separate read port to the replica — a real physical routing decision, not a simulated one. |
| Replication lag handling | The replica is asynchronous, so a just-completed write is not guaranteed visible on the next read — this has to be observed, then deliberately mitigated, not ignored. |
| Partitioning & materialized views | Extending the base system once it's queryable at meaningful volume, to practice partitioning an append-only table and precomputing aggregates. |

## Functional scope

The base system must support:

- Creating and managing Tenants and Services (a Tenant registers Services up to its plan's limit).
- Creating an Incident against one or more Services, always belonging to a single Tenant, through the authenticated internal panel — always against primary.
- Appending IncidentUpdate entries to an Incident's timeline, progressing its status forward only, ending in `resolved` with a final update.
- Viewing current status and Incident timeline through the public, unauthenticated status page, scoped per tenant — served from the replica.
- Resolving the current tenant from the session/token for the internal panel, once authentication exists.

## Roadmap

Work proceeds in phases, each intended to build the system up from a bare stack validation to the full isolation + replica-routing + lag-handling model:

0. **Stack and infrastructure validation** — stand up Postgres primary + replica in Docker Compose with streaming replication; confirm connectivity from Bun to both nodes; manually insert on primary, confirm it appears on the replica, measure the approximate lag.
1. **Domain & basic writes** — model Tenant, Service, Incident, IncidentUpdate with Hexagonal architecture; one write endpoint (create Incident), all against primary; a single hardcoded tenant, no multi-tenancy yet.
2. **Real multi-tenancy** — implement isolation (RLS and/or explicit `tenant_id` filtering — compare both); basic authentication resolving the current tenant from the session/token; verify the Service↔Incident↔Tenant isolation invariant both in the domain and as a database constraint.
3. **Read replica routing** — implement the read repository against the replica; expose the public status page through it; observe replication lag firsthand by writing an Incident and reading it immediately from the status page.
4. **Resolving the lag** — choose and justify one of the mitigation strategies from `expertise.md`, documenting the trade-off in `structure.md`.
5. **Partitioning & analytics** — partition IncidentUpdate by date range if simulated volume justifies it; add metrics (e.g. uptime % per service, per month) via materialized views; practice `EXPLAIN ANALYZE` comparing before/after partitioning and indexing.

## Done criteria

The base system (through phase 5) is done when all of the following hold:

- An Incident can be created against primary, progressed through IncidentUpdates, and reaches `resolved` only with a final update recording it — never regressing to an earlier status.
- At least one multi-tenant isolation approach is implemented and observably prevents a Service from a different Tenant being attached to an Incident, enforced both in the domain and as a database constraint.
- The public status page reads from the replica, and replication lag between a write and its visibility on that page has been measured, not just assumed.
- A chosen lag-mitigation strategy is implemented and its trade-off documented.
- At least one partitioning or materialized-view technique has been applied and compared against its unpartitioned/unmaterialized baseline with `EXPLAIN ANALYZE`.

## Stretch goals

Explicitly non-blocking for the base system:

- **Manual failover** — intentionally kill the primary, promote the replica, observe what breaks in the app (a hardcoded primary connection is a single point of failure) and document what a real automatic failover would require, without implementing it.
- Subscriber + notifications (opens the door to queues, outside this project's focus).
- PgBouncer in front of both nodes; evaluate its impact on connection pooling with RLS active.
- Fair-usage metrics: how much load each tenant generates against primary vs. replicas.
