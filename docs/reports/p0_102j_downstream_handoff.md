# P0-102j downstream handoff evidence

**Task:** R-362 / P0-102j
**Parent:** R-110 / P0-102
**Snapshot:** `0e020a30ebb518240d04bb48bd66630c4c915e78` (`main`)
**Date:** 2026-08-01
**Status:** **BLOCKED - required downstream handoffs are not production-complete**

## Scope and method

This is an evidence-only handoff check. It does not author house-tier assets, landmark art, map density, runtime behavior, or acceptance captures. The check compares the P0-102 ownership contract with the live task-board status and the repository paths named by the downstream deliverables.

The P0-102 contract explicitly keeps these responsibilities separate:

- **P0-101 / R-108:** final ordinary-fabric and exceptional-landmark art pass, including gameplay-scale day/night sign-off.
- **P2-063 / R-209:** `merchant_stone` authored exterior kit.
- **P2-064 / R-210:** `merchant_timber` authored exterior kit.
- **P2-065 / R-211:** `craft_boda` authored exterior kit.
- **P2-066 / R-212:** rear-plot and street-threshold dressing kit.
- **P2-067 / R-213:** Lower Town tier wiring and parity/integration evidence.

The existing `docs/reports/burgher_house_typology_contract.md` and `tests/godot/test_burgher_house_typology_contract.gd` prove the closed typology contract and parser round-trip only. They are not production handoff evidence for any of the six downstream rows.

## Handoff matrix

| Handoff | Board status | Required evidence | Result | Owner / next action |
|---|---|---|---|---|
| **P0-101 / R-108** | `todo` | Ordinary-fabric and landmark acceptance; all three house tiers on playable route; required exceptional landmarks; signed gameplay-scale day/night captures; route/collision/occlusion/performance checks | **BLOCKED** | P0-101 must produce the final art/landmark acceptance and captures after its dependencies, including P2-067 and A-009, are complete |
| **P2-063 / R-209** | `todo` | `merchant_stone` generator, GLB/PBR/LOD/collision assets, mesh-builder selection, `test_burgher_house_merchant_stone.gd`, provenance/lint results, gameplay-scale silhouette evidence | **MISSING** | P2-063 must author and verify the merchant-stone kit |
| **P2-064 / R-210** | `todo` | `merchant_timber` generator, GLB/PBR/LOD/collision assets, mesh-builder selection, `test_burgher_house_merchant_timber.gd`, provenance/lint results, gameplay-scale silhouette evidence | **MISSING** | P2-064 must author and verify the merchant-timber kit |
| **P2-065 / R-211** | `todo` | `craft_boda` generator, GLB/PBR/LOD/collision assets, mesh-builder selection, `test_burgher_house_craft_boda.gd`, provenance/lint results, gameplay-scale silhouette evidence | **MISSING** | P2-065 must author and verify the craft-boda kit |
| **P2-066 / R-212** | `todo` | Plot-dressing generator/assets for cellar neck, fence, gate, privy, well sweep, lean-to, firewood, and merchant-only hoist/loading hatch; `test_burgher_plot_dressing.gd`; parser and provenance evidence | **MISSING** | P2-066 must author and verify the plot-dressing kit |
| **P2-067 / R-213** | `todo` | Lower Town map tier assignments, mesh-builder selection, all three tiers on the playable route, parity fixture, `test_burgher_house_tiers.gd`, map regression, gameplay capture | **MISSING** | P2-067 must wire approved P2-063..066 outputs into the slice and record parity evidence |

## Repository evidence

The following required handoff paths are absent at the checked snapshot:

- `docs/reports/p0_101*`
- `docs/reports/images/burgher_houses/`
- `docs/reports/burgher_house_art_signoff.md`
- `assets/props/architecture/houses/merchant_stone/`
- `assets/props/architecture/houses/merchant_timber/`
- `assets/props/architecture/houses/craft_boda/`
- `assets/props/architecture/houses/plot_dressing/`
- `tests/godot/test_burgher_house_merchant_stone.gd`
- `tests/godot/test_burgher_house_merchant_timber.gd`
- `tests/godot/test_burgher_house_craft_boda.gd`
- `tests/godot/test_burgher_plot_dressing.gd`
- `tests/godot/test_burgher_house_tiers.gd`

The Lower Town source also has no `house_tier=` assignments and no `merchant_stone`, `merchant_timber`, or `craft_boda` tokens. This is consistent with the contract's statement that tier assignment remains owned by P2-067 and is not evidence of a completed handoff.

Present but insufficient evidence:

- `docs/reports/burgher_house_typology_contract.md`: closed allowlist, historical rules, and compiler contract.
- `tests/godot/test_burgher_house_typology_contract.gd`: allowlist, round-trip, rejection, and documentation assertions.
- `docs/reports/p0_102_environment_kit_contract.md`: ownership boundary and handoff checklist.
- `docs/reports/p0_102_environment_kit_acceptance.md`: explicitly records P0-101 and P2-063-P2-067 as separate, unclaimed work and says matched house/landmark evidence is missing.

## Decision

No P0-101 or P2-063-P2-067 handoff can be marked accepted from the current repository state. P0-102 must not claim the ordinary house tiers, plot dressing, tier wiring, or final landmark/day-night sign-off. Existing typology documentation can be consumed as an authoring prerequisite, but it cannot substitute for the missing production assets, tests, provenance, parity, and visual acceptance artifacts.

No new follow-up task is created here because the owning rows P0-101 and P2-063 through P2-067 already exist on the board with the required scopes and dependencies.

## Verification commands

```sh
# Board status was checked through the tasks tool for P0-101 and P2-063..P2-067.
git rev-parse HEAD
for p in \
  docs/reports/p0_101* \
  docs/reports/images/burgher_houses \
  docs/reports/burgher_house_art_signoff.md \
  assets/props/architecture/houses/merchant_stone \
  assets/props/architecture/houses/merchant_timber \
  assets/props/architecture/houses/craft_boda \
  assets/props/architecture/houses/plot_dressing \
  tests/godot/test_burgher_house_merchant_stone.gd \
  tests/godot/test_burgher_house_merchant_timber.gd \
  tests/godot/test_burgher_house_craft_boda.gd \
  tests/godot/test_burgher_plot_dressing.gd \
  tests/godot/test_burgher_house_tiers.gd; do
  test -e "$p" && echo "PRESENT $p" || echo "MISSING $p"
done
rg -n 'house_tier=|merchant_stone|merchant_timber|craft_boda' content/maps/lower_town_slice.rrmap
```

The final `rg` command returns no matches at this snapshot, confirming that P2-067 has not yet wired the three tiers into `lower_town_slice`.
