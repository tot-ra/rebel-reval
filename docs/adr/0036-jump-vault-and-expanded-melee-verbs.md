# ADR 0036: Jump, vault and expanded melee verbs

- **Status:** Proposed (2026-10-08). Needs maintainer approval before any runtime code; nothing here is truth until a task verifies it.
- **Amends:** [`COMBAT_ANIMATION.md`](../SYSTEMS/COMBAT_ANIMATION.md) (its §9 lists directional attacks as a known limit). Does not touch ADR 0033's guilt rules: new blows are physical blows and open guilt like any other.

## Context

The hero can walk, run, swim, attack (three-step chain plus heavy), guard, sidestep and roll (forward, back, and side rolls while guarding). He cannot jump, cross a low obstacle without a detour, or vary a strike beyond the chain. The shared rig already carries unused CC0 clips for this: `Jump_Start`, `Jump_Idle`, `Jump_Land`, `Jump_Full_Short`, `Jump_Full_Long`, `Block_Attack` (a shield shove), `2H_Melee_Attack_Spin`, `Unarmed_Melee_Attack_Kick`. No new import is needed.

Gameplay runs on a 2D logic plane; the 3D view only presents it. A jump therefore cannot be free vertical physics: it must stay deterministic and cheap on the logic plane.

## Decision

1. **Vault, not free jump.** The jump verb is a scripted **hop over a low obstacle**: `Space` is already roll, so the key is set by the task (gamepad: B). A hop covers a fixed distance (`Jump_Full_Short`, ~0.9 s) in a straight line in the facing direction and only starts when the destination is free. Standing still hops in place for the animation only.
2. **Obstacles opt in.** A map object is vaultable only when its blueprint primitive carries `vaultable` with a height under a global limit (low fences, crates, stacked logs, ditches). Everything else stays a wall. Authoring goes through `MapBlueprint` primitives per [`MAP_AUTHORING.md`](../MAP_AUTHORING.md); no stable ID is renamed.
3. **Logic.** A new `JUMP` action state in `PlayerActionStateMachine`: travel is a pure function of the action clock (like the roll), `move_and_slide` keeps collision against non-vaultable bodies, vaultable bodies are skipped through a collision-mask swap for the action's duration. Landing on a blocked point cancels the hop and returns to the start position.
4. **Presentation.** The 3D rig plays the jump clips against the action clock (`sync_action_presentation`). Height is presentation-only (a parabola on the view root); the logic plane never changes elevation.
5. **Cost and exposure.** Stamina 14. Invulnerable during the airborne middle (0.2-0.55 s), punishable on landing. A jump cannot be started in swim states.
6. **Expanded strikes (same task pack, second phase).** Two new verbs on existing clips: a **shove** (`Block_Attack`, from guard, knocks back and staggers, low damage, no guilt when it hits an armed aggressor) and a **sweep/spin** finisher (`2H_Melee_Attack_Spin`, optional fourth chain step for hammer and spear). **Directional strikes** (stick direction picks the swing) are deferred.

## Equivalent scope accounting

Added: one action state, one blueprint tag, three move records, tests and docs. Removed or deferred as the offset: the **heavy-strike charge-up pose** and **directional strike variants** listed in `COMBAT_ANIMATION.md` §9 are formally parked until Act 1 ships, and **ranged aiming/reload clips** (`1H_Ranged_*`, `2H_Ranged_*`, no gameplay owner) stay unwired.

## Alternatives considered

- **Free vertical jump with gravity.** Rejected: needs a third logic axis, breaks collision/nav parity and determinism.
- **Auto-vault on walking into obstacles.** Rejected as the first step: surprises players and conflicts with click-to-move; may return as a toggle later.
- **Only visual hop, no obstacle crossing.** Rejected: the player asked for crossing obstacles.

## Consequences

- Task pack (to be created on the task board once this ADR is approved; board refs run ahead of TODO.md): (a) `JUMP` state + travel + tests, (b) `vaultable` blueprint tag, validator and one map migration (Lower Town fences) with the pre-commit map gate, (c) rig clips and blends, (d) shove and spin moves with `CombatMoveCatalog` records and tests, (e) docs in `COMBAT_ANIMATION.md` and `CONTROLS.md`, new default bindings with a bindings-version bump.
- Verification per task: `--filter=test_combat_animation`, `test_player_action_state_machine`, map gate commands from `AGENTS.md`, and a captured state of the hop.
