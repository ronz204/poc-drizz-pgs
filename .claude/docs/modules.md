# Modules

Per-component functional reference for Forger's planned architecture. Why these components exist and are split this way lives in `overview.md` and `structure.md`, not here. None of the components below are implemented yet — this describes the target design agreed on before any code was written, not observed behavior; update each entry to describe real behavior once it exists.

---

## Write repository (planned)

**Purpose.** Implements the write side of the Incident persistence port. Owns every mutation to Tenant, Service, Incident, and IncidentUpdate data.

**Flow.** Always connects to the Postgres primary node — never the replica, regardless of caller. This is the only path by which incident data changes.

**Data shape.** Not yet defined — depends on the domain model's concrete field shapes, which haven't been implemented.

## Read repository (planned)

**Purpose.** Implements a separate, read-oriented persistence port geared toward status-page queries (current status, incident timelines) rather than mutation.

**Flow.** Always connects to the Postgres replica node — never the primary. Because it reads from a streaming-replication replica, results can lag behind the most recent write; resolving that lag is a dedicated later concern (see `structure.md`'s open architecture decisions).

**Data shape.** Not yet defined.

## Internal panel API (planned)

**Purpose.** The authenticated, per-tenant surface for creating and updating incidents and managing services.

**Flow.** Every operation goes through the write repository against the primary — this surface never reads from the replica, since the person using it needs to see the effect of their own writes immediately.

**Data shape.** Not yet defined.

## Public status page API (planned)

**Purpose.** The unauthenticated, tenant-scoped surface the public sees — current status plus incident timeline.

**Flow.** Every operation goes through the read repository against the replica. Expected to be the higher-volume of the two API surfaces, which is the reason it's the one deliberately routed off the primary.

**Data shape.** Not yet defined.

---

## Non-goals

- No queueing, notification-delivery, or background-worker components are planned as part of this initial component set — `Subscriber` notifications are a stretch-scope concept (see `approach.md`) and would only introduce such a component if actually pursued.
