# plan-lifecycle-swap — Spec

> Applying an already-decided change to an existing Tenant's plan, and the serviceCap that plan implies.

## Intent

A Tenant's plan can change over its lifetime (for example, moving from a lower tier to a higher one). This slice defines the domain operation that applies such a change to an existing Tenant, keeping its serviceCap consistent with its new plan. It is the counterpart, for an existing Tenant, to what the multitenant-org bounded context's Tenant creation already establishes for a new one.

## Scope

In scope:
- A domain operation on the existing `Tenant` aggregate that changes its plan and, together with it, its serviceCap, per a fixed plan-to-cap mapping the domain owns.
- Rejecting a plan change that would drop the Tenant's serviceCap below its current registered-Service count, leaving the Tenant's plan and serviceCap unchanged when that happens.

Out of scope:
- Who may initiate a plan change, or under what business circumstance (billing, an admin action, a self-service flow). This spec covers only the domain mechanics of applying a change that has already been decided, consistent with this project's non-goal of not modeling billing/plan-enforcement mechanics in depth.
- Any change to the existing database-level service-cap trigger, or any new database-level trigger to back up this slice's downgrade-rejection invariant. Whether one is needed is a genuinely open question (see Deferred / Open questions) that belongs to the persistence layer's own spec to decide, not this one.
- Persistence, schema, and row-level security — owned by the persistence layer's own spec; this spec is domain mechanics only.
- The session-scoped tenant-context discipline that keeps row-level security correct under connection pooling — a cross-cutting persistence-layer concern, not owned here.
- Incident, IncidentUpdate, and Subscriber — out of scope for the same reasons the multitenant-org bounded context's own spec already states.

## Contract

### Operation

| Input | Output on success | Output on conflict |
|---|---|---|
| An existing `Tenant` and a new plan | A new `Tenant` instance, with plan and serviceCap both updated per the plan-to-cap mapping | `PlanDowngradeConflictError`; the original Tenant instance is unaffected |

### Plan-to-cap mapping

A fixed mapping from each plan to a serviceCap value, owned by the domain:

| Plan | serviceCap |
|---|---|
| `free` | 3 |
| `pro` | 15 |
| `enterprise` | 50 |

## Invariants

- A Tenant's serviceCap always matches its current plan per the plan-to-cap mapping — the two never drift independently once a plan change is applied.
- `changePlan` never mutates the Tenant it's called on — it returns a new instance on success, and on a downgrade conflict raises `PlanDowngradeConflictError` and returns nothing, leaving the original instance untouched either way.

## Deferred / Open questions

- Whether a database-level trigger should back up the downgrade-rejection invariant, mirroring the two-independent-enforcement-paths pattern this project applies elsewhere (the persistence layer's own service-cap-on-insert trigger, and the multitenant-org bounded context's own domain-level cap check on Service creation), is not yet decided. Deciding it means amending the persistence layer's own spec, which this spec does not do unilaterally.

## Acceptance criteria

Currently satisfied:
- `Tenant.changePlan` exists and type-checks cleanly, on the same `Tenant` aggregate defined in multitenant-org.spec.md (not exposed outside the bounded context's `contexts/` yet — see that spec's Public surface).
- Unit tests cover: changing an existing Tenant's plan updating its serviceCap to match the new plan's mapped value; a plan change that would drop serviceCap below the Tenant's current registered-Service count being rejected, with the Tenant's plan and serviceCap left unchanged.

Not yet satisfied:
None — every acceptance criterion is satisfied.

---

Last updated: 2026-09-20.
