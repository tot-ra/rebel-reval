# WS-13 — Underwater view: fog, light shafts, Snell's window and a waterline across the lens

Part of the [water and sky task pack](README.md). Source technique: Tidewater `underwater` and
`underwater-composite` modules (`UnderwaterParams`: `lensDistance`, `shafts`, `band 9`,
`UW_STRADDLE`, `UW_IOR`), `underwaterLighting`, `causticsSample`, the `HazeParams.hasMedium` hand-off,
`LensParams` (wet lens after surfacing), and the audio `submerge()`/`emerge()` calls.

## Player-facing goal

When the camera goes below the surface (first-person or third-person camera near the shore, a
cinematic, or later swimming from WS-14), the view becomes a real underwater scene:

- Blue-green water swallows distance: red goes first, and things 10 m away fade into turquoise.
- Light shafts slant down from the rippling surface in the sun direction.
- Caustics play over the sand, rocks and quay foundations.
- Looking up, the sky is visible through a bright circular window (Snell's window). Outside the
  window, the surface is a silvery mirror of the underwater world.
- Half-submerged, a wavy waterline cuts across the lens with a thin dark meniscus. Above it is
  normal air view, and below it is the underwater view.
- Sound goes muffled underwater. On surfacing, water drops briefly bead and run down the lens.

## Why

P0-227 added only a short fog tint inside the water shader, *on the water surface pixels*. Anything
seen below the surface without looking through it (the bed, walls, fish, the player) gets no water
at all. There are no shafts, no Snell's window and no waterline. P0-227's constraint said
"isometric gameplay camera stays above water unless a later task submerges it", and this is that
task. It is a rendering task only. Moving the player under water is WS-14.

## Allowed files

- `scripts/map/view3d/underwater_pass.gd` (new, `class_name UnderwaterPass`: screen-quad node, state,
  audio low-pass)
- `scripts/map/view3d/underwater_pass.gdshader` (new)
- `scripts/map/view3d/ocean_fft_common.gdshaderinc` (new: move the WS-04 `_fft_*` sampling
  functions here unchanged so the water shader and this pass share them)
- `scripts/map/view3d/map_view_water.gdshader` (include the file above, add the back-face
  Snell's-window branch, remove the P0-227 fog tint)
- `scripts/map/view3d/map_view_3d.gd` (attach the pass for outdoor maps with water)
- `audio/default_bus_layout.tres` for a `LowPassFilter` on the world
  SFX bus, disabled by default
- `tools/capture_underwater.gd` (new: capture helper with a forced camera pose)
- `tests/godot/test_underwater_pass.gd` (new), `tests/godot/test_r715_water_material_contract.gd`
- `docs/reports/images/ws13_*.png`
- `TODO.md`

## Dependencies

- TODO: **WS-01** (`sigma_t` per channel, the IOR constant), **WS-05** (`OceanFftSampler.height_at`
  for the camera) and **WS-07** (caustic tiles). WS-11 is optional: if present, use
  `AtmosphereCpu.sky_irradiance` for the in-scatter colour. Otherwise use today's ambient.
- Stable IDs: none. No save data.

## Constraints and non-goals

- **Rendering only.** No player swimming, no new input, no gameplay state.
- The pass must cost **zero** when the camera is above water and away from the surface: the node is
  hidden, not running.
- One screen pass + the existing water shader. No extra scene renders, no reflection cameras.
- No new audio assets in this task (submerge and emerge SFX need the audio attribution pipeline;
  file a follow-up). The low-pass filter needs no assets.

## Deliverable

1. **Camera medium state** (`UnderwaterPass`, updated every frame from `map_view_3d.gd`):
   - `surface_y = water_plane_y(camera.xz) + OceanFftSampler.height_at(camera.xz, ocean_time)`,
     where the plane is the recessed water mesh height plus the tide. It only counts over water
     cells: check the water coverage field.
   - `camera_depth = surface_y − camera.y`.
   - States: `AIR` (depth < −near_half_height·2), `STRADDLE` (|depth| ≤ near_half_height·2, where
     the near plane cuts the surface) and `UNDER`. Use a small hysteresis so the state doesn't
     flicker.
2. **Shared FFT include.** Move the WS-04 `_fft_sample` and decode, the wind rotation and the
   standing-wave blend into `ocean_fft_common.gdshaderinc`. The water shader includes it, with no
   behaviour change (the contract test proves it). The pass includes it for the per-pixel
   waterline.
3. **`underwater_pass.gdshader`** (spatial, unshaded, depth test off, a quad at the camera near plane
   like `map_fog_of_war`, drawn after the water). It reads the screen and depth textures. Per pixel:
   - **Classification.** Build the pixel's point on the near plane (`ndc.z = −1` on Compatibility)
     and evaluate the water height there with the shared FFT functions. The pixel is *underwater* if
     that point is below the surface. In `UNDER` everything is underwater. In `STRADDLE` this gives
     the wavy waterline across the lens. In `AIR` the node isn't drawn.
   - **Meniscus** (`STRADDLE`): within a band of `9 px` (Tidewater `band`) of the waterline, darken
     a thin line (about 2 px), and refract the screen sample vertically by up to 6 px to form the
     lens-water lip.
   - **Medium** (underwater pixels): `d_m` = the distance to the scene depth in metres (world
     units × 0.87), capped at 60 m for sky or infinite depth.
     `T = exp(−sigma_t · d_m)`, using the same per-channel `sigma_t` as WS-01.
     `inscatter = water_ambient · T_down(depth) + sun_col · T_down(depth) · HG(cos(view, sun_refracted), 0.75) · 0.15`,
     where `T_down(depth) = exp(−sigma_t · depth_m)` is the light lost on the way down, and
     `sun_refracted = refract(−sun, up, 1/1.333)` negated to point towards the light.
     `color = scene · T + inscatter · (1 − T)`.
   - **Caustics on submerged surfaces:** for underwater pixels whose depth-reconstructed world
     point is under the surface, multiply by `1 + caustic(p) · T_down(p) · k`, using the WS-07
     projection and tiles (one tile, 2 samples).
   - **Light shafts:** march 8 samples (4 on `minimum`) along the view ray up to
     `min(scene distance, 20 m)`. Jitter the start per pixel with interleaved gradient noise. At
     each sample `x`, take the caustic value at the surface entry point along the refracted sun ray
     (WS-07 projection with `h` = the depth of `x`), attenuated by `T_down(x)` and by `T` from `x` to
     the camera. Accumulate with the HG phase. Scale by `shafts` (Tidewater 1.0). This gives
     slanted shafts that flicker with the waves, not a radial blur.
4. **Water surface seen from below** (water shader, `!FRONT_FACING`):
   - The view ray inside the water is `V`, and `N` is the down-facing surface normal.
     `cos θ = dot(−V, up)`, and the critical angle is `acos(sqrt(1 − 1/1.333²))` ≈ 48.6°.
   - **Inside Snell's window:** refract `−V` out of the water (`refract(−V, −N, 1.333)`), sample
     `screen_texture` at a slightly distorted UV (the air scene behind), and scale by the Fresnel
     transmission. Brighten the rim of the window and add a small colour fringe (dispersion) at its
     edge.
   - **Outside the window:** total internal reflection. Output the underwater in-scatter colour
     (same formula as the pass) with a faint bed tint. It reads as a silver-green mirror.
   - Remove the P0-227 `camera_submerge` fog tint from the front-face path. The pass replaces it.
     Update the contract test, which should now assert the Snell's window branch and the absence of
     the old tint.
5. **Audio:** in `UNDER`, enable a `LowPassFilter` (cutoff about 700 Hz, resonance 0.5) on the
   world SFX bus and fade it in over 0.15 s. Fade it out on surfacing. Music is unaffected.
6. **Wet lens on surfacing** (Tidewater `LensParams wet/age`): for 2.5 s after an `UNDER` → `AIR`
   transition, overlay procedural droplets. Use a Voronoi cell mask that refracts the screen sample
   by 3–8 px, with a few droplets sliding down, all fading out. It runs in the same pass, which stays
   visible for those seconds. Only first-person and third-person cameras get this (not top-down).
7. **Capture helper** `tools/capture_underwater.gd`: loads a map, places the camera at a given
   world position and orientation (`--pos=x,y,z --look=x,y,z`), sets the weather and time, and
   warms up the frames. It runs like the R-715 capture tool, on a real renderer and never headless.

## Verification

1. The headless Godot suite passes. `test_underwater_pass.gd` checks:
   - state classification with hysteresis (synthetic heights)
   - the node is hidden in `AIR`
   - the bus effect is enabled only in `UNDER`
   - the wet-lens timer runs on surfacing
   - the pass is not created for interiors
   The water contract test checks the shared FFT include and the Snell's window branch.
2. The water shader refactor to the include changes no pixels: harbour `clear/day` captures before
   and after are identical.
3. Captures (`tools/capture_underwater.gd`, Metal and Compatibility) on `reval_harbor_north`:
   - **UNDER, looking horizontally** at the quay foundation, `clear/day`: distance fades to
     turquoise, caustics on the stones, and slanted shafts.
   - **UNDER, looking straight up:** a bright Snell's window with sky and quay silhouettes, and a
     mirror outside it.
   - **STRADDLE**, the camera at the surface: a wavy waterline split, the meniscus line, and air
     above it.
   - **UNDER at night:** very dark, no shafts or caustics.
   - **UNDER in a storm:** murkier, and shafts dimmed by `cloud_darken`.
   - A 10 s clip of dipping in and out, showing the wet lens and no state flicker.
4. Performance: in `UNDER`, the pass cost on `recommended` is ≤ 1.0 ms at 1080p, and on `minimum`
   it is ≤ 0.5 ms. In `AIR` the cost is 0 (the node is hidden).

## Documentation updates

- File a follow-up task for the submerge and emerge SFX (audio attribution pipeline).
- `TODO.md` row:
  ```text
  - [ ] WS-13 | deps: WS-01, WS-05, WS-07 | deliverable: UnderwaterPass (AIR/STRADDLE/UNDER from FFT camera height) screen pass with per-pixel FFT waterline and meniscus, Beer-Lambert medium with HG sun in-scatter, submerged caustics and marched light shafts; water back-face Snell's window with total internal reflection; SFX low-pass; wet lens on surfacing; P0-227 tint removed | allowed files: `scripts/map/view3d/underwater_pass.gd`, `scripts/map/view3d/underwater_pass.gdshader`, `scripts/map/view3d/ocean_fft_common.gdshaderinc`, `scripts/map/view3d/map_view_water.gdshader`, `scripts/map/view3d/map_view_3d.gd`, `audio/default_bus_layout.tres`, `tools/capture_underwater.gd`, `tests/godot/test_underwater_pass.gd`, `tests/godot/test_r715_water_material_contract.gd`, `docs/reports/images/ws13_*.png`, `TODO.md` | verify: state/bus/lens tests; include refactor pixel-identical; under/up/straddle/night/storm captures and dip clip; pass <= 1.0 ms under water and 0 in air
  ```
