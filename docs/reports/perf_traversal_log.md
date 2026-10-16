# Performance and traversal coverage ledger

Status: QA coverage ledger for active Reval locations and travel destinations. Updated 2026-10-16.

Metrics are recorded only when the named place is actually measured. `not measured` is not a pass. Headless benchmark frame times are wall-clock instrumentation and are not rendered FPS. A full player traversal requires the player route tool or an equivalent deterministic end-to-end test; manifest/validator checks alone do not count as a walk.

## Coverage grid

`Last perf` and `Last traversal` are separate. Locations are keyed by stable manifest/district/site IDs. The active destination set comes from `content/transitions/active_destinations.json`; city districts and landmark sites come from `content/world/reval_city/plan.json` and `content/world/reval_city/sites/registry.json`. Interior rooms must be added as distinct rows when they have independent player entry/routes; the six city landmark sites below are listed individually but no room-level walk was completed in this run.

| Place ID | Region / map type | Last perf check | Last traversal check | avg / p1 frame time | Peak memory | Nodes / collisions | Hitches / open tasks |
|---|---|---|---|---|---|---|---|
| `forge` | Reval / smithy interior | 2026-10-16 (headless, load-contaminated) | never | median 8.9 / p95 32.5 ms (2026-10-11: p95 8.4; host load ~30) | +222.9 MiB (was +231.4) | 1,909 / 46 | No route walk; R-1687 |
| `reval_city` | Reval / continuous city | 2026-10-16 (headless, load-contaminated) | 2026-10-16 (4 street routes pass; house-door step is a stale harness, R-2178) | median 106.9 / p95 390.9 ms (host load ~30; 2026-10-11: p95 90.2) | +1,899.5 MiB (was +1,521.9) | 37,528 / 17,771 (was 31,294 / 15,216) | startup 71.3 s; R-1686, R-1687, R-2178 |
| `world_sacred_grove` | Harju / sacred grove site | 2026-10-16 (headless) | 2026-10-16 (3 spawns, 3/3 roads) | median 12.4 / p95 59.1 ms (load-contaminated) | +640 MiB | 2,750 / 39 | R-2177 |
| `world_harju` | Harju / hinterland site | 2026-10-16 (headless) | 2026-10-16 (6 spawns, 7/7 roads) | median 12.4 / p95 57.6 ms (load-contaminated) | +664 MiB | 2,520 / 447 | R-2177, R-1593 |
| `world_padise` | Lääne / monastery site | 2026-10-16 (headless) | 2026-10-16 (3 spawns, 5/6 roads) | median 10.2 / p95 53.8 ms (load-contaminated) | +684 MiB | 2,181 / 42 | R-2177, R-2176 (road.grange) |
| `world_saaremaa` | Saaremaa / island site | 2026-10-16 (headless) | 2026-10-16 (4 spawns, 3/3 roads; 5x reload flat) | median 11.9 / p95 60.9 ms (load-contaminated) | +625 MiB | 1,827 / 31 | R-2177 |
| `world_rebel_kings` | Harju / hinterland site | 2026-10-16 (headless) | 2026-10-16 (3 spawns, 2/5 roads) | median 18.3 / p95 75.9 ms (load-contaminated) | +622 MiB | 2,681 / 75 | R-2177, R-2176 (kanavere, lanes, stockade) |
| `world_kanavere` | Harju / village travel map | 2026-10-16 (load only, headless) | 2026-10-16 (load + spawn free in 3-4/4 dirs; no walk) | not measured (load 2005 ms) | not measured | 1006 / n.a. | R-1687 |
| `world_sojamae` | Harju / village travel map | 2026-10-16 (load only, headless) | 2026-10-16 (load + spawn free in 3-4/4 dirs; no walk) | not measured (load 1884 ms) | not measured | 992 / n.a. | R-1687 |
| `world_paide` | Järva / town site | 2026-10-16 (headless) | 2026-10-16 (4 spawns, 5/6 roads) | median 15.5 / p95 74.1 ms (load-contaminated) | +656 MiB | 2,147 / 106 | R-2177, R-2176 (road.east) |
| `world_parnu` | Pärnu / travel map | 2026-10-16 (load only, headless) | 2026-10-16 (load + spawn free in 3-4/4 dirs; no walk) | not measured (load 1715 ms) | not measured | 1057 / n.a. | R-1687 |
| `world_poide` | Saaremaa / travel map | 2026-10-16 (load only, headless) | 2026-10-16 (load + spawn free in 3-4/4 dirs; no walk) | not measured (load 1673 ms) | not measured | 1124 / n.a. | R-1687 |
| `world_rakvere` | Virumaa / travel map | 2026-10-16 (load only, headless) | 2026-10-16 (load + spawn free in 3-4/4 dirs; no walk) | not measured (load 1753 ms) | not measured | 1098 / n.a. | R-1687 |
| `world_haapsalu` | Lääne / travel map | 2026-10-16 (load only, headless) | 2026-10-16 (load + spawn free in 3-4/4 dirs; no walk) | not measured (load 1841 ms) | not measured | 1098 / n.a. | R-1687 |
| `world_lihula` | Lääne / travel map | 2026-10-16 (load only, headless) | 2026-10-16 (load + spawn free in 3-4/4 dirs; no walk) | not measured (load 1770 ms) | not measured | 1105 / n.a. | R-1687 |
| `world_tartu` | Ugandi / travel map | 2026-10-16 (load only, headless) | 2026-10-16 (load + spawn free in 3-4/4 dirs; no walk) | not measured (load 1823 ms) | not measured | 1101 / n.a. | R-1687 |
| `world_viljandi` | Sakala / travel map | 2026-10-16 (load only, headless) | 2026-10-16 (load + spawn free in 3-4/4 dirs; no walk) | not measured (load 1752 ms) | not measured | 1112 / n.a. | R-1687 |
| `world_poltsamaa` | Järva / travel map | 2026-10-16 (load only, headless) | 2026-10-16 (load + spawn free in 3-4/4 dirs; no walk) | not measured (load 1744 ms) | not measured | 1105 / n.a. | R-1687 |
| `world_narva` | Virumaa / travel map | 2026-10-16 (load only, headless) | 2026-10-16 (load + spawn free in 3-4/4 dirs; no walk) | not measured (load 1682 ms) | not measured | 1091 / n.a. | R-1687 |
| `world_karksi` | Sakala / travel map | 2026-10-16 (load only, headless) | 2026-10-16 (load + spawn free in 3-4/4 dirs; no walk) | not measured (load 1670 ms) | not measured | 1105 / n.a. | R-1687 |
| `world_helme` | Ugandi / travel map | 2026-10-16 (load only, headless) | 2026-10-16 (load + spawn free in 3-4/4 dirs; no walk) | not measured (load 1735 ms) | not measured | 1098 / n.a. | R-1687 |
| `world_maasilinna` | Saaremaa / travel map | 2026-10-16 (load only, headless) | 2026-10-16 (load + spawn free in 3-4/4 dirs; no walk) | not measured (load 1674 ms) | not measured | 1098 / n.a. | R-1687 |
| `world_karja` | Saaremaa / travel map | 2026-10-16 (load only, headless) | 2026-10-16 (load + spawn free in 3-4/4 dirs; no walk) | not measured (load 1683 ms) | not measured | 1091 / n.a. | R-1687 |
| `world_klint` | Harju / coastal travel map | 2026-10-16 (load only, headless) | 2026-10-16 (load + spawn free in 3-4/4 dirs; no walk) | not measured (load 1708 ms) | not measured | 1003 / n.a. | R-1687 |
| `world_soomaa` | Sakala / wetland travel map | 2026-10-16 (load only, headless) | 2026-10-16 (load + spawn free in 3-4/4 dirs; no walk) | not measured (load 1742 ms) | not measured | 1009 / n.a. | R-1687 |
| `world_frontier_ugandi` | Ugandi / frontier travel map | 2026-10-16 (load only, headless) | 2026-10-16 (load + spawn free in 3-4/4 dirs; no walk) | not measured (load 12646 ms) | not measured | 1032 / n.a. | R-1687 |
| `district.toompea` | Reval / upper town and castle | never | 2026-10-16 (street route luhike_jalg_up 25/25 (Lühike jalg), rendered walk) | not measured | not measured | not measured | R-1687; see historical ledger |
| `district.lower_town` | Reval / lower town | never | 2026-10-16 (street route pikk_jalg_up 44/44 (Pikk jalg), rendered walk) | not measured | not measured | not measured | R-1687; see historical ledger |
| `district.kalarand` | Reval / harbour shoreline | never | 2026-10-16 (street route pikk_to_harbour 111/111 (to the Coastal Gate), rendered walk) | not measured | not measured | not measured | R-1687; see historical ledger |
| `district.viru` | Reval / gate and road suburb | never | 2026-10-16 (street route viru_inward 32/32, rendered walk) | not measured | not measured | not measured | R-1687; see historical ledger |
| `district.karja` | Reval / farmsteads and road | never | 2026-10-10 (historical walk, not traversal QA) | not measured | not measured | not measured | R-1687; see historical ledger |
| `district.harju` | Reval / road and houses | never | 2026-10-10 (historical walk, not traversal QA) | not measured | not measured | not measured | R-1687; see historical ledger |
| `district.toompea_foot` | Reval / castle-foot yards | never | 2026-10-09 (historical walk, not traversal QA) | not measured | not measured | not measured | R-1687; see historical ledger |
| `site.raekoja_plats` | Reval / Town Hall square | never | 2026-10-10 (historical walk, not traversal QA) | not measured | not measured | not measured | R-1687; see historical ledger |
| `site.holy_spirit` | Reval / church and almshouse | never | 2026-10-15 (site-door traversal; not interregional) | not measured | not measured | not measured | R-1687; performance still unmeasured |
| `site.st_olaf` | Reval / church | never | 2026-10-15 (site-door traversal; not interregional) | not measured | not measured | not measured | R-1687; performance still unmeasured |
| `site.st_nicholas` | Reval / church | never | never | not measured | not measured | not measured | R-1687 |
| `site.st_mary` | Reval / Dome church building site | never | 2026-10-11 (historical walk, not traversal QA) | not measured | not measured | not measured | R-1687; see historical ledger |
| `site.kalev_smithy` | Reval / smithy site | never | never | not measured | not measured | not measured | R-1687 |

Coverage count (2026-10-16): 7/39 places have a completed performance-and-traversal check: the six hinterland sites (`world_sacred_grove`, `world_harju`, `world_padise`, `world_saaremaa`, `world_rebel_kings`, `world_paide`; headless perf plus spawn and full-road traversal) and `reval_city` (perf plus four street routes). 18 global-map travel scenes were loaded and spawn-checked only (counted as partial, 0 points). `forge` has perf only; four city districts have a street-route walk (pass) but no per-district perf; `site.st_nicholas`, `site.kalev_smithy` and the remaining districts are still uncovered. Coverage percentage 7/39 = 18% (26 manifest scenes + 13 city areas; not every enterable interior room is enumerated).

## Run log

### 2026-10-11 - initial headless baseline and verification preflight

- Commit: `d6b5ffd3f8531aa2e222748ca6ed55180bbcf5e7` (local main; checkout was ahead 21 / behind 7 vs origin/main at start).
- Machine: macOS, Apple M5 Pro, 18 logical processors, Godot 4.7.1 official. Performance command used headless instrumentation; renderer in report is `mobile` / `metal`, but no pixels were drawn.
- Candidate places selected for this run under the oldest/never-visited rule: `reval_city`, `world_harju`, `world_rakvere`, and `world_sacred_grove` (different map types/regions), plus recent-commit location `reval_city` (recent city weather/vegetation/performance edits). Due to test harness/environment limitations, only `reval_city` and `forge` were actually measured; no world destination was loaded for route testing.
- Quick baseline: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot tools/run_performance_report.sh build/benchmarks/perf-traversal-2026-10-11.json --quick` (exit 0, 58.7 s). Report is ignored under `build/`, not committed.
  - `reval_city_scene`: p95 90.218 ms (budget 16.67; +73.548 ms / 5.41x); 31,294 nodes (budget 7,500; +23,794 / 4.17x); 15,216 collisions (budget 900; +14,316 / 16.91x); memory +1,521.90 MiB (budget 280; +1,241.90 / 5.44x); 28 actors.
  - `kalev_smithy_scene`: p95 8.445 ms (budget 16.67); 1,844 nodes (budget 7,500); 46 collisions (budget 900); memory +231.43 MiB (budget 280). No previous comparable run is present in this new ledger, so no regression is claimed.
  - Synthetic navigation stress profiles: 128-cell map bake 67.660 ms, 256-cell map bake 3,284.487 ms. Synthetic only, not attributed to any active world place.
- Route checks attempted:
  - `tools/run_map_pipeline_ci.sh routes`: FAIL before tests. It filters for missing `test_lower_town_slice_map`; no current city route test was discovered.
  - `tools/run_map_pipeline_ci.sh seams`: PASS for the seam-continuity harness (11 tests), but the checked-in plan says the `reval_outdoor` group is flag-off/empty; result reports 0 seams. This does not prove city-to-hinterland movement.
  - Correct script-harness invocation `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/run_godot_tests.gd -- --filter=test_world_map_overlay`: FAIL, 14 tests with 24 assertion failures and 4 script errors. Failures include expected distant-map reciprocal door edges absent from current map catalog, stale assertions for retired `reval_east`/`st_olafs_guild_hall` IDs, and null UI controls in click/focus tests. These are automated contract failures, not a completed player route; triage against current transition/content schema before treating as runtime traversal defects.
  - Attempt to pass individual test with `--test` was rejected by official Godot binary: `compiled without support for unit tests`; the project's script harness requires `-- --filter=...`.
  - `tools/build_world_layout.gd -- --check` and `python3 tools/verify_world_layout.py`: PASS/expected-empty status; no world-layout manifest exists because plan declares no `reval_outdoor` members.
  - `verify_map_activation.py` and `verify_map_conversion_plan.py`: PASS. `verify_map_composition.py`: FAIL on pre-existing registry/threshold drift (14 registered regional maps lack threshold cards; 18 threshold cards target retired maps; `lower_town_slice` audit row mismatch). This is not a traversal failure.
- Routes completed: none. Failed/blocked routes: none reproducibly established; the route suite itself is blocked before route execution. City-to-region-and-back, region-to-region travel/load, doors/interiors, district-map click travel and manifest spawn pairs remain untested.
- Screenshot: none. Headless benchmark produced no visual frame; no minimized `godot_render.sh` capture was run because there was no route/session state to capture.
- Defect tasks filed: R-1686 (measured city performance budget exceedance), R-1687 (missing reproducible active-world route coverage/harness).
- Worst observed issue: city scene headless instrumentation p95 90.218 ms, 5.41x the target, alongside 16.91x collision and 5.44x memory budgets. It is a performance-budget defect, not a verified rendered FPS reading.

### 2026-10-16 - hinterland sites, travel maps and street routes

- Commit: `7f03786b7` (main). Machine: macOS, Apple M5 Pro, Godot 4.7.1. The host was heavily loaded by other agents' Godot renders (load average 22-32), so every TIME number below is contaminated and no frame-time regression is claimed; node, collision and memory counts are load-independent.
- Places picked (oldest or never visited, three map types, spread over Harju/Lääne/Saaremaa/Järva): `world_sacred_grove`, `world_padise`, `world_paide`, `world_saaremaa`, plus `world_harju` and `world_rebel_kings`, all 18 `world_travel` scenes, and the recent-commit place `reval_city` (citizen wardrobe, surcoats). Last run's places (`reval_city`, `forge`) were measured again only as the quick baseline.
- Quick baseline (`tools/run_performance_report.sh build/benchmarks/perf-traversal-2026-10-16.json --quick`): `reval_city_scene` nodes 31,294 -> 37,528 (+19.9%), collisions 15,216 -> 17,771 (+16.8%), memory 1,521.9 -> 1,899.5 MiB (+24.8%), startup 71.3 s; p95 390.9 ms vs 90.2 ms on 2026-10-11 but host load makes this unusable; `kalev_smithy_scene` p95 32.5 vs 8.4 ms (same caveat), memory 222.9 vs 231.4 MiB, nodes 1,909 vs 1,844. Assembly trace: kalev_smithy staged 49 frames, max 23.0 ms, 5 units over the 4 ms budget.
- Site perf (`scene_benchmark.tscn --scene=...`, headless, 120 frames): see grid. Memory +622 to +684 MiB per site against a 280 MiB budget (2.2-2.4x) with only 1.8k-2.8k nodes; every site shows one 1.0-1.5 s frame (probably load, re-check on an idle host). Filed R-2177.
- Traversal tool (new): `tools/verify_site_traversal.tscn`. Spawns: 23/23 pass. Roads: 18/23 pass. FAIL: `padise.road.grange` (106.3, -47.0, crosses `padise.bldg.barn`, `padise.bldg.granary`), `paide.road.east` (31.3, -45.5, start next to `paide.bldg.north_wing`), `rebel_kings.road.kanavere` (40.5, -75.5, inside `rebel_kings.bldg.smithy`), `rebel_kings.road.lanes` (-67.2, -152.0, fire `rebel_kings.poi.fire.02` and five shelters), `rebel_kings.road.stockade` (-61.5, -75.2, `rebel_kings.poi.council_fire`). Filed R-2176.
- Travel maps: 18/18 load and the player starts free (poide has 3 of 4 free directions, the rest 4). Load 1.7-2.0 s; the first one 12.6 s (cold cache).
- Repeated transition: `--leak=5 --site=saaremaa` static memory 695.8, 710.9, 710.9, 711.0, 711.0 MiB: no leak.
- City walk (`tools/capture_reval_city_walk.gd` via a temporary host scene with `OUTPUT_DIR` redirected to `build/qa/city_walk_2026-10-16/`): all four routes pass; landmark-site door traversal passes for the sites it walks (Holy Spirit, St Olaf, St Catherine and the others it reaches). Overall `WALK RESULT: FAIL (3)`, all three from stale harness assertions (NPC container count, house door without a click), filed R-2178. Rendered ms per frame 73-113 on a loaded host.
- Not covered: city <-> region transitions (travel map click-to-travel, DoorNavigator), region <-> region chains, city interiors outside landmark sites, per-district perf.
- Evidence: `build/qa/pt1016/*.json|log` and `build/qa/city_walk_2026-10-16/` (ignored, local).
- Tasks filed: R-2176 (site roads blocked), R-2177 (site memory), R-2178 (stale harness); evidence added to R-1686 and R-1687.
- Worst problem: reval_city static memory +1,899.5 MiB (6.8x budget, +24.8% since 2026-10-11) with a 71 s cold startup.

### 2026-10-15 - site-door traversal: Holy Spirit and St Olaf

- Command: the checked-in `tools/capture_reval_city_walk.gd` site-door harness was run through a temporary, untracked host scene with only `OUTPUT_DIR` redirected into `build/qa/city_walk_2026-10-15/`, preserving all previously accepted screenshots. Equivalent checked-in invocation: `tools/godot_render.sh --resolution 1600x900 res://tools/capture_reval_city_walk.tscn -- --only-sites --site=site.holy_spirit --site=site.st_olaf`.
- Result: `WALK RESULT: PASS`; `godot_render.sh` exit 0. Five exterior-door routes completed and returned outside without harness failures: `door.holy_spirit.north` -> `room.nave`, `door.holy_spirit.south` -> `room.nave`, `door.holy_spirit.almshouse` -> `room.almshouse`, `door.st_olaf.west` -> `room.tower`, and `door.st_olaf.south` -> `room.nave`. The log reports each door open and each roof lifted. Per-door walk time was 0.50-0.67 s; waits for door opening were 0.00-0.43 s. These are harness movement timings, not rendered-FPS or scene-performance measurements.
- Scope: this is local site entrance/interior traversal only. It does not cover any city-to-region or interregional route and does not resolve the route-suite filter failure recorded above. `R-1687` remains open.
- Evidence: nine screenshots and the full console log are present locally under ignored `build/qa/city_walk_2026-10-15/`; no existing image in `docs/reports/images/city/` was overwritten. Screenshots are local verification artifacts, not committed files.
- Renderer caveat: despite the route harness passing, the capture emitted repeated `Too many instances using shader instance variables` and `global_shader_uniforms.instance_buffer_pos` errors, followed by renderer/resource cleanup leaks (20 ObjectDB instances, 9 resources, one particle shader, and shader/camera RIDs). Treat this as route-pass-with-renderer-errors, not a clean renderer verification; visual/resource behavior needs separate follow-up.

## Uncovered places

Never covered by the combined gate: `forge` (no traversal), `site.st_nicholas`, `site.kalev_smithy`, `site.raekoja_plats`, `site.st_mary`, the districts `district.karja`, `district.harju`, `district.toompea_foot` (no street-route walk; perf unmeasured for all districts), and the 18 global-map scenes (only load and spawn). City interiors outside landmark sites and the city <-> region and region <-> region transitions are untested.

## Reproduction references

- Site traversal: `godot --headless --path . res://tools/verify_site_traversal.tscn -- [--site=paide] [--travel] [--leak=5]` (see docs/SYSTEMS/REGIONAL_SITES.md)
- Site perf: `godot --headless --path . res://tools/benchmarks/scene_benchmark.tscn -- --scene=res://scenes/world/sites/<site>.tscn --profile-id=world_<site> --output=build/qa/<site>.json`

- Quick baseline: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot tools/run_performance_report.sh build/benchmarks/perf-traversal-2026-10-11.json --quick`
- Route smoke: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot tools/run_map_pipeline_ci.sh routes`
- Seam smoke: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot tools/run_map_pipeline_ci.sh seams`
- Layout, activation and conversion checks: `godot --headless --path . --script tools/build_world_layout.gd -- --check`; `python3 tools/verify_world_layout.py`; `python3 tools/verify_map_activation.py`; `python3 tools/verify_map_conversion_plan.py`

Do not treat a passing manifest validator or seam fixture as proof that a player can traverse a route. Record stable spawn/door/prop IDs and coordinates only after an actual deterministic route reproduction.

<!-- docs-index:start (generated by tools/docs_index.py; do not edit) -->
<!-- docs-index:end -->
