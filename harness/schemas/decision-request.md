# Decision Request Schema

Use when Generator, Evaluator, Coordinator, or Harness Maintainer finds a
question that only the user may answer — an ambiguous requirement, policy
choice, trade-off, credential/provider selection, or domain judgment.

## Required fields

```text
decision_request: true
id: <stable slug, e.g. image-modality-m5>
from: <role>
milestone: <M# or phase>
spec_ref: <harness git commit>
priority: blocking | before-next-milestone | informational
question: <exactly one concise question for the user>
context: <short factual evidence; do not argue for an unstated preference>
options:
  - <option and consequence>
  - <option and consequence>
recommended_default: <optional; state why and label it a recommendation>
```

## Lifecycle

1. Coordinator uploads the request to
   `team/<team>/decision/<timestamp>_<id>.md` and records it in durable
   status/dashboard Open Items.
2. If `priority: blocking`, halt the current milestone after writing the
   request; do not invent an answer or repeatedly retry it.
3. Ask the user through the configured origin channel, **one question at a
   time**. The dashboard/workspace request is the durable cross-channel
   record; chat is the notification mechanism.
4. When the user answers, append the raw answer to `decisions.md`, update
   `spec.md` only as an explicit user-approved change, commit the harness,
   mark/supersede the request in the workspace, and resume the milestone.

A provider/capability fallback is not a decision request if the approved
spec/config already defines one (e.g. raster preferred, SVG fallback).
