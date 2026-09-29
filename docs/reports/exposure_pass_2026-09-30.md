# Exposure pass (2026-09-30)

Player report: the game reads too dark and most things are hard to see. Target look:
a daylight RPG town in the spirit of Witcher 3 / KCD2, with readable shade and a
blue but legible night.

## Method

`tools/capture_brightness_tour.gd` renders five production maps (`lower_town_slice`,
`market_civic_quarter`, `north_quarter`, `reval_harbor_east`, `kalev_smithy`) from the
shipped dimetric gameplay camera and from eye level at 08:00, 12:00, 17:00, 20:30 and
00:00, and prints mean/median/p90 sRGB luma per frame:

```bash
tools/godot_render.sh --script tools/capture_brightness_tour.gd -- --label=after [--maps=lower_town_slice]
```

Output goes to `build/brightness_tour/` (not committed).

## Findings

- Noon streets averaged ~50/255 mean luma. AgX compresses highlights, so a 1.2 sun and
  0.85 fill left shade sides near black and colours muddy.
- Outdoor fill took the pure sky hue, painting every shadowed facade blue.
- At 17:00 the sun is ~20 deg high: long shadows cover most streets and the camera sees
  the shade sides, so the frame read as night (17/255).
- Moonless night was ~1/255: only lantern-lit walls showed.
- A day lasts 60 real seconds (`DayNightCycle.CYCLE_DURATION_SECONDS`, dev pacing), so
  players spend a large share of play in dusk and night. Not changed here.

## Changes (`scripts/map/view3d/map_view_lighting.gd`)

| Constant | Before | After |
|---|---|---|
| `SUN_DAY_ENERGY` | 1.2 | 2.2 |
| `AMBIENT_DAY_ENERGY` | 0.85 | 1.7 |
| `AMBIENT_GROUND_BOUNCE_*` | - | warm bounce at weight 0.4 over the sky hue |
| `GRADE_DAY_*` exposure/saturation/contrast/brightness | 0.98/1.20/1.12/1.03 | 1.05/1.08/1.04/1.04 |
| `LOW_SUN_EXPOSURE_*` | - | up to +30% exposure below 35 deg sun, none at night |
| `AMBIENT_NIGHT_COLOR` / `_ENERGY` | 58,74,112 / 0.92 | 76,94,138 / 1.5 |
| `GRADE_NIGHT_*` exposure/saturation/contrast/brightness | 0.90/1.14/1.08/0.89 | 0.94/1.08/1.02/0.92 |
| `INTERIOR_AMBIENT_ENERGY_SCALE` | - | 0.6 (rooms keep near the old fill; hearth stays the accent) |

Night stays more than 20% darker than day (`post_grade_luminance_proxy`).

## Results (gameplay camera, mean luma /255)

| Map | 08:00 | 12:00 | 17:00 | 00:00 |
|---|---|---|---|---|
| lower_town_slice | 51 -> 100 | 48 -> 90 | 17 -> 63 | 1 -> 15 |
| market_civic_quarter | 44 -> 94 | 51 -> 94 | 16 -> 61 | - -> 12 |
| north_quarter | 44 -> 93 | 51 -> 93 | 24 -> 78 | - -> 14 |
| reval_harbor_east | 51 -> 100 | 60 -> 104 | 38 -> 97 | - -> 15 |

Before/after plates: `docs/reports/images/brightness_pass/`.

## Remaining gap to the reference look

Lighting no longer hides the town. What still separates it from Witcher 3 / KCD2 is
content: flat large-scale ground textures, sparse street clutter, simple building
geometry, no AO/GI in GL Compatibility, and blue-reflecting street pebbles.
