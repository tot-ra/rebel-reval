# P0-040 baseline reconciliation

Recorded: 2026-08-17T13:40:29Z
Task: `R-566 / P0-040`

## Reconciliation verdict

**Technical visual freeze: BLOCKED, baseline established.** The current checkout contains the approved visual direction and the implementation values below, and the P0-038 development baseline passes its headless budget. P0-040 is not fully closed because GPU texture-memory evidence and frame-time evidence on the declared minimum-supported-hardware profile are still absent. No runtime or asset files were changed for this reconciliation.

## Provenance and approval state

- Current checkout inspected: `2a94045c370d343e46182709b2d683d55b4294ee`.
- Current worktree is dirty (`145` status entries at inspection); unrelated changes are not part of this report and were not cleaned, staged, or absorbed.
- Historical P0-038 measurement revision: `a87b6002917fdfdc7afdb3fbf2fd8b1c030207d0`. The measurements below belong to that revision, not automatically to the current checkout.
- `docs/ART_BIBLE.md` is normative for new visual decisions, but its technical production freeze remains gated by P0-038/P0-040.
- ADR 0013 is **Accepted** and removes P0-039 blind-panel work as a P0-040 dependency. ADR 0018 is **Accepted (maintainer-directed)** and establishes the saturated HDR-range fantasy/anime direction.
- Material authority is `docs/MATERIAL_STYLE_LOCK_KIT.md`, version `style-lock-v1.1`.

## P0-038 evidence and checks

- Generator check: **PASS** - `python3 tools/generate_p038_comparison_report.py --check`.
- Python unit test: **PASS** - `python3 -m unittest tests.python.test_generate_p038_comparison_report -v`, 5/5 tests.
- P0-038 verdict: **Pass (development baseline)**.
- Headless Lower Town frame-time p95: **7.346 ms**, against the **16.67 ms** steady-state reference.
- Headless renderer texture readings: `RENDER_TEXTURE_MEM_USED = 0` bytes and `RENDER_VIDEO_MEM_USED = 0` bytes. These are dummy-renderer readings, not GPU acceptance evidence.
- P0-038 explicitly requires a non-headless run on the declared minimum-hardware profile before frame time or texture memory is accepted for P0-040. This remains an open blocker.

## P0-040 freeze fields

Each required freeze field appears once below. Statuses mean `Pass` is source/contract reconciliation only; it does not claim a new visual capture or minimum-hardware acceptance run.

| Freeze field | Status | Reconciled value and evidence |
|---|---|---|
| Renderer | **Pass - baseline value; acceptance blocked** | Godot 4.7, `GL Compatibility` in `project.godot` (`rendering/rendering_method` and mobile method). ADR 0018 describes the current output as SDR/GL Compatibility and does not claim HDR10 or wide-gamut delivery. GPU acceptance remains pending the non-headless minimum-hardware run. |
| Perspective | **Pass - implementation reconciled** | Runtime camera supports perspective over-the-shoulder third person and first person. Third person uses FOV `65°`, first person uses FOV `75°`; the orthographic top-down mode is retained as the alternate overview. Source: `scripts/map/view3d/map_view_runtime_camera.gd`. |
| Internal resolution | **Pass - implementation reconciled** | Design viewport is `1920x1080`; `window/stretch/mode = "viewport"`; the display window preserves the design aspect ratio while sizing to the screen. Source: `project.godot`, `scripts/display/display_window.gd`. No separate lower internal-resolution target is declared. |
| Camera angles | **Pass - implementation reconciled** | Orthographic top-down baseline is `CAMERA_PITCH_DEGREES = -30.0`, `CAMERA_YAW_DEGREES = 45.0`; runtime perspective defaults are third-person pitch `-12.0°` and first-person pitch `-10.0°`, with authored look bands. Source: `scripts/map/view3d/map_view_3d.gd`, `scripts/map/view3d/map_view_runtime_camera.gd`. |
| World scale | **Pass - implementation reconciled** | The logic plane remains authoritative and maps one logic cell to one world unit through `MapViewBridge.WORLD_UNITS_PER_CELL = 1.0`; the authored map pixel scale remains `DEFAULT_CELL_SIZE = 32`. Character visible height is frozen at `2.0` world units. Sources: `scripts/map/view3d/map_view_bridge.gd`, `scripts/map/map_types.gd`, `assets/characters/shared/character_scale.gd`. |
| Mesh-builder height rules | **Pass - implementation reconciled** | Authored wall heights are converted through `MapViewBridge.world_scale(cell_size)`. Fortification walls at or above `128 px` use `FORTIFICATION_HEIGHT_SCALE = 1.5`, unless an explicit `wall_height_scale` overrides it; lower enclosure fences and courtyard walls remain at authored scale. Sources: `scripts/map/map_types.gd`, `scripts/map/view3d/map_view_mesh_builder_buildings.gd`. |
| Lighting | **Pass - implementation reconciled** | Deterministic day/night lighting is wired through `MapViewLighting`: day sun `1.2`, night sun `0.72`, colored ambient fills, celestial/weather modifiers, and authored fog/weather response. Night retains indigo/cobalt and local color rather than a gray wash. Source: `scripts/map/view3d/map_view_lighting.gd`, aligned with ART_BIBLE v2 and ADR 0018. |
| Shadows | **Pass - implementation reconciled** | Directional sun shadows are enabled with four parallel splits, max distance derived from the gameplay orthographic size, bias `0.05`, normal bias `1.2`, zero blur, and crisp angular distance `0.0`. Source: `scripts/map/view3d/map_view_3d.gd`. This is a source contract, not a new capture result. |
| Post-grade | **Pass - implementation reconciled** | AgX tonemapping with controlled glow and day/night grade. Day: exposure `0.98`, saturation `1.20`, contrast `1.12`, brightness `1.03`; night: exposure `0.90`, saturation `1.14`, contrast `1.08`, brightness `0.89`; glow threshold `1.05`, intensity day/night `0.32/0.48`, bloom `0.10`, strength `1.0`, mix `0.05`. Source: `scripts/map/view3d/map_view_lighting.gd` and `docs/MATERIAL_STYLE_LOCK_KIT.md`. |
| Value hierarchy | **Pass - normative contract; capture review remains open** | ART_BIBLE v2 orders readability as player/NPC silhouette and feedback, interactables/hazards/VFX, routes/doors/collision boundaries, landmarks, meso detail, then terrain micro detail. It requires tiers 1-3 to survive grayscale/squint review in day, night, fog, rain, and firelight. No new P0-040 capture was recorded here. |
| Day/night settings | **Pass - implementation reconciled** | Day/night is deterministic lighting/post, not separately recolored textures. Night is required to be at least 20% darker while preserving local hue; runtime proxy is enforced by `MapViewLighting.post_grade_luminance_proxy`. ART_BIBLE and style-lock values match the runtime day/night grade listed above. |
| Style-lock version | **Pass - approved version** | `style-lock-v1.1` is the current material lock, recorded 2026-07-30 and authorized by ADR 0018. `style-lock-v1.0` remains migration evidence only; new material decisions use v1.1. |

## Remaining freeze blockers

1. **GPU texture-memory capture:** unresolved. Headless zero-byte readings cannot establish GPU texture memory. Run `BENCHMARK_HEADLESS=0 tools/run_performance_report.sh` and retain the resulting evidence outside Git.
2. **Minimum-hardware frame-time capture:** unresolved. The P0-038 host is `development-baseline-m5-pro` and is explicitly not the minimum-supported-hardware declaration. Run the non-headless benchmark against `tools/benchmarks/minimum-hardware.json` before treating frame time as P0-040 acceptance evidence.
3. **Current-checkout provenance:** the measured P0-038 numbers are historical (`a87b600...`), while this reconciliation is authored at `2a94045...`; rerun evidence after the current runtime/asset state is intentionally outside this report's allowlist.

Until the two non-headless measurements are recorded and reviewed, this report establishes the authoritative reconciliation baseline but does not claim technical visual-freeze completion.

## References

- [`docs/ART_BIBLE.md`](../ART_BIBLE.md)
- [`docs/adr/0013-authorial-visual-direction-without-blind-ux-panels.md`](../adr/0013-authorial-visual-direction-without-blind-ux-panels.md)
- [`docs/adr/0018-saturated-hdr-fantasy-anime-visual-direction.md`](../adr/0018-saturated-hdr-fantasy-anime-visual-direction.md)
- [`docs/MATERIAL_STYLE_LOCK_KIT.md`](../MATERIAL_STYLE_LOCK_KIT.md)
- [`docs/reports/p0_038_3d_view_comparison.md`](p0_038_3d_view_comparison.md)
- [`project.godot`](../../project.godot)
