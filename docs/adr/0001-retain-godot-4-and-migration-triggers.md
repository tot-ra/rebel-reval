# ADR 0001: Retain Godot 4.x and define migration triggers

**Reference:** TODO P0-003

## Status
Accepted

## Context
The project is currently being developed using the Godot 4.x engine. Godot provides a strong balance of features, quick iteration times, and an accessible scripting environment (GDScript), which is beneficial for our current development phase. However, as the project grows in complexity, scale, or target platforms, there is a risk that Godot 4.x might present hard limitations. To ensure the long-term viability of the project without prematurely incurring the high cost of an engine migration (e.g., to Unity, Unreal Engine, etc.), we need to explicitly commit to Godot 4.x for now while defining clear, measurable conditions under which a migration would be justified.

## Decision
We will retain Godot 4.x as our primary game engine for the foreseeable future. We will not migrate to a different engine unless specific, critical blockers arise. To objectively evaluate when a migration is necessary, we define the following measurable migration triggers:

1. **Repeatable Performance Limits:** We encounter engine-level performance bottlenecks that prevent the game from maintaining the target frame rate (e.g., 60 FPS) on target hardware, despite exhausting all standard optimization techniques.
2. **Tooling Blockers:** Critical workflow or tooling capabilities are missing and cannot be reasonably implemented via engine plugins, leading to a significant, sustained drop in team productivity.
3. **Export Failures:** The engine completely fails to build, export, or pass certification for critical target platforms (such as specific consoles), directly threatening the project's release strategy.
4. **Team Workflow Blockers:** The engine's handling of assets or scenes introduces insurmountable version control conflicts or data corruption that prevents the team from collaborating effectively.

If any of these triggers occur and are verified to be engine-level limitations with no viable workarounds, the team will initiate a formal evaluation for engine migration.

## Alternatives
- **Migrating immediately to another engine (e.g., Unity, Unreal):** Rejected. This would incur a massive, immediate cost in time and resources for porting the existing codebase, retraining the team, and resetting the project momentum, which is unjustified given our current progress with Godot 4.x.
- **Staying with Godot 4.x unconditionally:** Rejected. Refusing to acknowledge potential engine limitations could trap the project in an un-shippable state if critical blockers are discovered late in development. Defining triggers provides a safety valve.

## Consequences
- Development continues smoothly on Godot 4.x without the disruption of an engine switch.
- The team must stay vigilant and monitor the project against the defined migration triggers, especially during major scaling phases or when testing on new target platforms.
- We accept the risk that if a trigger is hit later in development, the cost of migration will be higher than it is today, but we consider this risk acceptable compared to the guaranteed high cost of an immediate, unprompted migration.
