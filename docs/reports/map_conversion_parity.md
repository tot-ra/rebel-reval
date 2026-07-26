# Map conversion parity (P2-021a / P2-021)

Gameplay-parity scaffold for the converted **Kalev smithy** interior and **Lower Town slice** exterior.
Visual human sign-off remains open under **P2-021** after **P0-101**.

## Gameplay parity

| Map | Topology trace | Godot suite | Anchor accounting |
|-----|----------------|-------------|---------------------|
| `lower_town_slice` | `street_start` -> `smithy_door` -> `brewery_door` -> `checkpoint_west` -> `checkpoint_east` | `test_lower_town_slice_map` | 11/11 anchors in `tests/fixtures/maps/lower_town_slice.parity.json` |
| `kalev_smithy` | `door_courtyard` -> `anvil` -> `ledger` -> `bed_alcove` | `test_kalev_smithy_map` | 3/3 anchors in `content/maps/kalev_smithy.rrmap` |

Automated checks:

- `python3 tools/verify_map_conversion_parity.py`
- `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_lower_town_slice_map`
- `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_kalev_smithy_map`

Rejected anchors: none (empty `rejected_anchors` arrays in `docs/data/map_conversion_parity_manifest.json`).

## Capture evidence

| Capture | Role | Notes |
|---------|------|-------|
| `map_conversion_smithy_before.png` | Legacy reference | Interim `smithy_courtyard` prototype framing |
| `map_conversion_smithy_after_day.png` | Converted day | `kalev_smithy` programmatic interior |
| `map_conversion_smithy_after_night.png` | Converted night | Matched framing, brighter-than-night check |
| `map_conversion_lower_town_before.png` | Legacy reference | Interim courtyard exterior until matched legacy Lower Town capture |
| `map_conversion_lower_town_after_day.png` | Converted day | `lower_town_slice` production exterior |
| `map_conversion_lower_town_after_night.png` | Converted night | Matched framing, brighter-than-night check |

All captures are 1280x720 PNG evidence under `docs/reports/images/`.

## Visual review

| Field | Value |
|-------|-------|
| Task | **P2-021** (blocked on **P0-101** and maintainer sign-off) |
| Signed | `false` |
| Reviewer | _pending_ |
| Review date | _pending_ |
| Scope | Composition, depth order, silhouette separation, interaction readability, day/night value hierarchy at gameplay scale |

Close **P2-021** only after maintainer records accept here and reruns:

```bash
python3 tools/verify_map_conversion_parity.py --require-human-sign-off
```
