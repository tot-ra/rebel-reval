# Historical door visual pass

## Design basis

The ordinary house and smithy door uses restrained fourteenth-century Tallinn construction rather than later decorative Gothic tracery. The closest surviving local comparison is the King's Chapel door in Tallinn Dome, described as vertical pine planks joined by inclined bars with an outer oak board layer:

- Alar Läänelaid, Juhan Kilumets, Andres Uueni, and Paul Borghaerts, "Investigating the age of the door of the King's Chapel in Tallinn Dome," *Dendrochronologia* (2025), https://doi.org/10.1016/j.dendro.2025.126462.

The game model translates that evidence into separate vertical boards, inner inclined braces, two forged strap hinges, visible hinge barrels and rivets, a simple latch and ring pull, and a timber frame. Ornamental church or castle ironwork is intentionally excluded from ordinary Lower Town doors.

## Runtime implementation

- `scripts/map/view3d/map_view_door_builder.gd` owns shared procedural leaf, frame, and hardware geometry.
- `scripts/map/view3d/map_view_material_patterns.gd` generates deterministic longitudinal wood grain, knots, worn edges, and a normal map.
- House facade and transition-door builders use the same construction at their authored dimensions.

## Reproduction and evidence

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/capture_door_preview.gd
```

Preview: `docs/reports/images/view3d/doors/historical_door_closeup.png`

Verified in a clean detached worktree from the task base:

- Godot 4.7.1 headless import: pass
- `test_map_view_3d_mesh`: 18 tests, 0 failures, 0 errors
- `test_map_view_3d_fortification`: 8 tests, 0 failures, 0 errors
