# AR-06: Lower Town burgher tier expansion and live window facades

Board row: **R-964**. Priority: high. Depends on: AR-03, AR-04.

## Player-facing goal

The shipped Lower Town slice - the part of the game that is actually playable today - stops looking like
three houses repeated down a street. Each plot on Pikk, Vene, Saiakang and the market rows has its own
frontage width, storey count, gable, cellar arrangement, shop opening and wear. Windows and shutters are
real openings with frames, not painted rectangles, and some are open while others are shuttered.

## Why this is needed

`lower_town_slice` is the **active production map**, and it carries all 43 `house_tier=` records in the
project. Those 43 buildings are served by **6 GLB files**:

- `merchant_stone.glb`, `merchant_stone_rendered.glb`
- `merchant_timber.glb`, `merchant_timber_log.glb`
- `craft_boda.glb`, `craft_boda_pentice.glb`

`MapViewBurgherHouseModels` documents the consequence itself: "The kit only ships two meshes per tier, so
a street of similar plots would otherwise clone one albedo set." Its whole variety mechanism is a
duplicated material, an extra tileable map, a mild tint and a UV offset, plus a non-uniform scale fit
that stretches one mesh onto each authored footprint.

Separately, `assets/buildings/facades/` holds three finished window-facade GLBs -
`timber_window_open_shutters`, `timber_window_closed_shutters`, `stone_pointed_window_open_shutters` -
built by `tools/generate_window_facades.py` and imported into Godot, and **no runtime script references
them**. They are dead assets. `tools/window_facade_mesh_builder.py` exists to make more.

## Deliverable

1. **Per-plot assembly for the three tiers.** The tiers stop being whole-mesh variants and become AR-04
   kit assemblies, so frontage comes from the authored footprint rather than from stretching a fixed
   mesh. The non-uniform-scale fit and the `MIN_VERTICAL_SCALE` / `MAX_VERTICAL_SCALE` band are retired:
   bay count absorbs frontage, storey count absorbs height, and doors, windows and roof pitch stay at
   their true size. This is the specific defect the loader comment already flags ("the v1 loader squeezed
   the whole model ... which left 0.5 m doors and flat roofs").
2. **A real population.** Per tier, enough authored variation that no two of the 43 plots read the same:
   frontage bay counts across the authored range, two- and three-storey variants, triangular and stepped
   gables, with and without exposed undercroft, with and without pentice, hoist beam, gallery or outside
   stair, and three wear bands.
3. **Window facades go live.** The three existing facade GLBs are wired into the opening schedule as
   kit opening parts, extended per AR-01 to the full set the tiers need (unglazed, shuttered open,
   shuttered closed, counter shutter, pointed stone, grille), and a deterministic per-building mixture so
   one facade has open shutters and its neighbour closed. If any of the three existing GLBs does not fit
   the AR-04 snap module, it is rebuilt through `tools/generate_window_facades.py` - not left orphaned.
4. **Smoke outlets stay correct.** The `smoke` outlet contract in `MERCHANT_TIMBER_VARIANTS` (and the
   stone / boda equivalents) is preserved: every assembly still publishes a flue outlet position that the
   existing smoke effect binds to, and a test proves the outlet sits on the chimney or vent, not in air.
5. **Surface variety simplifies.** With AR-03 landed and real geometry variety in place,
   `map_view_burgher_house_surface_variety.gd` stops being the primary variety mechanism and becomes what
   it should be - a wear and stem selector. The tint-and-UV-offset hack is removed or reduced, and the
   report states which.
6. `assets/SOURCES.csv` rows for anything new; superseded whole-house GLBs are removed only once nothing
   references them, per the storage policy.

## Allowed files

- `assets/buildings/kit/**` (tier-specific parts only), `assets/buildings/facades/**`
- `assets/props/architecture/houses/**` (retirement of superseded monoliths only)
- `assets/SOURCES.csv`
- `tools/generate_window_facades.py`, `tools/window_facade_mesh_builder.py`,
  `tools/build_architecture_kit.py`
- `scripts/map/view3d/map_view_burgher_house_models.gd` (+ `.uid`)
- `scripts/map/view3d/map_view_burgher_house_stone_models.gd` (+ `.uid`)
- `scripts/map/view3d/map_view_burgher_house_craft_boda_models.gd` (+ `.uid`)
- `scripts/map/view3d/map_view_burgher_house_surface_variety.gd` (+ `.uid`)
- `scripts/map/view3d/architecture_kit_catalogue.gd` (+ `.uid`),
  `scripts/map/view3d/architecture_kit_assembler.gd` (+ `.uid`)
- `tests/godot/test_burgher_house_models.gd`, `tests/godot/test_window_facades.gd` (+ `.uid`, new)
- `tools/capture_ar06_burgher_street.gd` (+ `.uid`, new)
- `docs/ASSET_INVENTORY.md`, `docs/ART_BIBLE.md`, `docs/ARCHITECTURE_KIT.md`,
  `docs/reports/ar06_burgher_tiers.md`, `docs/reports/images/ar06_*.png`, `TODO.md`

## Constraints and non-goals

- Asset freeze P0-040: exactly the files above.
- **No `content/maps/lower_town_slice.rrmap` edits.** The 43 `house_tier=` assignments, footprints,
  styles, door sides, anchors and transition IDs are untouched. `lower_town_slice` is the shipped map;
  moving a cell here breaks the demo.
- No collision or navigation change; walkability must be bit-identical. The forge, Mart's conversation,
  the anvil pickup and every transition must still work.
- Save/load must be verified explicitly: this is the active map, so `MapStableStateStore` and the save
  service are in scope for regression even though this task writes no state.
- No interiors and no new enterable doors. The forge remains the only interior reached from here.
- Do not delete a monolithic GLB while any script, scene or test still references it.
- The three existing facade GLBs are to be **used or rebuilt**, never left orphaned. Leaving them
  unreferenced fails the task.

## Verification

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_burgher_house_models,test_window_facades,test_architecture_kit,test_save
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/validate_map_blueprints.gd
python3 tools/verify_building_variety.py
python3 tools/validate_asset_sources.py && python3 tools/verify_asset_lint.py && python3 tools/verify_storage_hygiene.py
python3 tools/verify_map_audit.py && python3 tools/verify_map_activation.py && python3 tools/verify_map_composition.py
python3 tools/generate_active_docs_report.py --check
tools/run_pre_commit_checks.sh all
```

- `test_burgher_house_models.gd` asserts: all 43 plots assemble; **no two of the 43 produce the same
  configuration**; door height and window head height fall inside the AR-01 band on every plot (the 0.5 m
  door defect cannot recur); roof pitch equals the AR-01 pitch for the assigned cover on every plot;
  every assembly publishes a flue outlet that lies on its chimney or vent geometry; no non-uniform scale
  is applied to a whole assembly.
- `test_window_facades.gd` asserts every facade GLB in `assets/buildings/facades/` is referenced by the
  catalogue, snaps to the AR-04 module, and that open and closed shutter states both appear on
  `lower_town_slice` under the deterministic selector.
- `verify_building_variety.py` (from AR-05) reports `lower_town_slice` distinct configurations = 43 and
  no identical street-adjacent pair.
- **Gameplay invariance**: walkable cells and largest walkable region bit-identical; the demo route
  main menu -> Lower Town -> forge -> Mart conversation -> anvil pickup still completes; a save made
  before the change loads after it with the same player position and state.
- `git diff --stat content/maps/` is empty.
- `tools/capture_ar06_burgher_street.gd` through `tools/godot_render.sh`: matched before/after plates of
  the Pikk, Vene, Saiakang and market frontages at the gameplay camera; one plate framing the largest
  contiguous run of plots in a single shot to prove variety; a facade close-up showing open and closed
  shutters side by side; clear noon and midnight; Compatibility and Metal; both quality tiers.
- Performance: `lower_town_slice` frame cost, draw calls, materials and triangles before/after, inside
  the ADR 0022 budget.
- **Named human visual review** of the four frontage plates. Does the shipped street look like a
  Hanseatic Lower Town. Green tests do not close this (P0-209b).

## Doc updates

`docs/ASSET_INVENTORY.md`, `docs/ART_BIBLE.md`, `docs/ARCHITECTURE_KIT.md`,
`docs/reports/ar06_burgher_tiers.md`, `TODO.md`.

## TODO.md line

```
- [ ] R-964 | deps: R-961,R-962 | deliverable: the three burgher tiers converted from six stretched monolithic GLBs to per-plot AR-04 kit assemblies with bay-count frontage fitting (retiring the non-uniform whole-model scale fit and its MIN/MAX_VERTICAL_SCALE band), enough authored variation that none of the 43 lower_town_slice plots repeat, the three orphaned assets/buildings/facades window GLBs wired live into the opening schedule with deterministic open/closed shutter mixing and extended per AR-01, preserved flue outlet contracts, and surface_variety reduced to a wear/stem selector | allowed files: per docs/tasks/architecture/AR-06_burgher_tier_expansion.md | verify: `--filter=test_burgher_house_models,test_window_facades,test_architecture_kit,test_save`; full Godot suite; blueprint validate; verify_building_variety reporting 43 distinct configurations and no identical adjacent pair; asset sources/lint/storage; map audit, activation, composition; active docs; pre-commit all; door and window head heights inside the AR-01 band on every plot with no whole-assembly non-uniform scale; roof pitch matching the assigned cover; every facade GLB referenced by the catalogue; bit-identical walkability; demo route menu->Lower Town->forge->Mart->anvil still completes and a pre-change save loads unchanged; empty `git diff --stat content/maps/`; matched before/after Pikk/Vene/Saiakang/market plates plus a contiguous-run variety plate and a shutter close-up at noon and midnight on Compatibility and Metal at both tiers; frame/draw-call/material/triangle budget; named human review that the shipped street reads as a Hanseatic Lower Town
```
