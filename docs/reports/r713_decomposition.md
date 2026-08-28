# R-713 decomposition: unified sky, clouds, atmosphere, and weather

- Parent: **R-713** (priority 0, complexity 5, `in_progress`)
- Decomposition date: 2026-08-28
- Scope: producer/orchestrator breakdown only; no runtime, shader, map, or capture implementation

## Parent summary

R-713 replaces the static or underspecified sky presentation with one coherent atmosphere shared by all exterior maps. Acceptance requires synchronized sun/ambient/fog/exposure/reflections, layered clouds with quality tiers, five weather regimes with controlled transitions, rain/shelter/wet-surface behavior, shared state across adjacent maps, save/load persistence, automated continuity tests, documented performance budgets, and matched visual captures.

The parent task is too large to implement as a single agent session. The first-level board rows **R-732..R-739** remain the integration owners. This report adds second-level **low-complexity** rows (**R-767..R-782**) so each handoff has a single verification command and an explicit owner boundary.

## Current blocker snapshot (2026-08-28)

| Area | Observation | Immediate low-complexity owner |
|---|---|---|
| State contract | [`docs/SKY_WEATHER_STATE_CONTRACT.md`](../SKY_WEATHER_STATE_CONTRACT.md) exists; R-732 body was empty | R-767 |
| Deterministic snapshots | `test_sky_weather_3d` passes 27/27 headless (2026-08-28); R-768 fixed lunar UV assertion; R-769 closed R-733 | R-733 `done`; R-771/R-773/R-776 unblocked |
| Save/load | `test_save_envelope.gd` cannot load because of a duplicate `entry` iterator in one scope | R-770, then R-771/R-772 |
| Transition ownership | R-735 is `done` | no new row |
| Atmosphere/wet sync | R-736 remains `in_progress` at complexity 2 | R-773, R-774, R-775 |
| Quality tiers | R-737 remains `in_progress` at complexity 2 | R-776, R-777, R-778 |
| Adjacent-map captures | Structural packet exists; Metal plates are still `blocked` | R-779, R-780, R-781 |
| Final acceptance | R-739 ledger recommends **BLOCKED** | R-782 after children clear |

External parents that still gate R-739 and must not be duplicated here: **R-714**, **R-715**, **R-726**.

## First-level ownership (unchanged)

| Ref | Complexity | Status | Role |
|---|---|---|---|
| R-732 | 0 | in_progress | Shared state contract |
| R-733 | 2 | done | Deterministic `SkyWeather3D` snapshots |
| R-734 | 2 | in_progress | Save/load persistence |
| R-735 | 2 | done | One environment owner across transitions |
| R-736 | 2 | in_progress | Atmosphere and wet-surface synchronization |
| R-737 | 2 | in_progress | Quality tiers and budgets |
| R-738 | 2 | in_progress | Adjacent-map continuity captures |
| R-739 | 0 | in_progress | Final acceptance and closeout |

## Second-level low-complexity breakdown

### R-732 chain

| Ref | C | Depends on | Deliverable | Verify |
|---|---|---|---|---|
| R-767 | 0 | none | Reconcile `SKY_WEATHER_STATE_CONTRACT.md` with `SkyWeatherState` / `snapshot_state()` / `apply_state()` and close R-732 | `python3 -m unittest tests.python.test_verify_active_docs_report -v` only if links change; `--filter=test_sky_weather_state`; contract doc lists every persisted field present in code |
| R-768 | 0 | none | Fix the failing lunar UV assertion in `test_sky_weather_3d` without changing weather semantics | `--filter=test_sky_weather_3d` all green |
| R-769 | 0 | R-768 | Close R-733: confirm snapshot round-trip and deterministic continuation, then move R-733 to `done` | **done 2026-08-28** - 27/27 `test_sky_weather_3d` green; `test_snapshot_json_round_trip_preserves_full_state` and `test_snapshot_restore_continues_deterministically` pass |

### R-734 chain

| Ref | C | Depends on | Deliverable | Verify |
|---|---|---|---|---|
| R-770 | 0 | none | Rename the inner `entry` iterator in `test_save_envelope.gd` so the suite loads | `--filter=test_save_envelope` discovers tests and passes |
| R-771 | 1 | R-769, R-770 | Persist `SkyWeatherState` through the save envelope / `GameState` path | `--filter=test_save_service` weather round-trip passes |
| R-772 | 0 | R-771 | Close R-734 after save/load evidence is green | `--filter=test_save_envelope` + `--filter=test_save_service`; update R-739 ledger row |

### R-736 chain

| Ref | C | Depends on | Deliverable | Verify |
|---|---|---|---|---|
| R-773 | 1 | R-769 | Consume the typed presentation snapshot in lighting/fog/exposure paths | `--filter=test_sky_weather_3d` presentation snapshot assertions; focused lighting contract if present |
| R-774 | 1 | R-773, R-754 | Keep wet-surface and water reflection inputs aligned with the shared snapshot | `--filter=test_r715_water_weather_sync` and `--filter=test_map_view_3d_runtime` shelter/rain cases |
| R-775 | 0 | R-773 | Regression test proving no one-frame exposure or fog reset during weather transitions | new or extended focused Godot test passes |

### R-737 chain

| Ref | C | Depends on | Deliverable | Verify |
|---|---|---|---|---|
| R-776 | 1 | R-769 | Named minimum/recommended tier constants in `sky_weather_resources.gd` with deterministic equivalence | tier constants documented in code; state digest unchanged across tiers |
| R-777 | 0 | R-776 | Contract test for tier clamping and fallback selection | `--filter=test_sky_weather_3d` tier assertions |
| R-778 | 0 | R-777 | `docs/reports/r713_environment_performance.md` with measured or explicit `BLOCKED` rows | report exists; target hardware separated from measurement host |

### R-738 chain

| Ref | C | Depends on | Deliverable | Verify |
|---|---|---|---|---|
| R-779 | 0 | R-768 | Structural continuity suite loads and passes headless | `--filter=test_r713_sky_weather_continuity` |
| R-780 | 1 | R-779, R-775 | Metal capture for the `lower_town_slice` -> `monastery_quarter` representative handoff | capture helper exits 0; PNGs written under `docs/reports/images/r713_sky_weather/` |
| R-781 | 0 | R-780 | Fail-closed evidence verification for the committed packet | `python3 tools/verify_r713_sky_weather_evidence.py` |

### R-739 closeout

| Ref | C | Depends on | Deliverable | Verify |
|---|---|---|---|---|
| R-782 | 0 | R-767, R-772, R-775, R-778, R-781 | Refresh `r713_sky_weather_acceptance.md`, map every R-713 clause to green evidence or an explicit owner, recommend `done` / `blocked` / `ready for human sign-off` | acceptance report updated; `git diff --check`; no duplicate follow-ups for R-714/R-715/R-726 |

## Execution order

1. **Unblock parsers/tests:** R-768, R-770 (parallel)
2. **Close contract and snapshots:** R-767, R-769
3. **Persistence:** R-771, R-772
4. **Presentation sync:** R-773, R-774, R-775
5. **Performance tiers:** R-776, R-777, R-778
6. **Continuity evidence:** R-779, R-780, R-781
7. **Parent verification:** R-782, then rerun R-739

## Non-goals

- Do not create duplicate rows for R-714 streaming, R-715 water rollout, or R-726 capture matrix work.
- Do not mark R-713 complete from structural tests alone.
- Do not relabel a development-host benchmark as minimum-hardware acceptance.
