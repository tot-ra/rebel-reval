# UF-07: Toompea ramps on relief
Board row: **R-1116**. Priority: high. Depends on: **R-1113, R-976, R-1109**.

## Player-facing goal

Toompea reads and plays as the limestone hill above Lower Town: a long Pikk jalg climb beneath the wall and a steep Lühike jalg stair-lane, joining an identifiable plateau network.

## Why this is needed

`content/maps/toompea_quarter.rrmap` and `content/maps/archbishops_garden.rrmap` author Toompea at `elevation=2.8` world units, about 2.4 m, while HISTORICAL_AUDIT H01/H12 describe a limestone hill approximately 20-30 m above Lower Town and quarry cuts/level changes. The current authored datum therefore represents only a small fraction of the documented relief. ADR 0023 remains **Proposed, 2026-09-26. Awaiting maintainer acceptance**. Its no-code-before-acceptance clause is normative; R-1109 must record a named human decision with ISO date, and WB-04 R-976 must land before this map work proceeds.

## Deliverable

Add `ramp`-class streets on Toompea and Archbishops' Garden following compiled relief; author plateau ways for cathedral close, castle forecourt, Kohtu and Toom-Kooli; bind frontage to streets. Make Pikk jalg and Lühike jalg continuous routes terminating at existing registered gates `pikk_jalg_gate`, `luhike_jalg_gate_arch`, and `garden_descent_gate`. Keep gradients within ADR 0023's 35-degree walkable limit or author `relief_cliff` with an explicit decision. Record chosen datum and evidence against H01/H12.

## Allowed files

- `content/maps/toompea_quarter.rrmap`
- `content/maps/archbishops_garden.rrmap`
- `docs/data/urban_form_budget.json`
- `docs/data/map_composition_thresholds.json`
- `content/world/reval_outdoor_layout.json`
- `tests/godot/test_toompea_quarter_map.gd` (new focused test; verify existing tests first)
- `tests/godot/test_archbishops_garden_map.gd` (new focused test; verify existing test names first)
- `docs/reports/r454_historical_elevation_profiles.md`
- `TODO.md`

## Constraints and non-goals

Do not start until both R-1109 acceptance and WB-04 R-976 are complete; ADR 0023's status remains proposed until maintainer decision. Preserve existing `r454.*` elevation IDs and all gate/anchor IDs. Maps remain inactive. No new landmark models; UF-12 owns castle and cathedral exteriors. No stairs-as-props workaround. Do not exceed ADR 0023 total relief range or hide diagnostics. Preserve stable IDs, use MapBlueprint primitives/reviewed prefabs and explicit factory registrations; generated nodes disposable, diagnostics stable. Rebuild `reval_outdoor_layout.json` with any `reval_outdoor` `.rrmap` edit. `MAP_GEOMETRY_OUT_OF_BOUNDS` rejects the whole map.

## Verification

- `godot --headless --path . --script tools/validate_map_blueprints.gd` with no unreviewed `MAP_RELIEF_SLOPE`.
- `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_toompea_quarter_map,test_archbishops_garden_map` (confirm or add those test identifiers; existing exact files were not found in the current repository census).
- Headless walk from Lower Town gate cell to plateau anchor succeeds on compiled height field and fails when ramp is removed.
- `python3 tools/verify_urban_form.py`; build/check world layout and `python3 tools/verify_world_layout.py`.
- GPU silhouette captures via `tools/godot_render.sh`, Lower Town looking up and plateau looking down, noon/midnight; named human review confirms apparent 20-30 m hill.

## Doc updates

Record relief datum choice and H01/H12 confidence/uncertainty in `docs/reports/r454_historical_elevation_profiles.md`; document ramp street semantics in `docs/MAP_AUTHORING.md` in the owning implementation task if its scope is amended.

## TODO.md line

- [ ] R-1116 | deps: R-1113, R-976, R-1109 | deliverable: relief-aware Pikk jalg/Lühike jalg ramps and Toompea plateau streets | verify: ADR gate, compiled-height walk positive/negative tests, blueprint/world/urban-form checks and named silhouette review
