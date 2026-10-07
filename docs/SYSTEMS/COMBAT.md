# Combat runtime

Status: foundation implemented (tasks **P1-024..P1-027**, **P2-009**, **P5-008**, **R-722/R-725**); tower boss encounters are modelled and tested but not wired into their interior scenes (see [Limits](#limits)). Scope: vitals, defense, melee resolution, enemy AI, encounter outcomes and retry, forge techniques, mission allies, boss encounter packages. Related:

- Design contract for hammer combat and night missions: [`COMBAT_NIGHT.md`](./COMBAT_NIGHT.md).
- Kalev's move sets, chains, evasion, and animation timing: [`COMBAT_ANIMATION.md`](./COMBAT_ANIMATION.md).
- Spells: [`MAGIC.md`](./MAGIC.md).
- Spirit-world dialogue duels built on this vitals and defense model: [`SPIRIT_DIALOGUE.md`](./SPIRIT_DIALOGUE.md#spirit-arena-implemented-prototype-sd-04).

## Player-facing behavior

- Attack (light chain, hold for heavy), guard (hold or toggle, per [settings](./SETTINGS_AND_ACCESSIBILITY.md)), sidestep, roll. A timed guard inside the parry window parries. Dodges and post-hit invulnerability beat hits.
- Health and stamina bars over every combat actor; the combat feedback HUD prints readable enemy phases (detect, telegraph, attack, react, disengage).
- Enemies telegraph before striking, retreat when wounded unless cornered, and disengage past their leash.
- Losing a fight restores the encounter checkpoint: narrative progress made before the fight survives, the fight restarts.
- Encounters can close lethally or non-lethally (surrender, flee, bypass, talk). Both paths write the same quest state vocabulary.
- **Forge techniques** (quick menu **Iron**): one equipped technique, `Iron`, `Ember`, or `Root`. Iron pierces a braced guard outside the parry window.

## Runtime pieces

| Piece | File | Role |
|---|---|---|
| `CombatVitals` | `scripts/combat/combat_vitals.gd` | Health, stamina, death, and incoming-hit resolution (guard, parry, dodge, i-frames) for player and enemies; reads `CombatTimedModifiers`. |
| `CombatDefensePose`, `CombatHitResult` | `scripts/combat/` | Defensive snapshot at hit time; hit outcome. |
| `AttackProfile`, `AttackProfileResolver` | `scripts/combat/` | Damage, reach, stamina, damage type from the equipped item's `gameplay.attack_profile`, scaled by the active `CombatMove`. |
| `MeleeAttackResolver` | `scripts/combat/melee_attack_resolver.gd` | One deterministic strike pulse on the 2D logic plane. A pulse ID stops double hits. |
| `CombatKnockbackEffect`, `CombatStaggerEffect`, `CombatTimedModifiers` | `scripts/combat/` | Reusable status modules that magic and techniques apply. |
| `EnemyArchetype` | `scripts/combat/enemy_archetype.gd` | Tunable profiles: `watchman`, `sergeant`, `knight_order`, `crossbowman`, `bandit`. |
| `EnemyCombatStateMachine` | `scripts/combat/enemy_combat_state_machine.gd` | One shared AI loop: patrol → detect → chase → telegraph → attack → react/retreat → disengage. |
| `CombatRoomEnemy`, `CombatTrainingDummy` | `scripts/combat/` | Scene hosts for the AI and a dummy using the same vitals. |
| `EncounterOutcome`, `EncounterOutcomeDefinition`, `EncounterOutcomeResolver` | `scripts/combat/` | Shared lethal/non-lethal close vocabulary, mapped to quest states by `encounter.*` content. |
| `EncounterCheckpoint` | `scripts/combat/encounter_checkpoint.gd` | Retry checkpoint armed at encounter start. |
| `ForgeTechnique` | `scripts/combat/forge_technique.gd` | Technique layer on attack profile and vitals. Never a parallel state machine. |
| `MissionAllyController`, `MissionAllyScript` | `scripts/combat/` | Scripted Act 2 allies that heal or bolster automatically. No party control. |
| `PlayerActionStateMachine` | `scripts/player/` | Player action timing ([`COMBAT_ANIMATION.md`](./COMBAT_ANIMATION.md)). |

## Where combat happens

| Scene | Purpose |
|---|---|
| `scenes/tests/combat_room.tscn` | Test room with every archetype and the feedback HUD |
| `scenes/tests/night_encounter_stub.tscn` | Night-encounter host |
| `scenes/reval_east/workers_district_bandit.gd` | Bandit fight in the Workers' District |
| Bitter Brew night checkpoint | `BitterBrewNightConsequence`, `encounter.watch_checkpoint` ([`QUESTS.md`](./QUESTS.md)) |

## Guilt for physical blows

Player melee hits on actors with `guilt_context()` (all `CombatRoomEnemy`) record per-school guilt through `PhysicalBlowGuilt` (ADR 0033); see [`SPIRIT_DIALOGUE.md`](./SPIRIT_DIALOGUE.md#hybrid-combat-and-guilt-implemented-sd-07). Damage and encounter outcomes are unchanged.

## Content

`type: encounter` ([`schemas/encounter.schema.json`](../../schemas/encounter.schema.json)) maps outcome kinds to quest states: `encounter.watch_checkpoint`, `encounter.nunnatorn_boss`, `encounter.kuldjala_boss`, `encounter.rentenitorn_boss`. Weapon numbers live on items (`gameplay.attack_profile`, `gameplay.weapon_class`, [`schemas/item.schema.json`](../../schemas/item.schema.json)).

## Towers and bosses

**Frozen by [ADR 0033](../adr/0033-teen-protagonist-and-spirit-dialogue-combat.md):** no new tower or boss work. The code below is kept because the three tower interior maps and their tests validate against `EnterableTowerContract`; whether to delete it is decided at the SD-16 review.

`EnterableTowerContract` and `CompletedTowerPackages` (`scripts/tower/`) define the four completed 1343 tower packages ([`reval_fortifications_1343.md`](../reports/reval_fortifications_1343.md)). Each tower boss has an encounter adapter and a durable state model (door, outcome, rewards, retry markers survive re-entry and save/load):

| Tower | Encounter | State model | Interior scene | Alternate (non-lethal) branch |
|---|---|---|---|---|
| Nunnatorn | `NunnatornBossEncounter` | `NunnatornStateModel` | `scenes/reval_monastery/nunnatorn_interior.tscn` | Parley; evidence via `NunnatornEvidenceModel` |
| Kuldjala | `KuldjalaBossEncounter` | `KuldjalaStateModel` | `scenes/reval_monastery/kuldjala_interior.tscn` | Expose the warden's illicit repair ledger |
| Rentenitorn | `RentenitornBossEncounter` | `RentenitornStateModel` | `scenes/reval_north/rentenitorn_interior.tscn` | Serve the sealed rent tally; strongroom unseals |

## Verify

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_combat
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_enemy
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_encounter
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_nunnatorn
```

## Limits

- The three boss encounters and state models are used only by tests and acceptance tools. The interior scenes exist (Nunnatorn and Rentenitorn have active transitions) but do not instantiate their boss encounter. Open work is listed in the [code-health audit](../reports/code_health_audit_2026-10-07.md).
- `MissionAllyController` is exercised by tests only; no Act 2 mission scene mounts it yet.
- Enemy move sets, root motion, and authored clips are out of scope ([`COMBAT_ANIMATION.md`](./COMBAT_ANIMATION.md) §9).
