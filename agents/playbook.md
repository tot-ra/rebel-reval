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

### Git and commits
- Inspect `git status` before commit. Unstage unrelated index entries (`M ` in column 1).
- `git commit --only <paths>`: keep every `-m` before `--`. It commits working-tree bytes of those paths, not a prepared index snapshot. Untracked paths must be `git add`ed first; `--only` cannot create a commit from unknown files. For a HEAD-plus-scope commit in a dirty file, keep the scoped bytes in the path through the commit, or commit a temporary index without `--only`.
- In a dirty shared worktree, build a HEAD-plus-scope tree with a temporary `GIT_INDEX_FILE` when the working file has concurrent WIP. Normalize `diff --git`, `---`, and `+++` paths before `git apply --cached`.
- `git diff --no-index` status 1 is a valid new-file diff. Run whitespace checks separately.
- `git diff --cached --check` rejects Markdown hard-break spaces and an extra blank line at EOF. Strip trailing spaces; keep exactly one trailing newline. Scope the pathspec so unrelated dirty files cannot block the check.
- Staging `scripts/map/**` triggers the map audit. If the hook fails on unrelated scene or TODO drift after scoped checks pass, use documented `SKIP_PRE_COMMIT=1` / `git commit --only --no-verify`. Do not absorb audit WIP.
- On-commit gdlint checks every staged `scripts/**/*.gd` file. Wrap new `max-line-length` rows there. `SKIP_PRE_COMMIT=1` is for `tests/` and `tools/` drift that CI does not lint.
- `git commit --only` exports `GIT_INDEX_FILE` into hooks. Fixture-repo Git tests must clear `GIT_DIR` / `GIT_INDEX_FILE` / `GIT_WORK_TREE`.
- Do not `git checkout HEAD --` a hot shared file while other dirty scripts already call its new APIs. Do not mid-task `git stash` with fragile pathspecs.
- After a temporary-index commit, move only the branch ref. Do not `git reset --soft` in the live checkout.
- If a path-limited commit exits silently, inspect `HEAD` and hooks separately before retrying.

### Godot and Python verification
- Export `GODOT_BIN` in a preceding command (macOS: `/Applications/Godot.app/Contents/MacOS/Godot`). Inline `GODOT_BIN=... "$GODOT_BIN"` expands the old empty value and exits 127.
- Stale Godot tests often fail parse before runtime when APIs move: check enum renames (`RoutineState` -> `ActivityMode`), removed static helpers (`water_surface_height()` -> `MapViewMeshBuilderConfig` constants), and harness helpers (`assert_almost_eq`, `_assert_true` in custom RefCounted tests).
- Pre-commit runs `verify_map_audit.py` for any staged `scripts/map/**` file. When map audit is already red on `main`, keep production fixes in tests or non-map modules, or repair audit inventory first.
- `tools/run_godot_checked.sh [--require-test-summary] <log-basename> -- <godot-command>`. The log name is a basename, not `/tmp/...`. `--filter` goes after `--`.
- The harness is `tools/run_godot_tests.gd`. `--filter` matches `test_*.gd` file stems, not method names. Pass one `--filter=stem1,stem2` token. Repeated `--filter name` flags are ignored and the full suite runs.
- Fresh worktrees need `godot --headless --path . --import` before tests (global class cache).
- Do not run ordinary Node or RefCounted scripts with `--script`; they do not quit. Use the harness.
- A green focused summary can still fail the checked runner on unrelated parse errors. Report the scoped result separately from the baseline blocker.
- Visual capture helpers can exit 0 despite `SCRIPT ERROR`. Treat output as invalid until the log is clean.
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
- Create dependency chains sequentially and verify each returned ref. An empty `body` on update erases the contract. If a mutation times out, query the exact ref before retrying.
- When the `tasks` tool is unavailable in Cursor, read or update the project board through `~/.local/share/aagent/aagent.db` with the session `project_id`; do not infer open work from `TODO.md` alone.

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
