# UF-06: Quarter streets
Board row: **R-1115**. Priority: high. Depends on: **R-1114**.

## Player-facing goal

The player stays on continuous named routes through the Pikk/Lai precinct, the north ward and Knights' District, while each quarter retains its distinct medieval grain and closes remain open.

## Why this is needed

The source maps `monastery_quarter`, `north_quarter`, and `south_quarter` exist and are 260 x 112, 260 x 140, and 336 x 96 cells respectively; each is currently an inactive prototype. Their geometry has no authored street-network statement under the current RRMap grammar. Existing source/test contracts include `tests/godot/test_monastery_quarter_prototype_map.gd`, `tests/godot/test_north_quarter_prototype_map.gd`, `tests/godot/test_south_quarter_prototype_map.gd`, and `tests/godot/test_south_quarter_routes.gd`; the requested board filenames `test_monastery_quarter_map.gd` and `test_north_quarter_*.gd` are not present under those exact names. `docs/data/south_quarter_authoring_contract.json` explicitly reserves western pasture and south-wall/Karja glacis open regions and uses an enforced signed composition card.

## Deliverable

Author the register-owned ways and bind/subdivide frontage in: monastery quarter - Pikk, Lai, Vene, Olevimägi, Pühavaimu; north quarter - Pikk toward Coastal Gate, Lai, Tolli, Rannavärav approach; south quarter - Rataskaevu, Kuninga, Rüütli, Dunkri, Suur-Karja, Väike-Karja, Müürivahe. Müürivahe reads as a wall-side back lane, not boulevard. Each passes UF-04 budget. Preserve all existing stable IDs, route and patrol fixtures and parity fixtures; add/extend focused tests without replacing them.

## Allowed files

- `content/maps/monastery_quarter.rrmap`
- `content/maps/north_quarter.rrmap`
- `content/maps/south_quarter.rrmap`
- `docs/data/south_quarter_authoring_contract.json`
- `docs/data/urban_form_budget.json`
- `docs/data/map_composition_thresholds.json`
- `content/world/reval_outdoor_layout.json`
- `tests/godot/test_monastery_quarter_map.gd` (new only if intentionally added; existing prototype test remains required)
- `tests/godot/test_north_quarter_*.gd`
- `tests/godot/test_south_quarter_prototype_map.gd`
- `docs/reports/south_quarter_1343_fabric_contract.md`
- `TODO.md`

## Constraints and non-goals

Preserve every stable ID; maps remain `active=false`. Retain South Quarter signed H-bands, R-677 western-pasture reserve, convent/church closes as open ground; never set P1-036 `enforce=false` or lower a signed band. No filling courts with houses to game density. Rebuild `reval_outdoor_layout.json` in the same commit as source changes. Coordinate with R-285 monastery ordinary fabric; do not land concurrently on `monastery_quarter`. Blueprint primitives/reviewed prefabs only, explicit factory registration, no giant MapDefinition dictionary factories, generated nodes disposable. `MAP_GEOMETRY_OUT_OF_BOUNDS` rejects an entire map, making all its tests fail. No activation or hidden diagnostics.

## Verification

- Headless blueprint validation and full Godot suite: `godot --headless --path . --script tools/validate_map_blueprints.gd`; `godot --headless --path . --script tools/run_godot_tests.gd`.
- `python3 tools/verify_urban_form.py`; `python3 tools/verify_map_composition.py`.
- `godot --headless --path . --script tools/build_world_layout.gd -- --check`; `python3 tools/verify_world_layout.py`.
- `python3 tools/verify_map_audit.py`; `python3 tools/verify_map_activation.py`; `python3 tools/verify_map_conversion_plan.py`.
- All required route, patrol and reciprocal-transition tests remain connected; before/after GPU plates through `tools/godot_render.sh` for each district, noon and midnight; named human review confirms three distinct quarters.

## Doc updates

Update South Quarter ownership/route contract only to encode new street-linked ownership while preserving signed bands, reserves, stable IDs and evidence; document historical certainty in the 1343 fabric contract.

## TODO.md line

- [ ] R-1115 | deps: R-1114 | deliverable: named street networks and irregular frontage for monastery, north and south quarters | verify: headless map/route/patrol tests, urban-form/composition/world/audit/activation/conversion checks and named district review
