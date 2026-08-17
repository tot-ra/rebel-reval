# P0-040 lighting, grade, and material style-lock

Recorded: 2026-08-17
Task: `R-568 / P0-040`
Related decomposition: `R-111` lighting freeze fields; `R-567` engine/camera/world-scale lock

## Freeze status

**Lighting and material contract reconciled; final P0-040 technical freeze remains BLOCKED.** The normative documents and current runtime agree on the authored lighting, shadow, post-grade, day/night, value-hierarchy, and material-lock values recorded below. This report freezes the contract for review; it does not change runtime settings, renderer configuration, camera code, map data, shaders, materials, or assets.

`Pass` in this report means source or contract reconciliation, or a passing development/calibration check. It does not mean that a new GPU capture, a minimum-hardware run, or maintainer approval has completed.

## Authority and evidence boundary

- [ART_BIBLE v2](../ART_BIBLE.md) is normative for the approved saturated fantasy/anime direction, value hierarchy, HDR-range terminology, day/night readability, and new art decisions.
- [ADR 0018](../adr/0018-saturated-hdr-fantasy-anime-visual-direction.md) is the accepted maintainer-directed visual decision.
- [MATERIAL_STYLE_LOCK_KIT.md](../MATERIAL_STYLE_LOCK_KIT.md) is the material authority and records `style-lock-v1.1`.
- Live lighting and post-grade ownership is [MapViewLighting](../../scripts/map/view3d/map_view_lighting.gd), installed by [MapView3D](../../scripts/map/view3d/map_view_3d.gd).
- Live astronomical angle ownership is [SkyAstronomy](../../scripts/map/view3d/sky_astronomy.gd), exposed through [SkyWeather3D](../../scripts/map/view3d/sky_weather_3d.gd).
- [P0-040 baseline reconciliation](p0_040_baseline_reconciliation.md) establishes that the current checkout values are aligned, while GPU texture-memory and minimum-hardware frame-time evidence remain absent.
- [ADR 0018 visual calibration](adr0018_visual_calibration.md) is matched day/night development evidence from baseline commit `290c63b1`; it is not a current-checkout minimum-hardware acceptance run.
- [P0-038 3D comparison](p0_038_3d_view_comparison.md) is a headless development baseline from commit `a87b6002917fdfdc7afdb3fbf2fd8b1c030207d0`; its zero-byte renderer memory readings are not GPU evidence.

## Contract matrix

### Renderer and HDR-range meaning

| Field | Authored/frozen contract | Evidence status |
|---|---|---|
| Renderer | Godot 4.7, `GL Compatibility` desktop/mobile renderer | **Pass - source reconciliation.** Current pipeline is SDR output. |
| HDR-range meaning | Scene-referred values may exceed display white; AgX compresses highlights before SDR output; emissive separation and controlled bloom are allowed | **Pass - normative contract.** This is an internal HDR-like response only. |
| Unsupported delivery claims | Do not claim HDR10, wide-gamut, HDR-monitor, or HDR-display delivery | **Pass - wording check.** ADR 0018 explicitly rejects that claim; calibration verifier rejects HDR10 delivery claims. |
| UI boundary | World UI and screen-space UI must not inherit world bloom; UI is graded separately from world effects | **Pass - normative contract.** See material kit wiring notes and ART_BIBLE value hierarchy. |

### Light direction, sun angle, and shadow assumptions

There is no fixed authored Euler angle for the sun. The angle is deterministic and date-driven:

- World frame: `+X` east, `-Z` north, `+Y` zenith.
- Solar reference: Reval latitude `59.437°`, axial tilt `23.44°`, campaign vernal-equinoctial reference day `72.0`; local solar noon is progress `0.5`.
- `SkyAstronomy.celestial_direction()` computes the local ENU vector from solar declination and hour angle. `solar_direction()` and `solar_elevation_degrees()` supply the live direction/elevation.
- At twilight, the directional light blends from date-driven lunar direction to solar direction with `smoothstep(-6.0, 0.0, solar_elevation)`. The light basis is `Basis.looking_at(-light_direction, Vector3.UP)` because `DirectionalLight3D` emits along local `-Z`.
- Observable angle assumptions are therefore east-to-west daily traversal, seasonal sunrise/sunset, and moon-following night shadows, not a static noon-only light.

| Shadow field | Live value | Evidence status |
|---|---:|---|
| Shadow enabled | `true` | **Pass - source and test contract** |
| Shadow mode | `SHADOW_PARALLEL_4_SPLITS` | **Pass - source and test contract** |
| Max distance | `76.34375` world units, derived from `33.75 * 1.5 * 1.35 + 8.0` | **Pass - implementation reconciliation** |
| Split 1 / 2 / 3 | `0.08` / `0.22` / `0.48` | **Pass - source reconciliation** |
| Blend splits | `true` | **Pass - source and test contract** |
| Shadow bias | `0.05` | **Pass - source reconciliation** |
| Shadow normal bias | `1.2` | **Pass - source reconciliation** |
| Shadow blur | `0.0` | **Pass - source and test contract** |
| Angular distance | `0.0` | **Pass - crisp authored shadow contract** |
| Weather opacity | `clamp(1.0 - overcast * 0.85, 0.12, 1.0)` | **Pass - live weather rule.** Overcast softens/dims shadow presence locally without removing the shadow system. |

Live sources: [`map_view_lighting.gd`](../../scripts/map/view3d/map_view_lighting.gd#L124-L148), [`map_view_3d.gd`](../../scripts/map/view3d/map_view_3d.gd#L82-L87), [`map_view_3d.gd`](../../scripts/map/view3d/map_view_3d.gd#L741-L754), and [`sky_astronomy.gd`](../../scripts/map/view3d/sky_astronomy.gd#L9-L103).

### Day/night lighting

Night is deterministic lighting/post-grade over the rich day master. It is not a separately recolored texture set.

| Field | Day/noon | Night/midnight | Evidence status |
|---|---:|---:|---|
| Sun color | `Color8(255, 243, 222)` | `Color8(142, 162, 210)` | **Pass - live source and normative alignment** |
| Sun energy | `1.20` | `0.72` | **Pass - live source and test contract** |
| Ambient color | `Color8(168, 178, 189)` | `Color8(58, 74, 112)` | **Pass - live source and normative alignment** |
| Ambient energy | `0.85` | `0.92` | **Pass - live source.** Night fill is intentionally not reduced below day fill so local color survives outside emissive pools. |
| Background color | `Color8(31, 30, 28)` | `Color8(14, 18, 28)` | **Pass - live source and normative alignment** |
| Night readability rule | - | At least 20% darker by the post-grade luminance proxy while retaining local hue | **Pass - source/test contract; capture review remains open** |

Weather and celestial modifiers are layered over this baseline:

- Sunset, overcast, and lightning use authored colors `Color8(255, 148, 64)`, `Color8(172, 182, 196)`, and `Color8(206, 220, 255)`.
- Lightning adds sun energy `1.6` and ambient energy `0.9` while remaining a transient authored event.
- Morning mist is height-biased exponential fog in outdoor views only: color `Color8(200, 210, 220)`, maximum density `0.018`, height `3.5`, maximum height density `1.1`, with a `3.0` hour pre-sunrise and `2.5` hour post-sunrise window. The GL Compatibility renderer has no volumetric fog; this is not a claim of volumetric support.
- Enclosed interiors disable ground mist. Interior top-down views use a black clear color below the hidden ceiling so the outdoor sky does not compete with the room read.
- Shadows shift toward indigo/cobalt, moon edges may use cyan, and fire/windows remain amber/gold. Rain, fog, overcast, snow, lightning, sunrise, and sunset must not create a permanent gray wash.

### Post-grade and glow

| Post field | Day/noon | Night/midnight | Evidence status |
|---|---:|---:|---|
| Tonemap | AgX | AgX | **Pass - live source, ART_BIBLE, kit, and test** |
| Exposure | `0.98` | `0.90` | **Pass - exact source reconciliation** |
| Saturation | `1.20` | `1.14` | **Pass - exact source reconciliation** |
| Contrast | `1.12` | `1.08` | **Pass - exact source reconciliation** |
| Brightness | `1.03` | `0.89` | **Pass - exact source reconciliation** |
| Glow HDR threshold | `1.05` | `1.05` | **Pass - exact source reconciliation; selective glow gate** |
| Glow intensity | `0.32` | `0.48` | **Pass - exact source reconciliation** |
| Glow bloom | `0.10` | `0.10` | **Pass - exact source reconciliation** |
| Glow strength | `1.0` | `1.0` | **Pass - exact source reconciliation** |
| Glow mix | `0.05` | `0.05` | **Pass - exact source reconciliation** |
| Glow blend mode | `SOFTLIGHT` | `SOFTLIGHT` | **Pass - live source** |
| Enabled glow levels | `1`, `2`, `3` | `1`, `2`, `3` | **Pass - live source; levels `4`-`7` disabled** |

The runtime linearly interpolates these values from night to day using `day_blend`; it does not switch textures or apply a full-screen saturation overlay. Bloom is reserved for emissive fire, forge heat, windows, wet speculars, rim effects, and authorized magic. Matte walls, ordinary albedo, route marks, player/interactable silhouettes, and UI text must not become the dominant glow source.

### Value hierarchy and gameplay readability

The grayscale/squint priority order is frozen as follows, from highest to lowest:

1. Player/NPC silhouette and interaction/combat feedback.
2. Interactable props, hazards, and authorized VFX.
3. Doors, passages, route surfaces, and collision boundaries.
4. Landmark/building identity and faction color blocks.
5. Meso material detail.
6. Terrain variation and micro surface detail.

Acceptance rules:

- Tiers 1-3 must survive a grayscale/squint pass in day, night, fog, rain, and firelight.
- Readability is established by shape and value before hue; red/green alone may not encode a gameplay state.
- Surface texture may not create stronger edge density than the player or current interactable.
- Gameplay prompts, silhouettes, routes, and hazards must remain above background value noise in every phase.
- At least one quiet value/chroma field must remain around the active focal point; high saturation everywhere is a failure of emphasis.
- UI must retain text contrast and remain outside world bloom.

### Material style-lock contract

| Field | Frozen rule | Evidence status |
|---|---|---|
| Kit version | `style-lock-v1.1` | **Pass - exact authority/version reconciliation** |
| Recorded | `2026-07-30` | **Pass - kit metadata** |
| Authority | ADR 0018; palette/detail authority ART_BIBLE v2 | **Pass - source reconciliation** |
| v1.0 status | Migration/reference evidence only; not the current color target | **Pass - source reconciliation** |
| Surface model | Painterly PBR: stone remains mineral, cloth fibrous, metal metallic, skin skin; anime influence does not replace lit material response | **Pass - normative contract** |
| Albedo/light rule | Albedo contains no baked shadows, highlights, or bloom; bloom is runtime-only | **Pass - kit acceptance/wiring rule** |
| Required maps | Hero-visible sets should provide albedo, tangent normal, roughness, and AO/ORM where supported | **Pass - kit production rule** |
| Color space | sRGB albedo; linear normal/roughness/AO/ORM | **Pass - kit production rule** |
| Scale | One logic cell/world unit; default terrain repeat `1.0` world unit per tile unless authored otherwise | **Pass - source/kit contract; world-scale lock owned by R-567** |
| Detail levels | Macro silhouette/composition; meso construction/identity; micro close-camera craft. Micro detail must mip/LOD cleanly and must not become distant noise | **Pass - ART_BIBLE and kit contract** |
| Read distances | Macro top-down/distance; meso third-person; micro first-person/dialogue closeups | **Pass - kit contract** |
| Generation/curation | 2048 square preferred, 1024 minimum; CFG `6-8`; steps `30-50`; curate `2-4` candidates; record model/version/seed/prompt/post-process/license | **Pass - kit contract; provenance remains required per asset task** |

Current `style-lock-v1.1` material families and masters are:

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

Focal accents remain selective rather than architectural fills: hero crimson `#D9364D`, rebel indigo `#4052B5`, forge amber `#F0A13E`, moon cyan `#58C7E8`, copper/brass `#C98235`, and fire core `#FFD27A` as an emissive, not albedo, color.

## Measured development evidence

The following is evidence, not an authored replacement for the contract:

| Evidence | Result | Boundary |
|---|---|---|
| `python3 tools/verify_adr0018_calibration_captures.py` | **PASS**: all 12 matched plates exist at `1280x720`, are non-blank, day/night pairs differ, day/night luminance deltas meet the verifier, and outdoor day frames retain value variation | Calibration packet from ADR 0018; not a minimum-hardware GPU acceptance run |
| ADR 0018 visual calibration | **PASS**: outdoor day mean saturation approximately `0.397-0.586`; sparse highlight clip ratio at or below `0.003`; bloom/readability checks pass as documented | Baseline calibration evidence; deep outdoor night voids remain noted as silhouette-first |
| `test_map_view_lighting.gd` | **PASS**, 3/3: frozen AgX/glow values, day/night values, and at-least-20%-darker post-grade proxy | Headless source/contract test, not a visual GPU capture |
| `python3 tools/generate_p038_comparison_report.py --check` | **PASS**: P0-038 report is current | P0-038 is a development/headless performance baseline |
| `test_map_view_3d_lighting.gd` | **13 passed; 2 failed and 2 engine errors** in the current dirty checkout, all in `test_houses_get_evening_window_lights_with_per_building_variation` for `st_catherines_church` missing `WindowLights`; the remaining 13 lighting/celestial/weather tests passed | External current-checkout test defect observed during this task; no runtime repair is allowed by R-568, and the failure is not attributed to the grade constants |

The calibration verifier's contract is intentionally limited: it checks dimensions, non-blank output, day mean luminance, day/night luminance separation, non-identical pairs, and outdoor value variation. It does not prove HDR10/wide-gamut delivery, GPU texture memory, minimum-hardware frame time, or maintainer approval.

## Owned blockers and follow-up

1. **GPU texture-memory capture - owner: P0-040 technical-freeze follow-up (`R-569`/`R-570`).** P0-038 reports `RENDER_TEXTURE_MEM_USED = 0` and `RENDER_VIDEO_MEM_USED = 0` in the headless dummy renderer. Run `BENCHMARK_HEADLESS=0 tools/run_performance_report.sh` on the declared target and retain GPU evidence outside this report.
2. **Minimum-hardware frame-time capture - owner: P0-040 technical-freeze follow-up (`R-569`/`R-570`).** The existing `7.346 ms` Lower Town p95 is a development M5 Pro headless baseline, not a minimum-supported-hardware acceptance result. Measure against the declared minimum-hardware profile before closing the technical freeze.
3. **Current-checkout visual provenance - owner: P0-040 technical-freeze follow-up (`R-569`).** ADR 0018 plates and P0-038 measurements are historical development evidence. Re-capture the approved current runtime state if the maintainer packet requires current-checkout visual proof.
4. **Window-light test defect - owner: the existing map/view lighting test task, not R-568.** `st_catherines_church` lacks the expected `WindowLights` node in the current dirty checkout. R-568 records the boundary and does not widen its allowlist into runtime or test repair.
5. **Maintainer sign-off - owner: maintainer approval packet (`R-569`).** This report records the contract and evidence limits; it does not make the approval decision.

Until blockers 1-3 and maintainer sign-off are resolved, this document is an authoritative lighting/material reconciliation and review artifact, not a claim that P0-040 technical visual freeze is complete.

## Verification commands

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_view_lighting
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_view_3d_lighting
python3 tools/generate_p038_comparison_report.py --check
python3 tools/verify_adr0018_calibration_captures.py
git diff --check -- docs/reports/p0_040_lighting_grade_style_lock.md
```

## References

- [`docs/ART_BIBLE.md`](../ART_BIBLE.md)
- [`docs/MATERIAL_STYLE_LOCK_KIT.md`](../MATERIAL_STYLE_LOCK_KIT.md)
- [`docs/adr/0018-saturated-hdr-fantasy-anime-visual-direction.md`](../adr/0018-saturated-hdr-fantasy-anime-visual-direction.md)
- [`scripts/map/view3d/map_view_lighting.gd`](../../scripts/map/view3d/map_view_lighting.gd)
- [`scripts/map/view3d/map_view_3d.gd`](../../scripts/map/view3d/map_view_3d.gd)
- [`scripts/map/view3d/sky_astronomy.gd`](../../scripts/map/view3d/sky_astronomy.gd)
- [`scripts/map/view3d/sky_weather_3d.gd`](../../scripts/map/view3d/sky_weather_3d.gd)
- [`tests/godot/test_map_view_lighting.gd`](../../tests/godot/test_map_view_lighting.gd)
- [`tests/godot/test_map_view_3d_lighting.gd`](../../tests/godot/test_map_view_3d_lighting.gd)
- [`docs/reports/adr0018_visual_calibration.md`](adr0018_visual_calibration.md)
- [`docs/reports/p0_038_3d_view_comparison.md`](p0_038_3d_view_comparison.md)
- [`docs/reports/p0_040_baseline_reconciliation.md`](p0_040_baseline_reconciliation.md)
- [`docs/reports/p0_040_engine_camera_scale_lock.md`](p0_040_engine_camera_scale_lock.md)
