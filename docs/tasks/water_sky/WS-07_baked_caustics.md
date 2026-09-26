# WS-07 — Caustics derived from the FFT, projected onto the real bed

Part of the [water and sky task pack](README.md). Source technique: Tidewater `caustics` module
(two baked tiles, `causticsFineTex` and `causticsBroadTex`, sampled with stretched gradients by
`_causticsStretch` so they don't shimmer, `CausticsParams.strength 0.75`), plus its underwater
`causticsSample`.

## Player-facing goal

On a sunny day, shallow water shows a bright moving net of light on the sand and stones under it.
The net is sharp in ankle-deep water and wide and soft deeper down. It slides with the waves,
leans with the sun angle, fades under clouds and at dusk, and sits on the actual bed and quay foot.
It doesn't look painted onto the water surface.

## Why

`_bed_caustics()` is a sine lattice evaluated at the **surface** position
(`water_world_position.xz`) and added after extinction as `highlight_color`. Its scale doesn't
depend on depth, sun angle or the waves. It reads as a pattern on the water, not light on the floor.

## Allowed files

- `tools/bake_ocean_fft.py` (add the `caustics` subcommand)
- `tests/python/test_bake_ocean_fft.py`
- `assets/water/ocean_fft/caustics_fine.png`, `assets/water/ocean_fft/caustics_broad.png`
  (+ `.import`), `assets/SOURCES.csv`
- `scripts/map/view3d/map_view_water.gdshader`
- `scripts/map/view3d/map_view_water_materials.gd`
- `tests/godot/test_r715_water_material_contract.gd`
- `docs/reports/images/ws07_*.png`
- `TODO.md`

## Dependencies

- TODO: **WS-01** (bed world position and refracted column) and **WS-03** (FFT spectrum code to
  reuse). WS-04 isn't required. Caustics use their own tiles, so this also works on the Gerstner
  path.
- Unlocks: WS-13 reuses these tiles for underwater light shafts and caustics on submerged surfaces.

## Constraints and non-goals

- Two static tiles. Don't add a caustic flipbook. The motion comes from scrolling two layers.
- Tiles are under 1 MiB each. Store them as single-channel data in R, imported lossless with
  mipmaps and repeat.
- No caustics on above-water walls from reflected light (a possible follow-up, not this task).

## Deliverable

### A. Bake (`python3 tools/bake_ocean_fft.py caustics --out assets/water/ocean_fft --seed 1343`)

Compute a physically based caustic pattern from a height field with the photon area-ratio method:

1. Build a periodic height field from the WS-03 spectrum code, one frame only:
   - *fine*: 4 m … 0.5 m band, patch 4 m, N = 512
   - *broad*: 16 m … 2 m band, patch 16 m, N = 512
2. For each surface texel, refract a vertical sun ray (`refract((0,−1,0), n, 1/1.333)`) and intersect
   it with a flat bed at depth `d` (fine: `d = 1.2 m`, broad: `d = 4 m`). This gives a landing
   offset `o(x) = d·(T.xz / −T.y)`.
3. Splat each texel's energy onto the landing position in a periodic histogram at the same
   resolution, using bilinear splatting so it stays periodic. This is more robust than the analytic
   `1/|det J|` because it has no infinities at the focus lines.
4. Blur with a 1-texel Gaussian. Normalise so the mean is 1.0, clamp to `[0, 4]`, and store
   `v/4` in 8-bit R. Record the scale in `ocean_fft_profile.json` (`caustics` block: patch sizes,
   depths, scale).
5. The tiles must wrap seamlessly (test it) and the bake must be deterministic.

### B. Shader

1. **Project onto the bed along the refracted sun.** Use WS-01's `bed_world` and vertical column `h`:
   ```glsl
   vec3 Ts = refract(-normalize(sun_direction), vec3(0.0, 1.0, 0.0), 1.0 / WATER_IOR); // points down
   vec2 entry_xz = bed_world.xz - Ts.xz * (h / max(-Ts.y, 0.2));
   ```
   Sample the tiles at `entry_xz · 0.87 / patch_m` (world units to tile UV). The pattern now leans
   and stretches with a low sun and sits on the real bed.
2. **Motion.** Use two samples per tile, scrolling along ±wind at different speeds, and combine them
   with `min(a, b)`. The classic cross-scroll gives moving caustic lines without a flipbook. With
   WS-04 live, also offset the UVs by the local FFT slope × `h × 0.3`, so passing swells visibly
   bend the net.
3. **Depth focus.** Blend fine to broad with `smoothstep(0.6, 3.0, h_m)`. Blur with depth by choosing
   the mip level `lvl = log2(1.0 + h_m·1.5)`. Sample with `textureGrad` using stretched gradients
   (port `_causticsStretch`):
   ```glsl
   vec2 stretch(vec2 g, float min_len) { return g * max(min_len / max(length(g), 1e-9), 1.0); }
   // min_len = exp2(lvl) / TILE_RES
   ```
   This removes the shimmer at the isometric grazing angle.
4. **Dispersion.** Sample R, G and B with UV offsets of `±h_m·0.004` along the sun direction, so
   deep caustic edges get faint colour fringes. On the `minimum` quality tier, use one sample.
5. **Energy and gating.**
   `light_down = exp(-sigma_t · h_m / max(-Ts.y, 0.2))` (the light's own path down the column).
   `caustic = (c − 1.0) · caustic_strength · light_down · sun_visibility_gate · (1 − cloud_darken·0.85)`.
   `caustic_strength` should be about 0.75. Keep the wider `twilight_water_light` envelope that is
   already there as the sun gate.
6. **Apply it as light on the bed**, before extinction: `seabed *= 1.0 + caustic`. Delete the
   `water_color += highlight_color * caustics …` line and the old `_bed_caustics` function.

## Verification

1. Python tests: tile seams wrap, the mean is 1.0 ± 0.01, the bake is deterministic, and the
   histogram conserves energy (the sum before splatting equals the sum after).
2. The headless Godot suite passes. The contract test asserts that `_bed_caustics` is gone and that
   the caustic sample uses `textureGrad`.
3. Captures (Metal and Compatibility), shallow harbour edge:
   - `clear/day` at noon: a sharp net in the shallows that widens and softens with depth.
   - `clear/day` near sunset: the net stretches away from the sun and dims.
   - `overcast/day`: faint or none.
   - `clear/night`: none.
   - An orbit of the camera doesn't make the pattern shimmer or alias. Record a short clip.
4. Performance budget per fragment:
   - `recommended`: 2 tiles × 2 scroll layers = 4 samples. Dispersion samples only the dominant
     tile's two layers for the R and B offsets (+4), for at most **8** in total.
   - `minimum`: the dominant tile only, 2 scroll layers, no dispersion (**2** samples).
   Report the frame-time change from `tools/run_performance_report.sh --quick`.

## Documentation updates

- `assets/SOURCES.csv` rows for both tiles.
- `TODO.md` row:
  ```text
  - [ ] WS-07 | deps: WS-01, WS-03 | deliverable: photon-splat caustic tiles (fine/broad) baked from the FFT spectrum and applied as bed light along the refracted sun ray with depth focus, anisotropic-safe gradients, dispersion and cloud/sun gating; sine-lattice caustics removed | allowed files: `tools/bake_ocean_fft.py`, `tests/python/test_bake_ocean_fft.py`, `assets/water/ocean_fft/caustics_fine.png`, `assets/water/ocean_fft/caustics_broad.png`, `assets/SOURCES.csv`, `scripts/map/view3d/map_view_water.gdshader`, `scripts/map/view3d/map_view_water_materials.gd`, `tests/godot/test_r715_water_material_contract.gd`, `docs/reports/images/ws07_*.png`, `TODO.md` | verify: tile seam/energy tests; contract test; noon/sunset/overcast/night captures and an orbit clip show a depth-focused, sun-leaning, shimmer-free caustic net on the bed
  ```

## Final parameters and decisions (2026-09-26)

Implementation: `tools/bake_ocean_fft.py caustics`, `_bed_caustic_gain()` in
`scripts/map/view3d/map_view_water.gdshader`, `_apply_caustic_uniforms()` in
`scripts/map/view3d/map_view_water_materials.gd`. Plates: `docs/reports/images/ws07_*.png` from
`tools/capture_ws07_caustics.gd` (fishing-harbour beach shelf of `reval_harbor_east`).

1. **Bands extended to the focusing ripples.** With the contract's short ends (fine 0.5 m, broad
   2 m) the reference Baltic sea does not focus at 1.2 m / 4 m: the splat histogram's std is 0.18
   / 0.15, a faint mottle. The short ends are 0.12 m (fine) and 0.5 m (broad); long ends, patches,
   N and bed depths are as specified. Stored std is 0.79 / 0.71.
2. **Metadata in `assets/water/ocean_fft/caustics_profile.json`**, not in
   `baltic_reference/ocean_fft_profile.json`: the cascade bake owns and `--check`s that file, and
   the tiles live one level up. `--check` works for the caustics subcommand too.
3. **Cross-scroll normalisation.** `min(a, b)` of two layers has mean 0.62 (fine) / 0.66 (broad),
   which would darken every bed by a third. The bake records `min_pair_mean` and the shader
   divides it out; `MapViewWaterMaterials.CAUSTIC_MIN_PAIR_MEAN` mirrors it (contract test).
   Layer B is layer A rotated 90 degrees, which keeps the tile exactly periodic.
4. **Apparent depth.** The gameplay water column is centimetres; `sigma_t` is already art-scaled
   ~15x. The focus and the tile projection use `h_m = column * 0.87 * 15` (terrain optical floors
   0.075..0.38 units become ~1..5 m); `light_down` uses the real column, like the view path.
5. **Art knobs (ADR 0018).** `caustic_pattern_scale = 3.0` magnifies the tiles: the physical
   0.1-0.3 m net cell is 4-5 px at the gameplay camera and the depth mip blur erased it.
   `caustic_strength = 2.8`, not 0.75: ALBEDO still mixes in the art-weighted sky reflection
   (>= 0.34 + Fresnel), so 0.75 left a +-4/255 net at clear noon; 2.8 x the clear-sky gate 0.70
   is ~2.0 effective. Revisit both when WS-11 moves the reflection out of ALBEDO. The gain is
   floored at 0.35 so dark cells keep their skylight, and dispersion is blended in at 35% because
   the 1-2 texel lines otherwise split into a rainbow.
6. **Sun and cloud gate.** `(1 - cloud_darken * 0.85)` has no effect today: `MapViewLighting`
   never pushes `cloud_darken` (nor `sunset_factor`) to the water, so both stay 0 (follow-up for
   WS-11). The gate is `twilight_water_light x direct_share^2 x sun_reflection_visibility`, where
   `direct_share = smoothstep(0, 0.7, sun.y)` (skylight takes over the bed at dusk; zero at night)
   and `sun_reflection_visibility` is sun disk x (1 - cloud coverage): 0.70 clear, 0.02 overcast.
7. **Footprint stretch.** Besides the entry-point lean, the tile coordinate along the sun azimuth
   is compressed by cos(theta_t), so a low sun elongates the net away from the sun.

Evidence:

- Compatibility (shipping renderer), mean |on - off| luminance on the plate: clear noon 2.47/255
  (p99 25), sunset 0.48, overcast 0.07, night 0 by construction. Metal draws the same net weaker
  (0.84 at noon) because its water already shows less bed (pre-existing renderer difference).
- `ws07_*_clear_noon_o70.png`: no shimmer or aliasing after a 70 degree orbit.
  `ws07_opengl3_clear_clip_sheet.png`: frames 0/5/10/15 of a 16-frame, 1/15 s clip; mean
  frame-to-frame luminance change 0.0056 with caustics vs 0.0021 without (smooth drift, no strobe).
- `ws07_opengl3_clear_noon_minimum.png`: the `minimum` tier (dominant tile, 2 samples) still draws
  the net.
- The coloured mottle on the Compatibility sunset plates is in the caustics-off plate too
  (`ws07_opengl3_clear_sunset_off.png`); it is not from WS-07.
- Quick performance report A/B on the same tree (M5 Pro, Lower Town scene): caustics off p95
  15.19 ms / median 8.80 ms, on 14.70 / 8.91 ms. The cost is inside run-to-run noise; one on-run
  hit 17.43 ms p95 from a single hitch (median 8.75).
