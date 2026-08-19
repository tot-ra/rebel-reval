# R-598 P0-100 Lower Town surface/elevation verification

**Task:** R-598 / P0-100 surface shares and elevation access
**Verification date:** 2026-08-19
**Map:** `lower_town_slice` / Workers' District
**Checkout:** shared worktree with unrelated staged, modified, deleted, and untracked WIP
**Decision:** **BLOCKED for the documented surface bands; PASS for elevation access and scoped authoring contracts.**

## Scope and decision rule

This verification checks the existing Lower Town authoring contract, composition metrics, and elevation runtime invariants. It is verification-only: no map geometry, threshold, parity fixture, parser, runtime, camera, asset, or review decision was changed. The `lower_town_slice` composition card is explicitly `enforce=false`, so its surface thresholds are advisory evidence rather than an activation gate. A passing parser/invariant suite does not convert a surface-band miss into a PASS.

## Contract baseline

`docs/data/map_composition_thresholds.json` defines the following `lower_town_slice` ranges:

| Metric | Documented range / cap | Enforcement | Source
|---|---:|---|---|
| `stone_pct` | `25..40%` | advisory (`enforce=false`) | `H04-H05`, `H09-H10`
| `earth_pct` | `35..50%` | advisory (`enforce=false`) | `H04-H05`, `H09-H10`
| `grass_pct` | `15..30%` | advisory (`enforce=false`) | `H04-H05`, `H09-H10`
| `max_cobblestone_pct` | `40%` | advisory (`enforce=false`) | `H04-H05`, `H09-H10`
| `elevation_range_min` | `0.3` | advisory (`enforce=false`) | `H04-H05`, `H09-H10`

The authoring contract independently requires the source and compiled runtime IDs to resolve and records that composition enforcement remains advisory.

## Measured result

A bounded Godot probe loaded `content/maps/lower_town_slice.rrmap`, built the terrain grid, and called `MapCompositionAudit.measure` with `docs/data/lower_town_authoring_contract.json`:

```text
surface_shares:
  stone_pct=4.58036204059243
  earth_pct=26.0902358749314
  grass_pct=69.3294020844761
  cobblestone_pct=4.58036204059243
  unbuilt_cells=14584
built_density_pct=22.189617457184
largest_empty_region_cells=9289
excluded_open_region_cells=6084
max_style_share_pct=47.5409836065574
elevation_range=1.48229014535609
profiles=4
```

Elevation access is present and exceeds the documented minimum. The measured surface shares do not match the advisory bands: stone and earth are below their lower bounds, while grass is above its upper bound. Cobblestone is within its cap. Because the card is non-enforced and the task is verification-only, this result is **BLOCKED/ADVISORY**, not a reason to alter the map or silently change the threshold card.

## Focused checks

| Check | Result | Interpretation
|---|---|---|
| `python3 -m unittest tests.python.test_verify_map_composition -v` | **PASS: 2 tests** | Threshold-card schema and registry coverage pass.
| `python3 -m unittest tests.python.test_verify_clean_checkout_load -v` | **PASS: 6 tests, 1 expected skip** | Clean-checkout helper contract passes; the product clean-load parser issue remains separately owned by R-604.
| `test_lower_town_authoring_contract` | **PASS: 2/2** | Lower Town source/runtime ownership, stable IDs, frontage rules, and advisory enforcement flag resolve.
| `test_lower_town_slice_map` | **BLOCKED: 18/19** | Surface, routes, collision, navigation, and map validation assertions pass. Canonical parity fails because the current staged R-547 layout has `door_side` where the fixture expects `footprint` at line 185. Existing owner: R-606.
| `test_r454_elevation_scope` | **PASS: 3/3** | All nine urban exterior maps compile in the elevation matrix; Lower Town's four profile IDs remain in scope.
| `test_r503_elevation_gameplay_invariants` | **PASS: 3/3** | Elevation values are finite/scoped, remain view-only, and do not change gameplay geometry/navigation or reciprocal transition identity.
| `python3 tools/verify_map_composition.py` | **BLOCKED by baseline** | Lower Town is correctly skipped because `enforce=false`. The independent enforced-map audit fails on `monastery_quarter` empty-region metric (`25774 > 22000`), outside R-598's Lower Town scope.

The checked Godot runs emitted only the known shutdown ObjectDB/resource-leak diagnostics in addition to the summaries above. Those diagnostics do not change the scoped test results.

## Existing follow-ups

- **R-607** (created by this verification): reconcile Lower Town's measured substrate with the P0-100 surface bands or revise the evidence-backed threshold through review. Keep `enforce=false` until the decision is explicit; preserve elevation as view-only.
- **R-606**: review the concurrent R-547 map layout and regenerate only the canonical Lower Town parity fixture after the semantic diff is approved.
- **R-604**: restore/land RRMap elevation parser support on clean HEAD and rerun the clean-checkout load gate. The live checkout's elevation suites pass, but clean HEAD evidence remains blocked by `elevation_area` / `elevation_ramp` parser diagnostics.

No duplicate monastery task was created. The composition verifier's `monastery_quarter` baseline failure is recorded as an out-of-scope environment/map follow-up for its existing owner.

## Final disposition

**R-598 verification complete as a deterministic blocked ledger.** The Lower Town elevation contract is operational and gameplay-safe in the current checkout. Surface-share acceptance is not met, even though the card is advisory, and parity remains blocked by concurrent layout WIP. Keep R-598's parent acceptance open until R-607 and R-606 are resolved; do not promote this report to a full P0-100 PASS.

## Sources

- [`Lower Town RRMap`](../../content/maps/lower_town_slice.rrmap)
- [`Lower Town authoring contract`](../data/lower_town_authoring_contract.json)
- [`Composition thresholds`](../data/map_composition_thresholds.json)
- [`test_lower_town_authoring_contract.gd`](../../tests/godot/test_lower_town_authoring_contract.gd)
- [`test_lower_town_slice_map.gd`](../../tests/godot/test_lower_town_slice_map.gd)
- [`test_r454_elevation_scope.gd`](../../tests/godot/test_r454_elevation_scope.gd)
- [`test_r503_elevation_gameplay_invariants.gd`](../../tests/godot/test_r503_elevation_gameplay_invariants.gd)
- [`verify_map_composition.py`](../../tools/verify_map_composition.py)
- [`r454_historical_elevation_profiles.md`](r454_historical_elevation_profiles.md)
- [`r454l_historical_elevation_acceptance.md`](r454l_historical_elevation_acceptance.md)
