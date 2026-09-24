# R-881 / P0-185 runtime camera modes peel (2026-09-25)

## Change

- Added `scripts/map/view3d/map_view_runtime_camera_modes.gd` for per-mode FOV/pitch/near constants, enclosed-scene initial mode selection, cycling, and `apply_mode` presentation.
- `map_view_runtime_camera.gd` keeps follow/orbit/zoom/safety delegates and re-exports mode constants for `MapViewRuntime` and capture tools.
- Orbit keeps calling `_sync_player_facing_to_camera()` on the camera facade; that method forwards to `sync_player_facing_to_camera()` on the modes helper.

## Verification

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_view_runtime_camera,test_map_camera_modes,test_map_view_3d_runtime
```

23/23 tests passed on Godot 4.7.1 (macOS).
