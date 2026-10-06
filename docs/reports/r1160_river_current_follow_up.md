# R-1160 follow-up: the Pirita current follows its channel

The first R-1160 pass (commit `07e8acd0`) gave `river_water` a downstream read:
wave trains, stretched ripples, sheen filaments and foam ribbons all travel along
one authored heading, `(0, -1)` (south to north). The Pirita meanders by about
±5 cells over its length, so that single heading ran the whole surface pattern
diagonally across the banks on every bend, and the water moved at the same speed
from bank to bank, which reads as a conveyor belt rather than a river.

## What changed

- `scripts/map/view3d/map_view_river_flow.gd` (new) reduces the authored
  `TERRAIN_RIVER_WATER` cells of a map to a downstream-ordered channel
  centreline: per scan line across the channel, the mid-point and the local half
  width, smoothed and downsampled to the 24-point shader uniform. It is a pure
  function of the terrain grid, so it bakes on a worker next to the shore field
  (`compute_river_flow` / `attach_river_flow`, bound in the terrain stage).
- `map_view_water.gdshader` resolves `_river_current(world_xz)` per fragment and
  per wave sample: the heading of the nearest reach, plus an across-channel speed
  profile (`RIVER_BANK_DRAG`, the bank keeps 35 % of the mid-channel speed).
  Ripples, sheen and foam now follow the bend, and slack water near the bank is
  glassier. A varying speed cannot use one sliding offset without shearing the
  pattern without bound, so the ripple layer crossfades two half-cycle phases
  (`RIVER_FLOW_CYCLE`).
- Maps with no reducible channel (sea, ponds) keep `river_path_count == 0` and
  the previous single-heading behaviour. The binding is per map on a shared
  material, like the WS-08 shore field.
- The foam ribbons and sheen filaments were a single warped `_noise` call. On a
  river, which has no wave displacement to break a lattice up, that showed as
  rectangular patches; `_river_threads` adds a second octave on a lattice rotated
  37° and the foam weight came back down (0.75 → 0.55).

## Verification

Godot 4.7, `tools/run_godot_tests.gd`:

- `--filter=test_river_flow_field`: 6/6 (straight reach, meander, east-west
  channel, downsampling, no-river fallback, the authored Pirita).
- `--filter=test_coastal_sea_3d,test_viru_gate_foreland_map`: 28/28.
- `--filter=test_map_view_3d_core,test_r715_water_rollout_inventory,test_underwater_pass,test_r715_water_exceptions,test_r715_water_surface_geometry,test_ocean_fft_material,test_map_scene_bootstrap,test_sky_weather_3d,test_r455_city_elevation_readability`:
  98/98.
- `--filter=test_boat_float_3d,test_map_relief_water,test_r715_water_material_contract,test_r715_water_weather_sync,test_shore_distance_field`: pass.
- `python3 -m gdtoolkit.linter` on every changed script: clean.

Captures, `tools/godot_render.sh --rendering-method gl_compatibility
--rendering-driver opengl3 --script tools/capture_river_flow.gd`, 1280x720,
weather clock frozen so only the current moves:

| Framing | Plate |
| --- | --- |
| Straight reach at the ford, channel width fills the frame | [river_reach_0.png](images/river_flow/river_reach_0.png) |
| Meander south of the ford | [river_bend_0.png](images/river_flow/river_bend_0.png) |

Three shots 1.2 s apart per framing. Pillow mean absolute difference between
shots: reach 2.5-3.4 / 255 with 17-22 % of all frame pixels changing by more
than 6, bend 1.2-1.5 with 7-9 %. The water covers roughly a third of each frame,
so the surface itself changes across most of its area between shots. This is a
motion check, not an art sign-off.

## Known limitations

- The channel surface still shows faint rectangular panels of slightly different
  tone. They are not from the current: they are unchanged by the foam, sheen and
  wave-normal passes and do not travel downstream, which points at the bed read
  through the clear water column rather than at the water surface. Confirming and
  fixing that belongs with the terrain surface work, not here.
- `scripts/map/view3d/map_view_river_flow.gd` assumes one channel per map that is
  longer than it is wide. A fork, an oxbow, or a river mouth that opens into a
  basin would reduce to a misleading centreline; such a map should either stay on
  the single authored heading or get a per-reach authored path.
- A named human review of the current in motion is still open, as is a review of
  the Metal mobile path, which renders this map noticeably washed out compared
  with the shipped Compatibility renderer (a pre-existing difference, visible in
  both renderers' plates during this work).
