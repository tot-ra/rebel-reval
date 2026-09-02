# Playbook index

The project playbook is split by agent ownership so each role loads only relevant lessons.

- Shared workflow, tooling, and Git lessons: [`agents/playbook.md`](agents/playbook.md)
- Art: [`agents/rebel-art/playbook.md`](agents/rebel-art/playbook.md)
- Canon: [`agents/rebel-canon-keeper/playbook.md`](agents/rebel-canon-keeper/playbook.md)
- Character: [`agents/rebel-character/playbook.md`](agents/rebel-character/playbook.md)
- Development: [`agents/rebel-dev/playbook.md`](agents/rebel-dev/playbook.md)
- Dialogue: [`agents/rebel-dialogue/playbook.md`](agents/rebel-dialogue/playbook.md)
- Map: [`agents/rebel-map/playbook.md`](agents/rebel-map/playbook.md)
- Narrative: [`agents/rebel-narrative/playbook.md`](agents/rebel-narrative/playbook.md)
- Production: [`agents/rebel-producer/playbook.md`](agents/rebel-producer/playbook.md)
- QA: [`agents/rebel-qa/playbook.md`](agents/rebel-qa/playbook.md)
- Quest: [`agents/rebel-quest/playbook.md`](agents/rebel-quest/playbook.md)
- Research: [`agents/rebel-researcher/playbook.md`](agents/rebel-researcher/playbook.md)

New lessons must be appended to the shared playbook or the narrowest relevant role playbook. Do not rebuild identical copies across every agent.
- A temporary Godot navigation probe can fail before running when a loop iterator name is redeclared in the same scope; inspect the saved log and use distinct iterator names before classifying the engine bake result.
- 2026-08-25: Campaign save manifests may intentionally keep legacy migration inputs at an older raw game-state version; acceptance tests must run the SaveEnvelope migration path or explicitly separate raw legacy rows from current envelopes instead of asserting raw JSON equals the current schema version.
- 2026-08-25: When a CLI accepts an alternate file path, confirmation output should use the selected basename; tests must exercise a non-default filename so hard-coded success messages cannot pass unnoticed.
- 2026-08-25: When inserting a CLI regression test into an existing unittest class, keep it as a separate method and re-read the class tail before running tests; an insertion inside the prior method can silently move existing assertions.
- 2026-08-26: When reconstructing a scoped staged patch from temporary clean/current blobs, normalize all temporary absolute paths in `diff --git`, `---`, and `+++` headers before `git apply --cached`; changing only one header or leaving `/tmp` paths makes a valid patch fail without changing the index.
- 2026-08-27: When an exact edit misses after nearby serial changes, re-read the live bounded block before retrying; stale indentation/context can make a valid remaining lint fix report no match even though earlier edits succeeded.
- 2026-08-29: Before reading a project guidance or playbook file, pass the exact discovered file path; a malformed composed path can produce a misleading stat error and waste an investigation step.
- 2026-08-29: When a compound shell heredoc/printf probe exits silently, classify it as an invocation failure and split each check into independent commands before treating any evidence or repository state as tested.
- 2026-08-29: If a parallel tool batch is rejected before execution (for example, using `tool_uses` with `functions.parallel` instead of its `steps` schema), discard its result and rerun each independent check with the correct wrapper; do not infer repository state from a failed invocation.
- 2026-08-29: A malformed parallel-wrapper invocation (`functions.parallel` passed through the multi-tool `tool_uses` schema) fails before any diagnostic runs; discard that result and rerun independent checks with the wrapper's documented schema before classifying repository state.
- 2026-09-02: After inserting a regression test into an existing unittest class, re-read the complete neighboring method boundaries and confirm the test count before running the focused suite; replacing only a method header can silently absorb the next method body.
