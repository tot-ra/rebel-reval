# R-876 / P0-185 Camera Zoom Peel Closeout

**Date:** 2026-09-24

## Scope

Task board **R-876** tracked extraction of wheel, pinch, trackpad pan zoom, and the
third-person / first-person / top-down distance continuum from
`map_view_runtime_camera.gd` into `map_view_runtime_camera_zoom.gd`.

## Result

Implementation was already present on `main`:

- `MapViewRuntimeCameraZoom` owns zoom constants, boom distance, orthographic size,
  and mode transitions triggered by scroll thresholds.
- `MapViewRuntimeCamera` delegates `zoom_view_steps`, `zoom_from_magnify_factor`, and
  `zoom_from_pan_delta` and re-exports zoom constants for stable test APIs.

## Verification

```bash
export GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_view_runtime_camera,test_map_camera_modes
```

**2026-09-24:** 2 files, 12 tests, 0 failures.

## Documentation

- `docs/ARCHITECTURE.md` inventory row and P0-185 changelog updated for zoom and shake peels.
- `docs/ROADMAP.md` coordination note (2026-09-24) already records the zoom peel.

## Follow-up

Next **P0-185** claims: `map_view_materials.gd` review or further justified facade trims
only if a new hotspot appears in the architecture audit band.
