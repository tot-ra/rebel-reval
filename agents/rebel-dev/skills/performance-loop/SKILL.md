---
name: rebel-performance-loop
description: Recurring unattended loop that applies one measured performance fix per tick across low / mid / high graphics quality, without downgrading quality to hide problems.
---

# Performance loop (autonomous)

Runs on a schedule with **no human present**: never call `question`, never wait for a reply. A step that needs a human is a blocker; record it and stop.

Read first: `AGENTS.md`, `agents/WORK_PROTOCOL.md`, `agents/playbook.md`, `agents/rebel-dev/playbook.md`, `docs/PERFORMANCE_REPORT.md`, `agents/skills/verify-commands/SKILL.md`. Read `feature-docs` before committing.

## Hard rules

- **One measured fix per tick.** No bundles, no speculative refactors.
- **No quality downgrades to hide problems.** Do not lower resolution scale, shadow/GI/SSAO/vegetation/crowd quality, draw distance, LOD thresholds, population caps, or feature flags, and do not move work from one tier to another to improve a number. Fix the cost source (batching, caching, redundant work, allocation, bad shader path, per-frame scans). A quality-preset change is allowed only when the task or an accepted ADR already decides it.
- **Never open visible Godot windows.** Every Godot command uses `--headless`; GPU captures and rendered frame times run only through `tools/godot_render.sh --script <tool>.gd`.
- Never run two Godot processes on the same cache or two GPU benchmarks at once; concurrent jobs skew numbers (see memory/playbook).
- Never weaken tests, thresholds, budgets, or hooks. No `--no-verify`.
- Preserve stable IDs, determinism, and `GameState` as the only campaign state. No new frameworks or systems.

## 1. Orient

1. `git fetch`, `git status`; foreign dirty or staged files belong to other sessions and stay untouched.
2. Read the last runs of this loop (`project_session_history`, query `performance`) and `docs/PERFORMANCE_REPORT.md` for known hotspots and open findings.
3. If the tree is not clean on the paths you would touch, report `idle: no clean write boundary` and stop.

## 2. Measure the baseline (all three tiers)

Targets: frame time strictly below 33.33 ms (above 30 FPS) on the declared minimum profile in `tools/benchmarks/minimum-hardware.json`; watch frame-time tails, CPU, GPU, memory, loading and I/O.

Use existing tools, same host, renderer, scene, resolution and workload before and after:

- `tools/godot_render.sh --resolution 1920x1080 --disable-vsync --script res://tools/benchmarks/player_view_frame_time.gd -- --output=res://build/benchmarks/<name>.json --interleave=high,mid,low --rounds=3` for rendered frame time per quality tier.
- `tools/benchmarks/city_crowd_frame_time.gd`, `render_probe.gd` (single cost source per run), `tools/run_performance_report.sh [out.json] [--quick]`, and `tools/capture_vegetation_benchmark.gd` for counts.

Measure low, mid, and high. Headless numbers are instrumentation only, not rendered FPS; label them so. Record the host, GPU, renderer and limitations.

## 3. Pick one hotspot

Choose the largest measured cost whose fix is local, reversible, and behavior-preserving, with the worst tier first. If nothing is clearly attributable (noise above the expected gain, or the fix needs a design decision), stop with `idle: no safe measured fix` and list the findings. Create no board tasks unless a finding is independently deliverable; deduplicate first.

## 4. Fix and prove

1. Implement the smallest change. Typed GDScript, comments explaining WHY.
2. Re-measure all three tiers with the identical command. Keep the fix only if the target metric improves beyond run-to-run noise and no tier regresses. Otherwise revert your own edits by hand (never repo-wide Git commands) and record the negative result in `docs/PERFORMANCE_REPORT.md` or a report under `docs/reports/`.
3. Prove visual parity with a before/after capture via `tools/godot_render.sh` stored under `docs/reports/images/` (`git add -f`). Identical output is the bar; visible differences mean the fix is rejected.
4. Add or update a focused test when the change has logic; run only the affected tests, then `tools/run_pre_commit_checks.sh`, `git diff --check`, and `python3 tools/docs_index.py --check` before committing.
5. Update the matching `docs/SYSTEMS/` page and `docs/PERFORMANCE_REPORT.md` (numbers, host, limitations) in the same change.

## 5. Review, commit, push

One independent review (`delegate_to_agent`; pass diff range, before/after numbers, commands). Fix confirmed findings once. Commit on `main` only, stage explicit paths, check `git diff --cached --stat`, push normally. Never stash, reset, clean, force-push, or export `GIT_INDEX_FILE`.

## Report (in Russian)

Hotspot, baseline vs after per tier (low / mid / high) with host and limitations, visual parity proof, commands and results, review result, commit hash and push result, remaining findings. If nothing was done: `idle: <reason>` plus the findings.
