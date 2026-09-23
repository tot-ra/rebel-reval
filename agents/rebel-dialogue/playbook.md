# Dialogue playbook

Read `agents/playbook.md` first for shared workflow, tooling, and Git lessons.
This file contains lessons specific to the Dialogue role.

## Role-specific lessons
- `DialogueSettings.default_settings()` is untyped. Under Godot 4.7 assign it to an explicit `Variant` (or add a return type) before reading fields, or the test script itself fails to parse.
- Spoken "кавальня" / "на Кавальне" in Workers District notes usually means the outdoor `courtyard_anvil` (наковальня), not a building name. Confirm against `lower_town_slice.rrmap` before inventing a new landmark.
- The dialogue voice bundle cannot be completed from the authored manifest alone. Do not synthesize placeholder MP3s or mark cues approved without the real ElevenLabs export, human listening review, and record-level rights evidence.
