# WS-08 — Waves break, run up the beach and leave a wet band on the sand

Part of the [water and sky task pack](README.md). Source technique: Tidewater `ShoreParams`
(`period 9`, `amplitude 0.34`, `variation 0.55`, `gamma 0.78`, `breakSpan 0.13`, `curl 1`,
`runup 1`, `turbidity 0.16`), `ShoreSimParams` (`dryTime 28`, `foamLife 4.5`, `surfFoamLife 2.6`,
`residueLife 5`) and the shore fragment code (a foam bead at the front, a trailing foam line, and a
"meniscus" where the last decimetre of the water sheet bends down to the sand).

## Player-facing goal

On sandy shores (`coast_sand`, `sand`), sets of waves roll in, steepen and break into a white bore.
Then a thin sheet of water slides up the beach with a bubbly foam line at its front and slips back.
It leaves darker wet sand that slowly dries and a faint foam residue line at the highest reach. The
surf zone is slightly milky with stirred-up sand. Against quay walls and rocks, waves don't run up.
They slosh and throw foam at the foot of the wall.

## Why

Today the shore has two travelling `sin()` breaker bands and noisy edge foam inside the clipped
water mesh. The water never leaves its contour, so nothing moves up the beach and the sand never
gets wet.

## Allowed files

- `scripts/map/view3d/shore_swash.gdshaderinc` (new: shared swash functions)
- `scripts/map/view3d/map_view_water.gdshader`
- `scripts/map/view3d/map_view_terrain_blend.gdshader` (wet sand and residue only)
- `scripts/map/view3d/map_view_mesh_builder_terrain_water.gd` (the shore distance field and swash
  sheet mesh)
- `scripts/map/view3d/map_view_water_materials.gd`, `scripts/map/view3d/map_view_materials.gd`
  (wiring the shared field texture and uniforms)
- `tests/godot/test_shore_distance_field.gd` (new), `tests/godot/test_r715_water_material_contract.gd`,
  `tests/godot/test_r715_water_surface_geometry.gd`
- `docs/reports/images/ws08_*.png`
- `TODO.md`

## Dependencies

- TODO: **WS-04**, so the shore waves inherit the sea state and `ocean_time`. WS-06 is recommended
  so the foam look matches.
- Stable IDs: no map, terrain or anchor IDs change. The swash sheet is generated view geometry, not
  authored map content (see [`docs/MAP_AUTHORING.md`](../../MAP_AUTHORING.md)). It must not get a
  persistent ID or collision.

## Constraints and non-goals

- Deterministic and analytic. No simulation texture and no per-frame CPU work. Every effect is a
  pure function of `(shore distance, along-shore coordinate, ocean_time, sea state)`, so the wet sand
  and the water always agree.
- Gameplay is unchanged. The swash sheet has no collision, and navigation and walkable cells don't
  change.
- Rivers get no swash. `river_water` keeps its current bank treatment.
- The tide logic (`tide_level`, `tide_shore_retreat`) stays. The swash rides on top of the current
  tide line.

## Deliverable

1. **Shore distance field** (runtime generated, not an asset). In
   `map_view_mesh_builder_terrain_water.gd`, after `bake_water_contour`, build an `ImageTexture` at
   4 texels per cell covering the map (`FORMAT_RGBAH`, or RGBA8 with explicit encoding if RGBAH
   isn't allowed on Compatibility, so check first):
   - R: signed distance to the shoreline contour in world units (+ = water, − = land), clamped to
     ±8. Compute it with a two-pass distance transform on the contour coverage grid.
   - G, B: the unit direction towards land (the normalised negative gradient of R), encoded 0..1.
   - A: shore type. 1 = beach (the adjacent land cell is `coast_sand` or `sand`), 0 = hard edge
     (wall, stone, quay or anything else).
   Pass it and its world-space transform as uniforms to the water material and the terrain blend
   material (`shore_field`, `shore_field_origin`, `shore_field_size`).
2. **Swash sheet mesh.** For every beach shoreline segment, generate a strip that extends up to
   3 world units inland, laid on the terrain surface + 0.01 and densely subdivided across-shore
   (≥ 12 rows). It uses the water shader with `uniform bool swash_sheet = true`. Hard edges get no
   sheet.
3. **`shore_swash.gdshaderinc`.** It exposes
   `ShoreState shore_state(vec2 world_xz, float t, vec4 sea)`, which returns the wave height,
   bore foam, whether the point is wet, sheet thickness, front distance and time since last wetted.
   The model:
   - **Wave sets:** period `P = 9 s · mix(1.2, 0.8, sea_state)`. The along-shore phase variation is
     `variation·noise(along·0.05)`, so crests aren't parallel lines. An `along` coordinate is
     derived from the direction field: integrate by projecting `world_xz` on the perpendicular of
     the shore direction.
   - **Shoaling and breaking:** the wave height grows as `H = amplitude·sea·(d₀/d)^0.25`, and it
     breaks where `H > gamma·d` (`gamma = 0.78`, `d` = water depth in metres from the distance field
     × beach slope ≈ 0.05). Before breaking the crest steepens: use a skewed profile
     `pow(0.5+0.5·cos φ, 1 + 2·steep)`. After breaking there is a foam bore that decays with
     distance (`breakSpan 0.13` of the surf-zone width).
   - **Run-up:** once the bore reaches the contour, the sheet front moves inland to
     `R = runup·H·1.8` world units over about 35% of the period and then drains back more slowly
     (backwash). Use an ease-out up and an ease-in down.
   - **Front foam:** a narrow bright *bead* at the moving front plus a thinner *trail* behind it.
     Break both into patches with two octaves of noise (as Tidewater's `edgePatch` does), so it's
     never an even white rope.
   - **Meniscus:** in the last `0.14` of the sheet, fade the sheet's opacity to zero and darken it
     slightly, so the edge reads as water bending down to the sand, not a cut polygon.
   - **Wet time:** because the model is periodic, `time_since_wet` is analytic: the time since the
     phase at which this point was last reached, `fract(φ − φ_reach(x))·P`, or "never" if
     `R` never reaches `x`.
4. **Water shader:**
   - In the surf zone (distance < break distance), replace the two `sin()` breaker bands with the
     swash bore foam.
   - Add the shore wave height to `VERTEX.y` (with a small `curl` push towards shore at the crest
     top, `curl = 1`).
   - Tint the water towards sand colour by `turbidity (0.16) · surf_zone_mask`.
   - When `swash_sheet` is true, discard where the point isn't currently covered, and output a thin,
     mostly transparent water film. It is mostly the refracted sand darkened by the WS-01 extinction
     over the sheet thickness, plus the front foam and a strong Fresnel reflection. Set
     `ALPHA` from the thickness and meniscus.
   - Hard-edge shore (`A = 0`): a vertical slosh `± H·0.5`, a foam band at the wall foot, and no
     sheet.
5. **Terrain shader (wet sand):** sample `shore_field` and `shore_state()`. For sand and coast_sand
   only:
   `wet = exp(-time_since_wet / 28.0)`. Darken the albedo by up to 45%, lower the roughness towards
   0.25, and add a faint specular sheen. At the highest-reach line, draw a thin foam residue line
   with a 5 s life (`residueLife`). This reuses the style of the existing `mud_wetness` film. Don't
   change the mud logic.
6. **Quality tiers:** on `minimum`, drop the swash sheet mesh (keep the bore foam and wet sand).

## Verification

1. The headless Godot suite passes. `test_shore_distance_field.gd`, on a synthetic
   `MapTerrainGrid` (a straight beach and a quay corner), checks:
   - distance signs and magnitudes (±0.1 cell)
   - the direction points to land
   - shore type 1 on sand and 0 on stone
   - deterministic output
   - the sheet mesh is only generated on beach segments and has no collision
2. `test_r715_water_surface_geometry.gd` still passes. The water mesh contours are unchanged.
3. Map pipeline checks (the builder is part of view generation):
   ```bash
   godot --headless --path . --script tools/validate_map_blueprints.gd
   python3 tools/verify_map_audit.py
   python3 tools/verify_map_activation.py
   ```
4. Captures (Metal and Compatibility) on `reval_harbor_east`, which has `coast_sand`: `clear/day`,
   `storm/day` and `clear/night`, plus a 20 s clip at `clear/day`. Checks:
   - wave sets break and run up
   - the front has broken foam
   - the sheet edge fades without a hard polygon line
   - sand behind the swash is darker and dries over about 30 s
   - quay walls in the same map slosh and don't run up
   - storm run-up reaches further
5. Performance: water and terrain frame time from `tools/run_performance_report.sh --quick`. The
   swash include runs one texture sample and a handful of noise calls per fragment.

## Documentation updates

- A short section in [`docs/MAP_AUTHORING.md`](../../MAP_AUTHORING.md) explaining that the swash
  sheet and shore field are generated view output (one paragraph). Add `docs/MAP_AUTHORING.md` to
  the allowed files when you do this.
- `TODO.md` row:
  ```text
  - [ ] WS-08 | deps: WS-04 | deliverable: runtime shore distance field + generated beach swash sheet with analytic wave sets, shoaling/breaking bore, run-up/backwash with bead/trail foam and meniscus fade, surf turbidity, wall slosh, and deterministic wet-sand drying with residue line | allowed files: `scripts/map/view3d/shore_swash.gdshaderinc`, `scripts/map/view3d/map_view_water.gdshader`, `scripts/map/view3d/map_view_terrain_blend.gdshader`, `scripts/map/view3d/map_view_mesh_builder_terrain_water.gd`, `scripts/map/view3d/map_view_water_materials.gd`, `scripts/map/view3d/map_view_materials.gd`, `tests/godot/test_shore_distance_field.gd`, `tests/godot/test_r715_water_material_contract.gd`, `tests/godot/test_r715_water_surface_geometry.gd`, `docs/MAP_AUTHORING.md`, `docs/reports/images/ws08_*.png`, `TODO.md` | verify: shore field tests; map validation/audit/activation; reval_harbor_east clear/storm/night captures and 20 s clip show breaking sets, run-up sheet with fading edge, drying wet sand, and wall slosh
  ```
