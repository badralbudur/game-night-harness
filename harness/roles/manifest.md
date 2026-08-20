# Role Manifest

Registry of active roles for this harness. The coordinator reads this file
to know who to message and what inbox to use — it does not hardcode a
fixed set of roles. Add/remove roles by editing this file plus adding or
removing the corresponding `roles/<name>.md` file.

| Role name | File | Responsibility | Inbox address |
|---|---|---|---|
| generator | `roles/generator.md` | Builds the artifact strictly per `spec.md`. | `team/<team-name>/member/generator/inbox/` |
| evaluator | `roles/evaluator.md` | Grades the artifact against `spec.md`, emits a verdict per `schemas/verdict.md`. | `team/<team-name>/member/evaluator/inbox/` |

<!--
To add a role later (e.g. dashboard-support, game-catalog-advisor):
1. Write roles/<name>.md describing its responsibility and inputs/outputs.
2. Add a row here with its inbox address.
3. Update coordinator/policy.md if the new role changes retry/escalation
   behavior (e.g. a role whose failure should NOT count against the retry
   bound).
The coordinator loop itself should not need code changes for additive roles
that just consume/produce inbox messages per the existing schemas.
-->
