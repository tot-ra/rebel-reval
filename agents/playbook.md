# Shared agent playbook

Read this file together with the role-specific `agents/rebel-*/playbook.md` before working.
This file contains only cross-role operating lessons. Domain lessons belong to the agent that owns that work.

Keep this file short. Append a durable reusable rule, not a dated incident log. If the same lesson already exists, do not add another dated copy.

## Shared workflow and tooling

### Instruction conflicts
- When instruction blocks conflict (delegate to sub-agents vs do not call them; `suggest_git_commit` vs commit-and-push), follow the more specific project or session constraint and state the conflict once.

### Edits
- Never run parallel edits against the same file. Serialize replacements and re-read the saved block.
- Before an exact edit, read the live unique block. After any nearby change, re-read again. Stale context is the usual no-match cause.
- Pass the complete file path, not a directory. `read` takes one path per call. `start_line` must be `<= end_line`.
- After inserting a test or helper, re-read neighboring method boundaries and confirm the next `func` / `def` header is still present. Replacing only a header can absorb the following body.
- Discover the actual path before reading. Do not infer filenames from class names, task summaries, or the connected-skills directory. The active guide is root `AGENTS.md`.
- No-op replacements (identical old and new text) are rejected. Apply only a non-empty delta.

### Tool batches and probes
- If a parallel batch fails before execution (wrong schema, missing tool, malformed path), discard the batch and rerun each check independently. Do not infer repository state from a wrapper error.
- A silent compound shell or heredoc failure is an invocation failure. Split checks into independent commands with captured status.
- `grep` a line that starts with `-` using `--` or `-e`. Guard expected-empty searches with `|| true` under `set -e`.
- On macOS, GNU `timeout` may be missing (exit 127). Use a Python subprocess watchdog. Never kill unrelated long-running processes.
- `code_execution` may isolate helpers and imports. Keep diagnostics inline or use project `python3` via bash.
- Stateful browser actions cannot run through a parallel wrapper.
- Markdown backticks inside a double-quoted bash string are command substitution. Write SQL or task-board updates with Python or a single-quoted heredoc. A backtick path can execute a file and silently blank the intended text.

### TODO hygiene
- For the current `TODO.md` sectioned format, run `python3 tools/prune_completed_todo.py` to append completed rows to `docs/TASK_ARCHIVE.md`. Do not run `tools/condense_todo.py` unless deliberately migrating to the condensed open-only layout (it rewrites `docs/ROADMAP.md`).
- Map-conversion strict-task IDs (`P0-043`..`P0-046`, `P2-018`..`P2-021`, `P4-014`, `P4-015`) and the `P2-012` -> `P2-021` gate may live in `docs/TASK_ARCHIVE.md`. The audit and conversion-plan validators treat archived full-contract rows as completed. Do not copy archived rows back into `TODO.md` to go green.

### Git and commits
- Inspect `git status` before commit. Unstage unrelated index entries (`M ` in column 1).
- Repo-wide path rewrites must skip `.worktrees/` and `build/`. Prefer scoped `tools/assets/relocate_*_per_model.py` helpers over ad-hoc `rglob` sweeps when colocating GLBs into per-model folders.
- `git commit --only <paths>`: keep every `-m` before `--`. It commits working-tree bytes of those paths, not a prepared index snapshot. Untracked paths must be `git add`ed first; `--only` cannot create a commit from unknown files. For a HEAD-plus-scope commit in a dirty file, keep the scoped bytes in the path through the commit, or commit a temporary index without `--only`.
- In a dirty shared worktree, build a HEAD-plus-scope tree with a temporary `GIT_INDEX_FILE` when the working file has concurrent WIP. Normalize `diff --git`, `---`, and `+++` paths before `git apply --cached`.
- When an isolated verification worktree is fed by copying files from a dirty shared tree, rebuild every shared file from HEAD plus your own hunks each time. Do not re-copy the whole working file: a second copy can bring in another agent's half-finished edits (for example an `#include` of a file that is not there yet) and silently invalidate later tests and captures.
- `git diff --no-index` status 1 is a valid new-file diff. Run whitespace checks separately.
- `git diff --cached --check` rejects Markdown hard-break spaces and an extra blank line at EOF. Strip trailing spaces; keep exactly one trailing newline. Scope the pathspec so unrelated dirty files cannot block the check.
- Staging `scripts/map/**` triggers the map audit. If the hook fails on unrelated scene or TODO drift after scoped checks pass, use documented `SKIP_PRE_COMMIT=1` / `git commit --only --no-verify`. Do not absorb audit WIP.
- On-commit gdlint checks every staged `*.gd` file, including `scenes/**`. Wrap new `max-line-length` rows there. CI only lints `scripts/*/*.gd`, so `SKIP_PRE_COMMIT=1` is for `tests/`, `tools/`, and scene-script drift that CI does not lint.
- `git commit --only` exports `GIT_INDEX_FILE` into hooks. Fixture-repo Git tests must clear `GIT_DIR` / `GIT_INDEX_FILE` / `GIT_WORK_TREE`.
- Do not `git checkout HEAD --` a hot shared file while other dirty scripts already call its new APIs. Do not mid-task `git stash` with fragile pathspecs.
- After a temporary-index commit, move only the branch ref. Do not `git reset --soft` in the live checkout.
- After that commit, `unset GIT_INDEX_FILE` and `git restore --staged -- <your paths>` on the live index. The shared index can still hold those paths as staged deletes or leftover adds; the next shared commit would then revert the files you just pushed.
- If a path-limited commit exits silently, inspect `HEAD` and hooks separately before retrying.
- When several agents relocate GLB folders in one worktree, expect `.git/index.lock`, half-finished `git mv`, and empty asset dirs. Do not `git checkout HEAD -- assets/props/<area>/` until the lock is gone; restore from `origin/main` for that subtree, consolidate duplicates with a filesystem move, then stage only the scoped pathspec before commit.

### Godot and Python verification
- Export `GODOT_BIN` in a preceding command (macOS: `/Applications/Godot.app/Contents/MacOS/Godot`). Inline `GODOT_BIN=... "$GODOT_BIN"` expands the old empty value and exits 127.
- Stale Godot tests often fail parse before runtime when APIs move: check enum renames (`RoutineState` -> `ActivityMode`), removed static helpers (`water_surface_height()` -> `MapViewMeshBuilderConfig` constants), and harness helpers (`assert_almost_eq`, `_assert_true` in custom RefCounted tests).
- Typed GDScript parse failures: a later `:=` in a loop (`entry := dir.get_next()`) is illegal after the first declaration, use `=`. Annotate chained `.to_dict()` after `snapshot_state()` as `Dictionary`; that helper returns `RefCounted` and `:=` cannot infer the type.
- Pre-commit runs `verify_map_audit.py` for any staged `scripts/map/**` file. When map audit is already red on `main`, keep production fixes in tests or non-map modules, or repair audit inventory first.
- `tools/run_godot_checked.sh [--require-test-summary] <log-basename> -- <godot-command>`. The log name is a basename, not `/tmp/...`. The command after `--` must start with `"$GODOT_BIN"` (usually `--headless --path .`). Harness `--filter=stem` must come after a second `--` so `OS.get_cmdline_user_args()` sees it; otherwise the full suite runs.
- The harness is `tools/run_godot_tests.gd`. `--filter` matches `test_*.gd` file stems, not method names. Pass one `--filter=stem1,stem2` token. Repeated `--filter name` flags are ignored and the full suite runs.
- Fresh worktrees need `godot --headless --path . --import` before tests (global class cache).
- Do not run ordinary Node or RefCounted scripts with `--script`; they do not quit. Use the harness.
- A green focused summary can still fail the checked runner on unrelated parse errors. Report the scoped result separately from the baseline blocker.
- Never launch Godot with a visible window. Use `--headless` for tests, imports, and smokes. Run anything that needs real rendering (captures, render probes) as `tools/godot_render.sh --script <tool>.gd`: it starts the window minimized without focus. Do not hide or minimize the window from a script (it flashes first), and do not write `override.cfg` into the repo root.
- Visual capture helpers can exit 0 despite `SCRIPT ERROR`. Treat output as invalid until the log is clean. Do not run a rendering-capable capture in parallel with another Godot process: concurrent GPU use can write black PNGs that still exit 0. Check file size or pixel extrema before treating plates as evidence. A 1440x810 plate near 20 KiB is an empty or mis-aimed camera, not a valid character shot.
- `gdlint -d` only outside the repo. A root `gdlintrc` shadows `.gdlintrc`.
- CI runs `gdlint scripts/**/*.gd` in bash without globstar, so only `scripts/*/*.gd` is linted. Keep that depth-2 set clean; a passing staged-file hook does not prove the CI glob is green.
- `python3 tools/manage_lfs_assets.py verify` compares indexed LFS pointers to `docs/lfs_assets.json`. After a research plate is recompressed or replaced, update that row's `size_bytes` / `sha256` / `lfs_oid` from `git show :path`. Fetched `plates.csv` rows join the snapshot only when the pointer SHA already matches the CSV.
- `python3 -m unittest discover -s tests/python` collects live-inventory modules that fail on baseline drift. Run the documented fast contract subset on commit.
- Piping unittest to `tail` hides exit status. Use `PIPESTATUS` or a dedicated failure runner.
- Campaign save fixtures with `source_game_state_version` are raw migration inputs. Assert the raw version, or run the `SaveEnvelope` migration path. Do not require raw JSON to equal the current envelope version.
- When a CLI accepts an alternate path, tests must exercise a non-default filename and assert the selected basename.

### Task board
- Identity is the internal `R-*` ref, not a product ID (`P0-122f`) or a prose label (`R-454a`). Resolve with `tasks.list` before `tasks.get`.
- `tasks.next` does not honor complexity or role filters. Restore a wrongly claimed row with its full body, then claim the exact ref.
- If `tasks.create` fails with `UNIQUE constraint failed: tasks.project_id, tasks.ref (2067)` (2067 is the SQLite code, not a ref), the project's `max(seq)` lags its highest `R-*` ref. Check `select ref, seq from tasks where project_id=... order by seq desc limit 3` in `aagent.db`, set the top row's `seq` to its ref number, and retry. Never create board rows in parallel.
- Create dependency chains sequentially and verify each returned ref. An empty `body` on update erases the contract. If a mutation times out, query the exact ref before retrying.
- When the `tasks` tool is unavailable in Cursor, read or update the project board through `~/.local/share/aagent/aagent.db` with the session `project_id`; do not infer open work from `TODO.md` alone.
- Before coding an open `R-*` row, grep `TODO.md` for the product ID (`P0-226`); if it is already `[x]`, run the task `verify` clause headlessly and close the board row instead of re-implementing.
- Parser or compiler blockers filed as open `R-*` rows may already be fixed on `main` while reports still cite August diagnostics. Run `test_map_rrmap_parser`, `tools/validate_map_blueprints.gd`, and the named focused suites before landing duplicate parser work; close with a dated `docs/reports/r*_*.md` ledger when code is already green.

### Documentation, provenance, and evidence
- `tools/validate_content.py` validates JSON corpus roots, not Markdown reports.
- Hub indexes such as `history/RESEARCH_INDEX.md` have their own heading and link contract, not generic front matter.
- Do not regenerate `docs/reports/active_markdown_report.md` from a scoped dirty worktree. Unrelated Markdown WIP changes the excluded-file count.
- Rights-sensitive media requires record-level commercial terms or written permission. Regional metadata or CC BY-NC is not enough. Preserve the verified fallback.
- Prefer dated face plates under `docs/reports/images/characters/face_*.png` over older `closeup_*.png`.
- Never rewrite all of `assets/SOURCES.csv`. Append or replace only target rows. SHA-256 lives in `prompt_or_url`. `csv.writer` defaults to CRLF even on macOS; pass a Unix `lineterminator` when appending.
- Do not commit provenance for untracked WIP assets. Do not overwrite `build/act1/rr.dmg`.
- Tracked `generated/` is not uniformly disposable. Classify into runtime, rebuild inputs, retained evidence, and disposable intermediates before deleting.
- `Path.write_text()` in this environment has no `newline=` keyword. Normalize line endings in the content or use `open(..., newline="\n")`.
- Retiring superseded fauna GLBs requires the same sweep as adding them: update `MODEL_PATHS`, bird authored-pose expectations, `SOURCES.csv` (parent GLB plus Godot-extracted sidecars), gait allowlists, and asset-library tests that still filter `animals/` instead of `storybook/`. Relocate still-live livestock into `assets/storybook/` before deleting `assets/animals/medieval/`.
- Nine `BROKEN_LINK` issues in root `README.md` with `../../` targets usually mean the product README was overwritten by `assets/characters/README.md`. Restore from the parent commit (`git show <parent>:README.md`) instead of rewriting links in place.
- When moving GLBs into per-model subfolders, update paths with a scoped script (parent directory prefix + model name), not repo-wide `hammer.glb` / `sword.glb` string replaces. Those hit unrelated props and storybook equipment. After regex fixes on `.import` sidecars, rewrite `source_file=` from the folder basename; never use `\1` in shell-quoted Python replacements. Run Godot headless `--editor --import` before storybook Godot tests; imported `.scn` caches still point at old extracted texture paths until reimport.
- Path-rewrite scripts must exclude `.worktrees/`, `build/`, and other non-canonical trees; `Path.rglob` from repo root will dirty sibling worktrees and backup CSVs. For `assets/SOURCES.csv`, restore from `HEAD` and apply a prefix-scoped replace for the moved folder only. Stage with explicit paths (`git add assets/props/trade/...`); a dirty index can sweep unrelated prop migrations into the same commit. Split asset moves and loader/generator path updates into one commit when possible so runtime does not briefly point at missing flat paths.
- Commit verified work as soon as it is proven. A concurrent agent session running `git stash` wipes the whole uncommitted working tree, including files it has no interest in. Recover from `git stash list` (`git show 'stash@{N}:<path>'`), and re-derive generated artifacts from their generator rather than trusting a recovered binary - regenerating and matching the recovered SHA-256 also proves the generator is deterministic.
- A concurrent session can rewrite a shared facade file (for example `map_view_materials.gd`) from its own staged copy and drop your unstaged additions. Before capture, test, and commit, grep for your new symbols and re-add them as an unstaged hunk, without touching the other session's staged content.
- A board claim (`in_progress`) does not prove exclusivity: a parallel terminal session may implement the same task without claiming it. Before writing a task's new files, check `git status` and mtimes of its allowed paths; if another session is actively writing them, hand off review notes in the task body and pick a non-overlapping task instead of racing on the same file.
- Shell quirks here (zsh): `ls` is aliased to a table printer, so pipe `/bin/ls` into `grep`; unquoted `$VAR` holding several paths is not word-split (use an array `F=(...)` and `$F`); `timeout` is not installed. `run_godot_tests.gd --filter=` takes exact comma-separated file stems, and an empty filter silently runs the full ~25 min suite.
- To prove full-suite failures are not yours in a dirty shared tree, run an A/B check on only the suspect test files: back up your own paths, `git checkout --` your tracked files, move your new files aside, run the same `--filter=` stems, then restore. Run the whole swap inside one `bash -c '...'` with arrays and `set -e` up to the backup step. A zsh multi-path variable that does not split can silently skip the backup and the checkout.
- `git add <paths>` does not isolate a commit: the shared index can already hold stale entries, for example left behind when another session committed through a temporary `GIT_INDEX_FILE`. They then commit as silent reverts of that session's work. Right before `git commit`, run `git diff --cached --name-only` and require it to list only your paths; otherwise commit with a temporary index built from `HEAD` plus your paths. If a revert already landed, restore just those paths with `git restore --source=<their commit> --staged -- <paths>` and a follow-up commit, and never force-push.
- Godot scans `build/` as `res://` (gitignored, not ignored unless a folder has `.gdignore`). A scratch `class_name` copy steals the global class cache ("Class X hides a global script class"). Keep backups outside the project or under `build/scratch/` (`godot_render.sh` creates that `.gdignore`). Do not add `build/.gdignore` at the root: capture tools read and write `res://build/`. `run_pre_commit_checks.sh` and `run_godot_tests.gd` fail fast on unignored `build/**/*.gd` with `class_name`, or on cache paths outside `scripts/`, `tests/`, `tools/`, `assets/`, `scenes/`, `addons/`. Recover with `.gdignore` in the scratch folder plus `Godot --headless --editor --path . --quit-after 2`.
