# CO-04: Gradual coastal levels (foreshore, berm, dune, terrace)

Board row: **R-951**. Priority: high. Depends on: none.

## Player-facing goal

The Kalamaja shore stops being a single flat plane. Walking inland from the water the player crosses
four readable levels - wet foreshore, a low storm berm, a dune/scrub shelf, then the village terrace -
each with a visible slope between them, so the shore has depth in silhouette and the huts sit above
the water instead of on it. The same treatment gives Saaremaa's coast and alvar a real profile.

## Why this is needed

Measured 2026-09-26 by compiling each blueprint and reading `MapDefinition.elevation_profiles`:

| Map | Profiles | Authored height span (world units) |
|---|---|---|
| `reval_harbor_east` | 4 | **0.00 .. 0.05** |
| `reval_harbor_north` | 4 | 0.00 .. 0.60 |
| `world.saaremaa` | **0** | 0.00 .. 0.00 |

Kalamaja's entire relief is 0.05 units, roughly 4 cm. The authored intent is visible in the file
comment ("lifting the dry village edge just enough to distinguish it from the beach track"), but
0.05 is not a level, it is a rounding error. Saaremaa has no elevation authoring at all. That is the
whole of "need more gradual levels". `MapDefinition` already validates `ground_elevation` up to 8.0
units, and `lower_town_slice` is held to `elevation_range_min: 0.3` by
`docs/data/map_composition_thresholds.json`, so the machinery exists and the coast simply does not
use it.

## Deliverable

1. A documented coastal elevation ladder in `docs/MAP_AUTHORING.md`, in metres and world units
   (1 unit = 1 cell = 0.87 m), with the slope length each step needs to read as a ramp rather than a
   cliff at the gameplay camera:
   - wet foreshore 0.00
   - storm berm crest ~0.35
   - dune / scrub shelf ~0.75
   - village / yard terrace ~1.20
   - wood boundary ~1.50
2. `reval_harbor_east` elevation profiles rebuilt against that ladder using `elevation_area` and
   `elevation_ramp`, with authored height span **>= 1.2 units** and no step steeper than 0.35 units
   over fewer than 3 cells. Existing profile IDs (`r454.harbor_e.*`) are reused, not renamed.
3. `reval_harbor_north` rebuilt the same way, keeping its Coastal Gate ramp
   (`r454.harbor_n.coastal_gate_ramp`, 0.6 -> 0.1) as the top of the ladder and extending downward.
4. `world.saaremaa` gets its first elevation profiles: beach 0.0, dune 0.4, alvar plateau 0.9, Kaali
   crater rim ~2.0 with the crater floor back down near 0.3, so the crater reads as a crater.
5. A **graded seabed** companion: the WS-13b basin depth targets get an authored per-map ramp so the
   bed keeps falling away from the waterline instead of jumping to `deep_water` depth. Coordinate
   with CO-03, which widens the bands this gradient needs.
6. `docs/data/map_composition_thresholds.json` gains `elevation_range_min` for the three coastal maps
   so the flat state cannot come back.

## Allowed files

- `content/maps/reval_harbor_east.rrmap`, `content/maps/reval_harbor_north.rrmap`,
  `content/maps/world_saaremaa.rrmap` (+ `.uid`)
- `scripts/map/view3d/map_view_mesh_builder_terrain.gd` (seabed depth ramp only)
- `docs/data/map_composition_thresholds.json`
- `docs/MAP_AUTHORING.md`
- `tests/godot/test_coastal_elevation_ladder.gd` (new),
  `tests/godot/test_reval_harbor_map.gd`, `tests/godot/test_ws13b_sea_basin_depth.gd`
- `tools/capture_co04_coastal_levels.gd` (new)
- `docs/reports/co04_coastal_levels.md`, `docs/reports/images/co04_*.png`, `TODO.md`

## Constraints and non-goals

- Do not change the cell footprint of any map. That is CO-03 and CO-09.
- Do not rename or drop an elevation profile, terrain, transition, spawn or anchor ID.
- Every existing walkable route must survive: a slope must not become a wall. Character step height
  and navigation are the acceptance gate, not the screenshot.
- Do not touch buildings, props, boats, water shaders or the sky.
- Do not raise a cell that a transition rect, a spawn, an anchor or a pier deck stands on without
  proving the route still works.

## Verification

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/validate_map_blueprints.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_coastal_elevation_ladder,test_reval_harbor_map,test_ws13b_sea_basin_depth
python3 tools/verify_map_audit.py
python3 tools/verify_map_activation.py
python3 tools/verify_map_composition.py
python3 tools/generate_active_docs_report.py --check
```

- `test_coastal_elevation_ladder.gd` asserts per map: authored height span >= 1.2 (harbour) and
  >= 1.8 (Saaremaa, crater included); no elevation step > 0.35 units over < 3 cells; the four named
  coastal levels each cover >= 5% of the map's dry cells; the seabed ramp is monotonic seaward.
- Walkability regression: largest walkable region and every transition/anchor/spawn cell still
  walkable, compared against the 2026-09-26 baseline (harbor east 4326, harbor north 6333,
  saaremaa 2606).
- `tools/capture_co04_coastal_levels.gd` through `tools/godot_render.sh`: a low, shore-parallel
  gameplay-camera plate per map (the framing that shows silhouette), plus a walk clip from the
  waterline to the village terrace proving no snagging, before and after.

## Doc updates

`docs/MAP_AUTHORING.md` coastal elevation ladder, `docs/data/map_composition_thresholds.json`,
`docs/reports/co04_coastal_levels.md`, `TODO.md`.

## TODO.md line

```
- [ ] R-951 | deps: none | deliverable: documented coastal elevation ladder (foreshore/berm/dune/terrace) applied to reval_harbor_east (span 0.05 -> >= 1.2), reval_harbor_north and world.saaremaa (first profiles, crater rim), plus a monotonic seabed depth ramp and elevation_range_min thresholds | allowed files: per docs/tasks/coast/CO-04_coastal_elevation_levels.md | verify: blueprint validate; `--filter=test_coastal_elevation_ladder,test_reval_harbor_map,test_ws13b_sea_basin_depth`; map audit/activation/composition; active docs; walkable region and all transition/anchor cells unchanged vs the 2026-09-26 baseline; shore-parallel plates and a waterline-to-terrace walk clip per map
```
