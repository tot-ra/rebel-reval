# Playbook

## Tooling

- If project file indexing is disabled, skip `file_search` and use targeted `find_files`, `grep`, or `rg` searches instead.
- In `code_execution`, avoid relying on helper functions from comprehensions because the execution wrapper may isolate their scope; use explicit loops or inline calculations.
- Godot headless filters must use user args after `--`: `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_name`. Passing `--filter=` before `--` makes Godot ignore it and run the full suite.
- When Hunyuan3D/ComfyUI image-to-3D is unavailable, ship catalog-proportion Blender fauna GLBs with PBR maps and reference plates, then add an optional Hunyuan follow-up (`P2-034a` pattern) instead of blocking the batch.
- Blender glTF export with packed textures still yields Godot-extracted `*_albedo.png` / `*_normal.png` / `*_roughness.png` sidecars; register those derived paths in `assets/SOURCES.csv` or provenance validation fails.
- On macOS, `godot` is often not on `PATH`; use `/Applications/Godot.app/Contents/MacOS/Godot` or set `GODOT_BIN` before running headless tests or map pipeline scripts.
- After adding fauna/prop GLBs, run `godot --headless --path . --import` before Godot tests; `ResourceLoader.exists` stays false until `.import` sidecars exist.
- Bird authored-mesh allowlists live in `tests/godot/test_map_view_bird_meshes.gd`; update them in the same change as new `assets/birds/**` GLBs or CI fails.
- For catalog birds with exact `MapViewBirdSpecies` metrics, prefer deterministic Blender generators over Hunyuan when prior animal candidates were rejected for topology; keep an optional Hunyuan follow-up row.
- If `run_godot_checked.sh` fails without surfaced output, inspect the wrapper and its saved log before retrying so the original diagnostic is preserved.
- When the full Godot harness exceeds the available timeout, inspect its saved log, report the last completed test, and rely on clean focused suites rather than immediately repeating the same long run.
- Blender's bundled Python often lacks Pillow; compose multi-species fauna reference sheets with host `python3` + Pillow after the Blender generator writes per-species EEVEE previews, rather than failing the batch when in-process sheet composition returns `None`.
- Never open `assets/SOURCES.csv` with mode `w` until the replacement row list is fully built; a failed `DictWriter` after truncate can wipe provenance. Prefer write-to-temp then rename, or build rows before opening for write.
- `tools/run_godot_checked.sh` expects `tools/run_godot_checked.sh [--require-test-summary] <log-name> -- <godot-command> [args...]`; setting `GODOT_BIN` alone does not supply its required log-name or command arguments.
- When inserting many rows into a hot shared file like `TODO.md`, prefer one atomic Python rewrite and immediately assert the new IDs exist; Cursor `StrReplace` success alone is not enough if another writer can race the file.
- Do not treat a substring match for a new task ID (for example `P0-163` inside a `deps:` list) as proof that the task row itself was inserted.
- Before `git commit`, inspect `git status` for already-staged unrelated files (`M ` in the first column); unstage them or the commit will absorb them.
- When allocating new `TODO.md` IDs, also scan open `docs/ROADMAP.md` coordination notes and other tracks that may have just claimed nearby IDs (for example cart `P0-164` / `A-010` / `P4-037` versus Toompea work). After write, assert each new ID has exactly one deliverable row, not only `deps:` / `production:` mentions.
- Solid history dossiers need Producer follow-up rows that name the target map anachronism and Brief ship decisions; closing `R-###` alone does not put historically accurate fabric into the game.
- Discover focused test paths before reading them; do not infer filenames from runtime class names because smithy ambient coverage is grouped in `test_smithy_ambient_actors.gd`.
- In Python diagnostic snippets, precompute regex matches before formatting; backslashes inside f-string expressions cause a SyntaxError.
- The parallel tool accepts at most 12 steps per call; split larger exploration batches before dispatch.
- When validating YAML-like text, match full keys/values with anchored regexes; substring checks such as `mode: all` also match valid `mode: allow`.
- Before editing from a summarized audit, re-read the exact target line; a stale assumption can turn an already-correct permission into a failed replacement.
- After programmatic regex edits, inspect the saved source representation and run a tiny fixture immediately; doubled backslashes in raw strings can silently change whitespace matching into literal text matching.
- When a Producer-only TODO/ROADMAP tick makes the active Markdown report stale, create a bounded QA report-refresh row instead of editing the generated report outside Producer ownership.
- When a TODO allowlist names only `map_blueprint_compiler.gd` for a new typed style key, also update `map_blueprint_compiler_build.gd` (field copy) and `map_blueprint_compiler_expand_geometry.gd` / expand validation, or the key parses but never reaches `MapDefinition` and rejection tests stay red.
- Godot contract tests that assert documentation phrases are case-sensitive; match the exact casing used in the report (`Late-Gothic` vs `late-Gothic`) rather than assuming title-case variants.
