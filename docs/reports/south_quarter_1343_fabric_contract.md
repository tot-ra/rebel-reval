# R-675 / P4-024a South Quarter 1343 fabric contract

**Review date:** 2026-08-23
**Parent:** R-282 / P4-024
**Map:** `south_quarter` / Knights District prototype
**Status:** **CONTRACT FROZEN - implementation and activation remain blocked**
**Historical target:** Spring 1343 Reval, before later fortification completion and monumental rebuilding

## Decision boundary

This document freezes the authoring contract for the South/Knights District before the geometry, ordinary-fabric, landmark, population, and evidence passes. It is the source-facing acceptance ledger for P4-024 and its child tasks. It does not claim that the current prototype is visually complete, does not create geometry or assets, and does not activate the map.

The composition card is now **enforced** so future P1-036 audits cannot silently skip this district. That change is an authoring gate, not an acceptance result: the current activation row stays `implementation_delivered=false`, `status=BLOCKED`, and the RRMap stays `active=false`. The missing `karja_gate_arch/GateDoor0`, population profiles, gameplay evidence, and signed day/night seam pairs remain explicit downstream blockers.

## Sources and confidence notes

The contract uses the shared historical audit vocabulary: **A** = well-supported, **B** = supported synthesis, **C** = contested or weakly supported, **D** = design/composite, and **U** = unknown. The district label “Knights District” is a production label, not a claim that a documented medieval district of that name existed.

| Source | Evidence used for this contract | Confidence and boundary |
|---|---|---|
| [H08 - Tallinn defensive walls](../HISTORICAL_AUDIT.md#source-register) | Fortification expansion continued through the 1340s; the perimeter followed terrain; south-eastern and low ground could be wet and defended by moats or water management. | **A/B/U.** Exact completion of each wall or tower position in 1343 is unresolved. Do not present the later closed circuit as a dated fact. |
| [H09 - Viru/Vana Turg/Kuninga archaeology](../../history/AVE2016_17_KRAUT-NURK_Tln-Viru-tn.pdf) | Mid-14th-century gate and watermill context; possible limestone slab surfaces; later timber water pipes are not automatically medieval. | **B/U.** Viru work may be under construction in 1343. Later barbicans, foregates, and pipes are excluded from this district contract. |
| [H10 - Karja Gate archaeology](../../history/dossiers/topography/karja-gate-leaf-state-1343.md) | Early rubble/pebble road, later limestone slabs, coastal-lowland relief, road-aligned settlement, and early-14th-century wall/gate reconstruction. | **B/U.** Karja is first written in 1365; the 1343 superstructure, watermill state, and exact road edge remain uncertain. |
| [Shared historical audit](../HISTORICAL_AUDIT.md#south_quarter---southern-lanes-karja-approach-and-wall-edge) | South Quarter ranges for density, ordinary fabric, roof covers, surfaces, drainage, fencing, planting, fauna, relief, and landmarks. | **A/B/D/U by row.** These are broad authoring bands, not permission to copy later Tallinn facades or to claim measured acreage. |

## Frozen spatial decisions

### Street and property structure

- Preserve **dense irregular lanes** inside the expanding wall: Rataskaev, Dunkri, King's Street, Niguliste, Karja, and Viru-internal connections remain distinct route bands rather than a rectangular street grid.
- Keep the western connector and wall/glacis edge visibly looser than the dense eastern ward. Outside-gate or wet-edge ground is open service, pasture, ditch, or road space, not a second merchant frontage.
- Use compressed medieval strip and square plots as a production abstraction. The 7-11 m frontage median from H04 is not a universal South Quarter rule; artisan, institutional, edge, and service plots may be shorter, wider, or irregular.
- Keep wall and route openings tied to stable IDs. Do not solve density by widening buildings over `inspection_spawn`, `rataskaev_well`, `karja_approach`, transitions, or patrol corridors.

### Dense eastern ward and service plots

The eastern ward is the density anchor: frequent street-facing buildings, rear courts, service sheds, stable work, and short lane connections. It must read as lived-in without becoming a blanket roof field.

Required authoring treatment:

- ordinary timber, plank, plastered-timber, and selective limestone/cellar fabric;
- rear **service plots** with wattle/timber boundaries, lean-tos, privies, fuel, stable, smithing, and storage cues;
- open courts and work yards that are intentionally owned open space rather than unexplained empty cells;
- no repeated limestone “knights compound” and no ordinary building scaled to landmark height;
- service plots remain view-only dressing and must not block routes, anchors, transitions, or patrol points.

### Knights' complex scale

The Knights' complex is a restrained functional cluster for court, lodging, stable, armour, and chapter/service activity. The reviewed evidence does **not** establish dedicated 14th-century “knights' quarters” or a barracks plan; the legacy scene note instead describes distributed wall defence. Therefore:

- `knights_hall`, `knights_dormitory`, `knights_stable`, `niguliste_chapter_house`, and their service yards are composite production anchors, not attested room plans;
- the cluster may be locally more substantial than ordinary houses, but must remain subordinate to the wall and gate system;
- use selective limestone or institutional detail, not a repeated all-stone compound or later Order-convent silhouette;
- the art pass must distinguish the complex by arrangement, yard function, banner/armour cues, and silhouette at gameplay scale, not by simply enlarging a house kit.

### Rataskaev well uncertainty

Rataskaev is a required gameplay-scale water-source placeholder, but the reviewed source record first mentions the named wheel well in 1375. A 1343 well at this exact anchor is therefore **U**, not attested. The contract freezes the following reversible decision:

- retain stable IDs `rataskaev_well_prop`, `rataskaev_well`, `rataskaev_well_wash`, and `rataskaev_well_buckets` for route and review continuity;
- present a generic, period-safe water-source/well treatment until a dated review changes the claim;
- do not describe the exact 1343 location, wheel mechanism, water spirit, or later folklore as historical fact;
- future day/night evidence must label the feature as `uncertain_1343_water_source`, not as a proven 1375 landmark.

### Karja and Harju construction-state walls

`cattle_gate` / Karja and `harju_gate` remain **construction candidates** for 1343, not completed tower interiors or later finished silhouettes. The authored positions may use reversible masonry, low wall, earth, or construction-state cues when supported by the later implementation tasks.

- Preserve stable positions `karja_gate_west_tower`, `karja_gate_east_tower`, and the existing Karja wall IDs.
- Keep `karja_gate_arch` as the named gate landmark and retain the walkable causeway/opening.
- The required renderer affordance is `karja_gate_arch/GateDoor0`; it is a downstream R-678 deliverable and is not marked present by this contract.
- Do not add a mature barbican, foregate, finished later tower roof, or a completed Harju/Karja tower interior.
- The south wall may read as an irregular, stepped, partly unfinished defensive edge. It must not imply that the 1355/1373 circuit or later tower portfolio already existed in full.

## Composition and material thresholds

The enforceable South Quarter card is intentionally broad and must be audited against the compiled map after authoring work:

| Metric | Frozen target |
|---|---:|
| Built footprint inside wall | **40-55%** |
| Open space inside wall | **45-60%** |
| Built footprint outside wall/glacis | **10-25%** |
| Open space outside wall/glacis | **75-90%** |
| Stone / pebble / local paving | **25-40%** |
| Packed earth / dirt / mud / chips | **40-55%** |
| Grass / pasture / service vegetation | **15-30%** |
| Maximum cobblestone share | **40%** |
| Maximum repeated style share | **35%** |
| Minimum relief range | **0.3** audit units; exact cell-to-metre interpretation remains bounded reconstruction |
| Maximum unexplained empty region | **20,000 cells**, excluding explicitly owned wall, wet, route, glacis, and open-service reserves |

Road surfaces must follow a **primary/secondary balance**: cobble or pebble/stone belongs on King's Street, Karja approach, important gate throats, and selected institutional thresholds; packed earth, mud, sand, chips, and worn dirt dominate minor lanes, yards, and service plots. H10's early rubble/pebble road is not evidence for a district-wide limestone or cobble substrate.

### Vegetation, fences, drainage, and relief

- Inside-wall kitchen or fruit plots occupy **3-10%** of developable land; no formal ornamental garden or blanket glacis lawn.
- Outside-wall garden, field, or fallow use may occupy **10-25%**; meadow/pasture may occupy **20-40%**, with roads, wet ground, and moat/ditch kept separate.
- Use generic disturbed-ground herbs and grass inside, meadow grass plus reed/sedge and low scrub at wet edges, and rare enclosed fruit/herb planting. Exact species shares remain **U**.
- Wattle, timber fences, hedges, and service-building edges are the default. Limestone plot walls are selective, not ordinary fabric.
- Drainage follows the coastal-lowland fall toward wet defensive edges through localized open channels, ditches, soakage, and wells. Do not infer a city-wide covered sewer or copy later water-pipe infrastructure.
- Relief stays shallow and legible: gentle north-east/east fall, low wet depressions, and the authored Karja glacis/causeway. Do not import later urban accumulation as a 1343 hill or raise ordinary plots into monumental terraces.

## Historical exclusion lock

The following forms and claims are explicitly excluded from the Spring 1343 contract:

- a completed 1355/1373 fortification circuit presented as securely dated in 1343;
- later Karja/Viru barbicans, foregates, watermill compositions, or later timber water pipes treated as 1343 facts;
- `saunatorn`, `nunnadetagune`, `loewenschede`, `koismae`, `epping`, `neitsitorn`, `kiek_in_de_kok`, and `fat_margaret` as completed 1343 tower silhouettes or interiors;
- a finished monumental Order convent, palace, Gothic merchant frontage, or repeated limestone knights compound;
- a proven 1343 Rataskaev named wheel well or its later folklore as canon evidence;
- formal glacis landscaping, blanket cobblestone, universal tile roofs, and modern tourist reconstructions;
- any later monumental form used to make an ordinary South Quarter house read as exceptional.

The stable map IDs remain technical interfaces. Excluding a historical form does not authorize renaming, deleting, or silently replacing a stable ID; later tasks must use reversible state or a scoped registry decision.

## Required anchors, landmarks, and affordances

### Stable anchors

The current map/audit contract must preserve these required anchors:

- `inspection_spawn`
- `rataskaev_well`
- `karja_approach`

The route/seam follow-up must also keep these supporting route anchors available for review:

- `king_street_climb`
- `from_reval_center`
- `from_reval_east`
- `from_archbishops_garden`

### Landmark and exceptional review IDs

The contract requires the following named records to remain distinguishable without activating the map:

- `karja_gate_arch` - named gate landmark and causeway approach;
- `garden_descent_gate` - western connector gate landmark;
- `rataskaev_well_prop` - uncertain 1343 water-source placeholder;
- `knights_hall`, `knights_dormitory`, `knights_stable`, `niguliste_chapter_house` - restrained Knights' complex cluster;
- `karja_gate_west_tower`, `karja_gate_east_tower` - construction-state gate positions, not completed later towers;
- `karja_gate_arch/GateDoor0` - required authored renderer affordance, currently **not present** and owned by R-678.

## Population and activity profile contract

South Quarter is urban, so the eventual activation gate must bind deterministic profile records without mutating generic `GameState` semantics. R-679 owns runtime placement. This contract reserves the following IDs:

- population profiles: `day`, `market_day`, `night`, `crackdown`;
- activity profiles: `knights_watch`, `stable_service`, `craftsmen`, `residents`, `gate_road`;
- required authored activity anchors: `karja_approach`, `knights_hall`, `knights_stable`, `swordsmith_row`, `rataskaev_well`.

The current activation manifest intentionally records empty `profile_ids` and `activity_profile_ids` with `population.status=BLOCKED`; listing the required IDs here is not an acceptance claim.

## Matched day/night evidence IDs

R-681 owns the gameplay-scale visual packet. Each row below is a stable evidence ID pair and framing key to be populated only by authored, non-blank, matched captures. No unsigned or unrelated image is promoted by this contract.

| Surface | Day evidence ID | Night evidence ID | Required framing key |
|---|---|---|---|
| Rataskaev well court | `p4_024.south.rataskaev_well.day` | `p4_024.south.rataskaev_well.night` | `south_rataskaev_well` |
| Western connector / garden seam | `p4_024.south.western_connector.day` | `p4_024.south.western_connector.night` | `south_western_connector` |
| Dense eastern ward | `p4_024.south.eastern_ward.day` | `p4_024.south.eastern_ward.night` | `south_dense_eastern_ward` |
| Knights' court and hall | `p4_024.south.knights_court.day` | `p4_024.south.knights_court.night` | `south_knights_court` |
| Stable and service plots | `p4_024.south.service_plots.day` | `p4_024.south.service_plots.night` | `south_service_plots` |
| Karja Gate and dry causeway | `p4_024.south.karja_gate.day` | `p4_024.south.karja_gate.night` | `south_karja_gate` |
| Civic/Workers' and south-wall seams | `p4_024.south.neighbor_seams.day` | `p4_024.south.neighbor_seams.night` | `south_neighbor_seams` |

Every pair must retain the same camera/framing key and map revision, identify visible stable IDs and historical confidence caveats, and remain separate from map-audit orthographic captures.

## P4-024 acceptance boundary matrix

| Acceptance boundary | Frozen contract requirement | Downstream owner |
|---|---|---|
| Historical source and confidence | H08-H10 notes, A/B/U labels, and dated exclusions remain visible in every implementation review. | R-675, Canon/Art review |
| Irregular lanes and seams | Rataskaev/Dunkri/King/Niguliste/Karja/Viru lanes and western/civic/east seams retain stable route IDs and irregular relief/surface bands. | R-676 |
| Dense eastern ward and ordinary fabric | 40-55% interior built target with mixed timber/plank/plaster/selected limestone; no repeated monumental houses. | R-677 |
| Service plots and district life | Rear yards, fences, stable/service labor, fuel, craft, and drainage cues are authored without blocking routes. | R-677, R-679 |
| Road-surface balance | 25-40% stone, 40-55% earth/mud/chips, 15-30% grass/service vegetation; cobble cap and repeated-style cap enforced. | R-676, R-682 |
| Vegetation and relief | Shallow coastal-lowland fall, wet margins, localized planting, and no formal glacis lawn. | R-676/R-677 |
| Rataskaev | Reversible generic water-source placeholder; no claim that the named 1375 well is attested in 1343. | R-678, Canon review |
| Knights' complex | Restrained functional cluster, distinct from ordinary houses and not a documented barracks or later Order compound. | R-677/R-678 |
| Karja/Harju fortifications | Construction-state candidates only; no later tower, barbican, watermill, or completed-circuit silhouette. | R-678, R-680 |
| Anchors, routes, collision, patrols | Required anchors and every authored seam/patrol remain reachable with stable transitions and inactive gating. | R-680 |
| Landmark affordance | `karja_gate_arch` remains required; `GateDoor0` must be authored and verified before activation, but is not present now. | R-678/R-682 |
| Population/activity | Four context profiles and South-specific activity IDs bind only to walkable authored anchors and deterministic caps. | R-679/R-682 |
| Day/night evidence | Seven matched gameplay-scale pairs cover routes, ward, service plots, Knights' court, well, gate, causeway, and seams. | R-681/R-682 |
| Activation | `implementation_delivered=false`, current verdict `RED/BLOCKED`, and RRMap `active=false` remain until every independent gate is green. | R-682/R-683 |

## Machine-readable contract links

- Composition thresholds: [`../data/map_composition_thresholds.json#maps.south_quarter`](../data/map_composition_thresholds.json)
- Location activation ledger: [`../data/location_activation_manifest.json`](../data/location_activation_manifest.json)
- Map audit inventory: [`../../content/map_audit_manifest.json`](../../content/map_audit_manifest.json)
- Authored map source: [`../../content/maps/south_quarter.rrmap`](../../content/maps/south_quarter.rrmap)
- Focused contract/runtime checks: [`../../tests/godot/test_south_quarter_prototype_map.gd`](../../tests/godot/test_south_quarter_prototype_map.gd)

## Verification record

The contract gate is intentionally narrower than environment acceptance:

```bash
python3 -m json.tool docs/data/map_composition_thresholds.json >/dev/null
python3 -m json.tool docs/data/location_activation_manifest.json >/dev/null
python3 -m json.tool content/map_audit_manifest.json >/dev/null

export GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_south_quarter_prototype_map
```

The focused test proves the contract document, H08-H10 source labels, required evidence IDs, historical exclusion lock, enforced composition links, manifest blockers, stable anchor IDs, and `active=false`. It does not claim that P4-024 geometry, landmarks, population, gameplay, or visual evidence have passed.

## Handoff

- R-676 may author lane and surface bands only after consuming the thresholds and stable IDs here.
- R-677 may author ordinary fabric and service plots without turning the Knights' cluster into monumental housing.
- R-678 owns the exceptional landmark affordance and the `GateDoor0` boundary.
- R-679 owns South-specific deterministic population/activity records.
- R-680 owns routes, collision, navigation, patrols, reciprocal seams, and inactive guards.
- R-681 owns signed matched day/night evidence and human/art/canon review fields.
- R-682 owns the automated environment acceptance gate and must keep the candidate RED until all independent boundaries pass.
- R-683 owns independent parent closeout. No task in this contract changes `active=false`.
