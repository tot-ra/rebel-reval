# R-885 water and sky realism pack - acceptance packet

- Epic: **R-885**, water and sky realism pack (Tidewater port, fidelity)
- Contracts: [`docs/tasks/water_sky/README.md`](../tasks/water_sky/README.md)
- Recorded: 2026-10-06
- Status: **NOT ACCEPTED - two children are in review and the pre-pack baseline is missing**

This packet records the pack-level gate only. Per-child verification lives in each child's own
evidence; see the ledger entries in `TODO.md`. The rollout coverage gate stays with R-715 and the
release gate stays with R-716.

## Child status

| Child | Board | State on 2026-10-06 |
|---|---|---|
| WS-01 refracted water column | - | landed (`2e3d3e738`) |
| WS-02 GGX sun and moon glint | R-887 | implementation landed, **in review**; independent acceptance is R-1150 |
| WS-03 FFT ocean bake tool | - | landed |
| WS-04 FFT ocean shader | - | landed (`531dfd9cf`) |
| WS-05 boat float FFT parity | - | landed |
| WS-06 FFT foam and whitecaps | - | landed |
| WS-07 baked caustics | - | landed (`59cd68ca4`) |
| WS-08 shore swash | - | landed (`8eab04c9`) |
| WS-09 atmosphere static LUTs | - | landed (`bff8f03d1`) |
| WS-10 sky-view LUT runtime | - | landed, report `docs/reports/ws10_physical_sky.md` |
| WS-11 sky-driven water and fog | R-896 | landed, in review; art review is R-940 |
| WS-11a weather-driven water haze | R-930 | landed; plate review is R-937 |
| WS-12 cloud shadow map | - | landed (`a6a3dd76`); Compatibility match review is R-1052 |
| WS-13 underwater view pass | - | landed (`22969bab1`); follow-ups R-934, R-1031, R-1068/R-1087 |
| WS-13b/d/e harbour basin, cribs | - | landed; review R-943 |
| WS-14a swim and dive ADR | R-899 | ADR 0021 **accepted with amendments** 2026-09-29; the Decision 1 scope trade is still unnamed |
| WS-14b swim and dive implementation | R-910 | landed (`ba6f576b`), `scripts/player/player_swim_state.gd`; moved to **in review** |
| WS-15 interactive ripples and wake | - | landed (`067b9bb2d`), report `docs/reports/ws15_ripple_sim.md` |

Every child's code is in `main`. No child is unstarted. The epic is held open by the two reviews
and by the missing baseline described below.

## Pack-level captures

Tool: `tools/capture_r715_water_acceptance.gd` through `tools/godot_render.sh`, one process per
plate, viewport 1280x720, quality `recommended`, weather and time fixed by the plate contract.

| Plate | Renderer | File |
|---|---|---|
| `reval_harbor_north/clear/day` | Mobile/Metal | `docs/reports/images/r885_pack/reval_harbor_north_clear_day_metal.png` |
| `reval_harbor_north/clear/day` | GL Compatibility | `docs/reports/images/r885_pack/reval_harbor_north_clear_day_opengl3.png` |
| `lower_town_slice/clear/day` | Mobile/Metal | `docs/reports/images/r885_pack/lower_town_slice_clear_day_metal.png` |
| `lower_town_slice/clear/day` | GL Compatibility | `docs/reports/images/r885_pack/lower_town_slice_clear_day_opengl3.png` |

The manifest in `docs/reports/images/r715_water/` keeps its Metal contract: both Metal plates were
written through the runner and left in place, and the Compatibility runs were copied aside and the
Metal PNG and manifest restored. `reval_harbor_north/clear/day` had no capture before this run; it
moves from `blocked` to `captured_pending_review`.

### Before reference

`lower_town_slice/clear/day` is the only plate with an earlier real capture. The earlier image is
not duplicated into the repository; read it from history:

```bash
git show dccacca4:docs/reports/images/r715_water/lower_town_slice_clear_day.png > /tmp/before.png
```

That image was captured on 2026-09-28, which is **inside** the pack, after WS-01..WS-08 and before
WS-11, WS-12, WS-13b/d/e and the daylight rebalance. It is therefore a mid-pack reference, not the
pre-pack baseline the epic's verify line asks for. The true pre-pack water shader state is
`ef3f7d8a8` (2026-09-24, the last commit on `map_view_water.gdshader` before WS-04). Capturing it
needs a separate worktree and a full Godot import, which is tracked as a follow-up rather than done
here.

Readable difference between the 2026-09-28 reference and the current Metal plate: the open ground
loses its saturated green for a dark olive and brown, roofs and walls gain exposure, and the moat
water keeps its tone. This matches the WS-11 sky-driven lighting chain plus the later daylight
rebalance (`c13d5cae`); it is not a water-shader difference.

## Findings from this run

1. **The R-756 camera does not frame the authored harbour.** The runner aims at the first water
   cell in scan order. For `reval_harbor_north` that is cell `0,0`, the map corner, so the plate is
   open sea from far above and the authored quays sit at the frame edge. The plate is valid
   evidence for the water surface but is weak evidence for harbour fidelity.
2. **The two renderers disagree about detail, far beyond a water difference.** On Mobile/Metal the
   whole frame comes back soft: the town is an indistinct smear and the sea loses its surface
   texture. On GL Compatibility the same plate is sharp and more saturated, with individual houses
   and wall towers readable. The Metal PNGs are also much smaller (788 KB vs 1.2 MB on
   `reval_harbor_north`, 680 KB vs 1.7 MB on `lower_town_slice`), which is consistent with less
   high-frequency detail actually reaching the frame.

   The cause is **not identified** and must not be guessed at in this packet. What is ruled out:
   depth of field. `CameraAttributesPractical` with `dof_blur_far_enabled` exists only in
   `MapViewRuntimeCameraPerspective`, which is installed by `MapViewRuntimeCamera` through the
   runtime bootstrap. The capture runner calls `MapView3D.create()` and never installs the runtime,
   so no DOF is applied to the acceptance camera on either renderer. Candidates left for the
   follow-up to confirm: automatic mesh LOD and mipmap selection, which the Mobile renderer applies
   and GL Compatibility does not support, and the `glow`/`adjustment` post chain configured in
   `MapViewLighting.configure_post_process`, which the two renderers resolve differently.

   Either way the manifest requires Metal, so every Metal plate in the packet - including the
   2026-09-28 reference - is soft, and it is weak evidence for surface fidelity.
3. **Two geometry seams are visible on `reval_harbor_north` on both renderers:** an olive land
   quad crossing open water in the upper left, and a lighter rectangular water band running
   diagonally across the sea. Both read as authored-extent or backdrop seams rather than shader
   artefacts.
4. No glint path shows on the noon harbour plates. This is expected and already recorded as WS-02
   decision 4: the gameplay camera's mirror direction points north-west, so the southern noon sun
   cannot glint. Sunset evidence lives in `docs/reports/images/ws02_*`.
5. **The capture runner corrupts its own manifest contract.** A successful run rewrites
   `capture_manifest.json` through Godot's JSON serializer, which sorts object keys alphabetically.
   That reorders `required_visual_checks` and every plate's `visual_checks` away from the contract
   order asserted by `tests/godot/test_r715_water_acceptance_packet.gd`, and it produces a ~10 600
   line diff for a two-plate update. The runner also sets the packet-level `capture_status`,
   `commit`, `renderer_observed` and `hardware_host` unconditionally, so a single-plate run flips
   the whole fail-closed packet to `captured_pending_review` while 123 plates are still blocked -
   which the same test rejects. For this change the manifest was rebuilt from the committed version
   with only the two plates' fields applied and the packet-level fields left fail-closed, so the
   diff is 34 added and 17 removed lines and the packet tests pass. Tracked in R-1156.

## Remaining pack-level gates

- R-887 (WS-02) and R-896 (WS-11) close only on their named reviews (R-1150, R-940).
- R-910 (WS-14b) closes once ADR 0021's Decision 1 scope trade is named by the maintainer.
- A true pre-pack before/after pair from `ef3f7d8a8`.
- `tools/run_godot_tests.gd` with no regression (see below).

## Test suite

**Water and sky set - green.** 229 assertions, exit 0, no failures:

```
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=\
test_atmosphere_cpu,test_atmosphere_luts,test_boat_float_3d,test_cloud_shadow_pass,\
test_ocean_fft_material,test_ocean_fft_sampler,test_player_swim_state,test_player_water_traversal,\
test_r713_sky_weather_continuity,test_r715_water_acceptance_packet,test_r715_water_benchmark_protocol,\
test_r715_water_exceptions,test_r715_water_map_handoff,test_r715_water_map_rollout,\
test_r715_water_material_contract,test_r715_water_performance_verification,\
test_r715_water_rollout_inventory,test_r715_water_save_envelope,test_r715_water_surface_geometry,\
test_r715_water_weather_sync,test_sky_astronomy,test_sky_atmosphere_lut,test_sky_weather_3d,\
test_sky_weather_state,test_underwater_pass,test_water_ripple_sim,test_weather_realism,\
test_map_relief_water
```

**Full suite - not clean, and not attributable to this change.** The full run on 2026-10-06 exits 1
with 407 failing assertions (one of which is the harness's own self-test, which is designed to
fail). They land in the quest, save-matrix, building-surface and capture-manifest suites. At the
time of the run the working tree carried 556 files modified by a concurrent agent, including 37
`content/packages/*/package.json` quest packages, 19 `content/maps` files and changes under
`scripts/world`, `scripts/map`, `tools` and `tests/godot`. This change touches only documentation,
evidence images and the water capture manifest, so it cannot reach those suites.

**The epic's "no regression in `tools/run_godot_tests.gd`" gate therefore stays open** until the
full suite is run on a tree without the concurrent work in flight.
