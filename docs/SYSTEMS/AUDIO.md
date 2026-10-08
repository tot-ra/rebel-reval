# Sound effects (audio)

Status: implemented for Phases 0-1 (ADR 0035: policy, tooling, core runtime). Phases 2-6 (slice pilot, combat, fauna, space, act expansion) are planned.

Scope: every non-music sound. Music stays with [`music/README.md`](../../music/README.md) and `scripts/global/music_director.gd`. Decision record: [ADR 0035](../adr/0035-game-audio-sourcing-and-sfx-system.md).

Out of scope here: surface resolver, ambience controller, reverb and occlusion, ducking, voice-over, any runtime audio generation.

## What exists

- **Catalog** `content/audio/sfx_catalog.json` (`type: sfx_catalog`, schema `schemas/sfx_catalog.schema.json`). Stable IDs `sfx.*` and `amb.*`. Each entry names a `bus`, a `streams` pool, a `tier` (A licensed, B own recording, C AI), the `source_ids` that cover its streams in `assets/SOURCES.csv`, and optional `volume_db`, `pitch_jitter`, `volume_jitter_db`, `no_repeat`, `max_voices`, `cooldown_ms`, `spatial` (`none`, `2d`, `3d`), `max_distance`.
- **Seeded entries** (existing clips only): `sfx.door.wood.use`, `sfx.footstep.wood.walk`, `sfx.footstep.mud.walk`, `sfx.water.emerge`, `sfx.water.submerge`, `amb.weather.rain_roof`. Existing point-wise wiring (`sky_weather_roof_audio.gd` and others) is not migrated yet.
- **Runtime** `scripts/audio/sfx_catalog.gd` (`SfxCatalog`, loader) and `scripts/audio/sfx_player.gd` (`SfxPlayer`, a plain Node a scene owns, not an autoload). `SfxPlayer.play(&"sfx.footstep.wood.walk", position)` picks a stream, applies jitter, enforces `max_voices` and `cooldown_ms`, and routes to the entry's bus. Callers never reference files.
- **Variation**: `pick_stream_index` avoids the last `no_repeat` picks (window clamped to pool size minus one) using the player's own seeded RNG. It does not use `AudioStreamRandomizer`, so the pick is deterministic and testable. The RNG never affects game state; nothing in the catalog is saved.
- **Buses**: `Ambience`, `Weather`, `Footsteps`, `Combat`, `UI` are children of `SFX` in `audio/default_bus_layout.tres`. The settings screen still exposes only Music, SFX and Voice sliders.

## License gate

`python3 tools/validate_asset_sources.py` rejects approved audio rows whose `license`, `creator_or_tool` or `model_version` match the ADR denylist (NC/ND variants, BBC RemArc, AudioLDM, TangoFlux, MMAudio) and ElevenLabs rows that do not record a paid plan in `edits`. Primary license texts go under `docs/reports/audio_licenses/<source>/` ([README](../reports/audio_licenses/README.md)).

## Adding a sound

1. Add the file under `sounds/` and a provenance row in `assets/SOURCES.csv` (see the ADR for required columns).
2. Add or extend an entry in `content/audio/sfx_catalog.json`.
3. Run the verification below.

## Verify

```bash
python3 tools/validate_sfx_catalog.py
python3 tools/validate_asset_sources.py
python3 -m unittest tests.python.test_sfx_catalog -v
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_sfx
```

## Limits

- The ADR's Open questions 1-6 (xeno-canto share-alike, budget, voice, disclosure, Sonniss text, loudness) are unresolved; Phase 0-1 do not depend on them.
- `SfxPlayer` is not yet mounted in any scene. Wiring it in is Phase 2 (slice pilot).
