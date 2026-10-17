---
name: rebel-complex-task-loop
description: Unattended recurring loop that picks one high-complexity task the agent can finish without human approval, delivers a verified slice, commits and pushes on main, and hands off the rest as board follow-ups.
---

# Complex task loop

This loop runs on a schedule with **no human present**. Nobody answers questions, approves decisions, or reviews art during the run. Every choice below follows from that.

Read first: `AGENTS.md`, `agents/WORK_PROTOCOL.md`, `agents/playbook.md`, `agents/rebel-dev/playbook.md`, `agents/rebel-dev/skills/work-loop/SKILL.md`. Read the shared skills in `agents/skills/` when their trigger applies (always `feature-docs`; `map-authoring` for any map change; `verify-commands` before verifying).

## Autonomy rules

- Never call the `question` tool and never stop to wait for a reply. If a step needs a human, it is a blocker: record it and move on.
- Implement only what is in task contract. Do your best judgement

## 1. Orient and recover

1. `git fetch` and `git status`. Note foreign dirty and staged files; they belong to other sessions and stay untouched.
2. Read the previous runs of this loop (`project_session_history`, query `complex`) for unfinished work and failures.
3. **Resume first:** if a task tagged `complex-loop` is `in_progress` or carries a `## Next step` note from an earlier run of this loop, and no other session is working on its paths, continue it instead of picking a new one.

## 2. Select one eligible task

Candidates: status `todo`, complexity `c3`-`c5` (or `c0` with an estimate of 6h or more), highest priority first (`p0` > `p4`), then tasks that advance the `docs/ROADMAP.md` current focus (`track:demo`, `track:slice`).

Claim with `tasks.update` (`status: in_progress`, add tag `complex-loop`), then `tasks.get` again to confirm no concurrent worker (for example the hourly `task` loop) claimed it in between.

## 3. Plan before code

Write a short plan into the task body: player action or production risk, files to change, state and persistence touched, tests to add, docs page to update, verification commands. Split the task into increments that each leave `main` green and playable. A complex task usually does not fit one run: plan the first increment to be a complete vertical slice, not a half-built layer.

## 4. Implement

Follow the developer work loop: typed GDScript, `GameState` as the only campaign state, `ContentDB` as the content boundary, stable IDs preserved, no new frameworks. Godot runs only with `--headless`, captures only through `tools/godot_render.sh`. Do not run two Godot import or test processes on the same cache at once.

Budget: about 90 minutes of implementation. When it runs out, stop at the last green increment.

## 5. Verify

- Record a baseline of the relevant tests before editing, so pre-existing failures are not blamed on (or hidden by) this change.
- Run the task's `verify:` clause, the new focused tests, and the affected suites; then `tools/run_pre_commit_checks.sh` as documented in `verify-commands`, `git diff --check`, and `python3 tools/docs_index.py --check`.
- Visible changes need captures under `docs/reports/images/` (`git add -f`).
- Never weaken or delete tests, thresholds, or hooks, never use `--no-verify` or `SKIP_PRE_COMMIT`, never blindly regenerate golden fixtures.

## 6. Review

Request one independent review (`delegate_to_agent` with a reviewer agent; pass the task ref, the diff range, and the verification output). Fix confirmed findings once. Without a passing review the task goes to `in_review`, never `done`.

## 7. Commit and push

Commit on `main` only. Stage by explicit path, inspect `git diff --cached --stat` so only this change is staged, commit with normal hooks (message cites the task ref), push normally. Never stash, reset, restore, clean, force-push, or export `GIT_INDEX_FILE`. A rejected push: `git pull --rebase` only when the working tree contains nothing but this change; otherwise report the blocker.

## 8. Close the tick

Leave the task in exactly one state:

- **Done:** verify clause and review passed. Status `done` (or `testing` when a linked QA row is the acceptance gate).
- **Partial:** a verified increment was committed. Status back to `todo`, keep tag `complex-loop`, append `## Progress` (commit hash, what works) and `## Next step` (the exact next increment). Create follow-up tasks only for parts that are independently deliverable or owned by another role.
- **Blocked:** status `todo`, typed blocker per `WORK_PROTOCOL.md`, attempt count in the body, nothing half-done left in the working tree: undo this run's uncommitted edits by editing them back or deleting files this run created, never with repo-wide Git commands.

Follow-ups: deduplicate against the board first; include parent ref, role, deliverable, allowed files, dependencies, verification; tag `follow-up`. Work that needs a human decision is created as `idea` with tag `needs-human`, so this loop skips it and the producer sees it.

Append a reusable lesson to the narrowest playbook only when something failed in a way the next run could repeat.

## Report (in Russian)

Task ref and why it passed the autonomy check, what was delivered, commands with results, captures, commit hash and push result, review result, final task status, follow-ups created, what remains. If nothing was eligible: `idle: no autonomous candidate`, plus the top rejected candidates with the reason each was rejected.
