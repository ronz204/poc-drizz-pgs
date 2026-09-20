# multitenant-org — Spec

> The multi-tenant organizational boundary the rest of Forger's domain depends on: Tenants, their plan and service cap, and the Services registered under them.

## Intent

This bounded context owns the multi-tenant organizational boundary the rest of Forger's domain depends on — creating Tenants, tracking each Tenant's plan and service cap, and registering Services under a Tenant within that cap. It is the domain-model counterpart to the tenant-isolation guarantees the persistence layer already enforces at the database level (row-level security, a service-cap trigger, composite tenant-scoped foreign keys): this slice defines the aggregates and invariants that layer persists, not the schema itself.

## Scope

In scope:
- The `Tenant` aggregate: created with a unique public slug, a plan (free/pro/enterprise), and a positive-integer service cap. Exposes a capability to check whether registering another Service is currently allowed given the tenant's cap, consulted before a Service registration is attempted (see Invariants).
- The `Service` aggregate — its own aggregate root, not nested inside `Tenant`. This is deliberate: the persistence layer's schema already ties a Service to its Tenant through a composite foreign key rather than embedding it, so a different bounded context can reference a Service by id across the boundary without reaching into Tenant's internals. Created referencing an existing `TenantId`; belongs to exactly one Tenant.
- `TenantId` and `ServiceId` value objects, built on the shared kernel's identifier base.
- Domain-level errors for invalid identifiers (reusing the shared kernel's existing one), a service-cap violation, and a duplicate Service name within a Tenant.

Out of scope:
- Changing a Tenant's plan, and the service-cap re-evaluation that implies. Owned by the separate `plan-lifecycle-swap` spec, not this one.
- Persistence, schema, row-level security, and DB-level triggers — those belong to the persistence layer's own spec; this spec is the domain model that layer persists, not the schema itself.
- The session-scoped tenant-context discipline that keeps row-level security correct under connection pooling — that's a cross-cutting persistence-layer concern, not a rule this domain-layer slice owns.
- Incident and IncidentUpdate — owned by a future, separate bounded-context spec.
- Subscriber — a separate, not-yet-modeled bounded context; entirely out of scope here.

## Contract

### Aggregates

| Aggregate | Fields | Notes |
|---|---|---|
| `Tenant` | id (`TenantId`), slug (unique, public), plan (`free` \| `pro` \| `enterprise`), serviceCap (positive integer) | Root of the isolation boundary; not itself scoped to a tenant. |
| `Service` | id (`ServiceId`), tenantId (`TenantId`), name | Own aggregate root; always references an existing Tenant. |

### Public surface

This bounded context's `index.ts` barrel is its only public entry point, and currently re-exports just `TenantId` and `ServiceId` directly from their value-object files. `contracts/` holds this bounded context's ports (repository interfaces, published-event contracts) — it is currently empty, because no repository or other port-level consumer exists yet (that work belongs to the persistence layer's own plan, out of scope here). The `Tenant`/`Service` aggregate classes and their domain errors are not exposed outside `contexts/` at all right now; they become reachable from outside only once a real port in `contracts/` needs to expose them, not by re-exporting them preemptively.

### Cap-check capability

`Tenant`'s capability to check whether registering another Service is currently allowed takes the current Service count as an input parameter from its caller — it does not query for that count itself.

### Reconstitution

Both aggregates expose a `reconstitute` factory, alongside `create`, for rebuilding an instance from previously-persisted state:

| Aggregate | Reconstitutes from | Behavior |
|---|---|---|
| `Tenant` | A snapshot of its stored fields (id, slug, plan, serviceCap) | Rebuilds the Tenant as-is; does not re-derive serviceCap from plan or otherwise re-apply creation-time invariants. |
| `Service` | A snapshot of its stored fields (id, tenantId, name) | Rebuilds the Service as-is from a raw tenantId; unlike `create`, does not require an actual `Tenant` instance and does not re-check that the referenced Tenant exists. |

## Invariants

- A `Service` always references an existing `Tenant` via `TenantId` at creation — it cannot exist without one, mirroring the persistence layer's own composite-foreign-key enforcement.
- A Tenant's service cap is validated at the domain layer before a Service registration is attempted: `Tenant` exposes a capability that must be consulted before constructing a new `Service`, producing a domain-level error on violation rather than relying solely on the database trigger to reject it. This is a deliberate second, independent enforcement path alongside the persistence layer's own trigger — the same two-independent-enforcement-paths pattern that layer already applies to IncidentUpdate immutability: defense in depth, not redundant duplication to remove.
- Plan and service cap are fixed at Tenant creation as far as this spec is concerned — changing either is a separate operation, owned by the `plan-lifecycle-swap` spec, not this one.
- `TenantId` and `ServiceId` are UUIDs validated through the shared kernel's identifier primitives, consistent with the persistence layer's requirement that primary keys are application-generated, never database defaults.
- A Tenant's public slug is fixed at creation and never changes.
- A Service's name is validated for uniqueness within its Tenant at the domain layer before construction — the same defense-in-depth approach as the cap check, alongside the database's own per-tenant uniqueness constraint.
- The cap-check capability takes the current Service count as an input parameter from its caller rather than querying for it itself, keeping `Tenant` free of infrastructure dependencies.
- Reconstitution trusts its snapshot as-is: neither `Tenant.reconstitute` nor `Service.reconstitute` re-applies creation-time invariants (e.g. serviceCap-matches-plan, or Service's Tenant-existence check) — those were already enforced when the row was originally written, and reconstitution's job is fidelity to storage, not re-validation.

## Deferred / Open questions

None currently — every previously open question in this spec has been resolved.

## Acceptance criteria

Currently satisfied:
- `Tenant` and `Service` aggregates, their value objects, domain errors, and `create`/`reconstitute` factories exist and type-check cleanly.
- `TenantId` and `ServiceId` are reachable only through this bounded context's `index.ts` barrel, not by reaching into `contexts/` directly.
- Unit tests cover: creating a Tenant; registering a Service under cap; the domain-level cap check rejecting a registration that would exceed the cap, independent of any database call; registering a Service whose name duplicates another Service's name within the same Tenant being rejected at the domain layer; reconstituting a Tenant and a Service from a snapshot without re-validation; `Service.reconstitute` rejecting an invalid `tenantId` in its snapshot.
- A Service referencing a nonexistent Tenant is prevented structurally, not by a runtime check: `Service.create` requires an actual `Tenant` instance as its parameter, so there is nothing to unit-test at runtime for that case. `Service.reconstitute` deliberately does not check Tenant existence at all (see Reconstitution) — "nonexistent Tenant" isn't a case either path rejects at runtime.

Not yet satisfied:
None — every acceptance criterion is satisfied.

---

Last updated: 2026-09-20.
