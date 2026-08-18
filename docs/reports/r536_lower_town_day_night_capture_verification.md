# R-536 Lower Town day/night capture verification

**Task:** R-536 / P0-101 day/night capture verification
**Parent:** R-108 / P0-101
**Verification date:** 2026-08-18
**Map:** `lower_town_slice` / Workers' District
**Checkout:** `ef80c4fc` (`main`), shared worktree dirty with unrelated WIP
**Decision:** **PACKET INTEGRITY PASS; SURFACE-BY-SURFACE VISUAL ACCEPTANCE BLOCKED.**

## Scope and decision boundary

This report audits the dedicated gameplay-scale packet required by the R-491 capture matrix. It verifies that the existing outputs are present, decodable, non-blank, matched by deterministic framing metadata, and tied to the integrated `lower_town_slice` capture runner. It does not promote route crops into proof of a house tier, material, roof, wear state, special building, fortification, or historical silhouette when the current metadata does not identify that surface.

The packet is therefore usable evidence for capture capability, route framing, and day/night reproducibility. It is not a substitute for R-532 ordinary-fabric review, R-533 landmark-boundary review, R-534 route-integration handoff, or R-537 historical/art sign-off.

## Packet integrity checks

| Check | Result | Evidence |
|---|---|---|
| Integrated map target | **PASS** | Manifest `map_id` is `lower_town_slice`; runner uses `LowerTownSlice.create()` and production route anchors. |
| Source revision and fingerprint | **PASS with dirty-worktree boundary** | Manifest records map fingerprint `e8cde197067d824d1efd46b399506f6d86158a506cd92bf5d6c6b5552f4209b2`; current checkout is `ef80c4fc`; manifest correctly notes that the authored source is from a shared dirty worktree. |
| Camera contract | **PASS** | Renderer is `gl_compatibility`; camera is the production orthographic gameplay scale `33.75`, pitch `-30`, yaw `45`; every plate has route or landmark-approach intent and anchor midpoint metadata. |
| Day/night pairing | **PASS** | Four route presets each have one `day` and one `night` plate. Each pair shares its `framing_key`, focus logic cell, focus height, orthographic size, pitch, and yaw. |
| Output dimensions | **PASS** | All eight PNGs decode as `1280x720` RGBA images. |
| Non-blank output | **PASS** | All eight files have valid PNG signatures and non-zero payloads larger than 1 KiB; image extrema are not a single constant color. |
| Focused capture contract | **PASS** | `test_capture_lower_town_p0_101`: 1 file, 4 tests, 0 failures, 0 errors. Godot emitted only known shutdown ObjectDB/resource-leak diagnostics after the green summary. |
| Reproduction command | **PASS for packet contract; visual rerender not claimed here** | The manifest records the production command using `tools/capture_lower_town_p0_101.gd`; the focused test validates its deterministic packet definition and current outputs. A successful packet command does not itself establish per-surface visual readability. |

Independent packet check output:

```text
R536_PACKET_PASS plates=8 pairs=4 dimensions=1280x720 nonblank_payloads=8 matched_framing=4
manifest_sha256=b2e5c0acf9c87ac5eed0c0c2eb3fe6a2f98bfeed99615a16b215f7a460b600cf
```

## Capture inventory

The following four matched pairs are the complete dedicated packet. The same source task, map revision, camera contract, and renderer apply to every row.

| Source task | Map revision | Camera / intent | Renderer | Day plate | Night plate | Packet result |
|---|---|---|---|---|---|---|
| R-560 / P0-101f | `ef80c4fc` checkout; fingerprint `e8cde197...4209b2` | Gameplay orthographic `33.75`; pitch `-30`; yaw `45`; route-scale ordinary frontage; `street_start` -> `smithy_door` | `gl_compatibility` / `opengl3` | [`street_start_to_smithy_door_day.png`](images/lower_town_p0_101/street_start_to_smithy_door_day.png) | [`street_start_to_smithy_door_night.png`](images/lower_town_p0_101/street_start_to_smithy_door_night.png) | **PASS - matched, 1280x720, non-blank** |
| R-560 / P0-101f | `ef80c4fc` checkout; fingerprint `e8cde197...4209b2` | Gameplay orthographic `33.75`; pitch `-30`; yaw `45`; route-scale forge and brewery frontage; `smithy_door` -> `brewery_door` | `gl_compatibility` / `opengl3` | [`smithy_door_to_brewery_door_day.png`](images/lower_town_p0_101/smithy_door_to_brewery_door_day.png) | [`smithy_door_to_brewery_door_night.png`](images/lower_town_p0_101/smithy_door_to_brewery_door_night.png) | **PASS - matched, 1280x720, non-blank** |
| R-560 / P0-101f | `ef80c4fc` checkout; fingerprint `e8cde197...4209b2` | Gameplay orthographic `33.75`; pitch `-30`; yaw `45`; route-scale ordinary frontage toward gate; `brewery_door` -> `checkpoint_west` | `gl_compatibility` / `opengl3` | [`brewery_door_to_checkpoint_west_day.png`](images/lower_town_p0_101/brewery_door_to_checkpoint_west_day.png) | [`brewery_door_to_checkpoint_west_night.png`](images/lower_town_p0_101/brewery_door_to_checkpoint_west_night.png) | **PASS - matched, 1280x720, non-blank** |
| R-560 / P0-101f | `ef80c4fc` checkout; fingerprint `e8cde197...4209b2` | Gameplay orthographic `33.75`; pitch `-30`; yaw `45`; landmark approach and gate opening; `checkpoint_west` -> `checkpoint_east` | `gl_compatibility` / `opengl3` | [`checkpoint_west_to_checkpoint_east_day.png`](images/lower_town_p0_101/checkpoint_west_to_checkpoint_east_day.png) | [`checkpoint_west_to_checkpoint_east_night.png`](images/lower_town_p0_101/checkpoint_west_to_checkpoint_east_night.png) | **PASS - matched, 1280x720, non-blank** |

The authoritative metadata is [`capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json). Its schema is `r-560-lower-town-p0-101-capture-v1`; the map fingerprint field is named `map_fingerprint`.

## R-108 clause matrix

Every row below links the available day/night packet evidence and states the remaining owner when those route crops cannot prove the full clause. `PASS` means packet or structural evidence only, not final P0-101 art acceptance.

| R-108 visual clause / required coverage | Day evidence | Night evidence | Result | Owner / blocker |
|---|---|---|---|---|
| Representative `merchant_stone` frontage and tier silhouette | [`street_start_to_smithy_door_day.png`](images/lower_town_p0_101/street_start_to_smithy_door_day.png); [`brewery_door_to_checkpoint_west_day.png`](images/lower_town_p0_101/brewery_door_to_checkpoint_west_day.png) | Matching `_night.png` plates | **BLOCKED** - packet has ordinary-frontage intents but no stable house ID or tier annotation proving `merchant_stone` | R-532/R-487 must identify a visible authored house and record gameplay-scale tier/silhouette observations. |
| Representative `merchant_timber` frontage and tier silhouette | [`street_start_to_smithy_door_day.png`](images/lower_town_p0_101/street_start_to_smithy_door_day.png); [`brewery_door_to_checkpoint_west_day.png`](images/lower_town_p0_101/brewery_door_to_checkpoint_west_day.png) | Matching `_night.png` plates | **BLOCKED** - route metadata does not identify a `merchant_timber` record | R-532/R-487; add or annotate a matched route/approach crop after the authored frontage handoff. |
| Representative `craft_boda` frontage and tier silhouette | [`street_start_to_smithy_door_day.png`](images/lower_town_p0_101/street_start_to_smithy_door_day.png); [`brewery_door_to_checkpoint_west_day.png`](images/lower_town_p0_101/brewery_door_to_checkpoint_west_day.png) | Matching `_night.png` plates | **BLOCKED** - route metadata does not identify a `craft_boda` record | R-532/R-487; prove compact massing and no merchant hoist treatment in a matched pair. |
| Repeated frontage and material variation | All four day plates, especially the two ordinary-frontage routes | All four matching night plates | **BLOCKED** - packet integrity passes, but no per-surface review or documented repetition threshold is linked | R-532/R-487; do not infer a threshold from this packet. |
| Log, plank, plaster, and limestone wall families | Ordinary-frontage day plates listed above | Matching ordinary-frontage night plates | **BLOCKED** - source inventory proves authored families, not route-scale readability | R-532/R-487; annotate each observed family against stable IDs. |
| Tile, shingle, and thatch roof covers | Ordinary-frontage day plates listed above | Matching ordinary-frontage night plates | **BLOCKED** - no roof-family annotation and night readability review | R-532/R-487; capture or identify visible roof families without substituting source counts. |
| Localized wear and repaired details | [`smithy_door_to_brewery_door_day.png`](images/lower_town_p0_101/smithy_door_to_brewery_door_day.png); [`brewery_door_to_checkpoint_west_day.png`](images/lower_town_p0_101/brewery_door_to_checkpoint_west_day.png) | Matching `_night.png` plates | **BLOCKED** - non-blank pixels do not prove that mud, wet, grime, soot, or repairs read at gameplay scale | R-532/R-487; record observations for authored wear/decal IDs. |
| Special buildings and service/use-site context | [`smithy_door_to_brewery_door_day.png`](images/lower_town_p0_101/smithy_door_to_brewery_door_day.png); [`brewery_door_to_checkpoint_west_day.png`](images/lower_town_p0_101/brewery_door_to_checkpoint_west_day.png) | Matching `_night.png` plates | **BLOCKED** - route intents mention forge/brewery, but do not identify all nine special/use-site buildings or prove exceptional silhouettes | R-533/R-488/R-489; perform stable-ID route review for each required special building. |
| St. Catherine's church | No dedicated day plate in the current packet; checkpoint approach is only a candidate route frame | No dedicated night plate in the current packet; checkpoint approach is only a candidate route frame | **BLOCKED** - no stable `st_catherines_church` approach metadata or sign-off | R-533/R-492/R-537; capture a matched approach and obtain named canon/art review. |
| Inner Viru Gate 1343 state | [`checkpoint_west_to_checkpoint_east_day.png`](images/lower_town_p0_101/checkpoint_west_to_checkpoint_east_day.png) | [`checkpoint_west_to_checkpoint_east_night.png`](images/lower_town_p0_101/checkpoint_west_to_checkpoint_east_night.png) | **BLOCKED for visual acceptance; PASS for packet linkage** - pair is explicitly a gate-opening approach but does not annotate towers, jambs, or arch as observed | R-533/R-488/R-492; review the four inner-gate stable IDs and opening clearance. |
| Viru foregate 1343 state | Same checkpoint day plate as candidate approach | Same checkpoint night plate as candidate approach | **BLOCKED** - current preset reaches `checkpoint_east` but does not identify the foregate rows separately | R-533/R-488/R-492; provide foregate-specific stable-ID observations. |
| Remaining fortification and precinct walls | [`checkpoint_west_to_checkpoint_east_day.png`](images/lower_town_p0_101/checkpoint_west_to_checkpoint_east_day.png); other route day plates as context | Matching night plates | **BLOCKED** - no per-wall or wall-walk review is encoded | R-533/R-488/R-492; review city-wall, tower, sealed-join, monastery-wall, and smithy-fence IDs. |
| Route-scale proof that special buildings are not enlarged ordinary houses | Forge/brewery and checkpoint day candidate pairs | Matching night candidate pairs | **BLOCKED** - packet has route-scale framing but lacks per-building exceptional renderer observations | R-533/R-489/R-537; annotate exceptional registry outcomes and visual separation. |
| Matched day/night route and approach reproducibility | All four day plates | All four night plates | **PASS** | R-536 packet audit complete at file/metadata level; retain R-108 open for visual rows above. |

## Reproduction record

Focused contract command:

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --headless --path . \
  --script tools/run_godot_tests.gd -- \
  --filter=test_capture_lower_town_p0_101
```

Observed result:

```text
Godot headless tests: 1 file(s), 4 test(s), 0 failure(s), 0 error(s).
```

Independent PNG/manifest check:

```bash
python3 - <<'PY'
# Validate capture_manifest.json, PNG signatures, 1280x720 IHDR dimensions,
# non-zero payloads, and equal day/night framing keys for all four presets.
PY
```

The exact capture command recorded by the production runner is:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
  --script tools/capture_lower_town_p0_101.gd
```

The current audit does not claim a fresh non-headless rerender in this session. The existing packet and prior recorded command status are retained as evidence; the focused contract and independent file checks are the authoritative checks run for this report.

## Closeout decision and follow-up

**R-536 can move to `in_review`, not `done`.** The requested packet audit is complete and its integrity is green. The visual acceptance portion remains blocked because the current four route midpoint pairs do not provide stable-ID coverage for all three house tiers, every required material/roof/wear family, St. Catherine's, the inner gate, foregate, walls, special buildings, and named historical/art review.

No new follow-up task is created. Existing owners are sufficient:

- R-532/R-487: ordinary tiers, material/roof variation, repetition, and wear observations;
- R-533/R-488/R-492: special buildings, fortifications, St. Catherine's, and silhouette review;
- R-534/R-489: route integration and independent before/after handoff;
- R-537: named historical/art sign-off;
- R-108: final P0-101 acceptance after all blockers close.

## Sources

- [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md)
- [`capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json)
- [`tools/capture_lower_town_p0_101.gd`](../../tools/capture_lower_town_p0_101.gd)
- [`tests/godot/test_capture_lower_town_p0_101.gd`](../../tests/godot/test_capture_lower_town_p0_101.gd)
- [`r532_lower_town_ordinary_fabric_verification.md`](r532_lower_town_ordinary_fabric_verification.md)
- [`r533_lower_town_landmark_boundary_acceptance.md`](r533_lower_town_landmark_boundary_acceptance.md)
- [`r534_lower_town_route_integration_verification.md`](r534_lower_town_route_integration_verification.md)
- [`lower_town_p0_101_acceptance.md`](lower_town_p0_101_acceptance.md)
