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
