---
paths:
  - "source/core/**"
---

# Bounded Context Layering Conventions

This governs the internal folder and file layout of every bounded context under `source/core/`, following a hexagonal-plus-DDD tactical layering. A shared-kernel folder under `source/core/` already holds real primitives; bounded-context aggregates themselves are not implemented yet beyond empty scaffolding, so this convention is forward-looking for that part, corrected against the folder/file naming the shared kernel already uses in practice.

---

## Bounded context folders

- Each bounded context is its own folder directly under `source/core/`, named as a two-word kebab-case pair, because a shared naming shape makes the set of bounded contexts scannable as a flat list rather than a mix of single words and long compounds.
- The second word is chosen to be descriptive of that specific context, not a suffix repeated across every bounded context, because a repeated suffix (e.g. always `-domain` or always `-core`) stops carrying information the moment every folder has it — it becomes noise instead of a signal.

## Contexts and contracts split

- Every bounded context folder splits into exactly two top-level subfolders: `contexts/`, holding the domain model itself (aggregates, entities, value objects, domain events, domain errors), and `contracts/`, holding the ports that bounded context exposes outward (repository interfaces, DTOs, published-event contracts) for other contexts or the application layer to depend on.
- Nothing outside a bounded context imports from its `contexts/` folder directly — the `contracts/` folder is the only supported dependency surface, because letting outside code reach into `contexts/` directly would let another bounded context (or the app layer) couple to internal representations that are free to change without notice. The shared-kernel exception below is the one deliberate exception to this.
- `contracts/` never holds a re-export of a concrete aggregate, entity, or domain-error class merely to make it reachable from outside — only genuine port/interface/DTO declarations belong there (repository interfaces, published-event contracts, request/response DTOs). A bounded context with no ports yet has an empty, or absent, `contracts/` folder — that's not a gap to fill preemptively with re-exports of whatever `contexts/` happens to contain.
- Each bounded context also has an `index.ts` at its own root, acting as its single public entry point and the one place outside `contexts/` allowed to import from it: it re-exports the context's public reference value objects (ids and similar lightweight cross-boundary reference types) directly from `contexts/*/*.vos.ts`, plus whatever exists in `contracts/` once there's something there. Other code imports the bounded context through `index.ts` — never by reaching into `contracts/`'s own files, or into `contexts/`, directly.

## Shared kernel exception

- A folder under `source/core/` whose purpose is to hold primitives shared across bounded contexts (base value objects, shared ids, common base types, shared domain errors) rather than an aggregate of its own keeps the same `contexts/` folder and `index.ts` barrel as any bounded context, but is exempt from the slice-subfolder rule below: its files sit flat directly under `contexts/`, not grouped into per-aggregate subfolders, because shared primitives aren't aggregates and have nothing to group by.
- Its `index.ts` barrel re-exports `contexts/` directly, rather than a `contracts/` translation layer, and it typically has no `contracts/` folder at all — a shared kernel is shared by direct reference in DDD, not translated across a port like a real bounded context's internals, so there's usually nothing left needing one. The `contracts/` folder remains available on the same terms as any bounded context if a shared-kernel concept ever does need one.

## Slice subfolders inside contexts/

- Inside `contexts/`, organize by slice: one subfolder per aggregate, named after that aggregate (a "slice"), e.g. `contexts/tenant/`, `contexts/service/`. A bounded context routinely holds more than one slice side by side — nothing about the two-subfolder split above implies one aggregate per bounded context.
- Every slice gets its own subfolder, even a bounded context that currently has only one — never flatten a single-slice context's files directly under `contexts/` with a prefixed filename instead. Deciding flat-vs-nested per bounded context, based on how many slices it happens to have today, is exactly the kind of ad hoc call that drifts silently as a context gains a second slice later: some contexts end up nested, some stay flat, and nothing forces the flat ones to be revisited. A uniform rule removes that decision entirely.

## File naming inside a slice

- Inside each `contexts/<slice>/` folder, files are named `<slice>.aggregate.ts`, `<slice>.entities.ts`, `<slice>.vos.ts`, `<slice>.events.ts`, `<slice>.errors.ts`, `<slice>.enums.ts` (a closed set of literal values, e.g. a state or tier enum), and `<slice>.types.ts` (other type aliases/interfaces the slice needs that don't fit any of the other file kinds, e.g. the shape of a persisted snapshot a reconstitution factory accepts) — only the ones that slice actually needs (a slice with no domain events yet has no `.events.ts` file), because an empty placeholder file communicates nothing a missing file doesn't already communicate.

## Aggregate immutability

- An aggregate favors `readonly` public fields over a private field paired with a getter, when the getter would do nothing but return that field — that getter is boilerplate, not encapsulation, since it adds a method without adding any actual guard or transformation.
- A state-changing operation on an aggregate returns a new instance rather than mutating the receiver in place, so a caller still holding a reference to the pre-change instance keeps a value that stays valid and unaffected by the change, instead of having it silently mutate out from under them.

---

## Non-goals

- This rule governs internal layering and file naming only. It does not decide which domain concepts belong to which bounded context, or where one aggregate's boundary ends and another's begins — those are per-bounded-context decisions made in that slice's own `spec.md`, not here.
