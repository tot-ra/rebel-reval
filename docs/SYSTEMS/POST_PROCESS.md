# Renderer, post-process grade and HDR output

Status: implemented (task **R-1537**, [ADR 0043](../adr/0043-mobile-renderer-and-hdr-output.md); grade values from [ADR 0018](../adr/0018-saturated-hdr-fantasy-anime-visual-direction.md), P0-141).

Scope: the renderer the game ships on, the shared 3D post-process grade (tonemapper, glow, colour adjustment, interior exposure), and opt-in HDR (macOS EDR) output with its Settings toggle. Out of scope: HDR10 / wide-gamut delivery claims, eye adaptation, SSAO, Forward+-only features (SDFGI, SSIL, volumetric fog), removing the remaining `CURRENT_RENDERER == RENDERER_COMPATIBILITY` shader branches (follow-up).

## Player-facing behavior

- The game renders on the **Mobile** renderer with the **Metal** driver (`project.godot`: `rendering/renderer/rendering_method="mobile"`, `rendering/rendering_device/driver.macos="metal"`).
- On a Mac with an EDR/XDR screen, the sun, fire, forge glow and lamps can render brighter than UI white; UI stays at reference white. On an SDR screen the OS grants no headroom and the picture is the ADR 0018 SDR grade.
- **Settings → Graphics → HDR output (EDR displays)** turns the HDR request on or off live. Default on. Saved with the other user settings, outside campaign slots ([Settings and accessibility](./SETTINGS_AND_ACCESSIBILITY.md)).

## Runtime entry points

| Piece | Where |
|------|------|
| HDR request at startup | `project.godot`: `display/window/hdr/request_hdr_output=true`, `rendering/viewport/hdr_2d=true` |
| HDR toggle (live) | `GraphicsSettings.hdr_output` (`scripts/settings/graphics_settings.gd`) → `UserSettings._apply_graphics_settings()` sets `Window.hdr_output_requested` on the root window (skipped under the headless display server, which has no HDR API); UI row in `scripts/ui/game_settings_overlay.gd` |
| 3D grade | `MapViewLighting.configure_post_process()` (one-time: AgX, screen glow, adjustments) and `apply_post_grade()` / `apply_post_grade_snapshot()` (per cycle) in `scripts/map/view3d/map_view_lighting.gd` |
| Interior exposure | `MapViewLighting.interior_exposure_factor(fill_blend)`, applied in `apply_cycle_progress()` when `enclosed_interior` |
| Prologue grade | `scripts/prologue/almshouse_stage.gd` `_build_environment()` (AgX) |
| HDR sun disk and aureole | `scripts/map/view3d/sky_weather_3d.gdshader` uniforms `sun_disk_hdr_gain` (20), `sun_halo_hdr_gain` (3.0), `sun_corona_strength` (4.5) / `sun_corona_width` (3.0), visible sky pass only |
| EDR headroom global | shader global `edr_headroom` (`project.godot`), published by `UserSettings._publish_edr_headroom()` from `Window.output_max_linear_value_changed` |

## Grade values

- **Tonemapper:** AgX everywhere (3D views and the almshouse prologue). Filmic ignores EDR headroom, so it is no longer used.
- **Glow:** `GLOW_BLEND_MODE_SCREEN`, threshold 1.05, levels 1-3, intensity 0.14 day / 0.34 night. Soft-light glow is SDR-only (a no-op under HDR output). Screen glow lifted the smithy plates about 3-5% over soft light at the old 0.20 / 0.48, so intensity dropped 30%.
- **Interior exposure:** enclosed interiors multiply `tonemap_exposure` by 0.48 at night to 0.70 by day (`INTERIOR_EXPOSURE_NIGHT` / `_DAY`, lerped by the twilight fill blend). On Mobile, hearth, candle and window lights read 1.4x brighter by day and 2.2x by night than on GL Compatibility, where the ADR 0018 grade was tuned. The lights live in many prop builders, so the grade compensates instead. Kalev smithy, 32 day and night shots: mean luma ratio Mobile / GL Compatibility went from a median of 1.54 to 1.05 with the shipped values (day 1.07, night 1.02).
- **Sun disk and aureole:** the sky disk was calibrated to a scene-linear peak of 2.4 for SDR, which AgX shows at only ~1.2x UI white at headroom 4.0, so on EDR the sun read as a small white dot. The visible sky pass multiplies the disk by `sun_disk_hdr_gain` (noon centre near scene-linear 16, the probe's "sun" patch) and the halo by `sun_halo_hdr_gain`, so the sun uses the full headroom and carries a glare a few degrees wide. A Gaussian corona (`sun_corona_*`) holds the ring next to the disk at about 60-70% of the disk on EDR (probe: 73% at 1.5 disk radii, 62% at 2, 53% at 3). It is scaled by `smoothstep(1, 2, edr_headroom)`, so SDR screens (headroom 1) get no corona; otherwise it would clip to a large white disk. The radiance cubemap pass (`AT_CUBEMAP_PASS`) keeps gain 1 so sky reflections and glossy highlights do not brighten. On SDR the brighter disk clips to white. Measured 2026-10-10 on the XDR panel (`--sun-map=smithy_courtyard`, cloudless noon, headroom 5.9): sun peak 2.8x -> 5.6x UI white with gain 7; gain 20 now clips the disk at the panel limit (108% of headroom 6.07).
- **Headroom is dynamic.** Code that needs it reads `Window.get_output_max_linear_value()` per frame or listens to `output_max_linear_value_changed`. It is never cached.

## Verify

- `tools/godot_render.sh --rendering-method mobile --rendering-driver metal --script tools/probe_hdr_output.gd -- --screen=<XDR index> --map=kalev_smithy` writes `build/hdr_spike/hdr_probe.json`. Expect `hdr_output_enabled=true`, `ui_white` 1.0, `shipped_agx_screen` sun patch above 2x UI white at headroom 4.0, and the shipped variant different from `agx_no_glow`. Pick the XDR screen from the `screens` list in the JSON: indices change when monitors are reconnected.
- Add `--sun-map=smithy_courtyard` to the probe to frame the real sky sun on a cloudless noon. It writes `sun_frame` (peak, `peak_over_ui_white`) to the JSON plus `build/hdr_spike/<renderer>_sun_<map>.{exr,png}` and a `_heat.png` false-colour map (grey up to UI white, yellow 1-2x, orange 2-4x, red 4x and above). Expect `peak_of_headroom` near or above 1.0 and `aureole_rings` r1.50-r2.00 at 0.6-0.75 of the peak. `--edr-headroom=1` previews the SDR result.
- `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_game_settings_overlay,test_map_view_3d_lighting,test_map_view_lighting,test_sky_weather_optical_effects`
- Mobile acceptance plates: [images/r1537_mobile](../reports/images/r1537_mobile/) (city day/night, Kalev smithy, almshouse prologue). Plates captured on GL Compatibility before R-1537 are historical.

## Limits

- On 2026-10-10 the probe ran with `hdr_output_enabled=true` but macOS granted headroom 1.0 on the XDR panel (reference = peak = 1600 nits, panel brightness at maximum). The 4.0x headroom numbers come from the [2026-10-09 spike](../reports/hdr_output_spike_2026-10-09.md). A human eyeball check of a visible window on the XDR panel is still owed.
- **Headroom depends on panel brightness.** macOS shrinks EDR headroom as the display brightness goes up and grants 1.0 (no HDR) at maximum brightness or with a fixed reference preset where SDR white equals peak. With headroom 1.0 the game is correctly SDR. Check `output_max_linear_value` in the probe JSON before judging the picture.
- Agent captures run minimized (`tools/godot_render.sh`), and macOS often grants a minimized window no EDR headroom. Screenshots cannot show EDR.
- Shaders still carry `RENDERER_COMPATIBILITY` branches. ADR 0043 removes them after the switch; that cleanup is a separate task.
- No eye adaptation: `low_sun_exposure_factor()` stays as its stand-in.
