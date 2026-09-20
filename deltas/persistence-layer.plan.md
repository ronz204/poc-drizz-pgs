# persistence-layer — Plan

> Stand up and verify the core Postgres schema and its DB-level invariants described in core-schema.spec.md, from schema definition through a confirmed-working migration against a real Postgres primary.

## Status

In progress — schema, triggers, and migrations are complete and statically verified. Verification against a running Postgres instance is still pending, blocked on the primary being brought up (steps 4–5 below).

## Goal

Realize every table, enum, isolation policy, and trigger in core-schema.spec.md's Contract, and confirm each Invariant actually holds when exercised against a real database — not just when read from the schema definition.

## Approach

The schema and its triggers were built directly from the project's own database design reference, which already captured the target shape before this plan or its spec existed. Schema came before triggers, since the triggers reference tables that have to exist first; the parts expressible in the ORM were generated into a migration, and the parts that aren't (the triggers — this project's ORM has no trigger primitive) were hand-authored as canonical SQL and then pasted into a second, custom migration, kept in the same sequence as the generated one. Live verification was deliberately deferred rather than treated as a blocker on writing the schema itself: getting the shape and the invariants right in the schema definition doesn't require a running database, and infrastructure stand-up is being tracked as its own concern.

## Steps

| # | Step | Touches | Done when |
|---|---|---|---|
| 1 | Define the schema — tables, enums, isolation policy | Schema definition | Type-checks cleanly and generates the expected DDL with no duplicate constraint/policy names. |
| 2 | Author the DB-level triggers for invariants the ORM can't express | Trigger definitions | Every trigger in the spec's Contract exists as a canonical, self-contained definition (function + trigger together). |
| 3 | Generate and complete the migrations | Migrations | A generated migration produces the schema; a second, custom migration carries the trigger SQL, sequenced after it. |
| 4 | Stand up a Postgres primary and apply both migrations against it | Infrastructure, migrations | Both migrations apply with no errors against a running primary. |
| 5 | Exercise each trigger directly against that primary | Verification | All five trigger scenarios (service cap overrun, backward status update, resolving without a matching update, editing an IncidentUpdate, deleting an IncidentUpdate) are confirmed to fail exactly as the spec describes. |

Steps 1–3 are done. Steps 4–5 are the remaining work.

## Risks & rollback

Low risk: nothing in this plan has touched a live database yet, and no shared or production state exists. The only real risk is a trigger behaving differently once actually executed than its static reading suggested (e.g. a privilege the application role turns out not to have, or a row-level-security interaction that changes what a trigger's own queries can see). If step 4 or 5 surfaces that kind of problem, the fix is a change to the trigger definition and a fresh migration — there's no in-place data to roll back.

## Validation

Apply both migrations against a local Postgres primary, then attempt each of the five forbidden operations directly (a manual script or `psql` session is sufficient) and confirm each one is rejected with the expected error, and that the allowed counterparts (a service insert under the cap, a forward status update, a resolved status with its matching update already present, reading an IncidentUpdate) succeed normally.

## Out of scope

- Standing up a replica or confirming application connectivity to both nodes — that's the remaining piece of infrastructure stand-up beyond what this slice's schema needs, and belongs with the read-replica-routing work, not this plan.
- Explicit `tenant_id`-filtering, Subscriber's full design, and the write/read repository adapters that will consume this schema — see this slice's spec for why each is out of scope.
