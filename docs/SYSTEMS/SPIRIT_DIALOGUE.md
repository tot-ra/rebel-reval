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

## Planned entry points

The runner accessors and the spirit arena above are the entry points. First deliverable is a one-scene prototype (the almshouse quarrel) with schema fields, a validator check, and an arena host built on the existing combat feel. Tasks are to be created on the project board with allowed files and verification.

## Save state and IDs

Stable IDs in use: `guilt.church`, `guilt.folk`, `guilt.civic`, `act.*`, `rite.*`. Planned: `trait.*`; `skill.language.*`; duel records `duel.*`. Guilt and comprehension must save and load through `GameState` ([`STATE_AND_SAVES.md`](./STATE_AND_SAVES.md)).

## Verification

Not yet available. Planned: a content-validator test for tagged dialogue and a Godot test for guilt weights and save round trip.

## Limits

- The hybrid combat balance (physical versus spiritual) needs tuning against the prototype.
- Over-tagging every conversation is out of scope; only key conflicts are tagged.
