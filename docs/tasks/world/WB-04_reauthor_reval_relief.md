# WB-04: Re-author Toompea, the Lower Town and the Viru foreland with real relief

Board row: **R-976**. Priority: high. Depends on: **R-975**.

## Player-facing goal

Toompea reads as the limestone hill it is. From the Lower Town the player looks **up** at the
castle; from Toompea the town roofs are below. The walk between them climbs a real slope. Lower
Town streets fall toward the wet northern harbour margin instead of sitting on one plane, and the
ground outside the Viru gate is banked and ditched rather than a flat meadow.

## Why this is needed

Current authored relief, from the statement census:

| Map | Elevation statements | Authored intent |
|---|---|---|
| `toompea_quarter` | 4 | `elevation=2.8` units, about **2.4 m**, for a hill of roughly 20-30 m |
| `archbishops_garden` | 4 | `elevation=2.8` units, same plateau |
| `lower_town_slice` | 4 | three of them explicitly pin the datum to **0.0**; one ramp of 0.20 |
| `viru_gate_foreland` | **0** | none |
| `south_quarter`, `north_quarter`, `market_civic_quarter`, `monastery_quarter` | 4-5 each | plateaus |

`lower_town_slice.rrmap` says so in its own comments: "keep the ordinary Lower Town plane flat",
"keep both authored road spines on the readable zero plane". That was the correct decision while
relief was a view-only decal that navigation ignored. After R-975 it is no longer correct.

Evidence for the target profile is already in `docs/HISTORICAL_AUDIT.md`: H01 (high limestone hill,
Upper/Lower Town distinction), H12 (Toompea quarry cuts and level changes), H11 (Great Coastal Gate
on a sandstone cliff **5-8 m above** historical harbour ground), H08 (low and wet northern and
south-eastern ground, moats and water management), H10 (Karja Gate coastal-lowland relief).

## Deliverable

1. **A documented Reval relief datum** in `docs/MAP_AUTHORING.md`: one shared zero, the height of
   each district plateau in metres and world units, and the required slope length for each
   escarpment so it reads as a climb and not a wall. Toompea's crest sits at the ADR-approved
   height over the Lower Town datum; the harbour margin sits below it, consistent with H11's 5-8 m.
2. **`toompea_quarter` and `archbishops_garden`** re-authored on that datum with a `relief_ridge`
   escarpment, `relief_cliff` where the rock face is genuinely impassable, `relief_terrace` for the
   quarry-cut levels attested in H12, and at least two authored ascent routes.
3. **`lower_town_slice`** re-authored with a bounded fall toward the wet northern margin, a
   `relief_ditch` where the drainage attested in H11 and H08 runs, and `relief_noise` on open ground
   so no street is a perfect plane. Both authored road spines stay walkable and readable.
4. **`viru_gate_foreland`** gets its first relief: the approach bank, the ditch outside the wall,
   and the foreland's fall away from the gate.
5. **Seam continuity.** Every physical transition edge matches its reciprocal map's height within
   the R-974 `MAP_RELIEF_SEAM` tolerance, including the inactive neighbours, so R-980 can stream
   across them without a step.

## Allowed files

`content/maps/toompea_quarter.rrmap`, `content/maps/archbishops_garden.rrmap`,
`content/maps/lower_town_slice.rrmap`, `content/maps/viru_gate_foreland.rrmap`,
`content/maps/south_quarter.rrmap`, `content/maps/north_quarter.rrmap`,
`content/maps/market_civic_quarter.rrmap`, `content/maps/monastery_quarter.rrmap`,
matching `.uid` sidecars, `docs/data/map_composition_thresholds.json`,
`tests/godot/test_reval_relief_datum.gd` and its `.uid`, `docs/MAP_AUTHORING.md`,
`docs/HISTORICAL_AUDIT.md`, `docs/reports/reval_relief_2026-09-26.md`,
`docs/reports/images/reval_relief/`, `docs/tasks/world/WB-04_reauthor_reval_relief.md`, `TODO.md`.

## Constraints and non-goals

Preserve **every** stable ID: map, transition, spawn, anchor, patrol, prop, structure, landmark,
prefab instance and prefab-local, and all existing `r454.*` elevation profile IDs, which are reused
rather than renamed. Do not resize any map - that is a separate ADR-gated decision, as in R-950.
Do not touch the coastal maps; **R-951** owns `reval_harbor_east`, `reval_harbor_north` and
`world.saaremaa`, and this row must not contradict its ladder. No new buildings or props here.

## Verification

- `godot --headless --path . --script tools/validate_map_blueprints.gd` with zero `error`
  diagnostics and an explicit written decision for every `MAP_RELIEF_SLOPE` and
  `MAP_GEOMETRY_OVERLAP` warning.
- `godot --headless --path . --script tools/run_godot_tests.gd` with `test_reval_relief_datum.gd`
  asserting: Toompea crest minus Lower Town datum is within the ADR band; the harbour margin is
  below the Lower Town datum; every transition edge matches its reciprocal within tolerance; no
  authored step exceeds the R-975 slope maximum outside a declared `relief_cliff`.
- **Full stable-ID census green** against the pre-change baseline for all eight maps.
- Walkable-cell count and largest walkable region per map recorded before and after; any loss must
  be justified line by line in the report, and no transition, spawn or anchor cell may be lost.
- `python3 tools/verify_map_audit.py`, `verify_map_activation.py`, `verify_map_conversion_plan.py`,
  `verify_map_composition.py`, `python3 tools/generate_active_docs_report.py --check`
- Captures on GL Compatibility and Metal: a top-down relief overlay per map before and after; a
  Lower Town street plate looking up at Toompea; a Toompea plate looking down over the town roofs;
  a walk clip of one full ascent and one descent.
- `tools/run_performance_report.sh --quick` inside budget.

## Doc updates

`docs/MAP_AUTHORING.md` gains the Reval relief datum table. `docs/HISTORICAL_AUDIT.md` records the
chosen Toompea height with its confidence label and its H01/H11/H12 basis.
