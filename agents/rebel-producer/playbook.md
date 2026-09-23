# Producer playbook

Read `agents/playbook.md` first for shared workflow, tooling, and Git lessons.
This file contains lessons specific to the Producer role.

## Role-specific lessons
- When decomposing a high-complexity parent, rank open rows by numeric priority and complexity from the project-scoped store. Do not trust `tasks.next` or query text alone. Cancel overlapping broad rows with an explicit merged-into note.
- Task-board identity is the internal `R-*` ref. Resolve product IDs such as `P0-122f` before `tasks.get` or dependency lists. Create children sequentially and never precompute refs.
- An empty `body` on `tasks.update` erases the description. Omitted priority or complexity can reset metadata. Pass the full body and explicit fields, then re-read the card.
- When inserting many `TODO.md` rows, prefer one atomic rewrite and assert each new ID has exactly one deliverable row. A substring match inside `deps:` is not proof the row exists. Scan `docs/ROADMAP.md` for nearby IDs just claimed by other tracks.
- For hot `TODO.md` closeouts in a dirty worktree, rebuild from `git show HEAD:TODO.md` plus only the scoped row edits. Assert size and anchored `- [x] ID |` presence. Do not run `update_todo_counts.py --write` on a truncated file; that helper only rewrites when passed `--write`.
- Before claiming a hot coordination row, re-read its exact live line. Never overwrite an active lease.
- Closing a research `R-###` dossier does not put historically accurate fabric into the game. Producer follow-up rows must name the target map anachronism and Brief ship decisions.
- A Producer-only TODO or ROADMAP tick can leave the active Markdown report stale. Create a bounded QA refresh row instead of editing the generated report outside Producer ownership.
- When P7 design verify clauses require active-docs green, regenerate the report in-row. Do not invent a parallel refresh ID unless Current focus deliberately leaves the check red.
- Stage only allowlisted packaging files. Never absorb concurrent map or prop WIP into a packaging or closeout commit.
- For Act 1 packaging, keep the DMG gitignored and force-add only the small SHA fingerprint sidecars.
- Prefer Current focus over a historical QA report that says "do not start X". Open a Dev row for ambient runtime defects rather than widening a Producer allowlist.
