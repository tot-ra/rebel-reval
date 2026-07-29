# Playbook

## Tooling

- If project file indexing is disabled, skip `file_search` and use targeted `find_files`, `grep`, or `rg` searches instead.
- In `code_execution`, avoid relying on helper functions from comprehensions because the execution wrapper may isolate their scope; use explicit loops or inline calculations.
- On macOS, `godot` is often not on `PATH`; use `/Applications/Godot.app/Contents/MacOS/Godot` or set `GODOT_BIN` before running headless tests or map pipeline scripts.
