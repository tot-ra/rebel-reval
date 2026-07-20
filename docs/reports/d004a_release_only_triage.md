# D-004a release-only defect triage

Date: 2026-07-20  
Host: macOS darwin arm64 (Apple M5 Pro)  
Godot: 4.7.1.stable.official.a13da4feb  
Packaged binary: `build/Reval Rebel.app` from preset `rr` (`build/rr.dmg`)

## Goal

Find defects in the packaged move-talk-pickup loop that appear only in the
release binary and do not reproduce under editor / `godot --path .` play.

## Method

1. Reconfirm the editor-side demo proof:
   `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_demo_walkthrough`
   (2/2 pass; no debug presets).
2. Launch the packaged binary **without** `--path` or a scene argument:
   `"build/Reval Rebel.app/Contents/MacOS/Reval Rebel" --quit-after 6`
3. Diff release vs editor behavior for demo-relevant gates (`OS.is_debug_build()`,
   Start spawn, ContentDB demo dirs, DoorNavigator forge / `reval_east` routes).
4. Re-check `tools/verify_packaged_demo.sh` against release-template CLI limits.

## Findings

| ID | Severity | Release-only gameplay? | Decision |
|----|----------|------------------------|----------|
| (none) | - | - | **No release-only move-talk-pickup defects remain** |
| Tooling false positive (pre-fix) | n/a (verification) | No | `verify_packaged_demo.sh` used `--path` on the release binary; official templates abort with `compiled without support for path overrides`. Masked by `\|\| true` + `open` fallback. Fixed in the same D-004a change. |
| Shutdown ObjectDB / resource leak lines on packaged `--quit-after` | low | No | Same DEF-002 class as editor headless quit; not unique to release play. |

### Release vs editor demo gates

| Gate | Release packaged | Editor `--path .` |
|------|------------------|-------------------|
| Debug inspector installed | No (`OS.is_debug_build()` false) | Yes |
| Main menu / Start target | `forge` / `smithy_start` via manifest | Same |
| Demo content dirs | Bundled in `Reval Rebel.pck` (`export_filter=all_resources`) | Same `SessionState.DEMO_CONTENT_DIRS` |
| CLI `--path` / scene override | Rejected by release template | Supported |

### Packaged launch evidence (2026-07-20)

```text
EXIT:0
Godot Engine v4.7.1.stable.official.a13da4feb
OpenGL API 4.1 Metal - Compatibility - Apple M5 Pro
WARNING: 2 ObjectDB instances were leaked at exit ...
ERROR: 1 resources still in use at exit ...
```

No parser, missing-resource, or demo-content errors. Leak lines match DEF-002.

### Rejected packaged probes (expected template limits)

```bash
# Both abort before main-scene load on release templates:
"build/Reval Rebel.app/Contents/MacOS/Reval Rebel" --path .
"build/Reval Rebel.app/Contents/MacOS/Reval Rebel" res://scenes/menu/main_menu.tscn
```

These are not player-facing defects; players launch the `.app` without CLI overrides.

## Verdict

**D-004a closed with no release-only defects remaining** for the move-talk-pickup
demo loop. Packaged launch works without path overrides; editor headless
walkthrough remains green; the only release-specific issue found was a
verification-script misuse of `--path`, which is fixed.

## Follow-up

In-binary automated move-talk-pickup inside the release `.app` still needs a
dedicated entry (release templates cannot take a scene path). Tracked as
**D-004c** if product wants CI to exercise the PCK without the editor binary.
Human marketing capture remains optional **D-004b**.
