# WS-13d - Timber crib and pile geometry under harbour landings

Status: implemented 2026-09-26 (board R-905). Follow-up to [WS-13b](WS-13b_harbour_basin_depth.md).

## Player-facing goal

Under water, the timber landings of Harbor North (`pier.west`, `pier.east`) and the other sea maps
with `timber_floor` decks stand on a stacked-log crib with guide piles down to the WS-13b rendered
bed, instead of a smooth earth mound. The top-down gameplay view does not change.

## Allowed files (amended)

- `scripts/map/view3d/map_view_pier_crib_builder.gd` (new, `MapViewPierCribBuilder`)
- `scripts/map/view3d/map_view_mesh_builder_terrain.gd` (pier distance field, one build call)
- `scripts/map/view3d/map_view_mesh_builder_config.gd` (pier slope and crib constants)
- `tests/godot/test_ws13d_pier_cribs.gd` (new)
- `docs/reports/images/ws13d_*.png`, this file, `docs/tasks/water_sky/README.md`,
  `docs/tasks/water_sky/WS-13b_harbour_basin_depth.md`, `docs/reports/reval_harbour_1343_research.md`,
  `TODO.md`

## Decisions

1. **The pier face is made steep in the bed, not faked in front of it.** `timber_floor` cells
   (`SEA_BASIN_PIER_TERRAINS`) leave the WS-13b `basin_hard` field and get their own chamfer field
   with `SEA_BASIN_PIER_SLOPE = 12` per cell, so the bed reaches the local basin depth one terrain
   subvertex (1/3 cell) off the deck. Natural banks and stone/paving edges keep their WS-13b slopes;
   the nearest limit still wins. Waterline vertices do not move, so the deck and everything above
   the surface keep their exact shape.
2. **Logs follow the rendered face.** `MapViewPierCribBuilder` reads `bed_positions` directly.
   Terrain vertices are jittered in XZ, so each face profile keeps the real outward distance of
   every vertex row; each log sits one radius plus `FACE_GAP` outside the furthest face point above
   it (a slight batter, as real cribs have). Logs buried by the floor, or where a beach shelves the
   bed further out than `MAX_FACE_OFFSET`, are skipped.
3. **Everything stays under the surface.** Log and pile tops stay `CRIB_TOP_CLEARANCE` (0.22 units)
   below the rest water level. Pile feet are driven `CRIB_BED_EMBED` into the rendered bed
   (`view_bed_height`). No collision, navigation, content or save change.
4. **Two draws, no shadows.** Logs and piles are merged into `PierCribLogs` and `PierCribPiles`
   under `Terrain/PierCribs`, with a wet, algae-darkened copy of the hewn-oak material and shadow
   casting off. Triangles: Harbor North 1 768, Harbor East 6 408, Saaremaa 9 608.
5. **Historical label.** A stone-filled log crib is a reconstruction consistent with the research
   note's "short timber/rubble landings". It is not an attested 1343 Reval structure; see
   [`reval_harbour_1343_research.md`](../../reports/reval_harbour_1343_research.md).

## Verification

- `--filter=test_ws13d_pier_cribs` (6 tests): pier face depth vs stone landing, one crib face per
  sea-facing deck edge, no bank vertex in front of an upper crib log, pile feet on the rendered
  bed, shadowless nodes under the surface, none on inland water, both Harbor North landings clad.
  `--filter=test_ws13b_sea_basin_depth` stays green.
- Plates (`tools/capture_underwater.gd --shot=under_horizontal`, `reval_harbor_north`):
  [`ws13d_under_horizontal_metal.png`](../../reports/images/ws13d_under_horizontal_metal.png) and
  [`ws13d_under_horizontal_gl.png`](../../reports/images/ws13d_under_horizontal_gl.png), against
  the WS-13b `ws13b_under_horizontal_*` mound.
- Overview parity (GL Compatibility, `--shot=overview`, A/B with `SEA_BASIN_PIER_TERRAINS` empty):
  53 of 921 600 pixels differ by more than 8/255, all at the two pier tips; a rerun of the same
  build differs by 0 pixels. Diff:
  [`ws13d_overview_diff_gl.png`](../../reports/images/ws13d_overview_diff_gl.png) (x6 gain).

## Known limitations

- The deep ends of the tip piles reach the deep-water step in front of the shallow crib, so they
  stand slightly proud of the crib bottom in the plate. That is a correct bed contact, not a gap.

## WS-13e follow-up (R-921, 2026-09-26)

Harbor East (`reval_harbor_east`, 3 timber landings) and Saaremaa (`world.saaremaa`, ferry and
strait decks) already built cribs; this pass reviews them and closes the two visual gaps above.

### Decisions

1. **Saddle notches, not round caps, at tip corners.** Same-cell perpendicular faces mark
   `notch_from` / `notch_to` on their logs. Those ends skip the saw-cut disk and add a U-shaped
   remaining-wood saddle (two cheeks and a lintel) so the joint reads as a notched cabin corner.
2. **Visible stone fill inside the crib.** Each deep face packs up to
   `CRIB_RUBBLE_ALONG x CRIB_RUBBLE_MAX_LAYERS` irregular boxes between the deck edge and the
   innermost log. Stones stay under `CRIB_TOP_CLEARANCE`. They share the `PierCribLogs` node as a
   second surface (`wet_rubble`, darkened fortification masonry) so the map keeps two MeshInstance
   children (logs+rubble, piles). Godot issues one extra GPU draw for the stone surface.
3. **No third child, no shadows, no collision.** Overview water silhouette is unchanged because
   nothing rises through the rest surface.

### Verification

- `--filter=test_ws13d_pier_cribs` (9 tests): previous WS-13d cases plus tip notches, rubble under
  the surface, and crib/notch/fill coverage on Harbor East and Saaremaa.
- Plates (`tools/capture_underwater.gd --shot=under_horizontal`, `state=2` UNDER):
  Harbor East mid-pier tip `--pos=62.2,-0.85,24.4 --look=64.2,-0.55,26.3` ->
  `docs/reports/images/ws13e_harbor_east_under_horizontal_{metal,gl}.png`.
  Saaremaa ferry `--map=world.saaremaa --pos=6.4,-1.0,21.8 --look=8.6,-0.65,24.3` ->
  `docs/reports/images/ws13e_saaremaa_under_horizontal_{metal,gl}.png`.
- Overview (GL Compatibility): `docs/reports/images/ws13e_{harbor_east,saaremaa}_overview_gl.png`.
  Geometry stays under the waterline so the top-down look keeps the WS-13d budget.
