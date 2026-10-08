# Sound effects (audio)

Status: implemented for Phases 0-1 (ADR 0035: policy, tooling, core runtime) and Phase 2 (slice pilot: surfaces, footsteps, doors, layered ambience - tasks **R-1357**, **R-1358**, **R-1382**, partly **R-1356**). Phases 3-6 (combat, fauna, space, act expansion) are planned.

Scope: every non-music sound. Music stays with [`music/README.md`](../../music/README.md) and `scripts/global/music_director.gd`. Decision record: [ADR 0035](../adr/0035-game-audio-sourcing-and-sfx-system.md).

Out of scope here: reverb and occlusion, ducking, combat and gear sounds, animals beyond the existing bird and insect controllers, crowd walla, UI sounds, voice-over, any runtime audio generation.

## What exists

- **Catalog** `content/audio/sfx_catalog.json` (`type: sfx_catalog`, schema `schemas/sfx_catalog.schema.json`). Stable IDs `sfx.*` and `amb.*`. Each entry names a `bus`, a `streams` pool, a `tier` (A licensed, B own recording, C AI), the `source_ids` that cover its streams in `assets/SOURCES.csv`, and optional `volume_db`, `pitch_jitter`, `volume_jitter_db`, `no_repeat`, `max_voices`, `cooldown_ms`, `spatial` (`none`, `2d`, `3d`), `max_distance`.
- **Entries today**: `sfx.door.wood.use`, `sfx.footstep.wood.walk`, `sfx.footstep.mud.walk`, `sfx.water.emerge`, `sfx.water.submerge`, `amb.weather.rain_roof`, `amb.weather.rain_outdoor`, `amb.lower_town.bed`, `amb.forge.bed`. `sky_weather_roof_audio.gd` and `scenes/elements/door.gd` read the catalog; `nunnatorn_audio_controller.gd`, world item pickup feedback and the swim clips are still wired point by point (**R-1356**).
- **Tiers in use**: in-house ffmpeg synthesis counts as tier **B** (own material, rights assigned), not tier C: tier C is model output from Stable Audio or ElevenLabs. `amb.weather.rain_roof` was relabelled from C to B for that reason.
- **Runtime** `scripts/audio/sfx_catalog.gd` (`SfxCatalog`, loader) and `scripts/audio/sfx_player.gd` (`SfxPlayer`, a plain Node a scene owns, not an autoload). `SfxPlayer.play(&"sfx.footstep.wood.walk", position)` picks a stream, applies jitter, enforces `max_voices` and `cooldown_ms`, and routes to the entry's bus. Callers never reference files.
- **Variation**: `pick_stream_index` avoids the last `no_repeat` picks (window clamped to pool size minus one) using the player's own seeded RNG. It does not use `AudioStreamRandomizer`, so the pick is deterministic and testable. The RNG never affects game state; nothing in the catalog is saved.
- **Buses**: `Ambience`, `Weather`, `Footsteps`, `Combat`, `UI` are children of `SFX` in `audio/default_bus_layout.tres`, which `project.godot` names under `[audio] buses/default_bus_layout`. That path must stay inside version control: `/build/` is gitignored, so a layout kept there is absent from a fresh clone, from CI and from the export, and Godot then routes every catalog sound straight to `Master`, past the SFX slider (**R-1382**). The settings screen still exposes only Music, SFX and Voice sliders.

## Surfaces and footsteps (Phase 2, **R-1357**)

`scripts/audio/surface_resolver.gd` (`SurfaceResolver`) folds the twenty authored terrain IDs into the six first-cut surfaces. Listeners classify surface *type* reliably and materials inside a type poorly, so the folding is inaudible:

| Surface | Terrains |
|---------|----------|
| `wood` | `timber_floor` |
| `stone` | `stone`, `cobblestone`, `castle_paving`, `plaster` |
| `dirt` | `dirt`, `mud`, `farm_soil`, `bog`, `forest_floor` |
| `grass` | `grass`, `meadow`, `hay`, `straw` |
| `gravel` | `sand`, `coast_sand`, `ash` |
| `water_shallow` | `shallow_water`, `water`, `river_water` |

`deep_water` resolves to `&""` (silent): that is swimming, and `PlayerSwimState` owns those sounds. An unknown terrain is silent rather than guessed.

Sound IDs are `sfx.footstep.<surface>.<gait>` with gaits `walk`, `run`, `sneak`; gait comes from logic speed (`RUN_SPEED_THRESHOLD`, the same threshold the run animation uses). Only two pools exist so far, so `SURFACE_FALLBACKS` names an audible stand-in per surface, grouped by acoustic family so a dry surface never chains into the wet pool (**R-1382**):

| Family | Surfaces | Stand-in pool |
|--------|----------|---------------|
| hard, dry | `stone`, `gravel` | `wood` |
| soft, damp, wet | `dirt`, `grass`, `water_shallow` | `mud` |

Chains are flat data and are not resolved recursively. **Adding the real entry to the catalog retires the stand-in with no code change** - that is the ADR's replaceability rule, so licensed or recorded pools can land through `AUDIO-4` alone.

### One-shots only

A footstep or door entry is played once per event, so **every stream in a `sfx.footstep.*` or `sfx.door.*` pool must be a single impact**, not a walk cycle or a loop. `tools/validate_sfx_catalog.py` enforces a `ONE_SHOT_MAX_SECONDS` (1.5 s) cap per stream, reading durations with the MPEG frame parser in `tools/verify_runtime_audio_budget.py` (no ffprobe, so it runs in CI); `tests/godot/test_sfx_coverage.gd::test_one_shot_pools_hold_one_shots` repeats the check against what Godot imported.

This is a guard against a real defect: the first phase-2 catalog pointed both footstep pools at `sounds/walk_wood.mp3` (5.0 s) and `sounds/walking_on_mud_stable_audio_3.mp3` (8.0 s), which are continuous *walk cycles*. Every foot plant started a whole cycle, up to `max_voices` of them overlapped, and they kept sounding after the player stopped. Those two clips remain in `sounds/` as cycle material and must never be named by a one-shot entry again.

The shipped pools are single steps cut out of those cycles by `python3 tools/audio/slice_footstep_oneshots.py`: `sounds/footsteps/wood_walk_01..05.mp3` (115-260 ms) and `mud_walk_01..04.mp3`. The cut offsets are documented constants, so regeneration is byte-stable; each slice is mono (the pools play through `AudioStreamPlayer3D`, where a baked stereo image fights positional panning) and RMS-matched so variations do not jump in level. The mud pool is smaller because that source is a dense continuous squelch with only four separable steps.

`scripts/audio/footstep_audio.gd` (`FootstepAudio`) plays one voice per animation foot plant. `MapViewRuntimeActors.sync_player` already consumes `SharedCharacterRig.consume_foot_plant()` for mud prints and now calls the same event through `MapViewRuntime` → `MapViewRuntimeAmbient.play_footstep`, sampling terrain under the planted foot (not under the actor pivot). Cadence therefore comes from the rig, never from a timer inside a clip. Disable with `MapViewRuntime.set_footstep_audio_enabled(false)`; read `footstep_played_count()`, `last_footstep_sound_id()` and `last_footstep_surface()` for logs and the debug overlay.

## Ambience layers (Phase 2, **R-1358**)

`scripts/audio/ambience_controller.gd` (`AmbienceController`) blends four layers, mounted per map by `MapViewRuntimeAmbient`:

1. **bed** - 1-3 quiet loops, crossfaded with a per-second dB ramp like `music_director.gd`.
2. **mid** - longer loops (crowd density, market); declared, no licensed material yet.
3. **spot** - positional one-shots on randomised `min_interval`/`max_interval` around the listener, capped by `MAX_CONCURRENT_SPOTS` (the soundscape budget) so cues stay audible. Declared, no material yet.
4. **weather** - the *exterior* rain overlay, scaled by rain intensity. Interior rain-on-roof stays with `SkyWeatherRoofAudio` inside `SkyWeather3D`; running both would double the indoor rain.

Layers are declared in `scripts/audio/ambience_profiles.gd` (`AmbienceProfiles.PROFILES`), an explicit `map_id` table like the bird, insect and fauna contexts - never filesystem or catalog discovery. An entry carries `id` plus optional `volume_db`, an `hours` window (wrapping, for example `[21, 5]`), and the spot interval and radius. A map without a profile is silent. Day and night variation comes from the existing bird and insect controllers, not from separate beds.

Pilot profiles: `lower_town_slice` (bed `amb.lower_town.bed`, exterior rain `amb.weather.rain_outdoor`) and `kalev_smithy` (bed `amb.forge.bed`; no weather layer, the roof bed covers it). Selection uses a private seeded RNG, never touches game state, and nothing is saved: ambient timers restart on load.

## License gate

`python3 tools/validate_asset_sources.py` rejects approved audio rows whose `license`, `creator_or_tool` or `model_version` match the ADR denylist (NC/ND variants, BBC RemArc, AudioLDM, TangoFlux, MMAudio) and ElevenLabs rows that do not record a paid plan in `edits`. Primary license texts go under `docs/reports/audio_licenses/<source>/` ([README](../reports/audio_licenses/README.md)).

## Adding a sound

1. Add the file under `sounds/` and a provenance row in `assets/SOURCES.csv` (see the ADR for required columns). Run a headless import pass (`godot --headless --editor --quit`) so the `*.import` sidecar is committed with the clip.
2. Add or extend an entry in `content/audio/sfx_catalog.json`. A new footstep pool needs no code change: `sfx.footstep.<surface>.<gait>` is picked up by `SurfaceResolver` automatically.
3. Run the verification below.

In-house placeholder material is regenerated deterministically: `python3 tools/audio/generate_ambience_beds.py` (beds and the exterior rain overlay), `tools/audio/generate_rain_roof_clips.py` (roof loop) and `python3 tools/audio/slice_footstep_oneshots.py` (footstep one-shots). Each writes its `sounds/<dir>/manifest.csv` rows; the slicer also prints its `assets/SOURCES.csv` rows with `--print-sources`.

## Verify

```bash
python3 tools/validate_sfx_catalog.py
python3 tools/validate_asset_sources.py
python3 tools/verify_weather_audio_clips.py
python3 -m unittest tests.python.test_sfx_catalog -v
godot --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_sfx_catalog,test_sfx_player_no_repeat,test_sfx_surface_resolver,test_sfx_footsteps,test_sfx_ambience,test_sfx_coverage,test_weather_audio_clips
```

`tests/godot/test_sfx_coverage.gd` is the coverage gate: every surface and gait must resolve to an existing catalog entry, every terrain the two pilot maps author must sound, and every ID an ambience profile names must exist.

Session log (evidence for the phase-2 verify lines and the input to a listening review) - boots both pilot locations, walks a square circuit, records the triggered IDs:

```bash
godot --headless --path . --script tools/capture_sfx_session_log.gd -- \
  --out=res://build/reports/sfx_session_log.json
```

## Limits

- ADR Open questions 1, 2 and 4-6 (xeno-canto share-alike, **budget**, disclosure, Sonniss text, loudness) are unresolved. Open question 3 (voice) is answered in the ADR.
- **Placeholder audio.** Only two footstep pools exist (`wood`, `mud`); stone, grass, gravel and shallow water play a stand-in from the wrong material, so cobbles sound like boards and sand sounds like a board too. Both pools are cut from two AI-generated walk cycles, not recorded Foley. The three beds (`amb.lower_town.bed`, `amb.forge.bed`, `amb.weather.rain_outdoor`) are in-house synthesis, not recordings. Mid and spot layers are implemented and tested but have no content. Forge tool sounds (hammer, anvil, bellows, quench) do not exist. All of this is content, waiting on the budget decision (**R-1359**).
- Footstep levels have not had a listening pass. The pools are RMS-matched to each other, but the `Footsteps` bus trim against ambience and music is still at 0 dB and no catalog `volume_db` is set.
- Footsteps fire for the player only. NPC and animal foot plants are not wired.
- No separate footstep pool per shoe type, and no `sneak` gait in gameplay yet.
- Settings expose one SFX slider; the new buses have no individual sliders.
