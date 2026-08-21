#!/usr/bin/env bash
# coordinator.sh <team-name> [--deliverable-dir DIR] [--max-loops N]
#
# Drives ONE milestone's worth of Generator <-> Evaluator loop per
# invocation, using real separate `claude -p` subprocess invocations per
# role (spec #34), and raw fulcra-workspaces inbox files (v1 -- no
# fulcra-agent-coordination engine yet).
#
# Milestone scoping (see coordinator/milestones.md): a single run
# attempting the full spec is too large a unit of work to reliably
# complete or evaluate in one pass (confirmed empirically -- run 1 hit a
# provider usage limit mid-build on a full-spec attempt). Each
# invocation of this script targets exactly one milestone from
# milestones.md; the Generator still reads the full spec.md (to avoid
# violating later-milestone invariants) but its concrete task is scoped
# to the current milestone. Milestone progress persists in the
# workspace (team/<team>/milestone-progress.md), not in this script or
# the harness repo, so repeated invocations naturally advance through
# the milestone list over time (e.g. one per cron tick).
#
# Per-invocation flow:
#   1. Determine the current milestone (workspace progress marker, or
#      milestone 1 if none recorded yet).
#   2. Do-nothing short-circuits: already fully converged (all
#      milestones done for the current spec_ref), or an open escalation
#      already exists for the current spec_ref + milestone.
#   3. Message + invoke the Generator (own subprocess), scoped to the
#      current milestone, with the full spec for context.
#   4. Message + invoke the Evaluator (own subprocess), grading the
#      current milestone's criteria plus a regression check against
#      previously-completed milestones.
#   5. On PASS: mark the milestone complete, advance the pointer (or
#      mark the whole project converged if this was the last milestone),
#      exit 0. On FAIL: retry the SAME milestone (bounded by
#      coordinator/policy.md's retry bound), then escalate. On a hard
#      subprocess failure (crash, usage limit, timeout): retry once,
#      then escalate -- this path previously fell through to a bare
#      script exit with no durable escalation record; fixed here.
#
# This script coordinates ONLY. It does not itself generate or evaluate
# anything -- that's each role's own subprocess's job.
set -uo pipefail  # NOTE: no -e. Failures are handled explicitly so every
                   # failure path can reach escalate() before exiting.

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

RETRY_BOUND="$(grep -oE '\*\*[0-9]+\*\*' "$HARNESS_DIR/coordinator/policy.md" | head -1 | tr -d '*')"
RETRY_BOUND="${RETRY_BOUND:-3}"
# Explicit policy switch: automatic retrying is useful for later
# unattended/cron mode, but is OFF during the current interactive Discord
# run. Never infer this from where the script happened to be launched.
AUTO_RETRIES_ENABLED="$(grep -iE 'Automatic retries enabled:' "$HARNESS_DIR/coordinator/policy.md" | head -1 | grep -oiE '\*\*(true|false)\*\*' | tr -d '*' | tr '[:upper:]' '[:lower:]')"
AUTO_RETRIES_ENABLED="${AUTO_RETRIES_ENABLED:-false}"

GEN_MODEL="opus"
EVAL_MODEL="sonnet"
if [ -f "$DELIVERABLE_DIR/config.json" ]; then
  GEN_MODEL="$(python3 -c "import json; print(json.load(open('$DELIVERABLE_DIR/config.json'))['roles']['generator_model'])" 2>/dev/null || echo opus)"
  EVAL_MODEL="$(python3 -c "import json; print(json.load(open('$DELIVERABLE_DIR/config.json'))['roles']['evaluator_model'])" 2>/dev/null || echo sonnet)"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# --- Parse milestones.md into an ordered array of "ID|Title" -----------
MILESTONES_FILE="$HARNESS_DIR/coordinator/milestones.md"
if [ ! -f "$MILESTONES_FILE" ]; then
  echo "ERROR: coordinator/milestones.md not found -- harness cannot scope a run without it." >&2
  exit 1
fi
mapfile -t MILESTONE_LINES < <(grep -oE '^## M[0-9]+: .+' "$MILESTONES_FILE")
MILESTONE_IDS=()
MILESTONE_TITLES=()
for line in "${MILESTONE_LINES[@]}"; do
  id="$(echo "$line" | sed -E 's/^## (M[0-9]+): .*/\1/')"
  title="$(echo "$line" | sed -E 's/^## M[0-9]+: (.*)/\1/')"
  MILESTONE_IDS+=("$id")
  MILESTONE_TITLES+=("$title")
done
if [ "${#MILESTONE_IDS[@]}" -eq 0 ]; then
  echo "ERROR: no milestones parsed from milestones.md (expected '## M<n>: <title>' headers)." >&2
  exit 1
fi

milestone_section() {
  # Extract the full markdown section for a milestone id (## M<n>: ... up
  # to the next ## heading or end of file).
  awk -v id="^## ${1}:" 'BEGIN{p=0} $0 ~ id {p=1} p && /^## M[0-9]+:/ && $0 !~ id {exit} p {print}' "$MILESTONES_FILE"
}

write_inbox_message() {
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
    echo "spec_ref: ${CURRENT_SPEC_REF:-unknown}"
    echo "body: |"
    sed 's/^/  /' "$body_file"
  } > "$TMP/${fname}"
  run_fulcra file upload "$TMP/${fname}" "${TEAM_PREFIX}/member/${role}/inbox/${fname}" >&2
  echo "$fname"
}

# invoke_role_once <role> <model> <run_id> <context_file>
# Prints the subprocess's stdout on success. Returns non-zero (prints
# nothing meaningful) on failure -- caller decides retry/escalate.
invoke_role_once() {
  local role="$1" model="$2" run_id="$3" context_file="$4"
  local role_instructions="$HARNESS_DIR/roles/${role}.md"
  local spec_file="$HARNESS_DIR/spec.md"
  local out_file="$TMP/${role}-run${run_id}-attempt-output.md"

  (
    cd "$DELIVERABLE_DIR"
    "$CLAUDE_BIN" -p \
      --model "$model" \
      --add-dir "$DELIVERABLE_DIR" \
      --permission-mode acceptEdits \
      --append-system-prompt "You are the ${role} role for the Game Night v1 harness run, working on ONE milestone at a time (see coordinator/milestones.md philosophy below). Follow your role instructions and spec exactly, but restrict your actual work this run to the current milestone's scope -- do not attempt other milestones' work even if you see how to. Work only inside $DELIVERABLE_DIR (the deliverable repo, separate from the harness repo). Do not modify the harness repo. The Coordinator, not you, owns the deterministic git add/commit/push handoff after a successful Generator run; do not try to run git write commands yourself." \
      "$(cat <<PROMPT
Your role instructions (roles/${role}.md):
---
$(cat "$role_instructions")
---

The current FULL spec (spec.md), immutable for this run -- read this for
context and to avoid violating any invariant, even ones outside your
current milestone:
---
$(cat "$spec_file")
---

Context for this specific invocation (run ${run_id}), including which
milestone you are scoped to:
---
$(cat "$context_file")
---

Do your work now inside $DELIVERABLE_DIR, scoped ONLY to the current
milestone described above. When done, report a concise summary of what
you did/found.
PROMPT
)"
  ) > "$out_file" 2>&1
  local rc=$?
  cat "$out_file"
  return "$rc"
}

# invoke_role <role> <model> <run_id> <context_file> <milestone_id>
# Wraps invoke_role_once with one retry on hard failure, escalating
# durably (not just erroring silently) if the retry also fails. Prints
# the successful output on stdout; returns non-zero only after both
# attempts failed AND an escalation has been logged.
invoke_role() {
  local role="$1" model="$2" run_id="$3" context_file="$4" milestone_id="$5"
  local output

  echo "  -- invoking ${role} (model: ${model}, run ${run_id}, milestone ${milestone_id}) [attempt 1]" >&2
  if output="$(invoke_role_once "$role" "$model" "$run_id" "$context_file")"; then
    echo "$output"
    return 0
  fi
  echo "  !! ${role} subprocess failed on attempt 1" >&2
  echo "$output" >&2
  if [ "$AUTO_RETRIES_ENABLED" != "true" ]; then
    escalate "${role} subprocess failed for milestone ${milestone_id}, run ${run_id}. Automatic retries are disabled by coordinator/policy.md. Output: $(echo "$output" | tail -20 | tr '\n' ' ')" "$run_id" "$milestone_id"
    return 1
  fi
  echo "  -- automatic retries enabled; retrying ${role} once" >&2

  echo "  -- invoking ${role} (model: ${model}, run ${run_id}, milestone ${milestone_id}) [attempt 2 of 2]" >&2
  if output="$(invoke_role_once "$role" "$model" "$run_id" "$context_file")"; then
    echo "$output"
    return 0
  fi
  echo "  !! ${role} subprocess failed on attempt 2 -- escalating" >&2
  escalate "${role} subprocess failed twice in a row for milestone ${milestone_id}, run ${run_id}. Last output: $(echo "$output" | tail -20 | tr '\n' ' ')" "$run_id" "$milestone_id"
  return 1
}

# coordinator_commit_deliverable <milestone_id> <attempt> <generator-summary>
#
# The coordinator owns this deliberately narrow mechanical handoff instead
# of asking a non-interactive Generator subagent to execute git writes.
# This preserves role separation while ensuring requirement #35 (a
# deliverable commit per run/milestone attempt) is reliably enforceable.
coordinator_commit_deliverable() {
  local milestone_id="$1" attempt="$2" generator_summary="$3"
  local summary_line
  summary_line="$(printf '%s\n' "$generator_summary" | grep -v '^$' | head -1 | cut -c1-160)"
  summary_line="${summary_line:-Generator artifact handoff}"

  if [ -z "$(git -C "$DELIVERABLE_DIR" status --porcelain)" ]; then
    echo "  -- Coordinator git handoff: working tree clean; no commit needed" >&2
    return 0
  fi

  echo "  -- Coordinator git handoff: committing deliverable changes for ${milestone_id}, attempt ${attempt}" >&2
  if ! git -C "$DELIVERABLE_DIR" add -A; then
    escalate "Coordinator failed to stage deliverable changes for milestone ${milestone_id}, attempt ${attempt}." "$attempt" "$milestone_id"
    return 1
  fi
  if ! git -C "$DELIVERABLE_DIR" commit -m "feat(${milestone_id,,}): generator artifact handoff (attempt ${attempt})" -m "$summary_line"; then
    escalate "Coordinator failed to commit staged deliverable changes for milestone ${milestone_id}, attempt ${attempt}." "$attempt" "$milestone_id"
    return 1
  fi
  if ! git -C "$DELIVERABLE_DIR" push origin HEAD; then
    escalate "Coordinator committed but failed to push deliverable changes for milestone ${milestone_id}, attempt ${attempt}." "$attempt" "$milestone_id"
    return 1
  fi
  return 0
}

escalate() {
  local reason="$1" run_id="$2" milestone_id="${3:-unknown}"
  local ts fname
  ts="$(date -u +%Y%m%d-%H%M%S)"
  fname="${ts}_escalation-${milestone_id}-run${run_id}.md"
  {
    echo "---"
    echo "type: Escalation"
    echo "title: Escalation - ${milestone_id} run ${run_id}"
    echo "---"
    echo
    echo "## Escalation"
    echo "- **Milestone:** ${milestone_id}"
    echo "- **Run:** ${run_id}"
    echo "- **Time:** $(now_iso)"
    echo "- **Reason:** ${reason}"
    echo "- **Spec ref:** ${CURRENT_SPEC_REF:-unknown}"
    echo "- **Status:** open"
  } > "$TMP/${fname}"
  run_fulcra file upload "$TMP/${fname}" "${TEAM_PREFIX}/escalation/${fname}"
  {
    echo "spec_ref: ${CURRENT_SPEC_REF:-unknown}"
    echo "milestone_id: ${milestone_id}"
    echo "escalation_file: ${fname}"
    echo "reason: ${reason}"
    echo "timestamp: $(now_iso)"
  } > "$TMP/latest-escalation.md"
  run_fulcra file upload "$TMP/latest-escalation.md" "${TEAM_PREFIX}/escalation/.latest.md"
  echo "== ESCALATION (milestone ${milestone_id}, run ${run_id}): ${reason} ==" >&2
  echo "Logged durably to ${TEAM_PREFIX}/escalation/${fname}" >&2
}

CURRENT_SPEC_REF="$(git -C "$HARNESS_DIR" rev-parse HEAD 2>/dev/null || echo unknown)"

echo "== Coordinator starting for team/${TEAM_NAME} (retry bound: ${RETRY_BOUND}, auto retries: ${AUTO_RETRIES_ENABLED}, milestones: ${#MILESTONE_IDS[@]}) =="

# --- Do-nothing short-circuit #1: fully converged (all milestones done
#     for the current spec_ref) ---
CONVERGED_MARKER="$TMP/converged-check.md"
if run_fulcra file download "${TEAM_PREFIX}/converged.md" "$CONVERGED_MARKER" >/dev/null 2>&1; then
  converged_spec_ref="$(grep -oE '^spec_ref:\s*\S+' "$CONVERGED_MARKER" | awk '{print $2}' || true)"
  if [ -n "$converged_spec_ref" ] && [ "$converged_spec_ref" = "$CURRENT_SPEC_REF" ]; then
    echo "== Already converged (all milestones complete) for spec_ref ${CURRENT_SPEC_REF} -- nothing new to do. =="
    echo "(To force more work, revise spec.md/milestones.md, or delete ${TEAM_PREFIX}/converged.md.)"
    exit 0
  fi
fi

# --- Determine current milestone from workspace progress marker -------
PROGRESS_MARKER="$TMP/milestone-progress.md"
CURRENT_MILESTONE_INDEX=0
COMPLETED_MILESTONES=""
if run_fulcra file download "${TEAM_PREFIX}/milestone-progress.md" "$PROGRESS_MARKER" >/dev/null 2>&1; then
  current_id="$(grep -oE '^current:\s*\S+' "$PROGRESS_MARKER" | awk '{print $2}' || true)"
  COMPLETED_MILESTONES="$(grep -oE '^completed:\s*.*' "$PROGRESS_MARKER" | cut -d: -f2- | xargs || true)"
  for i in "${!MILESTONE_IDS[@]}"; do
    if [ "${MILESTONE_IDS[$i]}" = "$current_id" ]; then
      CURRENT_MILESTONE_INDEX=$i
      break
    fi
  done
fi
CURRENT_MILESTONE_ID="${MILESTONE_IDS[$CURRENT_MILESTONE_INDEX]}"
CURRENT_MILESTONE_TITLE="${MILESTONE_TITLES[$CURRENT_MILESTONE_INDEX]}"

echo "== Current milestone: ${CURRENT_MILESTONE_ID} (${CURRENT_MILESTONE_TITLE}) [${CURRENT_MILESTONE_INDEX}/${#MILESTONE_IDS[@]}] =="
echo "== Previously completed: ${COMPLETED_MILESTONES:-none} =="

# --- Do-nothing short-circuit #2: open escalation for THIS spec_ref AND
#     THIS milestone (a milestone advance or spec revision naturally
#     lifts this) ---
LATEST_ESCALATION_MARKER="$TMP/latest-escalation-check.md"
if run_fulcra file download "${TEAM_PREFIX}/escalation/.latest.md" "$LATEST_ESCALATION_MARKER" >/dev/null 2>&1; then
  open_spec_ref="$(grep -oE '^spec_ref:\s*\S+' "$LATEST_ESCALATION_MARKER" | awk '{print $2}' || true)"
  open_milestone="$(grep -oE '^milestone_id:\s*\S+' "$LATEST_ESCALATION_MARKER" | awk '{print $2}' || true)"
  if [ -n "$open_spec_ref" ] && [ "$open_spec_ref" = "$CURRENT_SPEC_REF" ] && [ "$open_milestone" = "$CURRENT_MILESTONE_ID" ]; then
    echo "== There is already an open escalation for spec_ref ${CURRENT_SPEC_REF}, milestone ${CURRENT_MILESTONE_ID}. Not re-attempting automatically. =="
    echo "See ${TEAM_PREFIX}/escalation/.latest.md for details. Resolve it before the next run."
    exit 1
  fi
fi

milestone_body="$(milestone_section "$CURRENT_MILESTONE_ID")"

run_id=1
prior_verdict_summary="(none -- this is attempt 1 on this milestone, no prior feedback)"

while [ "$run_id" -le "$MAX_LOOPS" ]; do
  echo "=== Milestone ${CURRENT_MILESTONE_ID}, attempt ${run_id} ===" >&2

  {
    echo "You are scoped to milestone ${CURRENT_MILESTONE_ID}: ${CURRENT_MILESTONE_TITLE}."
    echo
    echo "Full milestone definition (from coordinator/milestones.md):"
    echo "---"
    echo "$milestone_body"
    echo "---"
    echo
    echo "Previously completed milestones (do not redo, but your work must not"
    echo "regress them): ${COMPLETED_MILESTONES:-none}"
    echo
    echo "This is attempt ${run_id} on this milestone."
    echo
    echo "Prior verdict / feedback for this milestone:"
    echo "${prior_verdict_summary}"
  } > "$TMP/gen-context-${run_id}.md"

  write_inbox_message generator "$run_id" task "$TMP/gen-context-${run_id}.md" >/dev/null
  if ! gen_output="$(invoke_role generator "$GEN_MODEL" "$run_id" "$TMP/gen-context-${run_id}.md" "$CURRENT_MILESTONE_ID")"; then
    exit 1   # invoke_role already escalated
  fi
  echo "$gen_output" > "$TMP/gen-output-${run_id}.md"
  run_fulcra file upload "$TMP/gen-output-${run_id}.md" "${TEAM_PREFIX}/member/generator/archive/${CURRENT_MILESTONE_ID}-run${run_id}-output.md" >/dev/null 2>&1 || true

  # Mechanical handoff: commit/push the Generator's artifact BEFORE the
  # separate Evaluator reads it. This is Coordinator-owned deliberately:
  # non-interactive role sandboxes may permit file edits but deny git
  # shell writes; requiring the Generator to commit caused three false
  # M1 failures despite correct content. See coordinator_commit_deliverable.
  if ! coordinator_commit_deliverable "$CURRENT_MILESTONE_ID" "$run_id" "$gen_output"; then
    exit 1  # coordinator_commit_deliverable already escalated
  fi

  {
    echo "You are grading milestone ${CURRENT_MILESTONE_ID}: ${CURRENT_MILESTONE_TITLE}."
    echo
    echo "Full milestone definition (from coordinator/milestones.md):"
    echo "---"
    echo "$milestone_body"
    echo "---"
    echo
    echo "Previously completed milestones -- spot-check these have NOT"
    echo "regressed, in addition to grading the current milestone:"
    echo "${COMPLETED_MILESTONES:-none}"
    echo
    echo "This is attempt ${run_id} on this milestone."
    echo
    echo "Generator's own summary of what it did this attempt:"
    echo "${gen_output}"
  } > "$TMP/eval-context-${run_id}.md"

  write_inbox_message evaluator "$run_id" task "$TMP/eval-context-${run_id}.md" >/dev/null
  if ! eval_output="$(invoke_role evaluator "$EVAL_MODEL" "$run_id" "$TMP/eval-context-${run_id}.md" "$CURRENT_MILESTONE_ID")"; then
    exit 1   # invoke_role already escalated
  fi
  echo "$eval_output" > "$TMP/verdict-run${run_id}.md"
  run_fulcra file upload "$TMP/verdict-run${run_id}.md" "${TEAM_PREFIX}/artifact/${CURRENT_MILESTONE_ID}-verdict-run${run_id}.md" >/dev/null 2>&1

  overall="$(grep -oiE 'overall:[[:space:]]*(PASS|FAIL)' "$TMP/verdict-run${run_id}.md" | head -1 | awk '{print toupper($2)}' || true)"

  if [ "$overall" = "PASS" ]; then
    echo "== Milestone ${CURRENT_MILESTONE_ID}: PASS (attempt ${run_id}) ==" >&2
    new_completed="${COMPLETED_MILESTONES:+$COMPLETED_MILESTONES,}${CURRENT_MILESTONE_ID}"
    next_index=$((CURRENT_MILESTONE_INDEX + 1))
    {
      echo "spec_ref: ${CURRENT_SPEC_REF}"
      echo "completed: ${new_completed}"
      if [ "$next_index" -lt "${#MILESTONE_IDS[@]}" ]; then
        echo "current: ${MILESTONE_IDS[$next_index]}"
      else
        echo "current: (none -- all milestones complete)"
      fi
      echo "last_updated: $(now_iso)"
    } > "$TMP/milestone-progress-new.md"
    run_fulcra file upload "$TMP/milestone-progress-new.md" "${TEAM_PREFIX}/milestone-progress.md"

    if [ "$next_index" -ge "${#MILESTONE_IDS[@]}" ]; then
      echo "== All milestones complete -- writing converged.md ==" >&2
      {
        echo "spec_ref: ${CURRENT_SPEC_REF}"
        echo "timestamp: $(now_iso)"
      } > "$TMP/converged.md"
      run_fulcra file upload "$TMP/converged.md" "${TEAM_PREFIX}/converged.md"
    else
      echo "== Next milestone (${MILESTONE_IDS[$next_index]}) will be attempted on the next coordinator invocation. =="
    fi
    exit 0
  elif [ "$overall" = "FAIL" ]; then
    echo "== Milestone ${CURRENT_MILESTONE_ID}, attempt ${run_id}: FAIL =="
    prior_verdict_summary="$(cat "$TMP/verdict-run${run_id}.md")"
    if [ "$AUTO_RETRIES_ENABLED" != "true" ]; then
      escalate "Evaluator returned FAIL for milestone ${CURRENT_MILESTONE_ID}, attempt ${run_id}. Automatic retries are disabled by coordinator/policy.md; operator review and an explicit new run are required." "$run_id" "$CURRENT_MILESTONE_ID"
      exit 1
    fi
    if [ "$run_id" -ge "$RETRY_BOUND" ]; then
      escalate "Retry bound (${RETRY_BOUND}) exceeded for milestone ${CURRENT_MILESTONE_ID} without a passing verdict." "$run_id" "$CURRENT_MILESTONE_ID"
      exit 1
    fi
    echo "== Automatic retries enabled; retrying milestone ${CURRENT_MILESTONE_ID} =="
    run_id=$((run_id + 1))
  else
    escalate "Evaluator verdict for milestone ${CURRENT_MILESTONE_ID}, attempt ${run_id} did not contain a parseable overall: PASS|FAIL line -- treating as untestable." "$run_id" "$CURRENT_MILESTONE_ID"
    exit 1
  fi
done

escalate "Runaway guard hit (${MAX_LOOPS} attempts) on milestone ${CURRENT_MILESTONE_ID} without resolving." "$run_id" "$CURRENT_MILESTONE_ID"
exit 1
