# WS-02 — Physically based sun and moon glint on water

Part of the [water and sky task pack](README.md). Source technique: Tidewater water material,
which uses GGX distribution × Smith-GGX visibility × exact dielectric Fresnel, with the glint
clamped to 400× so it stays in fp16 range.

## Player-facing goal

The sun leaves a proper glitter path on the sea. It is a narrow, bright band of sparkles that
widens as the sun gets lower and as the sea gets rougher, and it vanishes behind the shadow of a
quay or a ship. Moonlight leaves a silver path at night. Glints don't strobe during the compressed
60-second day cycle.

## Why

Today the glint is drawn twice. Godot's built-in GGX lobe is driven by `ROUGHNESS` (0.09–0.42,
which is too rough for water) and `SPECULAR`. On top of that, the shader adds
`pow(sun_alignment, 220.0)` and `pow(moon_alignment, 320.0)` in `ALBEDO`. Neither is shadowed.
Neither widens with sea state. Because the hand-made glint lives in `ALBEDO`, it gets lit a second
time.

## Allowed files

- `scripts/map/view3d/map_view_water.gdshader`
- `scripts/map/view3d/map_view_water_materials.gd` (only if a new uniform needs wiring)
- `tests/godot/test_r715_water_material_contract.gd`
- `docs/reports/images/ws02_*.png`
- `TODO.md`

## Dependencies

- TODO: none. It can land before or after WS-01. If WS-01 has landed, reuse its `WATER_IOR` constant.
- Stable IDs: none.

## Constraints and non-goals

- Keep the existing sun-visibility and twilight gates (`sun_visibility`, `sun_reflection_visibility`,
  `low_sun_glitter`). The DirectionalLight still follows the sun past the visual disk fade, so every
  sun term must stay gated.
- Don't change the sky-dome reflection colour here. WS-11 does that.
- The `light()` function must also work for the moon light and for local lights (torches, forge
  light spill on the harbour, `candle_light_3d.gd`).
- No bloom dependency. Glints must read without post-processing because the Compatibility renderer
  has limited glow.

## Deliverable

1. **Custom `light()` in the water shader** (supported in GL Compatibility). It replaces Godot's
   built-in lighting for this material only:
   ```glsl
   void light() {
       vec3 N = NORMAL; vec3 V = VIEW; vec3 L = LIGHT; vec3 H = normalize(V + L);
       float NdL = max(dot(N, L), 0.0);
       float NdV = max(dot(N, V), 1e-4);
       float NdH = max(dot(N, H), 0.0);
       float VdH = max(dot(V, H), 0.0);
       float a2 = water_alpha * water_alpha;          // from fragment via varying/uniform
       float spec = D_GGX(NdH, a2) * V_SmithGGXCorrelated(NdL, NdV, a2)
                  * fresnel_dielectric(VdH, 1.333) * NdL;
       spec = min(spec, 400.0);                        // Tidewater clamp
       SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * spec * glint_gate;
       // water has almost no diffuse; keep a small term so foam and turbid water still shade
       DIFFUSE_LIGHT  += LIGHT_COLOR * ATTENUATION * NdL * diffuse_share;
   }
   ```
   - `fresnel_dielectric(cosθ, n)` must be the **exact unpolarised** formula, not Schlick.
     Tidewater uses it because Schlick overshoots at grazing angles:
     `g = sqrt(n² − 1 + c²); F = 0.5·((g−c)/(g+c))²·(1 + ((c(g+c)−1)/(c(g−c)+1))²)`.
   - `ATTENUATION` carries Godot's shadow, so quay and ship shadows kill the glint.
   - Pass `diffuse_share` and `glint_gate` from `fragment()` through varyings, or by writing them
     into spare built-ins you document. Foam pixels need a high diffuse share (foam is diffuse white).
     Clear water needs about 0.02.
2. **Roughness that follows wave slope variance** (a Toksvig-style fix against aliasing). Keep the
   glitter path wide in rough seas, and stop distant waves from sparkling as a single pixel:
   ```glsl
   // slope variance that the mesh/normals can't resolve at this pixel
   vec3 n_dx = dFdx(world_normal), n_dy = dFdy(world_normal);
   float unresolved = clamp(dot(n_dx, n_dx) + dot(n_dy, n_dy), 0.0, 0.25);
   float sea_variance = mix(0.0015, 0.02, clamp(choppiness * wave_chaos, 0.0, 1.0)); // storm widens
   water_alpha = sqrt(base_alpha * base_alpha + sea_variance + unresolved);
   ```
   `base_alpha` should be about 0.03 for calm water and about 0.08 for rivers and foam. Set
   `ROUGHNESS` to `sqrt(water_alpha)` so Godot's reflection probes and ambient specular stay
   consistent.
3. **Remove** the hand-made `sun_glint` / `moon_glint` additions to `water_color` once the lit path
   matches. Keep the reflected *star* sparkle term, because stars are not lights.
4. **Low-sun stability:** keep using `calm_normal` for the lit normal. The compressed day cycle turns
   every normal change into fast bands, so `NORMAL` must stay the calm normal.
5. **Moon:** if the moon is not a `DirectionalLight3D` in `map_view_lighting.gd`, keep one analytic
   moon lobe inside `fragment()` that uses the same GGX and Fresnel helpers, not `pow(…, 320)`.
   Output it through `EMISSION`, scaled by `moon_visibility`, so it isn't lit twice.

## Verification

1. The headless Godot test suite passes. The contract test asserts `void light()`, a GGX
   distribution function and exact dielectric Fresnel. It also asserts that
   `pow(sun_alignment, 220.0)` has been removed.
2. Captures (Metal and Compatibility), harbour map:
   - `clear` / `day` at noon and near sunset (set the sun through `SkyWeather3D.apply_sky_state`,
     as the capture tool does). At sunset the glitter path must be wider and more elongated than at
     noon.
   - `storm` / `day`: the glitter path is broad and broken, not a mirror.
   - A shadowed quay area has no glint.
   - `clear` / `night`: a silver moon path, with no sun glint after sunset.
3. There is no visible strobing when the day cycle runs at normal speed. Record a 10-second clip
   with the capture tool or by hand and attach it or describe it in the review.
4. Run `tools/run_performance_report.sh --quick` and compare the water frame time with the previous
   report. `light()` runs once per light, so check the harbour with torches lit at night.

## Documentation updates

- `TODO.md` row:
  ```text
  - [ ] WS-02 | deps: none | deliverable: water light() with GGX + Smith visibility + exact dielectric Fresnel, shadow-attenuated, slope-variance roughness; hand-made pow() sun/moon glints removed | allowed files: `scripts/map/view3d/map_view_water.gdshader`, `scripts/map/view3d/map_view_water_materials.gd`, `tests/godot/test_r715_water_material_contract.gd`, `docs/reports/images/ws02_*.png`, `TODO.md` | verify: contract test; noon/sunset/storm/night harbor captures show sea-state-dependent glitter path, no glint in quay shadow, no strobing on the 60 s day cycle
  ```
