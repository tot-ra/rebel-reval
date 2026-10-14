---
name: rebel-complex-task-loop
description: Unattended recurring loop that picks one high-complexity task the agent can finish without human approval, delivers a verified slice, commits and pushes on main, and hands off the rest as board follow-ups.
---

# Complex task loop (autonomous)

This loop runs on a schedule with **no human present**. Nobody answers questions, approves decisions, or reviews art during the run. Every choice below follows from that.

Read first: `AGENTS.md`, `agents/WORK_PROTOCOL.md`, `agents/playbook.md`, `agents/rebel-dev/playbook.md`, `agents/rebel-dev/skills/work-loop/SKILL.md`. Read the shared skills in `agents/skills/` when their trigger applies (always `feature-docs`; `map-authoring` for any map change; `verify-commands` before verifying).

## Autonomy rules

- Never call the `question` tool and never stop to wait for a reply. If a step needs a human, it is a blocker: record it and move on.
- Do not lower the selection bar to find work. "No eligible task" is a valid result (`idle: no autonomous candidate`).
- Do not make product, scope, canon, or art-direction decisions. Implement only what the task contract, accepted ADRs, and `docs/CANON.md` already decide. Where the contract is silent on a small technical detail, choose the option that is reversible and consistent with neighbouring code, and write the choice into the task body as a decision.

## 1. Orient and recover

1. `git fetch` and `git status`. Note foreign dirty and staged files; they belong to other sessions and stay untouched.
2. Read the previous runs of this loop (`project_session_history`, query `complex`) for unfinished work and failures.
3. **Resume first:** if a task tagged `complex-loop` is `in_progress` or carries a `## Next step` note from an earlier run of this loop, and no other session is working on its paths, continue it instead of picking a new one.

## 2. Select one eligible task

Candidates: status `todo`, complexity `c3`-`c5` (or `c0` with an estimate of 6h or more), highest priority first (`p0` > `p4`), then tasks that advance the `docs/ROADMAP.md` current focus (`track:demo`, `track:slice`).

A task is eligible only if **all** of these hold:

| Check | Reject when |
|-------|-------------|
| Human gate | Tags or body contain `blocked-external`, `blocked-decision`, `rights`, `needs-human`, `review: canon`, or the deliverable is a human/named/historical/art sign-off, review, or approval |
| Scope | Needs a new ADR, a scope change, or depends on an ADR whose status is not Accepted |
| Asset freeze | Creates or replaces art and the task does not name the exact files and `assets/SOURCES.csv` rows (P0-040) |
| Canon | Adds period-visible content (people, places, dialogue, history) whose content dependency is not canon-approved |
| Role | Owned by Producer, Canon Keeper, or Research (decision roles). Dev, QA-tooling, and Map work is eligible |
| Contract | Missing a concrete deliverable, an unambiguous write set, or a reproducible `verify:` clause |
| Dependencies | Any `depends_on` / `deps:` task is not `done` |
| Environment | Needs hardware, accounts, or services not available here (for example "recommended-host" measurements, a paid service without an integration) |
| Collision | Allowed paths overlap an `in_progress` task or dirty files of another session |
| Already built | `git log origin/main --grep <ref>` or a search of the deliverable paths shows the work already landed |
| Repeat failure | The body records two failed attempts by this loop |
| Epic | Tagged `epic`: pick its ready child instead of the parent |

Read the full body (`tasks.get`) of the top few candidates before deciding. If a strong candidate fails only on a human gate, leave it alone; if it fails on a missing contract, add one short note to its body (`autonomy: blocked - <reason>`) so later runs skip it faster. Do not spend more than about 10 minutes on selection.

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
