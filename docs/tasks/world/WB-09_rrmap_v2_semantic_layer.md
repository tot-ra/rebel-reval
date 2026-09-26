# WB-09: `.rrmap` v2 semantic layer - plots, style presets, required descriptions

Board row: **R-981**. Priority: high. Depends on: **R-982**, **R-974**.
Scope change: requires **ADR 0024** before implementation.

## Player-facing goal

None directly. This row is what lets a human and an agent both author a dense, historically
specific district without drowning in coordinates.

## Why this is needed

The maintainer's two requirements pull against each other in the current format: maps must be
readable and editable by humans, **and** cheap and descriptive for an agent to manage. Today
`lower_town_slice.rrmap` is 28 111 bytes and 89 `building` rows against 63 `style` rows. A sample:

```
building viru_gate_north_tower wall 107 41 10 8 style=wall.plain.h256.02 tower=false round_tower=true wall_walk_axis=z
style house.east.h104.40 door_side=east roof_color=6f6045ff roof_material=thatch wall_color=63594aff wall_material=log wall_height=104
```

Two problems, both measurable.

**Token cost is spent on the wrong thing.** The 63 `style` rows are generated variant names
differing only in two hex colours, a material enum and a height. They carry no authorial intent, so
an agent pays for them on every read and learns nothing.

**Meaning is absent.** Nothing in the file says that a given rectangle is a *rich merchant house
fronting Pikk with a rear service range and a yard*, which is exactly the structure
`docs/HISTORICAL_AUDIT.md` H04 describes - strip plots 7-11 m wide and up to 100 m deep, front
house, rear service buildings, plot walls. The format can only say "box at 107,41, 10x8, brown".
That is why the districts read as generic, and why an agent asked to make them historical has
nothing to reason over.

## Deliverable

1. **ADR 0024** deciding to add a semantic authoring layer, naming the equivalent-cost scope
   removed, and fixing the rule that v2 statements **lower deterministically** into the existing
   primitives so there is exactly one compiled representation and one fingerprint.
2. **A `plot` statement** as the district authoring unit, carrying frontage, depth, street, wealth
   tier, age tier and upkeep, and expanding through a reviewed prefab into a front house, an
   optional rear service range, a yard, a plot wall and a gate. Prefab-local IDs are stable and
   derived from the plot ID, so the census does not churn.
3. **Named style presets** replacing generated variant rows: a small reviewed palette keyed by
   material, wealth and age, held in `scripts/map/prefabs/`, referenced by name. Existing generated
   style IDs remain accepted and unchanged so no current map has to be re-authored to compile.
4. **A required `desc=` field** on `plot`, `landmark` and `anchor`, holding one short human sentence
   of authorial intent. A missing or placeholder description is a `MAP_DESC_MISSING` error. This is
   the descriptiveness half of the requirement and it must be enforced, not encouraged.
5. **A district summary header** emitted by `MapRrmapSerializer`: counts, terrain shares, wealth and
   age distribution, prop density, relief span. An agent reads the header instead of the body when
   it only needs orientation.
6. **Round-trip stability.** Parse then serialize is byte-identical for all 29 current maps.

## Allowed files

`docs/adr/0024-rrmap-semantic-authoring-layer.md`,
`scripts/map/rrmap/map_rrmap_parser_statements.gd`, `scripts/map/rrmap/map_rrmap_serializer.gd`,
`scripts/map/rrmap/map_rrmap_diagnostic.gd`, `scripts/map/map_blueprint.gd`,
`scripts/map/map_prefab_expander.gd`, `scripts/map/prefabs/urban_prefab_package.gd`,
`scripts/map/prefabs/burgher_plot_package.gd`, `scripts/map/map_blueprint_registry.gd`,
`scripts/map/map_blueprint_semantic_validator.gd`, matching `.uid` sidecars,
`tests/godot/test_rrmap_plot_authoring.gd` and its `.uid`,
`tests/fixtures/maps/rrmap_plot_example.rrmap` and its `.uid`,
`docs/MAP_AUTHORING.md`, `docs/tasks/world/WB-09_rrmap_v2_semantic_layer.md`, `TODO.md`.

## Constraints and non-goals

Do not migrate any production map in this row - R-986 does that, once, deliberately. Every existing
statement keeps working; v2 is additive. Preserve every stable ID. Do not introduce a second
compiled representation, a runtime dictionary authoring path, or filesystem blueprint discovery -
ADR 0009 forbids all three. No new giant `MapDefinition` factory.

## Verification

- `godot --headless --path . --script tools/validate_map_blueprints.gd`
- `godot --headless --path . --script tools/run_godot_tests.gd` with
  `test_rrmap_plot_authoring.gd` asserting: a `plot` lowers to the same primitives as the equivalent
  hand-authored buildings; prefab-local IDs are stable across two compiles and across a reorder;
  `MAP_DESC_MISSING` fires on a missing and on a placeholder description; named presets resolve;
  generated legacy style IDs still resolve.
- **Byte-identical round trip for all 29 maps** through parser and serializer.
- **Token-cost evidence**, since that is the stated requirement: author one equivalent district
  block both ways and publish the byte and line counts side by side. The v2 form must be smaller
  *and* must carry a description the v1 form does not.
- `python3 tools/verify_map_audit.py`, `verify_map_activation.py`, `verify_map_conversion_plan.py`,
  `generate_active_docs_report.py --check`
- Full stable-ID census green across all maps; compiled fingerprints unchanged for every map that
  authors no v2 statement.

## Doc updates

`docs/MAP_AUTHORING.md` gains the v2 grammar, the plot prefab contract, the preset palette, the
`desc=` rule and the summary-header format, plus a short "which layer do I author in" section.
