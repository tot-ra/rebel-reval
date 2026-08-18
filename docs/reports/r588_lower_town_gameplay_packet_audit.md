# R-588 Lower Town gameplay-scale day/night packet audit

**Task:** R-588 / P0-101 decomposition: audit gameplay-scale day/night packet
**Parent:** R-108 / P0-101
**Audit date:** 2026-08-19
**Map:** `lower_town_slice` / Workers' District
**Checkout:** `b3b1de22d2ee7ea071917ec8ff69d378f874f4af`, shared worktree dirty
**Decision:** **PACKET INTEGRITY PASS; STABLE-ID VISUAL ACCEPTANCE BLOCKED.**

## Scope and decision boundary

This is an evidence-only audit. It does not recapture or replace images, change camera presets, change acceptance thresholds, or promote orthographic, calibration, whole-map, debug, or headless-only output. A visual row is **PASS** only when a matched day/night gameplay-scale pair identifies the authored stable ID(s), records the requested observation, and has reviewer status. A valid route crop without stable-ID annotation remains **BLOCKED**.

The audit uses the current shared-worktree packet produced by R-560. Because R-560 is still `in_progress` and its packet files are uncommitted in this checkout, this report records the packet as current evidence rather than clean-checkout acceptance.

## Inputs and revision boundary

| Input | Result | Evidence |
|---|---|---|
| R-491 capture contract | **PASS as contract** | [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md) defines gameplay-scale camera, matched day/night, map revision, renderer, stable IDs, evidence, interpretation, and reviewer fields. |
| R-536 packet audit | **PASS for prior packet integrity; not reused as current visual sign-off** | [`r536_lower_town_day_night_capture_verification.md`](r536_lower_town_day_night_capture_verification.md) records the older 8-plate packet and keeps surface acceptance blocked. |
| R-561 evidence audit | **BLOCKED for visual acceptance** | [`r561_lower_town_gameplay_evidence_audit.md`](r561_lower_town_gameplay_evidence_audit.md) correctly rejects route crops without stable-ID observations. Its 4-preset result predates the current 5-preset shared-worktree packet. |
| R-560 packet files | **CURRENT, uncommitted** | [`capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json), ten current PNGs, [`tools/capture_lower_town_p0_101.gd`](../../tools/capture_lower_town_p0_101.gd), and [`test_capture_lower_town_p0_101.gd`](../../tests/godot/test_capture_lower_town_p0_101.gd). |
| Current authored source | **REVISION DRIFT FOUND** | Source contains 99 records: 97 `building` records and 2 `gate_arch` landmarks. The existing matrix/inventory names 91 stable IDs; eight rear-workshop IDs are absent from the matrix. This is a coverage blocker, not silently accepted evidence. |

Current source IDs absent from the existing matrix/inventory are:

- `saddlers_rear_workshop`
- `coopers_rear_workshop`
- `sauna_rear_boda`
- `rope_makers_rear_store`
- `karja_rear_boda`
- `brewery_rear_store`
- `smithy_rear_shed`
- `carriers_barn`

These records are retained as a source-revision finding. This audit does not expand the P0-101 matrix or claim them visually accepted.

## Deterministic packet verification

The manifest verifier checked the required top-level fields, `lower_town_slice` map identity, `gl_compatibility` renderer, `1280x720` viewport, `day` and `night` times, all per-plate camera and route metadata, PNG signatures, PNG dimensions, decoded pixel payload, non-blank/non-constant pixel data, one day/night plate per preset, and equal day/night framing keys.

Observed result:

```text
R588_PACKET plates=10 presets=5 errors=0
R588_PAIR eastern_artisan_wet_margin day=eastern_artisan_wet_margin_day.png night=eastern_artisan_wet_margin_night.png dimensions=1280x720 framing=eastern_artisan_wet_margin|[2768.0, 2784.0]|0.8|33.750|-30.000|45.000
R588_PAIR landmark_approaches day=landmark_approaches_day.png night=landmark_approaches_night.png dimensions=1280x720 framing=landmark_approaches|[1824.0, 1664.0]|0.8|33.750|-30.000|45.000
R588_PAIR market_primary_spine day=market_primary_spine_day.png night=market_primary_spine_night.png dimensions=1280x720 framing=market_primary_spine|[464.0, 896.0]|0.8|33.750|-30.000|45.000
R588_PAIR merchant_craft_lane day=merchant_craft_lane_day.png night=merchant_craft_lane_night.png dimensions=1280x720 framing=merchant_craft_lane|[1328.0, 1800.0]|0.8|33.750|-30.000|45.000
R588_PAIR service_yard day=service_yard_day.png night=service_yard_night.png dimensions=1280x720 framing=service_yard|[2688.0, 2144.0]|0.8|33.750|-30.000|45.000
```

Focused capture-contract command:

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
GODOT_LOG_DIR=/tmp tools/run_godot_checked.sh --require-test-summary r588-capture-contract -- \
  "$GODOT_BIN" --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_capture_lower_town_p0_101
```

Observed result:

```text
Godot headless tests: 1 file(s), 5 test(s), 0 failure(s), 0 error(s).
```

The checked run emitted only the known shutdown resource-leak diagnostics after the green summary. The non-headless capture command recorded by the packet is:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
  --script tools/capture_lower_town_p0_101.gd
```

This audit does not claim a fresh non-headless rerender. The current PNGs and manifest were inspected in place, and their packet integrity passed.

## Matched packet inventory

Every row below is a current packet pair. `Stable IDs observed` is deliberately `none`: the manifest records route anchors and interaction targets, not visible authored building or landmark IDs. `Reviewer status` is `not signed` for every row.

| Pair / stable IDs observed | Map revision | Camera intent and route anchors | Renderer / viewport | Day plate | Night plate | Decode / non-blank | Reviewer status |
|---|---|---|---|---|---|---|---|
| `market_primary_spine`; stable IDs observed: **none** | authored `lower_town_slice.rrmap`; fingerprint `8aaad06a1d88bce339ae1ccf809e303a0d31707e52bd6f53d67eb43f289e525c`; checkout `b3b1de22` | market and primary spine readability; `vene_street_north` -> `checkpoint_west`; gameplay orthographic size `33.75`, pitch `-30`, yaw `45` | `gl_compatibility`; `1280x720` | [`market_primary_spine_day.png`](images/lower_town_p0_101/market_primary_spine_day.png) | [`market_primary_spine_night.png`](images/lower_town_p0_101/market_primary_spine_night.png) | **PASS**, decoded, non-blank, matched framing | **Not signed** |
| `merchant_craft_lane`; stable IDs observed: **none** | same revision and fingerprint | route-scale merchant and craft frontage; `checkpoint_west` -> `brewery_door`; gameplay orthographic size `33.75`, pitch `-30`, yaw `45` | `gl_compatibility`; `1280x720` | [`merchant_craft_lane_day.png`](images/lower_town_p0_101/merchant_craft_lane_day.png) | [`merchant_craft_lane_night.png`](images/lower_town_p0_101/merchant_craft_lane_night.png) | **PASS**, decoded, non-blank, matched framing | **Not signed** |
| `service_yard`; stable IDs observed: **none** | same revision and fingerprint | route-scale service yard and production frontage; `brewery_door` -> `smithy_door`; gameplay orthographic size `33.75`, pitch `-30`, yaw `45` | `gl_compatibility`; `1280x720` | [`service_yard_day.png`](images/lower_town_p0_101/service_yard_day.png) | [`service_yard_night.png`](images/lower_town_p0_101/service_yard_night.png) | **PASS**, decoded, non-blank, matched framing | **Not signed** |
| `eastern_artisan_wet_margin`; stable IDs observed: **none** | same revision and fingerprint | artisan edge and wet-margin surface readability; `checkpoint_east` -> `karja_gate_south`; gameplay orthographic size `33.75`, pitch `-30`, yaw `45` | `gl_compatibility`; `1280x720` | [`eastern_artisan_wet_margin_day.png`](images/lower_town_p0_101/eastern_artisan_wet_margin_day.png) | [`eastern_artisan_wet_margin_night.png`](images/lower_town_p0_101/eastern_artisan_wet_margin_night.png) | **PASS**, decoded, non-blank, matched framing | **Not signed** |
| `landmark_approaches`; stable IDs observed: **none** | same revision and fingerprint | landmark approach and gate opening; `checkpoint_west` -> `checkpoint_east`; gameplay orthographic size `33.75`, pitch `-30`, yaw `45` | `gl_compatibility`; `1280x720` | [`landmark_approaches_day.png`](images/lower_town_p0_101/landmark_approaches_day.png) | [`landmark_approaches_night.png`](images/lower_town_p0_101/landmark_approaches_night.png) | **PASS**, decoded, non-blank, matched framing | **Not signed** |

**Packet result:** **PASS for 5/5 matched route pairs and 10/10 image files.** This does not pass any surface observation below because the packet has no stable-ID annotation or reviewer status.

## P0-101 stable-ID acceptance matrix

The matrix is deterministic: each required row lists the stable IDs, the best available matched packet candidate, the exact evidence disposition, and the remaining reviewer/annotation blocker. `Candidate pair` means route context only. It is not promoted to visual acceptance.

| Required row / stable IDs | Candidate day / night pair | Evidence disposition | Exact blocker | Reviewer status |
|---|---|---|---|---|
| Representative `merchant_stone` frontage: `pikk_corner_house`, `vene_row_house`, `vene_corner_house`, `market_row_house`, `saiakang_house`, `vene_gate_house`, `apothecary_house`, `moneychangers_house`, `kaik_house_west`, `kaik_house_mid`, `kaik_house_east`, `glovers_house`, `viru_house_stone`, `merchants_house` | `market_primary_spine`; `merchant_craft_lane` | **BLOCKED** | No visible authored house ID, tier observation, or material/silhouette annotation in either plate. | **Not signed; R-590 / ordinary-fabric handoff** |
| Representative `merchant_timber` frontage: `turg_house_north`, `vanaturu_kael_house`, `corner_house_muurivahe`, `viru_house_west`, `viru_house_mid`, `viru_house_east`, `weary_traveler_inn`, `saddlers_house`, `coopers_house`, `rope_makers_house`, `karja_corner_house`, `turg_south_house`, `west_lane_house`, `glassblowers_house` | `market_primary_spine`; `merchant_craft_lane` | **BLOCKED** | Route metadata does not identify a visible `merchant_timber` record or prove timber/plastered-timber silhouette. | **Not signed; R-590 / ordinary-fabric handoff** |
| Representative `craft_boda` frontage: `sauna_corner_house`, `kuninga_house_west`, `kuninga_house_mid`, `kuninga_house_east`, `vaike_karja_house`, `tenement_row`, `laundress_house`, `widows_house`, `dyers_house`, `hedge_house`, `wall_side_house`, `artisan_shed`, `potters_house`, `south_apron_timber_house`, `south_apron_far_roofs` | `merchant_craft_lane`; `eastern_artisan_wet_margin` | **BLOCKED** | No stable-ID annotation proving compact workshop-dwelling massing or absence of merchant hoist treatment. | **Not signed; R-590 / ordinary-fabric handoff** |
| Current rear-workshop source additions: `saddlers_rear_workshop`, `coopers_rear_workshop`, `sauna_rear_boda`, `rope_makers_rear_store`, `karja_rear_boda`, `brewery_rear_store`, `smithy_rear_shed`, `carriers_barn` | `merchant_craft_lane`; `service_yard` | **BLOCKED** | These eight current source IDs are absent from the existing inventory/matrix, so stable-ID coverage is incomplete before visual review. | **Not signed; reconcile source/matrix boundary** |
| Repeated frontage and variation audit: all ordinary IDs above | `market_primary_spine`; `merchant_craft_lane`; `eastern_artisan_wet_margin` | **BLOCKED** | Route crops are valid, but no per-surface review or authored repetition threshold links visible runs to stable IDs. | **Not signed; R-590** |
| Log, plank, plaster, and limestone families: ordinary IDs above plus wall IDs below | `market_primary_spine`; `merchant_craft_lane`; `eastern_artisan_wet_margin` | **BLOCKED** | No material-family observation tied to visible stable IDs; source style strings are not gameplay-scale visual proof. | **Not signed; R-590** |
| Tile, shingle, and thatch roofs: ordinary IDs above | `market_primary_spine`; `merchant_craft_lane`; `eastern_artisan_wet_margin` | **BLOCKED** | No roof-family annotation or night readability review. | **Not signed; R-590** |
| Localized wear and repaired states: ordinary IDs and route-specific props | `service_yard`; `eastern_artisan_wet_margin` | **BLOCKED** | Non-blank pixels do not prove mud, wet, grime, soot, or repair details read at gameplay scale. | **Not signed; R-590** |
| Special/use-site buildings: `monastery_cloister`, `monastery_barn`, `guild_storehouse`, `public_bathhouse`, `karja_gate_house`, `foaming_mug_brewery`, `kalev_smithy`, `muurivahe_house_north`, `south_apron_wall_walk_hut` | `service_yard`; `eastern_artisan_wet_margin`; `landmark_approaches` | **BLOCKED** | Candidate route intents do not identify all nine records or prove that their silhouettes remain distinct from ordinary houses. | **Not signed; R-589 / R-590** |
| St. Catherine's church: `st_catherines_church` | `landmark_approaches` only as route context | **BLOCKED** | No church-specific approach metadata, stable-ID observation, dated 1343 silhouette review, or night readability sign-off. | **Not signed; R-589** |
| Inner Viru Gate: `viru_gate_north_tower`, `viru_gate_south_tower`, `viru_gate_north_jamb`, `viru_gate_south_jamb`, `viru_gate_arch` | `landmark_approaches` | **BLOCKED** | Pair has gate-opening intent but does not annotate the five authored IDs, opening clearance, or view-only arch relationship. | **Not signed; R-589** |
| Viru foregate: `foregate_wall_north`, `foregate_wall_south`, `foregate_tower_north`, `foregate_tower_south`, `foregate_north_jamb`, `foregate_south_jamb`, `viru_foregate_arch` | `landmark_approaches` | **BLOCKED** | Current route pair does not separate foregate records from the inner gate or identify the incomplete 1343 state and oak arch. | **Not signed; R-589** |
| Remaining fortification: `city_wall_north`, `city_wall_gate_south`, `city_wall_south_continuation`, `wall_tower_northeast`, `wall_tower_north`, `hinke_tower`, `wall_tower_southeast`, `wall_tower_south`, `wall_tower_southwest`, all eight `wall_seal_*` IDs, `city_wall_bend_a`, `city_wall_bend_b`, `city_wall_bend_c`, `city_wall_bend_d` | `landmark_approaches`; route plates as context | **BLOCKED** | No per-wall stable-ID observation, wall-walk continuity review, sealed-join review, or route-scale fortification sign-off. | **Not signed; R-589** |
| Monastery precinct walls: `monastery_precinct_wall_west`, `monastery_precinct_wall_south_a`, `monastery_precinct_wall_south_b` | `market_primary_spine` as route context | **BLOCKED** | No stable-ID view or review of precinct separation and authored route access. | **Not signed; R-589** |
| Smithy yard fences: `smithy_yard_fence_north`, `smithy_yard_fence_east` | `service_yard` | **BLOCKED** | Production-yard context is present, but fence IDs and localized boundary reading are not annotated. | **Not signed; R-589** |
| Route-scale proof that special buildings are not enlarged ordinary houses: all special IDs and `st_catherines_church` | `service_yard`; `landmark_approaches` | **BLOCKED** | No per-building exceptional renderer observation or comparative silhouette review. | **Not signed; R-589 / R-590** |
| Matched gameplay-scale route packet reproducibility: route presets and anchors, not surface IDs | all five pairs | **PASS for packet integrity only** | No surface blocker for this narrow packet-integrity row; it does not close the visual rows above. | **Packet check complete; visual review not signed** |

## Final disposition

**R-588 audit result: BLOCKED for P0-101 visual acceptance, complete for evidence audit.**

What passed:

- five deterministic gameplay-scale route presets;
- one matched day/night pair for each preset;
- ten current PNG files at `1280x720`;
- PNG decode and non-blank checks;
- shared `gl_compatibility` renderer and gameplay orthographic metadata;
- equal day/night framing keys per preset;
- focused capture contract: 5 tests, 0 failures, 0 errors.

What remains blocked:

- all three ordinary tiers because no visible stable ID is attached to a plate;
- the eight current rear-workshop source IDs absent from the existing matrix/inventory;
- material, roof, wear, and repetition observations;
- nine special/use-site buildings;
- St. Catherine's church;
- inner Viru Gate, foregate, walls, precinct walls, and smithy fences;
- route-scale proof that exceptional buildings are not enlarged ordinary houses;
- named canon/art reviewer status for every visual row.

Do not close R-108 from this packet. Existing decomposition owners remain the correct follow-up boundary: R-589 for exceptional-landmark coverage, R-590 for ordinary-fabric/source handoff, and R-591 for runtime/performance gates. No duplicate follow-up task is created by this audit.

## Sources

- [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md)
- [`lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md)
- [`capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json)
- [`tools/capture_lower_town_p0_101.gd`](../../tools/capture_lower_town_p0_101.gd)
- [`tests/godot/test_capture_lower_town_p0_101.gd`](../../tests/godot/test_capture_lower_town_p0_101.gd)
- [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap)
- [`r536_lower_town_day_night_capture_verification.md`](r536_lower_town_day_night_capture_verification.md)
- [`r561_lower_town_gameplay_evidence_audit.md`](r561_lower_town_gameplay_evidence_audit.md)
