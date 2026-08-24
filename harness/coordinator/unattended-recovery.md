# Unattended Recovery Protocol

Use this when an unattended Coordinator/verifier finds a blocked,
interrupted, or unhealthy run. This is a **state-recovery** protocol, not
permission to make deliverable code fixes outside Generator.

## Non-negotiable boundaries

- Never edit `spec.md` or `decisions.md` without an explicit user decision.
- Never edit deliverable source/tests/docs to make a verdict pass. Only a
  Generator run on the current milestone branch may create deliverable
  code/content changes.
- Never discard deliverable work. Before any reset/checkout that could
  remove it, preserve it with a named `git stash -u` and record the exact
  stash reference in Fulcra Workspace under `team/<team>/handoff/`.

## Recovery decision tree

1. **Read evidence first:** `status-summary.md`, `milestone-progress.md`,
   latest escalation, coordinator run history, deliverable `git status`,
   `git branch --show-current`, and `git stash list`.
2. **Known ephemeral runtime artifacts only:** remove only documented test
   caches (`__pycache__/`, `.pyc`, optionally an explicitly documented
   `.pytest_cache/`). Never use broad `git clean`.
3. **Meaningful dirty work on the exact current milestone branch:** do not
   stash/reset it. Leave it in place and invoke Coordinator so Generator
   can inspect, test, commit, and push it. This is the normal recovery
   route for an interrupted Generator.
4. **Meaningful dirty work on another branch or detached state:** run a
   named `git stash push -u -m "coordinator-preserve-..."`; write the
   stash ref/reason to workspace handoff; then reset/check out the current
   milestone branch from its tracked remote/base. This is state repair,
   not a code change.
5. **Stale local branch/worktree or merge residue after a completed PR:**
   after preservation above, fetch origin, check out the milestone branch
   if it exists or recreate it from current `main`, and verify a clean
   worktree. Never force-push or rewrite remote history.
6. **Stale workspace escalation:** only clear/supersede a latest-escalation
   pointer when the blocking precondition has actually been repaired and
   a clean Coordinator preflight succeeds. Keep the historic escalation
   file for audit.
7. **Prove recovery:** run `doctor.sh`, then exactly one Coordinator
   invocation. Confirm it gets past preflight and records a new durable
   status. If it still blocks, preserve the new evidence and escalate;
   do not loop blindly.

## Reporting

Every recovery must report:
- what was found;
- whether source work was resumed or stashed (including stash ref);
- branch/reset operations performed;
- the Coordinator proof result;
- any remaining escalation and exact next action.
