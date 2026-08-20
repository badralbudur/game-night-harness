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
repro (`claude -p --model sonnet --add-dir <dir> --permission-mode
acceptEdits "write a file..."`) before applying to the coordinator.

**Value of separate-subagent evaluation (spec #34) demonstrated here:**
the Evaluator, running as a genuinely independent session rather than a
persona-switch, hit the *identical* blocker and reported it
independently rather than trusting the Generator's self-report — this is
exactly the kind of corroboration that would be impossible to get
credibly from one session pretending to be two roles. Worth citing this
finding in the PR #20 backport as evidence for why spec #34 (real
subagents, not personas) matters in practice, not just in theory.

## Finding 2: image-generation modality is genuinely ambiguous in spec.md (OPEN)

**Discovered:** run 1, flagged independently by both Generator and
Evaluator as a real spec gap, not an environment issue.

Spec #29/#32 require "a generated image" per newspaper edition and per
city, but never specify the modality. The Generator's sandbox has no
raster image-generation endpoint configured/reachable. Needs a decision:
does a deterministic, game-state-informed procedural or LLM-authored SVG
satisfy "generated image," or must an external raster image API be
provisioned (and if so, which)?

**Action needed:** user decision, then update `spec.md` accordingly
(this is exactly the kind of ambiguity the escalation path exists to
surface rather than let either role guess).

## Finding 3: two-slot check-in on a fully idle round — spec read confirmed unambiguous (RESOLVED, no spec change needed)

**Discovered:** run 1. The Generator flagged spec #23 (the two-slot
per-round check-in) as possibly ambiguous for the case where a player
has *zero* pending game actions in a round. The Evaluator, working
independently, read the same spec text and concluded it is NOT
ambiguous: slot (a) is simply unfilled when no game action is pending;
slot (b) fires whenever a second game action isn't pending (covering
both the zero-pending and one-pending cases) — so an idle round yields
exactly one question, never two, never zero.

**Resolution:** Evaluator's reading is correct per the literal spec text;
no spec change needed. Noting here so a future Generator retry doesn't
re-raise the same non-issue.
