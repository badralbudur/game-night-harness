# Verdict Schema

Every evaluator-type role emits a verdict in this format after grading an
artifact. This is the structured pass/fail + breakdown record the
coordinator (and later, the dashboard) reads. **The coordinator parses
this file by machine (a simple pattern match on the `overall:` line) —
format compliance is not optional, it's how your verdict actually gets
acted on.**

## Required exact format for the overall line

Your verdict file/output MUST contain a line exactly matching (case and
spacing matter for the parser):

```
overall: PASS
```
or
```
overall: FAIL
```

Put this line early (e.g. right after a one-line summary) so it's easy
to find. You may — and should — include rich prose, tables, and evidence
around it; only this one line needs to be exact.

## Full structure (prose/tables around the required line are fine and encouraged)

```
overall: PASS | FAIL

<criteria breakdown, tables, evidence, reasoning -- format is yours,
 but see "Handling UNTESTABLE criteria" below>

<summary prose>
```

Per-criterion, report:
- `id`: the requirement/criterion identifier from `spec.md` (or the
  current milestone's scope in `coordinator/milestones.md`)
- `result`: PASS | FAIL | UNTESTABLE
- `method`: deterministic | judgment (state which per-criterion — a
  verdict may mix both)
- `notes`: what was checked and what was found (for deterministic
  checks, show your actual evidence — command run, output observed —
  not just an assertion)

## Handling UNTESTABLE criteria

Not every `UNTESTABLE` means the same thing. Distinguish:

1. **Out-of-milestone-scope UNTESTABLE** (expected, not a problem): a
   spec criterion that genuinely belongs to a *later* milestone (per
   `coordinator/milestones.md`) and has no real content/behavior to
   check yet at the current milestone (e.g. grading newspaper tone
   before any newspaper-generation milestone exists). This does NOT
   block `overall: PASS` for the current milestone and does NOT need
   escalation — just say so explicitly and note which future milestone
   should re-check it.
2. **Genuine ambiguity UNTESTABLE** (a real problem): a criterion that
   *is* in scope for the current milestone but can't be evaluated
   because the spec itself is unclear, contradictory, or missing
   information needed to judge it. This DOES block `overall: PASS` and
   SHOULD be flagged for escalation per `coordinator/policy.md` — do not
   guess at a resolution yourself.

If you're not sure which kind an UNTESTABLE criterion is, treat it as
kind 2 (genuine ambiguity) — the safer failure mode is escalating
something that turns out to be milestone-scoping, not silently passing
something that's actually a real spec gap.

`overall: PASS` requires: every criterion genuinely in scope for the
current milestone is `PASS`, AND no kind-2 UNTESTABLE criteria exist.
Kind-1 UNTESTABLE criteria do not block a PASS.

## Other rules

- Verdicts are never edited after being written. A retry produces a new
  verdict file (e.g. a new `-run2.md`), not an amendment to the previous
  one — this preserves the run history trail in the workspace.
- If grading a milestone after earlier milestones have completed, also
  spot-check that the current work hasn't regressed a previously-passed
  milestone (the coordinator will tell you which ones), and report any
  regression as its own FAIL-level finding.
