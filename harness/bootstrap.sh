#!/usr/bin/env bash
# bootstrap.sh <team-name>
#
# Provisions a fresh Fulcra Workspaces team from ONLY the contents of this
# harness/ directory: spec.md, decisions.md, knowledge/*, roles/*.
#
# Deliberately uploads NOTHING execution-related (no run history, no verdict
# files, no inbox contents from any prior run) -- this is the portability
# boundary the harness README describes. Run against a brand-new team name
# to prove the harness travels cleanly.
#
# v1 note: uses only fulcra-workspaces primitives (file upload/list), no
# fulcra-agent-coordination engine.
set -euo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEAM_NAME="${1:?Usage: bootstrap.sh <team-name>}"
TEAM_PREFIX="team/${TEAM_NAME}"

FULCRA_BIN="$(command -v uvx || true)"
if [ -z "$FULCRA_BIN" ]; then
  echo "ERROR: uvx not found on PATH" >&2
  exit 1
fi
run_fulcra() { "$FULCRA_BIN" fulcra-api "$@"; }

echo "== Bootstrapping harness into ${TEAM_PREFIX} =="

# --- Guard: refuse to overwrite an existing team ---------------------------
if run_fulcra file stat "${TEAM_PREFIX}/role.md" >/dev/null 2>&1; then
  echo "ERROR: ${TEAM_PREFIX}/role.md already exists -- refusing to overwrite an existing team." >&2
  echo "Pick a new team name, or delete the existing team first if this is intentional." >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- 1. Team role.md (high-level mission, derived from spec.md's Goal) -----
{
  echo "---"
  echo "type: Role"
  echo "title: Team Role"
  echo "---"
  echo
  echo "# ${TEAM_NAME}"
  echo
  echo "Harness-driven project team. Bootstrapped $(date -u +%Y-%m-%dT%H:%M:%SZ) from a portable harness"
  echo "(see team/${TEAM_NAME}/knowledge/harness/README.md for the harness contract)."
  echo
  echo "## Goal (from harness spec.md)"
  echo
  awk '/^## Goal/{flag=1;next}/^## /{flag=0}flag' "$HARNESS_DIR/spec.md"
} > "$TMP/role.md"
run_fulcra file upload "$TMP/role.md" "${TEAM_PREFIX}/role.md"

# --- 2. Team index.md / progress.md / completed.md (initial OKF scaffolding) ---
{
  echo "---"
  echo "type: Index"
  echo "title: Team Index"
  echo "---"
  echo
  echo "# ${TEAM_NAME} Index"
  echo
  echo "- \`knowledge/harness/\` -- the portable harness contract (spec, decisions, knowledge, roles, schemas)."
  echo "- \`artifact/\` -- the deliverable being generated/evaluated."
  echo "- \`member/<role>/\` -- one directory per active role (see harness/roles/manifest.md)."
} > "$TMP/index.md"
run_fulcra file upload "$TMP/index.md" "${TEAM_PREFIX}/index.md"

{
  echo "---"
  echo "type: Progress Report"
  echo "title: Team Progress"
  echo "---"
  echo
  echo "## $(date -u +%Y-%m-%d)"
  echo "* **Bootstrap:** Harness provisioned into this team. No runs yet."
} > "$TMP/progress.md"
run_fulcra file upload "$TMP/progress.md" "${TEAM_PREFIX}/progress.md"

{
  echo "---"
  echo "type: Completed Objectives"
  echo "title: Team Completed"
  echo "---"
  echo
} > "$TMP/completed.md"
run_fulcra file upload "$TMP/completed.md" "${TEAM_PREFIX}/completed.md"

# --- 3. Upload harness contract into team/<team>/knowledge/harness/ --------
for f in spec.md decisions.md README.md; do
  if [ -f "$HARNESS_DIR/$f" ]; then
    run_fulcra file upload "$HARNESS_DIR/$f" "${TEAM_PREFIX}/knowledge/harness/$f"
  fi
done
if [ -d "$HARNESS_DIR/knowledge" ]; then
  find "$HARNESS_DIR/knowledge" -type f -name '*.md' | while read -r kf; do
    rel="${kf#"$HARNESS_DIR"/knowledge/}"
    run_fulcra file upload "$kf" "${TEAM_PREFIX}/knowledge/harness/knowledge/${rel}"
  done
fi
for f in "$HARNESS_DIR"/schemas/*.md; do
  [ -f "$f" ] || continue
  run_fulcra file upload "$f" "${TEAM_PREFIX}/knowledge/harness/schemas/$(basename "$f")"
done
if [ -f "$HARNESS_DIR/coordinator/policy.md" ]; then
  run_fulcra file upload "$HARNESS_DIR/coordinator/policy.md" "${TEAM_PREFIX}/knowledge/harness/coordinator/policy.md"
fi
if [ -f "$HARNESS_DIR/coordinator/milestones.md" ]; then
  run_fulcra file upload "$HARNESS_DIR/coordinator/milestones.md" "${TEAM_PREFIX}/knowledge/harness/coordinator/milestones.md"
fi

# --- 4. Provision roles generically from roles/manifest.md -----------------
# Manifest is a markdown table: | Role name | File | Responsibility | Inbox address |
# Skip header/separator rows; parse each data row's first two pipe-delimited columns.
MANIFEST="$HARNESS_DIR/roles/manifest.md"
if [ ! -f "$MANIFEST" ]; then
  echo "ERROR: roles/manifest.md not found -- harness is incomplete." >&2
  exit 1
fi

grep -E '^\|' "$MANIFEST" | tail -n +3 | while IFS='|' read -r _ name file _rest; do
  name="$(echo "$name" | xargs)"
  file="$(echo "$file" | xargs | tr -d '`')"
  [ -z "$name" ] && continue

  role_file="$HARNESS_DIR/roles/$(basename "$file")"
  if [ ! -f "$role_file" ]; then
    echo "WARNING: manifest lists role '$name' -> $file but that file doesn't exist; skipping." >&2
    continue
  fi

  echo "  -- provisioning role: $name"

  {
    echo "---"
    echo "type: Role"
    echo "title: ${name} Role"
    echo "---"
    echo
    cat "$role_file"
  } > "$TMP/role-${name}.md"
  run_fulcra file upload "$TMP/role-${name}.md" "${TEAM_PREFIX}/member/${name}/role.md"

  {
    echo "---"
    echo "type: Progress Report"
    echo "title: ${name} Progress"
    echo "---"
    echo
    echo "## $(date -u +%Y-%m-%d)"
    echo "* **Bootstrap:** Role provisioned. No work done yet."
  } > "$TMP/progress-${name}.md"
  run_fulcra file upload "$TMP/progress-${name}.md" "${TEAM_PREFIX}/member/${name}/progress.md"

  # Seed an empty inbox with a placeholder so the directory exists and is
  # listable before any real message arrives.
  echo "(inbox placeholder -- bootstrap $(date -u +%Y-%m-%dT%H:%M:%SZ))" > "$TMP/keep-${name}.md"
  run_fulcra file upload "$TMP/keep-${name}.md" "${TEAM_PREFIX}/member/${name}/inbox/.keep.md"
done

echo "== Bootstrap complete: ${TEAM_PREFIX} =="
echo "Next: coordinator/coordinator.sh (or manual first task message) to start run 1."
