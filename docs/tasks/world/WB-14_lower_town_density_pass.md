# WB-14: Density, wealth and age tiers, and landscape bedding on `lower_town_slice`

Board row: **R-986**. Priority: high. Depends on: **R-985**, **R-976**, **R-982**.

## Player-facing goal

The one district the player actually walks through stops looking placed and starts looking lived
in. Streets are worn where people walk and muddy where they do not. Houses sit **in** the ground
rather than on it. Rich stone houses on the merchant spine, poor log houses in the back lanes, some
buildings clearly newer than their neighbours. Yards, gardens, woodpiles, washing, animals, refuse.
Trees and rough ground where nothing is built.

## Why this is needed

This is the row the maintainer's complaint names directly. `lower_town_slice` is `scope=production`
and `active=true`, so it is what the game currently is:

| Metric | `lower_town_slice` | `kalev_smithy` (shipped interior) |
|---|---|---|
| Cells | 19 456 | 364 |
| Props | **39** | 41 |
| Props per 1000 cells | **2.0** | **112.6** |
| Decals | 11 | 7 |
| Distinct prop kinds | 19 | - |
| Elevation profiles | 4, three pinned to 0.0 | 0 |

Thirty-nine props across roughly 14 700 m². Of those, 8 are stairs and 6 are carts, so the district
has 2 wells, 2 trees, 2 bushes, 1 hay stack and 1 firewood stack. The 63 `style` rows vary two hex
colours and a wall height on the same box.

## Deliverable

1. **Density to the R-982 dense-urban thresholds**, met with variety rather than cloning: the
   single-kind share cap and the distinct-kind floor both hold, and the identical-adjacent-footprint
   run detector reports clean.
2. **Plot-based re-authoring** of the residential blocks through the R-985 `burgher_plot` prefab and
   the R-981 `plot` statement, with an authored wealth and age distribution - stone and tile on the
   merchant spine, plaster and plank in the middling lanes, log and thatch in the back lanes and
   toward the wet northern margin, matching the 1343 material mix already recorded in the file's own
   header comment and in `docs/HISTORICAL_AUDIT.md`.
3. **Domestic infrastructure placed from the R-984 table**: wells at a justified density instead of
   two, water butts, privies, middens, woodpiles, kitchen gardens, drying lines, animal pens where
   H18 supports them.
4. **Landscape bedding.** Buildings meet the ground with sills, plinths, steps and skirt geometry
   rather than a cut line. Ground surfaces follow use: worn earth and stone on the spines, mud and
   weeds in the closes, the R-976 relief fall toward the wet north margin, puddles in the hollows
   using the existing puddle and wear decal shaders.
5. **Vegetation and rough ground** on unbuilt land, through the existing foliage, bush, tree and
   scatter renderers - no new vegetation system.
6. **Wear and dirt** using the existing decal path, which 26 of 29 maps currently do not use at all.
7. **A before-and-after density table** against the R-982 baseline, published in the report.

## Allowed files

`content/maps/lower_town_slice.rrmap` and its `.uid`,
`content/transitions/active_destinations.json` only if a transition cell moves, with justification,
`docs/data/map_composition_thresholds.json`, `scripts/map/prefabs/burgher_plot_package.gd`,
`scripts/map/view3d/map_view_decals.gd`, `scripts/map/view3d/map_view_mesh_builder_scatter.gd`,
`scripts/map/view3d/map_view_terrain_details.gd`, matching `.uid` sidecars,
`tests/godot/test_lower_town_density.gd` and its `.uid`,
`docs/reports/lower_town_density_2026-09-26.md`, `docs/reports/images/lower_town_density/`,
`docs/HISTORICAL_AUDIT.md`, `docs/tasks/world/WB-14_lower_town_density_pass.md`, `TODO.md`.

## Boundary against AR-05 and AR-06 (architecture pack)

AR-05 (board row R-963) replaces the procedural box-plus-gable renderer for the 319 untiered houses;
AR-06 (R-964) expands the burgher meshes. Both change how `lower_town_slice` looks, and so does this
row. They are independently landable because they touch different layers - AR-05 the assembler,
AR-06 the meshes, this row the `.rrmap` file - but:

- the authored wealth and age distribution here must map onto the AR tier vocabulary, not a parallel
  one;
- building **appearance** repetition is measured by AR-13, not by this row's density test;
- whichever of AR-05, AR-06 and this row lands last owns the combined before/after captures, because
  a plate taken between two of them documents a state that will not ship.

## Constraints and non-goals

**One map only.** Migrate one map at a time, per `AGENTS.md`; the other districts follow in their
own rows once this one passes. Preserve every stable ID - map, transition, spawn, anchor, patrol,
prop, structure, landmark, prefab instance and prefab-local. Do not resize the map. Do not move a
transition, spawn or anchor without naming it and justifying it. Mart's conversation, the anvil
spearhead pickup and the forge route must all still work. Asset freeze **P0-040** applies; any new
art comes from R-985 or is named explicitly here. No new rendering system.

## Verification

- `godot --headless --path . --script tools/validate_map_blueprints.gd`, zero errors, with a written
  decision for every warning.
- `godot --headless --path . --script tools/run_godot_tests.gd` with `test_lower_town_density.gd`
  asserting the R-982 dense-urban thresholds, the distinct-kind floor, the single-kind cap and the
  identical-footprint-run limit.
- **Full stable-ID census green** against the pre-change baseline.
- Walkable-cell count and largest walkable region recorded before and after; every transition,
  spawn and anchor cell still walkable and still reachable from the primary spawn by flood fill.
- `python3 tools/verify_map_composition.py`, `verify_map_audit.py`, `verify_map_activation.py`,
  `verify_map_conversion_plan.py`, `generate_active_docs_report.py --check`, `git diff --check`
- **Playthrough regression**: main menu to Lower Town to forge, Mart conversation, anvil pickup,
  district map travel, save and load, on keyboard and on gamepad.
- Captures on GL Compatibility and Metal, before and after, at the fixed `R-716` capture contract:
  merchant spine, a back lane, a yard, and a vista, in day, night and rain.
- `tools/run_performance_report.sh` on minimum and recommended tiers, inside budget. Density work
  is the most likely thing in this pack to break the budget, so a failing number blocks the row
  rather than being deferred.
- The `R-716` world-building visual gate row for `lower_town_slice` updated with evidence paths and
  a named human art reviewer.

## Doc updates

`docs/reports/lower_town_density_2026-09-26.md` carries the before-and-after table and the reviewer
record. `docs/HISTORICAL_AUDIT.md` records any authoring decision that resolved a `U` label.
