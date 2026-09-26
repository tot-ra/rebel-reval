# AR-10: civic, guild and mercantile building set

Board row: **R-968**. Priority: high. Depends on: AR-04.

## Player-facing goal

The market and civic quarter reads as the commercial heart of a Hanse town: a town hall with a real
arcade the player can walk under, the Holy Spirit chapel and its hospital range as an institution and not
a house, guild frontages that are wider and better dressed than their neighbours without being 15th-century
palaces, and Pikk warehouses with gable doors, loading hoists and open cellar hatches where goods actually
move.

## Why this is needed

`market_civic_quarter` places **52 house records** - the second-densest map in the project - and the civic
landmarks it needs are all primitives: `town_hall_1343` (1 use), `holy_spirit_chapel_1343` (1 use),
`guild_frontage`, `storehouse` (2 uses), `stepped_gable_merchant` (3 uses). The geometry comes from
`map_view_mesh_builder_building_houses.gd`, whose town hall support is four constants -
`TOWN_HALL_ARCADE_THICKNESS`, `TOWN_HALL_CORRIDOR_DEPTH`, `TOWN_HALL_DOOR_RECESS` - and no asset.
`map_view_mesh_builder_building_registry.gd` classifies `town_hall_mass`, `guild_frontage`,
`holy_spirit_hospital` and `church_silhouette` as "exceptional" categories, but exceptional here only
means a different primitive path.

Four service-building GLBs already exist and prove the pattern works -
`assets/props/architecture/buildings/{brewhouse,log_barn,public_bath,stone_storehouse}` from
`tools/generate_lower_town_service_buildings.py`. There are simply only four of them, and no civic or
guild equivalent at all.

## Deliverable

A set under `assets/buildings/civic/`, kit-bashed on AR-04, built to the AR-01 civic card:

1. **Town hall, 1343** - `town_hall_1343_body`, `town_hall_arcade_bay` (repeatable, so the arcade is
   built rather than stretched), `town_hall_gable`, `town_hall_stair`, `town_hall_pillory_ground`. The
   arcade must be a walkable-looking depth consistent with the existing
   `TOWN_HALL_ARCADE_THICKNESS` / `TOWN_HALL_CORRIDOR_DEPTH` gameplay values, which stay authoritative.
2. **Holy Spirit** - `holy_spirit_chapel_1343`, `holy_spirit_hospital_range`, `holy_spirit_court_wall`,
   `holy_spirit_alms_porch`. An institution with a hall, a chapel and a court, not a taller house.
3. **Guild and mercantile** - `guild_frontage_wide` (two variants), `guild_hall_body`,
   `stepped_gable_merchant` as real authored geometry with its crow-stepped coping, `weighhouse`,
   `market_hall_open_bay`.
4. **Warehousing that works** - `warehouse_gabled` with gable doors at two storey levels, a
   `warehouse_hoist_beam` with pulley and rope, `warehouse_cellar_hatch` and `warehouse_loading_apron`.
   The map already authors `house.warehouse`, `house.warehouse.gabled` and `house.store`; they should
   look like the trade machinery they were.
5. **Existing service GLBs folded in.** The four `assets/props/architecture/buildings/*` models are
   brought onto the AR-04 snap module and AR-03 surfaces so they sit in the same visual language, and get
   two frontage variants each. They are not rebuilt from scratch.
6. Loader wiring through the AR-04 catalogue; the four town-hall constants and every ID in
   `market_civic_quarter.rrmap`, `town_hall.rrmap`, `holy_spirit_church.rrmap` and
   `st_olafs_guild_hall.rrmap` preserved.
7. `assets/SOURCES.csv` rows citing the AR-01 card and the audit's H03-H05 rows.

## Allowed files

- `assets/buildings/civic/**` (new), `assets/buildings/kit/**` (civic parts only),
  `assets/props/architecture/buildings/**`
- `assets/SOURCES.csv`
- `tools/build_civic_buildings.py` (new), `tools/generate_lower_town_service_buildings.py`,
  `tools/build_architecture_kit.py`
- `scripts/map/view3d/map_view_mesh_builder_building_houses.gd` (+ `.uid`) - civic paths only
- `scripts/map/view3d/map_view_service_building_models.gd` (+ `.uid`)
- `scripts/map/view3d/map_view_mesh_builder_building_registry.gd` (+ `.uid`)
- `scripts/map/view3d/architecture_kit_catalogue.gd` (+ `.uid`)
- `tests/godot/test_civic_buildings.gd` (+ `.uid`, new),
  `tests/godot/test_service_building_models.gd` (if present)
- `tools/capture_ar10_civic_quarter.gd` (+ `.uid`, new)
- `docs/ASSET_INVENTORY.md`, `docs/ART_BIBLE.md`, `docs/CANON.md` (confidence labels only),
  `docs/reports/ar10_civic_quarter.md`, `docs/reports/images/ar10_*.png`, `TODO.md`

## Constraints and non-goals

- Asset freeze P0-040: exactly the files above.
- **No rrmap edits.** No ID, footprint, style or anchor moves in any of the four maps.
- **The guild exclusions are hard.** No Great Guild Hall (1407-10) and no Brotherhood or Blackheads
  frontage: `docs/HISTORICAL_AUDIT.md` cross-map exclusion 2, and the `monastery_quarter.rrmap` header
  under **P4-023e**, both forbid them. St Olaf's craft-guild use is first recorded in 1363 and is
  therefore **U** for 1343, so `st_olafs_guild_hall` gets a generic wide merchant or craft frontage, not a
  guild monument. Add a named assertion.
- The town hall's arcade geometry must match the existing gameplay constants; the mesh adapts to the
  constants, not the reverse.
- Collision and navigation unchanged; walkability bit-identical. The arcade must not become walkable if it
  was not, and must not stop being walkable if it was.
- No interiors. `town_hall.rrmap`, `holy_spirit_church.rrmap` and `st_olafs_guild_hall.rrmap` are separate
  prototype maps; this task only changes how their exteriors and their masses look.
- No market, trade, weighing or storage gameplay. These are buildings.

## Verification

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_civic_buildings,test_service_building_models,test_architecture_kit,test_town_hall
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/validate_map_blueprints.gd
python3 tools/validate_asset_sources.py && python3 tools/verify_asset_lint.py && python3 tools/verify_storage_hygiene.py
python3 tools/verify_map_audit.py && python3 tools/verify_map_activation.py && python3 tools/verify_map_composition.py
python3 tools/verify_building_variety.py
python3 tools/generate_active_docs_report.py --check
git diff --check
```

- `test_civic_buildings.gd` asserts: every model loads; every civic and guild `primitive=` and style in the
  four maps resolves to an authored model; the arcade is built from repeated bays and its depth matches
  `TOWN_HALL_ARCADE_THICKNESS` and `TOWN_HALL_CORRIDOR_DEPTH` within tolerance; the warehouse gable doors
  and hoist beam sit at plausible storey levels from AR-01; a named assertion that no Great Guild Hall,
  Brotherhood or Blackheads frontage model exists and that `st_olafs_guild_hall` resolves to a generic
  wide frontage; the four existing service GLBs snap to the AR-04 module and use AR-03 surfaces; models
  within the ADR 0022 budget with LODs.
- **Gameplay invariance**: walkable cells, largest walkable region and anchor accounting bit-identical per
  map, including the arcade cells specifically; activation status unchanged.
- `git diff --stat content/maps/` is empty.
- `tools/capture_ar10_civic_quarter.gd` through `tools/godot_render.sh`: matched before/after plates of the
  town hall front and a shot from **under** the arcade, the Holy Spirit court, a guild frontage beside two
  ordinary neighbours, a Pikk warehouse with its hoist, the weighhouse, and a market-square vista; clear
  noon, overcast and midnight; Compatibility and Metal; both quality tiers.
- Performance: `market_civic_quarter` frame cost, draw calls, materials and triangles, inside budget.
- **Named human visual review** answering: does the square read as the commercial and civic centre, and is
  the guild frontage distinguishable from its neighbours **without** looking like a 15th-century monument.
  Green tests do not close this (P0-209b).

## Doc updates

`docs/ASSET_INVENTORY.md`, `docs/ART_BIBLE.md`, `docs/CANON.md`,
`docs/reports/ar10_civic_quarter.md`, `TODO.md`.

## TODO.md line

```
- [ ] R-968 | deps: R-962 | deliverable: assets/buildings/civic set covering the 1343 town hall with a repeatable arcade bay matching the existing TOWN_HALL_ARCADE_THICKNESS/CORRIDOR_DEPTH constants, gable, stair and pillory ground; Holy Spirit chapel, hospital range, court wall and alms porch; two wide guild frontages, guild hall body, authored crow-stepped stepped_gable_merchant, weighhouse and open market bay; gabled warehouse with two-level gable doors, hoist beam with pulley, cellar hatch and loading apron; and the four existing service GLBs folded onto the AR-04 module and AR-03 surfaces with two frontage variants each | allowed files: per docs/tasks/architecture/AR-10_civic_guild_set.md | verify: `--filter=test_civic_buildings,test_service_building_models,test_architecture_kit,test_town_hall`; full Godot suite; blueprint validate; asset sources/lint/storage; map audit, activation, composition; building variety; active docs; git diff --check; every civic and guild primitive/style across market_civic_quarter, town_hall, holy_spirit_church and st_olafs_guild_hall resolves with ids intact; arcade built from repeated bays at the authored depth; named assertion that no Great Guild Hall, Brotherhood or Blackheads frontage exists and st_olafs_guild_hall stays a generic wide frontage; existing service GLBs snapped and resurfaced; models within the ADR 0022 budget with LODs; bit-identical walkability including the arcade cells; empty `git diff --stat content/maps/`; matched before/after town hall front, under-arcade, Holy Spirit court, guild-beside-neighbours, warehouse hoist, weighhouse and market vista plates at noon/overcast/midnight on Compatibility and Metal at both tiers; frame/draw-call/material/triangle budget; named human review that the square reads as the civic centre and the guild frontage is distinguishable without becoming a 15th-century monument
```
