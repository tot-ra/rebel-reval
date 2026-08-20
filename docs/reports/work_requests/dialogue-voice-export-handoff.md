# Dialogue voice export handoff

**Status:** BLOCKED - awaiting the approved offline ElevenLabs export and record-level rights evidence.

**Parent task:** R-633 / R-632

## Preflight findings

The authored manifest at [`docs/data/dialogue_voice_manifest.json`](../../data/dialogue_voice_manifest.json) contains exactly 58 entries:

- all 58 cues are `pending`;
- all 58 `audio_path` values are unique;
- all 58 `voice_id` values are still unset;
- no production `audio/voice/**/*.mp3` files are present;
- existing `music/` and `sounds/birds/` MP3s are unrelated and must not be reused as dialogue speech.

The repository-side review correctly fails with 58 missing pending clips when run with `--require-all`.

## Required external handoff

Provide a directory outside the repository (or a secure archive that can be unpacked into one) containing:

1. Exactly 58 non-empty, valid MP3 files.
2. One file for every manifest cue, named either:
   - as the manifest basename, for example `dialogue_demo_forge_henning_kalev_responds.mp3`; or
   - as the complete `cue_id` followed by `.mp3`.
3. No duplicate cue matches and no orphan MP3s.
4. A rights/provenance record, preferably `rights_provenance.md` or `.json`, with record-level fields for:
   - ElevenLabs account or workspace/export owner and the applicable export or commercial-use terms;
   - model ID, voice ID, locale, and export date/time for every cue or voice group;
   - the exact manifest cue IDs covered by each voice/export record;
   - maintainer approval for use in the project, including the approval date;
   - any attribution, retention, editing, distribution, or seat restrictions.

Do not include system TTS output, placeholder audio, unrelated music, or bird recordings. Do not call an ElevenLabs API from runtime code.

## Repository intake and verification

Run these commands from the repository root after the external package is available:

```sh
python3 tools/dialogue_voice_bundle.py stage \
  --manifest docs/data/dialogue_voice_manifest.json \
  --input-dir /absolute/path/to/elevenlabs-dialogue-export \
  --project-root .

python3 tools/dialogue_voice_bundle.py review \
  --manifest docs/data/dialogue_voice_manifest.json \
  --project-root . \
  --require-all
```

`stage` copies the clips into the manifest-declared `audio/voice/...` paths and records SHA-256 values. The review must report `58 bundled, 0 pending`. Only after a human listening pass and rights review may the generated entries be changed to `approved` and the evidence record committed with the manifest and clips.
