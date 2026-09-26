# R-641 / R-212 closeout: asset provenance and plot-dressing contract

Date: 2026-09-26. Board rows: R-641 (repository provenance reconciliation), R-212 (P2-066 rear-plot and street-threshold dressing kit).

## R-641: provenance drift

Earlier reports ([`p0_102_acceptance_reconciliation.md`](p0_102_acceptance_reconciliation.md), [`p0_102_clean_elevation_recheck.md`](p0_102_clean_elevation_recheck.md)) recorded the provenance gate as blocked by ten plot-dressing albedo sidecars without manifest rows and mixed-case `merchant_timber` asset IDs.

Rechecked on a detached clean `HEAD` worktree (`aa5e4b1c`):

| Check | Result |
|-------|--------|
| `python3 tools/validate_asset_sources.py` | PASS, exit 0: 1144 rows, 852 inventory paths covered, 842 active runtime assets covered |
| `python3 tools/verify_asset_lint.py` | PASS |
| `merchant_timber` asset IDs in `assets/SOURCES.csv` | All lowercase. Mixed case remains only in exported texture file paths, which the validator accepts |
| Plot-dressing bundle | GLB plus ten albedo textures tracked and covered |

The drift was already reconciled by earlier commits. No manifest rows were changed in this closeout.

## R-212: plot-dressing authoring contract

`docs/MAP_AUTHORING.md` already stated that `hoist_beam` and `loading_hatch` require `house_tier=merchant_stone` or `merchant_timber`. The compiler did not enforce this: `house_tier` was not an allowed prop field, so `test_burgher_plot_dressing` failed 2 of 4 tests.

Change:

- `MapBlueprintCompiler.PROP_OVERRIDE_KEYS` accepts `house_tier` (the prop compile step already copied it into runtime props).
- `MapBlueprintCompilerExpand.append_prop` checks `house_tier` against the closed R-003 allowlist. It rejects `hoist_beam` / `loading_hatch` unless the tier allows hoist hardware, so `craft_boda` and untiered placements are rejected. The check lives in `append_prop`, so props placed through prefab row slots get the same check.

No active map places hoist or hatch props, so no content changed.

## Verification

| Command | Result |
|---------|--------|
| `--filter=test_burgher_plot_dressing` | 4/4 |
| `--filter=test_burgher_house_typology_contract` | 3/3 |
| `--filter=test_map_rrmap_parser` | 15/15 |
| `--filter=test_map_blueprint_compiler` | 13/13 |
| `--filter=test_merchant_cart_kit` | 2/2 |
| `tools/validate_map_blueprints.gd` | 28 registered, 0 errors (warnings unchanged in kind) |
| `gdtoolkit.linter` / `formatter --check` on changed scripts | clean |
