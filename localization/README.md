# Offline dialogue localization

Runtime dialogue localization is authored and bundled. Each locale file contains a
`locale` tag and a flat `translations` object. `DialogueLocalization` resolves the
requested locale, its language base, the configured default locale, and finally the
inline source text. Missing translations never trigger network access or a runtime
LLM request.

## Voice production handoff

`tools/dialogue_voice_manifest.py` builds the production-time ElevenLabs handoff:

```bash
python3 tools/dialogue_voice_manifest.py \
  --content content/examples/valid \
  --content content/demo \
  --locale en \
  --output docs/data/dialogue_voice_manifest.json
python3 tools/dialogue_voice_manifest.py \
  --content content/examples/valid \
  --content content/demo \
  --locale et \
  --voice-map docs/data/dialogue_voice_map.example.json \
  --output build/dialogue_voice_manifest.et.json
python3 tools/dialogue_voice_manifest.py \
  --content content/examples/valid \
  --content content/demo \
  --locale en \
  --output docs/data/dialogue_voice_manifest.json \
  --check
```

The tool is intentionally offline: it does not read an API key, call ElevenLabs,
or add runtime audio dependencies. It emits deterministic `pending` cues with the
resolved authored text, source pointer, speaker, text hash, model, optional voice
ID, and target audio path. A production operator can use the manifest with the
ElevenLabs dashboard or an approved exporter, then stage and review returned MP3
files without changing the authored cue data:

```bash
# Export files named by cue ID, for example:
# bark.prologue.wake_up_room.henning_stew_comment.mp3
python3 tools/dialogue_voice_bundle.py stage \
  --manifest docs/data/dialogue_voice_manifest.json \
  --input-dir build/elevenlabs/en \
  --project-root .

# Review the complete bundle before changing generated cues to approved.
python3 tools/dialogue_voice_bundle.py review \
  --manifest docs/data/dialogue_voice_manifest.json \
  --project-root . \
  --require-all
```

`stage` accepts either `<cue_id>.mp3`, the manifest basename, or the manifest
relative path. It validates the MP3 frame, copies the clip to the authored
`audio_path`, records `audio_sha256`, and changes only `pending` cues to
`generated`. `review --require-all` checks every generated/approved file, its
hash, the MP3 signature, missing pending cues, and orphan files. This remains a
production-time workflow: the game client continues to use bundled authored text
and never calls a speech or language API at runtime.
