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
- 2026-08-26: When reconstructing a scoped staged patch from temporary clean/current blobs, normalize all temporary absolute paths in `diff --git`, `---`, and `+++` headers before `git apply --cached`; changing only one header or leaving `/tmp` paths makes a valid patch fail without changing the index.
