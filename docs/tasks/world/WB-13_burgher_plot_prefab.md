# WB-13: Burgher plot prefab family - front house, rear service range, yard, plot wall

Board row: **R-985**. Priority: high. Depends on: **R-984**, **R-981**.

## Player-facing goal

A Lower Town street stops being a row of detached boxes. Each house fronts the street on a narrow
strip plot; behind it a yard runs back with a service range, a privy, a woodpile, a water butt and
a small garden, closed off by a plot wall with a gate. The player can see into the yards through
the gates, and the block reads as somewhere people live.

## Why this is needed

`docs/HISTORICAL_AUDIT.md` H04 already describes the correct structure: irregular streets, strip
plots commonly **7-11 m wide and up to 100 m deep**, a front house with rear service buildings, and
plot walls. H05 adds the archaeology from the NUKU courtyard: a mid-14th-century round-log
auxiliary building with a dirt floor, wattle, wells, gutters, and manure and chip yard layers.

None of it is implemented. `lower_town_slice` has 89 free-standing `building` rectangles with no
plot relationship, no yard, no service range, no plot wall and no gate. There is one prefab package
in the entire project, `scripts/map/prefabs/urban_prefab_package.gd`. At 0.87 m per cell, a 7-11 m
frontage is 8-13 cells, so the geometry fits the existing grid without any change of scale.

## Deliverable

1. **A `burgher_plot` prefab package** in `scripts/map/prefabs/`, reviewed and registered
   explicitly in `scripts/map/map_blueprint_registry.gd`, parameterised by frontage, depth, street
   side, wealth tier, age tier and upkeep, expanding to:
   - a street-fronting house whose footprint, storeys and material follow the tier;
   - an optional rear service range - byre, store, workshop or auxiliary dwelling - on H05's
     round-log evidence for the poorer tiers;
   - a yard with authored ground surface, including the manure and chip layers H05 attests;
   - a plot wall with a gate onto the street or a close;
   - domestic infrastructure placed from the R-984 authoring table: privy, midden, water butt or
     shared well, woodpile sized to the R-984 winter figure, kitchen garden, drying line.
2. **Deterministic prefab-local IDs** derived from the plot ID, stable across recompiles,
   reordering and chunking, per ADR 0009.
3. **Tier-driven variation** rather than random noise: a poor plot on the same street as a rich one
   differs in footprint, storeys, material, roof, wall, yard surface and the presence of a service
   range, all from the tier, all deterministic from the map seed.
4. **New production art** only where an existing model cannot carry the meaning, named exactly in
   the task claim, with `assets/SOURCES.csv` rows. Candidates from the current prop census, which
   has no such models: privy, midden, water butt, plot gate, garden bed, drying line.
5. **Godot tests** and a documented authoring contract.

## Allowed files

`scripts/map/prefabs/burgher_plot_package.gd` and its `.uid`,
`scripts/map/prefabs/urban_prefab_package.gd`, `scripts/map/map_blueprint_registry.gd`,
`scripts/map/map_prefab_expander.gd`, `scripts/map/map_prefab_primitive_transformer.gd`,
`scripts/map/map_prop_style_variants.gd`,
`scripts/map/view3d/map_view_mesh_builder_prop_models.gd`,
`scripts/map/view3d/map_view_mesh_builder_district_life_props.gd`,
new `scripts/map/view3d/map_view_domestic_infrastructure_models.gd` and its `.uid`,
matching `.uid` sidecars, art files named in the task claim, `assets/SOURCES.csv`,
`tests/godot/test_burgher_plot_prefab.gd` and its `.uid`,
`tests/fixtures/maps/rrmap_burgher_plot_example.rrmap` and its `.uid`,
`docs/MAP_AUTHORING.md`, `docs/ART_BIBLE.md`, `docs/reports/images/burgher_plot/`,
`docs/tasks/world/WB-13_burgher_plot_prefab.md`, `TODO.md`.

## Boundary against AR-06 (architecture pack)

AR-06 (`docs/tasks/architecture/AR-06_burgher_tier_expansion.md`, board row R-964) grows the burgher
**meshes** from the current 6 authored house GLBs to a real street population and brings the three
orphaned window facades in `assets/buildings/facades` into use. This row composes the **plot** those
meshes stand on.

So this row must not author house geometry or new house tiers. It consumes AR-06's tier vocabulary
verbatim; if AR-06 has not landed, use the existing `house_tier=` values (`merchant_stone`,
`merchant_stone_rendered`, `merchant_timber`, `merchant_timber_log`, `craft_boda`,
`craft_boda_pentice`) and add no others. New art in this row is limited to yard and service
objects - privy, midden, water butt, plot gate, garden bed, drying line - which AR-06 does not cover.

## Constraints and non-goals

Do not re-author any production map here - R-986 applies the prefab. Asset freeze **P0-040**
applies: no legacy isometric tiles, props or characters, no pixel-frame animation assets, and every
new file named explicitly in the task claim before work starts. Preserve every stable ID. Do not
add a new giant `MapDefinition` factory or a runtime dictionary authoring path. Roof overhang rules
from the `lower_town_slice` header still hold: only fortification seals and the smithy yard fence
may deliberately interpenetrate, so plot walls and neighbouring roofs must not z-fight.

## Verification

- `godot --headless --path . --script tools/validate_map_blueprints.gd` on the fixture, zero errors,
  and an explicit written decision for any `MAP_GEOMETRY_OVERLAP` warning.
- `godot --headless --path . --script tools/run_godot_tests.gd` with
  `test_burgher_plot_prefab.gd` asserting: prefab-local IDs are deterministic across two compiles
  and a reorder; frontage 8-13 cells maps to H04's 7-11 m; each wealth and age tier produces a
  distinguishable footprint, material and infrastructure set; the yard is enterable through the
  gate and the whole plot is navigable; no roof interpenetration.
- `python3 tools/validate_asset_sources.py`, `verify_asset_lint.py`, `verify_storage_hygiene.py`
- `python3 tools/verify_map_audit.py`, `verify_map_composition.py`,
  `generate_active_docs_report.py --check`
- Captures on GL Compatibility and Metal: a street elevation of four plots at four wealth tiers; a
  yard interior plate; a walk clip entering a yard through the gate.
- A second reviewer confirms every placed infrastructure element traces to a row in the R-984
  authoring table, and that nothing on the R-984 reject list appears.

## Doc updates

`docs/MAP_AUTHORING.md` documents the prefab parameters and the tier contract.
`docs/ART_BIBLE.md` records the wealth and age visual ladder.
