# R-532 Lower Town ordinary-fabric verification

**Task:** R-532 / P0-101 ordinary-fabric verification
**Parent:** R-108 / P0-101
**Map:** `lower_town_slice` / Workers' District
**Verification date:** 2026-09-01
**Worktree:** shared worktree contains unrelated staged, modified, and untracked WIP. This report changes no runtime, asset, or map source.
**Decision:** **SOURCE/CONTRACT PASS; GAMEPLAY-SCALE ORDINARY-FABRIC ACCEPTANCE BLOCKED.**

## Decision boundary

The current authored source contains the expected ordinary-fabric inventory: 43 tiered houses in the closed R-003-derived tier set, the required wall and roof families, and view-only weathering hooks. The source inventory and the independent fallback/material-precedence contract are sufficient for a source/contract handoff.

The integrated Godot suites are not green in the current checkout. The RRMap parser reports unsupported `elevation_area` and `elevation_ramp` commands before `LowerTownSliceDefinition.create()` can construct the map. The resulting incomplete definition causes cascading map, route, navigation, gate, and tier assertions to fail. This is a parser/map compatibility blocker, not evidence that the authored ordinary-fabric counts are absent.

This report does not close gameplay-scale visual acceptance. The existing packet contains valid-looking matched day/night files, but its source revision does not match the current authored source and all stable-ID observation rows remain `not_reviewed`. The packet therefore cannot prove tier coexistence, route-scale facade repetition, material/roof readability, localized wear or repair readability, or landmark separation.

No numeric facade-repetition threshold is defined in the available R-003/P0-101 evidence. This report does not invent one or claim that an undefined threshold has been met.

## 1. Evidence matrix

| Check | Result | Evidence and boundary |
|---|---|---|
| Current authored source inventory | **PASS** | `content/maps/lower_town_slice.rrmap` has 91 authoring records: 53 houses, 36 walls, and 2 gate arches. Current source SHA-256 is `67d6593bac4fa26a2fcf60a7206bc2938023eaadda20da7e3c4051cb3c6ddc9e`. |
| 43 tiered ordinary houses audited | **PASS at source level** | The current source has 43 `house_tier` records: `merchant_stone=14`, `merchant_timber=14`, `craft_boda=15`. The 10 untiered houses are not counted as missing ordinary tiers. |
| Closed tier assignment | **PASS at source level** | Every tier token in the current source is one of the three closed R-003-derived values; no unknown tier value is present. |
| Required wall families | **PASS at source level** | The 43 tiered records resolve to `log=17`, `plaster=13`, `plank=7`, `limestone=5`, and one documented rare `brick` accent. This is an authored-source result, not a gameplay readability claim. |
| Required roof families | **PASS at source level** | The 43 tiered records resolve to `shingle=29`, `thatch=8`, and `tile=6`. The three R-003 roof bands are represented in source. |
| Per-tier material and roof distribution | **PASS at source level** | `merchant_stone`: plaster 5, plank 5, limestone 4; shingle 10, tile 4. `merchant_timber`: plaster 6, log 4, plank 2, brick 1, limestone 1; shingle 11, tile 2, thatch 1. `craft_boda`: log 13, plaster 2; shingle 8, thatch 7. |
| Authored weathering hooks | **PASS at source level** | Eleven view-only decals are authored in the current source, including `mud`, `wet_threshold`, `grime`, and `soot` entries at lines 301-311. Their gameplay and visual effect still require a runnable integrated check and human review. |
| Fallback/material precedence contract | **PASS, isolated method** | `test_tier_fallback_and_authored_material_precedence_are_deterministic` passes in the tier log. This method does not require the Lower Town RRMap to parse successfully. |
| Integrated Lower Town map contract | **BLOCKED** | The focused map suite reports 19 tests, 26 failures, and 93 errors after parser diagnostics interrupt map construction. The saved log is `/tmp/r532_lower_town_logs/r532-lower-town-map.log`. |
| Integrated ordinary-tier contract | **BLOCKED** | The focused tier suite reports 5 tests, 92 failures, and 12 errors. The target 43-house method is interrupted by the same parser diagnostics; the isolated fallback method is the only reported PASS. The saved log is `/tmp/r532_lower_town_logs/r532-burgher-house-tiers.log`. |
| Capture packet file integrity | **PASS for packet integrity only** | Ten PNG outputs exist as five matched day/night pairs. Direct file inspection confirms `1280x720` RGBA, non-flat image data, and matching framing keys within each pair. This does not establish current-source or visual acceptance. |
| Capture source identity | **BLOCKED / mismatch** | The manifest records source SHA `6ae0b82a0a46a7391cb5db5a0bb02e562756def8073fe08cf63beebd7ace7e50` and compiled fingerprint `13525325b3d8be840c79d8c709c8aab12632bc6092a7123bc6d9275ba51d17ba`; neither is the current RRMap source SHA/fingerprint recorded above. |
| Stable-ID visual observations | **BLOCKED** | All five manifest coverage rows have empty `stable_ids` and status `not_reviewed` for both day and night. No named reviewer annotation promotes route candidates to accepted observations. |
| Repaired-state readability | **BLOCKED** | Authored decals and weathering variants are not gameplay-scale visual evidence. No reviewed day/night frame identifies a visible stable ID and a readable wear/repair state. Owner: R-487 with capture/review support from R-536/R-561. |
| Facade repetition threshold | **BLOCKED** | No documented numeric threshold is available, and no reviewed stable-ID route observation exists. Do not waive or infer this gate. Owner: R-487/R-536. |
| Gameplay-scale ordinary-fabric acceptance | **BLOCKED** | Source inventory is present, but integrated parser compatibility, current-source packet identity, stable-ID review, and human gameplay-scale visual review remain unresolved. |

## 2. Current source reconciliation

The live authored source used for this verification is:

- [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap)
- SHA-256: `67d6593bac4fa26a2fcf60a7206bc2938023eaadda20da7e3c4051cb3c6ddc9e`
- 91 authoring records: 53 houses, 36 walls, 2 gate arches
- 43 tiered houses: 14 `merchant_stone`, 14 `merchant_timber`, 15 `craft_boda`
- 10 untiered houses and 11 view-only decals

The tiered house records are in the current source around lines 176-229. The tiered styles resolve to the following source distributions:

| Tier | Count | Wall materials | Roof materials |
|---|---:|---|---|
| `merchant_stone` | 14 | plaster 5, plank 5, limestone 4 | shingle 10, tile 4 |
| `merchant_timber` | 14 | plaster 6, log 4, plank 2, brick 1, limestone 1 | shingle 11, tile 2, thatch 1 |
| `craft_boda` | 15 | log 13, plaster 2 | shingle 8, thatch 7 |

The 10 untiered houses are special or use-site records and are not silently converted into ordinary tiers by this report. Older R-612 material that refers to 51 tiered houses or eight rear-workshop additions describes a different source revision and is not used as current evidence here.

The R-003 review criteria remain authoring criteria, not gameplay-scale proof:

- gable to street with ridge perpendicular to the lane;
- merchant houses generally 2-3 storeys and `craft_boda` 1-2 storeys;
- stone/tile bias for affluent merchant masses;
- timber/plaster with shingle bias for ordinary merchant and craft frontage;
- log/thatch or shingle bias at the craft edge;
- no universal tiling, no late-Gothic tourist facade default, and no merchant hoist treatment on `craft_boda`.

## 3. Capture packet reconciliation

The authoritative packet is [`capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json). It declares:

- schema `r-560-lower-town-p0-101-capture-v1`;
- map ID `lower_town_slice`;
- renderer `gl_compatibility`, driver `opengl3`;
- viewport `[1280, 720]` and gameplay orthographic size `33.75`;
- pitch `-30`, yaw `45`;
- ten outputs in five matched day/night pairs;
- manifest source SHA `6ae0b82a0a46a7391cb5db5a0bb02e562756def8073fe08cf63beebd7ace7e50`;
- compiled map fingerprint `13525325b3d8be840c79d8c709c8aab12632bc6092a7123bc6d9275ba51d17ba`.

The five matched pairs are:

| Preset | Outputs |
|---|---|
| `market_primary_spine` | `market_primary_spine_day.png`, `market_primary_spine_night.png` |
| `merchant_craft_lane` | `merchant_craft_lane_day.png`, `merchant_craft_lane_night.png` |
| `service_yard` | `service_yard_day.png`, `service_yard_night.png` |
| `eastern_artisan_wet_margin` | `eastern_artisan_wet_margin_day.png`, `eastern_artisan_wet_margin_night.png` |
| `landmark_approaches` | `landmark_approaches_day.png`, `landmark_approaches_night.png` |

Each pair has the same `framing_key`, and direct PNG inspection found all ten files present, decodable, `1280x720`, RGBA, and non-blank. Those are packet-integrity facts only.

The manifest's `stable_id_observation_coverage` has five rows. For every preset, both `day` and `night` contain `stable_ids: []` and `status: "not_reviewed"`. `stable_id_candidates` and route anchors are planning metadata; they are not accepted visual observations. The packet also explicitly describes its source as a shared-worktree revision, so it cannot be silently relabeled as current-source evidence after the SHA mismatch above.

## 4. Reproducible verification

Both focused commands were run from the project root with Godot 4.7.1 and the checked runner. The harness filter is passed after the standalone `--` so the test harness receives it:

```bash
export GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"

./tools/run_godot_checked.sh --require-test-summary \
  r532_lower_town_map -- \
  "$GODOT_BIN" --headless --path . \
  --script res://tools/run_godot_tests.gd -- \
  --filter=test_lower_town_slice_map

./tools/run_godot_checked.sh --require-test-summary \
  r532_burgher_house_tiers -- \
  "$GODOT_BIN" --headless --path . \
  --script res://tools/run_godot_tests.gd -- \
  --filter=test_burgher_house_tiers
```

Observed checked-runner summaries:

```text
test_lower_town_slice_map       1 file, 19 tests, 26 failures, 93 errors
test_burgher_house_tiers        1 file, 5 tests, 92 failures, 12 errors
```

The tier log also records:

```text
PASS test_tier_fallback_and_authored_material_precedence_are_deterministic
```

### Parser diagnostics

The first repeated diagnostics in both logs are:

```text
res://content/maps/lower_town_slice.rrmap:14:1: error[unknown_command]: unknown command 'elevation_area'
res://content/maps/lower_town_slice.rrmap:17:1: error[unknown_command]: unknown command 'elevation_ramp'
res://content/maps/lower_town_slice.rrmap:20:1: error[unknown_command]: unknown command 'elevation_area'
res://content/maps/lower_town_slice.rrmap:22:1: error[unknown_command]: unknown command 'elevation_area'
```

The parser then emits the cascading definition failure:

```text
Invalid map definition : map_id is required, size_cells must be positive, player_spawn must be set, location is required, scope is required, palette is required, fingerprint is required
```

The tier suite consequently reports missing authored house records and missing aggregate wall/roof/weathering variation in its map-dependent method. Those failures follow the incomplete `LowerTownSliceDefinition.create()` result; they must not be reinterpreted as proof that the current source has zero tiered houses. The unsupported RRMap command compatibility issue is outside this verification-only report and requires a separate map/parser owner.

### What was and was not proven

The source audit proves that the current RRMap text contains the expected counts, closed tier values, material/roof families, and decals. The isolated fallback/material-precedence method proves that the deterministic fallback rule can run independently.

The failed integrated suites do not prove route endpoints, navigation, gate openings, parity, smithy approach, or runtime tier construction in this checkout. No gameplay-scale camera capture or human visual review was performed by this verification. The PNG packet's existence and non-blank pixels do not substitute for either.

## 5. Remaining blockers and ownership

1. **RRMap elevation-command/parser compatibility:** provide a separate Dev/Map follow-up for `elevation_area` and `elevation_ramp` support or an approved source compatibility decision. Re-run both focused suites after the parser can construct the map; do not repair runtime or map source under R-532.
2. **Current-source matched day/night packet:** R-536/R-561 must provide a packet generated from the current RRMap source and record the current source SHA/fingerprint. Preserve the five-pair route coverage only if its framing and source identity are re-established.
3. **Stable-ID gameplay review:** annotate visible stable IDs separately for day and night, then record tier, material, roof, localized wear/repair, repetition, and landmark-separation observations. Candidate IDs and route anchors alone are insufficient.
4. **Ordinary frontage variation and wear review:** R-487 must review the current-source gameplay frames against the R-003 decisions. No undocumented facade-repetition threshold may be inferred.
5. **Visual closeout:** R-532 can move from source/contract verification to final ordinary-fabric acceptance only after the parser blocker is resolved, current-source plates are reviewed, and named human art/canon observations are recorded.

## Linked evidence

- [`lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md) - source inventory and ordinary-fabric ID list; reconcile its revision before treating historical counts as current.
- [`lower_town_p0_101_acceptance.md`](lower_town_p0_101_acceptance.md) - P0-101 clause matrix and blocked closeout.
- [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md) - required matched gameplay-scale day/night packet and stable-ID review contract.
- [`capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json) - existing ten-output packet and explicit `not_reviewed` stable-ID coverage.
- [`burgher_house_typology_contract.md`](burgher_house_typology_contract.md) - closed tier, roof, massing, and rejection contract.
- [`burgher_house_art_signoff.md`](burgher_house_art_signoff.md) - conditional art-direction decision and missing final gameplay review.
- [`lower_town_p0_101_runtime_qa.md`](lower_town_p0_101_runtime_qa.md) - route/runtime boundary and independent runtime blockers.
- [`burgher-house-plan.md`](../../history/dossiers/architecture/burgher-house-plan.md) - R-003 Spring 1343 source dossier and decisions.
- [`lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap) - current authored source records, styles, transitions, and decals.

## Verification artifacts

- `/tmp/r532_lower_town_logs/r532-lower-town-map.log` - checked-runner map-suite log.
- `/tmp/r532_lower_town_logs/r532-burgher-house-tiers.log` - checked-runner tier-suite log.
