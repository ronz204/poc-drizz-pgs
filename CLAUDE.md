# Forger

A deliberate learning project on advanced Postgres, multi-tenancy, and read-replica high availability, using a simplified incident-management / status-page domain as the practice vehicle. It lives inside the `stores-pocs` monorepo, which has hosted a series of prior store/database proofs of concept, each discarded once its learning goal was met — Forger is the current iteration.

---

## Knowledge base layout

| Path | Holds |
|---|---|
| `.claude/docs/` | Self-contained reference files, one concern each: vision (`overview.md`), per-component reference (`modules.md`), topology and stack (`structure.md`), data model and database infrastructure (`database.md`), mechanism explanations (`expertise.md`), build sequencing and roadmap (`approach.md`) |
| `.claude/rules/` | Conventions auto-loaded when a matching file is opened/edited, scoped via `paths:` frontmatter |
| `.claude/skills/` | The delta methodology's own capabilities (`archivist`, `specifier`, `sentinel`, `surveyor`) |
| `.claude/settings.json` | Permission policy — see Permissions below |
| `deltas/` | Per-slice spec/design/plan files: `<slice>.spec.md`, optional `<slice>.design.md`, optional `<slice>.plan.md` |

## Repo layout

| Path | Purpose |
|---|---|
| `source/` | The Forger application itself (Hexagonal + DDD), including the persistence layer. No internal structure decided yet beyond this top-level directory — empty, since no application code has been written. |
| `drizzle/` | The Drizzle ORM schema layer: table/enum definitions, the tenant-isolation policy, DB-level triggers (hand-authored SQL, kept separately since the ORM can't generate them), and generated migrations. |
| `cmd/` | Scaffolded entrypoint for future scripts; purpose not yet decided — still empty. |
| `docker/` | Local Postgres infrastructure via Docker Compose: a primary node with bootstrap automation for roles and the schema. No replica yet. |

## Setup & common commands

- `bun install` — install dependencies.
- `bun run lint` / `bun run format` — Biome check / format.
- `bunx drizzle-kit generate` — regenerate migrations from the schema definition in `drizzle/`.
- Local Postgres comes up via the root Docker Compose file, which includes `docker/`'s. It defines a primary only; bringing it up and confirming Bun connects to it hasn't happened yet — see `deltas/core-schema.plan.md`.

## Permissions

The full policy lives in `.claude/settings.json`. By default it denies reading `.env`/secrets files and pushing/pulling git, and pre-approves read-only git inspection, Docker Compose/exec, and shell/web lookups needed to work on local infrastructure.

## Conventions

See `.claude/rules/` for the conventions currently enforced: persistence write/read adapter splitting, pairing a Row-Level-Security `SET` with its query inside the same transaction, Drizzle schema/trigger file conventions, and how this knowledge base itself gets edited.

---

## Non-goals

- Forger is a learning exercise, not a product build — features are scoped to what exercises the target Postgres/multi-tenancy/replication mechanics, not to what a real status-page product would need.
