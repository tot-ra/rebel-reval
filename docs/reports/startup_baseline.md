# Startup baseline (P0-017)

Recorded: 2026-07-16 (UTC baseline run on 2026-07-15T22:41Z)

## Summary

| Step | Result | Exit code |
|------|--------|-----------|
| Headless import | Pass | 0 |
| Headless main scene startup | Pass | 0 |
| Headless playable room (`reval_east`) | Pass | 0 |
| Docs validation (`generate_active_docs_report.py --check`) | Pass | 0 |
| Headless `--check-only` | **Fail** (hangs, no stderr output) | n/a (terminated after 30s watchdog) |

**Baseline verdict:** Pass for P0-017 import and playable-room criteria. The documented `--check-only` command does not complete headlessly on this project; see [known_runtime_defects.md](./known_runtime_defects.md) defect `DEF-001`.

## Environment

| Field | Value |
|-------|-------|
| Host OS | macOS (darwin arm64) |
| Godot binary | `/Applications/Godot.app/Contents/MacOS/Godot` |
| Godot version | `4.7.1.stable.official.a13da4feb` |
| Repository HEAD | `489b63a3669d48afed6e592b7cd2a37cb03b075e` |
| Clone method | `git clone --no-local <repo> /tmp/rebel-reval-p0-017-47/clean-clone` (no `.godot/` cache in clone) |
| Renderer pin | GL Compatibility (`project.godot`) |
| Version pins at run time | `.godot-version` was `4.4` (stale); `project.godot` `config/features` was `4.7` |

After this baseline, `.godot-version` and `docs/SETUP.md` were updated to **4.7** to match `project.godot` and the maintainer-installed editor.

## Commands (from `docs/SETUP.md` / P0-016)

All commands run from the clean-clone root unless noted.

### Version check

```bash
/Applications/Godot.app/Contents/MacOS/Godot --version
```

Output:

```text
4.7.1.stable.official.a13da4feb
```

Exit: `0`

### Headless import

```bash
godot --headless --editor --quit
```

Exit: `0`. Editor import pipeline completed (675 reimport steps, 38 scene group updates, 11 script documentation updates). Local `.godot/` cache created in the clone.

### Startup / parser check (`--check-only`)

```bash
godot --headless --check-only
```

**Does not exit** within 30 seconds. Stdout shows only the engine banner; stderr empty. Same behavior observed with Godot 4.4.1 on an earlier run. Use the playable-room smoke command below until `DEF-001` is resolved.

### Main scene startup smoke

```bash
godot --headless --quit-after 5
```

Loads `run/main_scene` (`scenes/menu/main_menu.tscn`). Exit: `0`.

Stderr (non-blocking exit leaks only):

```text
WARNING: 2 ObjectDB instances were leaked at exit (run with `--verbose` for details).
ERROR: 1 resources still in use at exit (run with --verbose for details).
```

No `SCRIPT ERROR`, `Parse Error`, or `Resource file not found` messages.

### Playable room smoke

```bash
godot --headless --quit-after 5 scenes/reval_east/reval_east.tscn
```

Exit: `0`. Scene loads player, tile map, navigation, and NPCs.

Stderr (non-blocking exit leaks only):

```text
WARNING: 26 ObjectDB instances were leaked at exit (run with `--verbose` for details).
ERROR: 12 resources still in use at exit (run with --verbose for details).
```

No parser or missing-resource errors. This room is the default destination after clicking **Start** on the main menu (`scenes/intro/start_label.gd` -> `reval_east.tscn`).

### Docs validation

```bash
python3 tools/generate_active_docs_report.py --check
```

Exit: `0`. Output: active Markdown docs have zero issues.

## Reproduction (clean clone)

```bash
TMP=/tmp/rebel-reval-p0-017-verify
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
git clone <repository-url> "$TMP/clean-clone"
cd "$TMP/clean-clone"
"$GODOT" --headless --editor --quit
"$GODOT" --headless --quit-after 5 scenes/reval_east/reval_east.tscn
```

Expected: both commands exit `0` without parser or missing-resource errors.

## Notes

- `godot` is not on the default `PATH` on the baseline host; use the full macOS app binary path or symlink per `docs/SETUP.md`.
- Headless exit-time resource leak warnings are logged but do not prevent scene load; tracked as `DEF-002` in [`known_runtime_defects.md`](./known_runtime_defects.md).
- Prior Godot **4.4.1** run on the same HEAD reported missing `run` animation errors in `reval_east`; those errors did **not** reproduce under **4.7.1**.
