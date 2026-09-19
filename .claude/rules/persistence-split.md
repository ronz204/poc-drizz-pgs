---
paths:
  - "source/**"
---

# Persistence Adapter Split Conventions

Forger's central learning goal is understanding primary/replica Postgres routing end to end, without a third-party read-routing library doing it invisibly. This rule protects that goal at the code level: it applies to any persistence-layer code written for Forger, regardless of which internal directory layout it eventually lands in under `source/` (not yet decided).

---

## Write and read paths never mix

- Every write operation must go through a client/adapter that connects only to the Postgres primary, because the primary is the only node guaranteed to reflect a write the instant it commits.
- Every read operation must go through a separate client/adapter that connects only to the Postgres replica, because routing reads there is the entire point of the exercise — reading from the primary defeats it silently.
- Never build a single adapter/client capable of reaching both nodes and deciding at call time which one to use. Collapsing the two into one adapter would hide a routing mistake behind code that happens to still work, rather than surfacing it as a wrong-node bug.

---

## Non-goals

- This is not a request for a full CQRS architecture with separate read/write data models — see `overview.md`'s scope boundary. The split here is purely about which physical Postgres node a query lands on.
