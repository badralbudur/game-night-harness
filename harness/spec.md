# Spec: Import/Export Game Night (v1)

_Derived from `decisions.md`. This is the immutable target for the current
harness run — to change target behavior, edit this file (a deliberate,
gated act between runs), never patch the generated artifact directly._

## Goal

Build a one-off, playable async social game ("Game Night v1") where 3–10
players each represent a city, take turns via their own conversational
agent, and build up game state (imports/exports/profits) plus real
getting-to-know-you answers, all surfaced through a running in-fiction
"newspaper" published to a private, unguessable URL. This is a one-off
build for a specific test game (see decisions [scope]) — not yet the
generalized, cross-platform agent skill that v2 will be.

## Requirements

Numbered and traceable to `decisions.md` tags in brackets.

### Players & cities
1. Min 3, max 10 (configurable) players. [players, scope, Q25]
2. Each player picks a home city on joining; the agent suggests
   possibilities but players may pick freely. City names must be unique
   per game; a duplicate pick is reassigned to a different, geographically
   close city. [players, cities, Q17]
3. Players may join after the game has started. [players, Q3]
4. The facilitator's city always occupies position 1 in the city order
   queue, so they can open the first import need immediately with no dead
   first round for others. [facilitator, rotation, Q18]
5. A joining player is appended to the city order queue only once they've
   submitted their first export; they may submit exports before that
   point but are not assigned an import need until queued. [players,
   rotation, Q4]

### Facilitator
6. The facilitator role is fixed for the whole game (does not rotate).
   [facilitator, Q1]
7. The facilitator participates as a player too — specifically, the human
   user of the facilitator agent plays under the same rules as everyone
   else. [facilitator, players, Q2]
8. The facilitator can accommodate multiple players directly (e.g. via
   Discord) for testing or for a player lacking their own agent, though
   the primary design target is one agent per player. [architecture,
   testing, Q23]

### Round structure & timing
9. Exactly one round timer for the whole game — no independent per-phase
   timers. Each round, in lockstep: one new import need opens, one
   export-collection window closes, and one earlier round's winner gets
   picked. [rounds, timing, Q20]
10. Round window: 24 hours by default, configurable. [rounds, timing, Q9]
11. Each player checks in and acts at most once per round. Their check-in
    bundles up to two pending items (see #21). [rounds, timing, Q20/21]
12. Fixed game length target: two rotations. Players present from
    rotation 1 get 2 import turns; players who join during/after rotation
    1 get only 1 import turn. [players, length, Q5]

### Import/export/winner cycle
13. Before a city's import turn opens, its importing mayor chooses that
    city's next import: present a small set of eligible seeded suggestions
    and also accept a freeform request. The choice, rather than a hidden
    random draw or a mere addition to a shared pool, becomes that city's
    next import. Suggestions and freeform requests must still obey the
    configured category/repetition policy. [imports, player-agency,
    2026-08-31 user decision]
13a. Import needs describe actual tradable imports -- e.g. food or candy,
    materials, equipment, living things, cultural works, or specialist
    services. They may be playful, but may not reduce to a request for
    generic advice or civic problem solving. Exports remain free-form
    proposals for an actual supplied import. [imports, game-content,
    2026-08-31 user decision]
14. Import categories may repeat across different cities, but the same
    city may not receive the same import category twice; configurable.
    [imports, config, Q22]
15. Exports are free-form text (not chosen from a list). Capped at one
    export submission per player per import need per round. [imports,
    Q21]
16. If a player doesn't submit an export within the window, they are
    simply skipped for that round — no penalty, no substitution. [rounds,
    fallback, Q10]
17. If zero players submit an export for an import need, the import city
    "ramps up its own industry" (framed creatively in the newspaper) and
    the import player still receives the rolled profit. [rounds,
    fallback, newspaper, Q11]
18. The import-city player selects the winning export subjectively (no
    fixed rubric) — but does so the round AFTER exports were collected
    (giving them a full window), not the same round. Voting is blind: the
    importer must not see which city submitted which export. [rounds,
    blind-voting, Q10, Q6]
19. If the import player still hasn't picked a winner by the end of their
    picking window, all submitted exports are treated as winners and the
    profit is split evenly among their cities. [rounds, fallback, Q10]

### Economy / scoring
20. On a winning export, roll a 2d6-style profit value and add it to that
    city's running cumulative total. [economy, scoring, Q6]
21. Non-winning suggestions' origin city must never be exposed (blind
    voting extends to post-round reveal too — don't leak it in the
    newspaper either). [economy, Q6]
22. The leaderboard (cumulative per-city profit) is shown in the
    newspaper for v1. What's exposed during the game generally must be
    driven by a configurable parameter set, not hardcoded, so exposure
    policy can be iterated on. [economy, config, Q7]

### Facilitator questions
23. Each player's per-round check-in has up to two slots: (a) a pending
    game action if one exists (import pick and/or export suggestion), and
    (b) if a second game action isn't pending, a getting-to-know-you
    question fills that slot. Configurable — not every round necessarily
    needs a question. [facilitator, questions, config, Q27]
24. v1 questions are freeform "getting to know you" questions using the
    game as pretext, not scoped to the import/export theme, and framed as
    questions to/about "the mayor" (the player's persona). Configurable
    for a future domain-specific harness run. [facilitator, questions,
    config, Q13]
25. Answers to these questions are shared in the newspaper by default
    (not private), phrased in "clever" aggregate ways — e.g. "the world"
    for a unanimous/group-wide pattern, "some countries"/"most nations"
    for a partial pattern. [newspaper, facilitator, privacy, Q12]

### Newspaper
26. Automatically renders and publishes exactly one redacted edition after
    every completed round (not batched), then notifies the group it is
    available. It publishes to a single fixed URL that is not publicly
    discoverable (unguessable subdomain + robots noindex, per the
    `fulcra-dashboard` pattern) but reachable by all players. A manually
    callable renderer alone does not satisfy this requirement. [newspaper,
    delivery, Q15, 2026-08-31 user decision]
27. Prior editions remain browsable at that same URL (an archive, not
    just the latest issue). [newspaper, timing, Q19]
28. Players are identified in the newspaper by city/mayor only — never
    real name/handle. May become even more anonymous later; configurable.
    [newspaper, privacy, identity, Q26]
29. Every edition includes a generated image, not just the final one.
    Preferred modality: a fun, colorful raster image from an available
    image-generation provider. If no such provider is available, a
    deterministic, game-state-informed SVG/procedural illustration is an
    explicitly permitted fallback — it must still be materially informed
    by the edition and meet the tone bar. [newspaper, endgame, Q24;
    user decision 2026-08-24]
30. Tone: funny, fun, colorful; humor is allowed to be pointed/not
    uniformly laudatory, but must not be snide or mean. [newspaper,
    endgame, Q24]
30a. The public archive must read visually as a real newspaper rather than
     a plain document: intentional editorial hierarchy, masthead, readable
     columns/department treatment, and edition images that are materially
     more expressive than minimal procedural placeholders. The stable paper
     URL opens the newest available edition by default; every edition has
     clear navigation to the latest issue, archive, and adjacent editions
     where applicable. [newspaper, design, navigation, 2026-09-01 user
     decision]

### Endgame
31. At game end: crown the overall cumulative-profit winner; also publish
    a tongue-in-cheek "twist" article about problems caused by some of the
    game's imports/exports. [newspaper, endgame, Q24]
32. Generate a description and image for each city informed by the game's
    actual history. For each importing city, portray its **excess** as
    offers it received and declined (declined imports), never revealing
    non-winning exporter identity/text in violation of #21. For each city
    that supplied a winning export, also portray fun/colorful **production
    of that winning export** (e.g. factories, fields, workshops). Winner
    origin may be shown because it is already inferable from the winning
    profit/leaderboard; this exception never extends to non-winning
    exports. Use the raster-preferred/SVG-fallback modality policy in #29.
    [newspaper, endgame, Q24; user decision 2026-08-27]

### Game content the Generator must produce
33. The seeded import-need list and the game/newspaper's name are part of
    the deliverable itself (game content), not a separate harness-side
    output. The Generator role produces both, early, as part of building
    the deliverable — the name must be good, not a placeholder; the import
    list seeds real gameplay (#13, #13a), supports mayor-facing choices,
    and can be extended by players during play. [harness-process, imports,
    naming, Q8, Q28, 2026-08-31 user decision]

### Roles & process integrity
34. Generator and Evaluator (and any future additional roles) must run as
    genuinely separate subagents/sessions, not a single session
    switching personas — this applies to the harness loop itself, not
    only to simulated players (#23 above already required this for
    multiplayer simulation; this extends it to Generator/Evaluator/etc.
    within any single run). [roles, harness-process]
35. Deliverable changes are committed to git once per harness run/round,
    in a repository separate from the harness's own git history — the
    harness repo and the deliverable repo must not be the same repo or
    share commit history. [harness-process, git]

## Generation Rules

- Build against real Fulcra Workspaces primitives (inboxes, shared files)
  for v1 — no `fulcra-agent-coordination` engine. [harness-process]
- Every role (Generator, Evaluator, and any future additional roles) runs
  as a genuinely separate subagent/session — never a single session
  switching personas to play multiple roles. This applies both to the
  harness loop's own roles and to simulated players used in evaluation.
  [architecture, testing, roles, Q14, Q23, Q34]
- The harness may use different models for different roles where
  appropriate (e.g. a creative-writing-heavy newspaper/image role vs. a
  strict rules-adherence evaluator role) rather than one fixed model
  throughout. [harness-process, Q28]
- All configurable parameters (round window, import repetition rule,
  exposure/visibility policy, question cadence, max players, etc.) live
  in a single `config.json` in the deliverable's own repo/workspace state
  — not hardcoded in role instructions or scattered across files. Roles
  read it; nothing re-derives config values independently.
- Deliverable changes are committed to git once per round/run, in a git
  repository that is separate from the harness's own git repository (no
  shared history). The harness tracks its own template/process evolution;
  the deliverable tracks the game's own build history independently.
  [harness-process, git, Q35]

## Evaluation Criteria

Deterministic checks (script/rule-based, no subjective judgment):
- Round-timer lockstep: exactly one round timer; every round opens one
  import, closes one export window, resolves one winner in the correct
  order (#9–#12).
- Blind-voting integrity: exporter identity never surfaced to the
  importer during voting, and never leaked in the newspaper for
  non-winning submissions, before or after the round resolves (#18, #21).
- Fallback logic: no-submission-by-a-player is a silent skip (#16);
  zero-submissions-at-all triggers the "ramp up own industry" path with
  profit still awarded (#17); no-pick-by-deadline triggers the even-split
  path (#19).
- Join-timing correctness: a joining player is queued only after their
  first export; rotation-count assignment (2 imports vs 1) matches
  whether they joined before or after rotation 1 closed (#5, #12).
- City uniqueness/reassignment: duplicate city picks are reassigned to a
  geographically close alternative, never silently allowed to collide
  (#2).
- Import repetition rule: a category may repeat across different cities
  but never repeats for the same city (#14), unless config overrides it.
- Importer agency and trade semantics: the importer receives several
  eligible suggestions plus a freeform choice, and the chosen request is
  the next need for that city; seeded and freeform prompts describe a
  procurable import rather than advice (#13, #13a).
- Newspaper mechanics: publishes exactly once per round, prior editions
  remain reachable at the same URL (archive, not overwrite), an automated
  completion transaction produces the edition/notification, and city/mayor
  identity only (never real name/handle) (#26–#28).
- Newspaper reading experience: automated checks exercise default routing
  to the latest edition and navigation across the archive; the Evaluator
  judges the rendered hierarchy, styling, and materially game-informed
  imagery against #30a rather than accepting a plain report page.
- `config.json` is the single source for every configurable parameter;
  no role hardcodes a value that config.json defines.

Judged checks (require an explicit rendering of subjective judgment,
performed by the Evaluator role or a named sub-role — state which):
- Newspaper tone: funny, fun, colorful; pointed humor is fine but must
  not read as snide or mean (#30). Evaluator should give concrete
  pass/fail reasoning (e.g. quote the line that crossed the line) rather
  than a bare verdict.
- Aggregate-answer phrasing quality: "the world"/"some
  countries"/"most nations" framing (#25) should plausibly and correctly
  reflect the underlying answer distribution — not just present-looking
  language over an actually-wrong aggregate.
- Endgame content quality: the twist article and per-city descriptions/
  images should be clearly informed by actual game history (not generic
  filler), and per-city images/descriptions should sensibly incorporate
  that city's own non-chosen exports as "excess" (#31–#32).
- Import-list and game-name quality: the generated seed list should be
  varied and gameable (not degenerate/repetitive), and the name should
  read as a deliberately chosen, good name, not a placeholder (#33).

Any criterion that turns out to be untestable as written (ambiguous,
unable to render a verdict either way) must be reported explicitly as its
own finding, per `coordinator/policy.md`'s escalation trigger — not
silently passed or failed.

## Out of Scope (v1)

- The generalized, cross-platform agent skill (v2's job).
- Domain-specific (non-getting-to-know-you) question sets.
- `fulcra-agent-coordination` engine adoption (may come later, based on
  what v1's plain-inbox loop reveals).
- Full anonymity beyond city/mayor identity.
