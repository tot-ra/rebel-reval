# St Olaf's church (Oleviste) 1343 remodel

Status: implemented (task **R-1120**, St Olaf half; the Great Guild exterior is still open)
Recorded: 2026-10-07
Map: `monastery_quarter`
Building: `st_olaf_silhouette` (renderer `st_olaf_1343`, `historical_phase=vaulted_hall_unfinished_tower_1343`)
Scope: the exterior view model only. Out of scope: the footprint, collision, transitions, the interior map `oleviste_church`, the Great Guild, and the Town Hall wear migration (R-1123).

## Problem

The R-281 renderer placed its west tower, buttresses and lancets inside the nave box and roof. The tower stood 8.5 m high under a 10.5 m ridge, and the windows sat inside the wall. In game the church therefore read as a plain tiled barn, with no tower, no openings and no age.

## Evidence

Source: [`churches-and-religious-houses.md`](../../history/dossiers/religion/churches-and-religious-houses.md) ("St Olaf"), audit row H14 in [`HISTORICAL_AUDIT.md`](../HISTORICAL_AUDIT.md), labels in [`CANON.md`](../CANON.md).

| Element | 1343 state | Confidence |
|---|---|---|
| Short church with a massive west tower (walls ~3.2 m thick) and a small east chancel | Built at the turn of the 13th/14th c. Visby St Mary's is the cited model | plausible composite |
| Vaults over the hall | Completed c. 1330 (dated boss) | attested |
| Upper tower | Dated 1364+, so in April 1343 it is unfinished | attested negative |
| Record spire, basilica, high choir | 15th c. and after the 1433 fire | attested negative, excluded |

## Model

`scripts/map/view3d/map_view_st_olaf_model.gd`, called from `MapViewMeshBuilderChurches.build_st_olaf_church`. This is the existing route, so no second renderer exists. Dimensions are in metres on the 22 x 14 m plot. The tower is at -X and the door faces south (+Z).

- **Hall nave** (11.5 x 12.4 m, eaves 8.4 m) under one steep tile roof (pitch 1.05). Two-stage buttresses with sloped weatherings mark the three vault bays. Each bay has one tall equilateral-pointed lancet with a chamfered surround, a dark splay, a leaded pane and a mullion. A drip course runs under the sills and a cornice along the eaves.
- **South portal** sits in a projecting frontispiece with a gablet and three stepped pointed orders. The outer order ends on the plot edge, where the `to_oleviste_church` door leaf is drawn. The portal axis (x = +1.0) matches the transition centre.
- **East nave gable** is masonry with coping. Five lime-washed blind niches step up to the ridge above the chancel roof.
- **Chancel**: lower (eaves 6.6 m) and narrower (7.8 m), with a stepped east triplet, a south lancet and corner buttresses. A **lean-to sacristy** stands on its north side.
- **West tower** (6.2 x 8.4 m) rises to 18 m, above the 14.9 m ridge, and stops there unfinished: the head is racked back in courses toward the corners, putlog holes are open, and there are belt courses, long-and-short quoins, slit lights and a pointed west portal. A putlog scaffold with board decks and standards covers the top lift, and a hoist jib lets a rope down to the yard. The bells hang in a **provisional timber frame under a shingle pyramid cap** until the upper tower is raised.
- **Works yard**: a masons' lodge lean-to and a stack of dressed blocks stand on the tower's free corners of the plot.
- **Wear** (LM-01 kit, [`map_view_landmark_weathering.gd`](../../scripts/map/view3d/map_view_landmark_weathering.gd)): a rising-damp band over a darker plinth, eave runoff on every face, sill streaks under every lancet, and age-toned library stems (`rubble_pale`, `ashlar_grey`, `tile_moss`, `shingle_silver`, `limewash_chalk`).
- **Glass** panes are root children named `Window<n>`, so the evening window-light schedule lights the church like other buildings.

Shared helpers: [`map_view_gothic_meshes.gd`](../../scripts/map/view3d/map_view_gothic_meshes.gd) builds pointed panels and arch bands, convex prisms and pyramids, and merged box batches. Quoins, putlog holes, the scaffold and the bell frame are one mesh each.

### Phase choices (plausible composite)

These are game decisions, not attested details. They are labelled in `CANON.md`:

- the provisional timber belfry, the scaffold, the hoist and the masons' lodge (an unfinished tower in active work);
- the projecting portal frontispiece (Baltic Gothic practice; no attested 1343 porch);
- the lime-washed blind niches on the east gable (Gotland and Reval practice);
- a single tall lancet per bay and the stepped east triplet.

### Excluded

The 1364+ upper tower, the 15th-century spire, the post-1433 basilica and high choir. These are recorded in node metadata `excluded_features`.

## Constraints kept

- The stable ID `st_olaf_silhouette`, the footprint, `olaf.close`, both `olaf_precinct_*` ranges and the `to_oleviste_church` / `to_reval_monastery` door pair are unchanged. No `.rrmap` edits, so the world layout and the Pikk-spine bypass lane are untouched.
- Every mesh stays inside the 22 x 14 m footprint. A test asserts this.

## Verify

- `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_st_olaf_church,test_oleviste_church,test_monastery_quarter_prototype_map`
- `tools/godot_render.sh --script tools/capture_st_olaf_1343.gd` writes studio plates from four sides plus a street view, and the in-map gameplay view by day and night, to `docs/reports/images/st_olaf_1343/`.

| Before (R-281) | After |
|---|---|
| Plain gabled box. The tower and openings are buried inside the mass | ![south-west](images/st_olaf_1343/studio_south_west.png) |

![north-east](images/st_olaf_1343/studio_north_east.png)
![in map, day](images/st_olaf_1343/map_day.png)

## Limits

- The plan is authored for the 22 x 14 m plot. A different footprint would need the plan constants revisited (the test pins the door axis and the footprint bounds).
- The Town Hall still carries its own copy of the wear recipe. R-1123 moves it onto the kit.
- The silhouette compresses scale: the real nave is longer and the tower more massive. The plot and the bypass lane fix the size.
- A named human canon and art review is still required, as for R-281 ([`r673_st_olaf_acceptance.md`](r673_st_olaf_acceptance.md)).
