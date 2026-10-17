# Combat runtime

Status: foundation implemented (tasks **P1-024..P1-027**, **P2-009**, **P5-008**, **R-722/R-725**); forge weapon set, axe/bow/shield classes and brawls with citizens implemented (tasks **R-1754**, **R-1755**, **R-1756**); tower boss encounters are modelled and tested but not wired into their interior scenes (see [Limits](#limits)). Scope: vitals, defense, melee resolution, enemy AI, encounter outcomes and retry, forge techniques, mission allies, boss encounter packages. Related:

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
- **New Game starts unarmed:** no weapon is granted to the bag or either hand. Six forge weapons stand by the anvil in Kalev's smithy; pick one up, then choose and equip it from the bag. A taken weapon never respawns. Existing saves keep their recorded equipment.
- Every city resident has health and stamina. Strike one and a physical fight starts: men fight back, others run ([Brawls with citizens](#brawls-with-citizens)).
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

## Forge weapon set

Status: implemented (tasks **R-1754** models, items and forge pickups; **R-1755** equip and attack per class). Out of scope: arrow ammunition (the bow never runs out), inventory icons, shield bash, enemy use of bows.

**What the player does.** The new-game character starts without a weapon in either hand or in the bag; previously saved equipment remains unchanged. In Kalev's city smithy (`loc.reval_city`) six weapons stand on a wall shelf (`weapon_shelf` dressing, right of the yard door) in the seamless city forge bay, where New Game starts you facing it. The retired standalone 2D forge scene is inactive; old transitions redirect here. Hover a weapon with the mouse and it gets a gold contour and a tooltip; there is no floor marker. Click it (or stand by it and press interact) to put it in the bag. Picking is done in screen space against the drawn model, so shelf height does not matter. Open the bag, select the weapon and equip it: sword, axe, war hammer and spear go to the **right hand**, the bow and the shield to the **left hand**. The equipped weapon appears in the hero's hand in the 3D view. Attack as usual (tap for the light chain, hold for the heavy strike, see [`COMBAT_ANIMATION.md`](./COMBAT_ANIMATION.md)). Use **G** to draw or sheathe the equipped weapon; attack with the normal attack input. Hold guard to benefit from the shield when it is equipped in the left hand.

| Item | Slot | Class | Behaviour |
|---|---|---|---|
| `item.forge_arming_sword` | right hand | sword | balanced cut and thrust chain |
| `item.forge_bearded_axe` ("Peasant axe", R-2009) | right hand | axe | slow heavy chops; hold for a two-handed cleave |
| `item.forge_war_hammer` | right hand | hammer | crushing blows; hold for an overhead smash |
| `item.forge_spear` | right hand | spear | long reach; the heavy lunge pierces a guard |
| `item.forge_longbow` | left hand (two-handed) | bow | every attack looses an arrow along the facing (~20 m), a three-shot volley; hold for a full draw (more damage, x1.3 range, pierces guard). Equipping it returns the right-hand item to the bag |
| `item.forge_heater_shield` | left hand | - | while guarding: stamina cost per blocked damage 1.0 -> 0.45, parry window 0.18 -> 0.26 s |

**Runtime pieces.**

| Piece | File | Role |
|---|---|---|
| Weapon models | `tools/assets/build_forge_weapons.py` -> `assets/props/weapons/<slug>/<slug>.glb` (the axe is the modelled `axe_peasant` variant, [`EQUIPMENT_VARIANTS.md`](./EQUIPMENT_VARIANTS.md)) | Deterministic Blender geometry; origin at the right-hand grip, long axis +Y. Rebuild: `blender --background --factory-startup --python tools/assets/build_forge_weapons.py -- --preview` |
| Held / world scenes | `assets/props/weapons/<slug>/<slug>_held.tscn`, `<slug>_ground.tscn` | Hand-slot rotation (item `equip.scene`) and the leaning display (item `equip.world_scene`, read by `WorldItemController`) |
| Forge pickups | `WorldItemController.SEED_GROUPS` (`scripts/world/world_item_controller.gd`), installed by `scenes/world/reval_city/reval_city.gd` | Seeded once per save under `loc.reval_city#forge_weapons`; a taken weapon never respawns. Stable object ids `world.forge_<slug>`; `height`/`yaw_deg` per entry only pose the 3D view (shelf top, lean onto the wall) |
| Move sets | `CombatMoveCatalog.CLASS_AXE`, `CLASS_BOW`; clips in `SharedCharacterRig.CANONICAL_ANIMATIONS` | Axe and bow rows in [`COMBAT_ANIMATION.md`](./COMBAT_ANIMATION.md) |
| Arrow | `scripts/combat/arrow_projectile.gd` (`ArrowProjectile`) | Item `gameplay.ranged` (`range_px`, `speed_px_per_sec`) fills `AttackProfile.ranged_*`; `Player._on_attack_impact` looses an arrow instead of a melee pulse. Straight, deterministic flight; stops at the first wall (physics frames only) or the first actor on its path; hits record guilt like a blow. `MapViewMagicVfx.play_arrow` draws the shaft |
| Shield | `scripts/combat/shield_guard.gd` (`ShieldGuard`) | Item `gameplay.shield_guard` replaces `CombatVitals.guard_stamina_per_damage` and `parry_window_sec` right before each incoming hit |

**Data.** Schema fields in [`schemas/item.schema.json`](../../schemas/item.schema.json): `weapon_class` now also `axe` and `bow`; `ranged`; `shield_guard`; `two_handed` (`GameState.equip_from_bag` frees the other hand); `equip.world_scene`. Assets are listed in `assets/SOURCES.csv` (`assets.props.weapons.*`).

**Save/load.** Picked-up and equipped weapons use the existing bag, equipment and world-item persistence; the seed-group flag is saved in `world_defaults_seeded`.

**Verify.** `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_forge_weapons`; visual grip check `tools/godot_render.sh --script tools/capture_forge_weapons.gd` (writes `docs/reports/images/combat/forge_weapons/`, summarised in `grip_sheet.jpg`); gameplay capture of the forge row, pickup and equip, and a city brawl: `tools/godot_render.sh --resolution 1600x900 res://tools/capture_forge_brawl.tscn -- --city-spawn=poi.forum --city-hour=11`.

## Peaceful and armed stance (R-1886)

Status: implemented (task **R-1886**, [ADR 0047](../adr/0047-interaction-stances-and-conversation-camera.md)). Out of scope: a sheathe animation and a scabbard or back slot for the weapon (it is simply hidden), auto-sheathing after a fight.

- The hero starts **peaceful**: the equipped weapon is hidden and the primary click never swings. A click on a person talks ([`DIALOGUE.md`](./DIALOGUE.md#talk-to-anyone-r-1887)), on a thing uses it, on open ground does nothing.
- `G` (gamepad Share) **draws** or sheathes. Drawn, the click is the normal attack chain (tap light, hold heavy).
- The attack button (gamepad X) on a sheathed hero draws first; the next press strikes. Clicking a real hostile (`combat_damageable`) draws and strikes in one go.
- Talking to someone sheathes.
- Runtime: `Player.weapon_drawn`, `set_weapon_drawn()`, `toggle_weapon_drawn()`, signal `weapon_drawn_changed` (`scripts/player.gd`); `MapClickInputController._is_armed` and the person deferral (`click_person_pickers` group); `MapViewRuntimeActors._apply_weapon_stance` hides or shows the hand slots. Not saved: a load starts sheathed.
- Verify: `--filter=test_character_conversation,test_map_click_input_controller`.

## Brawls with citizens

Status: implemented (task **R-1756**). Scope: census residents in the seamless city (`CityCitizens`). Lightning can fell or wound a resident too, without starting a fight ([lightning strikes](./SKY_ATMOSPHERE.md#lightning-strikes)). Out of scope: named NPCs (`CityNamedNpcs`) and ambient site workers, guards joining a fight, Living City Fear, legal consequences, saving injuries or the fallen (they last for the session), body looting.

**What the player does.** Draw the weapon (`G`, [stance](#peaceful-and-armed-stance-r-1886)), then swing it (or fists) or shoot an arrow at any resident. Nothing happens to people you do not actually hit: clicking a resident still opens the information panel, and a peaceful resident never attracts soft-lock or click attacks. Once struck:

- **Men aged 16-55, and anyone on watch duty, fight back.** They close in, telegraph (guard pose), strike, back off when badly hurt, and give up when the hero is more than 10 m away. Townsmen punch; the watch uses its spear or sword. Their blows go through the hero's guard, parry and dodge.
- **Women, children and the elderly run** directly away for up to 7 s (or until 10 m away), then walk back to where their day should take them.
- Health and stamina bars hover over anyone fighting or fleeing (health on top, stamina below). Attacks cost the resident stamina; a winded resident cannot strike until it recovers.
- At 0 health the resident falls (`fall`) and stays down where they fell for the session, even after walking away and coming back.

**Stats.** `CitizenBrawler.stats_for(record)`: health 60 (men) or 45 (women), 25 for children under 14, -20 over 60; build +-; heavy trades (smith, brickmaker, porter, mason, ...) +10 health and stamina and harder punches; the watch kit +15. Deterministic from `content/world/reval_city/citizens.json`.

**Runtime pieces.**

| Piece | File | Role |
|---|---|---|
| `CitizenBrawler` | `scripts/city/citizen_brawler.gd` | Per-resident `CombatVitals`, mode (calm, fight, flee, return, down), the shared `EnemyCombatStateMachine` with a `enemy.townsman` archetype. Created lazily on the first blow |
| `CitizenActor` | `scripts/city/citizen_actor.gd` | `take_damage`, `guilt_context`, `is_combat_dead`; health/stamina properties for the bars; while a brawl owns it, it moves by the fight (walls collide) instead of the timetable |
| `CityCitizens` | `scripts/city/city_citizens.gd` | Keeps brawlers by resident index while bodies are pooled, ends a fight broken off by distance, lays the fallen back down, adds and removes the bars |
| Bystander group | `MeleeAttackResolver.BYSTANDER_GROUP` (`combat_bystander`) | Peaceful residents: hit by real swings and arrows, ignored by `PlayerPrimaryAction` clicks and soft-lock. A resident who fights back moves to `combat_damageable` |
| Bars | `CharacterHealthRing3D.set_stamina` | Thin stamina strip under the health bar; `MapViewRuntimeActors` feeds it from any actor with `stamina` / `max_stamina` |

**Guilt.** Every blow on a resident records guilt through `PhysicalBlowGuilt` (ADR 0033): the first blow on a peaceful resident is `act.unarmed_victim` (or `act.provoked` for the armed watch); a resident who had already turned on the hero is self-defence. A fall counts as a kill.

**Verify.** `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_citizen_brawl`; the gameplay capture above saves `brawl_man_fights_back_close` and `brawl_bystander_flees`.

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
- Forge weapons: no arrow ammunition, no inventory icons yet; the bow is canted about 36 degrees in both idle and draw (one grip transform serves both poses).
- Brawls: only census residents take part; named NPCs, guards joining, Fear and legal consequences, and saving injuries are follow-ups.
