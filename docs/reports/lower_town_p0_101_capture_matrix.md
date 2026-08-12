# Lower Town P0-101 matched capture matrix

**Task:** R-491 / P0-101f
**Role:** production / art / canon
**Map:** `lower_town_slice` / Workers' District
**Source snapshot:** `cfcf9752` (`HEAD` at capture-matrix authoring time), shared worktree dirty
**Recorded:** 2026-08-12
**Status:** **BLOCKED - no dedicated gameplay-scale capture set can be produced from the current worktree**

## Decision

This report is the evidence matrix for the P0-101 visual acceptance pass. It deliberately distinguishes **evidence** from **interpretation**. No existing image is promoted to a P0-101 acceptance plate unless it is a matched day/night, gameplay-scale view with a reproducible camera and map revision.

The required capture set is not available in the current snapshot:

- `tools/capture_map_view_3d.gd` renders a fixed orthographic view of the complete map. It does not provide gameplay-scale third-person camera positions or landmark approach framing.
- `docs/reports/images/view3d/lower_town_slice_day.png` and `docs/reports/images/view3d/lower_town_slice_night.png` were regenerated successfully by the whole-map smoke command during this task, but remain supplementary because they use the fixed orthographic camera.
- The source inventory records 43 tiered houses, nine additional default-path special/use-site houses, 36 collision-bearing wall records, and two view-only gate arches, but source records do not prove visual material, wear, silhouette, or route-scale readability.
- The current rerun clears the previously recorded focused-suite parse blockers: `test_lower_town_slice_map` passes 19/19 and `test_burgher_house_tiers` passes 3/3. The capture set is still unavailable because the existing capture script has no gameplay-scale route/approach camera presets.

This is a blocked evidence handoff, not a visual acceptance or a waiver of the missing captures.

## Capture contract

Every acceptance plate must record all of the following in its filename or matrix row:

| Field | Required value |
|---|---|
| Map | `lower_town_slice` |
| Camera | gameplay-scale third-person route camera; no top-down/debug-only substitute |
| Time | one `day` plate and one `night` plate from the same camera pose and map revision |
| Renderer | `gl_compatibility` unless the capture owner records an approved renderer decision |
| Viewport | `1280x720` or the project-approved gameplay capture resolution |
| Map revision | commit or authored-map revision, including dirty-worktree note when applicable |
| Camera intent | route-scale, ordinary frontage, landmark approach, or gate opening |
| Evidence | PNG path, non-blank verification result, and exact command/script |
| Interpretation | observed result only; do not infer material/silhouette quality from source data |

The intended baseline command for the currently available whole-map script is:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --path . --script tools/capture_map_view_3d.gd
```

The script actually writes `docs/reports/images/view3d/{kalev_smithy,lower_town_slice}_{day,night}.png`. It is useful for renderer smoke evidence, but it does **not** satisfy this matrix's gameplay-scale camera requirement. A future dedicated capture runner must expose fixed route/approach camera presets and write plates below `docs/reports/images/lower_town_p0_101/`.

## Evidence status summary

| Acceptance surface | Required day plate | Required night plate | Evidence status | Source / blocker |
|---|---|---|---|---|
| Representative `merchant_stone` frontage | pending | pending | **BLOCKED** | Inventory 1.1, `merchant_stone` rows; no gameplay-scale tier capture |
| Representative `merchant_timber` frontage | pending | pending | **BLOCKED** | Inventory 1.1, `merchant_timber` rows; no gameplay-scale tier capture |
| Representative `craft_boda` frontage | pending | pending | **BLOCKED** | Inventory 1.1, `craft_boda` rows; no gameplay-scale tier capture |
| Repeated frontage / variation audit | pending | pending | **BLOCKED** | Inventory 3, source inventory only; repetition cannot be judged from records |
| Log / plank / plaster / limestone wall families | pending | pending | **BLOCKED** | Inventory 1.1-1.3; no material-readable route frames |
| Tile / shingle / thatch roof covers | pending | pending | **BLOCKED** | Inventory 3; no gameplay-scale roof-readability frames |
| Localized wear and repaired states | pending | pending | **BLOCKED** | Inventory 3; no close or route-scale wear frames |
| Nine default-path special/use-site buildings | pending | pending | **BLOCKED** | Inventory 1.2; listed individually below |
| St. Catherine's church | pending | pending | **BLOCKED** | Inventory 1.2, `st_catherines_church`; no dated silhouette approach |
| Inner Viru Gate 1343 state | pending | pending | **BLOCKED** | Inventory 1.3-1.4; no gate approach/opening frame |
| Viru foregate 1343 state | pending | pending | **BLOCKED** | Inventory 1.3-1.4; no foregate approach/opening frame |
| Remaining fortification and precinct walls | pending | pending | **BLOCKED** | Inventory 1.3; no route-scale wall/landmark frame set |
| Route-scale proof that special buildings are not enlarged ordinary houses | pending | pending | **BLOCKED** | R-491 deliverable; no matched route frame |
| Existing playable route and landmark approach reproducibility | pending | pending | **BLOCKED** | Current capture script has no route camera presets; its whole-map orthographic smoke run cannot satisfy this gameplay-scale matrix |

Every row above requires one day and one night frame. `pending` is intentionally not a claim that a file exists.

## Required ordinary-fabric coverage

The source inventory establishes the required IDs, but not visual acceptance. At least one matched day/night gameplay-scale route frame must show each tier, and the final review must inspect repeated runs rather than a single isolated house.

| Tier | Required source IDs | Day plate | Night plate | Interpretation to record after capture |
|---|---|---|---|---|
| `merchant_stone` | `pikk_corner_house`, `vene_row_house`, `vene_corner_house`, `market_row_house`, `saiakang_house`, `vene_gate_house`, `apothecary_house`, `moneychangers_house`, `kaik_house_west`, `kaik_house_mid`, `kaik_house_east`, `glovers_house`, `viru_house_stone`, `merchants_house` | pending | pending | Stone/mixed frontage, tier silhouette, tile-forward roof bias, variation across adjacent rows |
| `merchant_timber` | `turg_house_north`, `vanaturu_kael_house`, `corner_house_muurivahe`, `viru_house_west`, `viru_house_mid`, `viru_house_east`, `weary_traveler_inn`, `saddlers_house`, `coopers_house`, `rope_makers_house`, `karja_corner_house`, `turg_south_house`, `west_lane_house`, `glassblowers_house` | pending | pending | Timber/plastered-timber frontage, shingle-forward roof bias, no accidental landmark treatment |
| `craft_boda` | `sauna_corner_house`, `kuninga_house_west`, `kuninga_house_mid`, `kuninga_house_east`, `vaike_karja_house`, `tenement_row`, `laundress_house`, `widows_house`, `dyers_house`, `hedge_house`, `wall_side_house`, `artisan_shed`, `potters_house`, `south_apron_timber_house`, `south_apron_far_roofs` | pending | pending | Compact workshop-dwelling massing, log/plank/thatch or shingle readability, no merchant hoist default |

**Inventory link:** [`lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md), section 1.1, source lines 160-213 of `content/maps/lower_town_slice.rrmap`.

## Required special and landmark coverage

The following rows retain the stable IDs from the inventory so that each future plate can be linked to one authored record. A grouped row is used only where the inventory itself defines a wall surface family; the stable IDs remain explicit and must be checked individually during capture review.

| Surface / stable IDs | Day plate | Night plate | Required observation | Inventory link |
|---|---|---|---|---|
| `monastery_cloister`, `monastery_barn` | pending | pending | Special/use-site mass reads as a precinct/service structure, not a scaled ordinary house | Inventory 1.2 |
| `guild_storehouse`, `public_bathhouse` | pending | pending | Use-site identity and frontage remain distinct from ordinary tiers | Inventory 1.2 |
| `karja_gate_house`, `foaming_mug_brewery`, `kalev_smithy` | pending | pending | Gate/production landmarks retain readable approach and do not inherit a generic enlarged-house silhouette | Inventory 1.2 |
| `muurivahe_house_north`, `south_apron_wall_walk_hut` | pending | pending | Special/use-site boundary and wall relationship remain legible at route scale | Inventory 1.2 |
| `st_catherines_church` | pending | pending | Dated 1343 church silhouette, exceptional path, approach and night readability; no ordinary-house substitution | Inventory 1.2, exceptional registry |
| `viru_gate_north_tower`, `viru_gate_south_tower`, `viru_gate_north_jamb`, `viru_gate_south_jamb` | pending | pending | Collision-bearing inner gate throat, opening clearance, tower/jamb relationship and 1343 state | Inventory 1.3, Viru Gate subsection |
| `viru_gate_arch` | pending | pending | View-only ironbound arch and raised portcullis align visually with jambs; do not treat the arch as collision | Inventory 1.4 |
| `foregate_wall_north`, `foregate_wall_south`, `foregate_tower_north`, `foregate_tower_south`, `foregate_north_jamb`, `foregate_south_jamb` | pending | pending | Incomplete 1343 foregate state and oak leaves remain distinct from the inner gate | Inventory 1.3, Foregate subsection |
| `viru_foregate_arch` | pending | pending | View-only oak arch fits the foregate opening and preserves route readability | Inventory 1.4 |
| `city_wall_north`, `city_wall_gate_south`, `city_wall_south_continuation` | pending | pending | City-wall continuity and gate-side massing read as fortification surface, not ordinary houses | Inventory 1.3 |
| `wall_tower_northeast`, `wall_tower_north`, `hinke_tower`, `wall_tower_southeast`, `wall_tower_south`, `wall_tower_southwest` | pending | pending | Round-tower silhouettes and wall-walk continuity; no later or unowned tower invention | Inventory 1.3 |
| `wall_seal_viru_south_join`, `wall_seal_viru_south_west`, `wall_seal_viru_south_east`, `wall_seal_hinke_north`, `wall_seal_bend_a_east`, `wall_seal_bend_b_north`, `wall_seal_bend_c_west`, `wall_seal_bend_d_north` | pending | pending | Sealed wall joins remain closed and do not create accidental openings or ordinary frontage | Inventory 1.3 |
| `city_wall_bend_a`, `city_wall_bend_b`, `city_wall_bend_c`, `city_wall_bend_d` | pending | pending | Bends preserve fortification silhouette, occlusion and route clearance | Inventory 1.3 |
| `monastery_precinct_wall_west`, `monastery_precinct_wall_south_a`, `monastery_precinct_wall_south_b` | pending | pending | Precinct boundary reads separately from house rows and remains traversable only at authored routes | Inventory 1.3 |
| `smithy_yard_fence_north`, `smithy_yard_fence_east` | pending | pending | Yard boundary and production approach remain localized, not monumental | Inventory 1.3 |

**Note:** The complete tower set has ten IDs: `wall_tower_northeast`, `wall_tower_north`, `viru_gate_north_tower`, `viru_gate_south_tower`, `foregate_tower_north`, `foregate_tower_south`, `hinke_tower`, `wall_tower_southeast`, `wall_tower_south`, and `wall_tower_southwest`; the Viru and foregate tower IDs are covered in their dedicated rows above.

## Supplementary images that must not be promoted

These files exist, but they do not satisfy the P0-101 acceptance contract because their camera intent or scope is wrong:

| Existing file | Use | Why it is not P0-101 evidence |
|---|---|---|
| `docs/reports/images/view3d/lower_town_slice_day.png` | Whole-map renderer smoke context | Fixed orthographic camera; no route or landmark approach metadata |
| `docs/reports/images/view3d/lower_town_slice_night.png` | Whole-map renderer smoke context | Fixed orthographic camera; no matched gameplay-scale framing |
| `docs/reports/images/adr0018_calibration/lower_town_slice_third_person_day.png` | ADR-0018 calibration context | Calibration plate, not a P0-101 route/landmark inventory capture |
| `docs/reports/images/adr0018_calibration/lower_town_slice_third_person_night.png` | ADR-0018 calibration context | Calibration plate; it does not identify the required frontage/landmark IDs |
| `docs/reports/images/adr0018_calibration/lower_town_slice_top_down_day.png` | Debug/overview context | Top-down/debug view is explicitly disallowed as acceptance capture |
| `docs/reports/images/adr0018_calibration/lower_town_slice_top_down_night.png` | Debug/overview context | Top-down/debug view is explicitly disallowed as acceptance capture |
| `docs/reports/images/map_audit/lower_town_slice.png` | Map audit context | Audit image has no matched gameplay day/night camera contract |
| `docs/reports/images/map_conversion_lower_town_after_day.png` | Conversion context | Historical conversion evidence, not the final P0-101 integrated route set |
| `docs/reports/images/map_conversion_lower_town_after_night.png` | Conversion context | Historical conversion evidence, not the final P0-101 integrated route set |

## Blockers and ownership handoff

1. **Capture capability:** add or use a dedicated rendering-capable capture runner with stable gameplay-scale route and approach camera presets. It must write under `docs/reports/images/lower_town_p0_101/` and emit camera/map/time metadata.
2. **Focused contracts:** the current rerun passes `test_lower_town_slice_map` (19/19) and `test_burgher_house_tiers` (3/3). Preserve these results as the current baseline; the remaining blocker is the missing gameplay-scale route/approach capture capability, not a focused-suite parse failure.
3. **Production dependencies:** the ordinary house kits, plot dressing, tier wiring and exceptional-landmark implementation must be complete before the captures can show the required authored visual surfaces. The existing board tasks R-487/R-488/R-489 own those upstream handoffs.
4. **Review:** after the PNG set exists, run non-blank/dimension checks, capture the same route poses at day and night, then send the matrix plus plates to the canon/art reviewer for R-492. Do not close R-108 from this blocked matrix.

No new follow-up task is created here: each blocker already has an owning board task or an existing runtime owner, and creating a duplicate would obscure ownership.

## Reproduction and verification checklist

The following commands are the minimum evidence record for the next capture attempt:

```bash
# Whole-map renderer smoke only; not sufficient for this matrix.
/Applications/Godot.app/Contents/MacOS/Godot \
  --path . --script tools/capture_map_view_3d.gd

# Existing focused contracts (current rerun: 19/19 and 3/3).
tools/run_godot_checked.sh --require-test-summary r491-lower-map \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_lower_town_slice_map

tools/run_godot_checked.sh --require-test-summary r491-house-tiers \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_burgher_house_tiers
```

For each future plate, verify dimensions and non-blank output using the existing capture-stat helper or an equivalent project check. A successful command with no route-camera metadata still remains supplementary, not acceptance evidence.

## Source references

- [`lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md), especially sections 1.1-1.4, 3-4, and 5-6.
- [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap), source lines 116-219.
- [`tools/capture_map_view_3d.gd`](../../tools/capture_map_view_3d.gd), fixed `MAP_IDS`, `OUTPUT_DIR`, viewport, and orthographic view creation.
- [`tests/godot/test_capture_map_view_3d.gd`](../../tests/godot/test_capture_map_view_3d.gd), existing whole-map capture contract.
- [`tools/verify_adr0018_calibration_captures.py`](../../tools/verify_adr0018_calibration_captures.py), calibration-only image verification and camera modes.
- [`adr0018_visual_calibration.md`](adr0018_visual_calibration.md), calibration protocol and renderer context.
- [`docs/reports/renderer_evaluation.md`](renderer_evaluation.md), renderer choice and non-headless capture boundary.
