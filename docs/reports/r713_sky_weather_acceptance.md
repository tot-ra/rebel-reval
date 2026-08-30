# R-713 unified sky-weather acceptance

- Task: R-739 / R-782
- Parent: R-713
- Verification date: 2026-08-30
- Verification scope: fail-closed parent acceptance refresh
- Recommendation: **BLOCKED - not ready for human sign-off**

This report is an evidence ledger, not a claim that the unified sky/weather system is complete. Structural, persistence, and renderer-capture evidence is retained only for the clause it proves. Open water integration, target-hardware, external-parent, and human visual-review gates remain blockers.

## Current evidence boundary

The shared worktree was already dirty before this refresh. No pre-existing change was reverted, staged, or promoted as R-713 evidence. The refresh uses committed child-task results plus rerunnable verifiers in the current checkout.

| Command or evidence | Current result | Interpretation |
|---|---|---|
| `python3 tools/verify_r713_sky_weather_evidence.py` | **PASS**, 40/40 PNG plates and 20/20 handoffs | The committed Metal continuity packet is structurally complete, checksum-valid, and preserves state hashes and one environment owner. |
| `python3 tools/verify_weather_audio_clips.py` | **PASS**, 1 clip | The narrow roof-rain audio contract is healthy; this is not parent visual acceptance. |
| `python3 -m unittest tests.python.test_verify_weather_audio_clips -v` | **PASS**, 3/3 | Weather-audio verifier fixtures remain fail-closed. |
| `python3 -m unittest tests.python.test_verify_world_building_visual_gate -v` | **FAIL**, 2/6 | The current registry includes `kuldjala_interior`, but the generic benchmark matrix does not. This ambient R-716/R-726 drift is not repaired or waived by R-713. |
| `python3 tools/verify_world_building_visual_gate.py --json` | **FAIL** | Generic automated checks, capture categories, performance evidence, comparison sheet, and human art review remain pending. |
| `python3 tools/verify_r713_sky_weather_acceptance.py` | Expected **BLOCKED** (exit 2) | Aggregates artifact integrity and mandatory open gates without turning expected blockers into a false pass. |
| `test_r715_water_weather_sync` through checked Godot runner | **FAIL**, 3/4 | The save/load handoff assertion reports unequal water-uniform dictionaries even though their formatted float/vector values are identical; R-774 must use serialization-tolerant component comparisons or fix a real hidden type/precision mismatch. |

Previously retained focused evidence remains valid for completed child rows: `test_sky_weather_3d` 29/29, `test_sky_weather_state` 5/5, `test_save_envelope` 15/15, `test_save_service` 14/14, and `test_r713_sky_weather_continuity` 4/4. The current refresh reruns focused suites below before status changes are made.

## Dependency and ownership gate

| Dependency | Board status | Required evidence or clearing condition | R-713 impact |
|---|---|---|---|
| R-732 shared state contract | `done` | Contract enumerates all persisted fields; state suite is green | **CLEARED** |
| R-733 deterministic snapshots | `done` | Snapshot round-trip and deterministic continuation suite is green | **CLEARED** |
| R-734 save/load persistence | `done` | Envelope and service weather round-trips are green | **CLEARED** |
| R-735 one environment owner | `done` | Idempotent transition binding and duplicate-owner contract are covered | **CLEARED for owned scope** |
| R-736 atmosphere/wet-surface synchronization | `in_progress` | R-773 and R-775 are done; R-774 must close water-facing wetness/reflection synchronization with R-754 | **BLOCKER** |
| R-737 quality tiers and budgets | `in_progress` | Tier constants/tests/report exist, but target-specific measurements remain blocked | **BLOCKER** |
| R-738 adjacent-map continuity captures | `in_progress` | 40/40 plates and 20/20 handoffs pass structural verification; named human visual review remains pending | **BLOCKER** |
| R-774 water reflection synchronization | `in_progress` | `test_r715_water_weather_sync` and the shared snapshot adapter must be accepted with R-754 | **BLOCKER** |
| R-714 adjacent-map streaming | `in_progress` | Streaming traversal and border continuity acceptance must close | **EXTERNAL BLOCKER** |
| R-715 reflective water rollout | `in_progress` | Water weather synchronization, performance, visual packet, and closeout must close | **EXTERNAL BLOCKER** |
| R-726 fixed-setting exterior capture matrix | `in_progress` | Generic matrix and human art review must close | **EXTERNAL BLOCKER** |

Existing owners cover every open dependency. No duplicate implementation follow-up is required from R-713.

## R-713 deliverable ledger

| R-713 clause | Artifact or evidence | Result | Remaining owner or blocker |
|---|---|---|---|
| Shared physical sky synchronized with sun, ambient, fog, exposure, reflections, and day/night | `SkyWeather3D`, shared presentation snapshots, completed R-773 lighting/fog adapter, focused weather tests | **IMPLEMENTED / structurally green** | R-774 must finish the water-facing synchronization edge |
| Layered moving clouds and scalable quality tiers | R-776 constants/resources, R-777 tier tests, `r713_environment_performance.md` | **IMPLEMENTED; measurement blocked** | R-737 needs accepted minimum/recommended measurements |
| Clear, overcast, rain, storm, and post-rain controlled transitions | 29/29 weather tests and persisted state contract | **PASS for deterministic behavior** | Human visual acceptance remains separate |
| Rain direction/intensity, shelter, fog/haze, wet surfaces, and weather-aware water | Shared snapshot and shelter contracts exist | **PARTIAL** | R-774/R-754 must accept water reflection, tide, wind, and wetness agreement |
| Adjacent maps preserve time, cloud field, lighting, and weather | 20/20 captured handoffs have matching state hashes and one owner | **PASS for captured handoff contract** | R-714 streaming acceptance remains external |
| Signed matched captures show no lighting/exposure jump | Metal packet has 40/40 valid 1280x720 plates | **BLOCKED** | Named human visual review and R-726 generic matrix acceptance are pending |
| Parameters persist through save/load and map transitions | State, envelope, service, and transition-owner suites | **PASS** | No remaining persistence blocker |
| Automated continuity and duplicate-controller tests | Focused continuity packet and one-owner assertions | **PASS for R-713 packet** | Full adjacent streaming remains R-714-owned |
| Performance budgets and quality fallbacks measured on minimum/recommended hardware | `r713_environment_performance.md` defines both tiers and keeps host identity separate | **BLOCKED** | Intel UHD 620 minimum run and isolated recommended-host run are unavailable |

## Captures and performance

The committed continuity packet is no longer missing: it contains 40/40 PNG plates, 20/20 handoffs, matching snapshot hashes, fixed 1280x720 dimensions, Metal renderer metadata, and verified checksums. Its report explicitly says **human visual review pending**, so structural validity cannot be relabeled as signed acceptance.

The minimum target remains `minimum-hardware-intel-uhd-620`; an Apple M5 Pro measurement cannot certify it. The recommended target is `development-baseline-m5-pro`, but no retained run isolates the weather presenter. Both rows remain **BLOCKED** in `docs/reports/r713_environment_performance.md`.

The generic R-716/R-726 world-building gate also remains fail-closed. Its current registry/matrix mismatch for `kuldjala_interior` is an external baseline defect and is not proof against the narrower R-713 packet.

## Final recommendation

**BLOCKED - keep R-713, R-737, R-738, R-739, and R-782 in progress.**

Do not request final human sign-off until all of the following are complete:

1. R-774 and R-754 accept shared wet-surface and water-reflection synchronization.
2. R-737 records isolated recommended-host measurements and a declared Intel UHD 620-class minimum-target run, preserving `BLOCKED` when unavailable.
3. A named human reviewer records acceptance or actionable rejection of the 40-plate continuity packet.
4. R-714, R-715, and R-726 close their external streaming, water, and fixed-matrix contracts.
5. The generic world-building benchmark matrix includes the current active/candidate registry, including `kuldjala_interior`, and its own acceptance gate passes.
6. `python3 tools/verify_r713_sky_weather_acceptance.py` returns `R713_SKY_WEATHER_ACCEPTANCE_PASS`, then the maintainer signs this report.

Until then, exit 2 from the aggregate verifier is the expected fail-closed result, not a waived failure.
