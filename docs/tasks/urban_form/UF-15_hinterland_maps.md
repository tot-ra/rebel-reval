# UF-15: Hinterland maps and second world layout
Board row: **R-1133**. Priority: high. Depends on: **R-1129 (ADR 0027 accepted), R-980, R-1117, R-976**.

## Player-facing goal

Leaving the Viru or Coastal Gate, the player can walk along connected hinterland routes toward Kalamaja, Pirita and Harju without a loading screen, while shore and inland terrain visibly rise and fall.

## Why this is needed

`docs/SEAMLESS_STREAMING_PLAN.md` currently defines one `reval_outdoor` group with 10 streamed maps among 29 total maps; `content/world/reval_outdoor_layout.json` is its existing manifest. The requested connective map sources are not named concretely until ADR 0027, and the current map collection already has `viru_gate_foreland.rrmap`, `world_harju.rrmap`, and `world_sojamae.rrmap`, so distinguish genuinely new connective maps from existing travel maps rather than duplicating IDs or converting distant destinations. The coast ladder dependency belongs to CO-04 (R-951): `docs/tasks/coast/CO-04_coastal_elevation_levels.md` owns Kalamaja shore levels for `reval_harbor_east` (and the companion coast scope); UF-15 must consume that work or obtain explicit agreement. The complaint that near-sea maps are flat and houses too close to beach is CO-04's, not this row's. UF-15 owns only connecting maps and the second world layout.

## Deliverable

After accepted ADR 0027 names exact connective maps, author only those new maps as MapBlueprint blueprints and RRMap sources, explicitly register their factories in `scripts/map/map_blueprint_registry.gd`, add required anchors and reciprocal physical seams to `reval_outdoor` gate edges, and build `content/world/reval_hinterland_layout.json` with `tools/build_world_layout.gd`. Use UF-03 `extramural road` class. Keep dwellings off foreshore by consuming the CO-04 four-level foreshore/berm/dune/terrace ladder after CO-04 lands, or by explicit agreement with its owner. Preserve distinct travel beats for distant `world.*` destinations.

## Allowed files

- `content/maps/*.rrmap` (new connective maps only)
- `scripts/map/definitions/prototypes/**`
- `scripts/map/map_blueprint_registry.gd`
- `scripts/map/map_catalog.gd`
- `scripts/map/map_audit_registry.gd`
- `content/map_audit_manifest.json`
- `content/world/reval_hinterland_layout.json`
- `content/transitions/active_destinations.json`
- `docs/MAP_CONVERSION_PLAN.md`
- `docs/reports/scene_inventory.md`
- `tests/godot/test_hinterland_maps.gd`
- `docs/SEAMLESS_STREAMING_PLAN.md`
- `TODO.md`

## Constraints and non-goals

All new maps stay `active=false`; activation belongs to their own gate task. No giant MapDefinition dictionary factories, no filesystem discovery, and only blueprint primitives/reviewed prefabs. Register every blueprint explicitly. Never convert a distant `world.*` travel destination into a seam. Streaming flags retain ADR-0027 defaults. Depend on CO-04 for Kalamaja shore level ladder; do not assume UF-15 owns it. Preserve stable IDs, keep generated nodes disposable and diagnostics stable, and do not evade bounds/route diagnostics. Use `--headless` for all Godot commands.

## Verification

- `godot --headless --path . --script tools/validate_map_blueprints.gd`
- `godot --headless --path . --script tools/build_world_layout.gd -- --check` for both groups; `python3 tools/verify_world_layout.py` (verify second-group support is implemented before relying on it).
- `godot --headless --path . --script tools/verify_seam_continuity.gd`
- `python3 tools/verify_map_audit.py`, `python3 tools/verify_map_activation.py`, `python3 tools/verify_map_conversion_plan.py`
- `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_hinterland_maps`
- Headless walk from Lower Town through a gate seam to a hinterland anchor succeeds on compiled height field.
- `tools/run_map_pipeline_ci.sh benchmark-smoke` meets resident-group frame budget.
- `tools/godot_render.sh` plates show dwellings above waterline on graded shore.

## Doc updates

Update `docs/SEAMLESS_STREAMING_PLAN.md`, map audit/conversion inventory and tests to include the second group and exact connective maps established in accepted ADR 0027. The ADR 0027 maintainer decision and CO-04 ownership/dependency must be explicit before this row begins implementation.

## TODO.md line

- [ ] R-1133 | deps: R-1129, R-980, R-1117, R-976 | deliverable: registered connective hinterland blueprints and second world layout, consuming CO-04 shore ladder | verify: headless blueprint/layout/seam/audit/activation/conversion checks, cross-gate walk, benchmark and graded-shore plates
