# P0-122f White-tailed Eagle Fallback Acceptance

**Task:** R-424 / P0-122f
**Acceptance date:** 2026-08-03
**Decision:** **NO-OP - retain the verified German iNaturalist fallback.**

## Rights decision

The dependent permission review in [`white_tailed_eagle_permission.md`](white_tailed_eagle_permission.md) is unambiguously **BLOCKED**. The exact Estonian Loodusheli record is `speciesid=576`, published under CC BY-NC 3.0 EE, with no written commercial grant. Duration, quality, rightsholder authority, commercial game/update/trailer scope, editing/storage/distribution rights, and approved attribution wording are not all available. The candidate must not be downloaded or materialized.

## No-op implementation

The production eagle source remains the north-German iNaturalist field take:

- curated record: `recording_id=803125`, observation `180952096`, recordist `emilvus`, Brandenburg, Germany, CC BY 4.0;
- source clip: `sounds/birds/white_tailed_eagle/white_tailed_eagle_IN803125.wav`;
- processed clip: `sounds/birds/white_tailed_eagle/call.mp3`;
- runtime species ID and cue remain `white_tailed_eagle` / `bird.white_tailed_eagle.call`.

No `source=permission` row was added, no `white_tailed_eagle_PM<recording_id>.wav` was created, and no runtime scheduler or species ID was changed. The curated eagle row and both eagle audio files are byte-for-byte identical to their `HEAD` objects. The manifest rows continue to point to the same source and processed paths; their working-tree line-ending normalization is unrelated to this no-op and was not changed by this task.

## Verification

| Check | Result |
|---|---|
| `python3 tools/audio/verify_curated_bird_recordings.py` | **PASS** - both gap species retain permitted commercial-compatible sources |
| `python3 tools/verify_bird_audio_manifest.py` | **PASS** - all 30 species have an on-disk commercial-compatible source in the 15-90 second range |
| `python3 tools/verify_bird_audio_clips.py` | **PASS** - all 30 catalog cues resolve to processed clips, import sidecars, and provenance rows |
| Curated eagle row | **UNCHANGED** - `803125`, `https://www.inaturalist.org/observations/180952096`, CC BY 4.0 |
| Permission candidate | **BLOCKED** - no commercial grant; no download or registration performed |

## Evidence boundary and next action

This acceptance proves the blocked outcome and preserves the existing fallback; it does not prove that no other Baltic recording may later become available. A future replacement requires a written commercial grant tied to an exact recording or another explicitly commercial-compatible field take, followed by a fresh materialization and verification pass. Until then, keep the German iNaturalist clip unchanged.
