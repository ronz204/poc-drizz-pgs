# Forger — Structure

Architecture, stack, and planned infrastructure topology for Forger. Vision and domain live in `overview.md`; the build roadmap lives in `approach.md`; underlying mechanisms live in `expertise.md`. Nothing described below is implemented yet — this records design intent for the active POC, not as-built fact.

---

## Architectural pattern

Hexagonal architecture with a single domain, but with two separate outbound persistence adapters instead of one:

| Adapter | Port | Target node | Used by |
|---|---|---|---|
| Write repository | Write port | Primary | Any operation that mutates state (creating/updating an Incident, its Services, its updates) |
| Read repository | Read port | Replica | Read-heavy queries oriented around the public status page |

This is CQRS-lite, not full CQRS: there is one domain model and one persistence schema, not separate read/write projections — a full projection layer would be over-engineering for this POC's scope. What's real is the physical routing decision: which Postgres node a given operation talks to, decided by which port it goes through.

## API surfaces

| Surface | Auth | Access pattern | Routed to |
|---|---|---|---|
| Internal panel | Authenticated, scoped per tenant | Creating/updating Incidents, managing Services — write-heavy | Primary, always |
| Public status page | None | Viewing current status and Incident timeline — high read volume | Replica |

## Stack

| Concern | Choice | Rationale |
|---|---|---|
| Runtime/language | Bun + TypeScript | Fast local iteration for a learning-focused POC. |
| API framework | Elysia | Lightweight HTTP layer for the two API surfaces above. |
| Database | Postgres, primary + streaming-replication replica | The subject of the exercise — primary/replica topology is required to practice replication lag and read routing at all. |
| ORM | Prisma | Data access for both the write and read adapters. |
| Local infrastructure | Docker Compose | Runs primary, replica, and the app locally without external dependencies. |

## Planned infrastructure topology

Not yet provisioned — `compose.yml` and `docker/` are currently empty placeholders. The intended local topology:

```
                 ┌─────────────┐
   writes  ────► │   primary   │
                 └──────┬──────┘
                        │ streaming replication
                        ▼
                 ┌─────────────┐
   reads   ────► │   replica   │
                 └─────────────┘
```

Both nodes run as Docker Compose services alongside the application container. Standing this up, confirming connectivity from the app to both nodes, and measuring replication lag with a manual write/read test is the first roadmap phase.

## Open architecture decision — replication lag

Once read-replica routing exists, reads can observe stale data relative to a just-completed write. Which mitigation strategy to adopt — read-your-writes sticky routing, accepted eventual consistency with a staleness indicator, or timestamp-based staleness detection — is not chosen yet; see `expertise.md` for how each candidate actually works. The choice, and its trade-offs, get documented here once made.
