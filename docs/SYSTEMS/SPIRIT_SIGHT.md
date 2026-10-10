# Spirit sight, auras and soul lights

Status: partially implemented. The spirit sight toggle SS-1 (**R-1484**), aura profile data SS-2/SS-2b (**R-1485**, **R-1496**) and the aura look SS-3 (**R-1486**) are implemented, as are the duel layer SS-6 (**R-1489**) and duel entry SS-7 (**R-1490**); reading and duel use remain planned (epic **R-1483**, [ADR 0041](../adr/0041-spirit-sight-auras-and-soul-lights.md), accepted).

Scope: a spirit-sight layer the hero toggles anywhere on the same map, auras with seven soul lights on every person and animal, reading a soul, soul lights feeding the spirit duel, and duels that keep the building but hide furniture under a focused grade. Out of scope: a universal good/evil score, duels with animals, a separate spirit-world copy of the map, new art assets (P0-040). The duel rules themselves live in [`SPIRIT_DIALOGUE.md`](./SPIRIT_DIALOGUE.md).

Canon: the soul lights (*hingetuled*), auras and spirit sight are **`invented`**, folklore-inspired like the Hingepuu ([`CANON.md`](../CANON.md)). The seven soul lights are the seven NATURAL aspects ([`NATURAL.md`](./NATURAL.md)) shown on the body: light ids are the `aspect.*` ids and the hero's levels come from his NATURAL ranks (ADR 0041 revision, 2026-10-09). The word "chakra" is an anachronism and appears nowhere in ids or player-facing text; SS-2b (**R-1496**) implements the aspect IDs and rank reader together with SS-2.

## Three layers on one map

| Layer | Entered by | World | Hero can |
|---|---|---|---|
| Physical | default | normal grade, all props | everything |
| Spirit sight | `player_spirit_sight` toggle | same map, cold desaturated grade, props stay, auras on | walk, look, read, challenge |
| Spirit duel | Challenge from spirit sight, or a scripted duel | same place, indigo duel grade, furniture and clutter hidden, only the two fighters glow | fight ([ADR 0038](../adr/0038-realtime-3d-spirit-arena-and-topic-spells.md)) |

Nothing is loaded or unloaded between layers. A duel starts only from spirit sight and ends back in spirit sight.

## Spirit sight toggle (implemented, SS-1, **R-1484**)

Status: implemented (task **R-1484**). Scope: the toggle, the grade, the ripple, the walk-only limits and transient state. Out of scope: auras (SS-3), reading (SS-4), Challenge and duel entry (SS-7), the observation grade swap and the witness stare reaction (not wired yet, see Limits).

**Player:** press `player_spirit_sight` (`V` / gamepad left stick click, rebindable; the left stick click no longer walks) anywhere and the same place turns cold and desaturated; press again to return. A ripple spreads from the hero over 0.6 s and runs back on exit; with reduced motion it is a 0.2 s cross-fade with no ring or displacement. Settings -> Gameplay accessibility -> **Spirit sight grade intensity** (0-100 %) scales only the look.

**While on:** walk speed only (keyboard, stick and click-to-move); no attack, heavy charge, guard, sidestep, roll or self-talk. Any interaction (key, click, click-to-travel arrival, cursor pickup) leaves sight first and then runs normally; Challenge on a duel-ready person arrives with SS-7.

**Unavailable:** during dialogue (`demo_dialogue_active`), cutscenes (`cutscene_active`, joined by `CutscenePlayer` while playing), visible modal overlays (`modal_input_overlay`), a paused tree, swimming and diving, a running duel or observation, while the player is locked in an action or `combat_input_enabled` is off (scripted moves). If one of these starts while sight is on, sight drops at once on the next tick.

**Runtime:**

| Piece | File | Role |
|---|---|---|
| `SpiritSight` | `scripts/combat/spirit_sight.gd` | Child node `SpiritSight` of `Player`. Reads the input, tweens `blend`, composes the grade each frame and restores it before the next frame. |
| Ripple / tint / vignette | `scripts/combat/spirit_sight_ripple.gdshader` | Full-screen `canvas_item` pass on a CanvasLayer: blue-violet tint, soft vignette, travelling ring from the hero's screen position. |
| Walk cap and limits | `scripts/player.gd` (`is_walking`, `spirit_sight_blocked`, `leave_spirit_sight`) | |
| Exit before use | `scripts/interaction/interactable.gd`, `scripts/world/world_item_controller.gd` | |

**Grade (one recipe, never per map):** on the active camera or world `Environment`: saturation lerps to 0.25, ambient energy x0.6, ambient colour 35 % toward blue-violet, and the `Sun` light of that world x0.6; the shader adds the cold tint and the vignette. The weather keeps owning the physical values: the controller snapshots them after the weather update, grades, and restores the snapshot at the start of the next frame, so time of day and storms keep moving and the grade never compounds. Exit restores the latest ungraded values exactly.

**State:** `GameState.spirit_sight` (sight) and `GameState.spirit_encounter_active` (duel or observation) are transient and never written by `save_payload`; `load_payload` clears both and a replaced session state leaves sight. `GameState.in_spirit_world` is now derived: true in sight or an encounter. Existing duel/observation code still assigns it, which sets only the encounter flag, so ending a duel never clears sight. Spellforge casting checks `spirit_encounter_active`, so casting stays limited to duels.

**Verify:**

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_spirit_sight
tools/godot_render.sh --resolution 1280x720 --script tools/capture_spirit_sight.gd
```

Plates (day and night, physical vs sight, `smithy_courtyard`): [`../reports/images/spirit_sight/sheet.png`](../reports/images/spirit_sight/sheet.png).

**Limits:** observation mode (SD-06) still uses its own dimming; NPC stare reactions (SD-09 reuse) are not wired; Challenge waits for SS-7. The ripple origin uses the 32 px/cell logic-to-world bridge.

## Aura data (implemented, SS-2, **R-1485**)

Status: implemented (tasks **R-1485**, **R-1496**). Pure profile data and offline validation; rendering, reading, duel scaling and hero growth remain the separately gated SS-3..SS-8 tasks.

Seven lights, levels 0..5 each, plus clarity 0..1. Six lights are the duel elements, the seventh is sight:

| Light | Code id | Anchor | Element | Colour |
|---|---|---|---|---|
| 1 | `aspect.nature` | pelvis | fear | red |
| 2 | `aspect.affection` | lower spine | coin | orange |
| 3 | `aspect.tenacity` | mid spine | duty | yellow |
| 4 | `aspect.unity` | chest | love | green |
| 5 | `aspect.resonance` | neck | shame | blue |
| 6 | `aspect.awareness` | head, front | sight | indigo |
| 7 | `aspect.light` | above the head | faith | violet |

### Runtime API and precedence

`SpiritAuraProfile` (`scripts/combat/spirit_aura_profile.gd`) is a `RefCounted` value holder with `levels: Dictionary[StringName, int]`, `clarity: float` and `closed_mask: Array[StringName]`. Each call returns independent data; it does not mutate ContentDB, GameState, the RNG or any scene.

- `SpiritAuraProfile.for_character(id, content_db, state)` reads `ContentDB.get_character(id)`. Null/unloaded DB or a missing record falls back to a stable id-only profile. `from_record(id, record, state)` accepts the same fields for in-memory citizen metadata.
- For NPCs, an optional authored `aura` block wins over derivation and species defaults. It requires **all seven** `levels` (integers 0..5); optional `clarity` defaults to 1. `closed_mask` defaults to an empty array and lists unique closed (level 0) light IDs concealed from shallow reading. It does not change levels or implement reading itself.
- NPC fallback: SHA-256 of compact JSON `[id, faction, profession, sorted_unique_temperament]`. `faction` and `profession` are optional strings; `temperament` is an optional string array on the character record (not a lookup of a dialogue's duel tags). The first seven digest bytes modulo 6 give the levels; byte 7 divided by 255 gives clarity. Missing fields use empty strings/array. The fixed golden-vector test pins the result across processes; tag ordering/duplicates do not change it.
- Hero identity is `char.apprentice` or an explicit `is_player: true` record. Levels come live from `GameState.get_natural_aspect_rank` using the bands below, not from authored aura levels or separate saved lights. The light list reuses `GameState.NATURAL_ASPECT_IDS`. An authored mask may conceal currently closed lights only. Hero clarity **always** comes from live guilt: `1 - max(GuiltLedger.debuff_tier(school)) / 3`, across all three schools. Tiers 0/1/2/3 give clarity 1/0.667/0.333/0. This depicts conflict, not a summed morality score. A null state is guilt-free.
- `for_species(species)` or a record's optional `species` string uses the table below, case-insensitively. All unlisted lights are 0, clarity is 1, mask is empty. Unknown species use the default rather than humanoid derivation. The animal path does not offer a duel. An explicit authored block can override species defaults.

| Species | Nature | Unity | Awareness |
|---|---:|---:|---:|
| dog | 3 | 3 | 2 |
| horse | 3 | 2 | 1 |
| cat, cow, pig, goat | 3 | 2 | 0 |
| sheep, default/unknown | 2 | 2 | 0 |
| chicken, crow | 2 | 1 | 0 |

### Hero rank bands

`RANK_BANDS = [5, 10, 15, 25, 40]` and `level_for_rank(rank, locked=false)` define the read-only conversion:

| Stored rank | Level |
|---|---:|
| below 5, or locked | 0 |
| 5-9 | 1 |
| 10-14 | 2 |
| 15-24 | 3 |
| 25-39 | 4 |
| 40-50 | 5 |

The reader uses **stored** ranks, not temporary psyche-effective ranks. `level_for_rank(rank, true)` closes a locked aspect, but `natural.lock_aspect` is currently contract-only and GameState exposes no lock state. Runtime lock wiring must accompany that feature; SS-2b does not invent flags or a second persistence source.

### Authoring and validation

```json
"aura": {
  "levels": {
    "aspect.nature": 0, "aspect.affection": 1, "aspect.tenacity": 2,
    "aspect.unity": 3, "aspect.resonance": 4, "aspect.awareness": 5, "aspect.light": 1
  },
  "clarity": 0.75,
  "closed_mask": ["aspect.nature"]
}
```

The optional block and metadata are defined in `schemas/character.schema.json`. Existing records without an aura remain valid. The semantic validator emits `AURA_LIGHT` for unknown light IDs (levels or mask) or duplicate mask IDs; `AURA_LEVEL` for non-integer/out-of-range levels or masking a non-closed light. Structural errors, missing levels and clarity outside 0..1 emit `SCHEMA`. Aura diagnostics run before schema rejection, so the stable codes are not hidden by a schema error. Valid/invalid fixtures live in `content/examples/{valid,invalid}/character.aura*.json`.

### Persistence, verification and limits

No new save fields in SS-2/SS-2b. NPC/species profiles are rebuilt from content; hero levels and clarity are recalculated from the existing persisted NATURAL ranks and guilt ledger, including after save/load. The revised apprentice NATURAL baseline (nature 10, unity 10, awareness 15, others 5) belongs to SS-8 (**R-1491**); until then the runtime flat baseline 5 reads as level 1 for every aspect. Spending existing NATURAL points changes a light as soon as its rank crosses a band. No `soul_lights` save section is introduced. No scene mounts or presentation are added here: SS-3 (**R-1486**) consumes these data for rendering, SS-4/SS-5 for reading and duel rules. Keyboard/gamepad input is unchanged.

```bash
python3 -m unittest tests.python.test_validate_content -v
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_spirit_aura_profile
python3 tools/validate_content_examples.py
```

Tests cover the cross-process hash vector, metadata changes and tag reordering, independent copies, missing records, authored/default precedence, ranges and masks, all guilt tiers/schools, all rank-band boundaries and lock conversion, live NATURAL point spending and save/load, species and element mapping.

- **Meaning, not morality:** bright lights = a strong soul, a closed light (level 0) = a weak point, low clarity = a troubled soul. The aura never says whether someone is good.

## Aura look (implemented, SS-3, **R-1486**)

Status: implemented (task **R-1486**). Scope: drawing every nearby person and animal's aura while spirit sight is on, the LOD budget and reduced flashing. Out of scope: reading (SS-4), duel dimming and the break scatter (SS-5), the awareness-driven sight radius (SS-8), automatic animal registration (see Limits).

What the player sees when sight fades in (the auras fade with the sight `blend`, so they come and go with the ripple):

- **Seven lights** on fixed body positions in NATURAL aspect order: pelvis floor, lower belly, solar plexus, sternum, mid neck, forehead, and the violet light resting on the crown of the skull, coloured red, orange, yellow, green, blue, indigo, violet. The level sets size and brightness: 0 a dark knot with thin flickering cracks of its colour, 1 ember, 2 glow, 3 bright, 4 radiant with a corona of rays, 5 blazing. Every light breathes slowly (about 0.2 Hz, phase-shifted per light). Position, not colour alone, tells which light is which.
- **Field lines:** twelve closed loops shaped like a magnetic dipole. Each climbs the spine through the seven lights (root to crown), spills over the head, bows out around the body, dips under the pelvis and flows back into the root. Comets of light run round the loops; the line colour blends the lights beside it, brighter lights give brighter and wider lines, the mean level sets the speed and the spread. Low clarity carries the lines through a divergence-free (curl) field in small jerks and lays dark smoke streaks along them.
- **Sky beam** (the tie to the sky, maintainer request 2026-10-09): a violet-white column rising from the crown light, with pulses climbing it. Strength = (sum of all seven levels / 35) x (0.4 + 0.6 x crown level / 5), so every light together feeds it and the crown gates it: a closed or absent crown has no beam, a whole soul at 5 has a full one 12 m high. Weak souls show a thin short thread. Low clarity makes the beam stutter in broken pieces; reduced flashing slows the pulses and stills the stutter. It shows strength, not virtue. Full tier only; animals have no crown light and no beam.
- **Shell:** a faint fresnel rim hugging the torso and head, tinted by the level-weighted light colour.
- **Animals:** the same picture fitted to the animal's mesh bounds, lights along the back from the hindquarters (nature) to the head (awareness), scaled to the body. Lights a species does not have are absent rather than knots, so a dog shows no false weak point.

### Runtime

| Piece | Path | Role |
|---|---|---|
| `SpiritAuraView` | `scripts/combat/spirit_aura_view.gd` | One aura: three draw calls (ribbons, shell, lights) on shared meshes built once; updates the seven anchor uniforms every frame, never the meshes. Tiers `NONE`, `GLOW`, `FULL`. |
| `SpiritAuraManager` | `scripts/combat/spirit_aura_manager.gd` | Budget and visibility; mounted as `SpiritAuras` under the SS-1 controller (`scripts/combat/spirit_sight.gd`) and fades with its `blend`. |
| Flow shader | `scripts/combat/spirit_aura_flow.gdshader` | Dipole field-line loops and the fresnel shell (`shell_mode`). |
| Light shader | `scripts/combat/spirit_aura_light.gdshader` | The seven billboarded lights and the sky beam (quad 7, upright billboard, `beam_strength`) in one draw call, or one soft glow (`glow_only`). |
| Anchor list | `SharedCharacterRig.SPIRIT_AURA_ANCHORS` | The one const list of anchors: a point along a bone segment (`hips`, `spine`, `chest`, `head`; the rig has no neck bone) plus a forward offset. Rigs join group `spirit_aura_bearer`. |

- **Budget** (`SpiritAuraManager.assign_tiers`): nearest first from the hero rig (`PlayerRig`), ties in candidate order. The 12 nearest within the sight radius get a full aura, every other being within 40 m gets a single soft glow, nothing beyond. The radius follows the hero's awareness light (see Hero growth). Tiers are re-ranked every 0.25 s; bone anchors follow every frame. Views are created on first need, kept with their body (a child, freed with it) and hidden, not rebuilt, when sight closes.
- **Profiles:** `PlayerRig` gets the hero profile (`char.apprentice`, live guilt clarity, re-read on every re-rank). Actor rigs are named `<Actor>Rig`; a ContentDB record `char.<actor>` supplies authored data, otherwise the stable id-only derivation of SS-2 applies. `register(body, profile)` adds or overrides any body.
- **GL Compatibility:** plain vertex/fragment shaders, uniform arrays, no compute, no Decal, no textures (P0-040). The lights and the spine run are biased toward the camera so the torso does not hide them; buildings still occlude.
- **Reduced flashing** (`gameplay.reduced_flashing`): shimmer drops to 15 %, the breathing pulse and the corona drift to 15 %, and the knot cracks stop flickering.
- **Save/load:** nothing saved. Views are transient presentation.

### Verify

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_spirit_aura_view
tools/godot_render.sh --resolution 1280x720 --script tools/capture_spirit_auras.gd -- --out=res://docs/reports/images/spirit_auras
tools/godot_render.sh --resolution 1280x720 --disable-vsync --script tools/capture_spirit_auras.gd -- --bench
```

`test_spirit_aura_view` covers anchors following bones and the rig, shared meshes that are never rebuilt, crown on the skull and brow on the forehead, level -> intensity, clarity -> turbulence, the sky beam (needs the crown, grows with all lights), reduced flashing, the 12 / 40 m budget, hidden outside sight and shown inside, absent animal lights and the animal layout. Plates: [bright clear soul](../reports/images/spirit_auras/bright_clear_soul.png), [dim murky soul](../reports/images/spirit_auras/dim_murky_soul.png), [crowd](../reports/images/spirit_auras/crowd.png), [dog](../reports/images/spirit_auras/animal_dog.png).

**Frame budget** (`--bench`, crowd of 25 rigs, hero at the centre, 2026-10-09): 12 full auras and 13 glows add 49 draw calls (12 x 3 + 13 x 1) to the 851 the rigs already cost, and 29.7k primitives (+8.5 %). Per-frame CPU work is seven bone reads and three uniform writes per visible aura; meshes are never rebuilt. GL Compatibility reports no GPU timing, and the minimized render window is throttled by macOS, so the bench prints measured render time only as a noisy hint. `tools/run_performance_report.sh --quick` cannot run with sight on today: it hangs on `lower_town_scene_benchmark.tscn`, which still points at the removed `scenes/reval_east/reval_east.tscn`.

## Reading a soul (planned, SS-4, **R-1487**)

Looking at a being for about 0.5 s opens a panel: the seven lights with glyph, aspect name, the element each guards and level pips, the strongest and closed lights, clarity in words (calm, uneasy, torn). The hero's awareness light sets the depth: 3 adds temperament tags (SD-15), 4 masked closed lights, 5 a hint of the duel topic.

## Soul lights in a duel (implemented, SS-5, **R-1488**)

Status: implemented (task **R-1488**). Scope: the opponent's and the hero's soul lights changing the numbers of a `SpiritDuel`, the aura feedback and the element colours. Out of scope: who supplies the opponent's profile in play (SS-6/SS-7 callers) and the hero's baseline NATURAL ranks (SS-8, so the hero reads level 1 everywhere until then).

All numbers are constants in `SpiritDuel`. Light and element pair as in the Aura data table (`SpiritDuel.light_for_element`); sight guards no element and never scales a word.

| Rule | Value |
|---|---|
| Opponent pressure pool | `PRESSURE_MAX x sum(levels) / 14`, factor clamped 0.5..2.0 (neutral soul = 60) |
| Opponent blow of an element | x(1 + 0.1 x (level - 2)) by the light guarding that element |
| Hero word into a closed light (level 0) / level 1 | x1.5 / x1.25 |
| Hero's own light | his words and replies x(1 + 0.1 x (own level - 2)) |
| Combined word product | trait x temperament x topic x light, clamped 0.5..2.0 as one (`SpiritDuel.word_product`); guilt stays outside |

- **Neutral soul:** `opponent_aura` / `hero_aura` null (or all levels 2, clarity 1) leave every number as before. The one deliberate difference: the 0.5..2.0 clamp now covers the whole product, so topic x temperament x trait beyond 2.0 is capped even without a profile.
- **Spells:** `cast_spell` (MagicResolver) keeps its NATURAL aspect scaling and applies no light factor. A spoken word that is the reply, and free word strikes (`land_word`), do use it.
- **Entry points:** `SpiritDuel.opponent_aura` / `hero_aura` (set before `begin`), `SpiritArenaHost.opponent_aura` / `hero_aura` (the hero's profile is derived from NATURAL ranks when only the opponent's is set) and `SpiritArenaHost.opponent_aura_view`.
- **Aura feedback** (`SpiritAuraView.bind_duel`): a landed reply or word dims the light that guards its element (`dim_light`, 70 % at most, recovers in under a second); falling opponent pressure lowers clarity down to 35 % (`set_pressure_fraction`, more turbulence); a broken opponent shatters the aura over 0.8 s (`shatter_now`, levels to 0, turbulence to 1), mirroring the SD-19 crack of `SpiritFormView`. Exchange results now also carry `element` and `light_id`.
- **Colours:** `SpiritSpellCard.ELEMENT_COLORS` follow the soul lights: fear red, coin orange, duty yellow, love green, shame blue, faith violet.
- **Verify:** `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_spirit_duel_aura,test_spirit_arena,test_spirit_word_spells,test_spirit_traits,test_spirit_magic`.
- **Limits:** nothing in play yet supplies an opponent profile; the dim and the shatter are not captured in a plate.

## Duel layer (implemented, SS-6, **R-1489**)

Status: implemented (task **R-1489**). Scope: what the world looks like during a 3D spirit duel and how it returns. Out of scope: starting a duel from sight (SS-7). The arena mechanics (hide list, restore, tests) are documented in [`SPIRIT_DIALOGUE.md`](./SPIRIT_DIALOGUE.md) "3D arena disc and duel layer".

The building stays: walls, floor, pillars, stairs and building shells keep their place and collision. Furniture, props, loose items, decor and clutter are hidden through one named list of node groups (`SpiritArena3D.HIDE_GROUPS`), as are people outside the duel. This replaces the ADR 0038 interior stripping to the floor.

- **Duel grade** (`scripts/combat/spirit_sight.gd`, `DUEL_SATURATION`, `DUEL_AMBIENT_ENERGY`, `DUEL_AMBIENT_COLOR`, `DUEL_SUN_SCALE`): nearly monochrome deep indigo, ambient light cut and tinted, sun cut to a sliver, every light but the arena key and fill off. `SpiritSight.duel_amount` (0..1, owned by the open arena) layers it over the sight grade in the same restore-then-compose pass, so closing returns exactly to the sight grade, and leaving sight afterwards restores the physical environment exactly. Sight is not cancelled by the duel's modal flags while `duel_amount > 0`. Stages without a controller (the almshouse prologue) are graded and restored by the arena through the same `grade_environment` recipe.
- **Fighters-only auras:** `SpiritAuraManager.set_duel_fighters` (group `spirit_aura_manager`) shows the two fighters' full auras at full strength regardless of the sight blend and hides every other aura; an empty list returns to the normal budget. A scene without a manager gets a private one for the duel.
- **Return:** closing the arena restores visibility, lights, environment and aura budget, and leaves the hero in spirit sight.
- **Plates:** [`docs/reports/images/spirit_duel_layer/`](../reports/images/spirit_duel_layer/) (outdoor street before, in the duel, back in sight; made by `tools/capture_spirit_duel_layer.gd`) and the almshouse hall duel (`almshouse_duel_hall.png`, from `tools/capture_almshouse_opening.gd`; before R-1489 the hall was hidden down to a bare floor disc).
- **Limits:** the grade is a whole-screen adjustment, so aura colour is desaturated with the rest of the frame; untagged props stay visible until their spawner joins a hide group.

## Entering a duel (implemented, SS-7, **R-1490**)

Status: implemented (task **R-1490**). Scope: how a duel starts from spirit sight (Challenge), how scripted duels pass through sight, and what layer the hero is in afterwards. Out of scope: new duel content and open-world duel triggers with stakes (SW-3, **R-1350**), the look of the duel (Duel layer, SS-6).

A duel starts only from spirit sight and ends back in it.

- **Challenge:** in spirit sight, a person with a duel record shows the prompt **Challenge** instead of their normal one. Interact (`E` / `Enter`, gamepad A) opens the duel in place and sight stays on. The duel opens in the same place on the frozen world with the arena panel. Outside sight the same person gets the normal interaction, and every other interactable still leaves sight first, then interacts (SS-1). No second challenge opens while one is running.
- **Duel record:** the first dialogue, in id order, with a non-empty `duel` block whose `participants` contain both the person's `char.*` id and the hero (`char.apprentice`). An observed quarrel between two other people (`dialogue.prologue.almshouse_quarrel`) is not a challenge. The person behind a talk sensor is `Interactable.character_id`; a sensor without one never offers a challenge.
- **Scripted duels:** `SpiritArenaHost.open_scripted(db, state, dialogue_id)` asks the scene's spirit-sight controller to switch sight on with its ripple (`enter_for_script`, which bypasses the toggle's availability rules), then opens the arena in the same call, so callers keep a synchronous contract. A scene without a controller only sets the transient flag. If the dialogue is not a duel, the sight it switched on is undone and nothing opens.
- **The gate:** `SpiritArenaHost.open` returns false and changes nothing when `GameState.spirit_sight` is off. Every scripted caller (the prologue, tests, capture tools) goes through `open_scripted`. `observe` (watching a quarrel) is not gated.
- **Almshouse porter:** the hall has no Player, so `AlmshouseOpening` mounts its own `SpiritSight` controller (manual toggle disabled) before the duel, switches sight on before the arena is mounted, and opens the duel through `open_scripted`. When Kalev walks in, dialogue closes sight with the reverse ripple; a skip leaves sight at once.
- **After the duel:** closing the arena ends the encounter (`spirit_encounter_active` false) but leaves `GameState.spirit_sight` on, so `in_spirit_world` stays true until the player leaves sight. While a host is open it sits in the group `spirit_duel_open`, and `SpiritSight.enforce_availability` does not cancel sight for the duel's pause or modal flags.

Runtime entry points: `scripts/combat/spirit_sight.gd` (`duel_for`, `challenge_dialogue`, `challenge`, `enter_for_script`, `challenge_host`, `CHALLENGE_PROMPT`), `scripts/combat/spirit_arena_host.gd` (`open` gate, `open_scripted`), `scripts/interaction/interactable.gd` (`character_id`, Challenge prompt and interact routing), `scripts/prologue/almshouse_opening.gd`. Saves nothing: sight stays transient and a loaded game starts physical.

**Verify:** `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_spirit_sight_duel_entry,test_almshouse_opening`. `test_spirit_sight_duel_entry` covers the duel-record rule, the Challenge prompt only in sight, interact opening the duel with sight kept and no second challenge, the normal interaction outside sight, the `open` refusal outside sight, the scripted path turning sight on (ripple running) before `opened`, a scripted non-duel undoing sight, return to sight on close, keyboard `E` and gamepad A through `InteractionController`, and the almshouse porter duel passing through sight.

**Limits:**
- A city Challenge opens the frozen-world arena panel, not the real-time 3D disc. Mounting the disc needs the opponent's 3D rig, which the NPC presenters do not expose by character id yet. SW-3 (**R-1350**) places the first duel-ready NPCs and owns that wiring.
- No live NPC talk sensor sets `character_id` yet, so the Challenge prompt appears in play only once SW-3 adds duel-ready people. The prologue porter is the only duel reachable today.

## Hero growth (implemented, SS-8, **R-1491**)

Status: implemented (task **R-1491**). Scope: the apprentice's starting lights, growth through NATURAL and the awareness-driven sight radius. Out of scope: a separate light currency, cap or save section (ADR 0041 revision 2026-10-09), `natural.lock_aspect` (not implemented in `GameState` yet).

Hero lights are his NATURAL ranks seen as levels: rank below 5 or a locked aspect = 0, 5-9 = 1, 10-14 = 2, 15-24 = 3, 25-39 = 4, 40-50 = 5 (`SpiritAuraProfile.level_for_rank`). They grow only through NATURAL (`natural.grant_points`, `natural.spend_point` at the Hingepuu): a spend that crosses a band brightens the light on the next aura refresh.

- **Starting lights:** `SessionState` starts a New Game from `GameState.new_apprentice_game()`: nature 10, unity 10, awareness 15 (the clairvoyant gift), the rest 5, i.e. levels 2 / 1 / 1 / 2 / 1 / 3 / 1 bottom-up. A bare `GameState.new()` stays at a flat 5, because the save loader, debug presets and scratch states build on it.
- **Sight radius:** `SpiritAuraProfile.sight_radius_for_level(level)` = 12 m + 4 m per awareness level above 2 (never below 12 m): 16 m at the start, 20 m at level 4, 24 m at 5. `SpiritAuraManager` re-reads it from the session state each frame while it follows the session; detached fixtures keep the `sight_radius` they set. The 12-aura and 40 m glow budget is unchanged.
- **Reading depth:** the same awareness level (`SpiritReading`, see Reading a soul).
- **Saves:** nothing new. Ranks travel in the existing `natural` section; old saves keep their stored ranks (aspects missing from a save load as 5), so a Kalev-era save starts with lights 1 and a 12 m radius.
- **Verify:** `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_soul_lights_state,test_p7_011_natural_psyche,test_magic_natural_scaling` (baseline, band edges, locked = 0, a spend crossing a band, save round trip, old save, awareness -> radius).
- **Limits:** returning to the main menu and choosing New Game in the same process does not rebuild `SessionState.state` (pre-existing behaviour), so the baseline applies to the first New Game of each launch; a second New Game in that process inherits the previous run's ranks.

## Save state and IDs

- Stable ids: the NATURAL aspect ids `aspect.nature`, `aspect.affection`, `aspect.tenacity`, `aspect.unity`, `aspect.resonance`, `aspect.awareness`, `aspect.light` as light ids; input action `player_spirit_sight`.
- Saved: nothing new. Hero lights are the already saved NATURAL ranks; spirit sight, auras and duel visibility are transient.

## Verification

Each task names its filter: `test_spirit_sight`, `test_spirit_aura_profile`, `test_spirit_aura_view`, `test_spirit_reading`, `test_spirit_duel_aura`, `test_spirit_arena_3d`, `test_spirit_sight_duel_entry`, `test_soul_lights_state` (rank bands and apprentice baseline), plus capture plates for the grade, auras and the duel layer.

## Limits

- Animals are drawn only when registered with `SpiritAuraManager.register` (as the capture does). Ambient animal actors do not join the aura group yet; wiring them needs a task that may touch the animal presenters.
- Anchor offsets are tuned for the shared adult rig; very short or seated bodies keep the same offsets.

Open balance questions: light-level multipliers, the 12-aura budget in dense crowds, and how many NPCs get an authored `aura` block versus a derived one.
