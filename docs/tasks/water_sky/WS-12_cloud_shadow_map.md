# WS-12 — Moving cloud shadows on ground and water

Part of the [water and sky task pack](README.md). Source technique: Tidewater `CloudsParams`
(`shadowCenter`, `shadowSize 8000`, `shadowStrength 0.85`) and `cloudsShadow`/`cloudsShadowTap`.
The clouds are projected along the sun direction onto the world and darken the direct light.

## Player-facing goal

On partly cloudy days, large soft shadows drift across the town, harbour and sea in the wind
direction. A sunlit patch sweeps over the quay and the water brightens and sparkles under it. In
overcast weather there are no distinct patches, and on clear days there are none at all.

## Why

The isometric view rarely shows the sky, so the clouds are mostly invisible during play. Cloud
shadows are how the player *feels* the weather overhead. Our sky already has a cloud field
(`cloud_uv`, `cloud_bulk`, `cloud_opacity`, driven by `cloud_offset` and `cloud_coverage`). This
task projects that same field onto the world.

## Allowed files

- `scripts/map/view3d/sky_clouds.gdshaderinc` (new: the cloud field functions moved out of the sky
  shader, unchanged)
- `scripts/map/view3d/sky_weather_3d.gdshader` (include the file instead of defining the functions)
- `scripts/map/view3d/sky_weather_3d.gd` (publish global shader uniforms, add quality-tier rows)
- `scripts/map/view3d/cloud_shadow_pass.gd` (new: a screen-quad node) and
  `scripts/map/view3d/cloud_shadow_pass.gdshader` (new)
- `scripts/map/view3d/map_view_3d.gd` (attach the pass next to `_fog_of_war`, outdoor only)
- `project.godot` (the `[shader_globals]` entries only)
- `tests/godot/test_cloud_shadow_pass.gd` (new), `tests/godot/test_sky_weather_3d.gd`
- `docs/reports/images/ws12_*.png`
- `TODO.md`

## Dependencies

- TODO: none (it works with today's sky). WS-10's physical cloud lighting is independent of this.
- Stable IDs: none.

## Constraints and non-goals

- **One cloud field.** Move the functions into `sky_clouds.gdshaderinc` without changing any maths.
  The sky must render byte-identically before and after the move (compare captures).
- The pass must not touch interiors, top-down roofed rooms (`enclosed_interior`), UI or the sky
  background (depth at the far plane).
- One full-screen pass, with at most 3 texture samples per pixel on `recommended` and 1 on `minimum`.
- Don't edit the materials of buildings, props, characters or terrain. The screen pass covers
  everything consistently.

## Deliverable

1. **Global uniforms** (`project.godot` `[shader_globals]`, set by `SkyWeather3D` whenever the
   cloud state changes): `cloud_noise_tex`, `cloud_shape_tex`, `cloud_offset_g`,
   `cloud_detail_offset_g`, `cloud_coverage_g`, `cloud_chaos_g`, `storm_intensity_g`,
   `storm_locality_g`, `cloud_sun_dir`, `cloud_shadow_strength`. The sky shader keeps its own
   uniforms, and the include takes its inputs as function parameters, so both callers share the
   code.
2. **World projection** matching `cloud_uv(dir, altitude)`, which for steep rays is a plane where
   `uv = xz_on_plane · 0.12 − cloud_offset` at altitude 1:
   ```glsl
   // p = world position of the pixel (from depth), s = sun direction (s.y > 0)
   vec2 q = p.xz + s.xz / max(s.y, 0.15) * (cloud_layer_h - p.y);   // hit the cloud plane along the sun ray
   vec2 uv = (q / cloud_layer_h) * 0.12 - cloud_offset_g;
   float shadow = cloud_opacity(uv, cover);                           // shared include
   ```
   `cloud_layer_h` is an **art knob** in world units. A physically placed 1.5 km layer makes one
   cloud shadow larger than a whole map, so start at about 400 world units (≈ 350 m) to get
   readable patches, and tune on captures. Document the chosen value and why at the constant.
3. **`cloud_shadow_pass.gdshader`** is a spatial, `unshaded`, `depth_test_disabled` quad placed in
   front of the camera, like `map_fog_of_war`, with a high `render_priority` so it draws after the
   water. It reads `hint_depth_texture` and `hint_screen_texture`, rebuilds the world position, and
   evaluates `shadow` using the soft variant (the bulk plus one erosion octave, and a mip bias for
   softness).
   `color = screen · (1 − shadow · cloud_shadow_strength · sun_share)`, where:
   - `sun_share` = the fraction of light that is direct sun, computed in GDScript from
     `sun.light_energy` and `ambient_light_energy` (about 0.6 at a clear noon, ~0 at night), and
     passed as a uniform
   - `cloud_shadow_strength` should be about 0.55 (softer than Tidewater's 0.85, to suit the painted
     look; see `docs/ART_BIBLE.md`)
   - skip sky pixels (depth ≥ far)
   - fade out at `presentation.overcast → 1` (uniform grey light has no patches) and when the sun
     is below the horizon
4. **Pass lifecycle:** `map_view_3d.gd` creates the pass for outdoor maps only, next to
   `_fog_of_war`. `SkyWeather3D` updates the uniforms each frame the clouds move (cheap: two vec2
   and a few floats).
5. **Quality tiers:** add `cloud_shadow_samples` (recommended 3, minimum 1) and
   `cloud_shadow_enabled` (both true) to `QUALITY_TIERS`.

## Verification

1. The headless Godot suite passes. `test_cloud_shadow_pass.gd` checks that:
   - the pass is created only for outdoor maps
   - it is disabled for enclosed interiors
   - `sun_share` is ~0 at night and in full overcast, and > 0.4 at a clear noon
   - the globals are registered in `project.godot`
   `test_sky_weather_3d.gd` passes unchanged.
2. The sky refactor is exact: captures of the sky at 3 elevations × `clear`/`overcast`/`storm`
   before and after the include move are identical (pixel diff 0, or ≤ 1/255 from driver noise).
3. Captures (Metal and Compatibility), `reval_harbor_north` from the gameplay camera, at
   `clear` with coverage forced to 0.45 (partly cloudy), `overcast/day`, `clear/night`, and a 20 s
   clip. Checks:
   - soft patches move downwind at the speed of the sky clouds
   - water under the shadow loses its glint
   - no shadow on the sky, UI or interiors
   - no patches when overcast
4. Performance: report the pass cost from `tools/run_performance_report.sh --quick`. The target is
   ≤ 0.3 ms at 1080p on the reference machine.

## Documentation updates

- The comment at `cloud_layer_h` (the art knob rationale).
- `TODO.md` row:
  ```text
  - [ ] WS-12 | deps: none | deliverable: shared sky_clouds.gdshaderinc cloud field published via global uniforms and a screen-space cloud-shadow pass that projects it along the sun onto world depth, scaled by direct-sun share, outdoor only | allowed files: `scripts/map/view3d/sky_clouds.gdshaderinc`, `scripts/map/view3d/sky_weather_3d.gdshader`, `scripts/map/view3d/sky_weather_3d.gd`, `scripts/map/view3d/cloud_shadow_pass.gd`, `scripts/map/view3d/cloud_shadow_pass.gdshader`, `scripts/map/view3d/map_view_3d.gd`, `project.godot`, `tests/godot/test_cloud_shadow_pass.gd`, `tests/godot/test_sky_weather_3d.gd`, `docs/reports/images/ws12_*.png`, `TODO.md` | verify: pass lifecycle/sun-share tests; sky byte-identical after include move; partly-cloudy clip shows soft downwind patches that kill water glint, none when overcast or at night; pass <= 0.3 ms
  ```
