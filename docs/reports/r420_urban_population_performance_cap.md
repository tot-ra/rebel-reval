# R-420 urban population performance-cap verification

Task: **R-420**
Scope: Lower Town urban population renderer capacity
Evidence source: `docs/reports/population_clusters_r419.json`

## Acceptance

The published R-419 population scenarios stay below the authored crowd-renderer capacity:

| Scenario | Active actors | Renderer capacity | Headroom |
| --- | ---: | ---: | ---: |
| Ordinary day | 21 | 64 | 43 |
| Market day | 33 | 64 | 31 |
| Night checkpoint | 12 | 64 | 52 |

The largest published scenario uses 33 of 64 MultiMesh instances, leaving 31 slots of deterministic capacity headroom. The profile-level actor caps are also checked, so a manifest count cannot pass by exceeding the profile contract.

This is a renderer-capacity gate for the authored urban crowd workload. It is not a replacement for the GPU frame-time proof in the vertical-slice performance gate (`P3-011` / `P3-012`).

## Verification

Focused Godot acceptance:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- \
  --filter=test_urban_population_performance_cap
```

The test loads the R-419 manifest, re-resolves every profile from its recorded phase/date/seed, checks civilian/watch/total counts against the profile, and registers the largest scenario through `MapViewCrowdRenderer` to prove the configured capacity remains 64.

## Result

**Pass** on 2026-08-05 after the focused Godot suite completed with zero failures and zero errors.
