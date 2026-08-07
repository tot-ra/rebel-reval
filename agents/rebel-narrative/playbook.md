# Narrative playbook

Read `agents/playbook.md` first for shared workflow, tooling, and Git lessons.
This file contains lessons specific to the Narrative role.

## Role-specific lessons
- When asserting Act 1 / save identity after `SaveService` reload, compare remembered fields (`act_boundary`, quest state, flags, validated envelope) rather than raw `Dictionary` equality: JSON round-trip widens ints to floats and can reorder keys even when the save is correct.
- An NPC "standing on the smithy anvil" is usually an authored anvil-bound activity (`ap.visitor.inspect` / `ap.forge.anvil`) whose `approach_position` sits inside `forge_anvil` footprint, not a stray spawn; in prologue prefer Henning inspect over Mart (Mart stays hidden while `flag.mart_missing`).
- Renaming a `docs/CANON.md` heading breaks auto-generated anchors used by active docs (`BROKEN_ANCHOR`); keep a stable HTML `<a id="...">` alias for the old slug (for example `timeline-aprilmay-1343`) when widening a timeline section, then re-run `python3 tools/generate_active_docs_report.py --check`.
- New Game places the player via DoorNavigator spawn `smithy_start`, not `definition.player_spawn`. Moving only `spawn.main` leaves Kalev at the anvil; keep `transition smithy_start_spawn` on the same wake cell as `ap.sleep.wake` / bed foot.
- When a documentation contract check targets a Markdown table, isolate the bounded section before counting columns or searching for evidence-boundary phrases; whole-file literals also occur in narrative and production hooks and can produce false failures.
