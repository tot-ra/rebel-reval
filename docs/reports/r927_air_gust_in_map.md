# R-927 Air Gust in-map gameplay-camera plates

**Review date:** 2026-09-26
**Task:** R-927 / R-924 follow-up
**Parent:** R-924 / R-913 (`MapViewMagicVfx` wind cone)
**Map:** `lower_town_slice`, day, focus `street_start` (playable spawn)
**Camera:** `CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE` (33.75), pitch -30, yaw 45
**Status:** **PASS** - mid frame still shows a wedge; watchman slides away from Kalev. Do not restyle the VFX.

## Decision

The three new plates under `docs/reports/images/air_gust/in_map_*.png` show Air Gust on a real Lower Town street at the shipped gameplay crop, not the R-913 studio floor. The mid frame adds a compact pale dust puff at Kalev (the same unshaded wedge plus smoke, now ~10 percent of the view height). The after frame shows the watchman farther east along the spine. CombatKnockbackEffect was not changed.

This is a gameplay-camera readability check, not a human art-direction signature. The studio pair stays the R-924 close-up evidence.

## Per-plate

| Check | Result |
|---|---|
| Mid frame still shows a wedge | **PASS.** Center crop (520,220)-(920,520) mean L1 vs before is 4.02. Full-frame pale-pixel count (R>200, G>210, B>220) is 3370 -> 3381. At size 33.75 the volume reads as a short courtyard puff, not the studio-scale fan. |
| Target slides away from Kalev | **PASS.** Before: Kalev and watchman stand close on `street_start`. After: the watchman is farther right (east, +X). Crop L1 before->after 1.58. |
| No white-sheet or missing-actor frames | **PASS.** Both actors stay visible in before/mid/after. The overlay is a translucent puff, not an opaque wash. Files are 1440x810, ~2.8 MiB. |

## Capture notes

1. The first attempt focused the midpoint of `checkpoint_west` -> `brewery_door`. That cell sits inside roof mass, so the plates were only tiles. The accepted crop uses `street_start` (logic 2688, 1760; world 84, 0.8, 55).
2. Actors are placed with `MapView3D.sync_actor` so they sit on terrain. Heading is `Vector2.RIGHT` along the east-west spine.
3. Studio plates were regenerated during the first full run and restored to HEAD. `tools/capture_air_gust.gd` now accepts `--skip-studio`.

## Verification

Commands run from the project root on 2026-09-26:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT_LOG_DIR=/tmp/rebel-reval-r927
./tools/run_godot_checked.sh --require-test-summary \
  r927-air-gust -- "$GODOT_BIN" --headless --path . \
  --script tools/run_godot_tests.gd -- \
  --filter=test_magic_air_gust,test_map_view_magic_vfx
# Godot 4.7.1: 2 file(s), 9 test(s), 0 failure(s), 0 error(s).

tools/godot_render.sh --script tools/capture_air_gust.gd
# later in-map-only: tools/godot_render.sh --script tools/capture_air_gust.gd -- --skip-studio
```

Plate inventory (new in-map set; studio pair unchanged):

- [`in_map_lower_town_before.png`](images/air_gust/in_map_lower_town_before.png)
- [`in_map_lower_town_mid.png`](images/air_gust/in_map_lower_town_mid.png)
- [`in_map_lower_town_after.png`](images/air_gust/in_map_lower_town_after.png)

## Handoff

- R-927: move to done.
- Optional follow-up (not required): if a later review wants the gameplay-scale puff to read as a clearer fan against cobble, file a Dev row to scale `MapViewMagicVfx` for camera size 33.75. Do not restyle from this note.
