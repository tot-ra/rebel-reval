# Ambient bird contour pass — P0-216

Maintainer request: improve the 3D bird models. This follows the catalogue
realism pass in P0-212 and keeps the same species, ecology, poses and flight rig.

## Player-visible change

All 30 ambient species rebuild from `map_view_bird_anatomy.gd` revision 213.

- Body cross-sections have a keel and a flatter back, with a slightly darker dorsum.
- Folded wings are overlapping vanes around a thin arm core. The previous side oval read as a smooth sleeve.
- Flight primaries narrow and separate toward the tip. A small alula sits at the wrist.
- Bills are flattened culmens rather than round hoses. Waterfowl bills are thinner.
- Eyes keep a small catchlight.
- The shared plumage shader uses coarser barbs, a darker vane edge and keratin ridges so detail survives gameplay distance.

The five skinned storybook birds (robin, hooded crow, gull, hen, mallard) are unchanged.

A first attempt laid scapular cards on top of the hull. In the flight camera they read as a spike row down the back, so that row was removed.

## Evidence

Captured with Godot 4.7.1, Metal, on Apple M5 Pro. Each cell fits its own bounds.

- [Standing raptors and corvids](images/bird_model_pass_2026-09-23/standing_2.png)
- [Standing songbirds](images/bird_model_pass_2026-09-23/standing_4.png)
- [Flight](images/bird_model_pass_2026-09-23/flight_1.png)

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --rendering-driver metal --script tools/capture_bird_catalog.gd -- --page=2 --output=res://docs/reports/images/bird_model_pass_2026-09-23/standing_2.png
/Applications/Godot.app/Contents/MacOS/Godot --path . --rendering-driver metal --script tools/capture_bird_catalog.gd -- --page=1 --flight --output=res://docs/reports/images/bird_model_pass_2026-09-23/flight_1.png
```

## Verification

Focused catalogue, mesh and flight tests passed, including the live osprey rig.
Maximum triangles: **7,076** (cap 8,000).

`test_storybook_live_integration.gd::test_live_cast_retains_identity_health_and_fitted_equipment`
still fails on `kalev` versus `kalev_fresh`. That assertion is outside this bird
change.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_bird_catalog_realism,test_map_view_bird_meshes,test_map_view_bird_flight
```

## Limits

Bodies are still one continuous hull, not a coat of contour feathers. Flight
wings remain rigid sections. This is not AAA wildlife fidelity.
