#!/usr/bin/env bash
# coordinator.sh <team-name> [--max-loops N]
#
# Drives the Generator <-> Evaluator loop for one harness run, using
# real separate `claude -p` subprocess invocations per role (spec #34 --
# roles must be genuinely separate sessions, not persona-switching), and
# raw fulcra-workspaces inbox files (v1 -- no fulcra-agent-coordination
# engine yet).
#
# Each iteration ("run_id"):
#   1. Message the Generator's inbox with a task (run 1) or feedback
#      (retry, referencing the prior verdict).
#   2. Invoke the Generator as its own claude subprocess, working in the
#      DELIVERABLE_DIR (a separate git repo/clone from this harness).
#      Generator commits + pushes its own changes there.
#   3. Message the Evaluator's inbox pointing at the artifact + spec.
#   4. Invoke the Evaluator as its own claude subprocess, reading the
#      deliverable repo. Evaluator writes verdict.md (schemas/verdict.md
#      format) into the workspace's artifact/ area.
#   5. Parse the verdict's overall PASS/FAIL. On PASS, halt successfully.
#      On FAIL, loop back to the Generator with feedback, incrementing
#      run_id, until coordinator/policy.md's retry bound is hit --
#      then escalate and halt.
#
# This script coordinates ONLY. It does not itself generate or evaluate
# anything -- that's each role's own subprocess's job, driven by its
# roles/<name>.md instructions plus spec.md.
set -euo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEAM_NAME="${1:?Usage: coordinator.sh <team-name> [--deliverable-dir DIR] [--max-loops N]}"
shift
TEAM_PREFIX="team/${TEAM_NAME}"

DELIVERABLE_DIR="${DELIVERABLE_DIR:-$HOME/game-night}"
MAX_LOOPS=999   # coordinator/policy.md's retry bound is the real cap; this is just a runaway guard
while [ "$#" -gt 0 ]; do
  case "$1" in
    --deliverable-dir) DELIVERABLE_DIR="$2"; shift 2 ;;
    --max-loops) MAX_LOOPS="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

FULCRA_BIN="$(command -v uvx || true)"
if [ -z "$FULCRA_BIN" ]; then echo "ERROR: uvx not found" >&2; exit 1; fi
run_fulcra() { "$FULCRA_BIN" fulcra-api "$@"; }

CLAUDE_BIN="$(command -v claude || true)"
if [ -z "$CLAUDE_BIN" ]; then echo "ERROR: claude not found" >&2; exit 1; fi

# --- Read retry bound from coordinator/policy.md (best-effort parse; the
#     canonical value is the "**N**" on the "Maximum retries" line) -----
RETRY_BOUND="$(grep -oE '\*\*[0-9]+\*\*' "$HARNESS_DIR/coordinator/policy.md" | head -1 | tr -d '*')"
RETRY_BOUND="${RETRY_BOUND:-3}"

# --- Read model assignment from the deliverable's config.json -----------
GEN_MODEL="opus"
EVAL_MODEL="sonnet"
if [ -f "$DELIVERABLE_DIR/config.json" ]; then
  GEN_MODEL="$(python3 -c "import json; print(json.load(open('$DELIVERABLE_DIR/config.json'))['roles']['generator_model'])" 2>/dev/null || echo opus)"
  EVAL_MODEL="$(python3 -c "import json; print(json.load(open('$DELIVERABLE_DIR/config.json'))['roles']['evaluator_model'])" 2>/dev/null || echo sonnet)"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }

write_inbox_message() {
  # write_inbox_message <role> <run_id> <type> <body-file>
  local role="$1" run_id="$2" type="$3" body_file="$4"
  local ts fname
  ts="$(date -u +%Y%m%d-%H%M%S)"
  fname="${ts}_coordinator_run${run_id}-${type}.md"
  {
    echo "type: ${type}"
    echo "from: coordinator"
    echo "to: ${role}"
    echo "run_id: ${run_id}"
    echo "timestamp: $(now_iso)"
    echo "spec_ref: $(git -C "$HARNESS_DIR" rev-parse HEAD 2>/dev/null || echo unknown)"
    echo "body: |"
    sed 's/^/  /' "$body_file"
  } > "$TMP/${fname}"
  run_fulcra file upload "$TMP/${fname}" "${TEAM_PREFIX}/member/${role}/inbox/${fname}"
  echo "$fname"
}

invoke_role() {
  # invoke_role <role> <model> <run_id> <extra-context-file>
  local role="$1" model="$2" run_id="$3" context_file="$4"
  local role_instructions="$HARNESS_DIR/roles/${role}.md"
  local spec_file="$HARNESS_DIR/spec.md"
  local out_file="$TMP/${role}-run${run_id}-output.md"

  echo "  -- invoking ${role} (model: ${model}, run ${run_id})" >&2

  # Genuinely separate subprocess/session per spec #34 -- not a persona
  # switch within this coordinator's own context.
  (
    cd "$DELIVERABLE_DIR"
    "$CLAUDE_BIN" -p \
      --model "$model" \
      --add-dir "$DELIVERABLE_DIR" \
      --append-system-prompt "You are the ${role} role for the Game Night v1 harness run. Follow your role instructions and spec exactly. Work only inside $DELIVERABLE_DIR (the deliverable repo, separate from the harness repo). Commit and push your own changes to this repo's git remote when you're done, with a clear commit message. Do not modify the harness repo." \
      "$(cat <<PROMPT
Your role instructions (roles/${role}.md):
---
$(cat "$role_instructions")
---

The current spec (spec.md), immutable for this run:
---
$(cat "$spec_file")
---

Context for this specific invocation (run ${run_id}):
---
$(cat "$context_file")
---

Do your work now inside $DELIVERABLE_DIR. When done, report a concise summary of what you did/found.
PROMPT
)"
  ) > "$out_file" 2>&1 || {
    echo "ERROR: ${role} subprocess failed on run ${run_id}" >&2
    cat "$out_file" >&2
    return 1
  }

  cat "$out_file"
}

escalate() {
  local reason="$1" run_id="$2"
  local ts fname
  ts="$(date -u +%Y%m%d-%H%M%S)"
  fname="${ts}_escalation-run${run_id}.md"
  {
    echo "---"
    echo "type: Escalation"
    echo "title: Escalation - run ${run_id}"
    echo "---"
    echo
    echo "## Escalation"
    echo "- **Run:** ${run_id}"
    echo "- **Time:** $(now_iso)"
    echo "- **Reason:** ${reason}"
    echo "- **Spec ref:** ${CURRENT_SPEC_REF}"
    echo "- **Status:** open"
  } > "$TMP/${fname}"
  run_fulcra file upload "$TMP/${fname}" "${TEAM_PREFIX}/escalation/${fname}"
  # Also write/refresh a stable "latest open escalation" pointer so an
  # unattended (cron) invocation can cheaply check "is there already an
  # open escalation for the current spec?" without listing the whole
  # escalation/ directory.
  {
    echo "spec_ref: ${CURRENT_SPEC_REF}"
    echo "escalation_file: ${fname}"
    echo "reason: ${reason}"
    echo "timestamp: $(now_iso)"
  } > "$TMP/latest-escalation.md"
  run_fulcra file upload "$TMP/latest-escalation.md" "${TEAM_PREFIX}/escalation/.latest.md"
  echo "== ESCALATION (run ${run_id}): ${reason} ==" >&2
  echo "Logged durably to ${TEAM_PREFIX}/escalation/${fname}" >&2
}

echo "== Coordinator starting for team/${TEAM_NAME} (retry bound: ${RETRY_BOUND}) =="

CURRENT_SPEC_REF="$(git -C "$HARNESS_DIR" rev-parse HEAD 2>/dev/null || echo unknown)"

# --- Do-nothing short-circuit: if this exact spec version already has a
#     recorded PASS, there's nothing new to converge on. This matters most
#     for unattended/cron invocations, which would otherwise burn a real
#     Generator+Evaluator subprocess call every tick even after success. ---
CONVERGED_MARKER="$TMP/converged-check.md"
if run_fulcra file download "${TEAM_PREFIX}/converged.md" "$CONVERGED_MARKER" >/dev/null 2>&1; then
  converged_spec_ref="$(grep -oE '^spec_ref:\s*\S+' "$CONVERGED_MARKER" | awk '{print $2}' || true)"
  if [ -n "$converged_spec_ref" ] && [ "$converged_spec_ref" = "$CURRENT_SPEC_REF" ]; then
    echo "== Already converged for spec_ref ${CURRENT_SPEC_REF} -- nothing new to do. Skipping run. =="
    echo "(To force a re-run, update spec.md and commit the harness, or delete ${TEAM_PREFIX}/converged.md.)"
    exit 0
  fi
fi

# --- Do-nothing short-circuit #2: if there's already an open escalation
#     for the current spec version, don't silently re-attempt retries on
#     an unattended tick -- that would burn tokens re-discovering the
#     same blocker instead of waiting for the user to resolve it. A human
#     (or an explicit re-run after resolving the blocker) can still force
#     progress by deleting/resolving the .latest.md pointer, or by
#     revising spec.md (which changes CURRENT_SPEC_REF and naturally
#     un-blocks this check). ---
LATEST_ESCALATION_MARKER="$TMP/latest-escalation-check.md"
if run_fulcra file download "${TEAM_PREFIX}/escalation/.latest.md" "$LATEST_ESCALATION_MARKER" >/dev/null 2>&1; then
  open_spec_ref="$(grep -oE '^spec_ref:\s*\S+' "$LATEST_ESCALATION_MARKER" | awk '{print $2}' || true)"
  if [ -n "$open_spec_ref" ] && [ "$open_spec_ref" = "$CURRENT_SPEC_REF" ]; then
    echo "== There is already an open escalation for spec_ref ${CURRENT_SPEC_REF}. Not re-attempting automatically. =="
    echo "See ${TEAM_PREFIX}/escalation/.latest.md for details. Resolve it, or revise spec.md, before the next run."
    exit 1
  fi
fi

run_id=1
prior_verdict_summary="(none -- this is run 1, no prior feedback)"

while [ "$run_id" -le "$MAX_LOOPS" ]; do
  echo "=== Run ${run_id} ===" >&2

  # --- Generator step ---
  {
    echo "This is run ${run_id}."
    echo
    echo "Prior verdict / feedback:"
    echo "${prior_verdict_summary}"
  } > "$TMP/gen-context-${run_id}.md"

  gen_msg_file="$(write_inbox_message generator "$run_id" task "$TMP/gen-context-${run_id}.md")"
  gen_output="$(invoke_role generator "$GEN_MODEL" "$run_id" "$TMP/gen-context-${run_id}.md")"
  echo "$gen_output" > "$TMP/gen-output-${run_id}.md"
  run_fulcra file upload "$TMP/gen-output-${run_id}.md" "${TEAM_PREFIX}/member/generator/archive/run${run_id}-output.md" || true

  # --- Evaluator step ---
  {
    echo "This is run ${run_id}."
    echo
    echo "Generator's own summary of what it did this run:"
    echo "${gen_output}"
  } > "$TMP/eval-context-${run_id}.md"

  eval_msg_file="$(write_inbox_message evaluator "$run_id" task "$TMP/eval-context-${run_id}.md")"
  eval_output="$(invoke_role evaluator "$EVAL_MODEL" "$run_id" "$TMP/eval-context-${run_id}.md")"
  echo "$eval_output" > "$TMP/verdict-run${run_id}.md"
  run_fulcra file upload "$TMP/verdict-run${run_id}.md" "${TEAM_PREFIX}/artifact/verdict-run${run_id}.md"

  # --- Parse verdict overall (best-effort grep on the verdict schema's
  #     `overall: PASS|FAIL` line; if absent/ambiguous, treat as
  #     untestable -> escalate) ---
  overall="$(grep -oE 'overall:\s*(PASS|FAIL)' "$TMP/verdict-run${run_id}.md" | head -1 | awk '{print $2}' || true)"

  if [ "$overall" = "PASS" ]; then
    echo "== Run ${run_id}: PASS -- halting successfully ==" >&2
    run_fulcra file upload "$TMP/verdict-run${run_id}.md" "${TEAM_PREFIX}/progress.md" 2>/dev/null || true
    {
      echo "spec_ref: ${CURRENT_SPEC_REF}"
      echo "run_id: ${run_id}"
      echo "timestamp: $(now_iso)"
    } > "$TMP/converged.md"
    run_fulcra file upload "$TMP/converged.md" "${TEAM_PREFIX}/converged.md"
    exit 0
  elif [ "$overall" = "FAIL" ]; then
    echo "== Run ${run_id}: FAIL -- looping =="
    prior_verdict_summary="$(cat "$TMP/verdict-run${run_id}.md")"
    if [ "$run_id" -ge "$RETRY_BOUND" ]; then
      escalate "Retry bound (${RETRY_BOUND}) exceeded without a passing verdict." "$run_id"
      exit 1
    fi
    run_id=$((run_id + 1))
  else
    escalate "Evaluator verdict for run ${run_id} did not contain a parseable overall: PASS|FAIL line -- treating as untestable." "$run_id"
    exit 1
  fi
done

escalate "Runaway guard hit (${MAX_LOOPS} loops) without resolving -- this should not happen if retry bound parsing is correct." "$run_id"
exit 1
