# AGENTS.md

Critical rules for AI agents and contributors working on **Reval Rebel** (Godot 4.7 historical-fiction RPG, 1343 Reval). Details live in on-demand skills below; read one only when its trigger applies.

- Product vision and scope: [`README.md`](./README.md) (source of truth; it and this file override legacy docs)
- Work queue: the project task board (`tasks` tool) is the sole queue; claim only ready work
- Docs hub: [`docs/README.md`](./docs/README.md); features in [`docs/SYSTEMS/`](./docs/SYSTEMS/README.md); architecture in [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md); canon in [`docs/CANON.md`](./docs/CANON.md); art in [`docs/ART_BIBLE.md`](./docs/ART_BIBLE.md); setup and known defects in [`docs/SETUP.md`](./docs/SETUP.md), [`docs/reports/known_runtime_defects.md`](./docs/reports/known_runtime_defects.md)
- Role agents: [`agents/README.md`](./agents/README.md), shared protocol [`agents/WORK_PROTOCOL.md`](./agents/WORK_PROTOCOL.md), lessons in [`playbook.md`](./playbook.md)

## Read when

| Trigger | Skill |
|---------|-------|
| Running tests, validators, export, or pre-commit checks | [`agents/skills/verify-commands/SKILL.md`](./agents/skills/verify-commands/SKILL.md) |
| Touching maps, blueprints, prefabs, transitions, or map audits | [`agents/skills/map-authoring/SKILL.md`](./agents/skills/map-authoring/SKILL.md) (mandatory, includes the gate) |
| Creating a task, or implementing/changing a feature, tool, or pipeline | [`agents/skills/feature-docs/SKILL.md`](./agents/skills/feature-docs/SKILL.md) (task contract, docs, definition of done) |
| Planning features, judging scope, or finding where code/content lives | [`agents/skills/scope-and-repo/SKILL.md`](./agents/skills/scope-and-repo/SKILL.md) |

## Always

- **Never open visible Godot windows:** pass `--headless` to every Godot command; GPU captures run via `tools/godot_render.sh --script <tool>.gd`.
- Typed GDScript, small reusable scenes, composition. Scenes use `uid://` references; commit `*.import` sidecars; `.godot/` is gitignored.
- Preserve stable IDs (`quest.bitter_brew`, `char.aita`, `flag.aita_detained`, map/anchor IDs). All state is deterministic; `GameState` is the sole campaign-state store.
- No runtime LLM, procedural quests, or free-text chat. No new major system, mechanic, area, or framework without an approved ADR plus a task (see scope skill).
- **Asset freeze (P0-040):** no new or replaced legacy pixel/iso/HUD art; new art needs a task naming exact files and `assets/SOURCES.csv` rows.
- Every feature change ships its `docs/SYSTEMS/` page update in the same change; every Markdown file must be linked from `README.md` (`python3 tools/docs_index.py --check`).
- Do not hand-edit giant city `.tscn` files without visual verification. Visual changes need screenshots; when a screenshot or rendered image is available, show it to the user in Caesar via `notify_webapp` with its absolute `image_path` and a short caption, rather than reporting only a filesystem path. If the image cannot be attached, explain why and provide the path as a fallback.
- Delegated tasks must be independently verifiable and get a second review before done.
