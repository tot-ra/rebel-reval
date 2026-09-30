# UF-03: Street primitive, compiled StreetNetwork and street diagnostics
Board row: **R-1112**. Priority: high. Depends on: **R-1110 (ADR 0026 accepted)**.

## ADR gate and geometry authority

[ADR 0026](../../adr/0026-streets-as-authored-network.md) is **Proposed, 2026-09-30**.
UF-03 remains blocked until named WB-09 owner agreement and named maintainer
scope approval/acceptance are recorded; merging the proposal is not acceptance.
Implement its edge-aligned trace, 1..16-cell width bounds, 1-cell-per-4-cell width
change limit, connection/overlap rules and per-class dead-end diagnostics as one
geometry authority. `extramural_road` uses the same primitive as the urban classes.
Frontage seating belongs to UF-04 / R-1113; WB-09 / R-981 consumes that output.
The no-street fingerprint payload must omit an empty network and preserve the
legacy version-salt path. Do not regenerate parity fixtures to satisfy that rule.

## Player-facing goal

An authored street has a durable identity, trace, width, surface and continuity; it is not inferred from terrain left between buildings.

## Why this is needed

The parser dispatcher in `scripts/map/rrmap/map_rrmap_parser_statements.gd` and the adjacent canonical serializer `scripts/map/rrmap/map_rrmap_serializer.gd` contain no `street` statement. The 23 currently authored RRMap statement kinds are: `anchor`, `building`, `camera`, `decal`, `elevation_area`, `elevation_ramp`, `exclude`, `fade`, `landmark`, `map`, `patrol`, `prop`, `rrmap`, `sign`, `source`, `spawn`, `stroke`, `style`, `surroundings`, `terrain`, `terrain_rects`, `transition`, and `wall`. Today street intent is implicit in `terrain_rects` and `stroke` gaps. `lower_town_slice` has 97 building rows and 63 style rows, and geometry placement has no street identity to which a building can bind.

## Deliverable

Add the `street` statement and round-trip serialization; a typed `MapBlueprint` primitive; deterministic compilation to ordered `MapDefinition.street_network`, canonical fingerprint inclusion and emission of ground surface from each street's own surface. Add stable diagnostic codes `MAP_STREET_ORPHAN` (touches no gate, square, transition or other street), `MAP_STREET_WIDTH_JUMP` (width changes faster than ADR band's limit), `MAP_STREET_DEAD_END` (ADR 0026 per-class endpoint rules: one unconnected alley endpoint warns, two error; all other classes forbid an unconnected endpoint), and `MAP_STREET_OVERLAP`. Polyline traces must be strictly orthogonal; stepped segments represent angled ways. Thickness grows from the authored start edge in +x/+y, not centered, matching `stroke`.

## Allowed files

- `scripts/map/rrmap/map_rrmap_parser_statements.gd`
- `scripts/map/rrmap/map_rrmap_serializer.gd`
- `scripts/map/map_blueprint.gd`
- `scripts/map/map_blueprint_compiler.gd`
- `scripts/map/map_blueprint_compiler_build.gd`
- `scripts/map/map_blueprint_compiler_expand_terrain.gd`
- `scripts/map/map_blueprint_semantic_validator.gd`
- `scripts/map/map_blueprint_diagnostic.gd`
- `scripts/map/map_definition.gd`
- `tests/godot/test_rrmap_parser*.gd`
- `tests/godot/test_street_network.gd`
- `docs/MAP_AUTHORING.md`
- `TODO.md`
- `agents/rebel-map/playbook.md`

## Constraints and non-goals

Follow `docs/MAP_AUTHORING.md`, ADR 0009 and ADR 0010: MapBlueprint primitives and reviewed prefabs only, no giant MapDefinition dictionary factories; explicitly register required factories in `scripts/map/map_blueprint_registry.gd`; preserve every stable ID; generated nodes are disposable. `MapBlueprintDiagnostic` codes are stable API. No `.rrmap` edits, navigation-cost or traffic behavior, nor retirement of `stroke` or `terrain_rects`. Maps without streets must preserve bit-identical fingerprints and walkability across all 29 current maps. Do not bypass diagnostics. A future `stroke` edit must retain edge-origin thickness and orthogonal steps.

## Verification

- `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_street_network,test_rrmap_parser`
- `godot --headless --path . --script tools/validate_map_blueprints.gd`
- Compare before/after fingerprint and walkability bytes for all 29 existing maps.
- Negative fixture for each new diagnostic code; byte-identical serializer round-trip of a street-bearing fixture.
- `godot --headless --path . --script tools/build_world_layout.gd -- --check`
- `python3 tools/verify_world_layout.py`

## Doc updates

Document syntax, semantics, width/surface behavior, diagnostics and migration compatibility in `docs/MAP_AUTHORING.md`; add the parser/compiler lessons to the Map playbook.

## TODO.md line

- [ ] R-1112 | deps: R-1110 | deliverable: typed RRMap street primitive, deterministic StreetNetwork and stable diagnostics | verify: headless parser/network tests, all-map identity, blueprint validation and world-layout checks
