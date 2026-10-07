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

## Dialogue move tags (planned content shape)

Per node, in addition to the fields in [`DIALOGUE.md`](./DIALOGUE.md#content): `move_kind` (attack, defense, feint, appeal, pressure, evade), `element` (fear, shame, duty, love, faith, coin), `stakes[]` (respect, secret, obligation, balance), and `spirit_image_id`. The validator must reject a tagged duel with missing stakes or an unreachable resolution.

## Planned entry points

None exist yet. First deliverable is a one-scene prototype (the almshouse quarrel) with schema fields, a validator check, and an arena host built on the existing combat feel. Tasks are to be created on the project board with allowed files and verification.

## Save state and IDs

Planned stable IDs: `guilt.church`, `guilt.folk`, `guilt.civic`; `trait.*`; `skill.language.*`; duel records `duel.*`. Guilt and comprehension must save and load through `GameState` ([`STATE_AND_SAVES.md`](./STATE_AND_SAVES.md)).

## Verification

Not yet available. Planned: a content-validator test for tagged dialogue and a Godot test for guilt weights and save round trip.

## Limits

- The hybrid combat balance (physical versus spiritual) needs tuning against the prototype.
- Over-tagging every conversation is out of scope; only key conflicts are tagged.
