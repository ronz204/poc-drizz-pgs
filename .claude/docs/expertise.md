# Forger — Expertise

Reference explanations for the underlying Postgres and replication mechanisms Forger's architecture depends on. This file explains *how a mechanism works*, not *whether/when or where it's actually used*.

---

## Row-level security (RLS)

Postgres can attach a policy to a table that transparently adds a filtering predicate to every query against it, evaluated per row. A policy typically compares a column (e.g. `tenant_id`) against a session-scoped value read via `current_setting('app.current_tenant')`, which the application sets once per connection/request (`SET app.current_tenant = '<id>'`). Once enabled, a query that omits any tenant filter still only sees rows belonging to the current session's tenant — isolation is enforced at the database layer, not by trusting every query author to remember a `WHERE` clause.

The caveat that matters under connection pooling: the session-scoped setting is tied to the physical connection, not to a logical request. A pooled connection reused across requests without resetting that setting risks leaking the previous request's tenant context — RLS's guarantee depends on that reset happening reliably on every checkout.

## Explicit tenant filtering

The alternative to RLS: every repository query includes an explicit `tenant_id` predicate written by the application, with no database-level backstop. Isolation is only as strong as every query actually including that predicate — a missed one is a silent cross-tenant leak that no constraint catches. Its appeal is simplicity and a query plan the developer can reason about directly, without a policy rewriting the query underneath them.

## Streaming replication and lag

A Postgres primary ships its write-ahead log (WAL) to one or more replicas, which continuously replay it to stay in sync. This is asynchronous by default: a transaction commits durably on the primary before the replica has necessarily replayed it, so a replica can lag behind by some measurable interval. That lag is observable — the primary exposes replication state per connected replica, and the replica exposes how far behind it currently is — and it is never guaranteed to be zero, only bounded under normal operation.

## Replication-lag mitigation strategies

Three general strategies for coping with the read/write inconsistency streaming replication introduces:

| Strategy | How it works |
|---|---|
| Read-your-writes (sticky routing) | After a session/tenant performs a write, route that same session/tenant's reads to the primary for a short window before falling back to the replica — trades some replica offload for a consistency guarantee scoped to the writer. |
| Accepted eventual consistency | Always read from the replica, but attach a visible staleness signal (e.g. "updated N seconds ago") so the inconsistency is communicated rather than hidden. |
| Timestamp-based staleness detection | Version each row with a last-write timestamp; a reader can compare it against an expected freshness bound and detect staleness explicitly, rather than assuming the read is current. |

None of these eliminate lag — they differ in whether they hide it, avoid it for the writer, or surface it for the reader to react to.

## Partitioning

Range partitioning splits one logical table into multiple physical child tables based on a column range (e.g. a date range on `IncidentUpdate`'s creation time). Queries scoped to a narrow range only scan the matching partition(s) instead of the whole table, and old partitions can be dropped or archived independently. It pays off once a table is large enough that full-table scans or index bloat become the bottleneck — not before.

## Materialized views

A materialized view stores the result of a query physically, rather than recomputing it on every read. It has to be refreshed explicitly (`REFRESH MATERIALIZED VIEW`, optionally `CONCURRENTLY` to avoid blocking reads during the refresh) — it does not stay live as the underlying data changes. Useful for expensive aggregates (e.g. uptime percentage per service per month) that don't need to reflect every write immediately.

## Reading `EXPLAIN ANALYZE`

`EXPLAIN ANALYZE` runs a query and reports the actual plan Postgres chose — which indexes (if any) it used, the join strategy, estimated vs. actual row counts, and time spent per node of the plan. Comparing its output before and after adding an index or partitioning a table is how a performance claim gets verified instead of assumed.

## UUIDv7 vs. a database-generated key

A UUIDv7 encodes a millisecond timestamp in its high-order bits, followed by random bits for the remainder — unlike UUIDv4, which is fully random. Two consequences follow: values generated close together in time sort close together, so a UUIDv7 primary key keeps btree index inserts roughly sequential (append-like) instead of scattering writes randomly across the index the way UUIDv4 does; and because generation only needs a clock and a random source, it can happen entirely in application code with no round-trip to the database and no reliance on a Postgres extension, unlike `gen_random_uuid()` or a `SERIAL`/`IDENTITY` column.

## Composite foreign keys for cross-table tenant consistency

A single-column foreign key can only guarantee that a referenced row exists — it can't see a second column on the row it points to. Pairing a tenant-scoped foreign key with a redundant `tenant_id` copied onto the referencing table, and declaring the foreign key as a *composite* one (`(child_ref_id, tenant_id) REFERENCES parent (id, tenant_id)`, which requires a unique constraint on that same pair in the parent), forces the same `tenant_id` value to satisfy two references at once. A row pairing a child from one tenant with a parent from another fails the constraint outright — the isolation guarantee moves from "the application remembered to check" to "the database physically cannot store it," without needing a trigger.
