# R-713 unified sky-weather acceptance

- Task: R-739
- Parent: R-713
- Verification date: 2026-08-26
- Verification scope: fail-closed acceptance and closeout only
- Recommendation: **BLOCKED - not ready for human sign-off**

This report is an evidence ledger, not a claim that the unified sky/weather system is complete. It does not repair runtime, map, water, capture, or performance implementation. A green structural contract or an existing development capture is not promoted to final R-713 acceptance.

## Evidence boundary

The repository checkout was already dirty before this verification. No pre-existing changes were reverted or treated as evidence. Godot 4.7 is not installed in the verification environment (`godot` and `godot4` are unavailable), so no GDScript suite is reported as executed here. Python checks were run from the current checkout on 2026-08-26.

Commands run:

| Command | Result | Interpretation |
|---|---|---|
| `python3 -m unittest tests.python.test_verify_world_building_visual_gate -v` | **PASS**, 6 tests | The generic R-716 world-building gate contract and fail-closed fixture behavior are healthy. This does not provide R-713 sky/weather evidence. |
| `python3 tools/generate_world_building_capture_plan.py --output /tmp/r739-capture-plan.json` | **PASS**, 360 jobs generated | The generic capture planner is available. It does not mean the 360 images exist or are accepted. |
| `python3 tools/verify_world_building_visual_gate.py --json` | **FAIL** | The checked-in benchmark remains pending for registry/audit/capture/transition/performance checks, all capture categories, rubrics, and human art review. The failure is retained as evidence, not waived. |
| `python3 -m unittest tests.python.test_verify_weather_audio_clips -v` | **PASS**, 1 test | Weather roof-audio asset contract passes. This is a narrow audio check, not R-713 acceptance. |
| `python3 tools/verify_weather_audio_clips.py` | **PASS**, 1 clip | The committed roof-rain clip is present and verifiable. |
| `git diff --check` | **PASS** for the report and scoped playbook lesson | No whitespace errors in the files changed by this verification. |
| Focused Godot suites (`test_sky_weather_3d`, `test_sky_weather_state`, runtime/transition suites) | **BLOCKED: environment** | Godot 4.7 executable is unavailable in this environment. No pass is inferred from source inspection. |

## Dependency and ownership gate

R-739 depends on R-732, R-733, R-734, R-735, R-736, R-737, R-738, R-714, R-715, and R-726. Current task-board status at verification time:

| Dependency | Board status | Required evidence or clearing condition | R-739 impact |
|---|---|---|---|
| R-732 shared state contract | `in_progress` | Contract implementation and owner decision completed and reviewed | **BLOCKER** |
| R-733 deterministic snapshots | `todo` | Focused Godot snapshot/continuation suite passes | **BLOCKER** |
| R-734 save/load persistence | `todo` | Save-envelope and save-service round-trip evidence passes | **BLOCKER** |
| R-735 one environment owner across transitions | `todo` | Transition tests and duplicate-controller audit pass | **BLOCKER** |
| R-736 atmosphere/wet-surface synchronization | `todo` | Sky, lighting, fog, wetness, and water-facing inputs agree through transitions | **BLOCKER** |
| R-737 quality tiers and budgets | `todo` | Minimum/recommended budgets are documented and measured with target/host identity separated | **BLOCKER** |
| R-738 adjacent-map continuity captures | `todo` | Matched renderer captures and continuity verifier pass | **BLOCKER** |
| R-714 adjacent-map streaming | `todo` | Streaming traversal and border continuity acceptance passes | **BLOCKER** |
| R-715 reflective water rollout | `todo` | Water implementation and all-map rollout are accepted | **BLOCKER** |
| R-726 fixed-setting exterior capture matrix | `todo` | Required matrix and evidence packet are accepted | **BLOCKER** |

Existing owners already cover these blockers. No duplicate follow-up task is created by R-739.

## R-713 deliverable ledger

| R-713 deliverable / acceptance clause | Artifact, command, or observation | Result | Owner / remaining blocker |
|---|---|---|---|
| Physically plausible or authored sky/atmosphere synchronized with sun, ambient, fog, exposure, reflections, and day/night | [`scripts/map/view3d/sky_weather_3d.gd`](../../scripts/map/view3d/sky_weather_3d.gd) contains the sky resource, weather profiles, astronomy, and lighting modifier API; [`tests/godot/test_sky_weather_3d.gd`](../../tests/godot/test_sky_weather_3d.gd) contains source/state assertions | **PARTIAL structural evidence only**; Godot execution unavailable, and no R-713 signed capture exists | R-736 owns synchronization; R-739 cannot accept without focused runtime results and matched captures |
| Layered moving clouds with coverage, altitude, softness, shadowing, horizon blending, and scalable quality tiers | `SkyWeather3D` exposes cloud offsets, coverage, chaos, storm, locality, and wind-driven drift; the R-737 task and its performance report are still open | **PARTIAL implementation evidence; quality tier acceptance missing** | R-737 must document and measure tiers; R-738 must show visual continuity |
| Clear, overcast, rain, storm, and post-rain wetness with controlled transitions | [`tests/godot/test_sky_weather_3d.gd`](../../tests/godot/test_sky_weather_3d.gd) covers the five regimes, transition blending, lightning, gusts, and puddle wetness; [`docs/SKY_WEATHER_STATE_CONTRACT.md`](../../docs/SKY_WEATHER_STATE_CONTRACT.md) documents persisted fields | **UNVERIFIED in this environment**; no executed Godot result | R-733/R-736 own deterministic continuation and presentation proof |
| Rain direction/intensity, shelter behavior, fog/haze, wet surfaces, and weather-aware water reflections | Source inspection finds rain suppression and puddle synchronization in `MapView3D`; no accepted R-713 water/atmosphere packet exists, and R-715 remains `todo` | **BLOCKED** | R-715 and R-736 must deliver water and presentation evidence |
| Shared integration across adjacent maps preserving time, cloud field, lighting, and weather | Shared day-cycle restoration exists in `MapViewRuntime`, and the state contract defines a scene-tree-free handoff; static audit finds `MapView3D._assemble()` creates `SkyWeather3D.new()` and a `WorldEnvironment` per view, with no runtime call transferring `snapshot_state()` / `apply_state()` | **BLOCKED; duplicate/reset risk is not closed** | R-735 owns one canonical owner and idempotent transition binding; R-714 owns streaming continuity |
| Signed matched captures show a continuous sky/weather front without lighting/exposure jumps | Existing ADR-0018 and fishing-net images are development/reference captures, not R-738 adjacent-map continuity evidence. No `docs/reports/r713_sky_weather_continuity.md` or R-738 packet exists | **BLOCKED** | R-738 and R-726 must produce accepted matched captures and human review |
| Sky/cloud/weather parameters persist through save/load and map transitions | [`tests/godot/test_sky_weather_state.gd`](../../tests/godot/test_sky_weather_state.gd) covers JSON-like state round-trip between presenters; no canonical `GameState` save payload or transition integration is present in the inspected call sites, and R-734 is `todo` | **PARTIAL contract evidence only; acceptance blocked** | R-734 owns save/load; R-735 owns transition persistence |
| Automated tests verify state continuity and no duplicate environment controllers | State tests exist; runtime tests cover shared cycle continuity; no focused duplicate-controller test or R-735 implementation is present; Godot cannot run here | **BLOCKED** | R-733/R-735 must provide executable focused suites and owner audit |
| Performance budgets and quality fallbacks are documented and measured on minimum/recommended hardware | [`docs/data/world_building_visual_benchmark.json`](../../docs/data/world_building_visual_benchmark.json) records both performance rows as `pending`; minimum evidence identifies an Intel UHD 620 target but an Apple M5 Pro measurement host, and recommended evidence is also pending. The generic gate reports both rows as not accepted | **BLOCKED** | R-737 owns tier budgets; R-726/R-717-style capture owners must provide accepted measurements; no host relabeling is allowed |

## Existing artifact audit

### State and renderer boundary

The contract in [`docs/SKY_WEATHER_STATE_CONTRACT.md`](../../docs/SKY_WEATHER_STATE_CONTRACT.md) correctly keeps `Environment`, `Sky`, `Camera3D`, particles, audio players, and scene nodes out of persisted state. `SkyWeather3D.snapshot_state()` / `apply_state()` and the state tests provide a useful foundation. This is not sufficient for R-713 closeout while R-732 is still `in_progress` and R-734/R-735 have not integrated the contract into canonical save and transition ownership.

### Environment ownership

The static audit found one `SkyWeather3D.new()` and one `WorldEnvironment.new()` in the `MapView3D._assemble()` path, but that path runs for every newly assembled map view. No production call site outside tests currently transfers a weather snapshot into a rebuilt view. The existing shared MusicDirector path proves day-clock continuity only; it does not prove a single canonical weather owner. This is an explicit R-735 blocker, not a claim that a duplicate is visible in every current gameplay path.

### Captures and performance

The generic benchmark manifest covers 30 maps and 12 capture categories, but its accepted evidence is still pending. The generated planner produced 360 jobs. Existing images under `docs/reports/images/` are not relabeled as R-713 continuity evidence because they lack the required two-map handoff identity, matched weather parameters, owner audit, and R-713 acceptance review.

The declared minimum profile remains `minimum-hardware-intel-uhd-620` while the available recorded measurement host is Apple M5 Pro/arm64. Per the project performance evidence rules, this is supplementary evidence and cannot certify minimum hardware.

## Final recommendation

**BLOCKED - do not mark R-713 or R-739 done and do not request final human sign-off yet.**

R-739 has delivered the bounded acceptance ledger. Closeout can proceed only after the existing dependency owners provide their artifacts and the following commands are rerun in an environment with Godot 4.7 and a real renderer where required:

1. Run the focused sky/weather, state, save/load, runtime-transition, and continuity Godot suites through `tools/run_godot_checked.sh --require-test-summary`.
2. Run the R-738 continuity capture/verifier and inspect matched day/night and weather handoff images.
3. Run the R-737 performance evidence path with explicit minimum/recommended target hardware and measurement-host identities; keep unavailable target measurements `BLOCKED`.
4. Rerun the generic world-building evidence gate and confirm all R-713-specific evidence links resolve.
5. Rerun `git diff --check`, then obtain maintainer/human review of the matched captures and this report.

The parent R-713 task remains open because the required runtime, persistence, transition-owner, water, capture, and performance evidence is not yet complete.
