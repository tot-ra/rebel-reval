# Spirit dialogue combat

Status: planned; hero model implemented (SD-10) ([ADR 0033](../adr/0033-teen-protagonist-and-spirit-dialogue-combat.md)). Only the hero model (SD-10) is implemented; everything else is design. Scope: a teenage clairvoyant protagonist, dialogue authored as combat, observation of other people's conflicts as spirit duels, hybrid physical combat with per-school guilt, and the language-comprehension skill. Out of scope: party control, a universal morality score, runtime LLM dialogue (ADR 0003), a new magic framework beyond [`MAGIC.md`](./MAGIC.md) and [`PSYCHE.md`](./PSYCHE.md).

Canon labels: spirit world, creatures, and guilt rites are `folklore` / `invented` per [`docs/CANON.md`](../CANON.md). The almshouse at the Holy Spirit parish is `plausible composite`. The hero's perception is never given a clinical diagnosis.

## Runtime today

- **Playable hero model (SD-10):** the player rig spawns the 15-year-old orphan apprentice (`char.apprentice`, `assets/characters/variants/apprentice.tscn`, body `assets/characters/realistic/apprentice/`). Built by `tools/assets/realistic_humans/rebuild.sh apprentice` from the `apprentice` spec (Tier 0, shared 71-bone rig, 1.60 m, modular wardrobe). Outfits in `outfits.json`: `work` (default), `almshouse` (unshod), `street`, `travel`. Both player spawn points (`MapViewRuntimeBootstrap.PLAYER_RIG_SCENE`, `WorldHost.PLAYER_RIG_SCENE_PATH`) use it. Kalev's own scene is unchanged and is still used for tests and the master-smith NPC. Verify: `--filter=test_apprentice_rig`. No portrait yet (portraits need the local ComfyUI flow), and the teen move set is SD-11.

## Player-facing design

- **Physical world:** realistic, no magic. The hero can walk, observe, hide, talk, and, at a cost, strike.
- **Observation:** when two people are in conflict and the hero "looks closer", the world dims into a spirit duel between them. He learns moves from what he sees and can step in.
- **Own duels:** the world freezes into an arena. Opponent lines are telegraphed attacks with text; the hero dodges, guards, or answers from a reply wheel. Slow beats (confession, grief) use paced choices instead.
- **Physical blows:** stronger and safer in the moment, but they open guilt (*süü*) in the matching school. Guilt is per school, not a single score: Christian sin and absolution, folk blood-debt and cleansing, civic and faction reputation.
- **Dreams:** unresolved guilt and fear return as phantoms in the Hingepuu hub.
- **Language:** speech in German, Russian, or Middle Low German is imagery without meaning until the comprehension skill grows.
- **Oddness:** self-talk is an action with a buff. Witnesses react by faction rules.
- **Traits:** hero traits are double-edged. NPC temperament tags decide which move kinds hit them.

## Dialogue move tags (implemented, SD-02)

A dialogue record may declare a top-level `duel` and tag nodes and choices with a `move` ([`schemas/dialogue.schema.json`](../../schemas/dialogue.schema.json), shared defs in `common.schema.json`):

- `duel`: `stakes[]` (declared stakes) and `resolution_node_ids[]` (how the duel can end).
- `move` (on a node or a choice): `kind` (`attack`, `defense`, `feint`, `appeal`, `pressure`, `evade`), `element` (`fear`, `shame`, `duty`, `love`, `faith`, `coin`), optional `stakes[]` (`respect`, `secret`, `obligation`, `balance`) and `spirit_image_id`.
- Validator codes (`tools/validate_content_semantics.py`): `DUEL_MISSING` (a move without a `duel`), `DUEL_UNTAGGED` (a `duel` with no move), `DUEL_STAKE` (a stake not declared in `duel.stakes`), plus `REFERENCE` / `REACHABILITY` for an unknown or unreachable resolution node. Untagged dialogue stays valid.
- Runtime: `DialogueRunner.get_duel()` and `get_current_move()` return copies of the markup; resolved choices carry `move`. The runner only exposes the tags; the arena that uses them is SD-04. Fixture: `content/examples/valid/dialogue.test_duel.json`.
- Verify: `python3 -m unittest tests.python.test_validate_content -v`, `--filter=test_dialogue_move_tags`.

## Guilt (implemented, SD-03)

`GuiltLedger` (`scripts/state/guilt_ledger.gd`, `GameState.guilt`) keeps three independent levels, `guilt.church`, `guilt.folk` and `guilt.civic`, each 0..10. There is no combined score and it never touches the faction ledger.

- `record_act(act_id, circumstance, lethal)` adds the circumstance weights once per `act_id`: `act.self_defence` (church 1), `act.defend_other` (church 1), `act.provoked` (2/1/1), `act.unarmed_victim` (4/3/3); a lethal blow adds church 3, folk 4, civic 2. Unknown circumstances and repeated acts return `{}`.
- `debuff_tier(school)`: 0 for level 0, 1 for 1-2, 2 for 3-5, 3 for 6+. SD-07 applies the tier as the spirit-layer debuff.
- `absolve(school, amount, rite_id)` lowers one school once per rite (confession, cleansing, apology); returns the amount removed.
- Save: `guilt` section with levels, recorded act IDs and used rite IDs; saves without it load as zero guilt. Verify: `--filter=test_guilt_state`.
- Not yet wired: nothing records guilt in play (SD-07) and no rite content exists.

## Spirit arena (implemented prototype, SD-04)

- **Model:** `SpiritDuel` (`scripts/combat/spirit_duel.gd`) is a dialogue presenter that runs a tagged dialogue record as a fight on top of `DialogueRunner` (text, choices, effects, `once`) and `CombatVitals` / `CombatDefensePose`. Hero composure is `CombatVitals.health` (100), resolve is stamina (100); the opponent's pressure is health (60). `hero_id` (default `char.apprentice`) marks which speaker is the hero.
- **Telegraphed blows:** an opponent line whose move is `attack` (20), `pressure` (14) or `feint` (10) opens a 1.2 s window. Hold guard (`player_guard`) to block at a resolve cost; raising it within the last 0.18 s parries, which returns 15 pressure; `player_dodge` avoids the blow once for 25 resolve. Other moves are spoken without a blow.
- **Replies:** the hero's choices carry moves. A reply counters the incoming kind (defense beats attack, attack beats feint, feint beats defense, appeal and pressure beat each other) for 30 pressure; the same element adds 8; an untagged reply deals 0; a neutral reply 12; being countered 4. Each exchange restores 25 resolve.
- **Ending:** reaching a `duel.resolution_node_ids` node wins and reports `resolution_node_id` and whether the opponent was `broken` (pressure 0). Composure 0 loses; `retry()` restores the `EncounterCheckpoint` armed at the start and restarts with fresh vitals.
- **Screen:** `SpiritArenaHost` (`scripts/combat/spirit_arena_host.gd`) freezes the world (`SceneTree.paused`, restored on close), shows the line, bars and reply buttons, and works with keyboard, mouse and gamepad. `open(content_db, state, dialogue_id)`, `close()`, signals `opened` / `closed(outcome)`. It refuses a record without a `duel`.
- **Verify:** `--filter=test_spirit_arena`; frames with `tools/godot_render.sh --resolution 1280x720 --script tools/capture_spirit_arena.gd`.
- **Limits:** no scene mounts the host yet (SD-05 wires the prologue); no spells or hero moves beyond replies; no guilt hook (SD-07); NPC temperaments do not change damage yet (SD-15); the numbers are prototype values.

## Traits and temperaments (implemented, SD-15)

- **Hero traits** (`SpiritTraits.TRAITS`, `GameState.grant_trait(id, origin)`): `trait.hears_fear`, `trait.watchful`, `trait.stubborn`. Each comes in two variants by how it was gained, `gift` or `scar`, and every variant has both a boon and a cost (checked by `SpiritTraits.is_double_edged`). Modifiers: reply damage by element, incoming blows by kind, dodge cost, parry window, composure. A trait is held once; saved under `traits` (optional in older saves).
  - `hears_fear`: gift fear replies x1.25 but pressure blows x1.15; scar fear x1.1, pressure x1.3, composure -10.
  - `watchful`: gift parry window +0.07 s, dodge cost +5; scar +0.04 s, dodge cost +10.
  - `stubborn`: gift composure +15, shame replies x0.8; scar composure +5, love replies x0.75.
- **Opponent temperament:** an optional `duel.temperament` list on the dialogue record (`impulsive`, `procrastinator`, `creative`, `proud`, `anxious`) scales the damage of the hero's reply kinds (for example impulsive: defense x1.3, evade x1.2, appeal x0.7; creative: feint x0.6, appeal x1.3). Tags multiply and the product is clamped to 0.5..2.0. Fixture: `content/examples/valid/dialogue.test_duel_temperament.json`.
- Applied inside `SpiritDuel` together with guilt and counters. Verify: `--filter=test_spirit_traits`.
- **Limits:** nothing grants a trait in play yet (no content or choice calls `grant_trait`), the three traits are examples, and no prologue duel declares a temperament.

## Talking to yourself (implemented, SD-09)

- **Action:** `player_self_talk` (`T` on keyboard, left trigger on gamepad; rebindable under Combat). `Player.perform_self_talk()` runs `SelfTalk` (`scripts/player/self_talk.gd`): a 12 s, 20% incoming-damage reduction through `CombatTimedModifiers` (id `self_talk`), then a 20 s cooldown. `Player.self_talk_performed(result)` carries the result.
- **Witnesses:** nodes in the `self_talk_witnesses` group within 420 px that implement `witness_info()` -> `{id, faction}`. `NPC` joins the group and exposes `witness_faction` (a `FactionLedger` id such as `livonian_order`); it is the only witness class so far.
- **Reaction table** (fixed, no randomness): `livonian_order` suspicion (standing -1, city suspicion +1); `danish_crown`, `hanseatic` contempt (suspicion +1); `pskov_novgorod` unease (suspicion +1); `harju_kings`, `black_cloaks` awe (standing +1); `cult_metsik` recognition (standing +1); `vitalienbruder` amusement (nothing); unaffiliated townsfolk unease (suspicion +1, capped by `PRESSURE_MAX`).
- **Once per witness per save:** the memory `memory.<witness>.saw_self_talk` marks a witness as having reacted; standing changes are faction events `faction.event.self_talk.<witness>`.
- Verify: `--filter=test_self_talk` (also `test_input_bindings` for the new action).
- **Limits:** the 3D city NPCs and map-view actors are not witnesses yet; there is no HUD cue for the buff or its cooldown; the buff does not touch the spirit arena.

## Language comprehension (implemented, SD-08)

- **State:** `GameState` keeps comprehension 0..100 per language: `lang.estonian` (always 100), `lang.german`, `lang.latin`, `lang.russian`, `lang.danish`. The orphan starts with a little Latin (20) and street German and Russian (10 each). `train_language(id, amount)` raises it; `language_tier(id)` is 0 imagery (<20), 1 fragments (20-49), 2 gist (50-79), 3 fluent (80+). Saved under `language_comprehension` (optional in older saves).
- **Content:** a dialogue node may set `language`, `gist` (shown at tier 1) and `imagery` (shown at tier 0); a choice may set `comprehension: {language, min_tier}` to stay disabled, with a reason, until the hero understands enough. Fixture: `content/examples/valid/dialogue.test_language.json`.
- **Rendering:** `DialogueLanguage.render` (used by `DialogueRunner`) shows imagery, then the gist, then the real line at tier 2 and above. Nodes without `language`, or in Estonian, are unchanged.
- **Spirit layer:** while a line is not readable (tier below 2) the arena shows only the kind of blow, not its element or stakes (`SpiritDuel.kind_only`), and watching such a conflict teaches no move.
- **Accessibility:** Settings -> Dialogue -> "Always translate foreign speech" (`DialogueSettings.always_translate`) shows every line in full; imagery is never the only channel.
- Verify: `--filter=test_language_comprehension`.
- **Limits:** nothing trains languages in play yet (no teacher, book or conversation content); only one fixture uses it; voice playback is not changed.

## Hybrid combat and guilt (implemented, SD-07)

- **Hook:** after every player melee pulse, `Player._on_attack_impact` calls `PhysicalBlowGuilt.record_hits(SessionState.state, targets)`. Only targets that implement `guilt_context()` carry guilt (training dummies do not). `CombatRoomEnemy` implements it: `guilt_actor_id` (default the lowercase node name), `guilt_armed` (false makes it an unarmed victim), `guilt_defending_other`.
- **Circumstance** (`PhysicalBlowGuilt.classify`): animal -> none; an aggressor (it had already noticed the hero before the first blow: detect, chase, telegraph or attack) -> `act.self_defence`, or `act.defend_other` when the hero protects someone; unarmed and not an aggressor -> `act.unarmed_victim`; otherwise (a calm armed guard) -> `act.provoked`.
- **Once per act:** a target records `act.<id>.blow` once however many swings land, plus `act.<id>.kill` (`GuiltLedger.record_kill`, the lethal weight only) once when it dies.
- **Spirit debuffs:** a reply of an element is weakened by 15% per debuff tier of its school (floor 40%): faith and shame by church, love and fear by folk, duty and coin by civic. The opponent's blows are sharpened by 10% per tier summed over all schools (cap 1.6). Both apply inside `SpiritDuel`.
- Verify: `--filter=test_hybrid_combat_guilt`.
- **Limits:** no content gives a rite to lower guilt yet; dialogue-flag blows such as `flag.prologue.struck_porter` are not converted into guilt yet; enemies other than `CombatRoomEnemy` and any NPC without `guilt_context()` carry none.

## Observation mode (implemented prototype, SD-06)

- `SpiritObservation` (`scripts/combat/spirit_observation.gd`) plays a tagged dialogue record with no input: `begin(runner, content_db, state, dialogue_id)`, `step()`, `play_all()`. It refuses a record without a `duel`. Choices in an observed record are taken in authored order (first enabled), so the outcome is deterministic.
- **Learning:** every move the hero sees is learned once through `GameState.learn_move`, with the stable id `move.<kind>.<element>` (for example `move.attack.shame`); saved under `learned_moves` (optional in older saves). Watching again teaches nothing new. Nothing consumes learned moves yet (the arena does not gate replies on them).
- **Intervention:** `intervene(speaker_id)` sides with a participant once before the conflict ends and sets `flag.duel.<dialogue_id>.sided_with.<speaker_id>`. No consequence reads the flag yet.
- **Screen:** `SpiritArenaHost.observe(content_db, state, dialogue_id)` dims and freezes the world, shows each line with its move, auto-advances every 2.4 s (`interact` skips ahead), offers "Side with ..." buttons, and reports `moves_learned` when closed.
- Verify: `--filter=test_spirit_observation`, frame `observation.png` from `tools/capture_spirit_arena.gd`.

## Prologue content (implemented prototype, SD-05)

[`content/prologue/`](../../content/prologue/README.md) holds the almshouse opening: an observed matron-versus-porter quarrel (4 tagged nodes, hero not involved), the hero's first own duel against the porter (7 nodes, three resolutions: `resolved_spared`, `resolved_punished`, `resolved_struck`), Kalev taking the apprentice (`flag.prologue.apprenticed`), and three cast records. The `[Shove him away]` choice is the physical option: it ends the duel at once and sets `flag.prologue.struck_porter`, which the guilt hook (SD-07) will read. Verify: `--filter=test_spirit_prologue`, `python3 tools/validate_content.py content/prologue content/examples/support content/examples/valid`.

**Authoring-cost note:** tagging a node costs one `move` line (kind, element, stakes); the real cost is designing each exchange so the counters and elements make sense (about the work of writing a normal branching scene twice over for the duel scenes). Both duel scenes plus the Kalev scene and three characters were written in one pass. Not yet wired to a location, observation mode (SD-06) or the hero spawn.

## Planned entry points

The runner accessors and the spirit arena above are the entry points. First deliverable is a one-scene prototype (the almshouse quarrel) with schema fields, a validator check, and an arena host built on the existing combat feel. Tasks are to be created on the project board with allowed files and verification.

## Save state and IDs

Stable IDs in use: `guilt.church`, `guilt.folk`, `guilt.civic`, `act.*`, `rite.*`, `move.<kind>.<element>`, `lang.*`. Also in use: `trait.*`. Planned: `skill.language.*`; duel records `duel.*`. Guilt and comprehension must save and load through `GameState` ([`STATE_AND_SAVES.md`](./STATE_AND_SAVES.md)).

## Verification

Not yet available. Planned: a content-validator test for tagged dialogue and a Godot test for guilt weights and save round trip.

## Limits

- The hybrid combat balance (physical versus spiritual) needs tuning against the prototype.
- Over-tagging every conversation is out of scope; only key conflicts are tagged.
