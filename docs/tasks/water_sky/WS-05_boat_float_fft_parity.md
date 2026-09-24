# WS-05 — Boats and CPU water queries read the baked FFT field

Part of the [water and sky task pack](README.md). Source technique: Tidewater's ocean `query`
module (a CPU and GPU height query shared by boat buoyancy, the swimmer and the underwater
waterline), plus `Buoyancy`.

## Player-facing goal

Moored cogs and fishing boats ride the exact waves the player sees. They rise over a passing crest,
pitch when a wave runs along the hull and roll in cross seas. No hull floats above a trough or sinks
into a crest. Every boat reacts to the same sea, with no per-boat random phase.

## Allowed files

- `scripts/map/view3d/ocean_fft_sampler.gd` (new, `class_name OceanFftSampler`)
- `scripts/map/view3d/boat_float_3d.gd`
- `scripts/map/view3d/map_view_water_materials.gd` (move the weather → cascade-weight mapping into a
  static helper shared with the sampler)
- `tests/godot/test_ocean_fft_sampler.gd` (new), `tests/godot/test_boat_float_3d.gd`
- `docs/reports/images/ws05_*.png` or a short clip description in the review
- `TODO.md`

## Dependencies

- TODO: **WS-04** (the shader FFT path, `ocean_time`, and the weather-mapping table).
- Unlocks: WS-04 `use_fft` for real play, plus WS-13, WS-14 and WS-15 (they call
  `OceanFftSampler.height_at`).
- Stable IDs: boat prop IDs are unchanged. Save data doesn't store boat pose, and this must stay true.

## Constraints and non-goals

- **One source of truth.** The CPU sampler must use the same atlases, decode scales, wind rotation,
  standing-wave blend, cascade weights, choppiness, amplitude and `ocean_time` as the shader. Only
  C0 and C1 matter here. C2 (under 4 m) has no effect on hulls.
- No GPU readback. Decode the atlas bytes on the CPU once, at load.
- Memory: keep the raw bytes (`PackedByteArray`, about 3 MiB per cascade). Don't expand to floats.
- Keep `sample_hull_attitude` as the public API shape so the existing callers and tests keep working.
  The Gerstner `sample_wave` stays for rivers and fallback maps.

## Deliverable

1. **`OceanFftSampler`** (a static, lazily loaded cache):
   - `load_profile()` reads `ocean_fft_profile.json`. For each of C0 and C1 it loads the imported
     `Texture2DArray` resource (in exports the source PNGs are gone, so don't read them) and calls
     `get_layer_data(i)` for every frame. It keeps `Image.get_data()` bytes in one
     `PackedByteArray` laid out `[frame][y][x][rgba]`.
   - `set_sea_state(weights: PackedFloat32Array, choppiness, amplitude, wind_dir, standing_ratio)`.
     `map_view_water_materials.apply_sea_weather` calls this with the **same** values it sends to
     the shader. Refactor so one static function computes those values, and both the material and
     the sampler consume it.
   - `displacement_at(world_xz: Vector2, time: float) -> Vector3`: wind-rotate, bilinear-sample the
     four texels of two frames per cascade, blend frames, decode, weight, apply the standing-wave
     blend, rotate back, and convert metres to world units (`/ 0.87`). This mirrors WS-04's shader
     code line by line. Put a `# Keep in lockstep with map_view_water.gdshader _fft_*` comment on
     both sides.
   - `height_at(world_xz: Vector2, time: float) -> float`: the surface height **at a fixed world
     point**. Horizontal displacement moves surface points, so invert it with a fixed-point
     iteration (Tidewater does the same):
     ```gdscript
     var x0 := world_xz
     for i in 3:
         var d := displacement_at(x0, time)
         x0 = world_xz - Vector2(d.x, d.z)
     return displacement_at(x0, time).y
     ```
     Three iterations converge to under 1 mm for choppiness ≤ 1.2. The test must check this.
   - `ocean_time()` forwards to the runtime clock WS-04 added. Tests can inject a time.
2. **`BoatFloat3D` on the FFT path** (`const FFT_SUPPORTED := true`, which WS-04's enablement
   reads):
   - Sample `height_at` at the five hull points that `sample_hull_attitude` already uses (bow, stern,
     port, starboard, centre).
   - **Heave** = the mean of the five heights × `_motion_scale`. The mean acts as a hull-length
     low-pass filter, so heavy cogs automatically move less on short waves.
   - **Pitch** = `atan2(h_bow − h_stern, 2·half_length)`. **Roll** = `atan2(h_port − h_starboard, 2·half_beam)`.
     Keep the existing clamps (`BASE_PITCH_RAD·2.2`, `BASE_ROLL_RAD·2.2`).
   - **Surge** = the mean horizontal FFT displacement at the centre × 0.5 (a hull doesn't follow the
     water particle orbit completely). Remove the synthetic `sin(time·0.55)` surge on this path.
   - Keep the wind heel term.
   - Remove the per-boat `_phase` offset from the FFT time. Boats differ because they sit in
     different places. The offset stays for the Gerstner fallback.
   - Smooth each output with a critically damped spring (about 0.35 s) so the frame-blend steps in
     C1 never jitter a mast.
3. **Shore band caveat:** the shader fades displacement near the shore with the vertex
   `COLOR.r` (`shore_factor`), which the CPU can't see. If a boat's centre is within 1.5 world units
   of land, scale its sampled displacement by `MapViewMeshBuilderTerrainWater.combined_water_coverage_at`
   from the baked contour field when the runtime has access to it. Otherwise, document in code that
   boats moored inside the shore band may clip slightly.

## Verification

1. The headless Godot suite passes. `test_ocean_fft_sampler.gd`:
   - at texel centres and exact frame times, `displacement_at` equals the decoded byte values
     (tolerance 1e-4)
   - periodicity: `displacement_at(p, t) == displacement_at(p, t + 25.6)`
   - `height_at` inversion residual under 1e-3 world units over 200 random points
   - standing ratio 1 returns exactly `0.5·(F(p′) + F_opposite)` from the WS-04 formula, and ratio 0 returns `F(p′)`
   - calm vs storm sea states scale the amplitude monotonically
   - load time for both cascades under 300 ms. Measure one `height_at` call over 10k calls and
     record the number in the test output. GDScript does about 400 byte reads per call, so expect
     tens of µs.
   - **frame budget:** all boats on `reval_harbor_north` together cost under 0.5 ms per frame. If
     they don't, hull points use one fixed-point iteration instead of three (the hull-length average
     hides the error), and boats update round-robin at 30 Hz with the spring smoothing hiding the
     step. The camera and swimmer queries (WS-13, WS-14) keep all three iterations.
2. `test_boat_float_3d.gd` is extended so that on the FFT path the heave follows `height_at`,
   bow-up pitch comes with a crest at the bow, and the same position and time give the same pose for
   two boats (no phase offset).
3. Visual (Metal, harbour, `clear/day` and `storm/day`): record 10–20 s. The hulls must stay seated
   on the surface with no gap and no sinking at the waterline. Report the worst frame as
   "max waterline error in px". Attach the clip, or stills at three moments.
4. After this merges, the WS-04 enablement turns FFT on for sea terrains. Rerun the WS-04 capture
   plates and the performance report with it on.

## Documentation updates

- The lockstep comments in both files.
- `TODO.md` row:
  ```text
  - [ ] WS-05 | deps: WS-04 | deliverable: OceanFftSampler (CPU decode of C0/C1 atlases, shared sea-state mapping, fixed-point height_at) and BoatFloat3D heave/pitch/roll/surge from five FFT hull samples with the shared ocean_time clock | allowed files: `scripts/map/view3d/ocean_fft_sampler.gd`, `scripts/map/view3d/boat_float_3d.gd`, `scripts/map/view3d/map_view_water_materials.gd`, `tests/godot/test_ocean_fft_sampler.gd`, `tests/godot/test_boat_float_3d.gd`, `docs/reports/images/ws05_*.png`, `TODO.md` | verify: sampler decode/periodicity/inversion/perf tests; boat FFT attitude tests; harbor clip shows hulls seated at the waterline in clear and storm
  ```
