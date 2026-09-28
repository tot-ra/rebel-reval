# CO-02 shore debris (R-949)

Task contract: [`docs/tasks/coast/CO-02_shore_debris_props.md`](../tasks/coast/CO-02_shore_debris_props.md).
Date: 2026-09-28. Status: implemented, in review. A named human visual review is still open.

## Result

The Kalamaja (`reval_harbor_east`) and Harbor North tide margins now carry an authored
shore debris family:

- granite erratics standing in the shallows, with a crusted, barnacled foot near the line
- a green weed apron round submerged stones
- bladderwrack and reed drift along the swash line
- shingle lenses and stone clusters on the storm ridge
- the odd small boulder further up the beach

Placement is a pure function of the map seed, the cell, and the WS-08 shore distance field.
Every cove gets a different arrangement, and the same seed always gives the same one.

## What changed

| Area | Change |
|---|---|
| Assets | `tools/build_shore_debris.py` (Blender 5.2, headless) writes 11 geometry-only GLBs and five seamless 512 px PBR plate sets (albedo, normal, roughness) under `assets/props/environment/shore/`. The build is deterministic: two runs produce byte-identical files (`shore_debris_report.json` records every SHA-256). |
| Meshes | `shore_boulder_granite_{small,medium,large}` (0.6 / 1.2 / 2.1 m), `shore_boulder_granite_barnacled` (1.6 m, upright), `shore_stone_cluster_{a,b}`, `shore_pebble_patch_{a,b}`, `shore_wrack_line_{a,b}`, `shore_algae_skirt`. Boulders are noise-displaced icospheres with three flat fracture faces and a flattened, bedded underside. Parts range from 180 to 1280 triangles. |
| Materials | The GLBs carry only named slots (`shore_granite`, `shore_barnacle`, `shore_limestone`, `shore_shingle`, `shore_wrack`, `shore_algae`). `MapViewMaterials.shore_debris(family)` resolves each slot to one cached `StandardMaterial3D`, so a whole coast shares one material per family. Shingle reuses the CO-01 `shore_shingle` plate. |
| Scatter | `MapViewTerrainDetails.shore_debris_placements()` / `build_shore_debris()` builds one `MultiMesh` per kind for each scatter chunk. It is wired into `MapViewMeshBuilderScatter.build_scatter()`, so the debris shows at the gameplay camera, not only in first person. |
| Collision | Stones of 1.0 m or wider (`medium`, `large`, `barnacled`) carry a blocking footprint (`shore_debris_blocking_cells()`). Every footprint cell must already be impassable water, so the walkable region does not change. Smaller pieces carry no footprint. The view adds no physics bodies. |

## Placement bands

Distances are signed shore distances in cells (positive = seaward). Bands apply only on beach
shorelines (WS-08 `shore_type` >= 0.5). Quays and hard edges get nothing.

| Layer | Band | Density rule |
|---|---|---|
| Erratics (medium / large / barnacled) | 0.6 to 5.0, water cells | At most one per 4x4-cell block. The kind is chosen so the crown clears the water (20-85% emerged). The barnacled stone is chosen only where the waterline falls near the top of its crust (30-65% emerged). About 30% of stones that would not emerge are placed anyway, fully drowned, for the underwater view. |
| Submerged small stone + weed apron | 0.3 to 3.0, water cells | At most one per 2x2 block, 22% |
| Wrack line | -1.0 to 0.25 | At most one per 2x2 block, 70%, laid along the shore tangent |
| Shingle / stone cluster / small boulder | -6.0 to -1.2, beach cells | At most one per 2x2 block, 50% falling to 20% inland. Shingle dominates the storm ridge (d > -3.5). |

Reserved cells are never used:

- transition rects (+1 cell)
- the player spawn and interaction anchors (+1 cell)
- every prop position or footprint (+2 cells: boats, cribs, crates)
- building footprints

Land and wrack placements also need all eight neighbours to be sea or natural ground (never a
timber deck, landing, paving or dirt track). An erratic needs a clear one-cell ring of sea or
beach around its footprint.

## Decisions

1. **The scatter hook lives in `map_view_mesh_builder_scatter.gd`, outside the contract's allowed
   files.** The contract names `map_view_terrain_details.gd`. That file's existing layer is built
   only in first person, inside a small radius. Boulders standing in the shallows have to read at
   the gameplay camera, so the pass is implemented in `map_view_terrain_details.gd` and called
   from the always-built scatter chunk with a 7-line hook.
2. **"Collision above 1.0 m" means a blocking footprint on water that is already impassable.**
   Gameplay movement is the 2D logic grid, and the contract also requires the walkable region to
   stay at 4326 / 6333 cells. So stones of 1.0 m or wider are placed only where their whole
   footprint is sea, and `shore_debris_blocking_cells()` exposes those cells for swimming (WS-14b)
   and boats to consume. Nothing walkable is taken.
3. **Erratic kind follows water depth.** The WS-13b basin is already about 0.8 world units deep
   1.8 cells off the line. A contract-size 1.2 m stone set on the rendered bed was fully drowned
   and read as nothing from the gameplay camera. The barnacled variant was therefore made taller
   (1.6 m, crust on the lower 55%), and each stone is picked by how far its crown would emerge.
4. **`excluded_areas` are not reserved cells.** The harbours use them to make the shallow band
   impassable, which is exactly where erratics belong. Reserving them removed 70% of the map.
5. **Flat dressing fades its rim through vertex alpha.** Shingle and wrack use blended alpha:
   alpha hash rendered a hard cut-out edge on Compatibility. They are also tilted onto the
   sampled local slope and lifted 0.01-0.03 units, so the sand does not clip the rim. The weed
   apron uses alpha scissor, because the WS-13 underwater pass composites from depth and drops
   blended surfaces.
6. **The existing primitive `CoastalRocks` layer (`map_view_shoreline_3d.gd`) is left alone.** It
   has its own R-715 tests and is outside the allowed files. Its blue, faceted spheres are now the
   weakest element on the Kalamaja plates. Retiring it in favour of this family is a follow-up.
7. **Saaremaa's `alvar.boulders` terrain paint is untouched** (CO-09 decides).

## Verification

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_shore_debris_scatter,test_shore_distance_field
# 18 tests, 0 failures
godot --headless --path . --script tools/validate_map_blueprints.gd   # 29 registered, 0 errors (warnings pre-existing)
python3 tools/verify_map_audit.py         # passed (47 declarative maps)
python3 tools/verify_map_activation.py    # passed
python3 tools/validate_asset_sources.py && python3 tools/verify_asset_lint.py && python3 tools/verify_storage_hygiene.py   # passed
python3 tools/generate_active_docs_report.py --check                  # passed
```

`test_shore_debris_scatter.gd` covers:

- same seed gives identical placements, and a new seed rearranges them
- whole-map placements equal the union of four reversed chunks
- nothing lands on a transition, anchor, spawn, prop or pier cell
- only stones of 1.0 m or wider block, and every blocking cell is already impassable
- no physics bodies are added
- algae is only seaward, wrack is within one cell of the line, and dry stones are landward
- the per-chunk count stays within `SHORE_DEBRIS_MAX_PER_CHUNK`
- every family loads with the shared PBR material and stays within 1500 triangles
- the largest walkable region stays at 4326 (harbor east) and 6333 (harbor north) with the
  blocking cells removed

Coastal regressions `test_r715_water_surface_geometry`, `test_coastal_sea_3d` and
`test_harbour_shoreline_acceptance` stay green.

### Budget

Headless build of every chunk:

| Map | Chunks | Instances | Max per chunk | MultiMesh layers | Build time |
|---|---|---|---|---|---|
| `reval_harbor_east` | 15 | 135 | 27 | 59 | 73.9 ms (about 5 ms per chunk) |
| `reval_harbor_north` | 20 | 165 | 44 | 47 | 105.3 ms |

Each shore chunk adds at most 11 MultiMesh draws, plus a second surface for the barnacled
boulder and for cluster b. Parts are 180 to 1280 triangles. The P0-159 fauna and vegetation
layers are untouched. The Lower Town quick performance report has no shore, so it was not rerun.

## Evidence

Captured with `tools/capture_co02_shore_debris.gd` through `tools/godot_render.sh` on Kalamaja.
"before" plates were captured with the scatter hook reverted.

| Plate | Compatibility clear | Compatibility storm | Metal (mobile) clear |
|---|---|---|---|
| Cove (x 97-104), gameplay camera | [before](images/co02_cove_clear_compat_before.png) / [after](images/co02_cove_clear_compat_after.png) | [before](images/co02_cove_storm_compat_before.png) / [after](images/co02_cove_storm_compat_after.png) | [before](images/co02_cove_clear_mobile_before.png) / [after](images/co02_cove_clear_mobile_after.png) |
| Spit (x 50-70), gameplay camera | [before](images/co02_spit_clear_compat_before.png) / [after](images/co02_spit_clear_compat_after.png) | [before](images/co02_spit_storm_compat_before.png) / [after](images/co02_spit_storm_compat_after.png) | [before](images/co02_spit_clear_mobile_before.png) / [after](images/co02_spit_clear_mobile_after.png) |
| Eye level from the spit | [before](images/co02_close_clear_compat_before.png) / [after](images/co02_close_clear_compat_after.png) | [before](images/co02_close_storm_compat_before.png) / [after](images/co02_close_storm_compat_after.png) | [before](images/co02_close_clear_mobile_before.png) / [after](images/co02_close_clear_mobile_after.png) |

Underwater (Metal):
[before](images/co02_underwater_clear_mobile_before.png) /
[after](images/co02_underwater_clear_mobile_after.png).
The plate was taken with
`tools/capture_underwater.gd -- --shot=under_horizontal --map=reval_harbor_east --pos=51.0,-0.3,25.5 --look=54.0,-0.7,28.0`.
The Compatibility underwater pass on this map produced a corrupted frame, the same class of
defect as R-1087, so no Compatibility underwater plate is published.

## Open items

- **R-1093**: named human visual review of the plates. The contract cannot close on green tests.
- **R-1092**: retire the primitive `CoastalRocks` spheres in favour of this family.
- **R-1094**: the weed apron reads as flat fronds with angular clump edges; replace it with strand
  cards. This task also covers the corrupted Compatibility underwater frame on Kalamaja.
- WS-14b (R-910) swimming and boats must treat `shore_debris_blocking_cells()` as solid.
