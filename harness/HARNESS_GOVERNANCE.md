# Harness Evolution Governance

This file defines **who may change the harness, what they may change, and
when**. It exists because the harness is itself an evolving artifact, but
unbounded self-modification would silently change the user's target.

## Immutable without an explicit user decision

The Harness Maintainer and Coordinator must **never** automatically edit:

- `spec.md` — requirements are immutable during a run and may only change
  after a user decision/approval, recorded in `decisions.md`.
- `decisions.md` — raw user decisions are append-only and reflect the
  user, not an agent's inferred preference.
- The deliverable's product requirements or configuration intent.

A genuine spec ambiguity, conflict, or missing judgment is an escalation:
record it durably and ask the user. Do not "fix" it by rewriting the
spec.

## Automatically mutable harness scope

After evidence from a completed coordinator invocation, the Harness
Maintainer may automatically update and commit:

1. `knowledge/*.md` — factual findings from real runs: provider/sandbox
   behavior, inbox failure modes, evaluated domain learnings, regression
   observations. Do not overwrite history; append/find a topic file and
   mark a finding resolved only with evidence.
2. `coordinator/milestones.md` — split, re-order, or clarify work units
   when a run demonstrates that a task is too large, has an undiscovered
   dependency, or cannot be objectively evaluated as scoped. Preserve
   completed milestones and explain the evidence/rationale in the
   changed milestone text.
3. Harness process/mechanics: `coordinator/*.sh`, role instructions,
   schemas, `RUNBOOK.md`, `doctor.sh`, and `bootstrap.sh` — only for a
   concrete, evidenced process failure (e.g. a permission mode that
   blocks a role, a verdict parser mismatch, missing durable escalation,
   broken workspace bootstrap). The fix must address the process class,
   not hand-patch a single artifact.

Every automatic harness change must be committed with a message naming
the triggering milestone/run and evidence. It must be pushed and reported
to the live channel/dashboard.

## Cadence

The Harness Maintainer runs **once after every terminal coordinator
outcome**:

- milestone PASS (including after merge),
- evaluator FAIL/escalation,
- role subprocess failure/escalation,
- coordinator infrastructure failure/escalation.

It does **not** run after each internal retry (when retries are enabled),
and it does not run mid-role invocation. This avoids competing edits and
keeps a change attributable to a clear observed outcome.

## Role separation

Harness maintenance is its own agent session/role, distinct from
Generator and Evaluator:

- Generator changes only the deliverable's current milestone branch.
- Evaluator reads/tests only; it never edits either repo.
- Harness Maintainer changes only the harness repo within the automatic
  scope above; it never changes the deliverable or spec/decisions.
- Coordinator sequences the sessions, version-control checks, workspace
  messages, milestone PRs/merges, and durable tracking. It does not use a
  persona-switch to impersonate the other roles.

## Human review remains easy

Automatic does not mean invisible: each Harness Maintainer commit is
pushed to the private harness GitHub repo and reported, and the harness
project dashboard should surface it as an evolution event. A user can
always revert a harness commit or amend the scope through a decision.
