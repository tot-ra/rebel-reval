# ADR 0043: Mobile renderer on Metal and opt-in HDR (EDR) output

- **Status:** Proposed (2026-10-09, from the P0-142 HDR spike). Needs maintainer approval before `project.godot` or `export_presets.cfg` change.
- **Amends:** the P0-142 "stay on GL Compatibility" recommendation in [renderer_evaluation.md](../reports/renderer_evaluation.md) and the Renderer row of [VISUAL_FIDELITY_PLAN.md](../VISUAL_FIDELITY_PLAN.md). Keeps [ADR 0018](./0018-saturated-hdr-fantasy-anime-visual-direction.md) grade values (AgX) as the starting point.

## Context

Godot 4.7 can present HDR (macOS EDR) so emissive highlights exceed SDR white while UI stays at reference white. It requires the Mobile or Forward+ renderer with Metal; the project ships `gl_compatibility`. The spike ([hdr_output_spike_2026-10-09.md](../reports/hdr_output_spike_2026-10-09.md)) measured on the M5 Pro development baseline:

- HDR output works on Mobile and Forward+ and is unsupported on Compatibility. With AgX at 4.0x headroom, fire reaches 2.3x and the sun 2.8x UI white; the real forge hearth peaks at 2.2-2.3x on about 0.6% of the frame.
- Mobile renders the current city at 13.6 ms median (74 FPS), Forward+ 20.2 ms, Compatibility 28.8 ms.
- No shader compile errors on any renderer, but the city ground and roof shaders regress on the RenderingDevice renderers (paving reads as grass, roads as a pale streak, roof blotches), interiors are about 1.7x brighter, and two post settings are SDR-only (soft-light glow, Filmic in the prologue).

## Decision

1. **Renderer:** `rendering/renderer/rendering_method="mobile"` with the Metal driver on macOS, after the blocking regressions are fixed and re-captured. Forward+ is not chosen: it is about 50% slower here and its extras (SDFGI, SSIL, volumetric fog, clustered lights) are not needed by any planned task. It can be revisited by a later ADR.
2. **HDR is opt-in and follows the OS.** `display/window/hdr/request_hdr_output=true` and `rendering/viewport/hdr_2d=true`, plus a Settings toggle (default on when the screen reports headroom). SDR output stays the reference look: the AgX grade must read the same at headroom 1.0.
3. **Highlights come from the tonemapper, not from `output_max_linear_value`.** All 3D environments use AgX; glow switches from soft light to additive or screen and is retuned. Code that needs the headroom reads `Window.get_output_max_linear_value()` per frame or listens to `output_max_linear_value_changed`.
4. **One shader path.** New shaders target the RenderingDevice renderers; existing `CURRENT_RENDERER == RENDERER_COMPATIBILITY` branches are removed once the switch lands.

## Scope trade-off (AGENTS.md rule)

Removed scope of equivalent cost: maintaining GL Compatibility parity, that is the dual `RENDERER_COMPATIBILITY` branches in the water, underwater, god-ray, fog, cloud-shadow and aerial-perspective shaders, the 16-sampler budget workarounds, and any future web/HTML5 export path (already outside the macOS-only preset). No gameplay scope is added.

## Alternatives

- **Stay on Compatibility.** Keeps today's look and no migration cost, but HDR output is impossible and the city runs at about half the frame rate.
- **Forward+.** Same HDR result, more features, but 20.2 ms vs 13.6 ms median and a 37.5 ms worst shot.
- **Fake HDR on Compatibility** (brighter bloom, UI dimmed below white). Does not exceed SDR white on an EDR screen; rejected.

## Consequences

- Blocking fixes before the switch: city ground `splat`/`roads` and roof weathering on RD, interior grade retune, prologue Filmic -> AgX, soft-light glow -> additive/screen.
- Every visual acceptance plate is re-captured on Mobile; plates captured on Compatibility become historical.
- Mobile keeps per-mesh light limits (8 omni, 8 spot), like Compatibility, so no lighting design changes are required.
- Minimum-hardware frame time is still unmeasured; the perf report harness must be repaired first (it loads retired legacy scenes).
- Tracked by **R-1537** (switch, gated on this ADR), blocked by **R-1535** (city shader regressions on RD) and **R-1536** (perf harness repair).
