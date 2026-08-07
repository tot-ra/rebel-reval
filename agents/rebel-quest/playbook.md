# Quest playbook

Read `agents/playbook.md` first for shared workflow, tooling, and Git lessons.
This file contains lessons specific to the Quest role.

## Role-specific lessons
- When asserting Act 1 / save identity after `SaveService` reload, compare remembered fields (`act_boundary`, quest state, flags, validated envelope) rather than raw `Dictionary` equality: JSON round-trip widens ints to floats and can reorder keys even when the save is correct.
- Default session equipment can support charged attacks, which swing on button *release*. A click-path test that only sends the press sees `State.MOVE` and looks like a broken attack; drive the full press/release pair instead.
