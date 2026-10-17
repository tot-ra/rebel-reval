# ADR 0063: Farm calendar and field labour as date-driven presentation

**Reference:** maintainer request 2026-10-17 (session, screenshot of a farm woman walking aimlessly
through a puddled garden strip outside the walls): peasants must do something specific in the fields
(sow, harvest, weed), historically and geographically right for 1343, with real crops and 3D models
where needed; for every crop, what happens to it next, where it is stored and whether it feeds the
animals. Board: epic **R-2246** (FARMWORK). Feature page (planned): [`FARM_WORK.md`](../SYSTEMS/FARM_WORK.md).

## Status

**Proposed (2026-10-17), awaiting maintainer approval.** The decisions below are the agent's
recommended defaults; the calendar content itself waits for the research dossier FW-1 (R-2247).

## Context

- `CityNpcs._stream_field_workers` puts a `Walker` on one furrow line in about half of the spring and
  garden fields near Kalev. No tool, clip, farmstead, hour, weather or crop logic.
- Crop appearance is already a pure function of the date (`CityFarmland.growth` / `tint`, FLORA-2
  R-2133 planned stages); the drying loft load is a pure function of the date (`DryingLoft.sheaf_load`).
- [Farmland](../SYSTEMS/FARMLAND.md) lists harvest economy, property simulation and weather-driven
  agronomy as out of scope, and its realism roadmap puts "labour, last" after the landscape reads
  right. ADR 0008 allows ambient life; it does not allow a farming mechanic without an ADR.

## Decision

1. **Presentation only.** Field work is ambient life: what a crew does, where it stands, the field's
   state, store levels and fodder rounds are pure functions of (Julian date, hour, weather, weekday,
   field id). Nothing is written to `GameState` or saved; a reload shows the same scene.
2. **One farm calendar in content.** `content/world/farm_calendar.json` (schema + validator) lists,
   per crop and land use, ordered task windows with crew roles, tools (`obj.*`), clips and the field
   effect, each with an evidence label from the FW-1 dossier. `FarmCalendar` is a pure lookup. Stable
   task ids `farm.<verb>`.
3. **Fields belong to farmsteads.** The plan build assigns each field, garden and meadow a farmstead
   deterministically; that household is the crew. No ownership, dues or rent are modelled.
4. **A visible work front.** Within a task window a strip shows the day's progress along its long axis
   and the crew stands at the front.
5. **The chain is shown, not simulated.** Sheaves, stooks, loft load, threshing crews, granary bin
   level, hay stacks, root clamps and fodder rounds follow consistent yearly curves so that the same
   date tells the same story in the field, the barn and the byre. No quantities.
6. **No field work on Sundays and feast days, in rain or on waterlogged ground**; households do yard
   chores instead (R-2227).
7. **Evidence first.** No dev or art task starts before FW-1 lands; rows labelled `exclude` are not
   built, `plausible composite` and later analogies are labelled in the docs.
8. **New art is named per task** (FW-5, FW-6, FW-7) with exact files and `assets/SOURCES.csv` rows,
   under the asset freeze P0-040.

## Consequences

- The furrow `Walker` path is replaced by `FieldCrew` (FW-8); FARMLAND.md "Farm hands" and its Limits
  are rewritten then.
- Needs about 16 new labour clips (FW-4) and two prop kits plus a draught team (FW-5..FW-7).
- Rig budget per crew replaces `MAX_FIELD_WORKERS`; perf must be measured near a busy strip block.
- Lifts the FARMLAND.md non-goal "no sowing, hoeing or ploughing animation" once approved.

## Alternatives considered

- **Keep walkers, add tools only.** Cheap, but still aimless: no front, no task, no link to the crop.
- **A farm simulation with yields and stores in GameState.** Out of scope (ADR 0008); adds save data
  and balancing for no player-facing verb.
- **Hand-placed staged scenes per date.** Does not scale to dozens of strips and every date.
