---
paths:
  - "services/forger-engine/**"
---

# RLS Transaction Scope Conventions

Row-Level Security in Postgres is keyed off session-local state, but a connection pool can hand two calls to different physical connections without warning. This rule applies to any query written for Forger that depends on an active RLS policy, regardless of which internal directory layout it eventually lands in (not yet decided).

---

## The SET and its query share one transaction

- Whenever a query depends on RLS filtering by tenant, the session-scoped tenant-context `SET` and that query must execute inside the same transaction (or otherwise provably the same connection). Because RLS state lives on the connection, letting the pool separate the `SET` from its query silently breaks tenant isolation instead of raising an error — a query can end up unscoped or scoped to the wrong tenant with no visible failure.
- Never assume a `SET` from an earlier call in the same request is still active for a later query — pooled connections make no such guarantee. Re-establish the tenant context within the same transaction as every RLS-scoped query that needs it.

---

## Non-goals

- This rule governs RLS-scoped queries specifically; it says nothing about the explicit-`tenant_id`-filtering alternative also being evaluated for this project, which has no session-state dependency to protect.
