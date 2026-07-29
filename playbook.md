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
