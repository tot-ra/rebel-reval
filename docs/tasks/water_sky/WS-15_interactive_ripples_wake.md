# WS-15 — Ripples and wakes around moving bodies (render-target wave simulation)

Part of the [water and sky task pack](README.md). Source technique: Tidewater `WakeKernel` /
`WakeParams` (a local simulation window that follows the boat, `visc 0.006`, `foamGain 0.35`,
`aerGain`/`aerOut` aeration, `wash`, `bow` pressure, `hollow`) and its splash spray. Tidewater runs
it in compute. We run the same idea as two `SubViewport`s swapped each frame.

## Player-facing goal

Rain on the harbour makes countless expanding rings that interfere with each other. A rowing boat
or a cog warping along the quay leaves a V-shaped wake with churned white water behind the stern.
Once WS-14 lands, Kalev wading or swimming pushes ripples ahead of him, and a dive leaves a ring and
a patch of bubbles. The ripples bend the reflections and glints, and they die out after a few
seconds.

## Allowed files

- `scripts/map/view3d/water_ripple_sim.gd` (new, `class_name WaterRippleSim`: owns the swapped
  viewports and the impulse queue)
- `scripts/map/view3d/water_ripple_sim.gdshader` (new, `canvas_item`: the simulation step)
- `scripts/map/view3d/map_view_water.gdshader` (sample the ripple texture)
- `scripts/map/view3d/map_view_water_materials.gd` (wire the texture and window uniforms)
- `scripts/map/view3d/map_view_3d.gd` (create the sim for outdoor maps with water)
- `scripts/map/view3d/sky_weather_3d.gd` (the rain-impulse hook, plus `ripple_sim_size` in
  `QUALITY_TIERS`)
- `tests/godot/test_water_ripple_sim.gd` (new)
- `docs/reports/images/ws15_*.png`
- `TODO.md`

## Dependencies

- TODO: **WS-04** (`ocean_time`, FFT path). It relies on WS-10's finding about float
  render targets on Compatibility (`use_hdr_2d`). If WS-10 hasn't landed, do that check here first.
- Rain rings are the **first consumer** and need nothing else. Wakes need a moving-vessel feature
  (none is active today; `BoatFloat3D` only moors boats). The swimmer needs WS-14b. Both of those
  hook in through `add_impulse()` when they exist.
- Stable IDs: none. Nothing is persisted, and the sim state is transient on load.

## Constraints and non-goals

- A local window only: **64 × 64 world units** centred on the camera focus, at 256² texels on
  `recommended` (0.25 u/texel) and 128² at 30 Hz on `minimum`, or off.
- The simulation needs **float precision**. If `use_hdr_2d` doesn't give a float target on
  Compatibility, pack the height and its previous value as 16-bit fixed point into RG/BA of RGBA8
  (write helpers `pack16`/`unpack16`), and document the choice.
- No CPU readback. The gameplay never reads the ripple heights (boats and the swimmer keep using
  `OceanFftSampler`).
- Don't simulate the big waves. The ripples are an additive detail on top of the FFT sea.

## Deliverable

1. **`WaterRippleSim`**:
   - Two `SubViewport`s, A and B (`UPDATE_ALWAYS`, `transparent_bg` off). Each contains a
     full-rect `ColorRect` with the step shader reading the *other* viewport's `ViewportTexture` as
     `prev_state`. Swap the roles every frame by toggling which viewport updates (a viewport can't
     read its own output).
   - **State channels:** R = height `h_t`, G = height `h_{t−1}`, B = aeration (foam), A = unused.
   - **Window scrolling:** snap the window origin to whole texels as the camera focus moves, and
     pass the integer texel shift to the step shader, which samples `prev_state` with that offset
     (texels that enter from outside start at zero). Expose `window_origin` and `window_size` for the
     water shader.
   - `add_impulse(world_pos: Vector2, radius: float, strength: float)` queues up to 32 impulses per
     frame into a uniform array (`vec4 impulses[32]`). Also add
     `add_moving_body(world_pos, velocity, half_length, half_beam)`, which converts a hull into a bow
     push-up (positive) and a stern trough (negative) along the velocity, as Tidewater's `bow` and
     `hollow` do.
   - `set_rain(intensity)`: each frame, a deterministic RNG seeded by the frame index emits
     `intensity · 40` droplet impulses (radius 1–2 texels, strength 0.02–0.05) inside the window.
     `SkyWeather3D` calls it with `rain_intensity()`.
2. **Step shader** (`water_ripple_sim.gdshader`), the damped discrete wave equation:
   ```glsl
   float lap = h(x+1,y) + h(x-1,y) + h(x,y+1) + h(x,y-1) - 4.0*h(x,y);
   float h_next = (2.0*h - h_prev + c2 * lap) * (1.0 - visc);   // c2 ≈ 0.25 for stability, visc ≈ 0.006
   h_next += impulses …;                                         // Gaussian bumps from the queue
   float aer = max(aer * exp(-aer_decay*dt), abs(h_next - h) * aer_gain);   // churned-water foam
   ```
   Fade `h_next` to zero within 8 texels of the window edge (an absorbing border, so the window
   doesn't reflect waves back).
3. **Water shader:**
   - Map world xz to the window UV. Outside the window there is no effect.
   - Vertex: add `h · ripple_amplitude` to `VERTEX.y`, and only for the recommended tier's dense
     mesh near the camera.
   - Fragment: take the normal perturbation from central differences of `h` (4 samples), added to the
     FFT normal before WS-02's lighting. Add aeration to the WS-06 fresh-foam mask with a bubbly
     look.
   - Fade the ripple contribution by the distance to the window edge.
4. **Quality tiers:** add `ripple_sim_size` (recommended 256, minimum 0 = off) to
   `SkyWeather3D.QUALITY_TIERS`. When it's off, the water shader gets a 1×1 zero texture and the
   uniforms mark the window invalid.

## Verification

1. The headless Godot suite passes. `test_water_ripple_sim.gd` (the logic side, no rendering)
   checks:
   - the impulse queue caps at 32 per frame and clears after dispatch
   - the rain RNG is deterministic per frame index and scales with intensity
   - the window snapping shift is an integer and correct for moves in all four directions
   - `add_moving_body` produces paired bow and stern impulses along the velocity
   - the sim is not created indoors or on the `minimum` tier
2. Stability: run the step shader for 600 frames in a capture run with rain at maximum. The heights
   stay bounded (|h| < 1 in the packed range), with no checkerboard blow-up. Record the maximum
   height in the report.
3. Captures (Metal and Compatibility), `reval_harbor_north`: `rain/day` and `storm/day` (dense
   interfering rings), plus a scripted debug moving body along the quay using `add_moving_body`
   from the capture tool (a V wake and white water behind), plus a 10 s clip. Check that no seam
   appears where the window ends and that there is no pop when the window scrolls with the camera.
4. Performance: `tools/run_performance_report.sh --quick`, with the sim step at 256² plus the water
   samples. The target is ≤ 0.4 ms on `recommended`.

## Documentation updates

- The script header documenting the float vs packed-16 decision.
- `TODO.md` row:
  ```text
  - [ ] WS-15 | deps: WS-04 | deliverable: camera-following 64x64-unit ping-pong SubViewport wave-equation ripple sim (float or packed-16) with impulse queue, deterministic rain droplets, moving-body bow/stern wake and aeration foam, sampled by the water shader for height/normal/foam | allowed files: `scripts/map/view3d/water_ripple_sim.gd`, `scripts/map/view3d/water_ripple_sim.gdshader`, `scripts/map/view3d/map_view_water.gdshader`, `scripts/map/view3d/map_view_water_materials.gd`, `scripts/map/view3d/map_view_3d.gd`, `scripts/map/view3d/sky_weather_3d.gd`, `tests/godot/test_water_ripple_sim.gd`, `docs/reports/images/ws15_*.png`, `TODO.md` | verify: sim logic tests; 600-frame max-rain stability; rain/storm/moving-body captures and clip without window seams; <= 0.4 ms
  ```
