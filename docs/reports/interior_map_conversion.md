# Interior and compact urban map conversion report

Recorded: 2026-07-16

## Scope decision

Maintainer approved scope expansion under [ADR 0006](../adr/0006-interior-compact-urban-conversion-scope.md). Production conversion covers Kalev's smithy and the bounded Lower Town exterior. Market civic, guild hall, north quarter, and harbor warehouse ship as `active=false` prototypes.

## Shared primitives

| Module | Role |
|--------|------|
| `scripts/map/interior_map_factory.gd` | Room shells, doorway gaps, anchors, transitions, fade volumes |
| `scripts/map/map_scene_bootstrap.gd` | Scene wiring without legacy TileSets |
| `scripts/map/map_nav_builder.gd` | NavigationRegion2D from walkable terrain |
| `scripts/map/map_verification.gd` | Coverage, reachability, collision parity helpers |

Interior terrain IDs: `ash`, `timber_floor`, `plaster`. Interior prop kinds include furnace, ledger, bed, chest, table, shelf, quench bucket, stairs, stall, and hearth.

## Converted scenes

| Group | Scenes | Scope |
|-------|--------|-------|
| Production | `forge.tscn`, `reval_east.tscn` | `production`, active via existing manifest |
| Prototypes | `reval_center.tscn`, `market.tscn`, `olaf_guild_hall.tscn`, `reval_north.tscn` | `prototype`, inactive |
| Harbor expansion | `harbor/warehouse.tscn` | `prototype`, inactive |

Legacy diamond TileSet layers were removed from converted scenes. Stable spawn and anchor IDs are preserved; forge courtyard exit uses transition id `door_courtyard` with temporary spawn alias `main`.

## Verification

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd
python3 tools/verify_map_conversion_plan.py
python3 tools/verify_map_activation.py
```

Godot headless tests: 76 tests, 0 failures (2026-07-16).

## Remaining work

- P2-020 atomic manifest cutover
- P2-021 visual and gameplay parity captures
- Visual capture harness for prototype inspection scenes (optional follow-up)
