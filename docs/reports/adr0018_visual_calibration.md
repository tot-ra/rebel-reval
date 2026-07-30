# ADR 0018 visual calibration

**Baseline commit:** `290c63b1` (Adopt saturated fantasy visual direction)
**Date:** 2026-07-30
**Scope:** palette / grading constants and regression evidence only. No historical geometry or parallel map/asset WIP.

## Method

Matched day/night plates for three representative maps under forced clear weather:

| Map | Why |
|---|---|
| `kalev_smithy` | fire, windows, interior warm/cool |
| `lower_town_slice` | street readability, roofs, player-scale overview |
| `reval_harbor_east` | water, coastal sand, outdoor sky |

Cameras: gameplay-scale third-person perspective at spawn, and orthographic top-down overview.
Capture tool: `tools/capture_adr0018_visual_calibration.gd` (one Godot process per frame).
Plates: `docs/reports/images/adr0018_calibration/`.

## Checklist

| Criterion | Result |
|---|---|
| Saturation (day outdoor) | Pass - Lower Town / Harbor day mean sat ~0.40-0.59 |
| Warm/cool separation | Pass - smithy night fire vs indigo fill; outdoor cool shadows |
| Local color at night | Pass with notes - smithy and Lower Town retain material hue near light; deep outdoor voids still dark |
| AgX highlight clipping | Pass - sparse highlight clip ratio <= 0.003 on day plates |
| Bloom only on allowed sources | Pass - glow threshold raised to `1.05`; bloom limited to fire/windows |
| Player / interactable readability | Pass on day and smithy night (anvil/forge readable); outdoor night still silhouette-first |
| No HDR-display marketing claim | Pass - docs keep SDR/GL Compatibility wording; HDR means scene-referred AgX path only |

## Grading constants after calibration

Frozen in `scripts/map/view3d/map_view_lighting.gd`, `docs/ART_BIBLE.md`, and `docs/MATERIAL_STYLE_LOCK_KIT.md`:

| Pass | Day | Night |
|---|---:|---:|
| Exposure | 0.98 | 0.90 |
| Saturation | 1.20 | 1.14 |
| Contrast | 1.12 | 1.08 |
| Brightness | 1.03 | 0.89 |
| Glow HDR threshold | 1.05 | 1.05 |
| Glow intensity | 0.32 | 0.48 |
| Glow bloom / strength / mix | 0.10 / 1.0 / 0.05 | same |
| Ambient energy | 0.85 | 0.92 |
| Sun energy | 1.20 | 0.72 |

Night post-grade luminance proxy remains <= 80% of day. Clean-painted night terrain multipliers were raised so grass/water keep local hue.

## Capture metrics (final pass)

| Plate | mean Y | clip_hi | sat |
|---|---:|---:|---:|
| kalev_smithy third_person day | 70.33 | 0.000 | 0.466 |
| kalev_smithy third_person night | 9.53 | 0.000 | 0.627 |
| kalev_smithy top_down day | 40.07 | 0.003 | 0.142 |
| kalev_smithy top_down night | 4.14 | 0.000 | 0.215 |
| lower_town_slice third_person day | 122.24 | 0.000 | 0.397 |
| lower_town_slice third_person night | 8.60 | 0.000 | 0.244 |
| lower_town_slice top_down day | 99.82 | 0.000 | 0.497 |
| lower_town_slice top_down night | 4.38 | 0.000 | 0.482 |
| reval_harbor_east third_person day | 85.33 | 0.000 | 0.417 |
| reval_harbor_east third_person night | 11.37 | 0.000 | 0.318 |
| reval_harbor_east top_down day | 117.13 | 0.000 | 0.586 |
| reval_harbor_east top_down night | 0.88 | 0.000 | 0.166 |

Harbor top-down night remains the darkest plate because the orthographic overview frames large water/sky mass; third-person harbor night is the better coastal readability check.

## Verification

```bash
python3 tools/verify_adr0018_calibration_captures.py
tools/run_godot_checked.sh adr0018-lighting -- "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_view_lighting
tools/run_godot_checked.sh adr0018-programmatic -- "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_programmatic_map
tools/run_godot_checked.sh adr0018-outdoor -- "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_outdoor_map_packages
python3 tools/generate_active_docs_report.py --check
```
