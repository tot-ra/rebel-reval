# AR-05: deterministic assembler for the 319 untiered ordinary houses

Board row: **R-963**. Priority: high. Depends on: AR-03, AR-04.

## Player-facing goal

Walking `north_quarter`, the player sees 96 buildings, not 96 instances of one building. Each has its
own frontage rhythm, storey count, gable form, roof cover, opening layout, attachments and wear. Two
neighbours on the same lane read as two properties built in different decades by different owners.
Nothing pops or re-rolls when the player leaves and returns, and nothing looks different from how it
looked in the last save.

## Why this is needed

**319 of 362** `building ... house` records have no `house_tier=`, so they are drawn by
`map_view_mesh_builder_building_houses.gd` as an extruded footprint with a gable, coloured by two hex
values from the style. Per map: `north_quarter` 96, `market_civic_quarter` 52 (of which only some are
tiered), `monastery_quarter` 29, `south_quarter` 28, `toompea_quarter` 15, `world_padise` 14, plus the
world and harbour maps.

The style vocabulary cannot help: in `lower_town_slice`, 49 house styles differ only by `door_side`,
`wall_height`, `wall_material`, `roof_material` and two colours. The style names encode exactly that -
`house.south.h120.09`, `house.east.h104.41`. So even a perfect renderer has nothing to vary.

## Deliverable

1. **A district style-set layer.** For each map, a named, reviewed set that says which AR-04 part
   families, roof covers, storey counts, attachments and wear bands are allowed, matched to the
   `docs/HISTORICAL_AUDIT.md` target card for that map (roof-cover shares, density, material mix). The
   `monastery_quarter` set must keep precinct interiors free of generic houses, as its card requires.
   These sets live in code as explicit registries, not as new giant map dictionaries.
2. **Deterministic assembly.** `architecture_kit_assembler.gd` picks, from
   `hash(map_seed, building_id)` only:
   - bay count from the authored footprint frontage and the AR-01 bay module;
   - storey count consistent with the authored `wall_height` (the authored height stays the contract);
   - gable form, roof cover within the district's authored share, and pitch from AR-01;
   - opening schedule per storey, with the door on the authored `door_side`;
   - plinth / undercroft / cellar-hatch presence;
   - attachments (pentice, gallery, outside stair, buttress, chimney, signboard) within a per-district
     allowance;
   - AR-03 surface stems and a wear band.

   Same inputs, same building, forever. No `randi()`, no time, no node path, no instance id.
3. **Roof-cover share enforcement.** Selection is share-aware, not per-building independent, so a map's
   realised tile/shingle/thatch shares land inside its `docs/HISTORICAL_AUDIT.md` band. A verifier
   reports the realised shares per map.
4. **Neighbour awareness**, cheap and deterministic: an adjacent pair on the same street front must not
   receive the same gable form, roof cover *and* bay count. Party walls between abutting footprints are
   shared, not doubled.
5. **The old path is retired map by map.** Retire the box-plus-gable path for `north_quarter`,
   `south_quarter`, `monastery_quarter`, `toompea_quarter` and the harbour/world maps in separate
   commits, each with its own before/after plate, so any regression bisects to one map. The procedural
   builder is deleted only when the last map is off it.
6. LOD and instancing per ADR 0022, with a measured frame budget for `north_quarter` at 96 assembled
   buildings.

## Allowed files

- `scripts/map/view3d/architecture_kit_assembler.gd` (+ `.uid`)
- `scripts/map/view3d/architecture_district_style_sets.gd` (+ `.uid`, new)
- `scripts/map/view3d/map_view_mesh_builder_building_houses.gd` (+ `.uid`)
- `scripts/map/view3d/map_view_mesh_builder_house_structure.gd` (+ `.uid`)
- `scripts/map/view3d/map_view_mesh_builder_house_roof_dressing.gd` (+ `.uid`)
- `scripts/map/view3d/map_view_mesh_builder_buildings.gd` (+ `.uid`)
- `scripts/map/view3d/map_view_rural_dwelling_models.gd` (+ `.uid`)
- `tests/godot/test_ordinary_house_assembly.gd` (+ `.uid`, new)
- `tests/godot/test_building_houses_mesh_builder.gd` (if present), `tests/godot/test_architecture_kit.gd`
- `tools/verify_building_variety.py` (new)
- `tests/python/test_verify_building_variety.py` (new)
- `tools/capture_ar05_ordinary_houses.gd` (+ `.uid`, new)
- `docs/ARCHITECTURE_KIT.md`, `docs/ART_BIBLE.md`, `docs/MAP_AUTHORING.md` (assembler note only),
  `docs/reports/ar05_ordinary_houses.md`, `docs/reports/images/ar05_*.png`, `TODO.md`

## Constraints and non-goals

- **No `content/maps/*.rrmap` edits.** Not one authored cell, footprint, style line, ID or transition
  moves. If a building needs a different look, the assembler must derive it from what is already
  authored. This is the hard boundary of the task.
- No collision or navigation change. Gameplay footprints stay authored on the 2D plane exactly as
  `MapViewBurgherHouseModels` documents. A test must prove walkability per map is bit-identical.
- No new map dictionary factories (`AGENTS.md` / ADR 0009). District style sets are explicit registries.
- Never persist a chunk coordinate, node path or instance id, and never key variation on them.
- Do not touch the 43 tiered houses - AR-06 owns those.
- No interiors, no new enterable buildings, no doors that open. Facades only.
- The authored `wall_height` remains the contract for the building mass. The assembler may not make a
  120 cm-coded building read as four storeys.

## Verification

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_ordinary_house_assembly,test_architecture_kit,test_map_verification
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/validate_map_blueprints.gd
python3 tools/verify_building_variety.py
python3 -m unittest tests.python.test_verify_building_variety -v
python3 tools/verify_map_audit.py && python3 tools/verify_map_activation.py && python3 tools/verify_map_conversion_plan.py
python3 tools/verify_map_composition.py
python3 tools/generate_active_docs_report.py --check
tools/run_performance_report.sh build/ar05_perf.json --quick
git diff --check
```

- `test_ordinary_house_assembly.gd` asserts: every untiered house record assembles; assembly is
  deterministic per `(map_seed, building_id)` across two runs in the same process and across a save /
  load; no two street-adjacent buildings share gable form + roof cover + bay count; party walls between
  abutting footprints are not doubled; the authored `door_side` always carries the door; the authored
  `wall_height` band is respected; no `randi()` / time / node-path input reaches the selector.
- `verify_building_variety.py` reports, per map: distinct assembled configurations, the realised
  tile/shingle/thatch/straw shares against the `docs/HISTORICAL_AUDIT.md` band, and the largest run of
  identical neighbours. It **fails** when `north_quarter` yields fewer than 40 distinct configurations
  across its 96 houses, when any map's realised roof shares fall outside its band, or when three
  street-adjacent buildings are identical.
- **Gameplay invariance proof**: per-map walkable-cell count and the flood-filled largest walkable region
  are bit-identical to the pre-change values (same probe as the coast pack baseline), and the map-audit
  anchor accounting is unchanged.
- `content/maps/` is untouched: `git diff --stat content/maps/` is empty.
- `tools/capture_ar05_ordinary_houses.gd` through `tools/godot_render.sh`: matched before/after plates
  per retired map at the gameplay camera, clear noon and midnight, plus one long street vista per map
  proving variety in a single frame, on Compatibility and Metal at both quality tiers.
- Performance: `north_quarter` frame cost, draw calls, material count and triangle count before/after,
  at both quality tiers, inside the ADR 0022 budget.
- **Named human visual review** per retired map: does the street read as a town or as a pattern. This
  task does not close on green tests (P0-209b).

## Doc updates

`docs/ARCHITECTURE_KIT.md`, `docs/ART_BIBLE.md`, `docs/MAP_AUTHORING.md`,
`docs/reports/ar05_ordinary_houses.md`, `TODO.md`.

## TODO.md line

```
- [ ] R-963 | deps: R-961,R-962 | deliverable: deterministic kit assembly replacing the box-plus-gable path for all 319 untiered house records, driven only by hash(map_seed, building_id) over bay count, storey count, gable form, share-aware roof cover, per-storey opening schedule, plinth/undercroft, attachments and AR-03 surface stems, with explicit per-district style sets matched to the HISTORICAL_AUDIT target cards, neighbour de-duplication, shared party walls, LOD/instancing per ADR 0022, and the old path retired one map per commit | allowed files: per docs/tasks/architecture/AR-05_ordinary_house_assembler.md | verify: `--filter=test_ordinary_house_assembly,test_architecture_kit,test_map_verification`; full Godot suite; blueprint validate; tools/verify_building_variety.py failing under 40 distinct configurations across north_quarter's 96 houses, outside any map's HISTORICAL_AUDIT roof-share band, or on three identical street-adjacent buildings; python verifier unittest; map audit, activation, conversion plan and composition; active docs; determinism across save/load; bit-identical per-map walkable-cell count and largest walkable region; empty `git diff --stat content/maps/`; matched before/after plus long-street vista plates per retired map at noon and midnight on Compatibility and Metal at both tiers; north_quarter frame/draw-call/material/triangle budget; named human review per map that the street reads as a town
```
