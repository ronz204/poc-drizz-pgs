---
paths:
  - "drizzle/database/**"
---

# Drizzle Schema & Trigger Conventions

This project's Drizzle ORM schema layer is split into one file per concern — table definitions, database-level triggers, isolation policies, and declarations for objects that exist outside Drizzle's own management. These conventions keep that split navigable as the schema grows past a handful of tables; they don't apply to application code that later queries this schema, only to the schema layer itself.

---

## File layout and naming

- One table gets one file, and one trigger gets one file — never group multiple tables or multiple triggers into a shared file, because a reader looking for one table or one trigger shouldn't have to scan past others to find it.
- A schema file's name matches the entity it defines, in kebab-case, with a suffix that marks it as a schema definition rather than any other TypeScript file in the same tree. A trigger file's name matches the trigger's own concept, in kebab-case, with a suffix that marks it as a raw SQL trigger definition.
- An enum lives in the schema file of the aggregate that owns it, not in a shared enum file — because an enum's meaning (in particular, whether its declaration order is semantically significant) is part of that aggregate's contract, not a project-wide constant. A file that needs an enum owned elsewhere imports it from that owning file rather than redeclaring it.

## Imports

- A schema, trigger, or policy file that imports from a different concern (e.g. a shared column helper, an isolation-policy builder) uses the project's path alias for that import, because the physical distance between concerns makes a relative path fragile to reorganize.
- A schema file that imports a sibling in the same directory (one table referencing another) uses a relative import instead, because both files already move together — a path alias would only add indirection for something that's never going to cross a folder boundary.

## Declaring pre-existing database objects

- A database object created outside Drizzle's management (a schema namespace, a database role — anything provisioned by bootstrap SQL that runs before Drizzle ever touches the database) is declared "existing" in exactly one shared file, never redeclared inline in each schema file that references it. Redeclaring it per file works today but silently invites two declarations to drift out of sync the moment one gets touched and the other doesn't.

## Trigger definitions

- Every trigger file is fully self-contained: the trigger function, the trigger itself, and any privilege change (a grant or revoke) that exists specifically to back up that trigger's invariant all live together in the same file — never split a trigger from its own function, or from a revoke written to reinforce it, because a reader touching one half needs to see the other half's reasoning in the same place.
- A trigger's function and the trigger object itself use a shared, consistent naming prefix pattern — one prefix for functions, a different one for triggers — so the two are visually distinguishable at a glance in database tooling, migration output, and error messages.
- These trigger files are the canonical source for trigger SQL — the ORM in use here has no primitive to generate trigger DDL from a schema definition, so trigger SQL is hand-authored here and then copied, unmodified, into a migration when ready to ship. Never write trigger SQL directly into a migration without keeping this canonical copy in sync — the whole point of keeping triggers here is so a future change to one doesn't require searching through every migration ever generated to find the current definition.

## Schema discovery

- Whatever config tells the migration tool where to find schema files must match schema files specifically (by their dedicated suffix), not every file in the directory tree. A looser match also picks up a barrel file that re-exports tables from elsewhere, and the migration tool then sees each table twice — once from its own file, once through the barrel's re-export — producing duplicate constraint and policy names in generated output.

---

## Non-goals

- This governs the schema layer's own file organization, not the invariants those files encode — a table's constraints, a trigger's behavior, and what must hold at the database level belong in that slice's own spec, not here.
