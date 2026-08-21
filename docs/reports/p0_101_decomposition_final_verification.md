# P0-101 decomposition final verification

**Task:** R-651 / P0-101 independently verify decomposition and completion
**Parent:** R-108 / P0-101
**Verification date:** 2026-08-21
**Verification HEAD:** `a39a9423a92c80a31333374a20270f74bbcd93b3` (`main`)
**Worktree:** shared checkout with unrelated modified, staged, and untracked WIP; this report is the only scoped artifact created by R-651
**Scope:** verification-only; no production code, assets, map data, captures, thresholds, parity fixtures, or historical decisions were changed
**Decision:** **BLOCKED - decomposition coverage and handoffs are present, but R-108 / P0-101 is not accepted and must remain open.**

## Decision rule

R-108 may move to `done` only when every acceptance clause has independent evidence, every required handoff is resolved, and no source-only, packet-integrity-only, headless-only, development-host-only, conditional, or stale-revision result is promoted to final acceptance. A completed verification task may still carry a BLOCKED result. This report preserves that boundary.

## Independent source and packet checks

The current working-tree source was parsed independently on 2026-08-21:

| Check | Result | Interpretation |
|---|---|---|
| RRMap records | **PASS: 99 records, 99 unique IDs** | Current source inventory is internally unique. |
| Tier counts | **PASS as source evidence: `merchant_stone=14`, `merchant_timber=14`, `craft_boda=23`** | All three tiers are authored; counts do not prove visual readability. |
| R-547 rear workshops | **PASS as source evidence: 8/8** | All eight IDs are in the RRMap and match `lower_town_authoring_contract.json`; no visual acceptance is inferred. |
| Current RRMap SHA-256 | `6ae0b82a0a46a7391cb5db5a0bb02e562756def8073fe08cf63beebd7ace7e50` | Working-tree source revision used for this audit. |
| Capture packet | **PASS for package integrity: 10 PNG plates, 5 presets, 5 matched day/night pairs, 1280x720** | All referenced files exist, decode as PNG, and are non-blank. |
| Capture fingerprint | **BLOCKED for current-source acceptance** | Manifest fingerprint `13525325b3d8be840c79d8c709c8aab12632bc6092a7123bc6d9275ba51d17ba` does not match the current RRMap SHA-256. |
| Stable-ID visual metadata | **BLOCKED** | `capture_manifest.json` has route anchors and interaction targets, but no stable-ID observation fields or reviewer annotations. |

The eight reconciled rear-workshop IDs are: `saddlers_rear_workshop`, `coopers_rear_workshop`, `sauna_rear_boda`, `rope_makers_rear_store`, `karja_rear_boda`, `brewery_rear_store`, `smithy_rear_shed`, and `carriers_barn`.

## R-108 clause-by-clause matrix

| # | R-108 acceptance clause | Current result | Evidence and exact blocker | Owner / next action |
|---:|---|---|---|---|
| 1 | No unexplained repeated ordinary facade/material run; every required visible landmark is classified and present exactly once. | **BLOCKED** | Source uniqueness and the 51 tiered-house counts pass structurally. The tier suite passes 5/5, but no accepted gameplay-scale review proves repetition limits, material variation, or landmark presentation. | R-487 / R-612. Provide stable-ID-linked matched route evidence and ordinary-fabric review. |
| 2 | Gameplay-scale captures distinguish `merchant_stone`, `merchant_timber`, and `craft_boda`, plus log/plank/plaster/limestone, tile/shingle/thatch, and localized wear/repair. | **BLOCKED** | Capture contract passes 5/5 and the packet is complete as a file package, but the matrix marks every tier/material/roof/wear row pending. The packet has no stable-ID observations, and all eight rear workshops remain visually unproven. | R-487 / R-612 with R-616/R-561 packet handoff. Capture and annotate each required surface; do not infer visibility from route coverage. |
| 3 | St. Catherine's, the 1343 Viru Gate state, and every required special building have reviewed exceptional silhouettes and are not scaled-up ordinary houses. | **BLOCKED** | Fortification boundary suite passes 8/8 and environment contract passes 5/5. Structural registry and wall/arch separation are not visual or historical acceptance. No stable-ID approach/close observation or named human approval exists for the required exceptional rows. | R-488 / R-613 and R-617/R-492. Preserve the 1343 exclusions, capture every required ID, and obtain named review. |
| 4 | Matched gameplay-scale day/night captures exist for ordinary fabric and each required landmark, with camera and map-revision metadata. | **BLOCKED for acceptance; PASS for packet integrity only** | Ten files, five framing keys, and matched day/night metadata pass. The manifest fingerprint is stale against the current RRMap, and route anchors are not stable-ID observations for the required frontage, walls, gate arches, workshops, or landmarks. | R-489 / R-614 with R-560/R-561. Reconcile packet to the current source and annotate direct stable-ID observations. |
| 5 | Human historical/art review signs every required 1343 silhouette, or records a blocking amendment with an owner. | **BLOCKED** | R-617 remains `in_progress`; R-638 records blocked review rows, and R-492 remains `in_review`. No named human canon reviewer or named human art reviewer has signed the required silhouettes. Conditional R-6/A-009 is not final gameplay sign-off. | R-617 / R-492 / R-638. Obtain named reviewers or retain explicit per-row amendments and owners. |
| 6 | Routes, patrols, transitions, collision, navigation, occlusion/chunk metadata, deterministic parity fixtures, and performance budgets pass with hardware limitations stated. | **BLOCKED** | Capture/tier/fortification/environment contracts pass, but `test_lower_town_slice_map` is 18/19 because canonical `walkability_sha256` differs (`expected 57e9b9d32a01099e4c399e51b1552e5edbf6eba58d07eff5b6975d081bbbbf8f`, `actual 0c33d876cd74bdd69c35cb4e91e4b1503112cb1adf690c2072219c72f85a4944`). Camera suite is 5/11 with 6 failures. The clean-checkout gate passes detached checkout, LFS restore, and import, then fails on missing tracked-HEAD `eye_material.gdshader` and `hair_material.gdshader` preloads; earlier gate evidence retains `elevation_area`/`elevation_ramp` as the next parser blocker. Runtime ledgers retain resident node/memory overages and unavailable declared-target hardware evidence. | R-547/map owner and R-489/R-614 for parity; R-577 for camera; R-122/R-124 then R-453/R-455/R-604 for clean load; R-578/P3-011 for resident cost; R-563 for Intel UHD 620 evidence. No fixture or cap was changed here. |
| 7 | All upstream blockers and child handoffs are resolved or explicitly recorded; no incomplete P0-102 handoff is treated as complete. | **BLOCKED** | R-649 and R-650 are complete reconciliation reports, but their results are explicitly BLOCKED. R-109 is `in_progress`, R-6 is conditional `in_review`, implementation owners remain open, R-618 remains `in_progress`, and R-493 remains `in_review`. | R-618 / R-493 after all upstream and child gates change to accepted states. Keep R-108 open. |

## Dependency and handoff audit

Exact board queries were performed for the required refs. The current state is:

| Ref | Status | Interpretation |
|---|---|---|
| R-108 / P0-101 | `todo` | Parent remains open. |
| R-109 / P0-100 | `in_progress` | Upstream layout/terrain/composition handoff remains open. |
| R-213 / P2-067 | `done` | Tier wiring is complete structurally only. |
| R-6 / A-009 | `in_review` | Conditional reference-art direction, not final gameplay sign-off. |
| R-487 / P0-101b | `in_progress` | Ordinary-fabric implementation remains open. |
| R-488 / P0-101c | `in_progress` | Exceptional-landmark implementation remains open. |
| R-489 / P0-101d | `in_progress` | Playable-route art integration remains open. |
| R-490 / P0-101e | `in_review` | Runtime report carries a blocked result. |
| R-491 / P0-101f | `in_review` | Capture packet exists, but visual surface review is incomplete. |
| R-492 / P0-101g | `in_review` | Historical/art review has no named human approval. |
| R-560 | `in_progress` | Capture capability exists, but the source-revision handoff is open. |
| R-561 | `in_review` | Packet audit is not stable-ID visual acceptance. |
| R-562 | `done` | Gate implementation is complete; product clean load is blocked. |
| R-563 | `in_review` | M5 supplementary evidence exists; Intel UHD 620 measurement is unavailable. |
| R-612 | `in_progress` | Ordinary-fabric verification remains open. |
| R-613 | `in_progress` | Exceptional-landmark verification remains open. |
| R-614 | `in_progress` | Route-integration verification remains open. |
| R-615 | `in_progress` | Runtime/performance verification remains open. |
| R-616 | `done` | Packet integrity is complete; visual acceptance remains blocked. |
| R-617 | `in_progress` | Human historical/art sign-off remains open. |
| R-618 | `in_progress` | Final independent acceptance remains open. |
| R-493 | `in_review` | Parent acceptance review remains open. |
| R-649 | `done` | Decomposition coverage audit is complete as BLOCKED. |
| R-650 | `done` | Child handoff reconciliation is complete as BLOCKED. |
| R-651 | `in_progress` at verification start | This report completes the independent verification deliverable as BLOCKED. |

No self-dependency, unregistered required ref, duplicate acceptance surface, or missing owner was found. R-649 and R-650 cover decomposition and handoff consistency; they do not waive any acceptance clause.

## Artifact existence audit

The required reports, source files, manifest, focused tests, and gate scripts referenced by the current ledgers were checked from the project root. **11 core reports and 187 relative Markdown links were checked; 0 missing paths were found.** The key artifacts are:

- [`p0_101_decomposition_coverage_audit.md`](p0_101_decomposition_coverage_audit.md)
- [`r650_p0_101_child_handoff_reconciliation.md`](r650_p0_101_child_handoff_reconciliation.md)
- [`lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md)
- [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md)
- [`lower_town_p0_101_runtime_qa.md`](lower_town_p0_101_runtime_qa.md)
- [`p0_101_decomposition_readiness.md`](p0_101_decomposition_readiness.md)
- [`p0_101_clean_checkout_load_gate.md`](p0_101_clean_checkout_load_gate.md)
- [`p0_101_runtime_performance_gate_ledger.md`](p0_101_runtime_performance_gate_ledger.md)
- [`p0_101_gpu_budget_evidence.md`](p0_101_gpu_budget_evidence.md)
- [`r640_lower_town_final_acceptance_verification.md`](r640_lower_town_final_acceptance_verification.md)
- [`r611_p0_101_upstream_readiness.md`](r611_p0_101_upstream_readiness.md)
- [`images/lower_town_p0_101/capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json)
- [`../../content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap)
- [`../data/lower_town_authoring_contract.json`](../data/lower_town_authoring_contract.json)

The artifact paths exist, but existence is not acceptance. In particular, the packet and structural reports explicitly preserve their visual, historical, parity, clean-load, camera, resident-budget, and target-hardware blockers.

## Reproduction record

Run from the project root. The working tree must be treated as dirty; do not regenerate the parity fixture or modify caps as part of this verification.

### Source, manifest, and link audit

```bash
python3 - <<'PY'
from pathlib import Path
import hashlib, json, re, struct
root = Path('.')
rr = root / 'content/maps/lower_town_slice.rrmap'
text = rr.read_text(encoding='utf-8')
records = re.findall(r'^(?:building|landmark)\s+(\S+)\s+(\S+)', text, re.M)
tiers = re.findall(r'^building\s+\S+\s+house\b[^\n]*\bhouse_tier=(\S+)', text, re.M)
rear = {
    'saddlers_rear_workshop', 'coopers_rear_workshop', 'sauna_rear_boda',
    'rope_makers_rear_store', 'karja_rear_boda', 'brewery_rear_store',
    'smithy_rear_shed', 'carriers_barn',
}
ids = {record_id for record_id, _kind in records}
assert len(records) == 99 and len(ids) == 99
assert {tier: tiers.count(tier) for tier in sorted(set(tiers))} == {
    'craft_boda': 23, 'merchant_stone': 14, 'merchant_timber': 14,
}
assert rear <= ids
contract = json.loads((root / 'docs/data/lower_town_authoring_contract.json').read_text())
assert set(contract['frontage_audit']['rear_service_buildings']) == rear
manifest = json.loads((root / 'docs/reports/images/lower_town_p0_101/capture_manifest.json').read_text())
assert len(manifest['plates']) == 10 and len(set(manifest['presets'])) == 5
for plate in manifest['plates']:
    path = root / plate['output'].removeprefix('res://')
    raw = path.read_bytes()
    assert raw[:8] == b'\x89PNG\r\n\x1a\n'
    assert struct.unpack('>II', raw[16:24]) == (1280, 720)
print('SOURCE_PASS records=99 unique_ids=99 tiers=14/14/23 rear_workshops=8/8')
print('PACKET_PASS plates=10 presets=5 viewport=1280x720 files=10')
print('MAP_SHA256', hashlib.sha256(rr.read_bytes()).hexdigest())
print('MANIFEST_FINGERPRINT', manifest['map_fingerprint'])
print('STABLE_ID_METADATA', any('stable_id' in json.dumps(p).lower() for p in manifest['plates']))
PY
```

Expected output includes the current map SHA `6ae0b82a...`, the older manifest fingerprint `13525325...`, and `STABLE_ID_METADATA False`.

### Focused structural and packet checks

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT_LOG_DIR=/tmp/r651-p0-101

bash tools/run_godot_checked.sh --require-test-summary r651-capture -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_capture_lower_town_p0_101
# 1 file, 5 tests, 0 failures, 0 errors

bash tools/run_godot_checked.sh --require-test-summary r651-tiers -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_burgher_house_tiers
# 1 file, 5 tests, 0 failures, 0 errors

bash tools/run_godot_checked.sh --require-test-summary r651-landmark -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_map_view_3d_fortification
# 1 file, 8 tests, 0 failures, 0 errors

bash tools/run_godot_checked.sh --require-test-summary r651-environment -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_environment_kit_integration
# 1 file, 5 tests, 0 failures, 0 errors

bash tools/run_godot_checked.sh --require-test-summary r651-map -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_lower_town_slice_map
# 1 file, 19 tests, 1 failure: canonical walkability parity drift

python3 tools/report_slice_performance.py --check
# manifest and slice gates are valid

python3 -m unittest tests.python.test_verify_clean_checkout_load -v
# 7 tests, 0 failures, 0 errors
```

Known shutdown-only ObjectDB/resource diagnostics follow the green Godot summaries. They do not waive the parity failure.

### Runtime blockers

```bash
bash tools/run_godot_checked.sh --require-test-summary r651-camera -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_map_camera_modes
# 11 tests, 6 failures, 0 test errors

GODOT_BIN="$GODOT_BIN" tools/verify_clean_checkout_load.sh
# detached checkout, LFS restore, and import pass; clean product load is blocked
# first current blocker: missing eye_material.gdshader and hair_material.gdshader preloads
```

The clean-load command creates and removes its detached temporary checkout. The first current missing-shader blocker is distinct from the previously recorded downstream `elevation_area` / `elevation_ramp` parser blocker. Neither result is a PASS.

## Final disposition

**R-651 is complete as a reproducible deterministic BLOCKED verification report. Keep R-108 / P0-101 open.**

The decomposition is complete in the narrow coordination sense: every R-108 clause has an owner, R-649 and R-650 exist and are internally consistent, all three tier counts and eight rear-workshop IDs reconcile, and the required report paths exist. The acceptance is not complete because stable-ID gameplay evidence, named human historical/art approval, current parity, clean product load, camera behavior, resident budgets, declared Intel UHD 620 evidence, and upstream R-109/A-009 readiness remain unresolved.

No follow-up task was added. Existing owners already cover each blocker: R-487/R-612, R-488/R-613/R-617, R-489/R-614, R-547, R-577, R-578/P3-011, R-122/R-124, R-453/R-455/R-604, R-563, and R-618/R-493.

## Sources

- [`p0_101_decomposition_coverage_audit.md`](p0_101_decomposition_coverage_audit.md)
- [`r650_p0_101_child_handoff_reconciliation.md`](r650_p0_101_child_handoff_reconciliation.md)
- [`lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md)
- [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md)
- [`lower_town_p0_101_runtime_qa.md`](lower_town_p0_101_runtime_qa.md)
- [`p0_101_decomposition_readiness.md`](p0_101_decomposition_readiness.md)
- [`p0_101_clean_checkout_load_gate.md`](p0_101_clean_checkout_load_gate.md)
- [`p0_101_runtime_performance_gate_ledger.md`](p0_101_runtime_performance_gate_ledger.md)
- [`p0_101_gpu_budget_evidence.md`](p0_101_gpu_budget_evidence.md)
- [`r640_lower_town_final_acceptance_verification.md`](r640_lower_town_final_acceptance_verification.md)
- [`r611_p0_101_upstream_readiness.md`](r611_p0_101_upstream_readiness.md)
- [`images/lower_town_p0_101/capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json)
- [`../../content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap)
- [`../data/lower_town_authoring_contract.json`](../data/lower_town_authoring_contract.json)
- [`../../tools/run_godot_tests.gd`](../../tools/run_godot_tests.gd)
- [`../../tools/verify_clean_checkout_load.sh`](../../tools/verify_clean_checkout_load.sh)
