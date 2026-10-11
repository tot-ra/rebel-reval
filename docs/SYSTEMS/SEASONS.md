# Seasons

Status: partial (core **SeasonState** implemented; presentation tasks planned, [ADR 0045](../adr/0045-seasons.md)). Scope: the yearly cycle on top of day/night: climate, snow, ice, vegetation looks, sky, sea, clothing, smoke, movement. Out of scope: seasonal quests or economy effects (separate task and ADR if wanted).

## Player-facing behavior (target)

- Spring: buds, blossom, melt, mud and puddles. Summer: full leaf, fruit, short nights. Autumn: yellowing crowns, falling leaves that drift in wind and lie under trees. Winter: bare trees, grey straw-coloured grass, snow, ice, long nights.
- Snow falls slowly (fine), fast (heavy) or in large flakes. It settles on ground and roofs, grows icicles under eaves in the cold, and melts by itself when it warms.
- Puddles freeze in winter, then ponds, the moat and rivers, last the sea shore.
- Deep snow slows walking; over 0.5 m only roads are passable. Footprints stay for a while, like the mud trail logic.
- Citizens dress for the season. Chimneys smoke more in winter.
- The date and time are shown beside the map (already present); a debug control forces the date and season.

## Runtime entry points

| Piece | File | Status |
|---|---|---|
| `SeasonState` (pure climate by date) | `scripts/global/season_state.gd` | implemented (test `tests/godot/test_season_state.gd`) |
| Calendar, sun path | `scripts/global/game_calendar.gd`, `scripts/map/view3d/sky_astronomy.gd` | existing: the sun already follows the date |
| Crown phenology, falling leaves | `vegetation_phenology.gd`, `tree_leaf_fall_3d.gd` | existing |

`SeasonState.snapshot(date)` returns: `season`, `weights`, `temperature_c`, `snow_cover_target_m`, `snow_share`, `ice_puddle|fresh|sea`, `heating_demand`, `clothing_warmth`. Climate is a Tallinn-normals sinusoid (coldest day 30 at about -4 C, warmest day 212 at about +17 C).

## Task plan

| # | Task | Notes |
|---|---|---|
| 1 | Core `SeasonState` | done |
| 2 | Debug season/date control | done: `[` `]` step a day (Shift: 30 days), `F5`..`F8` jump to winter/spring/summer/autumn; clock speed already on the existing ladder |
| 3 | Snowfall weather | three looks, GPU particles, shared with rain budget |
| 4 | Ground snow, roof snow, icicles, melt | shader `snow_depth` uniforms, thaw by temperature |
| 5 | Movement in snow and footprints | extends the mud trail |
| 6 | Ice on puddles, ponds, moat, rivers, shore | |
| 7 | Vegetation seasons: blossom, fruit, wither, grass, litter under trees | extends phenology |
| 8 | Sky, clouds, sea per season | |
| 9 | Citizen winter/summer wardrobe | `clothing_warmth` |
| 10 | Chimney smoke by `heating_demand`; wall weathering; save; docs | |

Every visual task must record High (25 fps) and Medium (30 fps) results from the F3 monitor.

## Debug controls

- **Debug overlay (mouse).** Open the quick menu and press **Debug**. The panel has a **Date and Season** block: the current date, season and mean temperature, buttons `-30d`, `-1d`, `+1d`, `+30d`, and `Winter`, `Spring`, `Summer`, `Autumn` that jump forward to 15 Jan, 21 Apr, 15 Jul and 15 Oct. Clock speed and pause are in the **Time Controls** block above it.
- **Keys (3D runtime).** `[` / `]` step a day back / forward (Shift: 30 days); `F5` winter, `F6` spring, `F7` summer, `F8` autumn.
- Elapsed campaign days never go negative, so a step back past the phase's start date wraps to the same calendar day next year (`GameCalendar.days_until`). The sun, HUD date, phenology, farmland and forbs follow through `set_calendar_date`.
- Entry points: `MapViewRuntime.shift_calendar_days`, `jump_to_season`, `calendar_date`; UI in `scripts/ui/debug_overlay.gd`; keys in `map_view_runtime_input.gd`. Test: `tests/godot/test_debug_overlay.gd`.

## Verify

`godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_season_state`

## Limits

Only the core exists; nothing consumes it yet.
