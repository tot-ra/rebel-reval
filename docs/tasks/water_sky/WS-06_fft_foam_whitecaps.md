# WS-06 — Whitecaps that linger, from the baked foam channel

Part of the [water and sky task pack](README.md). Source technique: Tidewater `OceanParams`
foam accumulation (`foamBias 0.58`, `foamGain 3`, `foamDecay 0.35`, `foamAdd 2.5`),
`WaterSurfaceParams` (`foamCoverage 1`, `foamSharpness 2.2`, `foamScale 0.09`) and `SeaDetailParams`
(`gustAmount 1`, `slickAmount 1`, `streakAmount 0.3`).

## Player-facing goal

In fresh wind, whitecaps break on the steepest crests. They leave a patch of foam that stretches,
thins and fades over a few seconds as the wave moves on. Up close the foam looks like clusters of
bubbles, not a flat white smear. In a storm the sea is streaked with wind-aligned foam lines. On
calm days there are no whitecaps, only darker gust patches (catspaws) and glassy slicks crossing the
water.

## Why

Today's whitecaps (P0-223) come from the Gerstner Jacobian, which is evaluated twice (now and 0.42 s
earlier) to fake a trail. The foam colour is `mix(water_color, foam_color, foam)` with no texture.
WS-03 bakes true persistent foam per cascade into the disp alpha channel. This task makes it look
right.

## Allowed files

- `scripts/map/view3d/map_view_water.gdshader`
- `scripts/map/view3d/map_view_water_materials.gd`
- `tools/bake_ocean_fft.py` (add the `foam-tile` subcommand only)
- `tests/python/test_bake_ocean_fft.py` (a foam tile seamlessness test)
- `assets/water/ocean_fft/foam_tile.png` (+ `.import`), `assets/SOURCES.csv`
- `tests/godot/test_r715_water_material_contract.gd`
- `docs/reports/images/ws06_*.png`
- `TODO.md`

## Dependencies

- TODO: **WS-04** (FFT path live in the shader). WS-02 is recommended first, so foam gets its high
  diffuse share from `light()`.
- Stable IDs: none.

## WS-03 bake conventions (amended 2026-09-25)

WS-03 shipped in commit `3cc7967f` with deliberate deviations from its contract text; see
"Final parameters and decisions" in [WS-03](WS-03_fft_ocean_bake_tool.md) and the `conventions`
block of `ocean_fft_profile.json`. Three of them change this task:

1. **Foam is linear `0..1` in the `disp` alpha channel.** It does **not** use the signed
   `(v − 0.5)·2·scale` encoding that the RGB and `deriv` channels use, and it has no entry in
   `channel_scales`. Read the alpha raw.
2. **Each cascade's foam already carries full-sea statistics.** WS-03 had to make every cascade's
   foam loop with its own patch and period, so it scaled the foam Jacobian per cascade
   (`λ_c = λ₀·2·σ_total/σ_c`, giving C0 3.87 and C1 3.00). Each channel is therefore an estimate of
   the whitecaps of the *whole* sea, not of its own band. `w0·foam_c0 + w1·foam_c1` consequently
   roughly doubles the intended coverage, so **start `foam_coverage` at about 0.5** instead of 1.0
   and tune it on the captures. About 4% of texels generate foam per frame in the reference bake, so
   the reference sea should read as scattered whitecaps, not a covered sea.
3. **C2 has no foam and no disp atlas.** Only C0 and C1 contribute to the mask, as the formula in
   step 2 already assumes. C2 still exists as a derivative-only cascade for the gust/slick
   modulation in step 6.

The atlases are `CompressedTexture2DArray`: `sampler2DArray` in the shader, `TextureLayered` on the
GDScript side. The foam constants baked into the loop are `foamBias 0.58`, `foamGain 3`,
`foamDecay 0.35`, `foamAdd 2.5` at reference choppiness `λ₀ = 0.9`; they are fixed in the data and
cannot be retuned from the shader.

## Constraints and non-goals

- Shoreline breaker bands, edge foam and river current streaks stay as they are (WS-08 owns the
  shore).
- The Gerstner fallback path keeps the P0-223 Jacobian whitecaps unchanged.
- One extra texture only (the foam tile). Don't add another foam flipbook.

## Deliverable

1. **Foam tile generator** (`python3 tools/bake_ocean_fft.py foam-tile --out assets/water/ocean_fft/foam_tile.png --seed 1343`):
   256×256 RGBA8, tiling seamlessly (use periodic Worley and value noise). Channels:
   - R: bubble clusters. Inverted Worley F1 at two scales, thresholded into rims so it reads as
     bubbles.
   - G: fine speckle noise for breakup.
   - B: an elongated streak pattern (anisotropic noise stretched 6:1 along +X) for wind streaks.
   - A: 1.
   Import it with mipmaps and repeat, compressed lossless or as VRAM-compressed grey. It stays under
   300 KiB.
2. **Foam mask** on the FFT path, replacing the `_water_jacobian` call:
   ```glsl
   float mask = w0 * foam_c0 + w1 * foam_c1;            // baked alpha channels, linear 0..1, same frame blend
   mask *= storm_foam_coverage;                         // from apply_sea_weather (calm ≈ 0.2, storm ≈ 1.4)
   ```
   Sample the foam tile at the **undisplaced** `wave_sample_xz`, so the texture rides with the
   surface as it moves. Use two scales (`0.09 / 0.87` and 2.3× that) that drift slowly downwind:
   ```glsl
   float t = mix(tile_a.r, tile_b.r, 0.5) * mix(0.7, 1.0, tile_a.g);
   float foam_vis = clamp((mask * foam_coverage - (1.0 - t)) * foam_sharpness, 0.0, 1.0);
   ```
   `foam_sharpness` should be 2.2, and `foam_coverage` starts at about **0.5** as uniforms - not
   Tidewater's 1.0, because the two cascade channels double-count the same whitecaps (amendment 2).
   Tune it on the `overcast/day` capture and record the final value in the code comment.
3. **Fresh vs old foam.** The baked value decays over time, so a high mask means fresh foam and a
   low mask means old foam. Fresh foam is bright, opaque and rough. Old foam is thinner, bluish and
   partly *under* the surface: tint it towards `mix(shallow_color, foam_color, 0.4)` at about 50%
   opacity. This gives the translucent trailing foam that sells Tidewater's sea.
4. **Foam lighting.** Write the foam into `ALBEDO`. Raise the WS-02 `diffuse_share` to about 0.9 and
   the roughness to about 0.6 where `foam_vis` is high, and suppress the sky reflection weight by
   `(1 − foam_vis)`. Without WS-02, set `ROUGHNESS`/`SPECULAR` accordingly. Foam must dim at night
   together with the lighting, not glow.
5. **Wind streaks (storm only).** `streak = tile.b` sampled in wind-aligned UVs (rotate by the wind
   angle, stretch 1:6). Add `streak_amount · storm_intensity · smoothstep(0.1, 0.5, mask_blurred)`,
   where `mask_blurred` samples the foam mask at a coarser mip, so streaks connect whitecaps.
   `streak_amount` should be 0.3.
6. **Gusts and slicks (all weather).** A large, slowly drifting noise field (about 60 world units,
   moving at the wind speed) multiplies the C2 weight and the detail normal strength between
   `1 − slick_amount·0.6` (glassy slick) and `1 + gust_amount·0.4` (catspaw). This is the cheapest
   big improvement for calm days. It breaks the uniform ripple texture into moving dark and light
   patches.
7. The crest subsurface glow (P0-224) stays, but it is fed from the WS-04 `crest` term and dimmed
   under fresh foam.

## Verification

1. The Python test covers the foam tile's seamlessness (edges wrap within 1/255) and determinism.
2. The headless Godot suite passes. The contract test asserts that the FFT path contains no
   `_water_jacobian(` call, that `foam_tile` is sampled at `wave_sample_xz`, and that the foam mask
   reads the `disp` alpha without the signed decode (amendment 1).
3. Captures (Metal and Compatibility), harbour and open coast:
   - `clear/day`: there are few or no whitecaps, and gust and slick patches are visible.
   - `overcast/day`: scattered whitecaps with trailing thin foam.
   - `storm/day`: frequent whitecaps and wind-aligned streaks running along the wind heading.
   - `storm/night`: foam is dim, not emissive.
   - A close-up at the nearest gameplay zoom shows the foam has bubble structure.
4. The foam must not swim: a foam patch follows its wave. Check in a 10 s clip.
5. Performance: add at most 2 texture samples per fragment. Rerun `tools/run_performance_report.sh --quick`.

## Documentation updates

- `assets/SOURCES.csv` row for `foam_tile.png`.
- `TODO.md` row:
  ```text
  - [ ] WS-06 | deps: WS-04 | deliverable: FFT-path whitecaps from baked persistent foam with a seamless bubble foam tile, fresh/old foam shading, storm wind streaks, and gust/slick modulation; Gerstner Jacobian foam kept only on fallback | allowed files: `scripts/map/view3d/map_view_water.gdshader`, `scripts/map/view3d/map_view_water_materials.gd`, `tools/bake_ocean_fft.py`, `tests/python/test_bake_ocean_fft.py`, `assets/water/ocean_fft/foam_tile.png`, `assets/SOURCES.csv`, `tests/godot/test_r715_water_material_contract.gd`, `docs/reports/images/ws06_*.png`, `TODO.md` | verify: foam tile seam test; contract test; clear/overcast/storm/storm-night captures and a 10 s clip show lingering, textured, wind-streaked foam that rides its wave
  ```

## Final parameters and decisions (2026-09-25, R-891)

Evidence: `docs/reports/images/ws06_*.png` from `tools/capture_ws06_whitecaps.gd` (Metal and
Compatibility; harbour basin and east coast; `--close --aim=` for the bubble close-ups and `--clip`
for a 10 s strip at 1 s steps).

1. **Foam tile.** `python3 tools/bake_ocean_fft.py foam-tile --out assets/water/ocean_fft/foam_tile.png --seed 1343`,
   256x256 RGBA8, 183 KiB, imported lossless with mipmaps. R is two periodic Worley layers (22 and
   51 cells) with bright rims, a dim core and a foam film where cells meet, grouped by a
   low-frequency cluster envelope (mean 0.40). G is value-noise speckle. B is ridged value noise on
   a 4x24 lattice (6:1 along +X) with a gentle cross-wind warp. Every channel is exactly periodic
   in tile space, so the Python test checks the wrap at u = 1 and v = 1.
2. **Mask.** The shared include returns three foam terms per vertex: the weighted mask
   `w0*a0 + w1*a1` (raw alpha, no signed decode), freshness `max(a0, a1)` and the C0 share. The
   fragment adds exactly two foam-tile samples (both scales, in the wind frame at the undisplaced
   `wave_sample_xz`).
3. **Coverage.** `foam_coverage` is 1.0, not 0.5: the capped mask needed the full value for
   scattered overcast whitecaps. `storm_foam_coverage` comes from the sea-state table (calm 0.2,
   reference 0.8, storm 1.8; the storm regime at sea 0.79 gets 1.62, overcast 1.03, clear 0.2).
   The effective mask is capped at 1.0 (`FOAM_MASK_CAP`) so even storm foam keeps bubble holes.
4. **Fresh vs old.** Freshness is `smoothstep(0.35, 0.8, max(a0, a1) * storm_foam_coverage)`: the
   bake only broke where the reference sea broke, so a rougher sea also lowers the bar for foam to
   count as freshly broken. Old foam is `mix(shallow_color, foam_color, 0.4)` at 60% under the
   sky reflection. A trail term (`smoothstep(0.06, 0.3, mask)` over the brightest bubble rims)
   keeps the decayed tail of the bake visible for its 3-4 s instead of about 1 s.
5. **Lighting.** WS-02 has not landed, so fresh foam sets `ROUGHNESS` 0.6 and `SPECULAR` 0.1,
   removes the sky reflection and sun glint under it, and dims the crest glow. Foam is only in
   `ALBEDO`, so the storm/night plates show it dim, not emissive.
6. **Streaks.** `streak_amount` is 0.6: at 0.3 the lines disappeared under the storm sky
   reflection. The link uses the C0 foam share (`smoothstep(0.02, 0.3, ...)`) instead of a coarser
   mip because the disp atlases import without mipmaps. Streaks are laid on as surface foam.
7. **Gusts and slicks.** A wind-frame value-noise field (60 units, periodic every 16 cells along
   the wind, drifting ~2.3 units/s) scales the C2 ripple cascade and the detail normal between 0.4
   and 1.4. From the steep gameplay camera that alone barely changes a uniform sky, so, like
   `ripple_sheen`, the gain also scales the sky reflection weight and darkens catspaws slightly.
8. **Seamless drift.** Foam tiles drift 40 and 100 tiles and the gust field 64 cells per
   1638.4 s ocean-clock wrap, so the wrap never pops. The contract test pins those constants.
9. **Scope additions:** `scripts/map/view3d/ocean_fft_common.gdshaderinc` (foam terms and the C2
   gain; the UnderwaterPass keeps calling `_fft_displacement` / `_fft_normal` unchanged), the
   capture tool and this contract.

## WS-06b Compatibility vs Metal coverage (2026-09-26, R-907)

Storm/day harbour plates at `--ocean-time=6` disagreed: Metal showed broad foam fields,
Compatibility only small patches. Overcast plates were closer. Debug `--debug-foam-mask`
writes `fft_foam.x` to ALBEDO/EMISSION so lighting cannot hide the mask.

**Cause.** Two Compatibility bugs stacked. A vertex `fft_foam` varying sampled the
`CompressedTexture2DArray` disp atlases: RGB displacement still looked right, but the
alpha was not trustworthy. Moving the sample to `fragment()` kept the same blob
*shapes* on both renderers and did not close the coverage gap. Compatibility also
sRGB-decodes those 8-bit atlas alphas (no `source_color` hint). Foam is stored
linear 0..1 (WS-03), so mid-tones collapsed and storm `foam_mask` rarely cleared
the tile threshold.

**Fix.** `_fft_foam_terms()` resamples the same raw C0/C1 alpha (and the standing-train
mix) in `fragment()`. `_compat_stored_alpha()` restores the stored texel with the
Godot linear-to-sRGB curve when `OUTPUT_IS_SRGB`. Foam-tile samples stay at two.
`debug_foam_mask` stays off in play.

**Evidence.** `docs/reports/images/ws06b_*` from `tools/capture_ws06_whitecaps.gd`
`--prefix=ws06b` (beauty) and `--debug-foam-mask` (unlit mask). Storm and overcast
day harbour, Metal and `--rendering-driver opengl3`, `--ocean-time=6`. Water-crop
mask mean luminance: storm 9.9 percent, overcast 3.3 percent (contract 10 percent).
