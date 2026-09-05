# Overview

What Forger is for and the domain vocabulary it's built around. How the system is actually structured lives in `structure.md`, not here.

---

## Vision

Forger exists to practice advanced Postgres operation deliberately: multi-tenant isolation at the database level, primary-to-replica streaming replication, and the consistency trade-offs that come from routing reads and writes to different nodes. The incident-management / status-page domain (in the shape of a simplified Statuspage.io) is a vehicle for that practice, not the goal itself — every domain decision is chosen because it gives the underlying Postgres mechanics something concrete to bite into (e.g. an aggregate whose isolation invariant has to hold under replication, an append-only timeline that stresses read-heavy query patterns).

## Scope & non-goals

Forger owns: multi-tenant incident and status-page management, with a real physical split between the write path (primary) and the read path (replica). It does not aim to be a complete or production-ready status-page product — feature breadth is deliberately limited to whatever exercises the target database mechanics.

Explicitly out of scope: fully separate read/write data models or materialized projections. The write/read split is physical (which Postgres node a query lands on), not a full CQRS architecture with independent read models — introducing one would be over-engineering for what this project is practicing.

## Domain concepts

| Concept | Description |
|---|---|
| Tenant | The organization using Forger. Has a plan that limits how many Services it can register. |
| Service | A monitored component (e.g. an API, a dashboard, a payments system). Belongs to exactly one Tenant. |
| Incident | The aggregate root of the domain. Has a status that only moves forward — `investigating` → `identified` → `monitoring` → `resolved`, never backward — a severity (`minor`, `major`, `critical`), and one or more affected Services, all of which must belong to the same Tenant as the Incident itself. |
| IncidentUpdate | An immutable, append-only entry in an Incident's timeline. Never edited or deleted once created. |
| Subscriber | Optional, stretch-scope concept: someone subscribed to notifications for a Tenant. |

---

## Non-goals

- Notification delivery, billing/plan enforcement mechanics, and any UI beyond what's needed to exercise the read/write split are not modeled in depth — they exist only as far as the domain concepts above require to make the persistence-layer practice meaningful.
