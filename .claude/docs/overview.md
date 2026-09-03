# Forger — Overview

Vision and domain scope for Forger. Architecture and stack live in `structure.md`; the build roadmap lives in `approach.md`; the underlying Postgres/replication mechanisms live in `expertise.md`.

---

## Vision

Forger maintains per-tenant incident and status data behind two very different access patterns — an authenticated internal panel that mutates state, and a public, read-heavy status page — while keeping tenant data correctly isolated and both surfaces fast regardless of which Postgres node serves them. The point of the project is not the incident-management domain itself — it's a domain with genuine, non-forced reasons to need multi-tenant isolation and primary/replica read routing at once, so those two mechanisms can be practiced together rather than each in isolation: a paying tenant's data must never leak to another tenant, and a public status page must absorb high read volume without competing with writes on the primary.

## Domain concepts

| Concept | Description |
|---|---|
| Tenant | The organization using Forger. Has a plan that limits how many Services it may register. |
| Service | A monitored component (e.g. an API, a dashboard, a payments subsystem) belonging to exactly one Tenant. |
| Incident | The aggregate root. Moves through a one-way status lifecycle — `investigating → identified → monitoring → resolved`, never backward; a recurrence of the same problem becomes a new Incident — with a severity (`minor`/`major`/`critical`) and one or more affected Services, all of which must belong to the same Tenant as the Incident itself. |
| IncidentUpdate | An append-only, immutable timeline entry belonging to exactly one Incident. An Incident cannot reach `resolved` without at least one IncidentUpdate recording that resolution. |
| Subscriber | Someone subscribed to a Tenant's notifications. Deferred — see below. |

## Deferred domain scope

Subscriber and notification delivery are explicitly deferred. They open the door to a queue, which is a mechanism outside this project's actual focus (multi-tenant isolation and replica routing), not a natural requirement of the core domain — adding it now would be scope creep, not practice.

## Multi-tenancy isolation

Two isolation approaches are meant to be implemented and compared rather than one chosen up front: row-level security enforced by Postgres itself, versus explicit `tenant_id` filtering enforced by application-code discipline. See `expertise.md` for how each mechanism actually works — the comparison itself (real security guarantee vs. performance vs. maintenance complexity vs. behavior under replication) is this project's central learning subject, not an implementation detail to settle quickly.

---

## Non-goals

- No production-grade incident-management feature set — only what's needed to exercise isolation and replica routing.
- No frontend — the public status page and internal panel are exposed as API surfaces only, not a rendered UI.
- No general OLAP/analytics query surface — partitioning and materialized views are scoped to this project's own synthetic data, not a general analytical capability.
