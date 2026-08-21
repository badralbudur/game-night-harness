# RUNBOOK

How to actually execute this harness — for a human, a fresh Hermes/agent
session, or a different agent framework entirely. If you can't answer
"what runs this and how" from this file alone, the harness isn't
portable yet (see README.md's portability test).

## Who runs the coordinator

Two supported modes:

1. **On-demand:** any agent session with terminal access invokes
   `coordinator.sh` directly, once, and watches it run synchronously to
   completion (pass, retry-bound-exceeded, or escalation).
2. **Unattended (cron/scheduled):** a scheduler wakes a fresh agent
   session periodically; that session's job is to run `coordinator.sh`
   once and exit. See "Unattended execution" below. Unattended execution
   is a requirement, not optional — the harness must be able to loop
   without a human explicitly re-invoking it each time.

Either way, the actual generation/evaluation work happens in separate
subprocesses per role (see "Model/agent providers" below) — the
coordinator itself never generates or evaluates anything; it only
sequences role invocations and reads their verdicts.

## Prerequisites (doctor check)

Run the automated check first:

```bash
DELIVERABLE_DIR=/path/to/deliverable/repo ./doctor.sh
```

This verifies Fulcra Workspaces auth, the role-runner CLI (`claude` by
default — see "Model/agent providers" below if using something else),
git identity, that `spec.md` has an actual filled-in Goal (not the
template placeholder), that `coordinator/policy.md` declares a retry
bound, and that `DELIVERABLE_DIR` is a real, separate git repo from this
harness. Exits non-zero with a clear per-check failure message if
anything's missing — fix it before running `bootstrap.sh` or
`coordinator.sh`.

Manually, the same checks are:

```bash
# 1. Fulcra Workspaces auth (inboxes/artifacts live here)
uvx fulcra-api user-info    # must return a JSON user record, not an auth error

# 2. An agent/model CLI capable of running a role's instructions
#    non-interactively (see "Model/agent providers" below for what
#    "capable" means if you're not using claude)
claude --version            # if using Claude Code as the role runner

# 3. git identity configured (commits must be attributable)
git config user.name && git config user.email

# 4. The deliverable repo exists and is cloned locally, separate from
#    this harness repo (spec requirement: no shared git history)
ls <deliverable-dir>/.git
```

If any of these fail, fix them before running `bootstrap.sh` or
`coordinator.sh` — do not attempt to work around a missing prerequisite
by guessing at credentials or paths.

## First-time setup (per project)

```bash
# From inside this harness directory:
./bootstrap.sh <team-name>
```

This provisions a fresh Fulcra Workspaces team from the harness's current
`spec.md`, `decisions.md`, `knowledge/`, and `roles/*` — refuses to run
against a team name that already has a `role.md` (won't silently
overwrite an existing run's team). See README.md for exactly what does
and does not get uploaded.

## Running a loop

```bash
DELIVERABLE_DIR=/path/to/deliverable/repo \
  ./coordinator/coordinator.sh <team-name>
```

This runs to completion: PASS (exit 0), a first-attempt FAIL/escalation
(exit 1 while automatic retries are disabled), retry-bound-exceeded
(exit 1 when automatic retries are enabled), or unparseable-verdict
(escalation, exit 1). Its behavior is controlled explicitly by
`coordinator/policy.md`'s **Automatic retries enabled** switch:

- Current interactive/manual mode: `false`. One Generator→Evaluator
  attempt only; any role failure or FAIL verdict stops, records a durable
  escalation, and returns control to the human/operator — no sleeping,
  backoff, or automatic re-run.
- Future unattended mode: change it to `true`. The coordinator may then
  make bounded automatic attempts up to the policy's maximum retry count.

To keep the project moving after an escalation or a PASS (e.g. to pick up
a new `spec.md` revision and iterate further), invoke it again explicitly
in manual mode, or let the scheduler wake it after unattended mode has
been deliberately enabled.

### Do-nothing short-circuits

Before doing any real work, the coordinator checks two cheap markers in
the workspace so that repeated/unattended invocations don't waste a real
Generator+Evaluator subprocess call for no reason:

1. **Already converged:** if `team/<team>/converged.md` records a PASS
   for the *current* harness spec version (`git rev-parse HEAD` in this
   harness repo), the coordinator exits 0 immediately without invoking
   anyone. Revising `spec.md` and committing that change naturally
   invalidates this (the spec_ref changes), which is the intended way to
   ask for more work.
2. **Already escalated:** if `team/<team>/escalation/.latest.md` records
   an open escalation for the current spec version, the coordinator exits
   1 immediately without re-attempting retries — an unresolved blocker
   shouldn't be silently re-discovered every cron tick. Resolve the
   blocker (or revise `spec.md`, which changes the spec_ref and lifts the
   short-circuit) before the next run does real work again.

Both checks only compare against the *current* spec version, so editing
`spec.md` and committing is the standard way to signal "there's new work
to do" to any future invocation, attended or not.

## Milestone branches and review PRs

Before each milestone run, the Coordinator creates (or resumes) a branch
named `milestone/<id>-<slug>` in the **deliverable** repo. GitHub cannot
open a PR for a zero-diff branch, so after Generator pushes its first
milestone commit the Coordinator opens one private PR from that branch to
`main` **before** Evaluator runs. The branch/PR persists across attempts:
a FAIL or escalation leaves its committed work visible and reviewable
rather than discarding it.

- Generator receives narrow permissions to `git add`, `git commit`, and
  `git push` its own deliverable work **only on that prepared milestone
  branch**. It may not create branches, merge PRs, or write `main`.
- Evaluator grades the committed milestone branch state, not an
  uncommitted working tree.
- Coordinator merges that PR only after an `overall: PASS` verdict, then
  updates `milestone-progress.md` and moves to the next milestone.
- If merge itself fails, Coordinator escalates and does not advance the
  milestone pointer; an evaluation pass is not enough until the approved
  work is actually in `main`.

This requires authenticated `gh`; `doctor.sh` checks it.

## Harness evolution governance

Read `HARNESS_GOVERNANCE.md` before making process changes. In short:
`spec.md` and `decisions.md` only change after an explicit user decision;
knowledge accumulation, evidence-backed milestone decomposition, and
concrete harness-process fixes may be made automatically after every
terminal coordinator outcome by the separate Harness Maintainer role.
Every such change must be committed/pushed/reported, never silently
applied.

## Unattended execution (cron/scheduled)

The coordinator does not daemonize or schedule itself — that's the
scheduler's job, not the harness's. On Hermes, this looks like:

```bash
hermes cron create "0 */6 * * *" \
  --name "game-night-harness-coordinator" \
  --workdir /home/fulcra/game-night-harness/harness \
  --deliver origin \
  "Run the harness coordinator for team game-night-v1: cd into this workdir and run \
   DELIVERABLE_DIR=/home/fulcra/game-night ./coordinator/coordinator.sh game-night-v1 \
   Report the outcome (PASS / escalated / still-running) back to this chat. \
   If it escalates, read the escalation entry it wrote to the workspace and summarize \
   the blocking issue clearly so the user can resolve it from here or any other channel."
```

Key properties this relies on:
- Each cron tick wakes a **fresh agent session** with no memory of prior
  ticks (other than what's durably recorded in the harness/workspace
  files themselves) — this is why `decisions.md`, `spec.md`, and the
  workspace's own progress/escalation files must be self-sufficient. The
  cron prompt's job is only to say "go run this script and report back,"
  not to carry forward context the files don't already have.
- `--deliver origin` means outcomes get reported back to wherever this
  cron job was created from; combined with the durable escalation log
  (written to the workspace regardless of delivery channel), this
  satisfies "resolvable from any channel" — the chat notification is a
  convenience, the workspace log is the source of truth.
- On a non-Hermes framework, the equivalent is: whatever your scheduler
  is (system cron, a CI schedule, another agent framework's own
  scheduled-task primitive), wake a process, `cd` into the harness
  directory, run `coordinator.sh <team-name>`, and have your framework's
  own equivalent of "deliver output" surface the result. The escalation
  log in the workspace doesn't depend on Hermes at all — any framework
  reading Fulcra Workspaces files can pick it up.

## Model/agent providers

`coordinator.sh` currently invokes each role via the `claude` CLI
(`claude -p --model <alias> ...`), because that's what's available in
this environment. This is a convenience default, not a requirement of
the harness design. The actual requirement (spec #34) is only:

> Each role runs as a genuinely separate agent subprocess/session — never
> one session switching personas to play multiple roles.

To port this harness to a different model/agent provider (OpenAI's
Codex CLI, a raw API call to any model, a different agent framework
entirely), you only need to adapt the `invoke_role` function in
`coordinator.sh` — replace the `claude -p ...` invocation with your
provider's equivalent non-interactive, single-shot invocation, keeping
the same contract:
- Takes the role's instructions (`roles/<name>.md`), the current
  `spec.md`, and this invocation's context (task or feedback) as input.
- Runs as its own separate process/session, scoped to the deliverable
  directory, with no access to the other role's live context.
- Produces output the coordinator can capture (stdout is fine) and, for
  the Evaluator specifically, a `verdict.md` conforming to
  `schemas/verdict.md` that the coordinator can parse for
  `overall: PASS|FAIL`.

Nothing else in the harness (bootstrap.sh, the schemas, the role files,
the spec) is Claude-specific or Hermes-specific.

## Escalation channel

`coordinator.sh` writes every escalation to
`team/<team-name>/escalation/` in Fulcra Workspaces — durable, and
readable by anyone with access to that workspace regardless of which
channel (Discord, a cron report, a different agent entirely) is checking
in. If the invoking session has a live interactive channel available
(e.g. a Discord thread), it should also surface the escalation there as
a convenience, but the workspace log is the canonical, channel-agnostic
record — treat it as the thing to check if you're picking this project
up cold.
