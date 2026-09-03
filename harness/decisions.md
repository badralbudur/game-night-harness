# Decisions Log

Append-only. Chronological. One entry per decision, verbatim from the user
where possible (paraphrase only if necessary, and mark as paraphrased).
Tag each entry with one or more topic tags. This file is the source of
truth for "why" — `spec.md` is a derived, formalized view of these
decisions, not the other way around.

Format:

```
## YYYY-MM-DD HH:MM UTC — [tag1, tag2]
<decision text, verbatim or clearly marked as paraphrased>
```

---

## 2026-08-20 (pre-Grill-Me discussion) — [scope, harness-process]
V1 deliverable is a one-off build for a specific test game, not a
generalized skill. V2 (possibly requiring a new harness) will be the
generalized skill — and not just a Hermes skill, but a general agent
skill.

## 2026-08-20 (pre-Grill-Me discussion) — [game-mechanics, players]
Each player specifies a home city on joining. Rounds are staggered across
a 3-phase cycle so no player idles within a round: (1) an import need is
assigned to one city, (2) other players suggest exports to fill it, (3)
the import city picks a winning export (and simultaneously a new import
need is assigned to keep the cycle going). First two rounds are special
because the cycle takes 3 rounds to complete.

## 2026-08-20 (pre-Grill-Me discussion) — [game-mechanics, rotation]
Import need assignment rotates by city order, so everyone gets the same
number of imports.

## 2026-08-20 (pre-Grill-Me discussion) — [game-mechanics, imports]
Seed the import-need list as part of the deliverable, but allow players
to suggest their own additions. Exports are free-form text, not chosen
from a list.

## 2026-08-20 (pre-Grill-Me discussion) — [game-mechanics, blind-voting]
The import-city player picks the winning export subjectively (no fixed
scoring rubric). The importer must NOT know which city submitted which
export — voting is blind with respect to export origin.

## 2026-08-20 (pre-Grill-Me discussion) — [game-mechanics, length]
Fixed game length for v1: doesn't matter precisely, but use 2 import
turns per player as the target length.

## 2026-08-20 (pre-Grill-Me discussion) — [players, scope]
Minimum player count: 3.

## 2026-08-20 (pre-Grill-Me discussion) — [architecture]
Agents communicate with each other via Fulcra shares. Players communicate
with their own agents however they like.

## 2026-08-20 (pre-Grill-Me discussion) — [harness-process]
Harness v1 should be built on raw `fulcra-workspaces` primitives only (no
`fulcra-agent-coordination` engine yet), specifically to observe firsthand
whether/how a plain-inbox loop breaks down before deciding whether to
adopt the coordination layer.

## 2026-08-20 (pre-Grill-Me discussion) — [harness-process]
The harness itself must be portable: it can be moved to a new
workspace/team with new agents and run again, without carrying over
execution history (run logs, verdicts, inbox contents). It must include
everything needed to iterate on or rebuild the deliverable, but not the
deliverable itself.

## 2026-08-20 (pre-Grill-Me discussion) — [harness-process]
The harness needs a place to accumulate earned domain knowledge distinct
from `spec.md` (knowledge/), and a clean, raw, chronological record of
user decisions distinct from the derived spec (decisions.md — this file).
Both of these travel with the harness; they are not considered disposable
execution history.

## 2026-08-20 (pre-Grill-Me discussion) — [harness-process]
The harness must be customizable per use case: evaluation method varies
by what's being built, and roles are not fixed to a Generator/Evaluator
pair (e.g. a future dashboard-support role, or a game-catalog-advisor role
— not implemented yet, noted for later).

## 2026-08-20 (pre-Grill-Me discussion) — [harness-process, tracking]
Track the harness's own runs and evolution visibly, using
`fulcra-project-dashboard` as a starting point.

## 2026-08-20 (Grill-Me Q1) — [facilitator]
The facilitator role is fixed for the entire game (not rotating), so they
can coordinate gameplay and the resources involved for the duration of
the game.

## 2026-08-20 (Grill-Me Q2) — [facilitator, players]
The facilitator also participates as a player. More precisely: it's the
facilitator agent's own user who plays; the facilitator agent applies the
same rules to its own user as to everyone else.

## 2026-08-20 (Grill-Me Q3) — [players]
New players can join a game already in progress.

## 2026-08-20 (Grill-Me Q4) — [players, rotation]
A joining player is appended to the city order queue only after they've
participated in an export submission. As soon as they join, they can
suggest an export for the current round, but they are not assigned as an
importer until they've started actually participating.

## 2026-08-20 (Grill-Me Q5) — [players, length]
Reframe fixed length as two rotations rather than "2 imports per player"
literally: players who join after the first rotation has begun will only
get one import turn, not two.

## 2026-08-20 (Grill-Me Q6) — [economy, scoring]
Track cumulative wins for each city as a semi-randomized monetary export
profit (roll similar to 2d6) added to a running per-city total. Winning
non-chosen suggestions' origin city must not be exposed.

## 2026-08-20 (Grill-Me Q7) — [economy, config]
The profit roll happens once when an export wins, added to that city's
running total. For now, expose the leaderboard in the newspaper. What's
exposed during the game generally should be a configurable parameter set
so it can be iterated on.

## 2026-08-20 (Grill-Me Q8) — [harness-process, imports]
Generating the seeded import-need list (and, later, the game name) is one
of the harness's first tasks, not something the user writes directly.

## 2026-08-20 (Grill-Me Q9) — [rounds, timing]
Round progression is time-boxed, not purely action-triggered. Start with
a 24-hour phase window; this is a configurable parameter.

## 2026-08-20 (Grill-Me Q10) — [rounds, timing, fallback]
If a player doesn't submit an export within the window, they're simply
ignored for that round (no penalty, no substitution). The import player
does NOT pick a winner in the same round the exports were collected —
picking happens the following round, giving them a full window. If they
still haven't picked by the end of that round, all submitted exports are
treated as winners and the profit is split evenly among their cities.

## 2026-08-20 (Grill-Me Q11) — [rounds, fallback, newspaper]
If zero players submit an export for an import need, the import city
"ramps up its own industry" (the newspaper can be creative about the
narrative framing) and the import player still receives the rolled
profit.

## 2026-08-20 (Grill-Me Q12) — [newspaper, facilitator, privacy]
Facilitator follow-up/deepening questions' answers are shared with the
group via the newspaper by default (not private), but shared in "clever"
ways — e.g. "the world" represents a group-wide pattern, "some
countries"/"most nations" represent a partial (non-unanimous) pattern.

## 2026-08-20 (Grill-Me Q13) — [facilitator, questions, config]
For v1, the facilitator's deepening questions are freeform "getting to
know you" questions using the game as pretext (not scoped to the
import/export theme itself), framed as questions to/about "the mayor."
This is configurable (a v2 domain-specific harness run might scope
questions to a real domain like coding preferences instead).

## 2026-08-20 (Grill-Me Q14) — [testing, players]
For v1 testing, the user will play with at least one other real person
(and possibly the assistant as a stand-in player and/or facilitator). For
looping/evaluation, the harness needs to generate diverse simulated
players with varying levels of engagement (some more/less responsive) to
validate that the game handles disengagement gracefully while staying fun
and keeping momentum for engaged players.

## 2026-08-20 (Grill-Me Q15) — [newspaper, delivery]
The newspaper is published to a fixed URL that is not publicly
discoverable but accessible to all players (not a push notification per
player). `fulcra-dashboard`'s "unguessable subdomain + noindex" pattern
(e.g. via Surge) is the intended mechanism.

## 2026-08-20 (Grill-Me Q16) — [scope]
Confirmed (restated from pre-Grill-Me): v1 is a one-off build; v2 is the
generalized, general-purpose (not Hermes-specific) agent skill.

## 2026-08-20 (Grill-Me Q17) — [players, cities]
City choice must be unique across the game. Players pick freely (real or
invented names), with the agent suggesting some possibilities. If two
players pick the same city name, the second player is assigned a
different, geographically close city instead.

## 2026-08-20 (Grill-Me Q18) — [facilitator, rotation]
The facilitator's city is always first in the city order queue, so they
can pick the first import need immediately — this ensures there's no
first round where other players have nothing to do.

## 2026-08-20 (Grill-Me Q19) — [newspaper, timing]
The newspaper publishes once per completed round (not batched daily).
Prior editions remain browsable at the same fixed publication URL.

## 2026-08-20 (Grill-Me Q20 / Q21 clarification) — [rounds, timing]
There is exactly one round timer for the whole game (not independent
per-phase/per-cycle timers) — every round, in lockstep, one new import
need opens, one export-collection window closes, and one earlier round's
winner gets picked. Each player only needs to check in and act ONCE per
round, even if they have multiple pending items (e.g. picking a winner AND
suggesting an export) — the check-in bundles whatever's pending for that
player.

## 2026-08-20 (Grill-Me Q21) — [rounds, exports]
Capped at one export submission per player per import need per round.

## 2026-08-20 (Grill-Me Q22) — [imports, config]
Import-need categories can repeat across the game (a category may be
assigned more than once, to different cities), but the same import
category cannot be assigned to the same city twice. This repetition rule
is configurable.

## 2026-08-20 (Grill-Me Q23) — [architecture, testing]
Each player should have their own separate agent in the real deployment;
the facilitator should also be able to accommodate multiple players
directly (e.g. via Discord) for testing, or for a player without agent
access. For harness evaluation of multiplayer mechanics, use real spawned
subagents to simulate separate players rather than one session
role-playing multiple personas — this is needed to catch real
multi-agent coordination failures (race conditions, message ordering,
inbox contention) that persona-switching would hide.

## 2026-08-20 (Grill-Me Q24) — [newspaper, endgame]
At game end: crown an overall winner by cumulative profit; also publish a
tongue-in-cheek "twist" article about problems caused by some of the
game's imports/exports. Generate descriptions and images of each city
informed by the game's history (non-chosen exports framed as "excess").
Generate an image for every edition of the newspaper, not just the final
one. Tone throughout: funny, fun, colorful; humor should not be snide, but
also does not need to be uniformly laudatory.

## 2026-08-20 (Grill-Me Q25) — [players, scope]
Support up to 10 players for the v1 test (configurable).

## 2026-08-20 (Grill-Me Q26) — [newspaper, privacy, identity]
Players are referred to in the newspaper by city/mayor identity only, not
real name/handle. May become even more anonymous later (configurable),
but city is the right identity granularity for now.

## 2026-08-20 (Grill-Me Q27) — [facilitator, questions, config]
Each player has exactly two things to do per round: one mandatory game
action (import pick and/or export suggestion, whichever is pending), and
if a second game action isn't pending, a getting-to-know-you question
fills the second slot. Configurable.

## 2026-08-20 (Grill-Me Q28) — [harness-process, naming]
The harness (not the user) proposes the game/newspaper name — it should
be good, not a placeholder. The harness should also use different models
for different roles, when and as appropriate (not one fixed model for
every role).

## 2026-08-24 — [newspaper, images, user-decision]
For v1 newspaper editions and endgame city portraits, a fun, colorful
**raster image** is preferred. If no raster image-generation provider is
available, a deterministic, game-state-informed **SVG/procedural
illustration** is an explicitly permitted fallback. The fallback is not a
spec failure; it must still be fun, colorful, and materially informed by
the edition/city game state.

## 2026-08-27 — [endgame, newspaper, privacy, user-decision]
Resolve the #32/#21 endgame conflict as follows: portray each city's
**excess** as offers it received and declined (declined imports), not as
its own non-winning outgoing export text. Preserve #21's prohibition on
exposing non-winning export origins. Separately, portray the **production
of winning exports** in the exporter cities — e.g. factories, fields,
workshops, or other fun/colorful production scenes. Winner origin may be
shown because the winning city's profit increase already makes that origin
inferable; this permission does not extend to non-winning exports.

## 2026-08-31 — [imports, player-agency, newspaper, user-decision]
Smoke-test feedback: an importing mayor must choose what their city will
import next. Present a small set of suggestions, but let the mayor make a
freeform import request instead. A suggestion added merely to the shared
pool is not an adequate substitute for choosing that city's next import.

## 2026-08-31 — [imports, game-content, user-decision]
Imports must be actual tradable goods, materials, food (including candy),
equipment, living things, cultural works, or services. They may be funny
and creative, but an import prompt must not be merely a request for advice
or generic civic problem solving.

## 2026-08-31 — [newspaper, delivery, user-decision]
The facilitator flow must automatically render and publish the redacted
newspaper edition after every completed round, then notify the group that
the new edition is available. A manually callable renderer alone is not a
complete gameplay flow.

## 2026-09-01 — [newspaper, design, navigation, user-decision]
The newspaper must look and feel more like a real newspaper: improve the
publication's visual styling and edition images. The publication URL should
open on the latest edition by default, with clear navigation to the archive
and from every current or prior edition to adjacent editions and the latest
issue. This is a new harness milestone, not a cosmetic afterthought.

## 2026-09-02 — [imports, game-design, user-decision]
Smoke-test correction: players should not have to pretend to be actual
mayors solving real or complex municipal problems. The city framing is
light social-game flavour, not a civic-simulation role-play requirement.
Import categories must be everyday, immediately relatable things that
any player can enjoy proposing or exporting -- for example candy, soft
drinks, books, snacks, music, games, clothes, plants, pets, or small
comforts -- rather than infrastructure, procurement, or specialist civic
services.

## 2026-09-03 — [newspaper, player-voice, tone, user-decision]
Publish the newspaper when a player's freeform export text would otherwise
trip the tone gate. Do not reject, rewrite, redact, or halt the game because
of that passage. Make clear that it is the player's own entered text -- for a
winning export, it may be quoted cleverly as that mayor's statement. The
paper's editorial voice remains subject to the funny, pointed-but-not-mean
tone rule, and non-winning export origins remain anonymous.
