# P0-102 Ordinary and Exceptional Handoff Audit

**Task:** R-554 / P0-102 handoff audit
**Parent:** R-110 / P0-102
**Audit date:** 2026-08-17
**Live workspace HEAD:** `e9450c67a1f245d327a7de212eca55c587fb2bb7`
**Worktree:** shared worktree with unrelated staged, unstaged, and untracked WIP

## Decision

**BLOCKED / PARTIAL - do not accept or close the P0-102 handoff.**

The current source contains the intended R-003 ordinary tier assignments and R-213 wiring, and the renderer has a separate exceptional path. Those facts establish implementation boundaries only. They do not prove that the four upstream ordinary production handoffs, A-009 gameplay sign-off, or final exceptional landmark acceptance are complete.

The audit therefore records the following split decision:

- **Ordinary tier wiring:** implemented by R-213 and present in the current Lower Town source.
- **Ordinary production kits and plot dressing:** not supplied; R-209-R-212 remain open on the task board.
- **Exceptional ownership boundary:** structurally preserved; exceptional records are not accepted as ordinary-kit coverage.
- **Exceptional landmark acceptance:** still blocked by the independent fortification/review and gameplay-scale evidence gates.
- **Overall P0-102 handoff:** blocked; no ordinary or exceptional evidence is silently substituted for another owner.

## Reading rule and source state

This is a documentation-only reconciliation. It does not modify map source, runtime builders, assets, tests, or acceptance thresholds. The current source paths are inspected as implementation evidence, while acceptance claims are limited to the named task-board rows and reports.

The current implementation ledger is [`p0_102_scope_ledger.md`](p0_102_scope_ledger.md), task R-556. It is the current parent-level ledger and supersedes older downstream summaries where their source-state statements predate R-213. In particular, [`p0_102j_downstream_handoff.md`](p0_102j_downstream_handoff.md) is historical for this audit and is not used to claim the current tier assignment state.

## Ordinary handoff matrix

| Handoff | Board status | Current evidence | Audit result | Missing acceptance / owner |
|---|---|---|---|---|
| R-209 / P2-063 `merchant_stone` | `todo` | Current map has 14 authored `merchant_stone` IDs. Tier fallback selects the stone family in the shared house renderer. | **Wiring coverage only; production handoff missing.** | Deterministic generator, production GLB/PBR/LOD/collision output, focused asset test, lint/provenance record, and gameplay-scale silhouette evidence. R-209 owns these. |
| R-210 / P2-064 `merchant_timber` | `todo` | Current map has 14 authored `merchant_timber` IDs. Tier fallback selects timber/plastered-timber and shingle behavior. | **Wiring coverage only; production handoff missing.** | Deterministic generator, production GLB/PBR/LOD/collision output, focused asset test, lint/provenance record, and gameplay-scale silhouette evidence. R-210 owns these. |
| R-211 / P2-065 `craft_boda` | `todo` | Current map has 15 authored `craft_boda` IDs. Tier fallback selects the compact log/craft family. | **Wiring coverage only; production handoff missing.** | Deterministic generator, production GLB/PBR/LOD/collision output, focused asset test, lint/provenance record, and gameplay-scale silhouette evidence. R-211 owns these. |
| R-212 / P2-066 plot/threshold dressing | `todo` | No production plot-dressing generator, asset directory, or focused test was found in the scoped paths. | **Missing.** | Cellar-neck steps, fences/walls, yard gates, service structures, well/firewood details, and merchant-only hoist/loading props with tier restrictions. R-212 owns these. |
| R-213 / P2-067 Lower Town wiring | `done` | `lower_town_slice.rrmap` contains 43 tiered ordinary records: 14 stone, 14 timber, and 15 boda. `test_burgher_house_tiers.gd` covers the stable ID map, mixed-tier minimums, fallback/material precedence, texture/weathering variation, and untiered special IDs. | **Implemented, not a substitute for R-209-R-212.** | The R-213 task also names a gameplay capture and parity verification. Existing contract tests and source counts do not satisfy the missing gameplay-scale visual packet. R-213 owns wiring; P0-101/R-108 owns downstream visual acceptance. |
| R-6 / A-009 art sign-off | `in_review` | [`burgher_house_art_signoff.md`](burgher_house_art_signoff.md) grants a conditional art-direction pass for six A-008 reference plates. It explicitly records production GLBs and `signoff_*.png` gameplay captures as missing. | **Final gameplay sign-off blocked.** | Production kits, matched day/night captures for all three tiers, a shared route comparison, and annotations against the ten R-003 decisions. A-009 remains conditional until those inputs exist. |

### Ordinary source result

The current authored source has the following tiered ordinary coverage:

```text
merchant_stone=14
merchant_timber=14
craft_boda=15
ordinary tiered total=43
```

This is sufficient to prove that the three R-003 tokens coexist in the authored source and that R-213 did not leave the map untiered. It is not sufficient to prove production asset delivery, authored plot dressing, collision/LOD output, provenance, or gameplay-camera readability. The current repository also lacks the scoped upstream paths named by R-209-R-212:

- `tools/generate_burgher_house_merchant_stone.py`
- `tools/generate_burgher_house_merchant_timber.py`
- `tools/generate_burgher_house_craft_boda.py`
- `tools/generate_burgher_plot_dressing.py`
- `assets/props/architecture/houses/{merchant_stone,merchant_timber,craft_boda,plot_dressing}/`
- `tests/godot/test_burgher_house_{merchant_stone,merchant_timber,craft_boda}.gd`
- `tests/godot/test_burgher_plot_dressing.gd`

The existence of shared procedural fallback code in [`map_view_mesh_builder_house_styles.gd`](../../scripts/map/view3d/map_view_mesh_builder_house_styles.gd) is implementation coverage, not evidence that those upstream production kits were delivered.

## Exceptional handoff matrix

| Surface | Current ownership/boundary | Audit result | Acceptance limitation |
|---|---|---|---|
| Churches, civic buildings, guild halls, institutions | Registry-positive house records route through `build_exceptional_building()` and receive `renderer_boundary=exceptional` plus an exceptional category. | **Boundary preserved.** | Structural routing does not approve historical silhouette quality or gameplay-scale art. P0-101/R-108 and the relevant landmark owners retain final acceptance. |
| `st_catherines_church` | Stable `house` record ID is explicitly registered as `church`; the dedicated church builder emits exceptional metadata and church-specific forms. | **Not ordinary coverage.** | It must not be sent through the ordinary house kit. Current visual/review evidence remains blocked in the P0-101 and landmark reports. |
| Viru Gate towers | `viru_gate_north_tower` and `viru_gate_south_tower` are authored as `kind=wall`. The registry rejects non-house records, preserving the fortification renderer. | **Boundary preserved.** | Tower/wall acceptance remains subject to the clean fortification baseline and landmark review; it cannot be satisfied by ordinary-house tests. |
| `viru_gate_arch` and `viru_foregate_arch` | Separate `gate_arch` view landmarks with inner ironbound/portcullis and outer oak variants. | **View-only separation preserved.** | They are not collision-bearing ordinary buildings and still require route-scale approach/opening evidence. |
| Other registered exceptional IDs/styles/primitives | `town_hall_mass`, church, hospital, guild, gatehouse, and civic/exceptional primitive categories remain in the registry. | **Ownership remains exceptional.** | No ordinary tier assignment may be counted as their art or historical sign-off. |

The relevant registry guard is explicit: `exceptional_category()` returns an exceptional category only for `kind=house`, so a wall record with a historical landmark-like ID remains on the fortification path. The ordinary builder sets `renderer_boundary=ordinary`; the exceptional builder and St. Catherine's church builder set `renderer_boundary=exceptional`.

## Boundary verification

The current focused tier contract contains the required negative checks:

- known exceptional/special Lower Town IDs remain without `house_tier`;
- an exceptional registry ID remains exceptional even when a `house_tier` leaks into a fixture;
- a wall record with the same ID remains non-exceptional to the house registry and therefore remains on the wall renderer;
- an ordinary house with a known R-003 tier remains on the ordinary path.

These checks prove that no exceptional landmark is being counted as ordinary-kit coverage and that ordinary tier metadata cannot override the exceptional boundary. They do not make the exceptional path green for final art acceptance.

## Gameplay-scale evidence gate

The required matched day/night evidence remains unavailable:

- `docs/reports/images/lower_town_p0_101/` is absent;
- `docs/reports/images/burgher_houses/signoff_*.png` is absent;
- the existing whole-map `view3d` and ADR-0018 calibration PNGs are supplementary and do not carry the required route/approach camera matrix, stable pose, map revision, and landmark/tier annotations;
- [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md) keeps the ordinary tiers, landmark surfaces, and route-scale proof rows pending/blocked;
- [`lower_town_p0_101_acceptance.md`](lower_town_p0_101_acceptance.md) keeps the final P0-101 gate blocked and explicitly distinguishes source counts from visual evidence.

Therefore, no report or image packet is promoted here to prove that all three ordinary tiers are readable together in gameplay scale, and no ordinary packet is promoted to prove exceptional landmark quality.

## Current blockers and owners

1. **R-209 / R-210 / R-211:** deliver the three authored ordinary exterior kits and their focused verification/provenance evidence.
2. **R-212:** deliver plot/threshold dressing and enforce merchant-only hoist/loading ownership.
3. **R-213:** wiring is complete, but its gameplay capture/parity claims remain downstream evidence and must not be inferred from source counts or procedural fallback output.
4. **R-6 / A-009:** replace the conditional art-direction pass with final gameplay-scale day/night sign-off after the production kits land.
5. **R-397 / exceptional boundary recheck:** the recorded clean fortification recheck remains blocked by the exceptional `GateDoor0` contract and the separate `MAP_ID_DUPLICATE` baseline finding. These are not reasons to route landmarks through ordinary houses.
6. **R-108 / P0-101:** close the combined ordinary-fabric, exceptional-landmark, route, day/night, and human canon/art acceptance only after the named inputs are complete.

No new follow-up task is created by this audit. Existing board rows already own every blocker, and creating duplicates would blur the ordinary/exceptional handoff.

## Reproduction and verification commands

Run from the repository root. Because the live worktree is dirty, these commands are scoped evidence checks and are not a clean-parent acceptance run:

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot

tools/run_godot_checked.sh --require-test-summary r554-lower-map -- \
  "$GODOT_BIN" --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_lower_town_slice_map

tools/run_godot_checked.sh --require-test-summary r554-house-tiers -- \
  "$GODOT_BIN" --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_burgher_house_tiers
```

The named current acceptance report records these focused contracts as green in the dirty worktree: `test_lower_town_slice_map` 19/19 and `test_burgher_house_tiers` 5/5. The clean P0-102 baseline remains blocked earlier by the RRMap `elevation_area` / `elevation_ramp` parser path; that parent-level blocker is not repaired or waived by this audit.

For source-level rechecks:

```bash
python3 - <<'PY'
from collections import Counter
from pathlib import Path

counts = Counter()
for line in Path("content/maps/lower_town_slice.rrmap").read_text().splitlines():
    if line.startswith("building ") and "house_tier=" in line:
        counts[line.split("house_tier=", 1)[1].split()[0]] += 1
print(dict(counts), "total=", sum(counts.values()))
PY

rg -n 'st_catherines_church|viru_gate_(north|south)_tower|viru_gate_arch|viru_foregate_arch|house_tier=' \
  content/maps/lower_town_slice.rrmap
```

## Final audit conclusion

**R-554 is complete as a blocked handoff audit.** R-213 supplies the intended Lower Town tier wiring, and the code/test boundary prevents exceptional churches, civic/guild/institutional buildings, Viru Gate wall towers, and view-only gate arches from being accepted as ordinary houses. However, R-209-R-212 have not supplied the ordinary production kits and plot dressing, A-009 has only a conditional reference-art pass, gameplay-scale day/night evidence is missing, and exceptional acceptance remains separately blocked. Keep R-110/P0-102 open.

## Sources

- [`p0_102_scope_ledger.md`](p0_102_scope_ledger.md) - current R-556 implementation/ownership ledger.
- [`burgher_house_art_signoff.md`](burgher_house_art_signoff.md) - current A-009 conditional art-direction review.
- [`lower_town_p0_101_acceptance.md`](lower_town_p0_101_acceptance.md) - current downstream acceptance gate and board-state reconciliation.
- [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md) - required gameplay-scale day/night capture contract.
- [`p0_102_exceptional_boundary_reconciliation.md`](p0_102_exceptional_boundary_reconciliation.md) - exceptional routing and Viru Gate boundary reconciliation.
- [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap) - authored stable IDs and current `house_tier` assignments.
- [`scripts/map/view3d/map_view_mesh_builder_building_registry.gd`](../../scripts/map/view3d/map_view_mesh_builder_building_registry.gd) - exceptional registry and `kind=house` boundary guard.
- [`scripts/map/view3d/map_view_mesh_builder_buildings.gd`](../../scripts/map/view3d/map_view_mesh_builder_buildings.gd) - ordinary/exceptional builder routing and boundary metadata.
- [`scripts/map/view3d/map_view_mesh_builder_churches.gd`](../../scripts/map/view3d/map_view_mesh_builder_churches.gd) - dedicated St. Catherine's exceptional builder.
- [`tests/godot/test_burgher_house_tiers.gd`](../../tests/godot/test_burgher_house_tiers.gd) - tier assignment and exceptional exclusion checks.

---

## Current handoff recheck (2026-08-29)

**Recheck scope:** refresh the R-554 ordinary-versus-exceptional handoff against the current task board and checkout. This addendum is documentation-only. It does not change map geometry, runtime builders, assets, tests, thresholds, or visual acceptance decisions.

**Current decision:** **SOURCE/PRODUCTION CONTRACTS PASS; GAMEPLAY-SCALE ACCEPTANCE BLOCKED.** The earlier sections retain historical snapshots. This section is the current board and artifact state and must be used for handoff decisions.

### Current board state

| Handoff | Current status | Interpretation |
|---|---|---|
| R-209 / P2-063 `merchant_stone` | `in_progress` | Production kit is present and its focused contract passes, but the owning task is not closed. |
| R-210 / P2-064 `merchant_timber` | `done` | Production kit, runtime style, and imported-model contract are available. |
| R-211 / P2-065 `craft_boda` | `in_progress` | Production kit is present and its focused contract passes, but the owning task is not closed. |
| R-212 / P2-066 plot dressing | `in_progress` | Plot-dressing kit and parser/model contracts are present, but the owning task is not closed. |
| R-213 / P2-067 tier wiring | `done` | Lower Town tier assignments and renderer selection are present; this does not constitute visual sign-off. |
| R-353 / P0-102e exceptional boundary | `done` | Exceptional routing implementation is complete; final landmark quality and review remain separate gates. |
| R-487 / P0-101b ordinary frontage and wear | `in_progress` | Ordinary route-scale variation and wear acceptance remain open. |
| R-488 / P0-101c exceptional landmarks | `in_progress` | Exceptional landmark handoff remains open. |
| R-489 / P0-101d route integration | `in_progress` | Independent route/art handoff remains open. |
| R-492 / P0-101g silhouette review | `in_review` | No final named historical/art approval has been recorded for the required gameplay-scale silhouettes. |
| R-6 / A-009 | `in_review` | Conditional reference-art pass, not final gameplay-scale sign-off. |
| R-108 / P0-101 | `in_progress` | Parent acceptance remains open. |
| R-110 / P0-102 | `in_progress` | Parent environment handoff remains open. |

### Current ordinary-kit evidence

The authored `lower_town_slice` source currently contains **51** tiered ordinary records:

```text
merchant_stone=14
merchant_timber=14
craft_boda=23
tiered ordinary total=51
```

The additional craft-boda records include the eight current rear-workshop IDs covered by `test_lower_town_current_tier_inventory_includes_rear_workrooms`. The source count is not treated as a visual observation.

All four production handoff paths named by R-209-R-212 are present in the current checkout:

- `assets/props/architecture/houses/merchant_stone/merchant_stone.glb`
- `assets/props/architecture/houses/merchant_timber/merchant_timber.glb`
- `assets/props/architecture/houses/craft_boda/craft_boda.glb`
- `assets/props/architecture/houses/plot_dressing/plot_dressing.glb`

The corresponding focused Godot contracts verify imported production models, profile/budget evidence, tier-specific runtime style, and plot-dressing components/prop restrictions. These artifacts establish production-contract coverage, but do not replace R-487/R-489 route-scale review or R-6/R-492 visual sign-off.

### Current exceptional boundary

The boundary remains explicit in the current source and renderer:

- `MapViewMeshBuilderBuildings.build_building()` dispatches registry-positive house records to `build_exceptional_building()` before the ordinary path.
- Ordinary roots carry `renderer_boundary=ordinary`; exceptional roots carry `renderer_boundary=exceptional` and an `exceptional_category`.
- `MapViewMeshBuilderBuildingRegistry.exceptional_category()` only classifies house records. Wall records with landmark-like IDs retain the fortification path.
- `st_catherines_church` remains an exceptional church record without an ordinary `house_tier`.
- `viru_gate_north_tower` and `viru_gate_south_tower` remain wall/round-tower records, while `viru_gate_arch` and `viru_foregate_arch` remain separate view-only gate landmarks.

The focused tier contract also covers the negative boundary: a known exceptional house stays exceptional even if a tier leaks into a fixture, an ordinary house stays ordinary, and a wall record is not promoted into the exceptional-house path. No exceptional landmark is counted as ordinary-kit coverage in this recheck.

### Focused verification record

The current Godot 4.7.1 checked runs were:

```text
--filter=test_burgher_house_merchant_stone   1 file, 3 tests, 0 failures, 0 errors
--filter=test_burgher_house_merchant_timber  1 file, 3 tests, 0 failures, 0 errors
--filter=test_burgher_house_craft_boda       1 file, 3 tests, 0 failures, 0 errors
--filter=test_burgher_plot_dressing          1 file, 4 tests, 0 failures, 0 errors
--filter=test_burgher_house_tiers            1 file, 6 tests, 0 failures, 0 errors
```

The runs were executed through `tools/run_godot_checked.sh --require-test-summary` with `GODOT_LOG_DIR=/tmp/r554-current`. The plot-dressing and tier runs emitted the known Godot shutdown ObjectDB/resource cleanup diagnostics after green summaries; no assertion or parser error occurred. The combined focused result is **19/19 tests green**.

### Remaining acceptance blockers

The handoff is not promoted to PASS because the required visual and owner gates remain open:

1. R-209, R-211, and R-212 are still `in_progress`, so their board-level production handoffs are not closed even though the current artifacts and focused contracts exist.
2. `docs/reports/images/burgher_houses/signoff_*.png` is absent. The six A-008 reference plates are documentation-only and cannot substitute for matched gameplay-scale day/night evidence.
3. The current P0-101 packet contains ten route plates, but its matrix still marks tier-specific stable-ID observations, repeated-frontage review, material/roof readability, localized wear, and special/landmark observations as pending or blocked.
4. R-6/A-009 remains a conditional art-direction pass, and R-492 has not recorded final named canon/art approval.
5. R-108/R-110 and the active R-487-R-489 handoffs remain open. No source count, imported GLB contract, or renderer-boundary test is promoted as a substitute for the gameplay-scale visual gate.

**Current closeout:** R-554 is complete as a current blocked handoff audit. Existing board rows already own the production, route, exceptional, and visual blockers; no duplicate follow-up task is created. Keep R-108 and R-110 open, and do not count exceptional buildings as ordinary-house coverage.

### Recheck sources

- [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap) - current authored tier and exceptional records.
- [`tests/godot/test_burgher_house_tiers.gd`](../../tests/godot/test_burgher_house_tiers.gd) - current 51-record tier inventory and negative boundary checks.
- [`tests/godot/test_burgher_house_merchant_stone.gd`](../../tests/godot/test_burgher_house_merchant_stone.gd) - stone production contract.
- [`tests/godot/test_burgher_house_merchant_timber.gd`](../../tests/godot/test_burgher_house_merchant_timber.gd) - timber production contract.
- [`tests/godot/test_burgher_house_craft_boda.gd`](../../tests/godot/test_burgher_house_craft_boda.gd) - boda production contract.
- [`tests/godot/test_burgher_plot_dressing.gd`](../../tests/godot/test_burgher_plot_dressing.gd) - plot-dressing contract.
- [`scripts/map/view3d/map_view_mesh_builder_building_registry.gd`](../../scripts/map/view3d/map_view_mesh_builder_building_registry.gd) - exceptional registry boundary.
- [`scripts/map/view3d/map_view_mesh_builder_buildings.gd`](../../scripts/map/view3d/map_view_mesh_builder_buildings.gd) - ordinary/exceptional dispatch.
- [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md) - current gameplay-scale evidence matrix.
- [`burgher_house_art_signoff.md`](burgher_house_art_signoff.md) - current conditional A-009 review.
