# AR-11: fortification building set

Board row: **R-969**. Priority: high. Depends on: AR-04.

## Player-facing goal

The city wall reads as coursed limestone masonry built by hand: a battered base, visible courses, putlog
holes where the scaffolding stood, a wall-walk with a parapet the player can be on, and towers that are
recognisable Tallinn drums with conical tile roofs. Incomplete 1343 fabric looks incomplete - unfinished
crenellation, a tower with no ground door - rather than looking finished in a different colour. The Viru
gate reads as a gate complex.

## Why this is needed

There are **182 `building ... wall` records** plus 13 `wall_walk_platform` and 6 `wall_walk_access`
primitives across the maps - the single largest architectural population after ordinary houses. All of it
comes from `scripts/map/view3d/map_view_mesh_builder_building_fortification.gd`, 25k of GDScript with
**zero `res://assets` references**, plus `map_view_wall_walk_access_builder.gd` and
`map_wall_walk_access.gd`.

The authored vocabulary is again a tint: `wall.city` (`wall_height=192`), `wall.tower`
(`wall_height=240 round_tower=true`), `wall.limestone`, `wall.precinct`, `wall.rampart`, `wall.castle`,
`wall.rubble`, and heights encoded into style names like `wall.plain.h256.02`. The
`monastery_quarter.rrmap` comment is precise about what the geometry is supposed to convey and cannot:
"round_tower keeps the Tallinn circular drum and conical red-tile roof while tower=false marks incomplete
1343 fabric (no ground door / arrow slits)."

One authored gate GLB already exists and works - `assets/props/architecture/gates/viru_gate.glb` (1.5 MB,
seven material sets) - which proves the bespoke path is viable here. It is the only one.

## Deliverable

A set under `assets/buildings/fortification/`, kit-bashed on AR-04, built to the AR-01 fortification card:

1. **Wall sections** as repeatable modules, not stretched boxes: `wall_section_coursed` with a real
   batter, `wall_section_rubble`, `wall_section_precinct_low`, `wall_section_unfinished`,
   `wall_putlog_band`, `wall_parapet_merlon` (repeatable rhythm), `wall_parapet_unfinished`,
   `wall_corner_return`, `wall_arrow_slit`, `wall_offset_course`.
2. **Towers** - `tower_drum` (the Tallinn circular drum) with `tower_drum_conical_roof` in tile,
   `tower_drum_unfinished` for `tower=false` fabric with no ground door and no arrow slits,
   `tower_square`, `tower_horseshoe`, and the three named towers the maps place:
   `kuldjala_tower`, `nunnatorn_tower`, `rentenitorn_tower`, each recognisable from its neighbours.
3. **Gate works** - `viru_gate_north_tower` and `viru_gate_south_tower` as authored geometry (they are
   currently registry "gatehouse" primitives), `gate_passage_vault`, `gate_machicoulis`,
   `gate_flanking_wall`. The existing `viru_gate.glb` and the three gate-leaf GLBs are folded onto the
   AR-04 module and AR-03 surfaces, not rebuilt.
4. **Wall-walk** - `wall_walk_deck`, `wall_walk_stair`, `wall_walk_ladder`, `wall_walk_hatch`,
   `wall_walk_hoarding`, matching the existing `wall_walk_platform` and `wall_walk_access` primitives
   one-for-one so the 19 records keep working.
5. **Ramparts and earthworks** - `rampart_face`, `ditch_revetment`, `palisade_run` (the maps author
   `primitive=palisade` three times), `hill_barrier` and `hill_gate` for the Toompea barriers.
6. Loader replacement: `map_view_mesh_builder_building_fortification.gd` and
   `map_view_wall_walk_access_builder.gd` consume the AR-04 catalogue. The primitive assembly for replaced
   families is deleted. Every ID and every `round_tower` / `tower` flag semantic in the rrmap sources is
   preserved.
7. `assets/SOURCES.csv` rows citing the AR-01 card and `scripts/map/reval_fortification_registry.gd`.

## Allowed files

- `assets/buildings/fortification/**` (new), `assets/buildings/kit/**` (fortification parts only),
  `assets/props/architecture/gates/**`, `assets/buildings/walls-and-turrets/**`
- `assets/SOURCES.csv`
- `tools/build_fortification_buildings.py` (new), `tools/build_architecture_kit.py`
- `scripts/map/view3d/map_view_mesh_builder_building_fortification.gd` (+ `.uid`)
- `scripts/map/view3d/map_view_wall_walk_access_builder.gd` (+ `.uid`)
- `scripts/map/view3d/map_view_mesh_builder_building_registry.gd` (+ `.uid`)
- `scripts/map/view3d/architecture_kit_catalogue.gd` (+ `.uid`)
- `scripts/map/reval_fortification_registry.gd` (+ `.uid`) - model bindings only
- `tests/godot/test_fortification_buildings.gd` (+ `.uid`, new),
  `tests/godot/test_wall_walk_access.gd` (if present)
- `tools/capture_ar11_fortifications.gd` (+ `.uid`, new), `tools/capture_fortification_realism.gd`
- `docs/ASSET_INVENTORY.md`, `docs/ART_BIBLE.md`,
  `docs/reports/ar11_fortifications.md`, `docs/reports/images/ar11_*.png`, `TODO.md`

## Constraints and non-goals

- Asset freeze P0-040: exactly the files above.
- **No rrmap edits.** All 182 wall records, their heights, their `round_tower` and `tower` flags, and
  every wall-walk access ID stay exactly as authored.
- **Wall-walk traversal must not change.** `map_wall_walk_access.gd` governs whether the player can get up
  and along; this task changes only what the deck and stair look like. Traversal tests must pass unchanged,
  and the deck surface height must match the authored platform height exactly, or the player will float or
  clip.
- Collision and navigation unchanged; walkability bit-identical, including on every wall-walk.
- `tower=false` must remain visually distinct as incomplete fabric. Do not "finish" a tower because the
  finished model looks better.
- No later fortification phases: no Karja barbican composition, no 15th- or 16th-century gun towers, no
  Padise gun towers (AR-08 excludes those too), no Kiek in de Kök. The `docs/HISTORICAL_AUDIT.md` exclusions
  hold.
- No siege, destruction, climbing or wall gameplay. `P4-027f` already owns the tower portfolio check
  (`tools/verify_p4_027f_tower_portfolio.py`); keep it passing.

## Verification

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_fortification_buildings,test_wall_walk_access,test_architecture_kit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/validate_map_blueprints.gd
python3 tools/verify_p4_027f_tower_portfolio.py
python3 tools/validate_asset_sources.py && python3 tools/verify_asset_lint.py && python3 tools/verify_storage_hygiene.py
python3 tools/verify_map_audit.py && python3 tools/verify_map_activation.py && python3 tools/verify_map_composition.py
python3 tools/generate_active_docs_report.py --check
git diff --check
```

- `test_fortification_buildings.gd` asserts: every model loads; all 182 wall records plus the 19
  wall-walk primitives resolve; wall sections tile without a seam along a run and turn a corner without
  interpenetrating; the merlon rhythm is repeated geometry, not a scaled texture; `round_tower=true`
  yields a circular drum with a conical tile roof; `tower=false` yields unfinished fabric with no ground
  door and no arrow slits, and a named assertion that it is geometrically distinguishable from the
  finished variant; `kuldjala_tower`, `nunnatorn_tower` and `rentenitorn_tower` are three distinct
  silhouettes; the wall-walk deck top matches the authored platform height exactly; models within the
  ADR 0022 budget with LODs; no deleted primitive builder is referenced in `scripts/`.
- `test_wall_walk_access.gd` passes unchanged: every authored access route is still traversable and every
  excluded one is still blocked.
- **Gameplay invariance**: per-map walkable cells, largest walkable region and anchor accounting
  bit-identical, with the wall-walk cells called out separately in the report.
- `git diff --stat content/maps/` is empty.
- `tools/capture_ar11_fortifications.gd` through `tools/godot_render.sh`: matched before/after plates of a
  long wall run showing courses and putlog holes, a drum tower, an unfinished tower beside a finished one,
  the Viru gate complex, the three named towers side by side, and a from-the-wall-walk view; plus a
  raking-light plate proving the coursing reads; clear noon, overcast and midnight; Compatibility and
  Metal; both quality tiers. Refresh `tools/capture_fortification_realism.gd` output.
- Performance: the most wall-dense map's frame cost, draw calls, materials and triangles, inside budget.
- **Named human visual review** answering: does the wall read as hand-laid limestone, and is incomplete
  1343 fabric legible as incomplete. Green tests do not close this (P0-209b).

## Doc updates

`docs/ASSET_INVENTORY.md`, `docs/ART_BIBLE.md`, `docs/reports/ar11_fortifications.md`, `TODO.md`.

## TODO.md line

```
- [ ] R-969 | deps: R-962 | deliverable: assets/buildings/fortification set covering repeatable coursed/rubble/precinct/unfinished wall sections with real batter, putlog bands, repeated merlon parapet, corner returns and arrow slits; drum, square and horseshoe towers with conical tile roofs plus an unfinished tower=false variant and distinct Kuldjala, Nunnatorn and Rentenitorn silhouettes; Viru gate towers, passage vault, machicoulis and flanking walls with the existing gate GLBs folded onto the module; wall-walk deck, stair, ladder, hatch and hoarding matching the 19 authored wall_walk primitives; and rampart, ditch revetment, palisade and hill barrier/gate fabric, replacing the asset-free procedural fortification builder | allowed files: per docs/tasks/architecture/AR-11_fortification_set.md | verify: `--filter=test_fortification_buildings,test_wall_walk_access,test_architecture_kit`; full Godot suite; blueprint validate; verify_p4_027f_tower_portfolio; asset sources/lint/storage; map audit, activation, composition; active docs; git diff --check; all 182 wall records and 19 wall-walk primitives resolve; wall sections tile seamlessly and turn corners without interpenetration; merlons are repeated geometry; round_tower=true gives a drum with conical tile roof; named assertion that tower=false is geometrically distinguishable as unfinished with no ground door or arrow slits; three distinct named-tower silhouettes; wall-walk deck top matches the authored platform height exactly and all traversal tests pass unchanged; models within the ADR 0022 budget with LODs; bit-identical walkability with wall-walk cells reported separately; empty `git diff --stat content/maps/`; matched before/after long-wall, drum tower, unfinished-vs-finished, Viru gate complex, three-tower and from-the-wall-walk plates plus a raking-light coursing plate at noon/overcast/midnight on Compatibility and Metal at both tiers; frame/draw-call/material/triangle budget; named human review that the wall reads as hand-laid limestone and incomplete fabric is legible
```
