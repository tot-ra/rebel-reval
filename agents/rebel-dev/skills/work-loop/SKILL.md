---
name: rebel-dev-work-loop
description: Claim, implement, verify, and report scoped Reval Rebel runtime-development tasks.
---

# Rebel Developer Work Loop

1. Scan `TODO.md` for claimable `role: dev` rows. Dependencies must be `- [x]`; content dependencies therefore already carry canon approval. If no row qualifies, stop.
2. Claim the highest-priority eligible row by flipping it to `- [~]` and appending `claim: dev-N@<date>` before editing.
3. Implement the scoped behavior in typed GDScript with scene-local composition. Preserve these constraints: no runtime LLM, GameState is the sole campaign-state store, 3D is derived presentation only, autoloads require justification, and content loads through ContentDB. Follow the map-authoring contract for all map-adjacent work.
4. Run `godot --headless --script tools/run_godot_tests.gd`. Add or revise automated tests for the new behavior and its relevant failure modes. Run every additional command required by the task and AGENTS.md, especially the mandatory map validation block for map work.
5. Add a concise change note to `docs/ROADMAP.md` when the delivered milestone status or behavior requires it. On success, clear the claim tag and flip the row to `- [x]`.
6. If blocked, flip the row to `- [!]` and append `blocked: <reason>`.

## Completion standard

All required tests pass, new player-visible behavior has appropriate coverage, and no architectural constraint or approved scope boundary is violated.
