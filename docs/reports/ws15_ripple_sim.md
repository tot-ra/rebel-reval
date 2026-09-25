# WS-15 interactive ripples and wakes - evidence

Task: [WS-15](../tasks/water_sky/WS-15_interactive_ripples_wake.md) (board R-900). Date: 2026-09-25.
Godot 4.7.1, Apple M5 Pro. Capture tool: [`tools/capture_ws15_ripples.gd`](../../tools/capture_ws15_ripples.gd).

## What shipped

- `WaterRippleSim` (`scripts/map/view3d/water_ripple_sim.gd`) owns two 256 x 256 HDR SubViewports
  that swap roles every step. Each one runs `water_ripple_sim.gdshader` and reads the other as
  `prev_state` (R = h_t, G = h_{t-1}, B = aeration). The 64 x 64-unit window follows the camera
  focus in whole texels and passes the integer shift to the kernel. The impulse queue holds up to
  32 impulses per step, and `add_moving_body()` turns a hull into a bow ring and an opposite-phase
  stern ring. `set_rain()` adds `intensity * 40` deterministic droplets per step, seeded by the
  step index.
- `MapView3D` builds the sim for outdoor maps with water on tiers whose `ripple_sim_size` is above
  0 (`recommended` 256, `minimum` 0 = off). `SkyWeather3D._update_rain()` feeds it
  `rain_intensity()`, or 0 under a roof.
- `map_view_water.gdshader` samples the window. The vertex stage adds a crest-only lift. The
  fragment stage adds a slope from central differences to the FFT/detail normal (so rings bend
  reflections and glints), a small highlight on ring flanks (`ripple_sheen`), and bubbly aeration
  foam. Everything fades over the outer 10% of the window. With `ripple_window.w == 0` the path is
  off, and materials start on a flat 1 x 1 RGBAH texture, because an unset sampler would read
  white (h = 1).
- No CPU readback in play. Gameplay never reads ripple heights. Nothing is persisted.

## Decisions and deviations from the contract text

1. **Float targets, no packed-16.** A non-headless probe wrote `vec4(0.3, -0.2, 0.01, 0.75)` into
   a `use_hdr_2d` SubViewport. It read back as half-float-exact signed values from both a
   canvas_item and a spatial shader, on Compatibility (opengl3) and on Metal. Unlike the WS-10 sky
   shader, the spatial water shader sees no sRGB decode. Metal forces alpha to 1, so A is unused.
2. **Wave speed `c^2 = 0.02`, not 0.25.** At 0.25 a ring runs about 6.5 m/s at 0.87 m per unit,
   the rain turns into grid noise within a fraction of a second, and a rowing-pace hull is slower
   than the waves, so it cannot draw a V. At 0.02 rings move about 2.1 units/s: slow enough to
   read as rain rings, and a 3 u/s hull outruns them and leaves a V.
3. **Kelvin-Voigt damping (`wave_smoothing` 0.07).** The kernel adds a Laplacian of the vertical
   velocity to the contract's uniform `visc` 0.006. Grid-scale chatter from 1-2 texel drops dies in
   a few steps, and metre-scale rings survive. The explicit bound `c^2 + 2 * smoothing <= 0.5`
   holds (0.16).
4. **Zero-volume impulses.** Every impulse is a Laplacian-of-Gaussian ("Mexican hat") with zero
   integral. With plain Gaussians the rain piled up a standing offset (|h| 0.55 after 600 steps
   and no visible rings), and a hull built a quasi-static ridge that hid its wake.
5. **Rain has its own 40-slot array.** The 32-per-step cap applies to gameplay impulses, so a
   storm never takes wake slots. Full rain is 40 drops per step, as the contract asks.
6. **Aeration from hull forcing only.** Rain rings the surface without whitening it.
   `AERATION_GAIN` 110 maps about 0.006 of forcing per step (3 u/s) onto 0..1 foam, which decays
   at 0.45/s.
7. **Hull strength.** 0.002 per step per u/s, capped at 0.012. Hulls wider than a 0.45-unit half
   beam are scaled down by the beam ratio squared. The stern ring is -0.8 of the bow ring.
8. **Crest-only vertex lift and slope clamp.** The FFT trough floor leaves 0.0015 units above the
   recessed bed, so the ripple only raises crests. The shading slope is clamped at 0.6, because
   unbounded hull slopes mirrored the dark lower hemisphere as black streaks.
9. **Cadence.** The kernel steps at a fixed 60 Hz, at most once per rendered frame. Below 60 fps the
   ripples slow down rather than skip.
10. **Tier changes take effect on the next map build**, the same as the WS-04 FFT cascades.

Scope additions not in the contract's allowed files: the capture tool, this report, and a lesson
in `agents/rebel-dev/playbook.md`.

## Evidence

All plates are `reval_harbor_north`, open water at cell (80, 24), under the gameplay orthographic
camera (pitch -30, yaw 45) at size 16, around 10 am. `--fft` forces the WS-04 FFT sea, as the WS-04
plates did. The production Gerstner path still exposes the recessed bed through wave troughs at
this zoom. That is an existing problem and is filed as a follow-up. `_off` plates detach the sim,
which gives the before state.

| Plate | Compatibility | Metal |
|---|---|---|
| Rain, ripples / before | `ws15_opengl3_rain_fft.png` / `_off` | `ws15_metal_rain_fft.png` / `_off` |
| Storm, ripples / before | `ws15_opengl3_storm_fft.png` / `_off` | `ws15_metal_storm_fft.png` / `_off` |
| Debug hull, 3.2 u/s, half beam 0.9 | `ws15_opengl3_wake_fft.png` / `_off` | `ws15_metal_wake_fft.png` / `_off` |
| Wake height field (grey = h, red = aeration) | `ws15_opengl3_wake_state_fft.png` | `ws15_metal_wake_state_fft.png` |
| 600-step max-rain height field | `ws15_opengl3_stability_state.png` | `ws15_metal_stability_state.png` |
| 10 s storm pan, 8-frame strip | `ws15_opengl3_clip_fft.png` | `ws15_metal_clip_fft.png` |

### Stability (verify 2)

`--scenario=stability` runs 600 steps at rain 1.0 and reads the state back every 60 steps. This
readback exists only in the capture tool.

| Renderer | max abs h | checkerboard residual | rain aeration |
|---|---|---|---|
| Compatibility | 0.2496 | 0.252 | 0.0 |
| Metal | 0.2496 | 0.251 | 0.0 |

The bound is |h| < 1 (the kernel's safety clamp is 0.95 and is never reached). The per-60-step
maxima stay between 0.18 and 0.25, so the field is not growing. The checkerboard residual is the
mean |h - neighbour average| / mean |h|. An odd-even blow-up would push it past 1.

### Window scrolling (verify 3)

`--scenario=clip` pans the camera 12 units over 10 s in a storm, so the window scrolls about 48
texels. The strips show rings continuing across the whole pan with no seam line or jump. The largest
full-frame mean change between frames 4 apart is 0.0110 on Compatibility and 0.0070 on Metal
(0..1 RGB). Rain motion keeps that from being 0. No frame stands out. The deliverable is a strip
plus this metric, not a video file.

### Wake

On Compatibility the height field shows the bow and stern ring trains with a narrow V behind the
hull (max |h| 0.199) and churned water along the track (aeration 0.67). Metal takes fewer sim
steps in the same 150 rendered frames, so its wake is shorter (max |h| 0.178, aeration 0.17). The
capture drives the hull per rendered frame.

### Performance (verify 4)

`--scenario=benchmark` measures 2560 x 1440 with vsync off, storm rain plus the debug hull, 600
frames. Each result is the mean wall-clock frame time. Runs are interleaved with `--off` (the sim
node exists, but its viewports do not render and the shader path is off).

| Renderer | sim (5 runs) | off (5 runs) | delta |
|---|---|---|---|
| Compatibility | 11.37, 11.41, 11.01, 11.04, 11.12 ms (mean 11.19) | 11.34, 11.01, 10.87, 11.02, 11.50 ms (mean 11.15) | +0.04 ms |

The difference is inside the ±0.3 ms run-to-run noise, and inside the 0.4 ms target. Metal
presents at 16.667 ms in both modes even with vsync disabled, so it cannot resolve the delta. The
fixed work is two 256² passes of one 5-tap kernel plus at most 72 short impulse loops, and 5
extra texture taps per water fragment.

## Known issues

- **Metal-only shadow acne on water.** On the mobile renderer, water normals that tilt away from
  the sun show horizontal dashed rows. Disabling the sun's shadows removes them. Faint rows are
  already visible on `ws15_metal_storm_fft_off.png` without ripples, and the ripple slopes make
  them stronger. Compatibility, the shipping renderer, is clean. This is filed as a follow-up
  (stop water casting shadows onto itself or tune the bias). The fix is outside WS-15's allowed
  files.
- **No live consumers besides rain.** No moving-vessel feature exists yet, so `add_moving_body()`
  is exercised only by the capture tool. The swimmer hooks in after WS-14.
- **Windows over 64 units.** Zoomed-out gameplay views wider than the 64-unit window show ripples
  fading out toward the window edge by design.

## Commands

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_water_ripple_sim
/Applications/Godot.app/Contents/MacOS/Godot --path . [--rendering-method mobile --rendering-driver metal] \
  --script tools/capture_ws15_ripples.gd -- --scenario=rain|storm|wake|stability|clip|benchmark [--fft] [--off]
```
