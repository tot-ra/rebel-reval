---
name: rebel-feature-docs-and-done
description: Task contract, mandatory feature documentation, and definition of done for any Reval Rebel task that creates a task or implements/changes a feature, tool, or content pipeline.
---

# Task contract, feature docs, definition of done

## Task contract

Every delegated task must be independently verifiable ("improve combat" is invalid). Each task states: player-facing goal, allowed files, dependencies (task IDs and content IDs), constraints and non-goals, deliverable, exact verification (command, test, or screenshot), and the doc file that will document the feature.

Use `tasks.create` with dependencies, allowed files, deliverable, constraints, and verification; claim only ready work. Readiness and claim rules: [`agents/WORK_PROTOCOL.md`](../../WORK_PROTOCOL.md).

## Feature documentation (mandatory)

Every task that implements or changes a feature ships its documentation in the same change. A feature is any player-facing behavior, gameplay system, content pipeline, or tool other agents will run. Code, tests, and the task board are not documentation.

- **Where:** extend the feature's owning page in [`docs/SYSTEMS/`](../../../docs/SYSTEMS/README.md) (or `docs/CONTROLS.md`, `docs/MAP_AUTHORING.md`). For a new area, create `docs/SYSTEMS/<FEATURE>.md` and add it to the `docs/SYSTEMS/README.md` status table and the [`docs/README.md`](../../../docs/README.md) hub.
- **Header:** `Status: implemented (task **R-NNNN**)`, plus scope and what is out of scope. Use [`docs/SYSTEMS/QUESTS.md`](../../../docs/SYSTEMS/QUESTS.md) or [`COMBAT_ANIMATION.md`](../../../docs/SYSTEMS/COMBAT_ANIMATION.md) as the model.
- **Body:** what the player or agent can do and how (inputs, commands), the runtime entry points (scripts, scenes, autoloads), the data and stable IDs it reads or writes, save/load behavior, how to verify it (test file or command), and known limits.
- **Keep it true:** when a task changes or removes behavior, update or retire the matching section in the same change. A design doc for an unbuilt system says `Status: planned` until the code lands. Code that is built but not mounted in a scene goes under the page's **Limits** and in the latest code-health audit (`docs/reports/code_health_audit_*.md`), and gets a task to wire it or delete it.
- **Linked:** every Markdown file, including characters, lore, history, and reports, must be reachable by links from the root `README.md`. Link new pages from their folder's index page, then run `python3 tools/docs_index.py`. `--check` fails on any orphan.
- New or renamed docs under `docs/` also change the active-docs report: regenerate it with `python3 tools/generate_active_docs_report.py` and confirm `--check` passes.

## Definition of done

- Player-visible behavior satisfies the task's `verify` line
- Tests or validators cover state transitions and failure modes
- Keyboard/mouse and gamepad paths are checked where input applies
- Save/load is verified when persistent state is touched
- Every implemented or changed feature is documented per **Feature documentation** above; active docs and stable IDs are updated in the same change
- New assets have source, rights, and approval rows in `assets/SOURCES.csv`
- Visual changes include screenshots or captured states
- No unrelated systems or speculative abstractions were added
- A second reviewer (human or agent) confirms correctness, simplicity, and scope
