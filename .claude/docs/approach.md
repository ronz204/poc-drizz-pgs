# Approach

The order and philosophy behind building Forger — why this project exists lives in `overview.md`, not here.

---

## Technical pillars

| Pillar | What it means here |
|---|---|
| Advanced Postgres + multi-tenancy + read-replica HA, practiced together | All three are built against the same incident-management domain deliberately, rather than as isolated exercises — isolation decisions and replication trade-offs only feel real when they're applied to the same aggregate under the same load, instead of three disconnected toy examples. |
| Hexagonal design with two coexisting persistence adapters | The domain stays a single model; only the persistence layer forks into a write path (primary) and a read path (replica), which is itself part of what's being practiced. |

## Functional scope

- Create and manage Tenants, Services, and Incidents, including the Incident's forward-only status transition.
- Record an append-only IncidentUpdate timeline per Incident.
- An authenticated, per-tenant internal panel for managing the above.
- An unauthenticated, tenant-scoped public status page for viewing current status and incident history.

## Roadmap

All phases below are pending — none has started yet.

0. **Stack and infrastructure validation** — stand up Postgres primary + replica in Docker Compose with streaming replication, confirm Bun can connect to both nodes, and validate the ORM's Bun compatibility. Done when: both nodes are up under Compose, Bun connects to each, an insert on the primary is observed on the replica, and the replication lag has been measured at least once.
1. **Domain and basic writes** — model Tenant, Service, Incident, and IncidentUpdate through a hexagonal design; expose one write endpoint (create an incident) against the primary. No multi-tenancy yet — a single hardcoded tenant. Done when: that endpoint works end to end against the primary with the domain invariants enforced.
2. **Real multi-tenancy** — implement and compare Row-Level Security and explicit `tenant_id` filtering; add basic authentication that resolves the current tenant from the session/token; verify the Service/Incident/Tenant isolation invariant holds both in the domain and as a database constraint. Done when: both isolation approaches are implemented (at least one on a separate branch) and compared.
3. **Read-replica routing** — implement the read repository against the replica and expose the public status page through it. Done when: writing an incident and immediately reading it from the status page makes the replication lag directly observable.
4. **Resolving the lag** — choose and document one of the candidate strategies from `expertise.md`. Done when: a strategy is implemented and its trade-offs are documented against the alternatives.
5. **Partitioning and analytics** — partition IncidentUpdate by date range if simulated volume justifies it; add uptime-percentage metrics via materialized views; compare query plans before/after partitioning and indexing. Done when: a partitioned table and at least one materialized-view-backed metric exist, with `EXPLAIN ANALYZE` comparisons recorded.
6. **Manual failover (stretch)** — deliberately kill the primary, promote the replica, observe what breaks given the hardcoded primary connection, and document what a real automatic failover would require. Done when: the failure mode is observed and documented; automatic failover itself stays out of scope.

## Stretch goals

- Subscriber entity plus notification delivery.
- PgBouncer in front of both nodes, evaluating its interaction with RLS and connection pooling.
- Fair-usage metrics: how much load each tenant generates against the primary versus the replicas.

---

## Non-goals

- This roadmap sequences the learning goals, not a production launch — there is no phase for deployment, monitoring, or operational hardening beyond what a phase's own validation requires.
