# Harness Process Findings (v1)

Real findings surfaced by actually running the harness, not anticipated
in advance. Append new findings here as they're discovered; do not
retroactively edit past entries except to mark them resolved.

## Finding 1: `claude -p` needs explicit `--permission-mode`, not just a system-prompt instruction (RESOLVED)

**Discovered:** run 1, both Generator and Evaluator roles independently
hit an identical write-permission block despite `--add-dir
<deliverable-dir>` pointing at the correct directory and the system
prompt explicitly telling the agent it's allowed to write there.

**Root cause:** `--add-dir` grants tool-access scope, but the actual
permission gate (Write/Edit/Bash approval) is separate and defaults to a
mode that can't be satisfied non-interactively (`-p` mode has no TTY to
approve prompts). Telling the agent in prose that it's allowed to write
does not change the enforcement layer's behavior.

**Fix:** add `--permission-mode acceptEdits` to the `claude -p`
invocation in `coordinator.sh`'s `invoke_role()`. Verified with a minimal
repro before applying.

**Value of separate-subagent evaluation (spec #34) demonstrated here:**
the Evaluator, running as a genuinely independent session rather than a
persona-switch, hit the *identical* blocker and reported it
independently rather than trusting the Generator's self-report.

## Finding 2: image-generation modality was ambiguous in spec.md (RESOLVED by user decision 2026-08-24)

**Discovered:** run 1, flagged independently by both Generator and
Evaluator as a real spec gap, not an environment issue.

**Resolution:** fun, colorful raster image generation is preferred. If no
raster image-generation provider is available, a deterministic,
game-state-informed SVG/procedural illustration is an explicitly allowed
fallback. The fallback is not a failure; it must still be materially
informed by the edition/city state and meet the tone bar. The decision is
recorded in `decisions.md`, reflected in spec #29/#32, and M5's milestone
now requires the deliverable to record the actual modality/provider used.

**Process lesson:** this question should have become a durable structured
decision request at discovery rather than living only in role prose. The
new `schemas/decision-request.md` and Coordinator decision queue address
that for future questions.

## Finding 3: two-slot check-in on a fully idle round — spec read confirmed unambiguous (RESOLVED)

**Discovered:** run 1. The Generator flagged spec #23 as possibly
ambiguous for the case where a player has zero pending game actions. The
Evaluator independently concluded it is not ambiguous: slot (a) is empty;
slot (b) supplies exactly one question. No spec change needed.

## Finding 4: a PASS without executable deterministic tests is provisional, not merge-worthy (OPEN — corrective M2 required)

**Discovered:** M2 initially received an Evaluator PASS based on rigorous
static/manual tracing because the Evaluator session was blocked from
executing `python3 run_tests.py`. After the role permission contract was
fixed, the declared suite was run directly against the merged M2 artifact:
**139 tests ran, 138 passed, 1 errored**.

The failing test is
`tests/test_checkin_slots.py::SlotAllocationTest::test_slots_report_the_one_shared_round_deadline`:
a check-in slot lacks the expected `deadline` field (`KeyError:
'deadline'`). This is an actual M2 artifact defect that static tracing
missed.

**Process fixes:**
1. Generator and Evaluator receive narrow permission to execute the
   deliverable's declared test runner (`python3 run_tests.py`) and
   standard-library unittest only.
2. Evaluator instructions now require executable deterministic evidence;
   manual tracing may supplement, never replace, executed tests.
3. A milestone may not merge on a PASS whose deterministic in-scope tests
   could not run. Such a verdict must be `FAIL`/escalation until test
   execution is available.
4. M2 is reopened as a corrective milestone; workspace progress must not
   advance to M3 until the real suite passes in a separate Evaluator
   session.

## Finding 5: corrective deliverable work must remain role-owned and committed before a scheduled resumption (OPEN — M2 handoff required)

**Discovered:** unattended coordinator invocation 2026-08-22T02:35Z.
The M2 corrective branch contained tracked, uncommitted changes to
`engine/game.py` and `docs/m2-engine.md`; the source change adds the missing
question-slot shared-round `deadline` and the local declared suite then ran
**139 tests, all passing**. The correction is not in `origin/main` and the
worktree also retained a stash labelled an interrupted corrective Generator
attempt.

**Observed coordinator behavior:** the pre-branch dirty-tree guard removed
only Python bytecode caches and escalated rather than switching/resetting the
deliverable. That preservation is correct: an unattended coordinator must
never auto-clean tracked source changes to make a verdict or branch setup
appear clear.

**Required handoff:** the Generator must resume the M2 corrective milestone,
review the existing diff, commit and push it on the milestone branch, and let
a separate Evaluator grade that committed state. The Harness Maintainer must
not commit or otherwise patch the deliverable to clear this escalation.

## Finding 6: a terminal scheduled outcome needs a non-silent origin report (RESOLVED)

**Discovered:** scheduler-owned execution `8cf571ba4c54461db4d5615ae136fad6`
completed at 2026-08-22T20:49:04Z. Its workspace status checkpoint and the
dashboard data both refreshed at 2026-08-22T20:48:14Z, but the job's own
persisted response was `[SILENT]`. The Hermes ledger showed no delivery error,
but `[SILENT]` intentionally suppresses the origin message, so that is not
independent delivery evidence for this terminal coordinator outcome.

**Fix:** the weekend coordinator cron prompt now explicitly requires a concise,
non-silent origin report after every terminal coordinator invocation, including
a correctly blocked short-circuit. It may use `[SILENT]` only when no
coordinator invocation occurred. Durable workspace and dashboard state remain
the source of truth; the report is an independently observable notification.
