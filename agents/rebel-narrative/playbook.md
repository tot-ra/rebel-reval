# Narrative playbook

Read `agents/playbook.md` first for shared workflow, tooling, and Git lessons.
This file contains lessons specific to the Narrative role.

## Role-specific lessons
- After `SaveService` reload, compare remembered fields (`act_boundary`, quest state, flags, validated envelope), not raw `Dictionary` equality. JSON round-trip widens ints to floats and can reorder keys.
- An NPC "standing on the smithy anvil" is usually an authored anvil-bound activity (`ap.visitor.inspect` / `ap.forge.anvil`) whose `approach_position` sits inside `forge_anvil` footprint, not a stray spawn. In prologue prefer Henning inspect over Mart while `flag.mart_missing`.
- Renaming a `docs/CANON.md` heading breaks auto-generated anchors (`BROKEN_ANCHOR`). Keep a stable HTML `<a id="...">` alias for the old slug when widening a section, then rerun `python3 tools/generate_active_docs_report.py --check`.
- New Game places the player via DoorNavigator spawn `smithy_start`, not `definition.player_spawn`. Keep `transition smithy_start_spawn` on the same wake cell as `ap.sleep.wake`.
- When a documentation contract check targets a Markdown table, isolate the bounded section before counting columns or searching for evidence-boundary phrases. Whole-file literals also occur in narrative and production hooks.
