# WS-03 — Offline FFT ocean bake tool (looping JONSWAP cascades)

Part of the [water and sky task pack](README.md). Source technique: Tidewater `OceanParams`,
`jonswap()`, `tmaCorrection()`, `directionSpectrum()` and `normalisationFactor()` (itself based on
Horvath 2015, *Empirical directional wave spectra for computer graphics*, and Tessendorf 2001).

## Player-facing goal

None directly. This task produces the data that WS-04 through WS-07 display. Once those land, the
Baltic in the harbour gets real ocean wave statistics: many overlapping wave trains of different
lengths travelling mostly downwind, crests that group and fade, and no visible repeating
four-wave pattern.

## Why a bake

The GL Compatibility renderer has no compute shaders, so we can't run Tidewater's GPU FFT per frame.
A deep-water FFT ocean becomes **exactly periodic in time** if every wave frequency ω is rounded to a
multiple of `ω₀ = 2π / T`. We can therefore bake one loop of *T* seconds into a flipbook of frames
and play it back forever with no seam. The pattern tiles in space by construction (FFT patches are
periodic), and it loops in time because of the rounding.

## Allowed files

- `tools/bake_ocean_fft.py` (new)
- `tests/python/test_bake_ocean_fft.py` (new)
- `assets/water/ocean_fft/baltic_reference/*` (new: PNG atlases, `ocean_fft_profile.json`, and
  Godot `*.import` sidecars created by the editor import)
- `assets/SOURCES.csv` (rows for every generated image)
- `docs/tasks/water_sky/WS-03_fft_ocean_bake_tool.md` (only to record final chosen parameters)
- `TODO.md`

## Dependencies

- TODO: none.
- Python: `numpy` (2.x is installed locally) and `Pillow`. Add no other dependencies.

## Constraints and non-goals

- Deterministic: the same arguments and `--seed` must produce byte-identical PNGs. Use
  `numpy.random.default_rng(seed)`, and write PNGs with fixed compression and no timestamps.
- Every output file must be **under 10 MiB** (the storage policy's standard Git limit). Fail the bake
  if one isn't.
- No runtime code in this task. The shader integration is WS-04.
- Units inside the tool are **SI metres and seconds**. Metres-to-world-units conversion (×1/0.87)
  happens in the shader. The profile JSON records `meters_per_world_unit: 0.87` for reference only.

## Physics to implement

All formulas come from Tidewater's WGSL (which follows Horvath 2015). `g = 9.81`, and the depth `h` is
a profile parameter (Reval harbour default 20 m).

1. **Dispersion (finite depth):** `ω(k) = sqrt(g·k·tanh(min(k·h, 20)))`.
   Derivative: `dω/dk = g·(h·k/cosh²(kh) + tanh(kh)) / (2·ω)`.
2. **TMA shallow-water correction:**
   `ωh = ω·sqrt(h/g)`. The factor is `0.5·ωh²` if `ωh ≤ 1`, `1 − 0.5·(2 − ωh)²` if `ωh < 2`,
   and `1` otherwise.
3. **JONSWAP:**
   `α = 0.076·(U²/(F·g))^0.22`, `ωp = 22·(g²/(U·F))^(1/3)`, `γ = 3.3`,
   `σ = 0.07 if ω ≤ ωp else 0.09`, `r = exp(−(ω−ωp)² / (2σ²ωp²))`,
   `S(ω) = scale · TMA(ω) · α·g²/ω⁵ · exp(−1.25·(ωp/ω)⁴) · γ^r`.
   `U` is the wind speed at 10 m (m/s) and `F` is the fetch (m).
4. **Directional spreading** (Horvath / Tidewater `directionSpectrum`):
   `s = 16·tanh(ωp/ω)·swell²` (swell ∈ [0,1], 0 = pure wind sea).
   `D(θ) = normalisationFactor(s)·|cos(θ/2)|^(2s)`, blended with a cosine-squared term by
   `spread_blend`. Port `normalisationFactor(s)` exactly (piecewise quartic polynomial, split at
   s = 5):
   ```text
   s < 5 : -0.000564 s⁴ + 0.00776 s³ - 0.044 s² + 0.192 s + 0.163
   else  : -4.80e-08 s⁴ + 1.07e-05 s³ - 9.53e-04 s² + 5.90e-02 s + 3.93e-01
   ```
   Measure θ from the wind direction. The bake uses wind along +X. The runtime rotates the lookup
   (WS-04), so one bake serves every wind heading.
5. **Short-wave damping:** multiply by `exp(−k²·l²)` with `l = 0.01 m`.
6. **Initial spectrum per cascade texel** (Tessendorf):
   `h₀(k) = (ξr + i·ξi)/√2 · sqrt(2 · S(ω)·D(θ)·(dω/dk)/k · Δk²)`, with `Δk = 2π/L`, and ξ standard
   normal from the seeded RNG. Set `h₀ = 0` outside this cascade's band `[k_low, k_high)` (Tidewater
   `cuts`), so the cascades never add the same wavelength twice.
7. **Rounded frequency (the loop trick):** `ω_q = round(ω / ω₀)·ω₀`, with `ω₀ = 2π/T_c` for this
   cascade's loop period `T_c`. Any component that rounds to 0 is dropped.
8. **Time evolution:** `h(k,t) = h₀(k)·e^{iω_q t} + conj(h₀(−k))·e^{−iω_q t}`.
   With `i` the imaginary unit and `k̂ = k/|k|`:
   - height `Dy = IFFT(h)`
   - horizontal displacement `Dx = IFFT(−i·k̂x·h)`, `Dz = IFFT(−i·k̂z·h)` (choppiness λ = 1 is baked;
     λ is applied at runtime)
   - slopes `∂Dy/∂x = IFFT(i·kx·h)`, `∂Dy/∂z = IFFT(i·kz·h)`
   - `∂Dx/∂x = IFFT(kx²/|k|·h)`, `∂Dz/∂z = IFFT(kz²/|k|·h)`, `∂Dx/∂z = IFFT(kx·kz/|k|·h)`
   Use `numpy.fft.ifft2` with the correct `fftshift` and sign convention. Assert that the imaginary
   parts are below 1e-5 of the real peak.
9. **Baked persistent foam** (Tidewater `foamBias 0.58`, `foamGain 3`, `foamDecay 0.35`,
   `foamAdd 2.5`). The loop is periodic, so its steady-state foam is periodic too. Simulate **two**
   loops and keep the second:
   ```text
   J   = (1 + λ₀·∂Dx/∂x)(1 + λ₀·∂Dz/∂z) − (λ₀·∂Dx/∂z)²        λ₀ = 0.9 (reference choppiness)
   gen = clamp((foam_bias − J)·foam_gain, 0, 1) · foam_add · dt
   foam_n = clamp(foam_{n−1}·exp(−foam_decay·dt) + gen, 0, 1)
   ```
   Check that `max|foam(frame 0) − foam(after loop 2)| < 1/255`. If it isn't, run a third loop.

## Cascade layout (defaults; the tool takes them as arguments)

The flipbook plays back by blending adjacent frames. The shortest wave in a cascade therefore needs
**at least 8 frames per period**, or its amplitude visibly pulses when the blend is halfway between
frames (at 8 frames per period the dip is ≤ 8%). The tool must enforce
`T_c / frames ≤ (2π/ω(k_high)) / 8` and exit non-zero if it fails.

| Cascade | Patch L (m) | N | Band (wavelength) | Shortest period | Loop T_c | Frames | Use |
|---|---|---|---|---|---|---|---|
| C0 | 128 | 128 | 128 m … 16 m | 3.2 s | 25.6 s | 64 | vertex displacement + normals + foam |
| C1 | 32 | 128 | 16 m … 4 m | 1.6 s | 12.8 s | 64 | vertex displacement + normals + foam |
| C2 | 8 | 64 | 4 m … 1 m | 0.8 s | 6.4 s | 64 | fragment normals only |

Waves shorter than 1 m stay on the existing procedural detail normal (`_water_detail_normal`).
`T0 = 2·T1 = 4·T2`, so the combined sea repeats every 25.6 s with no drift between cascades.

**Reference sea state** `baltic_reference`: `U = 9 m/s`, `F = 40 km` (Tallinn Bay scale),
`h = 20 m`, `swell = 0.25`, `spread_blend = 0.85`, `seed = 1343`. Storm and calm are **runtime
scalings** of this one bake (per-cascade weights and choppiness in WS-04). Don't bake several sea
states unless WS-04 review shows the scaling looks wrong.

## Output format

Per cascade, write two **vertical-strip atlases** (frame *f* is rows `f·N … f·N+N−1`), RGBA 8-bit PNG:

- `cN_disp.png`: R = Dx, G = Dy, B = Dz, A = foam. C2 has no disp file.
- `cN_deriv.png`: R = ∂Dy/∂x, G = ∂Dy/∂z, B = ∂Dx/∂x, A = ∂Dz/∂z.

Encoding: `byte = round(clamp(0.5 + v / (2·scale), 0, 1)·255)`, where `scale` is the 99.9th
percentile of |v| per channel per cascade. Record every scale in `ocean_fft_profile.json`.
Values outside the percentile saturate, and that's intended.

`ocean_fft_profile.json` holds: tool version, CLI arguments, seed, g, depth, the JONSWAP numbers
(α, ωp, γ), `meters_per_world_unit`, per cascade `{patch_m, n, k_low, k_high, period_s, frames,
channel_scales, files{name: sha256}}`, and the measured significant wave height
`Hs = 4·sqrt(var(Dy_total))`.

**Godot import settings** (record them in the `.import` sidecars): import as `Texture2DArray`,
`slices/vertical = frames`, `compress/mode = Lossless`, `mipmaps/generate = true` for `deriv` and
`false` for `disp`. Budget: about 18 MiB of VRAM for all five atlases.

## CLI

```bash
python3 tools/bake_ocean_fft.py --profile baltic_reference \
    --out assets/water/ocean_fft/baltic_reference            # bake
python3 tools/bake_ocean_fft.py --profile baltic_reference --check   # re-bake to a temp dir, compare sha256, exit 1 on drift
python3 tools/bake_ocean_fft.py --profile baltic_reference --preview build/ocean_fft_preview.png
```

`--preview` writes a contact sheet (height of frames 0, 16, 32 and 48 per cascade, plus foam) for
review. Keep it out of `assets/`.

## Verification

1. `python3 -m unittest tests.python.test_bake_ocean_fft -v` passes. Use a small N (32) and few
   frames so it runs in under 10 s. It must test:
   - **Time periodicity:** evaluating at `t = T_c` equals `t = 0` to within 1e-6.
   - **Spatial periodicity:** the first and last columns and rows wrap continuously.
   - **Real output:** the imaginary residue is below 1e-5.
   - **Energy:** with `--unit-amplitude` (a test-only flag that uses |ξ| = 1 and a random phase, so
     there is no statistical noise), measured `Hs` matches `4·sqrt(Σ S·D·(dω/dk)/k·Δk²)` over the
     band to within 2%.
   - **Frame-rate guard:** too few frames raises `SystemExit` with a clear message.
   - **Determinism:** two bakes produce identical bytes.
   - **Foam loop:** the frame-0 and end-of-loop foam differ by less than 1/255.
2. The full bake runs in under 2 minutes on a laptop, every file is under 10 MiB, and
   `python3 tools/bake_ocean_fft.py --profile baltic_reference --check` exits 0.
3. `python3 tools/validate_asset_sources.py`, `python3 tools/verify_storage_hygiene.py` and
   `python3 tools/verify_asset_lint.py` pass. Add SOURCES rows with `creator_or_tool` =
   `tools/bake_ocean_fft.py`, `seed` = 1343, `license` = AGPL-3.0-or-later (project author), and
   the CLI arguments in `edits`.
4. Open the editor once, confirm the atlases import as `Texture2DArray` with 64 layers, and commit
   the sidecars.
5. Attach the `--preview` contact sheet to the review. Crests should be visibly sharper than troughs
   once choppiness is applied in WS-04. In the raw bake, check that wave trains run mostly along +X
   and the foam sits on crests.

## Documentation updates

- `assets/SOURCES.csv` rows.
- Record the final parameters in this file if they differ from the defaults above.
- `TODO.md` row:
  ```text
  - [ ] WS-03 | deps: none | deliverable: deterministic tools/bake_ocean_fft.py baking three band-split, time-looping JONSWAP/TMA FFT cascades (disp+foam, derivatives) into Texture2DArray PNG atlases with a profile manifest | allowed files: `tools/bake_ocean_fft.py`, `tests/python/test_bake_ocean_fft.py`, `assets/water/ocean_fft/baltic_reference/*`, `assets/SOURCES.csv`, `TODO.md` | verify: python unittest (periodicity, energy, determinism, foam loop); --check exits 0; storage/provenance/asset-lint validators pass; atlases import as 64-layer arrays
  ```

## Final parameters and decisions (implemented 2026-09-25)

The reference bake uses the default cascade layout and sea state above (`seed = 1343`).
Measured result: `Hs = 1.26 m` total (C0 1.13 m, C1 0.53 m, C2 0.16 m), which matches the
analytic JONSWAP integral for `U = 9 m/s`, `F = 40 km`. Full bake takes about 1.5 s; the largest
atlas is about 2 MiB. Four deliberate deviations from the text above, each recorded in
`ocean_fft_profile.json` and commented in `tools/bake_ocean_fft.py`:

1. **Amplitude normalisation.** `h0 = ξ·sqrt(E/2)` with `E|ξ|² = 1`, so the time-averaged spatial
   variance equals the band energy `Σ S·D·(dω/dk)/k·Δk²` and `Hs = 4·sqrt(m0)`. This is what the
   energy test above requires. The literal Tidewater form `ξ/√2·sqrt(2E)` is 2x taller; WS-04
   per-cascade weights own any art scaling.
2. **Displacement sign.** `D = IFFT(+i·k̂·h)` and the surface point is `x' = x + λ·D`, so crests
   compress and the Jacobian drops below 1 on crests (Horvath/Acerola convention). The `−i` sign in
   step 8 compresses troughs and would put foam in the troughs. The derivative channels follow:
   `∂Dx/∂x = IFFT(−kx²/|k|·h)`, `∂Dz/∂z = IFFT(−kz²/|k|·h)`, `∂Dx/∂z = IFFT(−kx·kz/|k|·h)`.
   **WS-04 must add `+λ·D`.**
3. **Directional spreading.** `s` includes Horvath 2015's Hasselmann base term
   (`6.97·(ω/ωp)^4.06` below the peak, `9.77·(ω/ωp)^(−2.33−1.45(U·ωp/g−1.17))` above) plus the
   swell term. The swell-only `s` stays below 1 for the reference sea and baked isotropic blobs
   instead of downwind wave trains. The `cos²` lobe is restricted to `|θ| ≤ π/2` so it integrates to 1
   like the Horvath lobe (`∫D dθ = 1` is unit-tested).
4. **Foam Jacobian choppiness.** Whitecaps come from the summed sea, but each cascade's foam must loop
   with its own patch and period. The foam Jacobian therefore uses
   `λ_c = λ₀ · 2 · σ_total/σ_c`, where `σ` is the std of `∂Dx/∂x + ∂Dz/∂z` (bands are independent,
   so variances add) and 2 is the Tidewater amplitude equivalence the foam constants were tuned for.
   With `λ₀ = 0.9` alone the reference sea bakes no foam at all. Resulting `λ_c`: C0 3.87, C1 3.00,
   C2 2.77; about 4% of texels generate foam per frame. C2 foam is simulated for statistics but not
   written (C2 has no disp atlas).

Foam channel encoding is linear `0..1` (not the signed mapping). The foam loop settles in 2-4 loops
(the integrator runs until the wrap drift is below 1/255, capped at 16 loops).

Godot imports every atlas as `CompressedTexture2DArray` with `slices/vertical=64`, lossless; mipmaps
on for `deriv`, off for `disp`.
