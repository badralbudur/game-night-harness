# Coordinator Policy

_Template — fill in per-project defaults, adjust as needed._

## Retry bound

Maximum retries before escalating to the user: **3** (default — override
per-project if stated otherwise).

## Escalation trigger

Escalate when any of:
- Retry bound is exceeded without a passing verdict.
- The Generator reports the spec is ambiguous/insufficient to proceed.
- The Evaluator reports a requirement is untestable as written.
- Any role fails to respond within its timeout (see below).

## Escalation behavior

On escalation:
1. Write a structured entry to the workspace's escalation log (durable,
   channel-agnostic — must be resolvable by the user from any channel, not
   only the one the harness happened to be run from).
2. If a live interactive channel is available in the current session,
   also notify the user directly there.
3. Halt the loop. Do not continue attempting retries past the bound.

## Timeout behavior

_Fill in: how long the coordinator waits for a role to respond before
treating it as unresponsive, and what happens then (retry the wait once?
escalate immediately?)._

## What does NOT count against the retry bound

_Fill in if applicable — e.g., a dashboard-support role's failure to render
a view should probably not block/retry the generation-evaluation loop
itself._
