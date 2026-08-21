# P0-102 three-tier gameplay capture

**Task:** R-667 / P0-102 decomposition
**Parent:** R-110 / P0-102
**Recorded:** 2026-08-22
**Status:** **CAPTURE COMPLETE - visual acceptance remains open**
**Map:** `lower_town_slice`
**Captured source revision:** `HEAD=5236487ff56a7c92f440758e92b90b97c5123153`; shared worktree contained unrelated WIP
**Authored map fingerprint:** `13525325b3d8be840c79d8c709c8aab12632bc6092a7123bc6d9275ba51d17ba`

## Decision

R-667 adds a deterministic matched day/night gameplay-camera pair for the same Lower Town route. The helper reuses `LowerTownSlice.create()`, `MapBuilder.build()`, and `MapView3D.create()`; it does not edit house meshes, map assignments, runtime builders, parity fixtures, or provenance rows.

The packet is evidence of camera/revision/file integrity and stable-ID coverage. It is not a human historical or art sign-off and does not promote source metadata into visual acceptance.

## Capture contract

| Field | Recorded value |
|---|---|
| Route | `checkpoint_west -> brewery_door` on `merchant_craft_lane` |
| Camera | shipped orthographic gameplay camera, `orthographic_size=33.75`, pitch `-30.0`, yaw `45.0` |
| Renderer | `gl_compatibility`, OpenGL 4.1 Metal compatibility driver |
| Viewport | `1280x720` |
| Mode | one `day` plate and one `night` plate with the same `framing_key` |
| Stable IDs observed | `kaik_house_west`, `viru_house_west`, `sauna_corner_house`, `saddlers_rear_workshop` |
| Tier labels | `merchant_stone`, `merchant_timber`, `craft_boda` |
| Material families recorded | limestone, plaster, log |
| Roof families recorded | tile, shingle, thatch |
| Exceptional boundary | `st_catherines_church`, `viru_gate_arch`, and `viru_foregate_arch` remain a separate list and are not counted as ordinary coverage |

## Outputs

- [`three_tier_route_day.png`](images/p0_102_three_tier/three_tier_route_day.png) - matched gameplay-scale day plate
- [`three_tier_route_night.png`](images/p0_102_three_tier/three_tier_route_night.png) - matched gameplay-scale night plate
- [`capture_manifest.json`](images/p0_102_three_tier/capture_manifest.json) - schema, command, map fingerprint, route, camera, IDs, tier/material/roof metadata, and plate records

Both PNGs decode at `1280x720`, have non-flat pixel payloads, and share the framing key:

```text
three_tier_route|[1328.0, 1800.0]|0.8|33.750|-30.000|45.000
```

## Reproduction

Run once for the complete matched pair:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
  --script tools/capture_p0_102_three_tier_gameplay.gd
```

Run one plate at a time when isolating renderer output:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
  --script tools/capture_p0_102_three_tier_gameplay.gd -- --time day

/Applications/Godot.app/Contents/MacOS/Godot \
  --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
  --script tools/capture_p0_102_three_tier_gameplay.gd -- --time night
```

The checked capture run wrote both files successfully. Godot emitted only the known shutdown ObjectDB/resource cleanup diagnostics after output was written.

## Verification

The following evidence checks passed on the captured files:

```text
three_tier_route_day.png: 1280x720, unique_rgb=86405, non-flat
three_tier_route_night.png: 1280x720, unique_rgb=1315, non-flat
manifest: 2 plates, matched framing_key, day/night, lower_town_slice, all three tier labels
```

Focused contract commands:

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_burgher_house_tiers
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_lower_town_slice_map
```

The existing P0-102 environment-kit verifier remains a separate eight-plate contract and is not a verifier for this new directory:

```bash
python3 tools/verify_p0_102_environment_kit_evidence.py
```

That distinction is intentional. This task's manifest and PNG integrity were checked directly so the dedicated three-tier packet cannot be confused with the four-space environment-kit packet.

## Limitations and handoff

- The route crop is gameplay-scale rather than a close-up. Wall-family and roof-cover readability still require human visual review.
- Stable IDs and authored tier metadata identify the intended observations; they do not by themselves prove that each tier is visually legible in the rendered frame.
- No visual sign-off is claimed by R-667. R-108/P0-101 and the art/canon reviewers must inspect the pair before changing any pending acceptance row.
- The shared worktree was dirty with unrelated changes; the manifest records the captured map fingerprint and this report records the source `HEAD` separately.

## Focused suite results

The scoped tier contract passed:

```text
`test_burgher_house_tiers`: 5 tests, 0 failures, 0 errors
```

The Lower Town map contract passed 18/19 tests. Its only failure is the pre-existing canonical parity-fixture mismatch below; all route reachability, tier, stable-ID, gate, validation, navigation, water, and seam assertions passed:

```text
`test_lower_town_slice_map::test_lower_town_slice_matches_canonical_parity_fixture`
expected walkability_sha256: 57e9b9d32a01099e4c399e51b1552e5edbf6eba58d07eff5b6975d081bbbbf8f
actual   walkability_sha256: 0c33d876cd74bdd69c35cb4e91e4b1503112cb1adf690c2072219c72f85a4944
```

R-667 does not regenerate or edit the parity fixture because the task explicitly forbids parity-fixture regeneration and the capture helper does not mutate map gameplay data. The mismatch is handed to a separate follow-up task.
