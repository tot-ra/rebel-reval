# Quest playbook

Read `agents/playbook.md` first for shared workflow, tooling, and Git lessons.
This file contains lessons specific to the Quest role.

## Role-specific lessons
- When asserting Act 1 / save identity after `SaveService` reload, compare remembered fields (`act_boundary`, quest state, flags, validated envelope) rather than raw `Dictionary` equality: JSON round-trip widens ints to floats and can reorder keys even when the save is correct.
- Default session equipment can support charged attacks, which swing on button *release*. A click-path test that only sends the press sees `State.MOVE` and looks like a broken attack; drive the full press/release pair instead.
- Generated quest traversal tests inherit the renderer's existing lines over the 100-character lint cap; a scoped add of new generated packages can therefore fail the staged hook even when generator checks and Godot tests pass. Keep generated output canonical and do not widen the task to reformat unrelated packages; record a follow-up for renderer/lint alignment, then use a scoped no-verify commit only after diff and focused tests are green.
- When wrapping generated GDScript arrays, keep commas in exactly one layer of the renderer: either each item or the join separator, never both. Run the scoped gdtoolkit parser after regeneration because Python checks cannot catch invalid generated syntax.
- Forward Godot harness filters after the script argument separator (`-- --filter=...`); placing `--filter` before the separator is ignored and can run the unrelated full suite.
