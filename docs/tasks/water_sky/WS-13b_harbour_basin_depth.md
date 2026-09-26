# WS-13b - Real underwater depth for harbour basins

Part of the [water and sky task pack](README.md). Follow-up to
[WS-13](WS-13_underwater_view_pass.md) (board R-901). This file is the task amendment the board
row asked for before coding: it is a view-geometry fix inside the approved water pack, not a scope
change (no new system, mechanic, area or gameplay state), so no ADR is needed.

## Player-facing goal

Under the surface of the open sea (Harbor North roadstead, berths, other `deep_water` /
`shallow_water` maps), the camera sees metres of water: the bed fades to turquoise with distance,
banks and pier cribs drop away, and hulls hang over a real floor. From the gameplay camera above
the surface the harbour looks the same as before.

## Why

WS-13 landed the underwater pass on a ~9 mm water column (bed recessed 0.08, surface lift 0.006),
so its plates showed the medium and Snell's window but no depth. WS-14 (swimming) cannot work on
that geometry.

## Allowed files

- `scripts/map/view3d/map_view_mesh_builder_config.gd` (basin constants)
- `scripts/map/view3d/map_view_mesh_builder_terrain.gd` (basin bake, rendered bed, seabed palette,
  border apron, `view_bed_height`)
- `scripts/map/view3d/map_view_mesh_builder_terrain_water.gd` (UV2 flat-bed flag on in-map water)
- `scripts/map/view3d/map_view_water.gdshader` (optical column measured to the flat bed)
- `tools/capture_underwater.gd` (camera depth, near plane, `under_sun` shot)
- `tests/godot/test_ws13b_sea_basin_depth.gd` (new)
- `docs/tasks/water_sky/WS-13b_harbour_basin_depth.md`, `docs/tasks/water_sky/README.md`
- `docs/reports/images/ws13b_*.png`
- `agents/rebel-dev/playbook.md`, `TODO.md`

Not touched: gameplay height (`ground_height`, collision, navigation, props), the water surface
height, the FFT geometry budget (`fft_geometry_scale`, trough floor), WS-01 refraction, the
surroundings builder and the underwater pass shader.

## Dependencies

- Done: WS-13 (R-898). Stable IDs: none. No save data.

## Deliverable (as built)

1. **Basin bake** (`_bake_basin_cells`): per cell, a target depth below the gameplay bed
   (`SEA_BASIN_DEPTH`: `shallow_water` 1.0, `deep_water` 3.6 units; rivers, ponds and ditches 0)
   plus two chamfer distance fields to the nearest natural dry cell (`NATURAL_SHORE_TERRAINS`) and
   the nearest hard dry cell (piers, stone, paving). Cells outside the map count as water.
2. **Depth profile** (`basin_extra_depth`): `min(target, natural_edge * 0.45, hard_edge * 2.4)`
   with bilinear cell-centre interpolation, so beaches shelve and pier cribs drop almost straight.
3. **Rendered bed** (`bake_bed_vertices`): `field["bed_positions"]` / `["bed_normals"]` /
   `["bed_offsets"]`. Only sea-cell subvertices that touch no dry cell move; waterline vertices
   and their normals are bit-identical. `field["positions"]` stays the flat gameplay bed because
   the water surface mesh, the WS-08 swash sheet and scatter read it. Deepened vertices use a
   `coast_sand` / `mud` seabed blend instead of the dry-neighbour or grass fallback.
4. **Seabed apron** (`build_seabed_apron_mesh`, node `SeaBedApron`): flat strips extruded
   `SEA_BASIN_APRON_REACH` (24) units outward from border segments whose bed is deepened, reusing
   the border bed vertices, so rays leaving a basin through the map edge meet a floor.
5. **Top-down parity** (water shader): in-map water carries `UV2 = (1, -WATER_RECESS)`. For those
   meshes the fragment clamps the scene depth to where the eye ray meets the flat bed plane
   (`_flat_bed_view_depth`, re-encoded through the same raw-depth round trip as a depth sample on
   either renderer), so every optical term (absorption, bed layers, caustics, foam fades) sees the
   old column. The underwater pass reads the raw depth buffer and sees the real basin.
6. **Capture tool**: UNDER shots sit 1.2 units under the surface (never closer than 0.35 to the
   rendered bed; thin-film water falls back to the WS-13 pose), near plane 0.01 (0.0004 for the
   film fallback), dip depth 0.12, new `under_sun` shot facing the refracted sun.

## Verification

1. Headless: `test_ws13b_sea_basin_depth` (7 tests: basin depth vs flat gameplay bed, waterline
   vertex and normal identity, hard vs natural bank slope, inland water unchanged and no apron,
   apron meets the border bed and skips land borders, UV2 flag plus shader contract, Harbor North
   roadstead deeper than 3 units). A mutation that disables the deepening fails it. Water suites
   (`test_underwater_pass`, `test_r715_water_surface_geometry`, `test_r455_city_elevation_readability`,
   `test_reval_harbor_map`, `test_r715_water_material_contract`, `test_ocean_fft_material`) pass.
2. Top-down parity, `reval_harbor_north` overview, Compatibility (`ws13b_overview_{before,after,diff}_gl.png`,
   crops of the harbour): median pixel difference 0; outside the item below, differences are 0-2 of 255.
3. Under-water plates on Metal and Compatibility: `ws13b_{under_horizontal,under_up,under_sun,straddle,under_night,under_storm,dip}_{gl,metal}.png`.
4. `tools/validate_map_blueprints.gd`: 28 registered, 0 errors. `verify_map_activation.py` passes.

## Decisions (2026-09-25)

1. **Task amendment, not ADR.** View-only geometry within the approved water pack; the allowed
   files above are the amendment.
2. **Gameplay bed unchanged.** `ground_height`, collision, props and the water surface keep
   -0.08 / +0.006. `view_bed_height()` is the view-only query for cameras, captures and WS-14.
3. **One deliberate top-down change.** The old plates show dark grass stripes in the deep water:
   the flat bed poked through FFT troughs on the 9 mm film (both renderers). With the basin they are
   gone and the water reads uninterrupted. Everywhere else the overview is unchanged.
4. **FFT budget kept.** `fft_geometry_scale` and the trough floor still assume the thin column so
   rivers, ponds and shore vertices stay covered and the top-down look is unchanged. Raising sea
   geometry over deep basins is a separate decision.
5. **Apron only along sea borders, no corner overhang.** A floor metres down survives the
   near-plane clip of the whole-map overview camera; with an overhang it showed as a sand wedge in
   the clipped foreground.
6. **Timber piers are hard edges.** Harbor North's 1343 shore has no masonry quay; the steep bank
   under `timber_floor` cells reads as a stone-filled timber crib. Real pile/crib geometry is a
   follow-up.
7. **Light shafts not met.** With real depth the WS-13 shafts are measurable but not readable: the
   procedural caustic lines are ~2.7 units apart, about one march step, so rays average them into
   haze. Broader patterns and a near-field march were tried and reverted (no readable beams at 1 m
   depth). Shafts move to a follow-up with WS-07's baked caustics.

## Cost

Basin bake on Harbor North (160 x 108): about 24 ms for the cell fields and 140 ms for the bed
vertices, measured while the full headless suite ran, on top of a ~0.7 s height-field bake. One
extra draw (apron) on sea maps. No per-frame cost; the water shader adds one plane intersection
per in-map water fragment.

## Known limitations and follow-ups

- Light shafts readable under water (with WS-07): board R-904 (WS-13c).
- Pier crib / pile geometry under timber landings: board R-905, done in
  [WS-13d](WS-13d_pier_cribs.md) (timber decks now get their own steeper crib face).
- Hairline seams between surroundings water planes now show the sand apron instead of the void
  (pre-existing crack, WS-04 note on horizontal chop).
