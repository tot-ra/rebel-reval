# LIVING_WORLD.md - Daily civilian routines

**Status:** implemented (task **R-1344**, LIFE-1), scope: Lower Town civilian crowd only.
**Out of scope:** named-NPC schedules, interior occupancy, watch routines, tavern/church anchors, per-actor walking between zones (see Limits). Parent epic: LIFE-0 (R-1337).

## What the player sees

The Lower Town crowd follows the in-game clock (`DayNightCycle` progress). Civilians sleep indoors at night (not rendered), leave home at dawn, work or trade by day, drink at the tavern in the evening and go home. On Sunday the morning is church. Occupancy therefore changes over 24 hours.

## Model

`scripts/world/citizen_schedule.gd` (`CitizenSchedule`) is pure and deterministic: `activity_for(occupation, hour, weekday, seed, actor_index)`.

- Activities: `sleep` (hidden), `home`, `work`, `market`, `tavern`, `church`.
- Tables per occupation (`merchant`, `artisan`, `laborer`, `resident`) for workdays and Sunday.
- Each actor shifts its hour by -1..+1 (hash of seed and `actor_index`) so streets do not empty on one tick.
- `zone_for` maps an activity to a `UrbanPopulationPlacement.ZONE_BOUNDS` zone. Off-market weekdays merchants use `street_frontage` instead of `market_lane`.
- `apply_to_plan` reroutes only `civilian` records and drops sleepers; `actor_index`/`actor_id` stay stable. Watch records are untouched.

## Runtime

`UrbanPopulationController` reads `cycle_progress` from the view runtime, folds the hour into its sync key, and applies the schedule after the phase profile is resolved. The `crackdown` profile keeps its fixed layout (curfew overrides habits). Controller state never writes `GameState`. Without a clock (`-1`) the old phase-only crowd is used.

## Verify

`godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_population_schedule` (per-hour activity, determinism, Sunday, zone mapping, 24h occupancy strip). Regression: `--filter=test_urban_population_runtime_integration`.

## Limits

- Tavern and church have no authored anchors in the slice; they map to `street_frontage` and `safe_interior`. Follow-up: real anchors per landmark.
- Positions are re-rolled when the hour changes (actors teleport between hour buckets); walking between zones is not implemented.
- The crowd is capped by the profile counts (`UrbanPopulationProfile.PROFILE_RULES`); the schedule never adds actors.
- The 24h capture strip and the quick performance report were not produced in this task.
