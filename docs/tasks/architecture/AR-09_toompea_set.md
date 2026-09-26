# AR-09: Toompea plateau building set

Board row: **R-967**. Priority: high. Depends on: AR-04.

## Player-facing goal

Toompea reads as the seat of Danish authority and the church: a cathedral visibly **under construction**
with scaffolding, a lifting wheel, a stone yard and an unfinished bay, the Small Castle as a walled
compound with a keep and ranges rather than a block, canonical and episcopal curiae that look like the
houses of men with money and no shop, and the Long Leg and Short Leg descents gated with real gate works.
Climbing from the Lower Town feels like entering a different town, which is what it was.

## Why this is needed

`toompea_quarter` places **15 house records**, `toompea_small_castle` another 6, and
`archbishops_garden` 2. The landmark geometry is primitives: `cathedral_silhouette` and `stone_keep` are
handled by `map_view_mesh_builder_churches.gd` and `map_view_mesh_builder_building_fortification.gd`,
neither of which references a single asset. `st_marys_construction_1343` is one `primitive=` value.

The authored style vocabulary is the usual tint set - `house.cathedral`, `house.castle`, `house.canonical`,
`house.chancery`, `house.noble`, `house.knights`, `house.barracks` - separated by `wall_height` and a
material keyword. The `docs/HISTORICAL_AUDIT.md` `toompea_quarter` card asks for "sparse compounds and
narrow routes ... do not use dense Lower Town strip rows", tile at 35-55% concentrated on cathedral,
castle and elite stone fabric, and explicitly flags the broad western "Knights District" identity and
"western canonical halls" as **D** (disputed). The geometry currently cannot distinguish an elite curia
from a Lower Town plank house at all.

## Deliverable

A set under `assets/buildings/toompea/`, kit-bashed on AR-04, built to the AR-01 Toompea elite card:

1. **St Mary's cathedral, 1343 construction phase** - a group, not one mesh:
   `cathedral_nave_1343`, `cathedral_west_front_1343`, `cathedral_unfinished_bay`,
   `cathedral_scaffold`, `cathedral_lifting_wheel`, `cathedral_stone_yard`, `cathedral_precinct_wall`.
   The construction state is the point: a finished cathedral here is historically wrong and visually
   generic at the same time.
2. **Small Castle** - `castle_keep`, `castle_range_hall`, `castle_range_service`, `castle_curtain`,
   `castle_gate`, `castle_courtyard_stair`, sized to the `toompea_small_castle` footprints.
3. **Elite domestic fabric** - `curia_canonical` (two frontage variants), `curia_episcopal`,
   `chancery_range`, `noble_compound_wall` and `compound_gate`. These are what make the plateau read as
   elite: stone, shopless ground floors, enclosed courts, tile roofs, wider window spacing than the
   Lower Town.
4. **Descents** - `long_leg_gate`, `short_leg_gate` and `descent_retaining_wall`, so the two routes down
   are gated approaches rather than open ramps.
5. **Disputed content stays out.** No repeated limestone knights compound, and no western canonical hall
   row. The `docs/HISTORICAL_AUDIT.md` `toompea_quarter` and `south_quarter` cards both label those **D**.
   `house.knights` and `house.barracks` records keep their IDs and resolve to generic elite or service
   masses from AR-05, not to a bespoke knights architecture.
6. Loader wiring through the AR-04 catalogue; every `primitive=` and ID in `toompea_quarter.rrmap`,
   `toompea_small_castle.rrmap` and `archbishops_garden.rrmap` preserved.
7. `assets/SOURCES.csv` rows citing the AR-01 card and the audit's H01, H12-H13 rows.

## Allowed files

- `assets/buildings/toompea/**` (new), `assets/buildings/kit/**` (Toompea-specific parts only)
- `assets/SOURCES.csv`
- `tools/build_toompea_buildings.py` (new), `tools/build_architecture_kit.py`
- `scripts/map/view3d/map_view_mesh_builder_churches.gd` (+ `.uid`) - cathedral path only
- `scripts/map/view3d/map_view_mesh_builder_building_fortification.gd` (+ `.uid`) - castle/keep path only
- `scripts/map/view3d/map_view_mesh_builder_building_registry.gd` (+ `.uid`)
- `scripts/map/view3d/architecture_kit_catalogue.gd` (+ `.uid`)
- `tests/godot/test_toompea_buildings.gd` (+ `.uid`, new)
- `tools/capture_ar09_toompea.gd` (+ `.uid`, new)
- `docs/ASSET_INVENTORY.md`, `docs/ART_BIBLE.md`, `docs/CANON.md` (confidence labels only),
  `docs/reports/ar09_toompea.md`, `docs/reports/images/ar09_*.png`, `TODO.md`

## Constraints and non-goals

- Asset freeze P0-040: exactly the files above.
- **No rrmap edits** for `toompea_quarter`, `toompea_small_castle` or `archbishops_garden`. All three are
  `active=false`; this task does not activate them.
- The cathedral must be in construction phase. A completed St Mary's fails the task.
- Disputed **D** content is excluded: no knights-district architecture, no western canonical hall row.
  Add a named assertion so it cannot be reintroduced silently.
- The audit's Bishop's Garden chronology review (`docs/CANON.md`, "Bishop's Garden chronology (1343 map
  boundary review)") governs anything placed in `archbishops_garden`. Do not extend the garden's built
  fabric beyond what that review allows.
- Collision and navigation unchanged; walkability bit-identical. No interiors, no gameplay.
- Tile-roof share on the plateau must land inside the audit's 35-55% band after this set lands; report the
  realised figure.

## Verification

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_toompea_buildings,test_architecture_kit,test_churches,test_fortification
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/validate_map_blueprints.gd
python3 tools/validate_asset_sources.py && python3 tools/verify_asset_lint.py && python3 tools/verify_storage_hygiene.py
python3 tools/verify_map_audit.py && python3 tools/verify_map_activation.py && python3 tools/verify_map_composition.py
python3 tools/verify_building_variety.py
python3 tools/generate_active_docs_report.py --check
git diff --check
```

- `test_toompea_buildings.gd` asserts: every model loads; all 23 house records across the three maps
  resolve; every ID in the three rrmap sources still resolves; the cathedral group includes an unfinished
  bay, scaffold and lifting wheel and has **no** completed east end; the Small Castle is a compound of
  separate ranges rather than one mass; `house.knights` and `house.barracks` resolve to generic elite or
  service masses, with a named assertion that no bespoke knights-compound model exists; realised tile
  share on `toompea_quarter` is inside 35-55%; models within the ADR 0022 budget with LODs.
- **Gameplay invariance**: per-map walkable cells, largest walkable region and anchor accounting
  bit-identical; all three maps still report inactive.
- `git diff --stat content/maps/` is empty.
- `tools/capture_ar09_toompea.gd` through `tools/godot_render.sh`: matched before/after plates of the
  cathedral west front and its construction yard, the Small Castle gate and courtyard, a canonical curia,
  the Long Leg gate, and a plateau vista; plus one comparison plate framing a Toompea curia beside a Lower
  Town plank house to prove the two classes now read differently; clear noon, overcast and midnight;
  Compatibility and Metal; both quality tiers.
- Performance: `toompea_quarter` and `toompea_small_castle` frame cost, draw calls, materials and
  triangles, inside budget.
- **Named human visual review** answering: does the plateau read as a separate, elite, authority town, and
  is the cathedral unmistakably a building site. Green tests do not close this (P0-209b).
- **Canon review** of confidence labels, including a check that nothing disputed was reintroduced.

## Doc updates

`docs/ASSET_INVENTORY.md`, `docs/ART_BIBLE.md`, `docs/CANON.md`, `docs/reports/ar09_toompea.md`,
`TODO.md`.

## TODO.md line

```
- [ ] R-967 | deps: R-962 | deliverable: assets/buildings/toompea set covering St Mary's 1343 construction phase as a group (nave, west front, unfinished bay, scaffold, lifting wheel, stone yard, precinct wall), the Small Castle as separate keep/hall/service ranges with curtain, gate and courtyard stair, elite domestic fabric (two canonical curia frontages, episcopal curia, chancery range, compound wall and gate) and the Long Leg / Short Leg gate works with retaining walls, wired through the AR-04 catalogue | allowed files: per docs/tasks/architecture/AR-09_toompea_set.md | verify: `--filter=test_toompea_buildings,test_architecture_kit,test_churches,test_fortification`; full Godot suite; blueprint validate; asset sources/lint/storage; map audit, activation, composition; building variety; active docs; git diff --check; all 23 house records across toompea_quarter, toompea_small_castle and archbishops_garden resolve with every id intact; cathedral has an unfinished bay, scaffold and lifting wheel and no completed east end; castle is a compound of separate ranges; named assertion that no bespoke knights-compound or western canonical hall model exists (HISTORICAL_AUDIT D); realised tile share on toompea_quarter inside 35-55%; models within the ADR 0022 budget with LODs; bit-identical walkability and anchor accounting with all three maps still inactive; empty `git diff --stat content/maps/`; matched before/after cathedral, castle, curia, Long Leg and plateau-vista plates plus a Toompea-curia-beside-Lower-Town-plank-house comparison at noon/overcast/midnight on Compatibility and Metal at both tiers; frame/draw-call/material/triangle budget; named human review that the plateau reads as a separate elite authority town and the cathedral as a building site; canon review that nothing disputed was reintroduced
```
