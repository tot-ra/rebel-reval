# Performance and traversal coverage ledger

Status: QA coverage ledger for active Reval locations and travel destinations. Updated 2026-10-15.

Metrics are recorded only when the named place is actually measured. `not measured` is not a pass. Headless benchmark frame times are wall-clock instrumentation and are not rendered FPS. A full player traversal requires the player route tool or an equivalent deterministic end-to-end test; manifest/validator checks alone do not count as a walk.

## Coverage grid

`Last perf` and `Last traversal` are separate. Locations are keyed by stable manifest/district/site IDs. The active destination set comes from `content/transitions/active_destinations.json`; city districts and landmark sites come from `content/world/reval_city/plan.json` and `content/world/reval_city/sites/registry.json`. Interior rooms must be added as distinct rows when they have independent player entry/routes; the six city landmark sites below are listed individually but no room-level walk was completed in this run.

| Place ID | Region / map type | Last perf check | Last traversal check | avg / p1 frame time | Peak memory | Nodes / collisions | Hitches / open tasks |
|---|---|---|---|---|---|---|---|
| `forge` | Reval / smithy interior | 2026-10-11 | never | p95 8.445 ms / p99 9.733 ms | +231.43 MiB | 1,844 / 46 | No route walk; R-1687 |
| `reval_city` | Reval / continuous city | 2026-10-11 | never | p95 90.218 ms / p99 see raw report | +1,521.90 MiB | 31,294 / 15,216 | p95 exceeds 16.67 ms budget; R-1686, R-1687 |
| `world_sacred_grove` | Harju / sacred grove site | never | never | not measured | not measured | not measured | R-1687 |
| `world_harju` | Harju / hinterland site | never | never | not measured | not measured | not measured | R-1593, R-1687 |
| `world_padise` | Lääne / monastery site | never | never | not measured | not measured | not measured | R-1687 |
| `world_saaremaa` | Saaremaa / island site | never | never | not measured | not measured | not measured | R-1687 |
| `world_rebel_kings` | Harju / hinterland site | never | never | not measured | not measured | not measured | R-1687 |
| `world_kanavere` | Harju / village travel map | never | never | not measured | not measured | not measured | R-1687 |
| `world_sojamae` | Harju / village travel map | never | never | not measured | not measured | not measured | R-1687 |
| `world_paide` | Järva / town site | never | never | not measured | not measured | not measured | R-1687 |
| `world_parnu` | Pärnu / travel map | never | never | not measured | not measured | not measured | R-1687 |
| `world_poide` | Saaremaa / travel map | never | never | not measured | not measured | not measured | R-1687 |
| `world_rakvere` | Virumaa / travel map | never | never | not measured | not measured | not measured | R-1687 |
| `world_haapsalu` | Lääne / travel map | never | never | not measured | not measured | not measured | R-1687 |
| `world_lihula` | Lääne / travel map | never | never | not measured | not measured | not measured | R-1687 |
| `world_tartu` | Ugandi / travel map | never | never | not measured | not measured | not measured | R-1687 |
| `world_viljandi` | Sakala / travel map | never | never | not measured | not measured | not measured | R-1687 |
| `world_poltsamaa` | Järva / travel map | never | never | not measured | not measured | not measured | R-1687 |
| `world_narva` | Virumaa / travel map | never | never | not measured | not measured | not measured | R-1687 |
| `world_karksi` | Sakala / travel map | never | never | not measured | not measured | not measured | R-1687 |
| `world_helme` | Ugandi / travel map | never | never | not measured | not measured | not measured | R-1687 |
| `world_maasilinna` | Saaremaa / travel map | never | never | not measured | not measured | not measured | R-1687 |
| `world_karja` | Saaremaa / travel map | never | never | not measured | not measured | not measured | R-1687 |
| `world_klint` | Harju / coastal travel map | never | never | not measured | not measured | not measured | R-1687 |
| `world_soomaa` | Sakala / wetland travel map | never | never | not measured | not measured | not measured | R-1687 |
| `world_frontier_ugandi` | Ugandi / frontier travel map | never | never | not measured | not measured | not measured | R-1687 |
| `district.toompea` | Reval / upper town and castle | never | 2026-10-09 (historical walk, not traversal QA) | not measured | not measured | not measured | R-1687; see historical ledger |
| `district.lower_town` | Reval / lower town | never | 2026-10-11 (historical walk, not traversal QA) | not measured | not measured | not measured | R-1687; see historical ledger |
| `district.kalarand` | Reval / harbour shoreline | never | 2026-10-09 (historical walk, not traversal QA) | not measured | not measured | not measured | R-1687; see historical ledger |
| `district.viru` | Reval / gate and road suburb | never | 2026-10-09 (historical walk, not traversal QA) | not measured | not measured | not measured | R-1687; see historical ledger |
| `district.karja` | Reval / farmsteads and road | never | 2026-10-10 (historical walk, not traversal QA) | not measured | not measured | not measured | R-1687; see historical ledger |
| `district.harju` | Reval / road and houses | never | 2026-10-10 (historical walk, not traversal QA) | not measured | not measured | not measured | R-1687; see historical ledger |
| `district.toompea_foot` | Reval / castle-foot yards | never | 2026-10-09 (historical walk, not traversal QA) | not measured | not measured | not measured | R-1687; see historical ledger |
| `site.raekoja_plats` | Reval / Town Hall square | never | 2026-10-10 (historical walk, not traversal QA) | not measured | not measured | not measured | R-1687; see historical ledger |
| `site.holy_spirit` | Reval / church and almshouse | never | 2026-10-15 (site-door traversal; not interregional) | not measured | not measured | not measured | R-1687; performance still unmeasured |
| `site.st_olaf` | Reval / church | never | 2026-10-15 (site-door traversal; not interregional) | not measured | not measured | not measured | R-1687; performance still unmeasured |
| `site.st_nicholas` | Reval / church | never | never | not measured | not measured | not measured | R-1687 |
| `site.st_mary` | Reval / Dome church building site | never | 2026-10-11 (historical walk, not traversal QA) | not measured | not measured | not measured | R-1687; see historical ledger |
| `site.kalev_smithy` | Reval / smithy site | never | never | not measured | not measured | not measured | R-1687 |

Coverage count for this initial inventory: 0/39 places have a completed performance-and-traversal QA check. Historical walk dates remain background visits and do not count. On 2026-10-15, the site-door harness completed all five outer-door traversals plus return checks for `site.holy_spirit` and `site.st_olaf`; this is city-site traversal evidence only, not an interregional route. Performance was measured only for `forge` and `reval_city`, and neither has a completed traversal run; Holy Spirit and St Olaf have no performance check. All locations therefore remain uncovered for the combined gate. The active list and 7 districts / 6 sites account for 39 inventory rows (26 manifest scenes + 13 city areas); this is not a claim that every separately enterable interior room has been enumerated. Add interiors and other active map types when their registries are identified.

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

### 2026-10-15 - site-door traversal: Holy Spirit and St Olaf

- Command: the checked-in `tools/capture_reval_city_walk.gd` site-door harness was run through a temporary, untracked host scene with only `OUTPUT_DIR` redirected into `build/qa/city_walk_2026-10-15/`, preserving all previously accepted screenshots. Equivalent checked-in invocation: `tools/godot_render.sh --resolution 1600x900 res://tools/capture_reval_city_walk.tscn -- --only-sites --site=site.holy_spirit --site=site.st_olaf`.
- Result: `WALK RESULT: PASS`; `godot_render.sh` exit 0. Five exterior-door routes completed and returned outside without harness failures: `door.holy_spirit.north` -> `room.nave`, `door.holy_spirit.south` -> `room.nave`, `door.holy_spirit.almshouse` -> `room.almshouse`, `door.st_olaf.west` -> `room.tower`, and `door.st_olaf.south` -> `room.nave`. The log reports each door open and each roof lifted. Per-door walk time was 0.50-0.67 s; waits for door opening were 0.00-0.43 s. These are harness movement timings, not rendered-FPS or scene-performance measurements.
- Scope: this is local site entrance/interior traversal only. It does not cover any city-to-region or interregional route and does not resolve the route-suite filter failure recorded above. `R-1687` remains open.
- Evidence: nine screenshots and the full console log are present locally under ignored `build/qa/city_walk_2026-10-15/`; no existing image in `docs/reports/images/city/` was overwritten. Screenshots are local verification artifacts, not committed files.
- Renderer caveat: despite the route harness passing, the capture emitted repeated `Too many instances using shader instance variables` and `global_shader_uniforms.instance_buffer_pos` errors, followed by renderer/resource cleanup leaks (20 ObjectDB instances, 9 resources, one particle shader, and shader/camera RIDs). Treat this as route-pass-with-renderer-errors, not a clean renderer verification; visual/resource behavior needs separate follow-up.

## Uncovered places

Every place in the coverage grid is uncovered for the combined performance + traversal gate. The only measured scenes are `reval_city` and `forge`, without any completed gameplay route. The 24 other active manifest destinations, seven district regions, and four city sites have no recorded traversal QA; Holy Spirit and St Olaf have site-door traversal only, and none of the city sites have performance measurements. Distinct indoor rooms and active destinations outside the transition manifest are not yet fully inventoried; completing that census is part of R-1687.

## Reproduction references

- Quick baseline: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot tools/run_performance_report.sh build/benchmarks/perf-traversal-2026-10-11.json --quick`
- Route smoke: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot tools/run_map_pipeline_ci.sh routes`
- Seam smoke: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot tools/run_map_pipeline_ci.sh seams`
- Layout, activation and conversion checks: `godot --headless --path . --script tools/build_world_layout.gd -- --check`; `python3 tools/verify_world_layout.py`; `python3 tools/verify_map_activation.py`; `python3 tools/verify_map_conversion_plan.py`

Do not treat a passing manifest validator or seam fixture as proof that a player can traverse a route. Record stable spawn/door/prop IDs and coordinates only after an actual deterministic route reproduction.

<!-- docs-index:start (generated by tools/docs_index.py; do not edit) -->
<!-- docs-index:end -->
