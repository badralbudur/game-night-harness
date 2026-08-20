# Message Schema

Messages sent between coordinator and role inboxes (raw
`fulcra-workspaces` inbox files, v1 — no `fulcra-agent-coordination` yet).

## Fields (as a markdown-frontmatter or plain structured block — pick one
convention and use it consistently across a harness run)

- `type`: one of `task` | `feedback` | `artifact-ref` | `verdict-ref`
- `from`: role name or `coordinator`
- `to`: role name
- `run_id`: which loop iteration this belongs to (integer, starts at 1)
- `timestamp`: ISO 8601 UTC
- `spec_ref`: pointer to the spec version this message is relative to
  (e.g. a git commit hash of the harness repo, if spec.md is versioned in
  git alongside the harness)
- `body`: free text — the task instruction, feedback content, or a path
  reference to the artifact/verdict file being pointed at

## Example: task message to Generator (run 1)

```
type: task
from: coordinator
to: generator
run_id: 1
timestamp: 2026-08-20T19:00:00Z
spec_ref: <spec commit hash>
body: |
  Build the artifact per spec.md. This is run 1 (no prior feedback).
```

## Example: feedback message to Generator (retry)

```
type: feedback
from: coordinator
to: generator
run_id: 2
timestamp: 2026-08-20T19:15:00Z
spec_ref: <spec commit hash>
body: |
  Evaluator verdict: FAIL. See verdict-ref below for the structured
  breakdown. Address the failing criteria only; do not change anything
  that passed.
verdict_ref: team/<team-name>/artifact/verdict-run1.md
```
