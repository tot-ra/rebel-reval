# WS-09 — Offline Hillaire atmosphere LUTs (transmittance and multi-scattering)

Part of the [water and sky task pack](README.md). Source technique: Tidewater `atmosphere` module
(`AtmosphereParams`, `atmosphereMedium`, `atmosphereTransmittanceUV`, and the LUTs
`atmoTransmittance` 256×64, `atmoMultiScat` 32×32 and `atmoSkyView` 192×108). It implements
Sébastien Hillaire, *A Scalable and Production Ready Sky and Atmosphere Rendering Technique*
(EGSR 2020), with Bruneton's LUT parameterisation.

## Player-facing goal

None directly. This task supplies the physical data WS-10 needs to draw a real sky: deep blue at the
zenith, a pale horizon, and orange-to-red sunsets with a pink Earth-shadow band opposite the sun.
The same data colours the sunlight in WS-11.

## Why a bake

The transmittance and multi-scattering LUTs depend only on the atmosphere's constants, not on the
sun, the camera or the weather. Tidewater computes them once in a compute pass. We compute them
once offline and ship them as two small float textures.

## Allowed files

- `tools/bake_atmosphere_luts.py` (new, includes a minimal half-float EXR writer)
- `tests/python/test_bake_atmosphere_luts.py` (new)
- `assets/sky/atmosphere/transmittance.exr`, `assets/sky/atmosphere/multiscatter.exr`,
  `assets/sky/atmosphere/atmosphere_profile.json` (+ `.import` sidecars), `assets/SOURCES.csv`
- `scripts/map/view3d/atmosphere_common.gdshaderinc` (new: the GLSL side of the same
  parameterisation, used by WS-10)
- `tests/godot/test_atmosphere_luts.gd` (new)
- `TODO.md`

## Dependencies

- TODO: none. Python needs only `numpy`.
- Unlocks WS-10 and WS-11.

## Constraints and non-goals

- The constants must match Tidewater / Hillaire defaults exactly, so the numeric tests have an
  oracle. Art-direction tints belong in WS-10, not in the data.
- No runtime sky change in this task.
- Deterministic output. Each file is under 1 MiB (256×64 and 32×32 RGBA half are tiny).

## Physics (units: km)

```text
R_ground = 6360        R_top = 6460
Rayleigh scattering β_R = (5.802, 13.558, 33.1) e-3 /km, density exp(-h/8)
Mie scattering      β_M = 3.996e-3 /km, extinction 4.440e-3 /km, density exp(-h/1.2), g = 0.8
Ozone absorption    β_O = (0.650, 1.881, 0.085) e-3 /km, density max(0, 1 - |h - 25| / 15)
Ground albedo       (0.06, 0.08, 0.10)   (Tidewater; Baltic sea + dark land)
extinction(h) = β_R·ρ_R + β_Mext·ρ_M + β_O·ρ_O
scattering(h) = β_R·ρ_R + β_M·ρ_M
```

Keep `rayleigh_scale`, `mie_scale` and `ozone_scale` as bake arguments (default 1). A hazy Baltic
summer might later want `mie_scale ≈ 1.5`, and that's a re-bake, not a code change.

### Transmittance LUT (256 × 64)

Bruneton mapping (port it exactly; the same functions go into `atmosphere_common.gdshaderinc`):

```text
H     = sqrt(R_top² − R_ground²)
rho   = sqrt(r² − R_ground²)
d     = −r·μ + sqrt(r²(μ² − 1) + R_top²)          distance to the top of the atmosphere
d_min = R_top − r      d_max = rho + H
u = (d − d_min)/(d_max − d_min)      v = rho / H
```

The bake inverts the mapping per texel (`r = sqrt(v²H² + R_ground²)`, then solve for μ from `d`)
and integrates `exp(−∫ extinction ds)` to the top with 40 midpoint steps.

### Multi-scattering LUT (32 × 32)

Hillaire §5.5. Texel `(u, v)` → `cos θ_sun = 2u − 1`, `h = v·(R_top − R_ground)`. Integrate over
**64 uniformly distributed sphere directions** (use a fixed Fibonacci sphere so it's deterministic),
with 20 steps along each ray, accumulating:

- `L_2nd`: in-scattered sunlight with an **isotropic** phase function (1/4π), using transmittance
  from the LUT above, plus the ground bounce `albedo/π · T · max(μ_sun_ground, 0)` where the ray hits
  the ground.
- `f_ms`: the transfer factor, i.e. the integral of scattering × transmittance along the ray.
- Result `Ψ_ms = L_2nd / (1 − f_ms)` (the infinite geometric series of higher-order scattering).

## Output

- `transmittance.exr` (RGB = T, A = 1) and `multiscatter.exr` (RGB = Ψ_ms, A = 1), both RGBA half,
  NO_COMPRESSION, scanline. Write a minimal EXR writer: magic, version, attribute header
  (`channels` A, B, G, R as HALF; `compression` 0; `dataWindow`; `displayWindow`; `lineOrder` 0;
  `pixelAspectRatio`; `screenWindowCenter`; `screenWindowWidth`), a line-offset table, then one
  chunk per scanline with the channels stored in alphabetical order. It's about 100 lines with
  `numpy.float16`. Don't add an OpenEXR dependency.
- `atmosphere_profile.json`: every constant, the LUT sizes, the tool version and the sha256 of both
  files.
- Godot import: `Texture2D`, `compress/mode = Lossless`, no mipmaps, filter linear, clamp.

## Deliverable: `atmosphere_common.gdshaderinc`

GLSL ports of the following, with comments naming the Hillaire section for each:

- constants
- `atmosphere_medium(h_km)`
- `ray_sphere(ro, rd, radius)` (nearest positive hit, −1 on a miss, as in Tidewater)
- `transmittance_uv(r, mu)` and its inverse
- `multiscatter_uv(r, mu_sun)`
- `rayleigh_phase(cosθ) = 3/(16π)·(1 + cos²θ)`
- `mie_phase_cornette_shanks(cosθ, g)`

This file has no runtime user yet. WS-10 includes it.

## Verification

1. `python3 -m unittest tests.python.test_bake_atmosphere_luts -v` passes. The analytic oracles are:
   - **Zenith transmittance at the ground:**
     `T = exp(−(β_R·8 + β_Mext·1.2 + β_O·15))` = **(0.940, 0.868, 0.762)** ± 0.005 (the vertical
     column optical depths; curvature is negligible straight up).
   - **Horizon transmittance** (μ = 0 at the ground) is much smaller than zenith, and blue < red.
   - The transmittance LUT is monotonic in μ.
   - The multi-scattering LUT is non-negative, and at the ground with the sun at the zenith it is
     ≈ 0.01–0.1 of the single-scattering order (sanity band).
   - `inverse(transmittance_uv(r, μ))` round-trips within 1e-4.
   - The bake is deterministic (identical bytes).
   - The EXR writer output parses back with a pure-Python reader in the test.
2. `test_atmosphere_luts.gd`: Godot loads both EXRs as `Texture2D`. Also
   `Image.get_pixel` at the zenith-ground texel equals the Python oracle within 0.01, which proves
   the EXR writer, import and parameterisation agree.
3. The headless Godot suite, `python3 tools/validate_asset_sources.py`,
   `python3 tools/verify_storage_hygiene.py`, `python3 tools/generate_active_docs_report.py --check`.

## Documentation updates

- `assets/SOURCES.csv` rows (tool, constants in `edits`, AGPL project author).
- Cite the Hillaire paper (EGSR 2020) at the top of both `tools/bake_atmosphere_luts.py` and
  `atmosphere_common.gdshaderinc`, plus the Tidewater notice from WS-01.
- `TODO.md` row:
  ```text
  - [ ] WS-09 | deps: none | deliverable: deterministic offline Hillaire transmittance (256x64) and multi-scattering (32x32) LUTs as half-float EXR with profile manifest, plus atmosphere_common.gdshaderinc GLSL parameterisation | allowed files: `tools/bake_atmosphere_luts.py`, `tests/python/test_bake_atmosphere_luts.py`, `assets/sky/atmosphere/*`, `assets/SOURCES.csv`, `scripts/map/view3d/atmosphere_common.gdshaderinc`, `tests/godot/test_atmosphere_luts.gd`, `TODO.md` | verify: python oracle tests (zenith T = 0.940/0.868/0.762, monotonicity, round-trip, determinism, EXR parse); Godot loads EXRs and matches the oracle texel
  ```
