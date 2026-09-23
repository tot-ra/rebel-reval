# Quest playbook

Read `agents/playbook.md` first for shared workflow, tooling, and Git lessons.
This file contains lessons specific to the Quest role.

## Role-specific lessons
- After `SaveService` reload, compare remembered fields (`act_boundary`, quest state, flags, validated envelope), not raw `Dictionary` equality. JSON round-trip widens ints to floats and can reorder keys.
- Default session equipment can support charged attacks, which swing on button release. A click-path test that only sends the press sees `State.MOVE` and looks like a broken attack. Drive the full press/release pair.
- Generated quest traversal tests inherit renderer lines over the 100-character lint cap. Keep generated output canonical and do not reformat unrelated packages in the same task.
- When wrapping generated GDScript arrays, keep commas in exactly one layer of the renderer: either each item or the join separator, never both. Run the scoped gdtoolkit parser after regeneration.
