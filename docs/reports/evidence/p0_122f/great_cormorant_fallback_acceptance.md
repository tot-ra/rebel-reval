# P0-122f Great Cormorant Fallback Acceptance

**Task:** R-425 / P0-122f
**Acceptance date:** 2026-08-05
**Decision:** **NO-OP - retain the verified German iNaturalist fallback.**

## Rights decision

The dependent review in [`great_cormorant_permission.md`](great_cormorant_permission.md) remains **BLOCKED**. The exact Estonian Loodusheli record is `speciesid=482`, published under CC BY-NC 3.0 EE, with no written commercial grant. Duration, rightsholder authority, commercial game/update/trailer scope, editing/storage/distribution rights, and approved attribution wording are incomplete. The candidate must not be downloaded or materialized.

## No-op implementation

The production cormorant source remains the verified German iNaturalist field take:

- curated record: `recording_id=367008`, observation `108097119`, recordist `jeremybarker`, Friedrichshafen, Germany, CC0 1.0;
- source clip: `sounds/birds/great_cormorant/great_cormorant_IN367008.wav`;
- processed clip: `sounds/birds/great_cormorant/call.mp3`;
- runtime species ID and cue remain `great_cormorant` / `bird.great_cormorant.call`.

No `source=permission` row was added, no `great_cormorant_PM<recording_id>.wav` was created, and no runtime scheduler or species ID was changed. The curated cormorant row, source WAV, and processed MP3 are byte-for-byte identical to their `HEAD` objects. The source and processed manifest rows continue to point to the same files and recording; their pre-existing working-tree line-ending normalization is unrelated to this no-op and was not changed by this task.

## Verification

| Check | Result |
|---|---|
| `python3 tools/audio/verify_curated_bird_recordings.py` | **PASS** - both gap species retain permitted commercial-compatible sources |
| `python3 tools/verify_bird_audio_manifest.py` | **PASS** - all 30 species have an on-disk commercial-compatible source in the 15-90 second range |
| `python3 tools/verify_bird_audio_clips.py` | **PASS** - all 30 catalog cues resolve to processed clips, import sidecars, and provenance rows |
| Curated cormorant row | **UNCHANGED** - `367008`, `https://www.inaturalist.org/observations/108097119`, CC0 1.0 |
| Source WAV and processed MP3 | **BYTE-FOR-BYTE UNCHANGED** from `HEAD` |
| Permission candidate | **BLOCKED** - no commercial grant; no download or registration performed |

## Evidence boundary and next action

This acceptance proves the blocked outcome and preserves the existing fallback; it does not prove that no other Baltic recording may later become available. A future replacement requires a written commercial grant tied to an exact recording or another explicitly commercial-compatible field take, followed by a fresh materialization and verification pass. The permission packet transmission and outbound-message evidence remain tracked separately by `R-435`. Until a grant is received, keep the German iNaturalist clip unchanged.
