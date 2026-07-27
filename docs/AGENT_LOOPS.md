# Agent Loops

Loop prompts for the AI agents that build **Reval Rebel** in parallel. Each loop is a self-contained prompt: the role, its trigger, inputs, task, expected outputs, acceptance criteria, handoff, and loop-exit condition. Loops run concurrently and re-enter when their inputs change.

> **Scope:** 2D narrative action RPG, Godot 4.7, GL Compatibility. Spring 1343 Reval (Tallinn), St. George's Night Uprising. Canon in `docs/CANON.md`, confidence labels `attested` / `plausible composite` / `folklore` / `invented`. Content is authored JSON under `content/` validated by `schemas/*.schema.json`. Runtime LLM is prohibited (ADR 0003); all dialogue is authored offline.

> **How to use:** instantiate one agent per loop. Feed it the Inputs each tick. The agent produces Outputs, runs its own Acceptance checks, and hands off to the listed consumer loops. A loop exits when its Exit condition holds; otherwise it waits for the next input change and re-enters.

## Loop topology

```text
                       Producer
                          |
        +--------+--------+--------+--------+
        |        |        |        |        |
   Canon Keeper  Research  Narrative  Quest  ...content loops...
        |        |        |        |
        +--- all content loops feed Art, Map, Dev, QA ---+
```

Every content loop's output is reviewed by **Canon Keeper** before it reaches **Dev** and **QA**. **Producer** sequences ticks and resolves cross-loop conflicts. No loop writes outside its owned paths.

## Owned paths

| Loop | Owns | May read |
|------|------|----------|
| Producer | `TODO.md`, `docs/ROADMAP.md` | all |
| Canon Keeper | `docs/CANON.md`, `docs/HISTORICAL_AUDIT.md` | all content + research |
| Research | `history/`, `docs/lore/`, research dossiers | canon, roadmap |
| Narrative | `story/`, `docs/GAME-PILLARS.md` | canon, research, quests |
| Quest | `content/packages/*/quest.json`, `schemas/quest.schema.json` | canon, narrative |
| Dialogue | `content/packages/*/dialogue.json`, `schemas/dialogue.schema.json` | narrative, quest, character |
| Character | `content/packages/*/character.json`, `schemas/character.schema.json`, `characters/` | narrative, research |
| Map Author | `content/maps/*`, `*.rrmap`, `docs/MAP_AUTHORING.md` | research, canon |
| Art | `assets/`, `generated/`, `docs/ART_BIBLE.md` | character, map, research |
| Dev | `scripts/`, `scenes/*.tscn`, `docs/ARCHITECTURE.md` | all content + schemas |
| QA | `tests/`, `tools/verify_*.py`, `tools/*_test.gd` | dev output, content |

## Cadence and scaling

One task takes roughly **20 minutes**, so one *tick* = 20 min of one agent instance. A single instance running an 8-hour day does about **24 ticks/day**. Loops are not called equally: some are front-loaded and go idle, some run continuously and are the bottleneck. Scale each loop by three levers - **how often it is invoked**, **how many instances run in parallel**, and **which model tier** it needs (complexity).

Model tiers: **L** = large/most-capable (deep reasoning, creative, architecture); **M** = mid (structured authoring, volume work); **S** = small-fast (short arbitration, mechanical checks).

| Loop | Model | Invocation cadence | Parallel instances | Load phase | Rationale |
|------|-------|--------------------|--------------------|------------|-----------|
| Producer | S | 1 planning tick per ~3 content ticks (~4x/day) | 1 | continuous, low | short arbitration; cheap but frequent |
| Canon Keeper | L | event-driven, queue drained ~2x/day | 1 (2 if backlog > ~10) | continuous, medium | reasoning-heavy gate; bursty |
| Research | L + web | 3-4 dossiers/day early, < 1/day late | 1-2 early, 0-1 late | front-loaded | 20-40 min per sourced dossier |
| Narrative | L | burst at act start, near-idle mid-act | 1 | front-loaded per act | creative reasoning, low volume |
| Quest | L | ~2-3 packages/day | 1-2 | steady mid-project | schema + branching logic |
| Dialogue | M | high volume once quests exist | 2-3 hot phase, else 1 | mid-to-late spike | many lines, low reasoning per unit |
| Character | M | bursty on new NPCs, low baseline | 1 | bursty | spikes with narrative |
| Map | M-L | one district per several ticks | 1-2 | steady | authoring + verification loops |
| Art | M + gen | high volume, latency-bound (gen 20-40 min) | 2-4 gen + 1 curator | steady, GPU-bound | throughput limited by generation, not reasoning |
| Dev | L | every tick (throughput bottleneck) | 2-3 | continuous, highest | most tasks flow here |
| QA | M | after every Dev/content merge | 1-2 | near-continuous | short runs, high frequency |

**Phase shape.** Early (pre-production of an act): Research + Narrative + Canon dominate; Dev/QA light. Mid (content build): Quest, Dialogue, Map, Art, Dev all hot; Research tapers. Late (hardening): Dev + QA dominate; content loops idle. Re-scale instance counts per phase rather than running all loops at full width the whole time.

**Worked example (one mid-build day, ~1 instance-day = 24 ticks each):** 3 Dev instances (~70 ticks of feature work), 2 Art gen workers (batching, latency-bound), 2 Dialogue, 1-2 Quest, 1 Map, 1 QA draining after each merge, Canon Keeper 2 review passes, Producer 4 planning ticks, Research/Narrative near-idle. Total ~10-12 concurrent instances, weighted toward Dev and Art.

**Rules of thumb:**
1. Scale Dev and QA together - QA must not fall more than ~1 tick behind Dev merges, or regressions pile up.
2. Front-loaded loops (Research, Narrative) run wide at act start, then drop to 0-1 standby instances that re-enter only on request.
3. Latency-bound loops (Art generation) scale by adding parallel gen workers, not by using a bigger model.
4. Canon Keeper is a single serialization point by design; widen it only when its review queue blocks Dev.
5. Producer stays a single small-fast instance - one arbiter avoids split-brain tick plans.

---

## 1. Producer

Coordinates the pipeline, sequences ticks, and resolves conflicts between loops.

- **Trigger:** new task in `TODO.md`, or a cross-loop conflict flagged by any loop.
- **Inputs:** `TODO.md`, `docs/ROADMAP.md`, open conflict flags from other loops.
- **Task:** Pick the next executable task. Decide which loops must run this tick and in what order. Break ties when two loops claim the same path. Record the decision in `docs/ROADMAP.md` under "Current focus".
- **Outputs:** a tick plan (ordered list of loop activations with their inputs), appended to `docs/ROADMAP.md`.
- **Acceptance:** every activated loop has unambiguous inputs and no two loops write the same file in the same tick.
- **Handoff:** tick plan dispatched to the listed loops.
- **Cadence:** 1 short planning tick per ~3 content ticks (~4x/day); always exactly 1 instance; model tier S.
- **Exit condition:** `TODO.md` has no open tasks for the current milestone.

---

## 2. Canon Keeper

Guardian of historical and narrative consistency. Reviews every content output before it reaches Dev and QA.

- **Trigger:** any content loop emits a new or changed artifact under `content/`, `story/`, `characters/`, or `assets/`.
- **Inputs:** the changed artifact, `docs/CANON.md`, `docs/HISTORICAL_AUDIT.md`.
- **Task:** Verify every claim carries a confidence label. Reject `invented` content that contradicts `attested` facts. Check named characters, dates, place names, and faction behavior against canon. Propose minimal canon amendments when research supersedes existing canon.
- **Outputs:** a review verdict (`approved` / `changes requested` with a numbered list), and optionally a pull request to `docs/CANON.md`.
- **Acceptance:** zero `invented` elements contradict `attested` facts; every new term appears in canon or is added with a label.
- **Handoff:** approved artifacts unblocked for Dev and QA; rejected artifacts returned to the originating loop with the change list.
- **Cadence:** event-driven, batched; drain the review queue ~2x/day; 1 instance (add a 2nd only if the queue exceeds ~10 artifacts); model tier L.
- **Exit condition:** milestone content set fully approved with no open `changes requested`.

---

## 3. Historical-Geo Researcher

Investigates and gathers data on 1343 Reval: buildings, interiors, clothes, tools, institutions, flora/fauna, and daily life.

- **Trigger:** Narrative, Quest, Map, or Art request a dossier on a topic (e.g. "Livonian Order knight harness, 1343", "lower-town smithy interior").
- **Inputs:** the topic request, `docs/CANON.md`, existing `history/` and `docs/lore/`.
- **Task:** Produce a sourced dossier. For each fact give a citation and a confidence label. Distinguish attested record from plausible composite. Note regional specifics (Danish Estonia, Hanseatic Reval, Livonian Order). Flag where evidence is thin and a `plausible composite` must carry the design.
- **Outputs:** a markdown dossier under `history/<topic>.md` with a `## Sources` section, plus a short brief (max 20 lines) for the requesting loop.
- **Acceptance:** every non-trivial claim has a source or is explicitly labeled `plausible composite` with rationale; no anachronisms (post-1343 material, terms, or technology).
- **Handoff:** dossier to Canon Keeper for review; brief to the requesting loop.
- **Cadence:** front-loaded - 3-4 dossiers/day in an act's pre-production, tapering to under 1/day once canon stabilizes; 1-2 instances early, 0-1 on standby late; ~20-40 min per dossier; model tier L plus web search.
- **Exit condition:** all open research requests in `TODO.md` are closed and canon-approved.

---

## 4. Screenwriter / Narrative Designer

Creates main story arcs, heroes, villains, quests hooks, endings, and scene-level beats.

- **Trigger:** Producer opens a story milestone, or Research delivers new canon that opens narrative possibilities.
- **Inputs:** `docs/GAME-PILLARS.md`, `story/STORY.md`, `docs/CANON.md`, research dossiers, faction ledger state.
- **Task:** Write or revise act/scene beats that fit the pillars (the forge as lever; objects and people remember; no universal morality meter; history cannot be prevented). Define character arcs for Kalev and named NPCs across the three acts. Produce branching beats that converge on the fixed historical spine. Ensure every beat has a forge-facing choice where relevant.
- **Outputs:** updated `story/STORY.md` and per-act beat documents under `story/actN_*.md`.
- **Acceptance:** every branch preserves the attested historical events; no beat contradicts canon; every choice maps to a consequence type (protection, evidence, betrayal, threat).
- **Handoff:** beats to Canon Keeper, then to Quest and Dialogue loops.
- **Cadence:** front-loaded per act - a burst of beats at act start, near-idle mid-act; 1 instance; model tier L.
- **Exit condition:** all three acts have complete, canon-approved beat documents.

---

## 5. Quest Designer

Turns narrative beats into authored quest packages with objectives, states, transitions, and outcomes.

- **Trigger:** Narrative emits a new beat, or Producer opens a quest task in `TODO.md`.
- **Inputs:** the beat, `schemas/quest.schema.json`, `schemas/quest_package.schema.json`, existing `content/packages/*/quest.json`.
- **Task:** Author a quest JSON package. Define entry conditions, states, transitions, objectives, and outcomes. Wire outcomes to the faction ledger. Ensure every forge modification the player can make is modeled as a quest variable that resurfaces later. Validate against the schema.
- **Outputs:** `content/packages/<quest_id>/quest.json` and a package manifest entry.
- **Acceptance:** passes `schemas/quest.schema.json`; every outcome references a faction ledger event; no orphan states; quest is replayable from a clean save.
- **Handoff:** quest package to Canon Keeper, then to Dialogue and Dev loops.
- **Cadence:** steady through mid-project - ~2-3 packages/day; 1-2 instances; model tier L.
- **Exit condition:** all milestone quests authored, validated, and canon-approved.

---

## 6. Dialogue Writer

Authors offline dialogue trees, barks, and condition lines (no runtime LLM, per ADR 0003).

- **Trigger:** Quest emits a package needing NPC lines, or Character adds/changes a character.
- **Inputs:** quest package, `schemas/dialogue.schema.json`, `schemas/bark.schema.json`, character profiles.
- **Task:** Write dialogue JSON keyed by quest state and character. Keep lines period-appropriate in diction (no modern idioms). Reflect character voice and faction allegiance. Provide barks for ambient states. Ensure branch conditions reference real quest variables.
- **Outputs:** `content/packages/<quest_id>/dialogue.json` and optional `bark.json`.
- **Acceptance:** validates against schemas; every referenced quest variable exists; no line contradicts canon; line count fits the vertical-slice budget.
- **Handoff:** dialogue to Canon Keeper, then to Dev for wiring.
- **Cadence:** high-volume, follows quests - spikes to 2-3 instances in content-heavy phases, drops to 1 otherwise; model tier M (volume work, low reasoning per line).
- **Exit condition:** all milestone quests have complete, validated, canon-approved dialogue.

---

## 7. Character Designer

Defines named and archetype characters: appearance, voice, allegiance, and role in the faction ledger.

- **Trigger:** Narrative introduces a new character, or Quest needs an NPC with a profile.
- **Inputs:** `schemas/character.schema.json`, narrative beats, research dossiers on dress and social roles.
- **Task:** Author `character.json` with physical description, faction allegiance, biography, voice notes, and portrait brief. Label every biographical claim with a confidence label. Produce an image prompt brief for the Art loop.
- **Outputs:** `content/packages/<id>/character.json` and a portrait brief in `characters/`.
- **Acceptance:** validates against schema; allegiance matches the faction ledger; no attested-contradicting biographical claims; portrait brief is single-subject and riggable where animation is needed.
- **Handoff:** character to Canon Keeper, portrait brief to Art.
- **Cadence:** bursty - spikes when new NPCs land, low steady baseline; 1 instance; model tier M.
- **Exit condition:** all milestone characters authored and canon-approved.

---

## 8. Map / Environment Author

Authors district maps and interiors from blueprints, enforcing the `docs/MAP_AUTHORING.md` contract.

- **Trigger:** Research delivers an environment dossier, or Producer opens a district task.
- **Inputs:** research dossier, `docs/MAP_AUTHORING.md`, ADR 0009/0010, `content/maps/`, stable building IDs.
- **Task:** Author or revise a `MapBlueprint` / `.rrmap` for the district. Place buildings, props, patrol corridors, and landmarks using stable IDs. Ensure deterministic compilation and gameplay parity with the 2D logic plane. Tag every building with a confidence label for its historical basis.
- **Outputs:** updated `content/maps/<district>` blueprint and compiled `MapDefinition` inputs.
- **Acceptance:** passes `tools/verify_map_composition.py`, patrol walkability checks, and parity tests; no duplicate stable IDs; composition within signed thresholds.
- **Handoff:** map to Canon Keeper, then to Art (dressing) and Dev (wiring).
- **Cadence:** steady - one district per several ticks including verification; 1-2 instances; model tier M-L.
- **Exit condition:** all milestone districts authored, verified, and canon-approved.

---

## 9. Art / Asset Producer

Generates and prepares 2D sprites, 3D presentation assets, and audio briefs using ComfyUI / Leonardo.

- **Trigger:** Character, Map, or Narrative delivers an image/asset brief.
- **Inputs:** the brief, `docs/ART_BIBLE.md`, `docs/MATERIAL_STYLE_LOCK_KIT.md`, `agents/3d-renderer/SKILL.md`.
- **Task:** Generate candidates following the style lock kit. For 3D, follow the single-object, neutral-pose, plain-background rules. Select the cleanest candidate, import into `assets/`, and record provenance in `assets/SOURCES.csv`. Do not let raw candidates reach runtime until production-approved.
- **Outputs:** approved asset in `assets/` with an import file and a `SOURCES.csv` row.
- **Acceptance:** matches the art bible; passes `tools/verify_asset_lint.py`; provenance recorded; no raw Hunyuan3D mesh used unapproved.
- **Handoff:** asset to Map/Dev for placement; Canon Keeper informed of any new visual canon implications.
- **Cadence:** high-volume but latency-bound (generation 20-40 min); scale by adding parallel gen workers (2-4) plus 1 curator, not by using a bigger model; batch overnight; model tier M plus generation tools.
- **Exit condition:** all open asset briefs fulfilled and lint-clean.

---

## 10. Developer

Implements runtime GDScript, scene wiring, and content loading in Godot 4.7.

- **Trigger:** canon-approved content artifact is ready to wire, or Producer opens a dev task.
- **Inputs:** approved content JSON, `docs/ARCHITECTURE.md`, `scripts/`, `scenes/`.
- **Task:** Wire content into the runtime without violating architecture boundaries (no runtime LLM, no second state store, 3D is derived presentation only). Implement features in typed models and scene-local composition. Keep `GameState` the sole campaign-state store. Add autoloads only when justified.
- **Outputs:** updated `scripts/` and `scenes/*.tscn`, plus a change note in `docs/ROADMAP.md`.
- **Acceptance:** existing tests pass; new behavior has tests; no architecture constraint violated; content loads through `ContentDB`.
- **Handoff:** build to QA.
- **Cadence:** continuous - the throughput bottleneck, runs every tick; 2-3 instances; model tier L.
- **Exit condition:** all milestone dev tasks complete and handed to QA.

---

## 11. QA / Tester

Writes and runs automated verification: unit tests, traversal tests, schema validation, and composition audits.

- **Trigger:** Dev delivers a build, or a content loop emits artifacts needing validation.
- **Inputs:** dev build, content JSON, `tests/`, `tools/verify_*.py`, `tools/*_test.gd`.
- **Task:** Run the full verification suite. Add regression tests for new behavior. Verify schema compliance, map composition thresholds, patrol walkability, and save/load replayability. Report failures with minimal reproduction steps.
- **Outputs:** a test report (pass/fail per suite) and new/updated test files.
- **Acceptance:** all suites green; new behavior covered; no regressions versus the last green baseline.
- **Handoff:** failures to Dev or the originating content loop; green report to Producer.
- **Cadence:** near-continuous, short runs - triggered after every Dev/content merge, ~1 tick per run; 1-2 instances scaled to stay within ~1 tick of Dev; model tier M.
- **Exit condition:** milestone build passes all suites and Producer accepts the release candidate.

---

## Concurrency rules

1. No two loops write the same file in one tick (Producer arbitrates).
2. Content artifacts are blocked from Dev and QA until Canon Keeper approves.
3. Research and Narrative may run concurrently; Quest waits for Narrative beats.
4. Art may start from a brief while Character is still refining, but the asset is not final until Character and Canon Keeper sign off.
5. QA is the final gate before Producer marks a milestone task done.
