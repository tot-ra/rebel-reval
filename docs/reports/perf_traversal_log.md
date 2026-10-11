# Performance and traversal coverage ledger

Status: QA coverage ledger for active Reval locations and travel destinations. Updated 2026-10-11.

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
| `site.holy_spirit` | Reval / church and almshouse | never | 2026-10-10 (historical walk, not traversal QA) | not measured | not measured | not measured | R-1687; see historical ledger |
| `site.st_olaf` | Reval / church | never | 2026-10-11 (historical walk, not traversal QA) | not measured | not measured | not measured | R-1687; see historical ledger |
| `site.st_nicholas` | Reval / church | never | never | not measured | not measured | not measured | R-1687 |
| `site.st_mary` | Reval / Dome church building site | never | 2026-10-11 (historical walk, not traversal QA) | not measured | not measured | not measured | R-1687; see historical ledger |
| `site.kalev_smithy` | Reval / smithy site | never | never | not measured | not measured | not measured | R-1687 |

Coverage count for this initial inventory: 0/39 places have a completed performance-and-traversal QA check. The historical walk dates are background visits only and are not credited as traversal QA. Performance was measured only for `forge` and `reval_city`; they have no completed traversal run. All locations therefore remain uncovered for the combined gate. The active list and 7 districts / 6 sites account for 39 inventory rows (26 manifest scenes + 13 city areas); this is not a claim that every separately enterable interior room has been enumerated. Add interiors and other active map types when their registries are identified.

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

## Uncovered places

Every place in the coverage grid is uncovered for the combined performance + traversal gate. The only measured scenes are `reval_city` and `forge`, without any completed gameplay route. The 24 other active manifest destinations, seven district regions and six registered city sites have never had perf/traversal QA in this ledger. Distinct indoor rooms and active destinations outside the transition manifest are not yet fully inventoried; completing that census is part of R-1687.

## Reproduction references

- Quick baseline: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot tools/run_performance_report.sh build/benchmarks/perf-traversal-2026-10-11.json --quick`
- Route smoke: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot tools/run_map_pipeline_ci.sh routes`
- Seam smoke: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot tools/run_map_pipeline_ci.sh seams`
- Layout, activation and conversion checks: `godot --headless --path . --script tools/build_world_layout.gd -- --check`; `python3 tools/verify_world_layout.py`; `python3 tools/verify_map_activation.py`; `python3 tools/verify_map_conversion_plan.py`

Do not treat a passing manifest validator or seam fixture as proof that a player can traverse a route. Record stable spawn/door/prop IDs and coordinates only after an actual deterministic route reproduction.

<!-- docs-index:start (generated by tools/docs_index.py; do not edit) -->
<!-- docs-index:end -->
