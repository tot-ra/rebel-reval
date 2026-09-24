# WS-01 — Refracted water column (Snell path to the bed)

Part of the [water and sky task pack](README.md). Source technique: Tidewater `water material`
("Trace the refracted view ray (Snell) to the sea floor instead of using the straight screen ray: at
grazing angles the straight ray overestimates the water path ~10x").

## Player-facing goal

Shallow harbour and river water looks clear and shows its bed when seen from the gameplay camera's
shallow angle. Deep water goes dark because it is deep, not because the camera is low. The bed
appears offset under the surface as real water refraction does. It no longer wobbles by an arbitrary
screen-space amount.

## Why

The current fragment code (`map_view_water.gdshader`, `geometric_depth = scene_depth - surface_depth`)
uses the distance along the **view ray** from the surface to whatever the depth buffer hit. From the
isometric camera (roughly 30–40° above the horizon), that distance is 1.5–2× the real vertical
column. At grazing angles it can be about 10×. To hide this, the shader clamps and layers
`optical_depth`, `depth_absorption` and `bed_detail_visibility`. Refraction is also a fixed
`view_normal.xy * refraction_strength` screen offset with no physical basis.

## Allowed files

- `scripts/map/view3d/map_view_water.gdshader`
- `scripts/map/view3d/map_view_water_materials.gd` (only to retune per-terrain absorption constants)
- `tests/godot/test_r715_water_material_contract.gd`
- `docs/THIRD_PARTY_NOTICES.md` (add `notice.code.tidewater`, full MIT text)
- `docs/reports/images/ws01_*.png` (captures)
- `TODO.md` (the task row)

## Dependencies

- TODO: none (builds on completed P0-222 … P0-227).
- Stable IDs: no content IDs change. The water terrain IDs in `MapTypes.WATER_TERRAINS` are unchanged.

## Constraints and non-goals

- Keep `blend_mix, depth_draw_always, cull_disabled` and the screen and depth texture reads. Add no
  new render passes.
- Keep the bank-halo protection: never sample a screen pixel whose depth is in front of the water
  surface.
- Don't touch the wave field, foam, sky reflection or glint. Those belong to other tasks.
- Must stay correct for the GL Compatibility depth convention (NDC z in −1..1, handled by the
  existing `_view_depth`) and for the Mobile renderer used by the capture tool (z in 0..1). Add one
  helper that handles both.

## Deliverable

A fragment path that:

1. Rebuilds the **bed's world position** from the depth buffer at `SCREEN_UV`:
   `bed_view = INV_PROJECTION_MATRIX * ndc`, then `bed_world = (INV_VIEW_MATRIX * bed_view).xyz`.
   Add `_view_position(uv, raw_depth)` next to `_view_depth` so both share the NDC convention.
2. Computes the **vertical water column** `h = max(water_world_position.y - bed_world.y, 0.0)`.
   This is the physical depth, independent of view angle.
3. Refracts the view ray at the surface, as Tidewater does:
   ```glsl
   const float WATER_IOR = 1.333;
   vec3 V = normalize(camera_world - water_world_position);   // towards the eye
   vec3 Tr = refract(-V, world_normal, 1.0 / WATER_IOR);
   // wave facets on a coarse mesh can refract upward: keep the ray going down
   vec3 Tv = normalize(vec3(Tr.x, min(Tr.y, -0.08), Tr.z));
   float t_down = max(-Tv.y, 0.04);
   float path_len = h / t_down;                              // world units of water the light crosses
   ```
   Use `calm_normal` (the low-sun stabilised normal), not the raw detail normal. Otherwise the path
   length shimmers.
4. Computes the **refracted sample point** `bed_hit = water_world_position + Tv * path_len`,
   projects it with `PROJECTION_MATRIX * VIEW_MATRIX`, and uses that UV to read `screen_texture`.
   Refine once: read depth at the new UV, rebuild `bed_world` there, recompute `h` and `path_len`,
   then project again. This matches Tidewater's "2 refinements" but uses the depth buffer instead of
   a terrain height function. Keep the existing safety rule: if the refined depth is in front of the
   surface (`<= surface_depth + 0.002`) or the UV leaves 0..1, fall back to `SCREEN_UV`.
5. Applies **Beer–Lambert extinction along `path_len`**, not `geometric_depth`:
   ```glsl
   // metres -> world units: path_len is in world units, 1 unit = 0.87 m
   float path_m = path_len * 0.87;
   vec3 T = exp(-sigma_t * path_m);   // sigma_t per metre, per channel
   vec3 water_color = seabed * T + inscatter_color * (1.0 - T);
   ```
   Derive `sigma_t` from the existing `depth_absorption * vec3(1.28, 0.72, 0.40)` so current terrain
   profiles keep their character. Then retune the per-terrain constants in
   `map_view_water_materials.gd` (`OPTICAL_DEPTH_BY_TERRAIN`, `WATER_WAVE_BASE`) so the default
   harbour plate matches the pre-change capture's average colour to within about 10%.
   Reasonable Baltic coastal values: `sigma_t ≈ (0.45, 0.12, 0.09) m⁻¹` in clear water,
   and about 2× in the harbour.
6. Keeps `terrain_optical_depth` only as a **minimum path** (a floor on `path_m`) for the flat
   gameplay bed. Delete clamps that become redundant, and explain each one you keep in a comment.
7. Feeds the new `h` (not the old `geometric_depth`) to `_seabed_layers`, caustic visibility and the
   edge-foam depth fades. Those fades were written for vertical depth.

Add a `notice.code.tidewater` section to `docs/THIRD_PARTY_NOTICES.md` (component, copyright
"Daniel Greenheck", MIT license text, use: "water, ocean and atmosphere shader techniques ported in
the WS task pack"). Put a one-line comment above the ported block.

## Verification

1. `godot --headless --path . --script tools/run_godot_tests.gd` passes. Extend
   `test_r715_water_material_contract.gd` so it asserts that the shader source contains `refract(`,
   `WATER_IOR`, and a Beer–Lambert `exp(-` term driven by the refracted path length. It must still
   reject planar reflections (existing assertion).
2. Visual: capture `reval_harbor_north`, scenario `clear`, time `day` before and after with
   `tools/capture_r715_water_acceptance.gd` (Metal) and with Compatibility. Required observations:
   - The quay foot and bed stones stay visible in the first 1–2 m of water. The old version turned
     them teal-opaque at the shallow camera angle.
   - Rotating or orbiting the camera doesn't change how deep the water looks (compare two orbit
     angles at the same spot).
   - There are no bright halos or dry bank pixels pulled into the water at quay edges.
3. The `minimum` quality tier shows the same result. The change is pure ALU, so it needs no tier
   gate.
4. `python3 tools/generate_active_docs_report.py --check` and `git diff --check`.

## Documentation updates

- `docs/THIRD_PARTY_NOTICES.md` (new notice).
- The `TODO.md` row, checked after review:
  ```text
  - [ ] WS-01 | deps: none | deliverable: water extinction and bed sampling follow the Snell-refracted ray to the depth-buffer bed (vertical column / refracted cosine, one refinement), replacing view-ray geometric depth and the fixed screen-offset refraction | allowed files: `scripts/map/view3d/map_view_water.gdshader`, `scripts/map/view3d/map_view_water_materials.gd`, `tests/godot/test_r715_water_material_contract.gd`, `docs/THIRD_PARTY_NOTICES.md`, `docs/reports/images/ws01_*.png`, `TODO.md` | verify: contract test asserts refract/Beer-Lambert path; harbor clear-day before/after captures show a clear shallow bed with no orbit-dependent darkening and no bank halo
  ```
