# P3-012: supported desktop platform declaration and packaged smoke proof

## Scope

This report records the **honest** vertical-slice supported-platform declaration for **P3-012**. Only platforms with an export preset, packaged install artifact, and in-binary smoke proof are listed as supported.

## Supported platforms

| ID | OS | Architecture | Minimum OS | Artifact | Smoke proof |
|----|----|--------------|------------|----------|-------------|
| `macos_universal` | macOS | universal | macOS 11.0 (Apple Silicon) / macOS 10.12 (Intel) | `build/rr.dmg` | `tools/verify_supported_platform.sh` |

### Smoke steps per supported platform

1. **install** - mount `build/rr.dmg`, extract `build/Reval Rebel.app`
2. **start** - launch the release binary on the authored main menu and reach forge via Start
3. **save** - write slot 7 through `SessionState.save_game`
4. **load** - transition to Lower Town, reload slot 7, resume forge through `DoorNavigator`
5. **exit** - quit with exit code 0 and `P3-012_PACKAGED_PLATFORM_PASS`

Repository-side contract checks:

```bash
python3 tools/report_slice_platform.py --check
python3 -m unittest tests.python.test_report_slice_platform -v
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_vertical_slice_platform
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_packaged_platform_smoke
```

Packaged proof on macOS:

```bash
tools/verify_supported_platform.sh
```

Set `SKIP_EXPORT=1` to reuse an existing `build/rr.dmg`.

## Explicitly unsupported platforms

| ID | Reason |
|----|--------|
| `windows` | No export preset or packaged smoke harness yet |
| `linux` | No export preset or packaged smoke harness yet |

## Maintainer status

**Pass (repository-side platform contract).** macOS universal is the only declared supported desktop platform. Windows and Linux remain undeclared until export presets and packaged smoke harnesses exist.

Minimum-hardware GPU proof for the supported platform remains split from P3-011 and is exercised during maintainer export validation, not headless CI.
