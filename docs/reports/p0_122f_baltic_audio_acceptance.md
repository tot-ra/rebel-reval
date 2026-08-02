# P0-122f Baltic Bird-Audio Acceptance

**Task:** R-379 / P0-122f
**Acceptance date:** 2026-08-02
**Decision:** **BLOCKED - preserve the verified German iNaturalist fallbacks.**

This gate verifies the two P0-122f gap species, the 30-species source manifest, the
processed cue set, and the focused Godot bird-audio suites. No curated row or audio
asset was changed by this acceptance pass.

## Per-species decision

| Runtime species | Current source and record | Region | License | Processed clip | Baltic permission evidence | Decision |
|---|---|---|---|---|---|---|
| `great_cormorant` | iNaturalist sound `367008`, observation `108097119`, recordist `jeremybarker` | Friedrichshafen, Germany | CC0 1.0 | `sounds/birds/great_cormorant/call.mp3` (source `great_cormorant_IN367008.wav`) | `docs/reports/evidence/p0_122f/great_cormorant_permission.md` identifies an Estonian Loodusheli record, but records published CC BY-NC 3.0 EE terms and no written commercial grant | **Fallback retained; Baltic replacement blocked** |
| `white_tailed_eagle` | iNaturalist sound `803125`, observation `180952096`, recordist `emilvus` | Brandenburg, Germany | CC BY 4.0 | `sounds/birds/white_tailed_eagle/call.mp3` (source `white_tailed_eagle_IN803125.wav`) | `docs/reports/evidence/p0_122f/white_tailed_eagle_permission.md` identifies an Estonian Loodusheli record, but records published CC BY-NC 3.0 EE terms and no written commercial grant | **Fallback retained; Baltic replacement blocked** |

The exact current curated rows are in `tools/audio/curated_bird_recordings.json` and
`sounds/birds/manifest.csv`. Both satisfy the commercial-license verifier. Neither
Estonian candidate may be downloaded, trimmed, registered, or substituted from
metadata alone.

## Verification matrix

| Check | Result |
|---|---|
| `python3 tools/audio/verify_curated_bird_recordings.py` | **PASS** - both gap entries use permitted field-recording sources and commercial-compatible licenses |
| `python3 tools/verify_bird_audio_manifest.py` | **PASS** - all 30 species have an on-disk 15-90 second commercial-compatible source row |
| `python3 tools/verify_bird_audio_clips.py` | **PASS** - all 30 catalog cues resolve to processed clips, import sidecars, and provenance rows |
| `python3 -m unittest tests.python.test_verify_curated_bird_recordings tests.python.test_bird_audio_manifest -v` | **BLOCKED** - 20 tests passed and 1 errored because the live `tests/python/test_bird_audio_manifest.py` lacks `import json` while `test_download_curated_permission_dry_run_uses_permission_prefix` calls `json.loads` at line 120 |
| Godot `test_bird_audio_clips.gd` | **PASS** - 1 test, 0 failures, 0 errors |
| Godot `test_map_view_bird_ambient_audio.gd` | **PASS** - 8 tests, 0 failures, 0 errors; shutdown-only ObjectDB/resource leak diagnostics were emitted and are covered by the checked-runner DEF-002 allowlist |

The Python error is a test-file defect in the current shared worktree, not a failure
of the curated manifest or either bird clip. It must be repaired and rerun before
this acceptance can become a clean pass.

## Exact reproduction commands

Run from the repository root:

```sh
python3 tools/audio/verify_curated_bird_recordings.py
python3 tools/verify_bird_audio_manifest.py
python3 tools/verify_bird_audio_clips.py
python3 -m unittest tests.python.test_verify_curated_bird_recordings tests.python.test_bird_audio_manifest -v

export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_bird_audio_clips
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_view_bird_ambient_audio
```

For the release-style log/error policy, rerun each Godot command through
`tools/run_godot_checked.sh` with a basename log name and `--require-test-summary`.

## Rights boundary and next action

The two Estonian Loodusheli pages are regionally correct, but their published
`CC BY-NC 3.0 EE` terms do not permit use in the commercial game. The evidence files
also record that the HTTP pages were readable while the HTTPS endpoint failed
certificate validation because the `www.loodusheli.ee` certificate was expired. That
access limitation is not permission evidence.

P0-122f remains open until each replacement has either:

1. a written commercial grant tied to the exact recording, including rightsholder
authority, editing/distribution scope, duration, and attribution wording; or
2. a different Estonia/Baltic field take whose commercial-compatible license and
provenance are explicitly documented.

Do not mark the parent complete while either species remains on the German fallback
or while the focused Python suite has the missing-import error. A follow-up should
repair only the missing `json` import in `tests/python/test_bird_audio_manifest.py`,
then rerun this matrix without changing runtime scheduling or species IDs.
