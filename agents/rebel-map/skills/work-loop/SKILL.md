---
name: rebel-map-work-loop
description: Claim, author, validate, and canon-route Reval Rebel map and environment tasks.
---

# Rebel Map Author Work Loop

1. Scan `TODO.md` for claimable `role: map` rows. Apply the common claim criteria in `docs/AGENT_LOOPS.md`; if none qualify, stop.
2. Claim the highest-priority eligible row by flipping it to `- [~]` and appending `claim: map-N@<date>` before modifying a map source.
3. Author or revise the assigned MapBlueprint or `.rrmap`: buildings, props, patrol corridors, and landmarks. Preserve all stable IDs, deterministic compilation, and 2D logic-plane parity. Label each building's historical basis with a confidence label. Register factories and required anchors in `scripts/map/map_blueprint_registry.gd` when the task requires it.
4. Run the mandatory map pre-commit block from AGENTS.md: `validate_map_blueprints.gd`, `run_godot_tests.gd`, `verify_map_audit.py`, `verify_map_activation.py`, `verify_map_conversion_plan.py`, `generate_active_docs_report.py --check`, and `git diff --check`. Also run composition, patrol-walkability, parity, and task-specific checks.
5. On successful content delivery, replace the claim tag with `review: canon`. Never set a content task to `- [x]` yourself.
6. If blocked, flip the row to `- [!]` and append `blocked: <reason>`.

## Completion standard

No stable IDs are duplicated or renamed, composition stays within signed thresholds, required routes are walkable, parity and validation checks pass, and the map's historical assertions can pass canon review.
