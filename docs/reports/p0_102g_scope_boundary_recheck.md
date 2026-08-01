# P0-102g Scope-Boundary Recheck

**Task:** R-368 / P0-102g recheck downstream scope boundaries
**Parent:** R-110 / P0-102
**Date:** 2026-08-02
**Snapshot:** `f9e79493567e4e561757753f5f7cf4e7bac2d3b9` (`main`, working tree ahead of `origin/main`)
**Status:** **BLOCKED - all required downstream production handoffs remain external and incomplete**

## Scope and method

This is a final ownership-boundary and handoff recheck for the shared P0-102 environment-kit closeout. It is evidence-only. It does not author house-tier assets, plot dressing, Lower Town tier assignments, landmark art, map density, runtime behavior, or gameplay-scale acceptance captures.

The audit used:

1. Current task-board status for P0-101 / R-108 and P2-063 through P2-067 / R-209 through R-213.
2. The P0-102 ownership contract in `docs/reports/p0_102_environment_kit_contract.md`.
3. Existing acceptance and handoff evidence in `docs/reports/p0_102_environment_kit_acceptance.md`, `docs/reports/p0_102j_downstream_handoff.md`, and `docs/reports/p0_102l_environment_kit_closeout.md`.
4. Repository existence checks for the required production assets, tests, reports, and Lower Town tier assignments.

The live worktree contains unrelated modified and untracked files. Those changes were not treated as evidence and are not included in this report.

## Ownership boundary

P0-102 may claim only the shared, view-only environment layer for the forge, street/well, brewery, and checkpoint: reusable building/roof/material helpers, deterministic wear and decals, shared prop composition, route/anchor safety, and preservation of the ordinary-versus-exceptional renderer boundary. It may consume approved downstream outputs later.

P0-102 must not claim:

- authored `merchant_stone`, `merchant_timber`, or `craft_boda` house GLBs or generators;
- plot and street-threshold dressing such as cellar necks, yard gates, privies, lean-tos, firewood, or merchant-only hoist/loading-hatch frames;
- opportunistic `house_tier` assignment or Lower Town tier wiring;
- exceptional landmark art quality or replacement church/gate/civic silhouettes;
- final ordinary-fabric review, repeated-facade review, or gameplay-scale day/night sign-off.

The contract is explicit on these boundaries: house tier assignment remains P2-067, tier-specific kits remain P2-063-P2-065, plot dressing remains P2-066, and final ordinary/landmark visual acceptance remains P0-101.

## Downstream handoff matrix

| Handoff | Current board status | Required completion evidence | Repository evidence at snapshot | Decision / external owner |
|---|---|---|---|---|
| **P0-101 / R-108** | `todo` | All three house tiers on the playable route; required exceptional landmarks; repeated-facade and material/wear audit; signed gameplay-scale day/night captures; route, collision, occlusion, and performance checks | No `docs/reports/p0_101*`, `docs/reports/burgher_house_art_signoff.md`, or `docs/reports/images/burgher_houses/` exists. Lower Town has no tier tokens. | **BLOCKED.** P0-101 remains the final art and visual acceptance owner after its dependencies land. P0-102 must not claim this sign-off. |
| **P2-063 / R-209** | `todo` | Deterministic `merchant_stone` generator, GLB/PBR/LOD/collision output, mesh-builder selection, focused test, provenance/lint evidence, and gameplay-scale silhouette evidence | `assets/props/architecture/houses/merchant_stone/` and `tests/godot/test_burgher_house_merchant_stone.gd` are absent. No production handoff report was found. | **MISSING.** P2-063 owns the merchant-stone kit and its verification. |
| **P2-064 / R-210** | `todo` | Deterministic `merchant_timber` generator, GLB/PBR/LOD/collision output, mesh-builder selection, focused test, provenance/lint evidence, and gameplay-scale silhouette evidence | `assets/props/architecture/houses/merchant_timber/` and `tests/godot/test_burgher_house_merchant_timber.gd` are absent. No production handoff report was found. | **MISSING.** P2-064 owns the merchant-timber kit and its verification. |
| **P2-065 / R-211** | `todo` | Deterministic `craft_boda` generator, GLB/PBR/LOD/collision output, mesh-builder selection, focused test, provenance/lint evidence, and gameplay-scale silhouette evidence | `assets/props/architecture/houses/craft_boda/` and `tests/godot/test_burgher_house_craft_boda.gd` are absent. No production handoff report was found. | **MISSING.** P2-065 owns the craft-boda kit and its verification. |
| **P2-066 / R-212** | `todo` | Plot-dressing generator/assets for cellar neck, fence, gate, privy, well sweep, lean-to/Hinterhaus, firewood, and merchant-only hoist/loading hatch; parser, focused test, provenance, and lint evidence | `assets/props/architecture/houses/plot_dressing/` and `tests/godot/test_burgher_plot_dressing.gd` are absent. No production handoff report was found. | **MISSING.** P2-066 owns plot and threshold dressing. |
| **P2-067 / R-213** | `todo` | Lower Town `house_tier` assignments, tier-aware mesh-builder wiring, mixed playable-route coverage, stable IDs, parity fixture, focused tier test, map regression, and gameplay capture | `content/maps/lower_town_slice.rrmap` contains no `house_tier=`, `merchant_stone`, `merchant_timber`, or `craft_boda` assignment. `tests/godot/test_burgher_house_tiers.gd` is absent. | **MISSING.** P2-067 owns integration and parity after P2-063-P2-066. |

## Positive evidence and non-evidence

The repository does contain `docs/reports/burgher_house_typology_contract.md` and `tests/godot/test_burgher_house_typology_contract.gd`. They prove that the closed `house_tier` allowlist, parser/compiler round-trip, rejection rule, and documentation contract exist. They do **not** prove authored house assets, plot dressing, tier wiring, parity, provenance, or gameplay acceptance.

The P0-102 reports also consistently preserve the boundary:

- `p0_102_environment_kit_contract.md` assigns the six downstream responsibilities to separate owners.
- `p0_102_environment_kit_acceptance.md` records that P0-102 does not author house tiers or landmark art and does not claim final day/night sign-off.
- `p0_102j_downstream_handoff.md` records the same six handoffs as `todo`/missing.
- `p0_102l_environment_kit_closeout.md` keeps the parent gate blocked by separate downstream owners, in addition to unrelated external baseline findings.

Therefore, the existence of the typology contract and shared environment-kit implementation is not sufficient to promote any downstream row or to broaden P0-102's deliverable.

## Verification commands

Run from the repository root:

```sh
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

rg -n 'house_tier=|merchant_stone|merchant_timber|craft_boda' \
  content/maps/lower_town_slice.rrmap
```

At this snapshot the artifact checks report all listed production paths as missing, and the final `rg` command reports no Lower Town tier assignments. Board status was checked through the tasks tool for R-108 and R-209 through R-213; every row is `todo`.

## Final handoff decision

**Do not accept or close the downstream handoffs. Do not widen P0-102.**

P0-102's final gate may proceed only as a shared environment-kit gate, with its own scoped integration and renderer-boundary findings handled by their owners. The ordinary-house production kits, plot dressing, Lower Town tier wiring/parity, and final landmark/day/night sign-off remain external dependencies owned by R-108 and R-209 through R-213. No new follow-up task is required because each missing handoff already has an owning board row.

The correct current state is:

- P0-102 scope boundary: **PASS**, no ownership leakage found in the reviewed reports or repository state.
- Downstream production handoffs: **BLOCKED / incomplete**, all six rows remain external.
- Final P0-102 gate: **NOT READY for full closeout** until the separate dependencies are completed or explicitly accepted by their owners.
