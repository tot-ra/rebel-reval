# P0-122f Baltic Bird-Audio Acceptance

**Task:** R-427 / P0-122f
**Acceptance date:** 2026-08-05
**Decision:** **BLOCKED - preserve the verified German iNaturalist fallbacks.**

This final rights-boundary closeout verifies the two P0-122f gap species, the 30-species
source manifest, the processed cue set, provenance registration, the focused Python
contract tests, and the focused Godot bird-audio suites. No curated row, runtime
species ID, scheduler, or audio asset was changed by this closeout.

## Per-species decision

| Runtime species | Current source and record | Region | License | Processed clip | Baltic permission evidence | Decision |
|---|---|---|---|---|---|---|
| `great_cormorant` | iNaturalist sound `367008`, observation `108097119`, recordist `jeremybarker` | Friedrichshafen, Germany | CC0 1.0 | `sounds/birds/great_cormorant/call.mp3` (source `great_cormorant_IN367008.wav`) | [`great_cormorant_permission.md`](evidence/p0_122f/great_cormorant_permission.md) identifies Estonian Loodusheli `speciesid=482`, published CC BY-NC 3.0 EE terms, and no written commercial grant | **Fallback retained; Baltic replacement blocked** |
| `white_tailed_eagle` | iNaturalist sound `803125`, observation `180952096`, recordist `emilvus` | Brandenburg, Germany | CC BY 4.0 | `sounds/birds/white_tailed_eagle/call.mp3` (source `white_tailed_eagle_IN803125.wav`) | [`white_tailed_eagle_permission.md`](evidence/p0_122f/white_tailed_eagle_permission.md) identifies Estonian Loodusheli `speciesid=576`, published CC BY-NC 3.0 EE terms, and no written commercial grant | **Fallback retained; Baltic replacement blocked** |

The exact current curated rows are in `tools/audio/curated_bird_recordings.json` and
`sounds/birds/manifest.csv`. Both satisfy the commercial-license verifier. Neither
Estonian candidate may be downloaded, trimmed, registered, or substituted from
metadata alone.

## Cross-manifest identity check

The final closeout compared the two gap-species records across every production
manifest. Each row resolves to the same source ID, observation URL, recordist,
license, source file, and processed runtime cue; `assets/SOURCES.csv` contains the
matching provenance entries for both source WAVs and both processed MP3s.

| Species | Curated JSON | Source manifest | Processed manifest | Provenance | Decision |
|---|---|---|---|---|---|
| `great_cormorant` | `inaturalist` / `367008` / `jeremybarker` / CC0 | `367008` / `sounds/birds/great_cormorant/great_cormorant_IN367008.wav` | `bird.great_cormorant.call` -> `call.mp3` / `367008` / CC0 | source + processed rows in `assets/SOURCES.csv` | **fallback retained** |
| `white_tailed_eagle` | `inaturalist` / `803125` / `emilvus` / CC BY 4.0 | `803125` / `sounds/birds/white_tailed_eagle/white_tailed_eagle_IN803125.wav` | `bird.white_tailed_eagle.call` -> `call.mp3` / `803125` / CC BY 4.0 | source + processed rows in `assets/SOURCES.csv` | **fallback retained** |

No metadata-only candidate, CC BY-NC/ND source, unregistered file, or
`source=permission` row is present for either gap species.

## Verification matrix

All commands below were run from the repository root on 2026-08-05. Every command
returned exit status `0`.

| Check | Exact command | Result |
|---|---|---|
| Curated gap-recording policy | `python3 tools/audio/verify_curated_bird_recordings.py` | **PASS (status 0)** - 2 gap species use permitted field-recording sources and commercial-compatible licenses |
| 30-species source manifest | `python3 tools/verify_bird_audio_manifest.py` | **PASS (status 0)** - all 30 species have an on-disk commercial-compatible source in the 15-90 second range |
| Processed cue/provenance coverage | `python3 tools/verify_bird_audio_clips.py` | **PASS (status 0)** - all 30 catalog cues resolve to processed clips, import sidecars, and provenance rows |
| Focused Python contracts | `python3 -m unittest tests.python.test_verify_curated_bird_recordings tests.python.test_bird_audio_manifest -v` | **PASS (status 0)** - 21 tests passed, 0 failures, 0 errors |
| Processed clip Godot suite | `tools/run_godot_checked.sh --require-test-summary r426-bird-audio-clips -- /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_bird_audio_clips` | **PASS (status 0)** - 1 file, 1 test, 0 failures, 0 errors |
| Ambient runtime Godot suite | `tools/run_godot_checked.sh --require-test-summary r426-map-view-bird-ambient-audio -- /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_view_bird_ambient_audio` | **PASS (status 0)** - 1 file, 8 tests, 0 failures, 0 errors |

The checked-runner logs were captured with the basenames `r426-bird-audio-clips`
and `r426-map-view-bird-ambient-audio`. The ambient suite emitted only shutdown
noise after its clean summary: `160 ObjectDB instances were leaked at exit` and
`8 resources still in use at exit`. These are documented DEF-002 non-blocking
shutdown diagnostics accepted by `tools/run_godot_checked.sh`; no engine, parser,
resource-loading, script, test, or assertion error was emitted.

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

Permission outreach remains tracked separately by `R-435`. Until a grant is
received, keep both German iNaturalist clips unchanged.
