# P3-016 vertical-slice end-to-end suite

Date: 2026-07-25

## Scope

This suite closes the vertical-slice validation loop after **P3-014** (maintainer gate) and **P3-015** (tagged release). It wires together:

- branch traversal and deliberate invalid-state rejection (**P3-001**)
- full playable flow across all three Bitter Brew families (**P2-012**)
- save/reload checkpoints on every phase boundary (**P2-016**)
- published save fixture compatibility (**P3-015**)
- declared supported-platform contract (**P3-012**)

## Authored contract

- Model: `scripts/slice/vertical_slice_e2e_model.gd`
- Manifest: `docs/data/slice_e2e_manifest.json`
- Verify script: `tools/verify_slice_e2e.sh`

## Coverage matrix

| Surface | Count | Source |
|---------|------:|--------|
| Intended endings | 3 | `docs/data/slice_traversal_manifest.json` |
| Invalid transitions | 9 | `docs/data/slice_traversal_manifest.json` |
| Save checkpoints | 10 | `scripts/slice/vertical_slice_save_matrix.gd` |
| Published save fixtures | 4 | `content/saves/released_manifest.json` |
| Supported platforms | 1 | `docs/data/slice_platform_manifest.json` (`macos_universal`) |

## Verification

```bash
tools/verify_slice_e2e.sh
python3 tools/report_slice_e2e.py --check
python3 -m unittest tests.python.test_report_slice_e2e -v
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_vertical_slice_e2e
```

## Maintainer sign-off

- Every intended slice ending is reachable through the authored flow branches.
- Every deliberate invalid transition remains rejected without terminal quest mutation.
- Every published save fixture in `content/saves/released_manifest.json` loads or migrates through `SaveEnvelope`.
- Declared platform support remains macOS universal only until another platform gains export and packaged smoke coverage.
