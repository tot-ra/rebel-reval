# R-997 interior wall plaster density: smithy evidence

- Task: `R-1000` (follow-up of `R-997`)
- Status: **finding - the smithy's visible walls never used the R-997 path**
- Capture tool: `tools/capture_smithy_uv_density.gd`

## What R-997 changed

`MapViewMeshBuilderBuildingInteriorWalls.interior_wall_material` replaced the
BoxMesh-sized `uv1_scale` (length * 3x2 atlas factor, from
`library_box_uv_scale`) with the plate-metre `library_world_uv_density`, because
the triplanar mapping reads `uv1_scale` as repeats per world unit.

## Measured materials (Kalev smithy, 12 interior wall meshes)

| Wall (x * z world units) | uv1_scale before | uv1_scale after |
|--------------------------|------------------|-----------------|
| 12 x 1 (limewash_clay)   | 6.79             | 0.348           |
| 9 x 1 (render_ochre)     | 3.26             | 0.2175          |
| 8 x 1 (limewash_clay)    | 4.70             | 0.348           |
| 1 x 4 (render_*)         | 1.63             | 0.2175          |

Long walls drop by roughly 20x, so the R-997 fix is correct at the material
level. "Before" values are `library_box_uv_scale(stem, box.size)` applied in
memory by the capture tool; "after" is the shipped material.

## Why the plates look identical

`MapViewKalevSmithyInterior.adapt_building` hides the `Walls` box of every
interior-wall building (`visible = false`; it only feeds occlusion bounds). The
player sees the authored GLB shell, whose plaster uses
`MapViewKalevSmithyInterior._plate` with world triplanar mapping at 1.6-1.8 m
plates. So the smithy never showed the over-tiling, and its first-person view
cannot demonstrate the R-997 fix. Even multiplying the old scale by 30 leaves
the plates unchanged.

Plates (Metal Forward Mobile and GL Compatibility, yaw 90, along the long wall):

- `images/r997_interior_uv_before_yaw090.png`, `images/r997_interior_uv_after_yaw090.png`
- `images/r997_interior_uv_before_yaw090_compat.png`, `images/r997_interior_uv_after_yaw090_compat.png`

## Limits

The fix is only visible on interior-wall maps without an authored shell
(`InteriorMapFactory` rooms). A visual proof needs one of those maps.
