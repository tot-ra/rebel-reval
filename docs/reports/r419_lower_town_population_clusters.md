# R-419 Lower Town population cluster captures

Evidence-only GPU captures for readable deterministic population clusters on the production Lower Town map.
The capture tool does not mutate `GameState`, the rrmap source, or runtime actor ownership.

## Acceptance

- Source map: `res://content/maps/lower_town_slice.rrmap`
- Viewport: 1280 x 720 PNG per scenario
- Renderer capacity: 64; profile actors remain logically registered and are placed only on walkable cells.
- Placement is deterministic from each profile's date, phase, and seed; building, water, prop, and actor clearances are checked before capture.

| Scenario | Profile | Civilians | Watch | Active | Capacity | Capture |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| Ordinary day | `day` | 18 | 3 | 21 | 64 | [day](images/population/lower_town_population_day.png) |
| Market day | `market_day` | 28 | 5 | 33 | 64 | [market_day](images/population/lower_town_population_market_day.png) |
| Night checkpoint | `night` | 6 | 6 | 12 | 64 | [night_checkpoint](images/population/lower_town_population_night_checkpoint.png) |

## Reproduction

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --editor --headless --import
/Applications/Godot.app/Contents/MacOS/Godot --path . --rendering-method mobile --rendering-driver metal --script tools/capture_lower_town_population.gd
```

The second command requires a rendering-capable session. The JSON manifest records the exact profile inputs and output dimensions.
