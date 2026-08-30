# R-612 Lower Town ordinary-fabric acceptance

**Task:** R-612 / P0-101 ordinary-fabric acceptance
**Parent:** R-108 / P0-101
**Map:** `lower_town_slice` / Workers' District
**Verification date:** 2026-08-30
**Scope:** verification-only; no runtime, asset, map, threshold, parity-fixture, capture, or human-review decision was changed
**Decision:** **SOURCE/CONTRACT PASS; GAMEPLAY-SCALE ORDINARY-FABRIC ACCEPTANCE BLOCKED.**

## Decision boundary

This audit consumes the current R-532 ordinary-fabric handoff, the R-487 implementation boundary, the R-213 tier-wiring result, the R-616 capture audit, the current inventory, and the R-003 typology contract.

The current authored source and focused contracts prove that all three closed `house_tier` values are present, that the required material and roof families are represented in authored style data, that stable weathering hooks exist, and that the map and tier contracts pass in the current checkout. They do not prove that those surfaces read at gameplay scale, that repeated frontage is acceptable, or that repairs are visually legible. Those acceptance rows remain blocked rather than being inferred from source records or non-blank PNGs.

## Current source reconciliation

A fresh source audit of [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap) found:

| Source result | Observed value | Classification |
|---|---:|---|
| Authored `building`/`landmark` records | 99 | PASS as source inventory |
| Unique stable IDs | 99 | PASS as source inventory |
| House records | 61 | PASS as source inventory |
| Wall records | 36 | Kept outside ordinary-house acceptance |
| View-only `gate_arch` landmarks | 2 | Kept outside ordinary-house acceptance |
| Tiered ordinary houses | 51 | PASS as source inventory |
| `merchant_stone` | 14 | PASS as authored tier coverage |
| `merchant_timber` | 14 | PASS as authored tier coverage |
| `craft_boda` | 23 | PASS as authored tier coverage |
| R-547 rear-workshop IDs | 8/8 present as `craft_boda` | PASS as source coverage; visual review blocked |

The ten untiered house records remain special or use-site records. They are not counted as missing ordinary tiers. The eight rear-workshop IDs are part of the current `craft_boda` count, but the existing packet does not provide accepted stable-ID observations for them.

## R-003 material and roof audit

The audit resolved each tiered building's `style=` token against the style definitions in the same RRMap. This avoids treating a broad style-table inventory as if it were an observation of a gameplay frame.

| Tier | Count | Wall materials in authored styles | Roof materials in authored styles | Structural result |
|---|---:|---|---|---|
| `merchant_stone` | 14 | plaster 5, plank 5, limestone 4 | shingle 10, tile 4 | PASS as source/contract evidence; visual readability blocked |
| `merchant_timber` | 14 | plaster 6, log 4, plank 2, limestone 1, brick 1 rare accent | shingle 11, tile 2, thatch 1 | PASS as source/contract evidence; visual readability blocked |
| `craft_boda` | 23 | log 21, plaster 2 | shingle 16, thatch 7 | PASS as source/contract evidence; compact silhouette and no-hoist visual review blocked |

Across the 51 tiered records, the required wall families `log`, `plank`, `plaster`, and `limestone` are represented. The single `brick` style is retained as a rare accent and is not promoted to a required family. The required roof families `tile`, `shingle`, and `thatch` are all represented.

The authoring contract remains the review authority for the R-003 rules: gable-to-street massing, merchant 2-3 storeys versus *boda* 1-2 storeys, selective tile, ordinary shingle/thatch, and no merchant hoist or granary treatment on `craft_boda`. See [`burgher_house_typology_contract.md`](burgher_house_typology_contract.md) and [`burgher_house_art_signoff.md`](burgher_house_art_signoff.md).

## Wear, repair, and repetition audit

| Acceptance surface | Current evidence | Result | Exact limitation / owner |
|---|---|---|---|
| Surface texture variation | `test_burgher_house_tiers` requires at least three wall textures and three roof textures; current run passes | PASS at contract level | Does not establish visual legibility in a gameplay frame |
| Stable weathering variation | The tier test requires at least two deterministic weathering variants; current run passes | PASS at contract level | Does not prove that wear reads at route distance |
| Localized authored wear hooks | Current RRMap has 14 decals: mud 6, grime 4, wet-threshold 3, soot 1 | PASS at source level | Decals are view-only authored hooks, not visual acceptance evidence |
| Explicit repair hook | `consequence_wall_repair cooper_staves` is present | PASS at source level | A source token does not prove that a repaired state is visible or readable |
| Repeated frontage/material run | Exact style reuse is present, with the most reused style `house.north.h96.44` used by 9 `craft_boda` records; the contract provides frontage-width ranges but no numeric facade-repetition threshold | BLOCKED | No matched gameplay-scale route review exists to classify the repeated run. R-487/R-532 must review it without inventing or waiving a threshold |
| Repaired-state readability | No stable-ID-linked day/night observation or human annotation identifies wear or repair in-frame | BLOCKED | R-487/R-532 with R-616 capture support |

The exact style reuse diagnostic is not itself a visual failure: style tokens can share a deterministic base while material and weathering selection remain separate. It is recorded so the owner can inspect the run in gameplay captures rather than silently treating source variation as acceptance.

## Focused verification

The following commands were run from the project root against the current shared checkout with Godot 4.7.1. The test filter is passed after the standalone `--` so the repository harness receives it.

```bash
export GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
export GODOT_LOG_DIR=/tmp/r612_lower_town

bash tools/run_godot_checked.sh --require-test-summary r612-burgher-house-tiers -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_burgher_house_tiers

bash tools/run_godot_checked.sh --require-test-summary r612-lower-town-map -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_lower_town_slice_map
```

Observed results:

```text
test_burgher_house_tiers: 1 file, 6 tests, 0 failures, 0 errors
test_lower_town_slice_map: 1 file, 19 tests, 0 failures, 0 errors
```

Both runs emitted only the known shutdown-time ObjectDB/resource cleanup diagnostics after their clean summaries. No parser, assertion, route, parity, navigation, or resource-load failure was observed in these focused runs.

The tier suite proves current tier inventory including the eight rear-workshop records, mixed R-003 tier assignment, untiered special-building boundaries, deterministic fallback/material precedence, textured wall/roof output, and stable weathering variation. The map suite proves the current map validation and parity contract, required route endpoints, wall and Viru Gate opening rules, navigation construction, water exclusion, service-yard coverage, and view-only decal fingerprint isolation. Neither suite performs a gameplay-scale visual review.

## Gameplay-scale evidence boundary

The current packet at [`images/lower_town_p0_101/capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json) contains 10 valid `1280x720` PNGs across five matched day/night route pairs. The manifest has route anchors and `stable_id_candidates`, but no accepted `stable_ids` observations or reviewer annotations. Its map fingerprint is `13525325b3d8be840c79d8c709c8aab12632bc6092a7123bc6d9275ba51d17ba`, while the current RRMap source SHA is `6ae0b82a0a46a7391cb5db5a0bb02e562756def8073fe08cf63beebd7ace7e50`; the packet therefore cannot be promoted to current-revision surface acceptance for the R-547 additions.

The current matrix keeps the following ordinary-fabric rows blocked:

- representative `merchant_stone` day/night frontage;
- representative `merchant_timber` day/night frontage;
- representative `craft_boda` day/night frontage, including all eight rear-workshop IDs;
- repeated frontage and material-run review;
- log, plank, plaster, and limestone gameplay readability;
- tile, shingle, and thatch gameplay readability;
- localized wear and repaired-state readability.

Candidate route pairs are useful for future review, but route coverage alone does not prove that a building, material, roof, or repair state is visible in-frame. The conditional A-009 art-direction decision also remains reference-only and is not final gameplay sign-off.

## Acceptance matrix

| R-108 ordinary-fabric clause | Result | Evidence | Owner / next action |
|---|---|---|---|
| All three authored tiers are present and mixed | PASS at source/contract level | Current source has `14/14/23`; tier test passes 6/6 | Retain visual review under R-487/R-532 |
| Required wall families are authored | PASS at source/contract level | Tier-linked styles represent log, plank, plaster, and limestone | Annotate visible stable IDs in matched route frames |
| Required roof families are authored | PASS at source/contract level | Tier-linked styles represent tile, shingle, and thatch | Annotate visible roof covers in matched route frames |
| Localized wear and repair hooks exist | PASS at source level; visual result blocked | 14 categorized decals and one repair prop are authored | Prove gameplay-scale readability under R-487/R-532 |
| Repeated frontage/material runs are acceptable | BLOCKED | No numeric repetition threshold and no accepted gameplay-scale review; exact style reuse is recorded for review | R-487/R-532 must inspect matched route runs without inventing a threshold |
| All three tiers are visually distinguishable at gameplay scale | BLOCKED | Packet is valid as a file package but has no accepted stable-ID observations | R-487/R-532 with R-616/R-561 capture handoff |
| All required material, roof, wear, and repair reads are visually distinguishable day/night | BLOCKED | Matrix rows remain `pending`; metadata is route-oriented, not observation-oriented | R-487/R-532 and capture/review owners |
| Ordinary houses remain distinct from exceptional landmarks | PASS at renderer/source boundary; visual result blocked | Tier test preserves untiered special IDs and exceptional registry boundary | R-488/R-613/R-617 own exceptional visual sign-off |

## Final disposition

**R-612 is complete as a deterministic verification report, with a BLOCKED gameplay-scale acceptance result.**

The structural/source handoff is sufficient to show that the ordinary-fabric contract is populated and internally coherent in the current checkout. It is not sufficient to close the P0-101 ordinary-fabric clause. Keep R-487, R-532, and parent R-108 open until a current-revision matched day/night packet identifies visible stable IDs and a named review records tier, material, roof, wear, repair, repetition, and landmark-separation observations.

No follow-up task is created: the missing evidence is already owned by R-487/R-532, with packet support under R-616/R-561 and exceptional-boundary review under R-488/R-613/R-617.

## Sources

- [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap)
- [`docs/data/lower_town_authoring_contract.json`](../data/lower_town_authoring_contract.json)
- [`burgher_house_typology_contract.md`](burgher_house_typology_contract.md)
- [`burgher_house_art_signoff.md`](burgher_house_art_signoff.md)
- [`lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md)
- [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md)
- [`r532_lower_town_ordinary_fabric_verification.md`](r532_lower_town_ordinary_fabric_verification.md)
- [`r616_lower_town_gameplay_evidence_verification.md`](r616_lower_town_gameplay_evidence_verification.md)
- [`images/lower_town_p0_101/capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json)
- [`tests/godot/test_burgher_house_tiers.gd`](../../tests/godot/test_burgher_house_tiers.gd)
- [`tests/godot/test_lower_town_slice_map.gd`](../../tests/godot/test_lower_town_slice_map.gd)
- [`tools/run_godot_checked.sh`](../../tools/run_godot_checked.sh)
- [`tools/run_godot_tests.gd`](../../tools/run_godot_tests.gd)
