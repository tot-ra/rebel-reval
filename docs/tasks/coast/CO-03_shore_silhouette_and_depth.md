# CO-03: Wider sea, wider shore, irregular waterline, real shoaling gradient

Board row: **R-950**. Priority: high. Depends on: CO-04. **Carries a scope-change ADR.**

## Player-facing goal

Standing on the Kalamaja shore, there is real sea in front of the player and real working ground
behind: the eye travels from dry drift sand, over a wet foreshore, through a knee-deep shallow, into a
turquoise shoal and then into open blue water, and it never crosses a straight line. The waterline
wanders in and out of coves and around spits over the whole 144-cell width, and the sea keeps getting
deeper away from the shore instead of stepping from shallow to deep at one row.

## Why this is needed

`content/maps/reval_harbor_east.rrmap` authors the sea as two ruler-straight full-width rects:

```
terrain water.deep    deep_water    0  0 144 24 order=1
terrain water.shallow shallow_water 0 24 144 10 order=2
terrain shore.sand    coast_sand    0 34 144 10 order=3
```

`shore.headlands` and `shore.coves` add small rect notches on top, but the underlying band edge
survives, which is exactly the "too straight shallow water section" the maintainer reported.
`reval_harbor_north` has the same structure (`0 46 160 8`).

The band budget leaves no room to fix it. At 144x80 Kalamaja spends 24 rows (21 m) on deep water,
10 rows (**8.7 m**) on shallow, 10 rows on beach, then mud, yards, grass and a forest boundary in the
remaining 46 rows. WS-13b derives rendered depth from distance to the water edge
(`basin_extra_depth = min(target, natural_edge * 0.45, hard_edge * 2.4)` with `SEA_BASIN_DEPTH`
shallow 1.0 / deep 3.6), so an 8-10 row shallow band can only ever produce a short, abrupt ramp.
Widening the bands inside 80 rows would have to come out of the village, so the footprint has to grow.

## Deliverable

1. **ADR** (next free number in `docs/adr/`, Status / Context / Decision / Alternatives /
   Consequences) covering: growing the cell footprint of `reval_harbor_east` and
   `reval_harbor_north`, the coordinate shift that follows, the parity fixtures that must be
   regenerated, and the named equivalent-cost scope removed in exchange. Merged or human-approved
   before any map edit.
2. `reval_harbor_east` re-authored at **192x128** (167x111 m), keeping map ID
   `reval_harbor_east` / `loc.reval_harbor.kalamaja`, `seed=1386`, `cell_size=32`, and **every**
   terrain, transition, spawn, anchor, prop and structure ID. Band budget:
   - open `deep_water` >= 40 rows
   - a new intermediate shoal expressed as `shallow_water` over a graded bed >= 16 rows
   - inshore `shallow_water` >= 14 rows
   - wet foreshore `coast_sand` >= 10 rows, dry `sand` drift >= 6 rows
   - mud, yards, village and boundary keep at least their current row counts
3. The waterline becomes **irregular by construction**, not by patching rects. Author the sea/shore
   boundary as a chain of `terrain_rects` runs (or blueprint primitives) whose edge offset varies by
   at least +/- 5 rows across the width, with at least 6 coves and 5 spits, none of them the same
   width. No full-width single rect may define the sea edge.
4. A graded bed: shallow-water cells adjacent to land stay near `SEA_BASIN_DEPTH` shallow, the new
   shoal band interpolates, and open `deep_water` reaches full depth. If WS-13b's edge-distance
   formula cannot express that with the wider bands, extend it (allowed file) rather than faking it
   with terrain paint.
5. `reval_harbor_north` gets the same treatment at **208x144**, reusing whatever the Kalamaja pass
   proves out.
6. Regenerated parity/snapshot fixtures with the before/after diff explained row by row in the report.

## Allowed files

- `content/maps/reval_harbor_east.rrmap`, `content/maps/reval_harbor_north.rrmap` (+ `.uid`)
- `scripts/map/definitions/outdoor/reval_harbor_east_definition.gd`,
  `scripts/map/definitions/outdoor/reval_harbor_north_definition.gd` (only if size constants live there)
- `scripts/map/view3d/map_view_mesh_builder_terrain.gd` (seabed grading only)
- `scripts/map/map_blueprint_registry.gd` (required anchors only, no ID renames)
- `docs/adr/00NN-coastal-map-footprint.md` (new), `docs/MAP_AUTHORING.md`,
  `docs/MAP_CONVERSION_PLAN.md`, `content/map_audit_manifest.json`
- `tests/godot/test_reval_harbor_map.gd`, `tests/godot/test_harbour_shoreline_acceptance.gd`,
  `tests/godot/test_ws13b_sea_basin_depth.gd`, `tests/godot/test_coastal_band_budget.gd` (new)
- `tools/capture_co03_shoreline.gd` (new)
- `docs/reports/co03_shore_silhouette.md`, `docs/reports/images/co03_*.png`, `TODO.md`

## Constraints and non-goals

- **No ID may be renamed or dropped.** Cell coordinates may move; IDs may not. The acceptance test
  must enumerate every pre-change ID and assert it still exists.
- Do not regenerate parity fixtures just to get green. Each fixture change is justified in the report.
- Do not change the water shader, FFT bake, foam, swash or sky. This is geometry and bed grading only.
- Do not activate either map. Both stay `scope=prototype active=false` until their own activation task.
- Do not touch Saaremaa (CO-09) or the boats (CO-06).
- Transitions to `reval_harbor_north` / `reval_east` / `world_saaremaa` must still land on walkable
  cells after the coordinate shift.

## Verification

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/validate_map_blueprints.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd
python3 tools/verify_map_audit.py
python3 tools/verify_map_activation.py
python3 tools/verify_map_conversion_plan.py
python3 tools/verify_map_composition.py
python3 tools/generate_active_docs_report.py --check
git diff --check
```

- `test_coastal_band_budget.gd` asserts, on both harbour maps: every band row minimum above; the sea
  edge offset varies by >= 5 rows across the width; >= 6 coves and >= 5 spits with distinct widths;
  **no** full-width rect defines the sea edge; rendered bed depth is monotonically non-decreasing
  seaward along at least 12 sample transects.
- `test_reval_harbor_map.gd` extended with a full stable-ID census: every terrain, transition, spawn
  and anchor ID present before the change is present after it.
- Route proof: every transition rect and anchor sits on a walkable cell, and the largest walkable
  region is at least as large in metres as the 2026-09-26 baseline (4326 cells on harbor east,
  6333 on harbor north).
- `tools/capture_co03_shoreline.gd` through `tools/godot_render.sh`: top-down band plate plus
  gameplay-camera plates at three points along the shore, clear noon and storm, before and after,
  on Compatibility and Metal.

## Doc updates

New ADR, `docs/MAP_AUTHORING.md` coastal band section, `docs/MAP_CONVERSION_PLAN.md`,
`content/map_audit_manifest.json`, `docs/reports/co03_shore_silhouette.md`, `TODO.md`.

## TODO.md line

```
- [ ] R-950 | deps: R-951 | deliverable: ADR-gated re-authoring of reval_harbor_east to 192x128 and reval_harbor_north to 208x144 with wider sea and shore bands, a constructively irregular waterline (>= 6 coves, >= 5 spits, +/- 5 row variation, no full-width sea-edge rect) and a monotonic seaward bed gradient | allowed files: per docs/tasks/coast/CO-03_shore_silhouette_and_depth.md | verify: blueprint validate, full Godot suite, map audit/activation/conversion/composition, active docs; test_coastal_band_budget band minima, cove/spit counts and 12 monotonic bed transects; full stable-ID census green; transitions and anchors still walkable; top-down and three gameplay plates clear/storm before/after on Compatibility and Metal
```
