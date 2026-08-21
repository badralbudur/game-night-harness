#!/usr/bin/env bash
# doctor.sh -- prereq check for running this harness, per RUNBOOK.md.
# Exit 0 if everything needed is in place; non-zero (with a clear
# message per failing check) otherwise. Run this before bootstrap.sh or
# coordinator.sh, especially on a freshly-ported copy of this harness.
set -uo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAIL=0

check() {
  local desc="$1"; shift
  if "$@" >/tmp/doctor-check-out.$$ 2>&1; then
    echo "OK   - ${desc}"
  else
    echo "FAIL - ${desc}"
    sed 's/^/       /' /tmp/doctor-check-out.$$
    FAIL=1
  fi
  rm -f /tmp/doctor-check-out.$$
}

echo "== Harness doctor: ${HARNESS_DIR} =="

check "uvx is on PATH" bash -c 'command -v uvx'
check "fulcra-api auth is valid (user-info)" bash -c 'uvx fulcra-api user-info'
check "claude CLI is on PATH (default role runner -- see RUNBOOK.md if using a different provider)" bash -c 'command -v claude'
check "gh CLI is authenticated (required for milestone PR lifecycle)" bash -c 'gh auth status'
check "git identity is configured" bash -c 'git config user.name && git config user.email'
check "roles/manifest.md exists" test -f "$HARNESS_DIR/roles/manifest.md"
check "spec.md exists and has a filled-in Goal section" bash -c \
  "grep -qv '^_What is being built' <(awk '/^## Goal/{flag=1;next}/^## /{flag=0}flag' '$HARNESS_DIR/spec.md')"
check "coordinator/policy.md declares a retry bound" bash -c \
  "grep -qE '\*\*[0-9]+\*\*' '$HARNESS_DIR/coordinator/policy.md'"

if [ -n "${DELIVERABLE_DIR:-}" ]; then
  check "DELIVERABLE_DIR is a separate git repo from this harness" bash -c \
    "test -d '$DELIVERABLE_DIR/.git' && [ \"\$(cd '$DELIVERABLE_DIR' && git rev-parse --show-toplevel)\" != \"\$(cd '$HARNESS_DIR' && git rev-parse --show-toplevel)\" ]"
else
  echo "SKIP - DELIVERABLE_DIR not set; export it and re-run to check the deliverable repo"
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "All checks passed."
else
  echo "One or more checks failed -- fix before running bootstrap.sh / coordinator.sh."
fi
exit "$FAIL"
