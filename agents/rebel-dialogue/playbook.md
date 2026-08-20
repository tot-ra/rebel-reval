# Dialogue playbook

Read `agents/playbook.md` first for shared workflow, tooling, and Git lessons.
This file contains lessons specific to the Dialogue role.

## Role-specific lessons
- `DialogueSettings.default_settings()` is untyped; under Godot 4.7 assign it to an explicit `Variant` (or add a return type on the helper) before reading fields, or the test script itself fails to parse.
- Spoken "кавальня" / "на Кавальне" in Workers District notes usually means the outdoor `courtyard_anvil` (наковальня), not a building name; confirm against `lower_town_slice.rrmap` before inventing a new landmark.
- The dialogue voice bundle workflow cannot be completed from the authored manifest alone: do not synthesize placeholder MP3s or mark cues approved without the real 58-clip ElevenLabs export, human listening review, and record-level rights/provenance evidence. Keep the parent task in progress and create a focused handoff task for the missing export.
- R-633 preflight (2026-08-20) found no ElevenLabs dialogue export or handoff directory in the repository: the authored manifest has 58 pending cues, while `audio/` contains only the default bus layout. Keep the task in progress, request the real offline export plus record-level rights evidence, and never reuse music/bird MP3s or synthesize placeholders.
