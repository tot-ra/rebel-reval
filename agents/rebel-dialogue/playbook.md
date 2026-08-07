# Dialogue playbook

Read `agents/playbook.md` first for shared workflow, tooling, and Git lessons.
This file contains lessons specific to the Dialogue role.

## Role-specific lessons
- `DialogueSettings.default_settings()` is untyped; under Godot 4.7 assign it to an explicit `Variant` (or add a return type on the helper) before reading fields, or the test script itself fails to parse.
- Spoken "кавальня" / "на Кавальне" in Workers District notes usually means the outdoor `courtyard_anvil` (наковальня), not a building name; confirm against `lower_town_slice.rrmap` before inventing a new landmark.
