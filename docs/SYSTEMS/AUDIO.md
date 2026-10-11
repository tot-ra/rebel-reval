# Sound effects (audio)

Status: implemented for Phases 0-1 (ADR 0035: policy, tooling, core runtime) and Phase 2 (slice pilot: surfaces, footsteps, doors, layered ambience - tasks **R-1357**, **R-1358**, **R-1382**, **R-1383**, partly **R-1356**; footsteps on every map and for NPCs with recorded pools - **R-1641**; wading and swim strokes - **R-1648**), plus weather-driven sea surf and wind (task **R-1550**). Phases 3-6 (combat, fauna, space, act expansion) are planned.

Scope: every non-music sound. Music stays with [`music/README.md`](../../music/README.md) and `scripts/global/music_director.gd`. Decision record: [ADR 0035](../adr/0035-game-audio-sourcing-and-sfx-system.md).

Out of scope here: reverb and occlusion, ducking, combat and gear sounds, animals beyond the existing bird and insect controllers, crowd walla, UI sounds, voice-over, any runtime audio generation.

## What exists

- **Catalog** `content/audio/sfx_catalog.json` (`type: sfx_catalog`, schema `schemas/sfx_catalog.schema.json`). Stable IDs `sfx.*` and `amb.*`. Each entry names a `bus`, a `streams` pool, a `tier` (A licensed, B own recording, C AI), the `source_ids` that cover its streams in `assets/SOURCES.csv`, and optional `volume_db`, `pitch_jitter`, `volume_jitter_db`, `no_repeat`, `max_voices`, `cooldown_ms`, `spatial` (`none`, `2d`, `3d`), `max_distance`.
- **Entries today**: `sfx.door.wood.use`, `sfx.footstep.{wood,stone,grass,gravel,dirt,mud,puddle,water_shallow,water_wade}.walk`, `sfx.water.swim_stroke`, `sfx.water.emerge`, `sfx.water.submerge`, `amb.weather.rain_roof`, `amb.weather.rain_outdoor`, `amb.lower_town.bed`, `amb.forge.bed`, and the sea and wind loops `amb.sea.{calm,moderate,storm}` and `amb.wind.{light,strong,storm}` (**R-1550**). `sky_weather_roof_audio.gd` and `scenes/elements/door.gd` read the catalog; world item pickup (`sfx.item.pickup`, item field `gameplay.pickup.sfx_id`), the Harju Kings reputation cheer (`sfx.social.reaction.harju_kings_trusted`), the swim cues (`sfx.water.submerge`/`emerge` in `underwater_pass.gd`) and the Nunnatorn roof bed (`amb.weather.rain_roof`) were migrated onto the catalog by **R-1356**; entries may set a base `pitch` (default 1.0) beside `pitch_jitter`.
- **Tiers in use**: in-house ffmpeg synthesis counts as tier **B** (own material, rights assigned), not tier C: tier C is model output from Stable Audio or ElevenLabs. `amb.weather.rain_roof` was relabelled from C to B for that reason.
- **Runtime** `scripts/audio/sfx_catalog.gd` (`SfxCatalog`, loader) and `scripts/audio/sfx_player.gd` (`SfxPlayer`, a plain Node a scene owns, not an autoload). `SfxPlayer.play(&"sfx.footstep.wood.walk", position)` picks a stream, applies jitter, enforces `max_voices` and `cooldown_ms`, and routes to the entry's bus. Callers never reference files.
- **Variation**: `pick_stream_index` avoids the last `no_repeat` picks (window clamped to pool size minus one) using the player's own seeded RNG. It does not use `AudioStreamRandomizer`, so the pick is deterministic and testable. The RNG never affects game state; nothing in the catalog is saved.
- **Buses**: `Ambience`, `Weather`, `Footsteps`, `Combat`, `UI` are children of `SFX` in `audio/default_bus_layout.tres`, which `project.godot` names under `[audio] buses/default_bus_layout`. That path must stay inside version control: `/build/` is gitignored, so a layout kept there is absent from a fresh clone, from CI and from the export, and Godot then routes every catalog sound straight to `Master`, past the SFX slider (**R-1382**). The settings screen still exposes only Music, SFX and Voice sliders.

## Surfaces and footsteps (Phase 2, **R-1357**, **R-1641**, **R-1648**)

The player and every walking NPC near the player make one footstep per foot contact, on every map: district and debug maps, streamed locations and the seamless city. The sound follows what the sole lands on - flagstone, boards, turf, packed earth, wet mud, gravel and sand, a rain puddle, shallow water, wading through deeper water. A swimmer's feet leave the bed, so swimming plays arm strokes instead of steps.

`scripts/audio/surface_resolver.gd` (`SurfaceResolver`) defines nine surfaces and folds the twenty authored terrain IDs into them. Listeners classify surface *type* reliably and materials inside a type poorly, so the folding is inaudible:

| Surface | Terrains |
|---------|----------|
| `wood` | `timber_floor` |
| `stone` | `stone`, `cobblestone`, `castle_paving`, `plaster` |
| `dirt` | `dirt`, `farm_soil`, `forest_floor` |
| `mud` | `mud`, `bog` |
| `grass` | `grass`, `meadow`, `hay`, `straw` |
| `gravel` | `sand`, `coast_sand`, `ash` |
| `water_shallow` | `shallow_water`, `water`, `river_water` |
| `puddle` | none: reported where a filled puddle lies under the foot |
| `water_wade` | none: chosen by water depth (below) |

`deep_water` resolves to `&""` by terrain alone. **Water depth decides splash or wading (R-1648):** wherever the player can walk into water, the view measures the water column under the foot and `SurfaceResolver.water_surface_for_depth(depth)` returns `water_shallow` below `WADE_SURFACE_DEPTH` (0.3 world units, mid-shin on a 2-unit body) and `water_wade` from there. Ankle-deep water splashes, deeper water is a long gurgling slosh of a leg pulled out and pushed back in. From `PlayerSwimState.SWIM_ENTER_DEPTH` (1.25) the feet leave the bed and no step plays. An unknown terrain is silent rather than guessed. `SurfaceResolver.with_puddle(surface, in_puddle)` turns a ground surface (`PUDDLE_HOSTS`: stone, dirt, mud, grass, gravel) into `puddle`; a board or a stream never becomes a puddle.

Sound IDs are `sfx.footstep.<surface>.<gait>` with gaits `walk`, `run`, `sneak`; gait comes from logic speed (`RUN_SPEED_THRESHOLD`, the same threshold the run animation uses). Only `walk` pools exist; `run` falls back to the same surface at a walk.

**A stand-in may only name the same material** (**R-1383**). Every surface has a pool of its own since **R-1641**, so `SURFACE_FALLBACKS` is empty and a missing pool resolves to `&""` (silent). Earlier phases borrowed across materials and the result was audible as a defect (`world_saaremaa` knocked like a plank on its beaches); a wrong surface type is heard immediately, a missing step is not. Adding a catalog entry retires a silent surface with no code change.

### Where the surface comes from

`FootstepAudio` asks the map view: `MapView3D.footstep_surface_at(foot_position)` (view-local space, the space `add_mud_footprint_at` uses).

- **District, debug and streamed maps** (`MapView3D`): on water the player may enter (`PlayerWaterTraversal.is_traversable_terrain`, so the sea's `deep_water` shelf too), the column from `PlayerWaterTraversal.depth_at` picks `water_shallow` or `water_wade`; otherwise the terrain cell under the foot, then `puddle` when the foot lands inside a scatter puddle decal (`Puddles` MultiMesh per chunk) while `SkyWeather3D.puddle_wetness()` is at least `PUDDLE_STEP_MIN_WETNESS` (0.02, where the decal shader shows water). The waterline radius matches `map_view_puddle.gdshader` without its outline noise.
- **Seamless city** (`CityMapView` → `scripts/audio/city_surface_sampler.gd`, `CitySurfaceSampler`): the city has no terrain grid, so the sampler reads what `city_ground.gdshader` paints. First match wins: water over the walking surface (`water_depth_at`) → `water_shallow` or `water_wade` by depth; a bridge deck → `wood`; an interior site floor → `stone`, except `site.kalev_smithy` (beaten earth, `dirt`); any other building shell → `wood`, `church`/`chapel` → `stone`; ground below 1 m on a coastal plan → `gravel` (beach sand); otherwise the splat layer with the largest share above 0.5 (R paving `stone`, G packed earth, fields and cart roads `dirt`, B sand `gravel`, A mud `mud`), else `grass`. Rasters come from `CityShore.land_use_at` / `road_raster_at`, the cache `CityShore` and `CityGrass` already use. On `dirt` and `mud` a rain puddle is heard where the shader's earth basins hold water: `puddle_depth` ports the `hollow * soft` basin, its noise (`hash12`, `value_noise`, `mud_height`) and the water level `1.05 - puddles * 0.75`, and baked ground (`ground_dryness` above 0.3) holds none. Rut and footprint pools, which the shader only fills near the camera, are left out.

### Who makes steps

`MapViewRuntimeActors` consumes `SharedCharacterRig.consume_foot_plant()` - the rig's own contact event, never a timer - for the player and for each registered NPC rig (citizens, named NPCs, site people, guards). The player event also places the mud print. NPC rigs are sampled only while moving and within `NPC_FOOTSTEP_RADIUS` (16 m) of the player, which keeps a crowd cheap. Animals and the instanced crowd (`CrowdRenderer`, no skeleton) make no steps.

`MapViewRuntimeAmbient` owns two `FootstepAudio` nodes: `FootstepAudio` for the player and `NpcFootstepAudio` for NPCs, with its own variation RNG, its own voice budget (each pool caps at `max_voices` 3 per `SfxPlayer`, so a crowd never steals the player's steps) and `NPC_FOOTSTEP_VOLUME_OFFSET_DB` (-5 dB). Voices are `AudioStreamPlayer3D` at the foot's global position (`sound_position`), so a step on a streamed location offset from the world origin still plays where the foot is. `MapViewRuntimeBootstrap` wires both callbacks on district and hosted maps; `CityRuntime._install_footsteps` wires them in the seamless city, which had no footstep audio before **R-1641**. Disable with `MapViewRuntime.set_footstep_audio_enabled(false)`; read `footstep_played_count()`, `last_footstep_sound_id()` and `last_footstep_surface()` for logs and the debug overlay (player steps only).

### Swim strokes (R-1648)

While the player swims (`PlayerSwimState` `SWIM` or `DIVE`), `MapViewSwimmerPresenter` reports a stroke every half cycle of its stroke phase, when one arm enters the water in the crawl or a sculling sweep turns while treading, and only once the stroke pose has blended in past 50 %. `consume_stroke()` returns `&"crawl"`, `&"tread"` or `&""`; `MapViewRuntimeActors` passes it with the rig's global position to `MapViewRuntimeAmbient.play_swim_stroke`, which plays `sfx.water.swim_stroke` on the player's `FootstepAudio` voices (`FootstepAudio.on_swim_stroke`). Treading plays the same pool `TREAD_STROKE_VOLUME_OFFSET_DB` (-7 dB) softer. The cadence follows the posed arms, as steps follow foot plants: 0.55-1.0 crawl cycles per second (two strokes each), 0.45 when treading. Entering and leaving the water keep their own cues (`sfx.water.submerge` / `emerge`).

### One-shots only

A footstep or door entry is played once per event, so **every stream in a `sfx.footstep.*` or `sfx.door.*` pool must be a single impact**, not a walk cycle or a loop. `tools/validate_sfx_catalog.py` enforces a `ONE_SHOT_MAX_SECONDS` (1.5 s) cap per stream, reading durations with the MPEG frame parser in `tools/verify_runtime_audio_budget.py` (no ffprobe, so it runs in CI); `tests/godot/test_sfx_coverage.gd::test_one_shot_pools_hold_one_shots` repeats the check against what Godot imported. (The first phase-2 catalog pointed the pools at the 5-8 s walk cycles `sounds/walk_wood.mp3` and `sounds/walking_on_mud_stable_audio_3.mp3`; every foot plant started a whole cycle. Those clips stay in `sounds/` and must never be named by a one-shot entry.)

### Footstep material (R-1641)

Every pool except `snow` is a recording of real steps, tier **A**, CC0 (`snow` is synthesised, see [`SEASONS.md`](./SEASONS.md#snow-footprints-and-the-crunch)), built by `python3 tools/audio/build_footstep_pools.py` into `sounds/footsteps/<surface>_step_NN.mp3` (5-6 variations per surface, 105-780 ms, mono 44.1 kHz 128 kbps):

| Surface | Source |
|---------|--------|
| `wood`, `stone`, `grass` | Kenney, *Impact Sounds* (footstep_wood, footstep_concrete, footstep_grass one-shots) |
| `gravel` | GiocoSound, FS 401345 *SFX_Steps_Gravel_Walk* |
| `dirt` | aglinder, FS 264469 *Footsteps Dirt 01* |
| `mud` | BenDrain, FS 488068 and 488069 *Footsteps_Mud_01/02* |
| `puddle` | j1987, FS 106395 *puddlewalk*; ChristopherJngs, FS 861369 *Splashing Footsteps Shallow Water* |
| `water_shallow` | aglinder, FS 265582 *Footsteps Water 01* |
| `water_wade` (**R-1648**) | ryansitz, FS 342932 *Wading in Shallow Water* (feet pulled out and pushed back in; the cuts keep the low plunge and the other leg's lift-out) |
| `swim` stroke (**R-1648**) | craigsmith, FS 438845 *G54-26-Person Swimming* (dry, no room; the opening jump-in splash is skipped) |

Kenney clips are already single steps; Freesound walks are cut at fixed onset offsets (constants in the tool, each a strong step with a clean gap to the next). Each clip is high-passed (50-90 Hz: several walks carry handling rumble below 60 Hz), faded in over 3 ms and out over its last 40 %, and levelled so its loudest 50 ms window meets a per-surface target (-14 dBFS for wood, stone, puddle and water, -16 to -17 for gravel, mud, dirt and wading, -18 for swim strokes, -19 for grass: a step on turf is quieter than a heel on flagstone). Gain is capped at a -3 dBFS peak instead of limited, to keep the transient. Sources are cached in `build/audio_sources/` and pinned by sha256; the tool writes `sounds/footsteps/manifest.csv` (credited in `CREDITS.md`) and prints the `assets/SOURCES.csv` rows with `--print-sources`. It replaced the placeholder tools `slice_footstep_oneshots.py` (AI walk-cycle cuts) and `generate_footstep_oneshots.py` (noise synthesis).

Before/after spectrograms of every pool: [footstep_pools_r1641.png](../reports/images/footstep_pools_r1641.png).

## Ambience layers (Phase 2, **R-1358**)

`scripts/audio/ambience_controller.gd` (`AmbienceController`) blends four layers, mounted per map by `MapViewRuntimeAmbient`:

1. **bed** - 1-3 quiet loops, crossfaded with a per-second dB ramp like `music_director.gd`.
2. **mid** - longer loops (crowd density, market); declared, no licensed material yet.
3. **spot** - positional one-shots on randomised `min_interval`/`max_interval` around the listener, capped by `MAX_CONCURRENT_SPOTS` (the soundscape budget) so cues stay audible. Declared, no material yet.
4. **weather** - the *exterior* rain overlay, scaled by rain intensity. Interior rain-on-roof stays with `SkyWeatherRoofAudio` inside `SkyWeather3D`; running both would double the indoor rain.

Layers are declared in `scripts/audio/ambience_profiles.gd` (`AmbienceProfiles.PROFILES`), an explicit `map_id` table like the bird, insect and fauna contexts - never filesystem or catalog discovery. An entry carries `id` plus optional `volume_db`, an `hours` window (wrapping, for example `[21, 5]`), and the spot interval and radius. A map without a profile is silent. Day and night variation comes from the existing bird and insect controllers, not from separate beds.

Pilot profiles: `lower_town_slice` (bed `amb.lower_town.bed`, exterior rain `amb.weather.rain_outdoor`) and `kalev_smithy` (bed `amb.forge.bed`; no weather layer, the roof bed covers it). Selection uses a private seeded RNG, never touches game state, and nothing is saved: ambient timers restart on load.

## Sea surf and wind (R-1550)

Near the sea the player hears surf whose character follows the weather, loudest at the waterline and gone about 180 m inland; outdoors the wind rises with wind strength and gusts. Interiors hear neither.

**Material.** Six CC0 field recordings from Freesound (tier **A**), cut into 52 s seamless loops by `python3 tools/audio/generate_sea_wind_beds.py`: a fixed excerpt per clip (the steadiest window by 1 s RMS), 40 Hz high-pass, and the 3 s that follow the excerpt mixed into its head with an equal-power crossfade, so the loop end flows into the start. Each tier is mastered to its own loudness, so the weather crossfade also rises in level.

| ID | File | Source | Loudness |
|----|------|--------|----------|
| `amb.sea.calm` | `sounds/sea/sea_calm.mp3` | timsc, FS 367479, small waves on shingle | -24 LUFS |
| `amb.sea.moderate` | `sounds/sea/sea_moderate.mp3` | leesparey, FS 653395, surf on shingle and rock | -21 LUFS |
| `amb.sea.storm` | `sounds/sea/sea_storm.mp3` | chris_dagorne, FS 426076, storm waves on a beach | -18 LUFS |
| `amb.wind.light` | `sounds/wind/wind_light.mp3` | kvgarlic, FS 184277, wind through pines | -27 LUFS |
| `amb.wind.strong` | `sounds/wind/wind_strong.mp3` | felix.blume, FS 187756, wind in a tree | -22 LUFS |
| `amb.wind.storm` | `sounds/wind/wind_storm.mp3` | DBlover, FS 505999, howling storm | -18 LUFS |

Sea loops play on the `Ambience` bus, wind on `Weather`. The previews are cached in `build/audio_sources/` (gitignored, several exceed the 2 MiB cap for `sounds/`) and checked by sha256; `--print-sources` prints the `assets/SOURCES.csv` rows. Credits come from `sounds/sea/manifest.csv` and `sounds/wind/manifest.csv` through `tools/generate_credits.py`.

**Gain model** (`AmbienceController`, pure static helpers so tests cover them):

- `tier_weights(wind_strength)` - three tiers centred on 0, 0.5 and 1; neighbours crossfade at equal power, so a calm sea is pure `calm`, a gale is pure `storm`, and the two never mix.
- `shore_gain(distance)` - quadratic falloff from 1 at the water to 0 at `SEA_AUDIBLE_DISTANCE` (180 m); a profile may override it with `audible_distance`.
- `wind_level(strength, gust)` - `WIND_CALM_LEVEL` (0.35) in still air up to 1 in a gale, lifted up to 35 % by `wind_gust()`.
- `nearest_sea_distance(origin, is_sea)` - coarse ring probe (radii 0-180 m, 16 directions), INF when no ring touches the sea. It only drives the falloff, so it is re-run every 0.5 s (about 60 us on the city plan).

**Wiring.** `MapViewRuntimeAmbient._sync_exterior_weather` reads `SkyWeather3D.wind_strength()` and `wind_gust()` and calls `AmbienceController.set_exterior_weather(...)` before every `sync`. The sea test is the city plan ground below the sea surface (`CityPlan.ground_height < -0.3`, sea at y = 0) in the seamless city, and `deep_water` terrain on district maps. Interiors (`suppresses_exterior_surroundings()` or `SkyWeather3D.rain_suppressed`, which the city sets inside enclosed buildings) mute both layers. `CityRuntime._install_ambience` mounts the controller in the seamless city, which had only bird audio before.

**Profiles.** `reval_city`, `prototype.reval_harbor_surroundings`, `prototype.paldiski_coastal_outpost` and `world_saaremaa` declare `sea` and `wind`; `lower_town_slice` declares `wind` only. `kalev_smithy` (interior) declares neither.

Verify: `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_sfx_sea_wind` (tier selection, shore falloff, ring probe, interior mute, gusts, coastal profiles).

## License gate

`python3 tools/validate_asset_sources.py` rejects approved audio rows whose `license`, `creator_or_tool` or `model_version` match the ADR denylist (NC/ND variants, BBC RemArc, AudioLDM, TangoFlux, MMAudio) and ElevenLabs rows that do not record a paid plan in `edits`. Primary license texts go under `docs/reports/audio_licenses/<source>/` ([README](../reports/audio_licenses/README.md)).

## Adding a sound

1. Add the file under `sounds/` and a provenance row in `assets/SOURCES.csv` (see the ADR for required columns). Run a headless import pass (`godot --headless --editor --quit`) so the `*.import` sidecar is committed with the clip.
2. Add or extend an entry in `content/audio/sfx_catalog.json`. A new footstep pool needs no code change: `sfx.footstep.<surface>.<gait>` is picked up by `SurfaceResolver` automatically.
3. Run the verification below.

Licensed sea and wind loops are regenerated by `python3 tools/audio/generate_sea_wind_beds.py`. In-house placeholder material is regenerated deterministically: `python3 tools/audio/generate_ambience_beds.py` (beds and the exterior rain overlay) and `tools/audio/generate_rain_roof_clips.py` (roof loop); the bed tool writes its `sounds/<dir>/manifest.csv` rows. Recorded footstep pools are rebuilt by `python3 tools/audio/build_footstep_pools.py` (see Footstep material).

## Verify

```bash
python3 tools/validate_sfx_catalog.py
python3 tools/validate_asset_sources.py
python3 tools/verify_weather_audio_clips.py
python3 -m unittest tests.python.test_sfx_catalog -v
godot --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_sfx_catalog,test_sfx_player_no_repeat,test_sfx_surface_resolver,test_sfx_footsteps,test_city_surface_sampler,test_sfx_ambience,test_sfx_sea_wind,test_sfx_coverage,test_weather_audio_clips
```

`tests/godot/test_sfx_coverage.gd` is the coverage gate: every surface and gait must resolve to an existing catalog entry, every terrain the two pilot maps author must sound, and every ID an ambience profile names must exist.

Session log (evidence for the phase-2 verify lines and the input to a listening review) - boots the forge and the seamless city, walks a square circuit, records the triggered player IDs and surfaces and the NPC step count:

```bash
godot --headless --path . --script tools/capture_sfx_session_log.gd -- \
  --out=res://build/reports/sfx_session_log.json
```

## Limits

- ADR Open questions 1, 2 and 4-6 (xeno-canto share-alike, **budget**, disclosure, Sonniss text, loudness) are unresolved. Open question 3 (voice) is answered in the ADR.
- **Placeholder audio.** Footstep pools are recorded CC0 Foley since **R-1641**, but have had no listening review in game. The three beds (`amb.lower_town.bed`, `amb.forge.bed`, `amb.weather.rain_outdoor`) are in-house synthesis, not recordings. Mid and spot layers are implemented and tested but have no content. Forge tool sounds (hammer, anvil, bellows, quench) do not exist. All of this is content, waiting on the budget decision (**R-1359**).
- Footstep levels are set by measurement (per-surface peak-window targets), not by ear; the `Footsteps` bus trim against ambience and music is still at 0 dB and no catalog `volume_db` is set. `NPC_FOOTSTEP_VOLUME_OFFSET_DB` (-5 dB) is likewise untuned.
- Animals and the instanced crowd make no footsteps; NPC rigs beyond 16 m from the player are not sampled.
- Wading and swim strokes (**R-1648**) were chosen from spectrograms and onsets, not by ear. NPCs never wade or swim (navigation blocks water). Only the player swims, so only the player strokes; there is no separate surface-breaking dive splash beyond `sfx.water.submerge`.
- Only `walk` pools exist: running reuses them (no heavier run steps), there is no `sneak` gait in gameplay, and no pool per shoe type (Kenney steps are hard soles, the Freesound walks boots).
- City puddles follow the shader's earth basins only; water standing in cart ruts and footprints near the camera is silent. District puddles test the decal's mean waterline, not its noisy outline.
- Interior floors are inferred from building kind and site (houses wood, churches and site floors stone, the smithy earth); `content/world/*/sites/*.json` floors carry no material field yet.
- Settings expose one SFX slider; the new buses have no individual sliders.
- Sea and wind loops (**R-1550**) have had no listening review: tier balance, the 180 m falloff and the `volume_db` trims (-6 dB sea, -8 dB wind) are set by measurement, not by ear. MP3 encoder padding can leave a few milliseconds of gap at the loop point. Surf is one non-positional stereo bed: it does not pan toward the shore, and a quay sounds like a beach (no harbour-lap tier).
