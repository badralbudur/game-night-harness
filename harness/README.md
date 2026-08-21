# Harness Template

This directory is the **portable harness**: everything needed to iterate on or
rebuild a deliverable, but not the deliverable itself, and not any run's
execution history.

## What travels with the harness (this directory)

- `RUNBOOK.md` — how to actually execute this harness: who runs it,
  prerequisites, on-demand vs. unattended/cron execution, how to adapt
  the coordinator to a different model/agent provider than the default.
  Read this first if you're picking up a ported copy cold.
- `HARNESS_GOVERNANCE.md` — explicit authority/cadence for evolving the
  harness itself: user-only spec/decision changes vs. automatically
  mutable knowledge, milestones, and evidence-backed process fixes.
- `spec.md` — the current, synthesized, structured specification: requirements,
  generation rules, evaluation criteria. Immutable *during* a run; updated
  only between runs, deliberately, as the mechanism for changing target
  behavior (never patch the output artifact directly).
- `decisions.md` — an append-only, chronological, lightly-tagged log of raw
  user decisions, verbatim. `spec.md` is *derived* from this; when spec.md and
  the reason "why" seem to diverge, `decisions.md` is the source of truth.
- `knowledge/*.md` — domain knowledge earned while iterating that isn't a
  requirement in its own right (patterns noticed, things learned about the
  problem space, cross-run observations worth remembering).
- `roles/manifest.md` — registry of active roles: name, responsibility,
  inbox address. The coordinator loops over whatever is listed here; roles
  are not hardcoded to a fixed Generator+Evaluator pair. Add or remove roles
  by editing this file (e.g. a dashboard-support role, a domain-specific
  advisory role) without touching the coordinator's logic.
- `roles/*.md` — one file per active role, its operating instructions.
- `coordinator/coordinator.sh` (or `.py`) — drives the loop: reads
  `roles/manifest.md`, `coordinator/milestones.md`, and workspace
  progress state to determine the current milestone, sends directives,
  waits for artifacts/verdicts, applies retry/escalation policy from
  `coordinator/policy.md`.
- `coordinator/milestones.md` — breaks `spec.md` into an ordered
  sequence of small, independently buildable-and-gradeable increments.
  The coordinator scopes each Generator/Evaluator run to exactly ONE
  milestone at a time — attempting the full spec in one run is too large
  a unit of work to reliably complete (confirmed empirically: an
  early full-spec attempt produced a substantial partial build but hit
  a provider usage limit before finishing or committing). The Generator
  still reads the full `spec.md` every run so it never violates a
  later-milestone invariant, but its concrete task is milestone-scoped.
- `coordinator/policy.md` — retry bound, escalation trigger, timeout
  behavior. Does **not** encode how evaluation works — that's up to each
  evaluator role — only how the loop reacts to a verdict.
- `schemas/message.md` — inbox message format (task directive, artifact
  reference, feedback).
- `schemas/verdict.md` — pass/fail + structured breakdown format that every
  evaluator-type role must emit.
- `bootstrap.sh` — given a target team/workspace name, provisions fresh
  inboxes/directories in Fulcra Workspaces and uploads the current
  `spec.md`, `decisions.md`, `knowledge/`, and `roles/*` — nothing else.

## What does NOT travel with the harness

- The deliverable/artifact itself (lives in the workspace's `artifact/` area
  during iteration; gets exported out once approved).
- Execution history: run logs, verdict records from past loops, inbox
  message history, continuity/presence state. This is workspace-side and
  disposable — reconstructable at any time by re-running `bootstrap.sh`
  against the current harness contents.

## Portability test

`bootstrap.sh <new-team-name>` run against a brand-new empty Fulcra
Workspaces team must immediately produce a working loop: new
generator/evaluator (or whatever roles are active) agents pick up
`spec.md`, `decisions.md`, `knowledge/`, and `roles/*.md` from scratch, with
zero dependency on any prior run's inbox contents or logs. If bootstrap
needs anything besides this directory's contents, the harness isn't
portable yet — that's a bug to fix.

## v1 scope note

This harness runs on raw `fulcra-workspaces` primitives (inboxes, shared
files) only — no `fulcra-agent-coordination` engine yet. The goal is to
observe firsthand how/when a plain-inbox loop breaks down (message loss,
ambiguous state, unclear liveness) before deciding whether to adopt the
coordination layer. Track breakdowns in `knowledge/` as they're found.
