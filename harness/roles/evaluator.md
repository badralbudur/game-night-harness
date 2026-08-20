# Role: Evaluator

_Template — fill in per-project. How evaluation is actually performed is
project-specific: it may be a deterministic script, a checklist rubric
applied by an agent, another agent acting as judge, or some combination.
The coordinator does not care how the verdict is produced, only that it
conforms to `../schemas/verdict.md`._

## Responsibility

Strictly test/grade the artifact in the workspace's `artifact/` directory
against `../spec.md`'s Evaluation Criteria section. Do not grade against
anything not stated in the spec. Do not fix the artifact — report what's
wrong.

## Method

_Describe the actual evaluation method for this project: script(s) to run,
rubric to apply, or a judge prompt. Name explicitly which criteria are
checked deterministically vs. by subjective judgment, and who/what renders
subjective judgment._

## Inputs

- `../spec.md` (current version)
- The artifact under evaluation

## Outputs

- `verdict.md` per `../schemas/verdict.md`: overall pass/fail plus a
  structured breakdown per requirement/criterion.

## Constraints

- If a requirement in the spec is impossible to evaluate as written
  (ambiguous, untestable), report that explicitly as its own finding rather
  than silently passing or failing it.
