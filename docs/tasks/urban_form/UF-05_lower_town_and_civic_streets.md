# UF-05: Lower Town and civic streets
Board row: **R-1114**. Priority: high. Depends on: **R-1113, R-1111**.

## Player-facing goal

Leaving Kalev's yard, the player joins named medieval ways that lead to the well, Niguliste, gates and forum, with varied frontage and legible civic open space rather than a corridor between repeated houses.

## Why this is needed

`content/maps/lower_town_slice.rrmap` is a 152 x 128 cell active production map; `market_civic_quarter.rrmap` is a 114 x 128 cell inactive prototype. The pack baseline counts 97 `building` rows versus 63 `style` rows in Lower Town. Neither source has a `street` statement because the RRMap grammar currently has none. Lower Town's contract `docs/data/lower_town_authoring_contract.json` sets merchant frontage 7-11 m (median 9), artisan 5-9, institutional 10-18, edge 4-8, harbourward 6-10, irregular merchant compounds 12-14; all must be considered alongside its ownership and gameplay contracts. The required historical way names include Rataskaevu, Niguliste, Dunkri and Harju; Vanaturg and Raekoja must read as authored square edges.

## Deliverable

Author street rows for every UF-02 register way owned by these two maps; bind current buildings to streets with authored frontage variation; subdivide blocks into strip plots; define Vanaturg/Raekoja edges as square-edge streets. Both maps must pass UF-04's budget with headroom. Street traces and widths must reflect the attested register and confidence vocabulary rather than fabricated historical certainty.

## Allowed files

- `content/maps/lower_town_slice.rrmap`
- `content/maps/market_civic_quarter.rrmap`
- `docs/data/lower_town_authoring_contract.json`
- `docs/data/urban_form_budget.json`
- `docs/data/map_composition_thresholds.json`
- `content/world/reval_outdoor_layout.json`
- `tests/godot/test_lower_town_*.gd`
- `tests/godot/test_market_civic_quarter_map.gd`
- `docs/reports/reval_street_register_1343.md`
- `TODO.md`

## Constraints and non-goals

Preserve every stable map/building/transition/spawn/anchor/patrol/prop/landmark ID. Patrol points and route anchors remain walkable; inspect compiled `MapDefinition` records, not generated nodes. Preserve parity fixtures and regenerate `lower_town_slice.parity.json` only for IDs deliberately moved, naming every move. Any `.rrmap` change to a `reval_outdoor` map requires rebuilding `content/world/reval_outdoor_layout.json` in the same commit. Sequence this before WB-14 (R-986) density and never concurrently with it; coordinate non-concurrent Lower Town work with AR-05 (R-964). Do not activate any map or suppress diagnostics. Use blueprint primitives/reviewed prefabs and explicit factory registration; generated nodes are disposable. Bounds errors `MAP_GEOMETRY_OUT_OF_BOUNDS` reject the whole map and therefore invalidate every test on it. Do not alter P1-036 enforcement or signed bands.

## Verification

- `godot --headless --path . --script tools/validate_map_blueprints.gd`
- `godot --headless --path . --script tools/run_godot_tests.gd`
- `python3 tools/verify_urban_form.py`
- `python3 tools/verify_map_composition.py`
- `godot --headless --path . --script tools/build_world_layout.gd -- --check`
- `python3 tools/verify_world_layout.py`
- `python3 tools/verify_map_audit.py` and `python3 tools/verify_map_activation.py`
- Existing route/patrol tests plus demo walkthrough remain green; matched GPU gameplay-camera plates via `tools/godot_render.sh` at yard exit, Rataskaevu, Niguliste frontage and forum edge, noon and midnight; named human review confirms designed-town legibility.

## Doc updates

Update `docs/data/lower_town_authoring_contract.json` only to reflect authored ownership/frontage evidence; retain all existing IDs and threshold enforcement. Record evidence/confidence in the street register, not unsupported claims.

## TODO.md line

- [ ] R-1114 | deps: R-1113, R-1111 | deliverable: authored Lower Town and civic street networks with bound, irregular frontage and square edges | verify: blueprint, full headless suite, urban-form/composition/world/audit checks, route/patrol parity and named visual review
