# R-590 Lower Town ordinary-fabric handoff ledger

**Task:** R-590 / P0-101 ordinary-fabric handoff reconciliation
**Parent:** R-108 / P0-101
**Map:** `lower_town_slice` / Workers' District
**Verification date:** 2026-08-19
**Worktree:** shared worktree contains unrelated staged, modified, deleted, and untracked WIP. This ledger changes no runtime, map, asset, camera, budget, or review decision.
**Decision:** **BLOCKED - source/contract evidence is available for the authored tier mapping, but the ordinary-fabric production handoff is not complete. Keep R-108 open.**

## Scope and decision rule

This ledger reconciles R-590's six dependencies: R-209, R-210, R-211, R-212, R-213, and R-487. It maps each ordinary tier and plot dressing to its owner, named artifact paths, provenance/lint evidence, focused checks, and gameplay-scale visual status.

A source `house_tier` assignment, a procedural fallback, a generated reference plate, or a passing headless contract is not production-art or gameplay-scale visual acceptance. A tier is `PASS` only when its production artifact, provenance/lint evidence, focused check, and required matched gameplay-scale visual evidence are all present. Otherwise the tier is `BLOCKED` and the exact owner/action remains open.

## Dependency and owner reconciliation

| Board ref | Owner scope | Current board status | Ledger interpretation |
|---|---|---:|---|
| R-209 / P2-063 | `merchant_stone` production exterior kit | `todo` | No production-kit handoff. The owner must provide the deterministic generator, GLB/PBR/LOD/collision artifact, focused test, provenance/lint evidence, and gameplay-scale silhouette evidence. |
| R-210 / P2-064 | `merchant_timber` production exterior kit | `done` | Working-tree production evidence exists and the focused kit test passes. The current shared worktree still reports the bundle as staged deletions plus untracked replacements, so clean tracked delivery is not independently established here. Gameplay-scale tier acceptance is also missing. |
| R-211 / P2-065 | `craft_boda` production exterior kit | `todo` | No production-kit handoff. The owner must provide the compact craft-dwelling artifact, focused test, provenance/lint evidence, and gameplay-scale proof of the lower/compact silhouette. |
| R-212 / P2-066 | plot/street-threshold dressing kit | `todo` | No plot-dressing artifact or focused test was found. The owner must provide cellar-neck steps, fence/wall, yard gate, privy, well sweep, service lean-to/Hinterhaus, firewood stack, and merchant-only hoist/loading frames with parser/test evidence. |
| R-213 / P2-067 | Lower Town tier wiring | `done` | Authored source wiring is present and `test_burgher_house_tiers` passes. This is structural handoff evidence only; it does not replace the three production kits or gameplay review. |
| R-487 / P0-101b | ordinary frontage variation, wear, and visual handoff | `in_progress` | The ordinary-fabric review remains open. Existing R-532 evidence explicitly keeps gameplay-scale readability, repaired-state readability, and repetition review blocked. |

All six dependencies were queried with `tasks.get` during this verification. No duplicate follow-up task is created because the existing owner rows cover every unresolved action.

## Tier and dressing matrix

| Surface | Owner | Authored source / artifact state | Provenance and focused checks | Gameplay-scale visual status | Result and exact next action |
|---|---|---|---|---|---|
| `merchant_stone` | R-209 | `content/maps/lower_town_slice.rrmap` contains 14 authored `house_tier=merchant_stone` records. `assets/props/architecture/houses/merchant_stone/` is absent; `tools/generate_burgher_house_merchant_stone.py`, `tests/godot/test_burgher_house_merchant_stone.gd`, and `generated/blender/burgher_house_merchant_stone_v1/` are absent. | No tier-specific production row, focused kit test, or asset/lint evidence is available. Repository-wide validators cannot supply missing kit evidence. | `docs/reports/images/lower_town_p0_101/capture_manifest.json` has 10 matched day/night plates, but no stable tier IDs or tier observations. The capture matrix keeps `merchant_stone` day/night rows pending/blocked. | **BLOCKED.** R-209 must deliver the named production kit and then obtain a matched gameplay-scale day/night route observation for representative stone frontage. |
| `merchant_timber` | R-210 | `content/maps/lower_town_slice.rrmap` contains 14 authored `house_tier=merchant_timber` records. Working-tree artifacts: `assets/props/architecture/houses/merchant_timber/merchant_timber.glb`, `generated/blender/burgher_house_merchant_timber_v1/{brief.json,report.json,state.json}` and generated street/rear-yard references. `assets/SOURCES.csv` has a provenance row with SHA-256 `ec35e038cafa12f6e25ec1ec7b06fb38ec3cd71d5c876553c123ae4477bfae16`. | `--filter=test_burgher_house_merchant_timber`: **3 tests, 0 failures, 0 errors**. The test confirms imported production model use, profile/budget evidence, timber/shingle style, and no default hoist. `validate_asset_sources.py` and `verify_asset_lint.py` fail on broad pre-existing inventory/portrait/character drift; they do not establish a clean scoped handoff for this dirty bundle. | The generated references are not gameplay-scale route evidence. The dedicated packet has 10 valid 1280x720 non-blank PNGs, but its manifest has no `merchant_timber` token or stable-ID observation, and the matrix keeps the tier row pending/blocked. | **BLOCKED.** R-210/R-487 must preserve a clean tracked bundle and record a matched gameplay-scale day/night observation proving timber-dominant frontage distinct from stone and post-1400 Gothic treatment. |
| `craft_boda` | R-211 | `content/maps/lower_town_slice.rrmap` contains 23 authored `house_tier=craft_boda` records, including rear/service records. `assets/props/architecture/houses/craft_boda/` is absent; `tools/generate_burgher_house_craft_boda.py`, `tests/godot/test_burgher_house_craft_boda.gd`, and `generated/blender/burgher_house_craft_boda_v1/` are absent. | No tier-specific production row, focused kit test, or asset/lint evidence is available. | The capture manifest does not identify `craft_boda` or prove compact height, craft massing, roof readability, or absence of merchant hoist treatment. The matrix keeps the tier row pending/blocked. | **BLOCKED.** R-211 must deliver the compact production kit and then obtain matched gameplay-scale evidence for the craft-edge silhouette. |
| Plot dressing and threshold props | R-212 | The Lower Town source has no `plot_dressing`, `cellar_neck`, `wattle`, `privy`, `well_sweep`, `hoist_beam`, or `loading_hatch` authoring tokens. Two `firewood_stack` text occurrences do not constitute the requested dressing kit. `assets/props/architecture/houses/plot_dressing/` is absent. | `tools/generate_burgher_plot_dressing.py` and `tests/godot/test_burgher_plot_dressing.gd` are absent. No focused parser/prop-kind test or provenance row was found. | No gameplay-scale evidence identifies the required plot-dressing objects or proves merchant-only hoist/loading-frame restrictions. | **BLOCKED.** R-212 must author the bounded dressing kit, wire/parser-test it, add provenance, and obtain route-scale evidence; do not infer completion from existing firewood text or generic yard images. |

## Source and contract verification

The current source inspection found:

```text
source: content/maps/lower_town_slice.rrmap
tier_counts: merchant_stone=14, merchant_timber=14, craft_boda=23
plot_dressing token audit: plot_dressing=0, cellar_neck=0, wattle=0, privy=0,
  well_sweep=0, hoist_beam=0, loading_hatch=0
```

The focused tier contract was rerun with Godot 4.7.1 through the checked runner:

```text
--filter=test_burgher_house_tiers
1 file, 5 tests, 0 failures, 0 errors
```

The suite proves authored tier assignment, special-building exclusion, deterministic fallback/material precedence, surface texture variation, roof variation, and stable weathering variants. It does not prove production GLB delivery or visual acceptance.

The only tier-specific production-kit test present in the current checkout was also rerun:

```text
--filter=test_burgher_house_merchant_timber
1 file, 3 tests, 0 failures, 0 errors
```

The checked runner emitted only the known shutdown resource-leak diagnostics for the tier suite. These diagnostics do not change the test summary, but the working-tree bundle remains subject to the clean tracked-delivery caveat above.

## Provenance and lint boundary

The smallest applicable repository validators were run, but both report unrelated baseline drift:

- `python3 tools/validate_asset_sources.py`: **FAIL** on a large inventory of missing animal/bird/character texture paths outside this ledger's allowlist. This is not evidence that the existing `merchant_timber` row is invalid, and it cannot establish missing rows for the absent three kits.
- `python3 tools/verify_asset_lint.py`: **FAIL** on pre-existing portrait-dimension and character-GLB provenance errors outside this ledger's allowlist. No stone, craft-boda, or plot-dressing production artifact exists to lint.

These failures are recorded rather than repaired because R-590 is verification-only and explicitly forbids widening the change into unrelated provenance or asset work.

## Gameplay-scale evidence boundary

The current packet at `docs/reports/images/lower_town_p0_101/` contains ten PNGs in five matched day/night route pairs. The manifest records `lower_town_slice`, `gl_compatibility`, `1280x720`, five presets, and `10` plates; all checked PNGs decode at `1280x720` and have non-blank pixel payloads.

That packet is package/camera evidence, not ordinary-tier acceptance. Its manifest contains no `merchant_stone`, `merchant_timber`, or `craft_boda` stable-ID mapping. The matrix rows for the three tiers, material families, roof covers, localized wear/repair, and repeated frontage remain pending/blocked. The generated merchant-timber street/rear-yard images are reference studies, not gameplay-scale route captures. No source count or headless test is promoted to visual acceptance.

## Final decision and handoff

**R-590 result: BLOCKED, with deterministic structural evidence recorded.**

- `merchant_stone`: BLOCKED - R-209 production kit and focused evidence missing; gameplay proof missing.
- `merchant_timber`: BLOCKED - working-tree kit and focused contract pass, but clean tracked delivery and gameplay-scale tier evidence are not closed; R-487 review remains open.
- `craft_boda`: BLOCKED - R-211 production kit and focused evidence missing; gameplay proof missing.
- Plot dressing: BLOCKED - R-212 production kit, parser/test evidence, provenance, and gameplay proof missing.
- R-213 source wiring: PASS only at structural/contract level; not a production-art or visual-acceptance PASS.

The parent R-108/P0-101 must remain open. The next action is for the named owners to land the missing production kits and then supply stable-ID-linked matched day/night gameplay observations for R-487's ordinary-fabric review. No follow-up task is necessary because R-209, R-211, R-212, and R-487 already own the gaps.

## Sources

- [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap)
- [`tests/godot/test_burgher_house_tiers.gd`](../../tests/godot/test_burgher_house_tiers.gd)
- [`tests/godot/test_burgher_house_merchant_timber.gd`](../../tests/godot/test_burgher_house_merchant_timber.gd)
- [`assets/SOURCES.csv`](../../assets/SOURCES.csv)
- [`docs/reports/r532_lower_town_ordinary_fabric_verification.md`](r532_lower_town_ordinary_fabric_verification.md)
- [`docs/reports/lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md)
- [`docs/reports/images/lower_town_p0_101/capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json)
- [`docs/reports/burgher_house_art_signoff.md`](burgher_house_art_signoff.md)
- [`tools/validate_asset_sources.py`](../../tools/validate_asset_sources.py)
- [`tools/verify_asset_lint.py`](../../tools/verify_asset_lint.py)
