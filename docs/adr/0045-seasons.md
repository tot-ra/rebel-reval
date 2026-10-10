# ADR 0045: Seasons

**Reference:** maintainer request 2026-10-11 (session): the outdoor world must change with the
time of year, not only with the time of day.

Builds on [`docs/SYSTEMS/TIME_AND_PHASES.md`](../SYSTEMS/TIME_AND_PHASES.md) (campaign calendar),
[`LIVING_VEGETATION.md`](../SYSTEMS/LIVING_VEGETATION.md) (phenology, falling leaves) and
[`WEATHER_GROUND.md`](../SYSTEMS/WEATHER_GROUND.md) (rain, puddles, mud). Does not change the
three-act scope of [ADR 0008](0008-three-act-campaign-and-faction-scope.md).

## Status

**Accepted (maintainer-approved, 2026-10-11).** Tasks are defined in
[`docs/SYSTEMS/SEASONS.md`](../SYSTEMS/SEASONS.md). Nothing there is runtime truth until a
task verifies it.

## Context

- `GameCalendar` and `SkyAstronomy` already move the sun along a date-dependent path;
  `VegetationPhenology` already gives crown state per species per day; leaves already fall in autumn;
  farmland, forbs and forest floor read the day of year.
- Missing: snow (fall, ground cover, roofs, icicles, melt), ice, a shared definition of "what
  season is it", seasonal sky/sea/cloud looks, clothing, chimney smoke by cold, snow-dependent
  movement and footprints, and a debug date control.

## Decision

1. One pure function of the date, `SeasonState` (`scripts/global/season_state.gd`), is the single
   source of seasonal truth: temperature, season weights, snow and ice targets, heating demand,
   clothing warmth. No RNG, no saved state of its own.
2. Stateful effects own their state and chase the `SeasonState` target: settled snow depth,
   roof snow, icicle length, ice thickness, footprints. Their state saves with the world state;
   anything derivable from the date does not save.
3. Snowfall is a weather state beside rain with three looks (fine slow, heavy fast, large
   flakes), chosen deterministically by the weather seed. It accumulates on ground and roofs,
   grows icicles under eaves when it is cold, and melts by temperature.
4. Every seasonal visual is a shader parameter or a pooled multimesh/particle change, never new
   per-frame CPU work per object. Budget: 25 fps on High, 30 fps on Medium, measured with the
   F3 performance monitor before and after each visual task.
5. Snow depth slows movement; above 0.5 m only roads (cleared surface) are passable.
6. Debug: the date and season can be forced and the clock sped up from the debug menu.

## Scope removed to pay for it

Equivalent-cost scope frozen until Seasons lands: the unstarted tasks of the visual-fidelity
backlog P0-140..157 (`docs/VISUAL_FIDELITY_PLAN.md`). Seasons reuses their shader, grading and
lighting work where it overlaps.

## Alternatives

- Per-map season scenes (rejected: doubles art, breaks the seamless city).
- Baked seasonal texture sets only (rejected: no gradual snow cover or leaf flush).
- A global event bus for season changes (rejected by AGENTS.md; systems poll `SeasonState`).

## Consequences

- New shader uniforms on ground, roof, wall and water materials; every one needs a High/Medium
  frame-time check.
- Docs and tests per task; `SEASONS.md` is the owning page.
