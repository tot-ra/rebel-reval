# CO-02: Shore debris - rocks, boulders, pebbles, seaweed and wrack

Board row: **R-949**. Priority: high. Depends on: CO-01.

## Player-facing goal

The Kalamaja and Harbor North tide margins are littered the way a real Baltic shore is: erratic
granite boulders standing in the shallows, pebble and shingle patches where the storm throws them,
bladderwrack and reed wrack rotting in a line at the high-water mark, barnacled stones going green
below the waterline. Walking the beach, the player sees a different arrangement in every cove, and
the boulders are solid obstacles that the eye can use to judge distance and depth.

## Why this is needed

`assets/props/` has **no** rock, boulder, pebble, shingle, seaweed, wrack or kelp family at all
(checked 2026-09-26 across `assets/props/{environment,architecture,...}`). The only stone assets are
building limestone and paving. Saaremaa fakes boulders with `terrain_rects alvar.boulders stone`, a
flat terrain paint. So the shore has ground and vegetation and nothing in between, which is why it
reads as a smooth ramp into the sea.

## Deliverable

1. A new prop family under `assets/props/environment/shore/`, authored as GLB through the existing
   Blender prop pipeline, each with albedo + normal + roughness:
   - `shore_boulder_granite` - 3 size variants (roughly 0.6 m, 1.2 m, 2.1 m across), erratic glacial
     granite, one variant with a barnacle/algae band for use at the waterline
   - `shore_stone_cluster` - 2 variants of grouped fist-to-head-size stones
   - `shore_pebble_patch` - 2 flat shingle patch meshes for scatter, using the CO-01
     `shore_shingle` material
   - `shore_wrack_line` - 2 variants of bladderwrack and reed wrack drift
   - `shore_algae_skirt` - submerged algae skirt for boulder bases and pier cribs
2. A deterministic scatter pass in `scripts/map/view3d/map_view_terrain_details.gd` seeded from the
   map seed plus cell, placing the family by **distance to the waterline** using the WS-08 shore
   distance field: algae and barnacled boulders below the line, wrack in a band at the line, dry
   stones and shingle above it. Density and variety per terrain family, `MultiMesh`-batched with the
   existing LOD path, bounded per chunk.
3. Boulders above 1.0 m contribute collision; everything smaller is decoration and must not block.
   Navigation and every existing walkable route stay valid.
4. `assets/SOURCES.csv` rows for every mesh and texture.

## Allowed files

- `assets/props/environment/shore/**` (new)
- `assets/SOURCES.csv`
- `scripts/map/view3d/map_view_terrain_details.gd`
- `scripts/map/view3d/map_view_mesh_builder_prop_models.gd` (registration only)
- `scripts/map/view3d/map_view_materials.gd` (shore material lookup only)
- `tests/godot/test_shore_debris_scatter.gd` (new), `tests/godot/test_shore_distance_field.gd`
- `tools/build_shore_debris.py` (new Blender build script), `tools/capture_co02_shore_debris.gd` (new)
- `docs/FLORA_FAUNA.md`, `docs/ART_BIBLE.md`, `docs/reports/co02_shore_debris.md`,
  `docs/reports/images/co02_*.png`, `TODO.md`

## Constraints and non-goals

- Asset freeze P0-040: only the files listed above. No legacy isometric or pixel assets.
- Determinism: the same map seed must produce the identical scatter, chunk order independent. No
  runtime randomness that is not seeded from `(map_seed, cell)`.
- Do not change terrain IDs, map geometry, transitions, spawns or anchors.
- Do not place props that block a pier deck, a landing, a transition rect, a spawn or an anchor cell.
- Do not regress the P0-159 fauna/vegetation LOD and instancing budget.
- Saaremaa's `alvar.boulders` terrain paint stays: CO-09 decides whether to replace it. Do not
  silently delete it here.

## Verification

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_shore_debris_scatter,test_shore_distance_field
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/validate_map_blueprints.gd
python3 tools/verify_map_audit.py
python3 tools/verify_map_activation.py
python3 tools/validate_asset_sources.py && python3 tools/verify_asset_lint.py && python3 tools/verify_storage_hygiene.py
python3 tools/generate_active_docs_report.py --check
```

- `test_shore_debris_scatter.gd` asserts: same seed gives the same placements twice; no placement on a
  pier/landing/transition/spawn/anchor cell; sub-1.0 m props add no collision; algae only below and
  wrack only within one cell of the waterline; per-chunk instance count bounded.
- A route test proves the largest walkable region on `reval_harbor_east` and `reval_harbor_north` is
  unchanged in size after scatter (4326 and 6333 cells as measured 2026-09-26).
- `tools/capture_co02_shore_debris.gd` through `tools/godot_render.sh`: Kalamaja cove and spit plates
  clear noon and storm, plus one underwater plate showing algae and barnacle bands, before and after.

## Doc updates

`docs/FLORA_FAUNA.md` shore-debris section, `docs/ART_BIBLE.md`,
`docs/reports/co02_shore_debris.md`, `TODO.md`.

## TODO.md line

```
- [ ] R-949 | deps: R-948 | deliverable: shore boulder/stone-cluster/pebble-patch/wrack/algae GLB family with waterline-aware deterministic scatter and collision only above 1.0 m | allowed files: per docs/tasks/coast/CO-02_shore_debris_props.md | verify: `--filter=test_shore_debris_scatter,test_shore_distance_field`; blueprint validate, map audit and activation; asset sources/lint/storage; walkable region unchanged at 4326 (harbor east) and 6333 (harbor north); Kalamaja cove/spit/underwater plates before/after
```
