# R-616 Lower Town gameplay-scale day/night evidence verification

**Task:** R-616 / P0-101 decomposition: verify gameplay-scale day/night evidence
**Parent:** R-108 / P0-101
**Verification date:** 2026-08-21
**Map:** `lower_town_slice` / Workers' District
**Checkout:** `94ae942a`, shared worktree with unrelated modified, staged, and untracked WIP
**Decision:** **PACKET INTEGRITY PASS; SOURCE/INVENTORY RECONCILED; P0-101 VISUAL ACCEPTANCE BLOCKED.**

## Scope and decision rule

This is a verification-only audit. It does not recapture or modify PNGs, camera presets, map content, runtime code, budgets, or human-review records. A visual acceptance row is **PASS** only when a matched gameplay-scale day/night pair identifies the authored stable ID(s), records the requested observation, and has the required review status. A valid non-blank route crop with only route-anchor metadata remains **BLOCKED** for surface acceptance.

The audit reconciles the current R-560 packet, R-536 packet-integrity result, R-561's earlier evidence decision, the current capture matrix, and the authored RRMap/inventory boundary. The repository contains the current R-561 artifact as [`r561_lower_town_gameplay_evidence_audit.md`](r561_lower_town_gameplay_evidence_audit.md); a filename such as `r561_lower_town_gameplay_capture_audit.md` is not present and is not cited as evidence.

## Board and artifact snapshot

| Item | Current state | Acceptance meaning |
|---|---|---|
| R-108 / P0-101 | `todo` | Parent remains open; no partial visual evidence may close it. |
| R-491 / P0-101f | `in_review` | Capture contract and production packet handoff exist, but visual review remains open. |
| R-536 | `done` | Prior packet audit passed file integrity and explicitly kept surface acceptance blocked. |
| R-560 | `in_progress` | Current five-preset packet is present in the shared worktree but its producing task is not closed. |
| R-561 | `in_review` | Earlier evidence audit passed packet integrity and blocked stable-ID visual acceptance. |
| R-616 | `in_progress` at audit start | This report provides the independent current-checkout decision. |

## Capture contract and packet integrity

The authoritative current manifest is [`images/lower_town_p0_101/capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json). Its required metadata is present:

| Field | Observed value | Result |
|---|---|---|
| Schema / source task | `r-560-lower-town-p0-101-capture-v1` / `R-560 / P0-101f` | **PASS** |
| Map identity | `lower_town_slice` | **PASS** |
| Map revision | `lower_town_slice.rrmap authored source (shared worktree; record HEAD separately)` | **PASS with dirty-worktree boundary** |
| Authored map fingerprint | `13525325b3d8be840c79d8c709c8aab12632bc6092a7123bc6d9275ba51d17ba` | **PASS** |
| Renderer | `gl_compatibility`, capture command specifies `opengl3` | **PASS** |
| Viewport | `1280x720` | **PASS** |
| Gameplay camera | orthographic size `33.75`, pitch `-30`, yaw `45`, focus height `0.8` | **PASS** |
| Time coverage | five `day` and five `night` plates | **PASS** |
| Matched framing | one equal `framing_key` for each preset's day/night pair | **PASS** |
| Output files | ten PNGs, all present, valid PNG signature, `1280x720`, non-zero payload | **PASS** |
| Stable-ID visual observations | no visible building, landmark, material, roof, wear, or reviewer annotations in plate metadata | **BLOCKED** |

### Current matched packet inventory

All rows below are route or approach candidates. They are not promoted to stable-ID visual acceptance because the manifest records anchors and interaction targets, not visible authored building IDs.

| Preset | Route anchors | Day plate | Night plate | Pair result |
|---|---|---|---|---|
| `market_primary_spine` | `vene_street_north` -> `checkpoint_west` | [`market_primary_spine_day.png`](images/lower_town_p0_101/market_primary_spine_day.png) | [`market_primary_spine_night.png`](images/lower_town_p0_101/market_primary_spine_night.png) | **PASS - matched, 1280x720, non-blank** |
| `merchant_craft_lane` | `checkpoint_west` -> `brewery_door` | [`merchant_craft_lane_day.png`](images/lower_town_p0_101/merchant_craft_lane_day.png) | [`merchant_craft_lane_night.png`](images/lower_town_p0_101/merchant_craft_lane_night.png) | **PASS - matched, 1280x720, non-blank** |
| `service_yard` | `brewery_door` -> `smithy_door` | [`service_yard_day.png`](images/lower_town_p0_101/service_yard_day.png) | [`service_yard_night.png`](images/lower_town_p0_101/service_yard_night.png) | **PASS - matched, 1280x720, non-blank** |
| `eastern_artisan_wet_margin` | `checkpoint_east` -> `karja_gate_south` | [`eastern_artisan_wet_margin_day.png`](images/lower_town_p0_101/eastern_artisan_wet_margin_day.png) | [`eastern_artisan_wet_margin_night.png`](images/lower_town_p0_101/eastern_artisan_wet_margin_night.png) | **PASS - matched, 1280x720, non-blank** |
| `landmark_approaches` | `checkpoint_west` -> `checkpoint_east` | [`landmark_approaches_day.png`](images/lower_town_p0_101/landmark_approaches_day.png) | [`landmark_approaches_night.png`](images/lower_town_p0_101/landmark_approaches_night.png) | **PASS - matched, 1280x720, non-blank** |

**Packet result:** **PASS for 5/5 matched route pairs and 10/10 image files.** This is packet integrity only, not P0-101 art acceptance.

## Source and inventory reconciliation

The current authored source is now reconciled with the evidence audit:

- `content/maps/lower_town_slice.rrmap` contains **99 unique records**: 61 `house`, 36 `wall`, and 2 `gate_arch` records.
- The current source has **51 tiered houses**: `merchant_stone=14`, `merchant_timber=14`, and `craft_boda=23`.
- The prior R-486 inventory and capture matrix covered 91 records and 15 craft-boda houses. The eight R-547 rear-workshop records are now listed in the inventory delta at source lines 234-241, but the existing packet fingerprint predates them and no plate metadata identifies them visually.
- The current RRMap SHA-256 is `6ae0b82a0a46a7391cb5db5a0bb02e562756def8073fe08cf63beebd7ace7e50`; the packet manifest's authored-map fingerprint remains a separate older snapshot.

| Current source ID | RRMap line | Acceptance effect |
|---|---:|---|
| `saddlers_rear_workshop` | 234 | Missing from prior inventory/matrix; no visual evidence. |
| `coopers_rear_workshop` | 235 | Missing from prior inventory/matrix; no visual evidence. |
| `sauna_rear_boda` | 236 | Missing from prior inventory/matrix; no visual evidence. |
| `rope_makers_rear_store` | 237 | Missing from prior inventory/matrix; no visual evidence. |
| `karja_rear_boda` | 238 | Missing from prior inventory/matrix; no visual evidence. |
| `brewery_rear_store` | 239 | Missing from prior inventory/matrix; no visual evidence. |
| `smithy_rear_shed` | 240 | Missing from prior inventory/matrix; no visual evidence. |
| `carriers_barn` | 241 | Missing from prior inventory/matrix; no visual evidence. |

This revision drift is now reconciled in the source inventory, but it remains a coverage blocker, not a reason to infer acceptance from the source. The eight records require a future matched capture/review that identifies each stable ID in both day and night evidence.

## R-108 visual coverage matrix

`Candidate pair` means the best current route context only. It does not mean that the referenced surface is visible, stable-ID linked, or reviewed.

| R-108 visual clause | Day evidence | Night evidence | Verdict | Exact blocker / owner |
|---|---|---|---|---|
| Representative `merchant_stone` frontage and silhouette | `market_primary_spine_day.png`; `merchant_craft_lane_day.png` as route candidates | Matching `_night.png` plates | **BLOCKED** | No visible stable house ID or tier observation. Ordinary-fabric owner R-487/R-532 must annotate a visible record. |
| Representative `merchant_timber` frontage and silhouette | `market_primary_spine_day.png`; `merchant_craft_lane_day.png` as route candidates | Matching `_night.png` plates | **BLOCKED** | Route metadata does not identify a visible `merchant_timber` record or prove its silhouette. Owner R-487/R-532. |
| Representative `craft_boda` frontage and silhouette, including current rear-workshop additions | `merchant_craft_lane_day.png`; `eastern_artisan_wet_margin_day.png` as route candidates | Matching `_night.png` plates | **BLOCKED** | No stable-ID observation proves compact workshop-dwelling massing, no merchant hoist treatment, or coverage of the eight new IDs. Owner R-487/R-532 with source/matrix reconciliation. |
| Repeated frontage and material variation | `market_primary_spine_day.png`; `merchant_craft_lane_day.png`; `eastern_artisan_wet_margin_day.png` | Matching night candidates | **BLOCKED** | Valid crops do not encode visible runs, repetition threshold, or per-surface review. Owner R-487/R-532. |
| Log / plank / plaster / limestone wall families | Ordinary-frontage day candidates; source inventory is not visual evidence | Matching night candidates | **BLOCKED** | No material-family observation tied to visible stable IDs. Owner R-487/R-532. |
| Tile / shingle / thatch roof covers | Ordinary-frontage day candidates | Matching night candidates | **BLOCKED** | No roof-family annotation and no night readability review. Owner R-487/R-532. |
| Localized wear and repaired states | `service_yard_day.png`; `eastern_artisan_wet_margin_day.png` | Matching night candidates | **BLOCKED** | Non-blank pixels do not prove mud, wet, grime, soot, or repairs read at gameplay scale. Owner R-487/R-532. |
| Special/use-site buildings and route-scale separation from ordinary houses | `service_yard_day.png`; `landmark_approaches_day.png` as route candidates | Matching night candidates | **BLOCKED** | The packet does not identify all nine prior special/use-site records or current source additions, and does not prove exceptional silhouettes. Owners R-488/R-489/R-533. |
| St. Catherine's church (`st_catherines_church`) | No church-specific day approach metadata; `landmark_approaches_day.png` is route context only | No church-specific night approach metadata; matching route context only | **BLOCKED** | No stable-ID approach observation, dated 1343 silhouette review, or named approval. Owners R-488/R-492/R-537. |
| Inner Viru Gate: towers, jambs, and view-only arch | `landmark_approaches_day.png` | `landmark_approaches_night.png` | **BLOCKED** | Gate intent exists, but `viru_gate_north_tower`, `viru_gate_south_tower`, both jambs, and `viru_gate_arch` are not observed by stable ID or reviewed for opening/arch relationship. Owners R-488/R-492/R-533. |
| Viru foregate: walls, towers, jambs, and view-only arch | `landmark_approaches_day.png` | `landmark_approaches_night.png` | **BLOCKED** | Current route pair does not separate foregate IDs from the inner gate or document the incomplete 1343 state and oak arch. Owners R-488/R-492/R-533. |
| Remaining fortification, precinct walls, and smithy fences | `landmark_approaches_day.png`; `service_yard_day.png` as context | Matching night candidates | **BLOCKED** | No per-wall stable-ID, wall-walk, sealed-join, precinct-boundary, or fence observation. Owner R-488/R-533. |
| Matched gameplay-scale route and landmark-approach reproducibility | All five day plates | All five night plates | **PASS for packet integrity only** | Manifest/file audit and focused contract are green. This PASS does not waive any blocked surface row. |

## Verification commands and observed output

### Independent manifest and PNG audit

```text
schema=r-560-lower-town-p0-101-capture-v1
map=lower_town_slice
renderer=gl_compatibility
viewport=[1280.0, 720.0]
plates=10
times={'day': 5, 'night': 5}
framing_pairs=5
missing_or_invalid=0
```

The audit checked every manifest output path, PNG signature, IHDR dimensions, payload size, required top-level fields, required per-plate fields, one day/night row per preset, and equal framing keys per pair.

### Focused capture contract

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_capture_lower_town_p0_101
```

Observed:

```text
Godot headless tests: 1 file(s), 5 test(s), 0 failure(s), 0 error(s).
```

Godot emitted the known shutdown-only `ObjectDB instances were leaked` and `resources still in use` diagnostics after the green summary. They do not invalidate PNG integrity, but they are retained as a runtime limitation and do not waive the visual blockers.

### Reproduction command recorded by the packet

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
  --script tools/capture_lower_town_p0_101.gd
```

This R-616 session did not claim a fresh non-headless rerender. The existing current-worktree packet was independently checked in place.

## Final disposition

**R-616 verification result: BLOCKED for P0-101 visual acceptance, complete as a packet audit.**

What passes:

- current manifest identifies the production map, source task, fingerprint, renderer, viewport, camera, times, and output paths;
- ten PNGs exist and decode as `1280x720`;
- five day/night pairs share deterministic framing metadata;
- focused capture contract passes 5/5;
- route and landmark-approach packet integrity is independently reproducible from the current shared checkout metadata.

What remains blocked:

- all three ordinary tiers and the eight current rear-workshop IDs lack stable-ID visual observations;
- material, roof, wear, and repeated-frontage review is absent;
- special/use-site buildings, St. Catherine's, inner Viru Gate, foregate, wall/precinct surfaces, and smithy fences lack per-ID observations;
- no named canon/art reviewer status is attached to these visual rows;
- the current 99-record source and eight rear-workshop IDs are reconciled into the inventory/matrix, but the older packet fingerprint remains explicitly separate and does not prove those additions visually;
- R-560 remains `in_progress`, so the packet is current shared-worktree evidence rather than a clean completed handoff.

Keep R-108/P0-101 open. Existing owners R-487/R-488/R-489/R-492/R-532/R-533 and the R-560/R-561 handoff are sufficient; no duplicate follow-up task is created by this audit.

## Sources

- [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md)
- [`lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md)
- [`r536_lower_town_day_night_capture_verification.md`](r536_lower_town_day_night_capture_verification.md)
- [`r561_lower_town_gameplay_evidence_audit.md`](r561_lower_town_gameplay_evidence_audit.md)
- [`r588_lower_town_gameplay_packet_audit.md`](r588_lower_town_gameplay_packet_audit.md)
- [`r592_p0_101_final_acceptance_verification.md`](r592_p0_101_final_acceptance_verification.md)
- [`capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json)
- [`tools/capture_lower_town_p0_101.gd`](../../tools/capture_lower_town_p0_101.gd)
- [`tests/godot/test_capture_lower_town_p0_101.gd`](../../tests/godot/test_capture_lower_town_p0_101.gd)
- [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap), current authored source and R-547 delta at lines 234-241
