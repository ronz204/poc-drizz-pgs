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
| `services/forger-engine/deltas/` | Per-slice spec/design/plan files: `<slice>.spec.md`, optional `<slice>.design.md`, optional `<slice>.plan.md` — none exist yet |

## Repo layout

| Path | Purpose |
|---|---|
| `services/forger-engine/` | The Forger application itself (Hexagonal + DDD). No internal structure decided yet beyond this top-level directory — it doesn't exist on disk yet, since no code has been written. |

## Setup & common commands

Not yet established. No package manifest, task runner, or Docker Compose file exists yet — the project's first build phase (standing up Postgres primary + replica and confirming Bun connectivity) hasn't started.

## Permissions

The full policy lives in `.claude/settings.json`. By default it denies reading `.env`/secrets files and pushing/pulling git, and pre-approves read-only git inspection, Docker Compose/exec, and shell/web lookups needed to work on local infrastructure.

## Conventions

See `.claude/rules/` for the two conventions currently enforced: splitting persistence into separate write (primary) and read (replica) adapters, and always pairing a Row-Level-Security `SET` with its query inside the same transaction.

---

## Non-goals

- Forger is a learning exercise, not a product build — features are scoped to what exercises the target Postgres/multi-tenancy/replication mechanics, not to what a real status-page product would need.
