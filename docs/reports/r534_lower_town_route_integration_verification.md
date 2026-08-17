# R-534 Lower Town route-integration verification

**Task:** R-534 / P0-101 route-integration verification
**Parent:** R-108 / P0-101
**Dependency:** R-489 / P0-101d, still `in_progress`
**Verification date:** 2026-08-18
**Snapshot:** `782ba009226c22802bf14045abed0d0c83cf2410`
**Worktree:** shared worktree contains unrelated staged, modified, and untracked WIP. This report is the only scoped change from this verification; no map, runtime, asset, fixture, or test source was edited.

## Decision

**AUTHORED/CONTRACT PARITY PASS; R-489 FINAL HANDOFF BLOCKED.**

The current Lower Town and Kalev Smithy authored contracts are green. The focused checks show no route, transition, collision, navigation, anchor, spawn, or art-only decal fingerprint regression in the checked snapshot. The reproducible route-scale capture packet is also valid and deterministic.

This does **not** close R-489 or promote the result to final art acceptance. The required independent R-489 before/after baseline reconciliation is not present in the checkout, and the capture packet does not provide a surface-by-surface visual occlusion review or human visual sign-off. Those remain explicit blockers rather than inferred failures.

## Scope and evidence boundary

This was a verification-only pass. It compares the current authored data with the canonical parity fixture and exercises the gameplay contracts that art integration must preserve. It does not regenerate the fixture, change stable IDs, alter collision or navigation, author art, or reinterpret route-scale images as visual approval.

The canonical fixture is a current-reference comparison, not an archived R-489 before snapshot. Therefore:

- **Proven:** current authored data equals the canonical gameplay parity fixture; view-only decals do not alter the generated gameplay terrain fingerprint; route and transition contracts pass.
- **Not proven:** an independent before/after comparison against the R-489 pre-integration baseline, or that every visible art surface is free of occlusion at gameplay scale.

## Acceptance matrix

| Requirement | Result | Evidence and limitation |
|---|---|---|
| Lower Town map validates and remains canonical | **PASS** | `test_lower_town_slice_map`: 19/19. `test_lower_town_slice_matches_canonical_parity_fixture` passes. The fixture contains 17 anchors, 89 buildings, 37 props, 7 transitions, 2 patrols, and 2 landmarks. |
| Required Lower Town route endpoints remain reachable | **PASS** | `street_start` reaches `smithy_door`, `brewery_door`, `checkpoint_west`, `checkpoint_east`, `katariina_kaik`, `monastery_gate`, `karja_gate_south`, and `vene_street_north`. Smithy entrance/facade attachment and courtyard apron checks also pass. |
| Viru Gate, wall, water, and navigation semantics remain safe | **PASS** | City-wall blocking and Viru causeway opening pass; gate route and navigation polygon connectivity pass; water cells remain outside navigation; player capsule clearance is preserved; view-only `viru_gate_arch` span matches collision jambs. |
| Art-only route dressing does not change gameplay fingerprints | **PASS at current-contract level** | Lower Town and Kalev Smithy decal tests build with and without authored decals and require equal terrain fingerprints. Lower Town also passes route-specific prop clearance and no-second-forge checks. This is invariance evidence, not an R-489 archived before/after hash. |
| Kalev Smithy interior route and collision contracts remain intact | **PASS** | `test_kalev_smithy_map`: 16/16. New-game spawn, `anvil`/`ledger`/`bed_alcove` anchors, courtyard door, work triangle, domestic/forge separation, protected routes, full terrain coverage, and `collision_parity` pass. |
| Transition manifest and stable spawns remain resolvable | **PASS** | `test_transition_manifest`: 3/3. Release scene IDs, development traversal scenes, scene paths, and stable spawns including Lower Town `street_start`/`forge` and forge `smithy_start` resolve as expected. |
| RRMap conversion/parity accounting remains consistent | **PASS** | `python3 tools/verify_map_conversion_parity.py` passes: Lower Town anchor accounting 11/11 and Kalev Smithy anchor accounting 3/3; both focused Godot filters are green. |
| Route-scale capture packet is reproducible and non-blank | **PASS for packet contract** | `test_capture_lower_town_p0_101`: 4/4. Manifest records eight 1280x720 matched day/night plates across four deterministic route presets, gameplay orthographic size 33.75, camera pitch/yaw, anchor pairs, and fingerprint `e8cde197067d824d1efd46b399506f6d86158a506cd92bf5d6c6b5552f4209b2`. This proves packet validity, not visual sign-off. |
| Independent R-489 before/after baseline reconciliation | **BLOCKED** | No archived R-489 baseline report, hash ledger, or before packet was found in the checkout. The current canonical fixture and current capture fingerprint cannot establish what changed before versus after art integration. |
| Surface-by-surface visual occlusion and final art handoff | **BLOCKED** | Existing capture matrix marks ordinary tiers, material/roof families, localized wear, special buildings, fortifications, and route-scale visual interpretation as pending. Eight valid plates are capture evidence only; they do not replace R-489 reconciliation or named visual review. |

## Verification record

### Focused Godot suites

All runs used Godot 4.7.1 from the project root. The saved logs are outside the repository at `/tmp/r534_final_lower/`, `/tmp/r534_final_smithy/`, `/tmp/r534_final_transition/`, and `/tmp/r534_final_capture/`.

```text
--filter=test_lower_town_slice_map
1 file, 19 tests, 0 failures, 0 errors

--filter=test_kalev_smithy_map
1 file, 16 tests, 0 failures, 0 errors

--filter=test_transition_manifest
1 file, 3 tests, 0 failures, 0 errors

--filter=test_capture_lower_town_p0_101
1 file, 4 tests, 0 failures, 0 errors
```

The first three runs were executed as the final checked suites; the capture contract was rerun independently during this verification. Each green run emitted only the known shutdown `ObjectDB`/resource cleanup diagnostics after the zero-failure summary. Those warnings are harness teardown noise, not test failures.

### Conversion parity

```text
python3 tools/verify_map_conversion_parity.py
# lower_town_slice: anchor accounting 11/11
# kalev_smithy: anchor accounting 3/3
# Godot filter green: test_kalev_smithy_map
# Godot filter green: test_lower_town_slice_map
# map conversion parity verification passed
```

### Capture packet

`docs/reports/images/lower_town_p0_101/capture_manifest.json` records:

- map `lower_town_slice`;
- source fingerprint `e8cde197067d824d1efd46b399506f6d86158a506cd92bf5d6c6b5552f4209b2`;
- `1280x720` output and eight plates;
- four matched route presets: `street_start_to_smithy_door`, `smithy_door_to_brewery_door`, `brewery_door_to_checkpoint_west`, and `checkpoint_west_to_checkpoint_east`;
- paired `day`/`night` outputs with deterministic framing keys;
- `gl_compatibility` / `opengl3` capture command contract.

The packet is valid evidence that the route capture process is reproducible and outputs non-blank matched plates. It is not evidence that every required tier, landmark, material, wear state, or occlusion boundary has passed human review.

## Closeout status and required next action

Keep R-534 in `in_review` until the R-489 handoff supplies both missing evidence classes:

1. an archived before/after baseline reconciliation covering stable IDs, anchors, props, transitions, patrols, collision, navigation, and gameplay fingerprints; and
2. a route-scale, surface-by-surface visual occlusion review tied to the matched capture packet, with named review ownership or explicit amendments.

No runtime or art implementation change is justified by this verification. The current contract passes should be retained when R-489 evidence is added and rerun.

## Sources

- [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap)
- [`content/maps/kalev_smithy.rrmap`](../../content/maps/kalev_smithy.rrmap)
- [`tests/fixtures/maps/lower_town_slice.parity.json`](../../tests/fixtures/maps/lower_town_slice.parity.json)
- [`tests/godot/test_lower_town_slice_map.gd`](../../tests/godot/test_lower_town_slice_map.gd)
- [`tests/godot/test_kalev_smithy_map.gd`](../../tests/godot/test_kalev_smithy_map.gd)
- [`tests/godot/test_transition_manifest.gd`](../../tests/godot/test_transition_manifest.gd)
- [`tests/godot/test_capture_lower_town_p0_101.gd`](../../tests/godot/test_capture_lower_town_p0_101.gd)
- [`tools/verify_map_conversion_parity.py`](../../tools/verify_map_conversion_parity.py)
- [`docs/reports/images/lower_town_p0_101/capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json)
- [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md)
- [`lower_town_p0_101_acceptance.md`](lower_town_p0_101_acceptance.md)
- [`burgher_house_art_signoff.md`](burgher_house_art_signoff.md)
