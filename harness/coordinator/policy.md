# Coordinator Policy (Game Night v1)

## Retry policy

- **Automatic retries enabled:** **false** (current interactive/manual-run
  mode).
- **Maximum automatic retries when enabled:** **3**.

The retry mechanism remains part of the harness because unattended mode
(e.g. cron) may need bounded autonomous convergence. But while a human is
watching runs from Discord and actively shaping the harness, automatic
retries are deliberately disabled: a Generator/Evaluator failure or a
role/subprocess failure stops after its first attempt, writes the durable
escalation record, and returns control to the operator. The operator can
review the evidence, adjust the harness/spec/process if needed, then
explicitly invoke a fresh coordinator run.

When enabling unattended operation later, change `Automatic retries
enabled` to **true** and retain the bounded retry count above; do not
silently change this behavior in coordinator code.

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

## Timeout / liveness behavior

A role is supervised by an **activity-aware watchdog**, not a naïve
wall-clock-only timeout. Observable activity means a changed deliverable
file (excluding `.git/`) or fresh role subprocess output.

- **Maximum idle time:** **15 minutes** with no observable activity.
- **Hard maximum role wall clock:** **120 minutes** (two hours).
- **Watchdog poll interval:** **30 seconds**.

On either a 15-minute inactivity stall or the two-hour hard ceiling, the
Coordinator terminates the role subprocess, writes a durable escalation
that distinguishes `stalled` from `hard-wall-clock-exceeded`, and halts
in the current manual mode (automatic retries are disabled). If automatic
retries are later enabled, this failure participates in the same bounded
retry policy as other role subprocess failures.

The two-hour ceiling is deliberately much longer than ordinary work, but
prevents a wedged process from appearing to run forever. The 15-minute
idle threshold prevents it from killing a genuinely active longer build
(e.g. M2), as long as that build is still producing observable artifacts
or output.
## What does NOT count against the retry bound

- Any future dashboard-support role's failure to render a view does not
  block or retry the Generator/Evaluator loop itself (not implemented in
  v1, noted for when it is).
- A subprocess timeout that succeeds on its one automatic retry (see
  above) does not count as a used retry against the 3-retry bound — that
  bound is about failing verdicts, not transient infra hiccups.

