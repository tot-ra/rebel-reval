# R-602 Lower Town matched day/night capture evidence

**Task:** R-602 / P0-100 visual QA decomposition
**Map:** `lower_town_slice` / Workers' District
**Capture date:** 2026-08-19
**Map revision:** `HEAD=06ab54e4` at capture start; shared worktree was dirty, so the authored RRMap fingerprint is the authoritative packet identity
**Map fingerprint:** `8aaad06a1d88bce339ae1ccf809e303a0d31707e52bd6f53d67eb43f289e525c`
**Renderer:** Godot 4.7.1, `gl_compatibility`, OpenGL 3 / Metal compatibility driver
**Viewport:** `1280x720`
**Decision:** **PACKET VALID; VISUAL ACCEPTANCE BLOCKED/CONDITIONAL**

## Scope and decision rule

This report closes the capture deliverable only. It does not promote the Lower Town density pass, ordinary-fabric art, landmarks, or runtime route integration to visual acceptance. R-601 (`P0-100: verify routes, collision, transitions, and streaming`) remains `in_progress`; therefore player/entrance readability and route safety are recorded as conditional observations, not accepted results.

The packet intentionally uses the five existing gameplay-scale route presets. It does not reuse whole-map smoke images, ADR-0018 calibration images, or top-down/debug captures.

## Reproduction

The full packet can be regenerated with one process:

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --path . \
  --rendering-method gl_compatibility --rendering-driver opengl3 \
  --script tools/capture_lower_town_p0_101.gd
```

The runner also supports one process per plate. The first process creates the manifest; each subsequent process preserves the other records with `--append-manifest`:

```bash
"$GODOT_BIN" --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
  --script tools/capture_lower_town_p0_101.gd -- \
  --preset market_primary_spine --time day

"$GODOT_BIN" --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
  --script tools/capture_lower_town_p0_101.gd -- \
  --preset market_primary_spine --time night --append-manifest
```

All ten required combinations were executed through the selector mode. A representative non-headless rerun of `market_primary_spine/day` reached the real renderer and wrote a `1280x720` PNG. The shell batch exceeded the ten-minute tool ceiling after completing the packet; post-timeout inspection found no live Godot process and a complete ten-record manifest, so the packet was independently checked rather than treating the timeout as success.

## Packet integrity

| Check | Result | Evidence |
|---|---|---|
| Presets | **PASS** | Five required IDs in `capture_manifest.json` |
| Matched times | **PASS** | Five `day` and five `night` plates |
| Stable framing | **PASS** | Five framing keys, each shared by its day/night pair |
| Map identity | **PASS** | `map_id=lower_town_slice`, fingerprint recorded above |
| Camera contract | **PASS** | Gameplay orthographic size `33.75`, pitch `-30`, yaw `45`, focus height `0.8` |
| PNG decode | **PASS** | All ten files decode as RGBA `1280x720` |
| Non-blank payload | **PASS** | All ten images contain non-zero pixel data |
| Focused Godot contract | **PASS** | `test_capture_lower_town_p0_101`: 5 tests, 0 failures, 0 errors |
| Runtime route acceptance | **BLOCKED** | R-601 is still `in_progress`; this packet cannot waive its route/collision/transition/streaming gate |

The known Godot shutdown diagnostics (`ObjectDB instances were leaked` and `resources still in use`) appeared after successful output and test summaries. They are renderer/process cleanup diagnostics, not image decode failures, but remain a limitation of this capture path.

## Plate matrix

The metadata below is copied from the generated manifest. `Surface/elevation visibility` describes what the crop is intended to expose, not a signed visual-art verdict. `Player/entrance readability` remains conditional because the route/runtime gate is open and the capture runner records authored interaction targets rather than simulating a player traversal.

| Preset | Day / night outputs | Authored anchors and interaction targets | Surface / elevation visibility | Player / entrance readability |
|---|---|---|---|---|
| `market_primary_spine` | `market_primary_spine_day.png`, `market_primary_spine_night.png` | `vene_street_north` -> `checkpoint_west`; targets: `vene_street_north`, `checkpoint_west` | Market reserve and western primary-spine crop; packed-earth/stone street substrate and the authored low-town datum are inspectable in the route frame. No surface-share or elevation acceptance is claimed here. | Conditional: the west checkpoint and street entrance are the intended endpoints, but R-601's route/transition/collision result remains open. |
| `merchant_craft_lane` | `merchant_craft_lane_day.png`, `merchant_craft_lane_night.png` | `checkpoint_west` -> `brewery_door`; targets: `checkpoint_west`, `brewery_door` | Merchant frontage into the craft lane; ordinary earth/stone surface transition is in scope. The frame is not a substitute for the surface-band verification in R-598/R-607. | Conditional: checkpoint and brewery door IDs are encoded and centered by the authored midpoint; interaction clearance is not accepted independently of R-601. |
| `service_yard` | `service_yard_day.png`, `service_yard_night.png` | `brewery_door` -> `smithy_door`; targets: `brewery_door`, `smithy_door` | Brewery/smithy working-yard crop; service-yard earth, yard edges, and local elevation readability are intended review surfaces. No claim is made that the crop proves collision-free yard access. | Conditional: both production entrances are named in the manifest; gameplay approach and collision remain owned by R-601. |
| `eastern_artisan_wet_margin` | `eastern_artisan_wet_margin_day.png`, `eastern_artisan_wet_margin_night.png` | `checkpoint_east` -> `karja_gate_south`; targets: `checkpoint_east`, `karja_gate_south` | Eastern artisan edge, rear lanes, and southern wet-margin transition; dirt/mud/sand and the visible fall toward the wet margin are the intended surface/elevation review points. | Conditional: east checkpoint and Karja gate endpoint are metadata-backed; wet-margin traversal and gate clearance are not independently approved. |
| `landmark_approaches` | `landmark_approaches_day.png`, `landmark_approaches_night.png` | `checkpoint_west` -> `checkpoint_east`; targets: `checkpoint_west`, `checkpoint_east` | Inner Viru Gate and foregate approach crop; gate-side stone surfaces and the route's elevation context are visible review targets. This is not historical landmark sign-off. | Conditional: the two checkpoint endpoints are recorded; gate opening, collision, occlusion, and transition acceptance remain blocked by R-601 and the landmark review owners. |

## Verification commands and outputs

Focused packet contract:

```text
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
 tools/run_godot_checked.sh --require-test-summary r602-capture-contract-after-selector -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_capture_lower_town_p0_101

Godot headless tests: 1 file(s), 5 test(s), 0 failure(s), 0 error(s).
```

PNG/manifest audit:

```text
schema=r-560-lower-town-p0-101-capture-v1
map=lower_town_slice
renderer=gl_compatibility
viewport=[1280, 720]
plate_count=10
preset_ids=5
 time_counts: day=5, night=5
framing_pairs=5
all ten plates: 1280x720, nonblank=True
```

The ten outputs are under [`images/lower_town_p0_101/`](images/lower_town_p0_101/) and the full metadata is in [`images/lower_town_p0_101/capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json).

## Limitations and handoff

1. This is compatibility-renderer evidence on the development Mac, not a measurement on the declared minimum hardware profile. It does not establish GPU budget compliance.
2. The orthographic gameplay-scale route camera is deterministic, but the runner is a map-view capture and does not provide a player-controlled traversal recording. Anchor IDs and interaction targets are metadata-backed evidence.
3. The packet records route surface/elevation review points, but it does not prove material readability, tier distinction, wear states, historical silhouettes, or landmark sign-off. Those remain separate acceptance rows.
4. R-601 remains `in_progress`, so the report explicitly keeps player/entrance readability and route safety conditional. Do not promote this packet to an overall P0-100 or P0-101 visual pass until that gate and the relevant art/canon reviews are resolved.
5. No duplicate follow-up task is created: the blocking runtime work is already owned by R-601, while surface-band and visual-art blockers are covered by the existing R-598/R-607 and P0-101 review work.

## Sources

- [`tools/capture_lower_town_p0_101.gd`](../../tools/capture_lower_town_p0_101.gd)
- [`tests/godot/test_capture_lower_town_p0_101.gd`](../../tests/godot/test_capture_lower_town_p0_101.gd)
- [`images/lower_town_p0_101/capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json)
- [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md)
- R-601 task-board contract: route, collision, transition, and streaming verification remains open at capture time
- [`r598_lower_town_surface_elevation_verification.md`](r598_lower_town_surface_elevation_verification.md)
- [`r607_lower_town_surface_reconciliation.md`](r607_lower_town_surface_reconciliation.md)
- [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap)
