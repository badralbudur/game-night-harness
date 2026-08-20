# Verdict Schema

Every evaluator-type role emits a verdict in this format after grading an
artifact. This is the structured pass/fail + breakdown record the
coordinator (and later, the dashboard) reads.

```
run_id: <integer>
timestamp: <ISO 8601 UTC>
overall: PASS | FAIL
spec_ref: <spec version this verdict is relative to>

criteria:
  - id: <requirement/criterion identifier from spec.md>
    result: PASS | FAIL | UNTESTABLE
    method: deterministic | rubric | judgment
    notes: <what was checked, what was found>

summary: >
  <short prose summary of the verdict, for a human skimming the log>
```

## Rules

- `overall: PASS` only if every criterion is `PASS`. A single `FAIL` or
  `UNTESTABLE` criterion makes the overall verdict `FAIL` (an `UNTESTABLE`
  criterion should also trigger escalation per `coordinator/policy.md`,
  since it indicates the spec itself needs clarification).
- `method` must be stated per-criterion, not just once for the whole
  verdict — different criteria within one spec may be checked differently.
- Verdicts are never edited after being written. A retry produces a new
  verdict file (e.g. `verdict-run2.md`), not an amendment to the previous
  one — this preserves the run history trail in the workspace.
