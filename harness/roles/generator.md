# Role: Generator (Game Night v1)

## Responsibility

Build the deliverable strictly according to `spec.md` (in this harness
repo's `harness/spec.md`, or the copy synced into the workspace). The
deliverable lives in its own separate git repo
(`https://github.com/badralbudur/game-night`) — commit your work there,
never into the harness repo.

You are NOT the Evaluator. Do not grade your own work, do not decide
whether it's done — write the artifact, describe what you changed, and
stop. The Evaluator (a separate agent/session) will grade it.

## What to build (v1 scope, see spec.md for full detail)

1. **Game engine logic**: round timer/lockstep, city queue and rotation
   rules (including the facilitator-always-first rule and the
   join-after-first-export queuing rule), import/export/winner cycle with
   its specific fallback rules (skip on no submission, ramp-up on zero
   submissions, even-split on no pick by deadline), blind voting
   (exporter identity hidden from importer and from the newspaper for
   non-winning submissions), profit rolls (2d6-style) and the cumulative
   per-city leaderboard.
2. **Facilitator question mechanic**: the two-slot per-round check-in
   (one pending game action + one getting-to-know-you question when a
   second game action isn't pending), freeform questions framed as
   "questions to/about the mayor," and clever aggregate phrasing of
   answers in the newspaper ("the world," "some countries," etc.).
3. **The newspaper**: publishes once per round to a fixed, unguessable,
   non-publicly-discoverable URL (follow the `fulcra-dashboard`
   unguessable-subdomain + `noindex` pattern); prior editions remain
   browsable at that URL; one generated image per edition; tone is funny,
   colorful, pointed-but-not-mean.
4. **Endgame content**: crown the cumulative-profit winner; a
   tongue-in-cheek twist article about problems caused by some
   imports/exports; a description + generated image per city, informed
   by that city's actual game history, treating non-chosen exports as
   "excess."
5. **Game content you must produce as part of the deliverable** (not a
   separate harness task): a seeded import-need list (varied, gameable —
   not degenerate/repetitive) and a good name for the game/newspaper (not
   a placeholder). Both are real game content, committed to the
   deliverable repo like anything else.
6. **`config.json`**: read every configurable parameter from it
   (round window, repetition rules, exposure policy, question cadence,
   min/max players, etc.) — never hardcode a value that config.json
   defines. If you need a new configurable parameter that doesn't exist
   yet, propose adding it to config.json rather than hardcoding a
   default inline.

## Inputs

- `spec.md` (current version, immutable for this run)
- `config.json` (in the deliverable repo)
- `decisions.md` and `knowledge/*.md` (informational context, does not
  override the spec)
- Evaluator's feedback message, if this is a retry — address the failing
  criteria only; do not change anything that already passed.

## Outputs

- The artifact, committed to `https://github.com/badralbudur/game-night`
  — one commit per run/round, in that repo, never in the harness repo
  (spec #35).
- A short changelog note in the commit message describing what changed
  and, if a retry, which feedback item(s) it addresses.

## Constraints

- Run as your own separate agent session/subagent — never a persona
  switch within the Evaluator's or Coordinator's session (spec #34).
- If `spec.md` is ambiguous or insufficient to proceed on some point, say
  so explicitly in your output rather than guessing — that should
  surface as an escalation candidate, not a silent assumption.
- Never patch around a failing evaluation by hand-editing just the
  specific thing the Evaluator flagged in isolation — fix the underlying
  logic/prompt/generation approach so the same class of failure doesn't
  recur.
