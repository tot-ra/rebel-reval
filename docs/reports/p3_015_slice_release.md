# P3-015 vertical-slice release

Date: 2026-07-25

## Release tag

- `v0.1.0-slice`

## Frozen compatibility contract

| Surface | Version | Notes |
|---------|--------:|-------|
| Save envelope | 1 | `SaveEnvelope.CURRENT_ENVELOPE_VERSION` |
| Game state | 2 | `GameState.CURRENT_VERSION` |
| Map world state | 2 | `MapStableStateStore.CURRENT_SAVE_VERSION` |
| Content schema | 1 | `schemas/*.schema.json` fingerprint in `slice_release_manifest.json` |

Slice content corpus fingerprint covers:

- `content/demo`
- `content/examples/support`
- `content/examples/valid`

## Published save fixture

- ID: `save.slice_prologue_complete`
- Path: `content/saves/released/save.slice_prologue_complete.json`
- Checkpoint: `checkpoint.prologue_complete`
- Branch: Maker's Mark ledger preserved after honest watch-buckle commission

## Verification

```bash
tools/verify_slice_release.sh
python3 tools/report_slice_release.py --check
python3 -m unittest tests.python.test_report_slice_release -v
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_vertical_slice_release
```

Regenerate the published fixture after intentional prologue-state changes:

```bash
python3 tools/build_slice_release_fixture.py
```

## Maintainer sign-off

- Release tag `v0.1.0-slice` points at the vertical-slice MVP gate closed in `docs/reports/p3_014_slice_gate.md`.
- Published save fixture loads on a clean clone without migration errors.
- Content and save schema versions are frozen in `docs/data/slice_release_manifest.json`.
