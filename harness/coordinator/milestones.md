# Milestones (Game Night v1)

Breaks `spec.md` into an ordered sequence of small, independently
buildable-and-gradeable increments. The coordinator scopes each
Generator/Evaluator run to exactly ONE milestone — never "build the
whole spec" in one shot. This exists because a single run attempting the
full spec is too large a unit of work to reliably complete or evaluate
in one pass (confirmed empirically: run 1 produced a substantial partial
build — engine skeleton, content seeding, naming — but hit a hard
provider usage limit before finishing or committing anything).

The Generator must still read the **full spec.md** every run (so it
never violates an invariant that belongs to a later milestone), but its
concrete task for a given run is limited to the current milestone's
scope. The Evaluator grades the current milestone's specific criteria
AND spot-checks that previously-completed milestones haven't regressed
(the immutable-spec/incremental-build combination means later milestones
could otherwise silently break earlier guarantees).

Milestones are ordered; a milestone should generally only depend on
milestones before it in this list. If a later refinement of the spec
requires re-ordering or splitting a milestone, edit this file (a harness
change, gated like any other) rather than letting a role guess at
ordering.

## M1: Game content seeding

**Scope:** the seeded import-need list, city-reassignment gazetteer,
mayor-question bank, and the game/newspaper naming (spec #33, #2's data
needs, #23-25's data needs). No engine/game-flow logic yet — this is
pure structured content.

**Target spec requirements:** #2 (data only), #13, #14, #22 (data/rules
only, not runtime enforcement), #23-25 (question bank only), #33.

**Done when:** `content/import_needs.json`, `content/gazetteer.json`,
`content/questions.json`, and `NAME.md` exist, are well-formed, and pass
the Evaluator's judged quality checks for #33 (varied/gameable list,
real chosen name). Committed to the deliverable repo.

**Status:** substantially produced during run 1 (uncommitted). Re-verify
and commit under this milestone's scope on the next run.

## M2: Core round-flow engine (lockstep, queue, cycle, fallbacks)

**Scope:** the round timer/lockstep sequence (#9-12), city queue and
rotation including the facilitator-always-first rule and join-after-
first-export queuing (#4, #5), the import/export/winner cycle with its
fallback rules (#15, #16, #17, #19), and blind-voting data handling
(#18, #21) — as a testable engine, with placeholder/stub content
anywhere the engine would otherwise need newspaper prose, generated
images, or facilitator-question phrasing (M4/M5/M6/M7's job). Config.json
conformance for every parameter this milestone touches (round window,
repetition rules, submission caps).

**Target spec requirements:** #4, #5, #9-12, #14 (enforcement), #15, #16,
#17, #18, #19, #21.

**Done when:** deterministic unit tests (written by the Generator or
Evaluator) demonstrate: round lockstep ordering; queue/rotation
correctness including the facilitator-first and join-timing rules; each
fallback path (skip / zero-submission ramp-up / no-pick even-split)
triggers correctly; blind-voting data never exposes exporter identity to
the importer at the engine-state level (newspaper-level redaction is
M5's job, but the underlying data must already be structured to make
that possible).

**Status:** substantially produced during run 1 (`engine/game.py` and
supporting modules — uncommitted). Re-verify against this milestone's
narrower scope (i.e. don't penalize for the newspaper/image pieces not
existing yet — that's expected at this milestone) and commit.

## M3: Economy (profit rolls, leaderboard)

**Scope:** the 2d6-style profit roll on a winning export, the cumulative
per-city leaderboard, and the rule that non-winning submission origins
are never exposed regardless of config (#20-22).

**Target spec requirements:** #20, #21, #22.

**Done when:** deterministic tests confirm profit rolls land in range,
accumulate correctly per city, and that leaderboard visibility follows
`config.json`'s `economy.leaderboard_visible_in_newspaper` while
non-winner-origin exposure is never configurable (hardcoded to always
off, not exposed as a knob).

## M4: Facilitator two-slot question mechanic

**Scope:** the per-round check-in bundling (#23), freeform
getting-to-know-you questions framed as questions to/about the mayor
(#24), and the (currently text-only, not yet newspaper-integrated)
aggregate-answer data model that M5 will render into prose (#25's data
side; the prose/"clever phrasing" itself is M5's job).

**Target spec requirements:** #23, #24, #25 (data model only).

**Done when:** deterministic tests confirm the two-slot logic (one
pending game action + one question when a second action isn't pending,
per the Finding-3 reading already confirmed correct — see
`knowledge/harness-process-findings.md`) and that question selection
respects `config.json`'s facilitator_questions settings.

## M5: Newspaper rendering core

**Scope:** render actual newspaper prose per simulated round (the
"departments" `NAME.md` sketches — Sealed Bids, Cleared Customs, etc.),
apply M4 aggregate-answer data ("the world" / "some countries" framing),
enforce city/mayor-only identity redaction (#28), meet the tone requirement
(#30), and generate one edition image (#29). Raster image generation is
preferred when an available provider supports it; otherwise a deterministic,
game-state-informed SVG/procedural illustration is an explicitly allowed
fallback. Record the actual modality/provider in deliverable config/output.

**Target spec requirements:** #25 (rendering), #28, #29, #30.

**Done when:** at least one full simulated round produces a local/rendered
edition artifact with correct identity redaction, aggregate phrasing,
recorded image modality, and a passing judged tone review. Do **not** block
this milestone on public/private hosting or archive deployment; M6 owns
that separate integration boundary.

## M6: Newspaper publication & archive

**Scope:** take M5's rendered editions and publish them to a fixed,
non-publicly-discoverable URL; preserve browseable prior-edition archive;
verify the isolated public manifest and delivery privacy rules.

**Target spec requirements:** #26, #27.

**Done when:** a M5-rendered edition is reachable at a stable URL, its
archive exposes at least one prior edition without overwriting it, and the
Evaluator verifies that only intentionally curated public files are
published (no inboxes, raw verdicts, credentials, or private repo data).

## M7: Endgame content

**Scope:** crown the cumulative-profit winner, the tongue-in-cheek twist
article, and per-city descriptions/images built from actual game history.
Each importing city's excess is the declined offers it received; each
winning exporter city additionally shows fun/colorful production of its
winning export. Winner origin is displayable; non-winning origin/text
remains protected. [spec #21/#32; user decision 2026-08-27]

**Target spec requirements:** #31, #32.

**Done when:** a full simulated game (multiple rounds via M2-M6) reaches
its end condition and produces all three endgame artifacts, passing the
Evaluator's judged quality checks.

## M8: Full-spec integration & regression pass

**Scope:** no new features — wire M1-M7 together end to end, run a
complete simulated game with real spawned simulated players (varying
engagement levels, per spec's Generation Rules) rather than milestone-
scoped unit tests, and confirm every spec requirement (#1-#35) holds
simultaneously, not just per-milestone in isolation.

**Target spec requirements:** all of them, as an integration check.

**Done when:** the Evaluator's full deterministic + judged checklist
(spec.md's Evaluation Criteria section, in full) passes end to end against
one complete simulated game run.

## Milestone progress tracking

The coordinator tracks current/completed milestones in the workspace at
`team/<team-name>/milestone-progress.md` — not in this file, which is
part of the portable harness and should not accumulate run-specific
state. See RUNBOOK.md for the exact mechanics.
