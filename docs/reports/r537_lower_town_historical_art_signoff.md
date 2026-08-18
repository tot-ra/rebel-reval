# R-537 / P0-101 historical and art sign-off ledger

**Review date:** 2026-08-18
**Parent:** R-108 / P0-101
**Map:** `lower_town_slice` / Workers' District
**Review scope:** R-486 inventory, R-492 silhouette review, R-533 boundary acceptance, R-536 capture verification, and the R-491/R-560 capture packet
**Status:** **BLOCKED - evidence audit complete; no historical or art approval issued**

## Decision

R-537 cannot approve the Lower Town historical/art gate. The source and runtime boundary contracts pass, but the acceptance packet does not contain a stable-ID-linked gameplay-scale day/night pair for each required landmark or ordinary family, and no named human canon or art reviewer has signed a per-row observation.

The final disposition is therefore **BLOCKED for all 48 non-ordinary stable IDs and all three ordinary-family boundaries**. This is an evidence decision, not a rejection of the authored source or a historical claim. No row is promoted from `BLOCKED` to `PASS` or `PASS WITH AMENDMENTS` based on source records, structural tests, generic route crops, or supplementary images.

### Reviewer assignment boundary

| Required role | Named reviewer | Result |
|---|---|---|
| Human canon reviewer | **Not assigned** in R-492 or the current review packet | Blocking absence; no historical silhouette approval |
| Human art reviewer | **Not assigned** in R-492 or the current review packet | Blocking absence; no material/value or readability approval |

R-492 explicitly records `Human canon reviewer: Not assigned`, `Human art reviewer: Not assigned`, and `BLOCKED - no silhouette may be approved from the current evidence set`. R-533 records structural PASS but final art/history BLOCKED for every row. R-536 records packet integrity PASS while keeping surface-by-surface visual acceptance BLOCKED.

## Evidence audit

| Evidence item | Result | Boundary used in this ledger |
|---|---|---|
| R-486 authored inventory | **PASS as source inventory only** | 91 unique records: 43 tiered houses, 10 untiered houses, 36 wall records, and 2 view-only gate arches. Source ownership is not visual acceptance. |
| R-533 boundary contract | **PASS structurally; BLOCKED visually** | All 48 required non-ordinary IDs are present exactly once; renderer, wall, route, collision, and view-only boundaries pass. No human review or gameplay-scale visual verdict is present. |
| R-492 historical/art review | **BLOCKED** | Human canon and art reviewers are unassigned; all per-silhouette rows are intentionally blocked. |
| R-536 packet integrity | **PASS as packet integrity; BLOCKED per surface** | Eight valid 1280x720 PNGs, four matched day/night framing pairs, deterministic manifest, and focused capture contract pass. The packet does not identify every required stable ID. |
| R-491 capture matrix | **BLOCKED for acceptance surfaces** | Every tier, material, roof, wear, special-building, church, gate, wall, and exceptional-boundary row remains pending or blocked. |
| `capture_manifest.json` | **PASS as metadata** | Map `lower_town_slice`, renderer `gl_compatibility`, orthographic size `33.75`, pitch `-30`, yaw `45`, viewport `1280x720`, and four generic route presets. No per-landmark stable-ID observations. |
| Existing whole-map/calibration/audit images | **Supplementary only** | They lack the required matched gameplay-scale stable-ID route/approach annotation and cannot be promoted. |

### Accepted packet metadata

The current dedicated packet is reproducible at the metadata level:

- Source task: `R-560 / P0-101f`.
- Map: `lower_town_slice`.
- Map fingerprint: `e8cde197067d824d1efd46b399506f6d86158a506cd92bf5d6c6b5552f4209b2`.
- Map revision note: authored source from a shared dirty worktree; the packet records the checkout separately.
- Renderer: `gl_compatibility` / `opengl3`.
- Camera: gameplay orthographic route camera, size `33.75`, pitch `-30`, yaw `45`.
- Outputs: four generic route presets, each with one `day` and one `night` PNG, all `1280x720` and non-blank.
- Focused result: `test_capture_lower_town_p0_101`, 1 file, 4 tests, 0 failures, 0 errors.

The four available pairs are useful packet evidence only:

1. `street_start_to_smithy_door_day.png` / `street_start_to_smithy_door_night.png`
2. `smithy_door_to_brewery_door_day.png` / `smithy_door_to_brewery_door_night.png`
3. `brewery_door_to_checkpoint_west_day.png` / `brewery_door_to_checkpoint_west_night.png`
4. `checkpoint_west_to_checkpoint_east_day.png` / `checkpoint_west_to_checkpoint_east_night.png`

None of these pairs names a required stable ID in its manifest row. The checkpoint pair is a generic gate-opening approach and is not a signed observation of the inner gate, foregate, church, or any individual wall record.

## Disposition rules

A row may be changed to `PASS` or `PASS WITH AMENDMENTS` only when all of the following are present:

1. A matched day/night gameplay-scale pair from the same camera pose, map revision, and renderer contract.
2. The pair links directly to the stable ID or ordinary family being reviewed, rather than only to a generic route midpoint.
3. A named canon reviewer records the Spring 1343 historical observation, confidence boundary, and excluded later forms.
4. A named art reviewer records silhouette, material/value readability, route/occlusion, and day/night legibility.
5. The row's collision or view-only semantics are checked where applicable.
6. Any amendment has an owner and a concrete next action.

Because conditions 2-4 are absent for every required row, each row below is **BLOCKED**. `R-533` structural PASS is retained as a separate evidence field and does not alter this final disposition.

## Ordinary-family boundary ledger

| Family / required IDs | Day/night evidence | Canon reviewer | Art reviewer | Verdict | Per-row observation and next action |
|---|---|---|---|---|---|
| `merchant_stone` - 14 IDs: `pikk_corner_house`, `vene_row_house`, `vene_corner_house`, `market_row_house`, `saiakang_house`, `vene_gate_house`, `apothecary_house`, `moneychangers_house`, `kaik_house_west`, `kaik_house_mid`, `kaik_house_east`, `glovers_house`, `viru_house_stone`, `merchants_house` | None linked to the family or a stable ID. Generic ordinary-frontage pairs are rejected as unannotated. | Not assigned | Not assigned | **BLOCKED** | No signed observation of stone/mixed frontage, tile-forward roof, merchant massing, variation, or separation from exceptional landmarks. Owner: R-487/R-532; provide stable-ID-linked day/night frontage evidence and named review. |
| `merchant_timber` - 14 IDs: `turg_house_north`, `vanaturu_kael_house`, `corner_house_muurivahe`, `viru_house_west`, `viru_house_mid`, `viru_house_east`, `weary_traveler_inn`, `saddlers_house`, `coopers_house`, `rope_makers_house`, `karja_corner_house`, `turg_south_house`, `west_lane_house`, `glassblowers_house` | None linked to the family or a stable ID. Generic ordinary-frontage pairs are rejected as unannotated. | Not assigned | Not assigned | **BLOCKED** | No signed observation of timber/plastered-timber frontage, shingle-forward roof, variation, or negative check against stone/Gothic drift. Owner: R-487/R-532; provide stable-ID-linked day/night frontage evidence and named review. |
| `craft_boda` - 15 IDs: `sauna_corner_house`, `kuninga_house_west`, `kuninga_house_mid`, `kuninga_house_east`, `vaike_karja_house`, `tenement_row`, `laundress_house`, `widows_house`, `dyers_house`, `hedge_house`, `wall_side_house`, `artisan_shed`, `potters_house`, `south_apron_timber_house`, `south_apron_far_roofs` | None linked to the family or a stable ID. Generic ordinary-frontage pairs are rejected as unannotated. | Not assigned | Not assigned | **BLOCKED** | No signed observation of compact workshop-dwelling massing, log/plank/thatch or shingle read, or absence of a merchant hoist. Owner: R-487/R-532; provide stable-ID-linked day/night frontage evidence and named review. |

## Non-ordinary stable-ID ledger

### Special and exceptional buildings

| Stable ID | Required review boundary | Day/night evidence | Canon reviewer | Art reviewer | Verdict | Per-row observation and next action |
|---|---|---|---|---|---|---|
| `monastery_cloister` | Monastery precinct mass, not a scaled ordinary house | None; generic route pair not linked | Not assigned | Not assigned | **BLOCKED** | No signed period or route-scale observation. Owner: R-488/R-489/R-492; capture and review the precinct mass and its ordinary-family boundary. |
| `monastery_barn` | Service/agricultural mass distinct from ordinary frontage | None; generic route pair not linked | Not assigned | Not assigned | **BLOCKED** | No signed service-yard, material/value, or silhouette observation. Owner: R-488/R-489/R-492; capture and review the authored use-site boundary. |
| `guild_storehouse` | Storage/use-site identity and enlarged mass | None; generic route pair not linked | Not assigned | Not assigned | **BLOCKED** | No signed storehouse identity or non-monumental period observation. Owner: R-488/R-489/R-492; provide an annotated approach pair. |
| `public_bathhouse` | Bathhouse identity and frontage distinct from ordinary tiers | None; generic route pair not linked | Not assigned | Not assigned | **BLOCKED** | No signed use-site, material/value, or route readability observation. Owner: R-488/R-489/R-492; provide an annotated approach pair. |
| `karja_gate_house` | Gate-side use-site, not an enlarged house | None; generic route pair not linked | Not assigned | Not assigned | **BLOCKED** | No signed gate-side boundary or exclusion of later forms. Owner: R-488/R-489/R-492; provide an annotated approach pair. |
| `foaming_mug_brewery` | Production building, entrance, and working-yard relationship | None; brewery route intent is not a stable-ID observation | Not assigned | Not assigned | **BLOCKED** | The route packet names a brewery anchor but does not identify this building or record a signed production-yard read. Owner: R-488/R-489/R-492. |
| `kalev_smithy` | Smithy mass and production approach, not a tier substitute | None; smithy route intent is not a stable-ID observation | Not assigned | Not assigned | **BLOCKED** | The route packet names a smithy anchor but does not identify this building or record a signed special-use read. Owner: R-488/R-489/R-492. |
| `muurivahe_house_north` | Wall-adjacent special boundary | None; generic route pair not linked | Not assigned | Not assigned | **BLOCKED** | No signed wall relationship, modest scale, or period-boundary observation. Owner: R-488/R-489/R-492. |
| `south_apron_wall_walk_hut` | Wall-walk/service relationship and modest scale | None; generic route pair not linked | Not assigned | Not assigned | **BLOCKED** | No signed service relationship, occlusion, or modest-scale observation. Owner: R-488/R-489/R-492. |
| `st_catherines_church` | Dated 1343 church silhouette; dedicated exceptional renderer; no later enrichment | No dedicated day/night approach pair | Not assigned | Not assigned | **BLOCKED** | R-536 explicitly reports no dedicated church approach metadata or sign-off. No approval of the silhouette, church mass, route readability, or exclusion of later Gothic forms. Owner: R-488/R-489/R-492. |

### Inner Viru Gate

| Stable ID | Required review boundary | Day/night evidence | Canon reviewer | Art reviewer | Verdict | Per-row observation and next action |
|---|---|---|---|---|---|---|
| `viru_gate_north_tower` | Collision-bearing round tower; wall-walk `z`; 1343 gate mass | Generic checkpoint pair only; not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | Structural boundary passes in R-533, but no signed tower silhouette, wall-walk, opening-clearance, or period observation. Owner: R-488/R-489/R-492. |
| `viru_gate_south_tower` | Collision-bearing round tower; wall-walk `z`; 1343 gate mass | Generic checkpoint pair only; not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | Structural boundary passes in R-533, but no signed tower silhouette, wall-walk, opening-clearance, or period observation. Owner: R-488/R-489/R-492. |
| `viru_gate_north_jamb` | Collision-bearing inner-gate jamb and road opening | Generic checkpoint pair only; not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed jamb-to-arch alignment, route clearance, or material/value observation. Owner: R-488/R-489/R-492. |
| `viru_gate_south_jamb` | Collision-bearing inner-gate jamb and road opening | Generic checkpoint pair only; not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed jamb-to-arch alignment, route clearance, or material/value observation. Owner: R-488/R-489/R-492. |
| `viru_gate_arch` | View-only ironbound arch and raised portcullis; no collision/navigation | Generic checkpoint pair only; not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | R-533 structurally verifies view-only semantics, but no signed visual fit, arch readability, or historical observation. Owner: R-488/R-489/R-492. |

### Viru foregate

| Stable ID | Required review boundary | Day/night evidence | Canon reviewer | Art reviewer | Verdict | Per-row observation and next action |
|---|---|---|---|---|---|---|
| `foregate_wall_north` | Collision-bearing incomplete foregate wall | Generic checkpoint pair only; not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed incomplete-state, wall opening, or route-scale observation. Owner: R-488/R-489/R-492. |
| `foregate_wall_south` | Collision-bearing incomplete foregate wall | Generic checkpoint pair only; not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed incomplete-state, wall opening, or route-scale observation. Owner: R-488/R-489/R-492. |
| `foregate_tower_north` | Subordinate round-tower stub in the incomplete state | Generic checkpoint pair only; not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed subordinate-tower silhouette or construction-state observation. Owner: R-488/R-489/R-492. |
| `foregate_tower_south` | Subordinate round-tower stub in the incomplete state | Generic checkpoint pair only; not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed subordinate-tower silhouette or construction-state observation. Owner: R-488/R-489/R-492. |
| `foregate_north_jamb` | Collision-bearing foregate opening boundary | Generic checkpoint pair only; not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed jamb alignment, route clearance, or oak-leaf boundary observation. Owner: R-488/R-489/R-492. |
| `foregate_south_jamb` | Collision-bearing foregate opening boundary | Generic checkpoint pair only; not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed jamb alignment, route clearance, or oak-leaf boundary observation. Owner: R-488/R-489/R-492. |
| `viru_foregate_arch` | View-only oak arch; no collision/navigation | Generic checkpoint pair only; not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | R-533 structurally verifies view-only semantics, but no signed oak-arch fit, opening readability, or historical observation. Owner: R-488/R-489/R-492. |

### City-wall continuity and gate-side fabric

| Stable ID | Required review boundary | Day/night evidence | Canon reviewer | Art reviewer | Verdict | Per-row observation and next action |
|---|---|---|---|---|---|---|
| `city_wall_north` | Continuous city-wall surface, not ordinary frontage | None; generic route pair not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed fortification silhouette, skyline exclusion, or route-scale occlusion observation. Owner: R-488/R-489/R-492. |
| `city_wall_gate_south` | Gate-side wall mass and non-tower state | None; generic route pair not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed gate-side mass, route boundary, or period-state observation. Owner: R-488/R-489/R-492. |
| `city_wall_south_continuation` | Continuous wall silhouette and route-scale edge | None; generic route pair not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed continuation, occlusion, or exclusion of later skyline observation. Owner: R-488/R-489/R-492. |

### Round towers and wall-walk silhouettes

| Stable ID | Required review boundary | Day/night evidence | Canon reviewer | Art reviewer | Verdict | Per-row observation and next action |
|---|---|---|---|---|---|---|
| `wall_tower_northeast` | Round tower and wall-walk `z`; no unowned later tower | None; generic route pair not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed tower silhouette, wall-walk continuity, or later-form exclusion. Owner: R-488/R-489/R-492. |
| `wall_tower_north` | Round tower and wall-walk `z`; no unowned later tower | None; generic route pair not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed tower silhouette, wall-walk continuity, or later-form exclusion. Owner: R-488/R-489/R-492. |
| `hinke_tower` | Round tower and wall-walk `z`; no unowned later tower | None; generic route pair not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed tower silhouette, wall-walk continuity, or later-form exclusion. Owner: R-488/R-489/R-492. |
| `wall_tower_southeast` | Round tower and wall-walk `x`; no unowned later tower | None; generic route pair not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed tower silhouette, wall-walk continuity, or later-form exclusion. Owner: R-488/R-489/R-492. |
| `wall_tower_south` | Round tower and wall-walk `x`; no unowned later tower | None; generic route pair not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed tower silhouette, wall-walk continuity, or later-form exclusion. Owner: R-488/R-489/R-492. |
| `wall_tower_southwest` | Round tower and wall-walk `x`; no unowned later tower | None; generic route pair not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed tower silhouette, wall-walk continuity, or later-form exclusion. Owner: R-488/R-489/R-492. |

### Sealed wall joins

| Stable ID | Required review boundary | Day/night evidence | Canon reviewer | Art reviewer | Verdict | Per-row observation and next action |
|---|---|---|---|---|---|---|
| `wall_seal_viru_south_join` | Closed wall join; no route breach or ordinary frontage | None; generic route pair not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed closure, material continuity, or accidental-opening observation. Owner: R-488/R-489/R-492. |
| `wall_seal_viru_south_west` | Closed wall join; no route breach or ordinary frontage | None; generic route pair not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed closure, material continuity, or accidental-opening observation. Owner: R-488/R-489/R-492. |
| `wall_seal_viru_south_east` | Closed wall join; no route breach or ordinary frontage | None; generic route pair not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed closure, material continuity, or accidental-opening observation. Owner: R-488/R-489/R-492. |
| `wall_seal_hinke_north` | Closed wall join; no route breach or ordinary frontage | None; generic route pair not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed closure, material continuity, or accidental-opening observation. Owner: R-488/R-489/R-492. |
| `wall_seal_bend_a_east` | Closed wall join; no route breach or ordinary frontage | None; generic route pair not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed closure, material continuity, or accidental-opening observation. Owner: R-488/R-489/R-492. |
| `wall_seal_bend_b_north` | Closed wall join; no route breach or ordinary frontage | None; generic route pair not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed closure, material continuity, or accidental-opening observation. Owner: R-488/R-489/R-492. |
| `wall_seal_bend_c_west` | Closed wall join; no route breach or ordinary frontage | None; generic route pair not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed closure, material continuity, or accidental-opening observation. Owner: R-488/R-489/R-492. |
| `wall_seal_bend_d_north` | Closed wall join; no route breach or ordinary frontage | None; generic route pair not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed closure, material continuity, or accidental-opening observation. Owner: R-488/R-489/R-492. |

### City-wall bends and precinct/fence boundaries

| Stable ID | Required review boundary | Day/night evidence | Canon reviewer | Art reviewer | Verdict | Per-row observation and next action |
|---|---|---|---|---|---|---|
| `city_wall_bend_a` | Fortification bend, route clearance, and intended occlusion | None; generic route pair not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed bend silhouette, route-clearance, occlusion, or later-form exclusion. Owner: R-488/R-489/R-492. |
| `city_wall_bend_b` | Fortification bend, route clearance, and intended occlusion | None; generic route pair not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed bend silhouette, route-clearance, occlusion, or later-form exclusion. Owner: R-488/R-489/R-492. |
| `city_wall_bend_c` | Fortification bend, route clearance, and intended occlusion | None; generic route pair not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed bend silhouette, route-clearance, occlusion, or later-form exclusion. Owner: R-488/R-489/R-492. |
| `city_wall_bend_d` | Fortification bend, route clearance, and intended occlusion | None; generic route pair not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed bend silhouette, route-clearance, occlusion, or later-form exclusion. Owner: R-488/R-489/R-492. |
| `monastery_precinct_wall_west` | Precinct boundary separate from houses; traversal only at authored routes | None; generic route pair not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed precinct boundary, route access, or ordinary-house separation observation. Owner: R-488/R-489/R-492. |
| `monastery_precinct_wall_south_a` | Precinct boundary separate from houses; traversal only at authored routes | None; generic route pair not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed precinct boundary, route access, or ordinary-house separation observation. Owner: R-488/R-489/R-492. |
| `monastery_precinct_wall_south_b` | Precinct boundary separate from houses; traversal only at authored routes | None; generic route pair not stable-ID linked | Not assigned | Not assigned | **BLOCKED** | No signed precinct boundary, route access, or ordinary-house separation observation. Owner: R-488/R-489/R-492. |
| `smithy_yard_fence_north` | Localized production boundary; modest, not monumental or house-like | None; smithy route intent is not a stable-ID observation | Not assigned | Not assigned | **BLOCKED** | No signed fence scale, production approach, material/value, or ordinary-house separation observation. Owner: R-488/R-489/R-492. |
| `smithy_yard_fence_east` | Localized production boundary; modest, not monumental or house-like | None; smithy route intent is not a stable-ID observation | Not assigned | Not assigned | **BLOCKED** | No signed fence scale, production approach, material/value, or ordinary-house separation observation. Owner: R-488/R-489/R-492. |

## Acceptance summary

| Scope | Rows | Structural result | Final historical/art result |
|---|---:|---|---|
| Ordinary-family boundaries | 3 | Source tier contract exists; R-533 tier boundary tests pass in its recorded run | **0 PASS, 0 PASS WITH AMENDMENTS, 3 BLOCKED** |
| Special and exceptional buildings | 10 | Source and renderer boundaries pass where covered by R-533 | **0 PASS, 0 PASS WITH AMENDMENTS, 10 BLOCKED** |
| Inner Viru Gate | 5 | Wall/view-only and opening contracts pass in R-533 | **0 PASS, 0 PASS WITH AMENDMENTS, 5 BLOCKED** |
| Viru foregate | 7 | Wall/view-only boundary contracts pass in R-533 | **0 PASS, 0 PASS WITH AMENDMENTS, 7 BLOCKED** |
| City-wall continuity | 3 | Authored wall records present | **0 PASS, 0 PASS WITH AMENDMENTS, 3 BLOCKED** |
| Round towers and wall-walks | 6 | Authored tower/wall-walk records present | **0 PASS, 0 PASS WITH AMENDMENTS, 6 BLOCKED** |
| Sealed wall joins | 8 | Authored sealed wall records present | **0 PASS, 0 PASS WITH AMENDMENTS, 8 BLOCKED** |
| Bends, precinct walls, and fences | 9 | Authored wall/fence records present | **0 PASS, 0 PASS WITH AMENDMENTS, 9 BLOCKED** |
| **Total** | **51** | Structural source/boundary evidence retained separately | **0 PASS, 0 PASS WITH AMENDMENTS, 51 BLOCKED** |

The 51-row total is 3 ordinary-family boundaries plus the 48 non-ordinary stable IDs. The R-486/R-492 inventory count of 48 remains unchanged.

## Handoff and follow-up ownership

No duplicate follow-up task is created. The blockers already have executable owners:

- **R-487 / P0-101b:** ordinary frontage variation, wear, and tier-specific visual evidence.
- **R-488 / P0-101c:** exceptional landmark implementation and non-ordinary silhouettes.
- **R-489 / P0-101d:** playable-route art integration.
- **R-490 / P0-101e:** runtime, route, occlusion, and budget QA.
- **R-491 / P0-101f:** stable-ID-linked matched day/night capture packet.
- **R-492 / P0-101g:** named canon/art silhouette review.
- **R-108 / P0-101:** final parent acceptance after the blockers close.

R-537 is complete as a verification ledger but must not be interpreted as approval of the historical/art gate. R-108 remains open.

## Reproduction and source references

Focused evidence and metadata checks used for this ledger:

```sh
python3 - <<'PY'
from pathlib import Path
import re
text = Path("docs/reports/r533_lower_town_landmark_boundary_acceptance.md").read_text()
ids = [m.group(1) for m in re.finditer(r"^\| `([^`]+)` \|", text, re.MULTILINE)]
assert len(ids) == 48
assert len(set(ids)) == 48
assert "Human canon reviewer: Not assigned" in Path("docs/reports/r492_lower_town_1343_landmark_silhouette_review.md").read_text()
assert "Human art reviewer: Not assigned" in Path("docs/reports/r492_lower_town_1343_landmark_silhouette_review.md").read_text()
assert "BLOCKED" in Path("docs/reports/r536_lower_town_day_night_capture_verification.md").read_text()
print(f"R537_EVIDENCE_PASS stable_ids={len(ids)} ordinary_families=3 reviewers_assigned=0")
PY
```

Source records and prior decisions:

- [`lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md)
- [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md)
- [`r492_lower_town_1343_landmark_silhouette_review.md`](r492_lower_town_1343_landmark_silhouette_review.md)
- [`r533_lower_town_landmark_boundary_acceptance.md`](r533_lower_town_landmark_boundary_acceptance.md)
- [`r536_lower_town_day_night_capture_verification.md`](r536_lower_town_day_night_capture_verification.md)
- [`images/lower_town_p0_101/capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json)
- [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap)
- [`tests/godot/test_lower_town_slice_map.gd`](../../tests/godot/test_lower_town_slice_map.gd)
- [`tests/godot/test_burgher_house_tiers.gd`](../../tests/godot/test_burgher_house_tiers.gd)
