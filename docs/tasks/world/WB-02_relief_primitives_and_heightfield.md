# WB-02: Signed relief primitives and a compiled gameplay height field

Board row: **R-974**. Priority: high. Depends on: **R-973** (ADR 0023 accepted).

## Player-facing goal

None directly yet - this row makes relief *authorable and compiled*. R-975 makes it felt.

## Why this is needed

Today an author has exactly two shapes: `elevation_area` (a flat rect plateau) and `elevation_ramp`
(a linear gradient), both clamped to `0.0 .. 8.0`. Tallinn's ground is not a stack of rectangular
plateaus. There is no way to author a rounded hill shoulder, a ditch, a moat, a cut bank, a hollow
way worn below grade, a quarry step, or a cliff.

## Deliverable

1. **New `.rrmap` relief statements**, parsed by `MapRrmapParserStatements` and round-tripped by
   `MapRrmapSerializer`, each with a stable ID as its first argument:
   - `relief_hill ID cx cy radius height [falloff=smooth|linear|plateau]` - radial mound.
   - `relief_ridge ID x0 y0 x1 y1 width height [falloff=...]` - linear crest, for the Toompea
     escarpment and street-side banks.
   - `relief_ditch ID x0 y0 x1 y1 width depth` - signed negative, for moats, drains and hollow ways.
   - `relief_terrace ID x y w h height [edge=N]` - a plateau with a worked edge of `N` cells rather
     than a vertical face.
   - `relief_cliff ID x0 y0 x1 y1 drop` - an intentionally impassable face.
   - `relief_noise ID x y w h amplitude [seed=N]` - bounded deterministic undulation so open ground
     is not a plane.
   `elevation_area` and `elevation_ramp` remain accepted and lower into the same field unchanged.
2. **A compiled per-cell height field** on `MapDefinition`, produced deterministically by
   `MapBlueprintCompilerExpandTerrain` by evaluating relief primitives in authored order. Height
   range per ADR 0023. The field participates in the canonical fingerprint; bump the compiler
   version and state the new number in `docs/MAP_AUTHORING.md`.
3. **A sampling API** on `MapDefinition`: `height_at(cell) -> float`, `height_at_world(Vector2)`
   with bilinear interpolation, and `slope_at_world(Vector2) -> float` in radians. These are the
   single source of truth for R-975.
4. **Diagnostics** as stable `MapBlueprintDiagnostic.code` values: `MAP_RELIEF_RANGE` (error, height
   outside the ADR range), `MAP_RELIEF_SLOPE` (warning, a face exceeds the walkable slope where no
   `relief_cliff` was authored), `MAP_RELIEF_SEAM` (error, height at a physical transition edge does
   not match the reciprocal map within tolerance), `MAP_RELIEF_UNDER_BUILDING` (warning, a building
   footprint spans more than a stated height delta).
5. **View-layer reconciliation.** `MapViewMeshBuilder.ensure_height_field` consumes the compiled
   field as its base and keeps its procedural relief only as sub-cell detail, so `boat_float_3d`,
   `map_view_penned_fauna`, `map_view_urban_fauna`, `map_view_mesh_builder_scatter` and
   `map_view_terrain_details` keep their current call sites.

## Allowed files

`scripts/map/rrmap/map_rrmap_parser_statements.gd`, `scripts/map/rrmap/map_rrmap_serializer.gd`,
`scripts/map/map_blueprint.gd`, `scripts/map/map_blueprint_compiler.gd`,
`scripts/map/map_blueprint_compiler_expand_terrain.gd`, `scripts/map/map_blueprint_compiler_build.gd`,
`scripts/map/map_blueprint_diagnostic.gd`, `scripts/map/map_blueprint_semantic_validator.gd`,
`scripts/map/map_definition.gd`, `scripts/map/view3d/map_view_mesh_builder_terrain.gd`,
matching `.uid` sidecars, `tests/godot/test_map_relief_field.gd` and its `.uid`,
`tests/fixtures/maps/rrmap_relief_example.rrmap` and its `.uid`, `docs/MAP_AUTHORING.md`,
`docs/tasks/world/WB-02_relief_primitives_and_heightfield.md`, `TODO.md`.

## Constraints and non-goals

No gameplay behaviour change in this row: navigation, collision, movement and the player rig are
untouched, so every existing map must behave identically at runtime. Preserve every stable ID,
including all `r454.*` profiles. Do not re-author any map here. Do not regenerate parity fixtures to
get green - a parity change must be explained cell by cell.

## Verification

- `godot --headless --path . --script tools/validate_map_blueprints.gd`
- `godot --headless --path . --script tools/run_godot_tests.gd`, including a new
  `test_map_relief_field.gd` asserting: determinism across two compiles, exact round trip through
  parser and serializer for every new statement, `elevation_area`/`elevation_ramp` lowering to the
  same heights as before the change, signed depth below zero, bilinear sampling at cell centres and
  edges, slope values on a known ramp, and each of the four diagnostic codes firing.
- `python3 tools/verify_map_audit.py`, `verify_map_activation.py`, `verify_map_conversion_plan.py`,
  `python3 tools/generate_active_docs_report.py --check`, `git diff --check`
- Semantic snapshot parity for all 29 maps: compiled height must be unchanged for every map that
  authors no new statement.

## Doc updates

`docs/MAP_AUTHORING.md`: the six new statements in the EBNF grammar and the primitive mapping table,
the new compiler version, the height range, and a replacement for the "view-layer only" paragraph.

## Implementation notes and decisions (2026-09-26)

Status: implemented, **in review**. ADR 0023 is drafted and merged as *Proposed*; the maintainer
acceptance line in its `Status` section is still open, so R-974 stays `in_review` until it is signed.

- **Legacy lowering is zero.** Audit during implementation: `grade`, `elevation_area` and
  `elevation_ramp` were parsed and validated but never evaluated by any renderer or gameplay code.
  The only authored height ever drawn was `elevation=` times the 10-cell edge taper. Lowering the
  profiles as real height would have silently reshaped nine maps, so they lower to zero relief and
  keep their `r454.*` IDs. `test_registered_maps_keep_pre_relief_heights` pins every registered
  map (28, not 29 - the registry holds 28 blueprints) to the pre-change datum.
- **Field layout.** `MapDefinition.relief_heights` is empty for maps without `relief_*` statements
  and otherwise one quantised (`1/64`) value per cell centre. Ground height = tapered datum + relief.
  The view field adds `MapDefinition.sample_relief` to its unchanged datum, so rendered ground is
  bit-identical for every existing map.
- **Primitive semantics.** Hill/ridge falloff `smooth|linear|plateau`; ditches use a plateau (flat
  bed) profile; terrace edges use Chebyshev rings so corners are no steeper than sides; cliffs lower
  the right-hand side of `start -> end` in screen orientation (y down) within the segment's span.
- **Diagnostics scope.** `MAP_RELIEF_RANGE`, `MAP_RELIEF_SLOPE` and `MAP_RELIEF_UNDER_BUILDING` run
  only on maps that author relief, so no existing map gains warnings. `MAP_RELIEF_SEAM` needs two
  compiled maps and runs in `tools/validate_map_blueprints.gd` via
  `MapBlueprintSemanticValidator.validate_relief_seams` - one allowed-file deviation (the gate tool
  itself), required so the pre-commit gate can raise the error.
- **Compiler version** 9 -> 10. No committed fixture pins a fingerprint, so no parity file changed.
