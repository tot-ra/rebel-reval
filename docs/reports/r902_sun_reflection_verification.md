# R-902 sun-reflection colour verification

The 0..255 `Color` bug was already fixed in `sky_weather_3d.gd` by commit `13cbf8d3` (WS-11). The physical-atmosphere path now overrides the normalized `Color8` fallback with a normalized sun tint. This change adds a regression test that forces missing CPU LUTs, tests noon/intermediate/sunset tints, and restores LUT state. No glint gain or swash-film retuning was made: both renderers retain a visible, bounded reflection rather than a washed-out water surface.

## Fixed-setting captures

`tools/godot_render.sh` with `tools/capture_ws02_glint.gd`, `--scenario=clear --focus=harbour --progress=0.5` (day) or `--progress=0.76` (low sun), 1280x720. Each row is the current worktree, *not* a before/after pair from a revision predating the WS-11 fix. `tools/capture_underwater.gd --shot=under_horizontal --pos=57.5,-0.02,41.5 --look=57.5,-0.02,47.5` captures the specified grazing-angle underwater pose.

| Renderer | Day | Low sun | Underwater |
| --- | --- | --- | --- |
| Metal mobile | [day](images/ws02_metal_clear_r902_noon_harbour.png) | [low sun](images/ws02_metal_clear_r902_sunset_harbour.png) | [grazing](images/r902/under_horizontal_metal.png) |
| OpenGL3 Compatibility | [day](images/ws02_opengl3_clear_r902_noon_harbour.png) | [low sun](images/ws02_opengl3_clear_r902_sunset_harbour.png) | [grazing](images/r902/under_horizontal_opengl3.png) |

The water material reported `sun_reflection_color` (1.0, 0.957, 0.892) by day and (1.0, 0.894, 0.744) at low sun on both renderers. For a coarse white-sheet sanity check, Pillow counted pixels with **all** RGB channels above 245: zero in the lower half of each of the four harbour captures and zero across either underwater frame. This is a clipping check, not a visual-art sign-off. The existing tracked `ws02_*_clear_{noon,sunset}_harbour.png` plates were captured under different past settings and cannot serve as matched pre-fix baselines.

## Tests and boundary

- `--filter=test_sky_weather_3d,test_underwater_pass`: 48/48.
- Eleven `test_r715_water_*` files: 57/57. The first tool call timed out while the Godot process continued; its final log recorded 0 failures and 0 errors.
- `python3 -m gdtoolkit.linter tests/godot/test_sky_weather_3d.gd` and `git diff --check`: pass.
- Independent code review: no blocking findings; temporary CPU LUT state is restored, matching `test_atmosphere_cpu.gd`.
- `python3 tools/generate_active_docs_report.py --check` currently reports a stale `docs/reports/active_markdown_report.md` due to other concurrent edits of active docs. That report is outside R-902 and was not staged here.

The sunset shots use a low but not grazing sun; the underwater pose covers the grazing-angle acceptance case. Human visual sign-off, a matched pre-WS-11 renderer baseline, and a capture explicitly disabling the GPU sky LUT remain outside this packet. Do not use these screenshots to claim complete visual acceptance of the gradient-water fallback.
