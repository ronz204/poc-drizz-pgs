# stores-pocs

A container repo for sequential, learning-focused proof-of-concept projects. Each POC lives under `services/` and is worked on until its learning goals are exhausted, then purged and replaced by the next one — this has already happened once (a prior feature-flags POC was fully removed before the current POC started). Treat whatever is currently under `services/` as the *active* POC, not a permanent product.

**Current active POC: Forger** — a Postgres-focused exercise (advanced Postgres, multi-tenancy isolation, high availability via read replicas) using an incident-management/status-page domain as the vehicle. See `.claude/docs/overview.md` for its vision and domain model, `.claude/docs/structure.md` for its architecture and stack, `.claude/docs/approach.md` for its build roadmap, and `.claude/docs/expertise.md` for the underlying Postgres/replication mechanisms it depends on. `ROADMAP.md` at the repo root is the user's personal progress checklist for that same roadmap — not part of the knowledge base, not English-mandated, and safe to check off freely.

---

## Knowledge base layout

| Path | Holds |
|---|---|
| `.claude/docs/` | Reference files for the active POC — `overview.md` (vision, domain model), `structure.md` (architecture, stack, planned infrastructure topology), `approach.md` (build roadmap), `expertise.md` (underlying Postgres/replication mechanisms) |
| `.claude/rules/` | Conventions auto-loaded when a matching file is opened/edited — currently only the rule governing how this knowledge base itself is edited |
| `.claude/skills/` | The delta methodology's own skill set: `archivist` (writes knowledge-base artifacts), `specifier` (gathers spec/design intent before a slice is written), `sentinel` (checks a slice against its implementation), `surveyor` (bootstraps a new project's knowledge base — used to create this file) |
| `.claude/settings.json` | Permission policy — see Permissions below |
| `services/<service>/deltas/` | Per-slice spec/design/plan files (`<slice>.spec.md`, optional `<slice>.design.md`, optional `<slice>.plan.md`) — none exist yet, since the active POC has no code |

## Repo layout

| Path | Purpose |
|---|---|
| `services/forger-engine/` | Forger's backend service — a Hexagonal-architecture API. Not yet implemented. |
| `docker/` | Local container provisioning for Forger's planned Postgres primary/replica topology. Not yet implemented. |
| `compose.yml` | Root orchestration for Forger's local services. Not yet written. |
| `ROADMAP.md` | Personal progress checklist mirroring `.claude/docs/approach.md`'s roadmap, in Spanish. |

## Setup & common commands

Nothing is runnable yet — no package manifest exists anywhere in the repo. Standing up the local stack (Postgres primary + replica, confirming connectivity) is the first roadmap phase in `.claude/docs/approach.md`; this section gets filled in once that lands.

## Permissions

The full policy lives in `.claude/settings.json`. Reads of `.env`/secrets files and `git push`/`git pull` are denied by default; read-only git inspection, `docker exec`/`docker compose`, `curl`, `powershell`, and `WebSearch` are pre-approved.

## Conventions

No application-code conventions exist yet — the active POC has no code. `.claude/rules/delta-artifacts.md` governs how this knowledge base itself is edited (route writes through the matching skill rather than hand-editing).

---

## Non-goals

This repo does not aim to ship a production-ready product. A POC's code is expected to be discarded once its learning goals are met, the same way the prior one was — don't treat `services/forger-engine`'s eventual implementation as something that needs long-term backward compatibility.
