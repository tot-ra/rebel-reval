---
name: rebel-simple-task-loop
description: Unattended hourly loop that selects and completes one autonomous c1-c2 task within about 30 minutes, verifies it, and commits only its own paths on main.
---

# Simple task loop

This loop runs on a schedule with **no human present**. Nobody answers questions or approves decisions during the run. Complete at most one task per tick, within an approximately 30-minute end-to-end budget.

Read first: `AGENTS.md`, `agents/WORK_PROTOCOL.md`, `agents/playbook.md`, `agents/rebel-dev/playbook.md`, `agents/rebel-dev/skills/work-loop/SKILL.md`. Read the shared skills in `agents/skills/` when their trigger applies (always `feature-docs`; `map-authoring` for any map change; `verify-commands` before verifying).

## Autonomy rules

- Never call the `question` tool or wait for a reply. A step requiring human input, approval, rights clearance, or a product/canon/art decision is a blocker; do not perform it.
- Do your best
- Work on `main` only. Never switch branches or create a feature branch.
- Take one task only and finish it in this tick. **Do not split work into increments, make partial commits, or leave a claimed task for a later run.** If it cannot be completed and verified within the budget, release it as blocked and undo only this run's uncommitted changes.

## 1. Orient

1. Read `git status`, current branch, task-board stats and ready candidates. Fetch `origin` if safe; preserve every foreign staged, dirty, or untracked path. Do not stash, reset, restore, or clean the repository.
2. Read relevant recent run history for this hourly loop and recent commits to avoid duplicate or already-landed work.
3. Confirm the current branch is `main`. If not, or if the tree cannot be safely worked in place, report the blocker and stop without switching branches.

## 2. Select one eligible task

Consider only ready `todo` tasks with explicit complexity **c1 or c2**, highest priority first (`p0` > `p4`). Read the full body of the best candidates before choosing. Do not select `idea`, `in_progress`, `in_review`, or otherwise unready work. Do not pick any task tagged **`complex-loop`**, even if its complexity is c1-c2; that tag belongs to the separate complex-task loop.

Do not spend more than about 5 minutes on selection. If no task qualifies, report `idle: no autonomous candidate` and the top rejected candidates with concise reasons.

Claim the selected task using `tasks.update` (`status: in_progress`, add a loop-identifying claim/tag if the board supports it), then immediately call `tasks.get` again. Reconfirm that it is still assigned/claimed by this run, remains eligible, and its allowed paths are still clear of active-task and foreign-work collisions. If any check changed, release it to `todo` with a concise typed blocker and select no replacement this tick.

## 3. Plan and implement

Write a compact plan and the selected verification commands into the task body before editing. Use the developer work loop: typed GDScript, `GameState` as the only campaign-state store, `ContentDB` as the content boundary, stable IDs preserved, and no new framework. Follow the feature-docs skill for applicable feature changes. Keep edits inside the task's allowed paths and this run's own scope.

Budget: approximately 30 minutes total, including orientation, selection, implementation, verification, and close-out. Do not start work that cannot be completed and verified in that window. No increment splitting or partial delivery: if the budget is at risk, stop and release the task as blocked rather than leaving partial work or committing a partial slice.

## 4. Verify

- Before editing, note relevant baseline checks or failures when this can be done cheaply.
- Run the task's `verify:` clause and focused tests, plus applicable `git diff --check`, documentation/link checks, and affected regressions within the time budget. Read `agents/skills/verify-commands/SKILL.md` first.
- Run every Godot command with `--headless`; use `tools/godot_render.sh --script <tool>.gd` for captures. Never open a visible Godot window.
- Never weaken or delete tests, thresholds, or hooks, never use `--no-verify` or `SKIP_PRE_COMMIT`, and never blindly regenerate golden fixtures.
- Do not claim success if a required check fails. A pre-existing unrelated failure is reported distinctly and does not authorize changing foreign paths.

## 5. Commit and push

Commit only after the complete task deliverable and required verification pass. Commit on `main` with normal hooks and push normally.

- Stage only explicit paths allowed by this task and changed by this run. Inspect the staged diff and confirm it contains no foreign content.
- Other workers may already have staged unrelated changes. Never unstage or include them: commit this task with `git commit --only -- <explicit-owned-paths>` so the commit contains only this run's paths. Inspect the resulting commit's file list and diff before pushing.
- Never use broad staging, stash, reset, restore, clean, force-push, or `GIT_INDEX_FILE`.
- If hooks fail, diagnose within the budget. Do not bypass them. If push is rejected, do not rebase a checkout containing any foreign staged or dirty changes; report the blocker.

## 6. Close the task

Leave the task in exactly one final state and release this run's claim:

- **Done:** the full deliverable and its verify clause passed, and no human approval remains. Set `done` with concise evidence.
- **Testing:** use only when the completed task explicitly hands acceptance to a linked QA row. Record the handoff and release the claim.
- **In review:** only if the task's contract requires an independent review gate that cannot be performed here; the task is not done. Do not select tasks that predictably require human approval.
- **Blocked:** if eligibility, implementation, verification, budget, commit, or push is blocked, return it to `todo`, remove this run's claim/tag as appropriate, and record a typed blocker plus the exact clearing condition. Undo only this run's uncommitted edits by editing them back or deleting files created by this run; never use repository-wide Git cleanup. Do not create a partial commit.

Create a follow-up only for a separate, independently deliverable need; deduplicate first and include parent ref, role, allowed files, dependencies, verification, and constraints. Human decisions belong in an `idea` tagged `needs-human`, not as autonomous work.

Append a reusable lesson to the narrowest playbook only when a failure exposed a repeatable lesson.

## Report (in Russian)

Report the task ref and why it passed autonomy checks, what was delivered, verification commands and results, commit hash and push result, final task state, follow-ups, and any remaining blocker. If nothing qualified, say `idle: no autonomous candidate` and list the top rejected candidates and reasons.
