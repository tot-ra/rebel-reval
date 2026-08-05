# R-446 Lower Town population profile captures

Task: **R-446**
Scope: evidence-only readable population profiles for the final urban-population QA gate
Evidence source: `docs/reports/population_clusters_r419.json`

## Acceptance

Three matched GPU captures on the production `lower_town_slice` map show deterministic
profile clusters without mutating `GameState`, rrmap source, or runtime actor ownership.
Each scenario records profile inputs (phase, date, seed) and actor counts in the manifest.

| Scenario | Profile | Civilians | Watch | Zones | Capture |
| --- | --- | ---: | ---: | ---: | --- |
| Ordinary day | `day` | 18 | 3 | 3 | [day](images/population/lower_town_population_day.png) |
| Market day | `market_day` | 28 | 5 | 4 | [market_day](images/population/lower_town_population_market_day.png) |
| Night checkpoint | `night` | 6 | 6 | 3 | [night_checkpoint](images/population/lower_town_population_night_checkpoint.png) |

Readable cluster coverage:

- **Workers / carriers** - `work_yard` and residential spill on day and market-day plates.
- **Merchants / customers** - `market_lane` and `street_frontage` on market-day; street frontage on day.
- **Watch / checkpoint** - `checkpoint` and `safe_interior` on the night plate.

The capture overlay records `profile`, civilian/watch totals, placed actor count, and seed on
each PNG. Placement stays on walkable cells with building, prop, and actor clearances. This
artifact is evidence-only; runtime crowd wiring remains owned by R-409 / R-448.

## Verification

Regenerate captures (Metal rendering required):

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --editor --headless --import
/Applications/Godot.app/Contents/MacOS/Godot --path . --rendering-method mobile --rendering-driver metal --script tools/capture_lower_town_population.gd
```

Contract verifier:

```sh
python3 tools/verify_lower_town_population_profiles.py
python3 -m unittest tests.python.test_verify_lower_town_population_profiles -v
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_urban_population
```

## Result

**Pass** on 2026-08-06 after Metal regeneration, manifest replay checks, and the focused urban
population Godot suites completed with zero failures.
