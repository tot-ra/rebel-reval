# UF-04: Frontage binding, block subdivision and anti-grid gate
Board row: **R-1113**. Priority: high. Depends on: **R-1112 (street primitive), R-1111 (street register)**.

## Player-facing goal

Houses address real streets as variable-width and variable-depth plots, and a machine gate detects placement that reads as a regular box grid.

## Why this is needed

The `lower_town_slice` source contains 97 `building` statements and 63 generated variant `style` names (as measured in the pack baseline); buildings currently use absolute cells without street attachment. Its named ownership contract is `docs/data/lower_town_authoring_contract.json`, which fixes merchant frontages at 7-11 m (median 9 m), artisan at 5-9 m, institutional edges at 10-18 m, outer/transition edges at 4-8 m, harbourward service at 6-10 m and documented irregular merchant compounds at 12-14 m. `docs/data/south_quarter_authoring_contract.json` encodes open-region, density-zone and frontage ownership, so plot derivation cannot treat all empty cells as missing plots.

## Deliverable

1. Support `building street=<id> side=<n|s|e|w> offset=<cells>` and seat the building against that street's edge. Frontage width is `w` on north/south sides and `h` on east/west sides.
2. Derive blocks enclosed by streets and subdivide into strip plots in the HISTORICAL_AUDIT H04/H05 7-11 m frontage and approximately 100 m maximum depth band, with authored variation. Consume WB-13 (R-985) plot tiers if available; do not create a parallel tier vocabulary.
3. Add `tools/verify_urban_form.py` and committed per-map limits in `docs/data/urban_form_budget.json`: maximum share of origins sharing axis spacing, maximum identical-frontage run, minimum frontage variance per street, unbound-building share, continuous-way street-cell share. Fail closed and wire `tools/run_pre_commit_checks.sh` for `content/maps/**` and street scripts.

## Allowed files

- `scripts/map/map_blueprint.gd`
- `scripts/map/map_blueprint_compiler*.gd`
- `scripts/map/map_blueprint_semantic_validator.gd`
- `scripts/map/rrmap/map_rrmap_parser_statements.gd`
- `scripts/map/rrmap/map_rrmap_serializer.gd`
- `tools/verify_urban_form.py`
- `docs/data/urban_form_budget.json`
- `tests/python/test_verify_urban_form.py`
- `tests/godot/test_street_frontage.gd`
- `tools/run_pre_commit_checks.sh`
- `docs/MAP_AUTHORING.md`
- `TODO.md`

## Constraints and non-goals

No `.rrmap` content edits: baseline thresholds must reflect measured current state with stated headroom; UF-05 through UF-07 then fix maps. No `enforce=false` escape hatch. Do not duplicate AR-13 appearance repetition checks: this gate measures placement. Preserve stable IDs, use only blueprint primitives/reviewed prefabs, register required factories explicitly in `scripts/map/map_blueprint_registry.gd`, and keep diagnostics codes stable. Do not relax a signed composition band; P1-036 cards stay `enforce=true`.

## Verification

- `python3 -m unittest tests.python.test_verify_urban_form -v` including negative fixtures for regular grid, zero frontage variance, unbound building and discontinuous street.
- `python3 tools/verify_urban_form.py` exits 0 on repository and prints per-map headroom.
- Godot headless `--filter=test_street_frontage`.
- Pre-commit fixtures prove map changes trigger the check and unrelated files do not.
- Fingerprint byte-identity for maps without frontage bindings.

## Doc updates

Document frontage side/dimension convention, plot derivation and thresholds in `docs/MAP_AUTHORING.md`.

## TODO.md line

- [ ] R-1113 | deps: R-1112, R-1111 | deliverable: street-bound frontages, irregular strip plots and fail-closed anti-grid budget | verify: Python negative/real-repo fixtures, headless frontage test, pre-commit fixtures and fingerprint compatibility
