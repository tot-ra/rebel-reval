# R-938 cloudy continuity visual review

- Task: R-938
- Parent: R-920 / R-738 / R-713
- Reviewer: Codex (automated evidence review)
- Review date: 2026-09-28
- Packet: `r713-sky-weather-continuity-v1`
- Renderer: Metal capture packet, 1280x720
- Decision: **ACCEPT - cloudy is visually distinct from both clear and overcast in all reviewed states.**

## Scope and boundary

This is the named review gate for the first-class `cloudy` scenario. It reviews the committed R-920 Metal packet only; it does not retune weather, replace captures, or claim parent R-713 acceptance. The source packet remains bounded by `docs/reports/r713_sky_weather_continuity.md`: it proves the captured `lower_town_slice` -> `monastery_quarter` handoff, while broader R-713 external and target-hardware gates remain separate.

The packet verifier passed on this checkout:

```text
python3 tools/verify_r713_sky_weather_evidence.py
R713_SKY_WEATHER_CONTINUITY_PASS
```

The focused structural suite also passed: `test_r713_sky_weather_continuity`, 4 tests, 0 failures, 0 errors. Godot emitted pre-existing invalid-UID fallback warnings for the shared hero GLBs; they did not affect the weather test result.

## Review criteria

For each map, time, and shelter state, the cloudy plate must remain recognisably separate from both comparison regimes:

- clear retains the clearer, brighter air identity;
- cloudy reads as cooler and dimmer broken-cloud weather rather than a relabelled clear state;
- overcast remains the brighter, more uniformly lifted cloud-cover treatment in this captured grade;
- the sheltered pair may hide rain only. Since cloudy has no rain emitter, exterior and sheltered framing must preserve the same cloudy lighting identity.

As a supporting reproducible signal, mean absolute RGB pixel deltas were calculated from the committed PNGs. They are not a substitute for visual judgment, but every cloudy plate has a non-zero and legible separation from both adjacent regimes.

## Named plate decisions

| Map | Time | Shelter | Cloudy vs clear / overcast mean absolute RGB delta | Decision | Visual finding |
|---|---|---|---:|---|---|
| `lower_town_slice` | day | exterior | 15.82 / 24.83 | Accept | Cooler, dimmer sky and ground than clear; does not collapse into the lifted overcast plate. |
| `lower_town_slice` | day | sheltered | 15.81 / 24.83 | Accept | The same cloudy grade persists under shelter without a weather-identity reset. |
| `lower_town_slice` | night | exterior | 5.16 / 11.37 | Accept | Cloudy retains a subtly cooler night treatment, distinct from both clear and overcast. |
| `lower_town_slice` | night | sheltered | 5.17 / 11.37 | Accept | Shelter preserves the cloudy night identity; no false rain-only change is present. |
| `monastery_quarter` | day | exterior | 10.96 / 25.80 | Accept | Broken-cloud grade remains between clear and overcast in the district camera view. |
| `monastery_quarter` | day | sheltered | 10.96 / 25.80 | Accept | Sheltered scene keeps the same distinct cloudy presentation. |
| `monastery_quarter` | night | exterior | 2.90 / 8.03 | Accept | The night distinction is restrained but visible, and is clearly not the overcast lift. |
| `monastery_quarter` | night | sheltered | 2.90 / 8.02 | Accept | Cloudy remains stable across the sheltered handoff view. |

## Conclusion

All eight prescribed cloudy plates are accepted. `cloudy` is a dedicated scenario ID with a visually stable, cooler broken-cloud identity across both maps, day/night, and exterior/sheltered views. It is not a duplicate of either `clear` or `overcast`.

This closes the R-938 review deliverable and removes the named cloudy-visual-review blocker for R-738. It does not close the parent R-713 acceptance ledger, which retains its separately documented external, water, performance, and target-hardware blockers.
