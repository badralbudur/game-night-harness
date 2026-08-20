# Coordinator Policy (Game Night v1)

## Retry bound

Maximum retries before escalating to the user: **3**.

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

_Proposed default, not yet confirmed by user — flag as open in the first
escalation log entry if this hasn't been explicitly approved by the time
it's first needed:_

The coordinator invokes each role (Generator, Evaluator) as a synchronous
subprocess (`claude -p ...`) per run, so "timeout" here means "the
subprocess call itself hangs or errors," not an async wait on a human
inbox (this is the harness loop's own Generator↔Evaluator timing, not the
in-game 24h player round window, which is a separate, already-decided
game-mechanic parameter in `config.json`).

- Default subprocess timeout: 10 minutes per role invocation.
- On timeout: retry the same role invocation once. If it times out again,
  treat this as an escalation trigger (role failed to respond).

## What does NOT count against the retry bound

- Any future dashboard-support role's failure to render a view does not
  block or retry the Generator/Evaluator loop itself (not implemented in
  v1, noted for when it is).
- A subprocess timeout that succeeds on its one automatic retry (see
  above) does not count as a used retry against the 3-retry bound — that
  bound is about failing verdicts, not transient infra hiccups.

