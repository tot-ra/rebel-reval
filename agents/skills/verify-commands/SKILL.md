---
name: rebel-verify-commands
description: Cheat sheet of Reval Rebel test, validator, docs, asset, map, performance, and export commands. Read when you need to run checks before a commit.
---

# Verification commands

Godot is pinned to **4.7** ([`.godot-version`](../../../.godot-version)); install per [`docs/SETUP.md`](../../../docs/SETUP.md) (full CLI reference and `GODOT_BIN` setup there). Every Godot command passes `--headless`; GPU captures run as `tools/godot_render.sh --script <tool>.gd`.

| Purpose | Command |
|---------|---------|
| Headless import / startup smoke | See `docs/SETUP.md` (`--check-only` hangs, `DEF-001`) |
| Godot tests | `godot --headless --path . --script tools/run_godot_tests.gd` (runs `tests/godot/test_*.gd`) |
| Content validator | `python3 tools/validate_content.py content/examples/valid content/examples/support` |
| Content validator tests | `python3 -m unittest tests.python.test_validate_content -v` |
| Content schema examples | `python3 tools/validate_content_examples.py` |
| Active docs / links | `python3 tools/generate_active_docs_report.py --check` |
| Docs reachable from README | `python3 tools/docs_index.py` (regenerate index blocks), `python3 tools/docs_index.py --check` |
| Physical object catalog | `python3 tools/validate_object_catalog.py`, `python3 -m unittest tests.python.test_object_catalog -v`; browse and edit with `python3 tools/object_catalog.py` (see [`docs/SYSTEMS/OBJECT_CATALOG.md`](../../../docs/SYSTEMS/OBJECT_CATALOG.md)) |
| Asset provenance / lint | `python3 tools/validate_asset_sources.py`, `python3 tools/verify_asset_lint.py` |
| Storage hygiene | `python3 tools/verify_storage_hygiene.py` |
| Map composition audit | `python3 tools/verify_map_composition.py` |
| World-layout manifest | `godot --headless --path . --script tools/build_world_layout.gd -- --check`; `python3 tools/verify_world_layout.py`; `python3 -m unittest tests.python.test_verify_world_layout` |
| Legacy archive headers | `python3 tools/archive_speculative_docs.py --dry-run` (no output = OK) |
| Performance report | `tools/run_performance_report.sh [out.json] [--quick]` (see `docs/PERFORMANCE_REPORT.md`) |
| Pre-commit gates | `tools/run_pre_commit_checks.sh [staged\|all]` |
| Export | `mkdir -p build && godot --headless --export-release "rr" ./build/rr.dmg` |

Tests use the repository's own harness (no GUT). Add `tests/godot/test_*.gd` files with zero-argument `test_*` methods; shared assertions are in `tests/godot/test_case.gd`. Add runtime JSON under `content/` only when it passes `tools/validate_content.py`. CI (`.github/workflows/ci.yml`) runs these checks plus a macOS export smoke. Codesigning is not configured.

Map changes have their own gate: [`agents/skills/map-authoring/SKILL.md`](../map-authoring/SKILL.md).
