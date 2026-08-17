# P0-040 maintainer technical-freeze approval packet

Recorded: 2026-08-17
Task: `R-569 / P0-040`
Parent: `R-111 / P0-040`
Decision state: **PENDING - technical visual freeze is not accepted or rejected in this checkout**

## Purpose and governing approval path

This packet is the maintainer-facing decision record for the P0-040 technical visual production freeze. It reconciles the baseline, engine/camera/scale, and lighting/grade/style-lock matrices without changing runtime code, assets, maps, tests, renderer settings, or active production scope.

[ADR 0013](../adr/0013-authorial-visual-direction-without-blind-ux-panels.md) cancels the blind participant-panel gate. No blind readability study is required for this decision. The governing approval path is:

1. maintainer review of the complete ART_BIBLE v2 and technical value set;
2. P0-038 technical evidence, including the required non-headless minimum-supported-hardware/GPU evidence; and
3. an explicit maintainer `ACCEPT`, `REJECT`, or `PENDING` decision recorded in this packet.

A source-level reconciliation or a passing headless development check is not itself maintainer approval.

## Evidence packet links

| Artifact | Role | Current boundary |
|---|---|---|
| [`p0_040_baseline_reconciliation.md`](p0_040_baseline_reconciliation.md) | R-566 baseline and P0-038 freeze-gap reconciliation | Authoritative source reconciliation; explicitly remains blocked on non-headless GPU/minimum-hardware evidence. |
| [`p0_040_engine_camera_scale_lock.md`](p0_040_engine_camera_scale_lock.md) | R-567 engine, camera, and world-scale matrix | Contract is documented, but R-567 remains `in_progress`; its camera integration suite is red. |
| [`p0_040_lighting_grade_style_lock.md`](p0_040_lighting_grade_style_lock.md) | R-568 lighting, grade, day/night, value hierarchy, and material matrix | Contract and calibration are documented, but current lighting integration has failures/errors and approval is not claimed. |
| [`p0_038_3d_view_comparison.md`](p0_038_3d_view_comparison.md) | P0-038 performance and renderer evidence | Headless development baseline only; its zero-byte texture readings are not GPU evidence. |
| [`p0_040_decomposition_verification.md`](p0_040_decomposition_verification.md) | R-570 parent-readiness verification | Recommends keeping R-111/P0-040 blocked. |
| [`../ART_BIBLE.md`](../ART_BIBLE.md) | Normative v2 visual direction | Direction is accepted through ADR 0018; technical production freeze remains gated. |
| [`../adr/0013-authorial-visual-direction-without-blind-ux-panels.md`](../adr/0013-authorial-visual-direction-without-blind-ux-panels.md) | Approval-process authority | Blind-panel gate cancelled; maintainer review plus P0-038 evidence govern. |

## Complete frozen value set for review

The values below are the proposed technical freeze set. `Reconciled` means that the value is present in the cited source contract. It does not mean that the P0-040 approval gate is green.

| R-111 freeze field | Frozen value | Source and evidence state |
|---|---|---|
| Engine | Godot `4.7` | `project.godot`; source contract reconciled. |
| Renderer | `GL Compatibility` for desktop and mobile; current delivery is SDR | `project.godot`, ART_BIBLE v2, ADR 0018; selected source value reconciled, GPU acceptance pending. |
| Perspective | Exterior default: perspective over-the-shoulder third person, FOV `65°`; first-person alternate FOV `75°`; orthographic top-down retained as an alternate | ADR 0015 and `MapViewRuntimeCamera`; source contract reconciled, camera integration still blocked. |
| Internal resolution | Design viewport `1920x1080`, `window/stretch/mode = "viewport"`; no separate lower internal-resolution target | `project.godot`, `scripts/display/display_window.gd`; source contract reconciled. |
| Camera angles | Orthographic top-down pitch `-30°`, yaw `45°`; third-person pitch `-12°`; first-person pitch `-10°`; authored pitch clamps remain `-55°..35°` and `-80°..80°` respectively | `MapView3D`, `MapViewRuntimeCamera`, ADR 0015; values reconciled, camera integration suite has 6 assertion failures. |
| Orthographic size and zoom | Gameplay orthographic size `33.75`; zoom band `10.125..50.625` (`0.3..1.5` factors); construction camera uses distance `90`, far plane `800`, margin `1.15`, headroom `5.0` | `CharacterScale`, `MapViewRuntimeCamera`, `MapView3D`; source contract reconciled. |
| World scale | One authored gameplay cell equals `1.0` world unit; authored map cell remains `32 px`; logic-to-world bridge is one-way; visible character height `2.0` world units and reference framing target `64 px` at `1080 px` | `MapViewBridge`, `MapTypes`, `CharacterScale`; deterministic source contract reconciled. |
| Mesh-builder height and pivot rules | Authored wall heights convert through `world_scale(cell_size)`; walls at or above `128 px` use `1.5x` fortification height unless explicitly overridden; lower fences/courtyard walls keep authored scale; building roots are footprint-centered at ground level, wall boxes are vertically centered at `height / 2`, roofs sit at resolved wall tops | `MapTypes`, `MapViewMeshBuilderBuildings`; source contract reconciled. |
| Light angles | No fixed authored Euler angle. World frame is `+X` east, `-Z` north, `+Y` zenith; Reval latitude `59.437°`, axial tilt `23.44°`, vernal-equinoctial reference day `72.0`, solar noon at progress `0.5`; twilight blends lunar to solar direction with `smoothstep(-6.0, 0.0, solar_elevation)` | `SkyAstronomy`, `SkyWeather3D`, R-568 matrix; deterministic date-driven angle contract reconciled. |
| Lighting | Day sun energy `1.20`, night `0.72`; day sun `Color8(255, 243, 222)`, night `Color8(142, 162, 210)`; ambient day `Color8(168, 178, 189)` at `0.85`, night `Color8(58, 74, 112)` at `0.92`; backgrounds day `Color8(31, 30, 28)`, night `Color8(14, 18, 28)` | `MapViewLighting`, ART_BIBLE v2, ADR 0018, R-568; source/test contract reconciled. |
| Shadows | Enabled; `SHADOW_PARALLEL_4_SPLITS`; max distance `76.34375`; split positions `0.08 / 0.22 / 0.48`; blended splits; bias `0.05`; normal bias `1.2`; blur `0.0`; angular distance `0.0`; weather opacity `clamp(1.0 - overcast * 0.85, 0.12, 1.0)` | `MapViewLighting`, `MapView3D`, `SkyAstronomy`, R-568; source/test contract reconciled, not a new GPU capture. |
| Post-grade | AgX; day exposure/saturation/contrast/brightness `0.98 / 1.20 / 1.12 / 1.03`; night `0.90 / 1.14 / 1.08 / 0.89`; glow threshold `1.05`; intensity `0.32 / 0.48`; bloom `0.10`; strength `1.0`; mix `0.05`; softlight; enabled levels `1, 2, 3` only | `MapViewLighting`, ART_BIBLE v2, MATERIAL_STYLE_LOCK_KIT; exact source reconciliation and contract test pass. |
| Value hierarchy | `1` player/NPC silhouette and interaction/combat feedback; `2` interactables, hazards, authorized VFX; `3` doors, passages, routes, collision boundaries; `4` landmarks/building identity/faction blocks; `5` meso detail; `6` terrain variation/micro detail | ART_BIBLE v2 and R-568; tiers 1-3 must survive grayscale/squint review in day, night, fog, rain, and firelight. Capture review remains open. |
| Day/night settings | One rich day-master asset set; night is deterministic light/post rather than recolored textures; night is at least `20%` darker by the post-grade luminance proxy while retaining local hue; shadows indigo/cobalt, moon edges cyan, fire/windows amber/gold; weather uses authored color scripts | ART_BIBLE v2, `MapViewLighting`, R-568; source/test contract pass, current visual/minimum-hardware acceptance remains open. |
| Style-lock version | `style-lock-v1.1`, recorded `2026-07-30`, authority ADR 0018 and ART_BIBLE v2; v1.0 is migration/reference evidence only | `MATERIAL_STYLE_LOCK_KIT.md`, ADR 0018, R-568; version reconciled. |

### Material family values

The technical freeze uses the following `style-lock-v1.1` material families and masters. These are albedo/reference colors, not emitted light values:

| Family | Master | Supporting range |
|---|---|---|
| `stone` | `#9EADB9` | `#667889` shadow, `#C8D1D3` light |
| `plaster` | `#E7C98E` | `#B89B73` shade, `#F3DFB3` light |
| `timber` | `#6B3F35` | `#342B30` tar, `#A2693F` cut |
| `roof_tile` | `#B94A3D` | `#8E3837` brick, `#D76643` sunlit |
| `mud` | `#9A5A3F` | `#663B38` umber, `#C9873D` ochre |
| `cobble` | `#7F91A1` | `#586979` deep, `#AEBBC2` pale |
| `hay` | `#E3B83F` | `#C99732` straw, `#F2CE62` sunlit |
| `water` | `#168FAA` | `#14617C` deep teal, `#46C7D8` cyan |

Selective focal accents are hero crimson `#D9364D`, rebel indigo `#4052B5`, forge amber `#F0A13E`, moon cyan `#58C7E8`, copper/brass `#C98235`, and fire core `#FFD27A` as emissive rather than albedo.

## Evidence and remaining limitations

### Passing evidence

- `python3 tools/generate_p038_comparison_report.py --check` is the required P0-038 generator check and passes in the current checkout.
- `python3 -m unittest tests.python.test_generate_p038_comparison_report -v` is the focused P0-038 unit test and is expected to pass 5/5.
- The historical P0-038 headless Lower Town p95 is `7.346 ms` against the `16.67 ms` steady-state reference.
- The P0-038 report, ADR 0018 calibration, R-566, and R-568 all preserve their evidence boundaries instead of presenting headless or historical measurements as GPU acceptance.

### Blockers that keep the decision pending

1. **Minimum-hardware/GPU evidence is missing.** P0-038 reports `RENDER_TEXTURE_MEM_USED = 0` and `RENDER_VIDEO_MEM_USED = 0` in the dummy renderer. A non-headless benchmark on the declared minimum-supported-hardware profile is required before frame time or texture memory can support acceptance.
2. **R-567 is not complete.** Its contract is documented, but the focused camera integration suite records 6 assertion failures involving collision pull-out, first-person eye height, third-person boom distance, and scroll-zoom restoration.
3. **Current lighting integration is not green.** R-568 records 13 passed tests, 2 failed tests, and 2 engine errors around the missing `WindowLights` contract for `st_catherines_church`. R-568 did not widen its allowlist into runtime/test repair.
4. **Evidence revisions are not one synchronized clean acceptance snapshot.** P0-038 measurements are historical development evidence, while the reconciliation reports describe the current shared checkout and explicitly note unrelated worktree WIP.
5. **The parent is not ready to advance.** R-570 recommends keeping R-111/P0-040 `todo`; no approval can be inferred from R-566 or R-568.

These limitations are blockers, not rejected design choices. The reconciled values remain the proposed baseline for the next maintainer review.

## Explicit maintainer decision record

| Decision field | Record |
|---|---|
| Decision | **PENDING** |
| Maintainer | Not recorded in this checkout |
| Decision date | Not recorded |
| Technical freeze accepted | **No** - no acceptance claim is made by this packet |
| Technical freeze rejected | **No** - the proposed values are not rejected; evidence and review are incomplete |
| Blind participant study required | **No** - cancelled by ADR 0013 |
| Governing approval path | Maintainer review plus P0-038 technical evidence, including non-headless minimum-hardware/GPU evidence |
| Current parent state | Keep R-111/P0-040 `todo`; do not start broader active-district conversion on this packet alone |

### Required maintainer action

A maintainer may replace `PENDING` with `ACCEPT` only after reviewing this complete value set and the linked matrices, confirming the required P0-038 minimum-hardware/GPU evidence, and recording the decision date and identity here. If the maintainer accepts, a separate scoped coordination change must update ART_BIBLE v2 and the P0-040 roadmap/task wording so they no longer describe the technical freeze as pending. If the maintainer rejects, preserve the blocker and record the replacement direction. Until then, this packet intentionally leaves `ART_BIBLE.md`, ADR 0013, `TODO.md`, and `docs/ROADMAP.md` unchanged.

## Verification record

Commands for this packet:

```bash
python3 tools/generate_p038_comparison_report.py --check
python3 -m unittest tests.python.test_generate_p038_comparison_report -v
python3 tools/generate_active_docs_report.py --check
python3 tools/verify_adr0018_calibration_captures.py

git diff --check -- docs/reports/p0_040_maintainer_approval_packet.md
```

The active-document report scans active Markdown and excludes `docs/reports/**`; the packet therefore does not require regeneration of the generated active report. Any pre-existing repository-wide active-report drift must remain separately reported and must not be treated as approval evidence.

## Scope boundary

This packet does not perform a blind study, renderer switch, runtime tuning, camera repair, lighting repair, asset generation, map conversion, active-district activation, or parent closure. It records the pending maintainer decision and preserves every unresolved evidence limitation.
