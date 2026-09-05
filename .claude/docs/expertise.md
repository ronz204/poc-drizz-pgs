# Expertise

How the non-trivial mechanisms Forger depends on actually work — not whether or where they're used, which is `structure.md`'s and `database.md`'s job.

---

## Glossary

| Term | Meaning |
|---|---|
| RLS | Row-Level Security — a Postgres feature that transparently filters or rejects rows per query based on a policy tied to session state. |
| Streaming replication | Postgres's mechanism for continuously shipping write-ahead log records from a primary to one or more replicas, keeping them near-real-time copies. |
| CQRS-lite | This project's term for its own write/read split: separate persistence adapters targeting different physical Postgres nodes, without separate read/write data models or projections. |

## Postgres streaming replication

A replica continuously applies the primary's write-ahead log to stay in sync. Replication is asynchronous by default: a write is considered committed on the primary before the replica has necessarily applied it, which means there is always some non-zero replication lag between "written" and "visible on the replica." That lag is not a bug to eliminate — it's a real property of the system that has to be measured and either compensated for or explicitly surfaced (see `structure.md`'s open architecture decisions for the candidate strategies).

## Row-Level Security and connection pooling

RLS policies key off session-local state — typically set via `SET app.current_tenant = '<value>'` — evaluated per query against the current session. The critical constraint: that `SET` must be executed on the exact same database session/connection as the query it's meant to scope. If a connection pool hands the query to a different physical connection than the one the `SET` ran on, the tenant context is silently wrong or absent, and RLS either leaks another tenant's rows or blocks all of them — a failure mode that fails quietly rather than loudly. This is why any RLS-scoped query must run inside the same transaction as its `SET` statement, never relying on the connection pool to preserve session state across separate calls.

An open question not yet confirmed: how (or whether) RLS policy configuration itself propagates from primary to replica under streaming replication, versus needing to be set up independently on each node. This has to be validated once replica routing exists, since it directly affects whether the isolation guarantee holds on the read path.

## Replica-lag mitigation strategies

Three approaches are candidates for resolving the read-your-writes problem once it's observed in practice:

- **Read-your-writes / sticky primary**: route a tenant's reads to the primary for a short window after their own recent write, then fall back to the replica. Strong consistency for the writer, at the cost of extra load on the primary and added routing complexity.
- **Accepted eventual consistency with a staleness indicator**: always read from the replica, and surface how stale the data might be (e.g. "updated N seconds ago") rather than hiding the lag. Simple, but pushes the consistency problem into the UI.
- **Timestamp-based versioning**: attach a write timestamp to records and compare it against a known replication watermark to detect staleness explicitly, rather than assuming a fixed window. More precise than a sticky-primary window, at the cost of extra bookkeeping.

No trade-off has been chosen yet — this is deliberately deferred until the lag can be observed directly.

---

## Non-goals

- This file explains mechanisms Forger's own design depends on; it does not attempt a general Postgres or Elysia/Drizzle tutorial beyond what those mechanisms require.
