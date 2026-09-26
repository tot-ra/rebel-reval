# WB-10: A machine-checkable density and variety contract for exterior maps

Board row: **R-982**. Priority: high. Depends on: none.

## Player-facing goal

None directly. This row turns "the districts feel like generic boxes" from an opinion into a number
that fails a build, so R-985 and R-986 have a target and cannot drift back.

## Why this is needed

The measured baseline, counted from `content/maps/*.rrmap`:

| Map | Cells | Props | Props / 1000 cells | Decals | Styles |
|---|---|---|---|---|---|
| `kalev_smithy` (interior, shipped) | 364 | 41 | **112.6** | 7 | 3 |
| `lower_town_slice` (active district) | 19456 | **39** | **2.0** | 11 | 63 |
| `south_quarter` | 32256 | 15 | 0.5 | 0 | 7 |
| `toompea_quarter` | 27648 | **9** | **0.3** | 0 | 14 |

Toompea carries nine props over about 21 000 m². The shipped forge interior is fifty-six times
denser than the one active outdoor district. Twenty-six of twenty-nine maps have zero decals.

There is already a fail-closed acceptance gate for exterior maps -
`docs/WORLD_BUILDING_VISUAL_GATE.md` with `tools/verify_world_building_visual_gate.py` - but its
rubric rows are human judgements ("repetition", "historical coherence") and its automated side does
not measure density, variety or landscape bedding at all. So nothing stops a map shipping empty.

## Deliverable

1. **Authoring thresholds** added to `docs/data/map_composition_thresholds.json` per map class -
   dense urban, sparse urban, foreland, rural, interior - covering at minimum:
   - props per 1000 walkable cells, with a floor derived from the interior benchmark rather than
     from the current outdoor maps, which are the thing being fixed;
   - decals per 1000 walkable cells;
   - distinct prop kinds, so density cannot be met by cloning one barrel;
   - the largest share any single prop kind or style may take;
   - wealth-tier and age-tier spread once R-981 lands, ignored before that;
   - relief span, reusing the R-951 `elevation_range_min` mechanism;
   - vegetation and ground-cover share on unbuilt land;
   - a maximum run of identical adjacent building **footprints**, which is the authoring-side
     "row of boxes" failure. Building *appearance* repetition is **AR-13's** metric, not this
     row's - see the boundary note below.
2. **`MapCompositionAudit` measures them** and reports per map, with each new check as a stable
   diagnostic code.
3. **`tools/verify_map_composition.py` enforces them** for maps at `scope=production`, and reports
   without failing for `scope=prototype`, so the inactive districts show their gap without blocking
   CI today.
4. **The gate is wired in.** `tools/verify_world_building_visual_gate.py` consumes the composition
   result as an automated row, so a map cannot be marked promotable while it fails density.
5. **A published baseline table** for all 29 maps, so R-986 and every later map pass can be scored
   against a fixed starting point.

## Allowed files

`docs/data/map_composition_thresholds.json`, `scripts/map/map_composition_audit.gd` and its `.uid`,
`tools/audit_map_composition.gd` and its `.uid`, `tools/verify_map_composition.py`,
`tools/verify_world_building_visual_gate.py`, `docs/data/world_building_visual_benchmark.json`,
`tests/python/test_verify_map_composition.py`,
`tests/godot/test_map_composition_density.gd` and its `.uid`,
`docs/WORLD_BUILDING_VISUAL_GATE.md`, `docs/MAP_AUTHORING.md`,
`docs/reports/map_density_baseline_2026-09-26.md`,
`docs/tasks/world/WB-10_authoring_density_contract.md`, `TODO.md`.

## Boundary against AR-13 (architecture pack)

The architecture pack's **AR-13** (`docs/tasks/architecture/AR-13_repetition_audit_gate.md`, board
row R-971) owns building **appearance** repetition: per-map distinct-silhouette count,
nearest-neighbour identical-appearance distance, part-reuse histogram, and the
`landmark_architecture` and repetition rows of the visual gate.

This row owns **dressing and ground**: props, decals, distinct prop kinds, vegetation and
ground-cover share, relief span, and the identical-adjacent-*footprint* run. A building can pass
AR-13 with a beautiful varied silhouette and still stand in an empty street; it is this row that
catches that.

Both rows write to `tools/verify_world_building_visual_gate.py` and
`docs/data/world_building_visual_benchmark.json`. Whichever lands second must extend the other's
rows rather than replace them, and must not duplicate a metric the first already defines. If both
are in flight at once, coordinate before touching the shared manifest.

## Constraints and non-goals

Do not change any map in this row. Do not add a building-appearance or silhouette metric - that is
AR-13. Do not promote or activate any map. Do not make the new
thresholds fail CI for maps that are already `scope=production` until R-986 has raised them -
land the thresholds, publish the gap, and let R-986 close it. State that grace explicitly in the
threshold file rather than setting the floors low enough to pass.

## Verification

- `python3 tools/verify_map_composition.py` over all 29 maps, producing the baseline table.
- `python3 -m unittest tests.python.test_verify_map_composition -v`
- `godot --headless --path . --script tools/run_godot_tests.gd` with
  `test_map_composition_density.gd` asserting each new metric on a fixture with a known answer,
  including the identical-footprint-run detector and the single-kind-share cap.
- `python3 tools/verify_world_building_visual_gate.py` still returns `BLOCKED` for the right
  reasons, now including density, and its JSON names the failing metric per map.
- `python3 tools/verify_map_audit.py`, `generate_active_docs_report.py --check`
- A second reviewer confirms each floor is justified against the interior benchmark or a cited
  reference, and is not reverse-engineered from the current outdoor maps.

## Doc updates

`docs/WORLD_BUILDING_VISUAL_GATE.md` documents the new automated rows.
`docs/MAP_AUTHORING.md` states the density contract an author must meet before requesting promotion.
