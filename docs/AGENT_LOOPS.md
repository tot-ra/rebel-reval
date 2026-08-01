# Agent Loops

Reval Rebel uses an asynchronous pull system organized around playable vertical slices. The binding shared protocol is [`agents/WORK_PROTOCOL.md`](../agents/WORK_PROTOCOL.md); each agent's `skills/work-loop/SKILL.md` defines its role-specific delivery and proactive audit.

> Scope: Godot 4.7 historical-fiction narrative action RPG set in Spring 1343 Reval. Product intent is in `README.md`, operational work is in the project task board, durable/legacy task IDs remain in `TODO.md`, milestone order is in `docs/ROADMAP.md`, canon in `docs/CANON.md`, and confidence labels are `attested` / `plausible composite` / `folklore` / `invented`.

## Operating model

```text
Task board + ROADMAP Current Focus + open work requests
                 |
                 v
       Producer validates and plans
                 |
                 v
   role-tagged board items and legacy TODO rows grouped by slice
                 |
      workers claim ready work
                 |
  evidence/content/assets/runtime/tests
        |                   |
        v                   v
   Canon gate          QA acceptance
        |                   |
        +------> playable checkpoint

Idle worker -> bounded role audit -> task-board follow-up or work request -> Producer
Blocked worker -> release claim + typed blocker + task-board follow-up or request -> Producer
```

This is a pull queue, not a dispatch chain. Workers never call or wait for one another. The Producer does not need to predict every gap: specialists proactively discover grounded needs. Concrete executable follow-ups go through the `tasks` tool; unresolved decisions and underspecified needs use `docs/reports/work_requests/` rather than silently expanding scope.

## Tick behavior

Every agent performs the common sequence:

1. **Orient** on repository state, task-board state, current focus, queue, role rules, and relevant evidence.
2. **Recover** its own valid unfinished claim before taking new work.
3. **Deliver** the highest-priority ready board item or legacy row if one exists.
4. **Improve** through a bounded unblock or current-slice scout when no row is ready.
5. **Report and release** as delivered, pending canon, blocked with an owner, or `idle: healthy`.

One tick produces at most one task delivery or one audit. Empty queues are not a reason to wait, but they are also not permission for speculative backlog generation.

## Task board contract

Use the project `tasks` tool for the operational queue. Existing TODO IDs remain useful durable
identifiers, but a board `ref` is the execution identity and must be cited in handoffs. New
follow-ups must be independently verifiable and include role, slice, goal, deliverable, allowed
files, dependencies, constraints, verification, handoff, and a parent task or dossier. Start
cross-role discoveries as `idea`; Producer triage promotes accepted work to `todo`. Use request
cards only for unresolved decisions, missing evidence, rights, or underspecified scope.

## Task contract

Preferred row format:

```text
- [ ] ID | slice: <slug> | role: <loop> | deps: <IDs or none> | goal: <player value> | deliverable: <exact result> | allowed files: <exact paths> | verify: <reproducible evidence> | handoff: <next role or gate>
```

Older rows remain valid only if the Producer can establish the same Definition of Ready from linked context. The Producer adds explicit `role:` and `slice:` to every open Current Focus row before relying on autonomous workers. Specialists do not infer ownership from an untagged row.

### States and reporting tags

| Marker | State | Rule |
|---|---|---|
| `- [ ]` | open | Claimable only when the full readiness contract passes. |
| `- [~] + claim:` | active | One leased worker claim. |
| `- [~] + review: canon` | review | Delivered content, no worker claim, not stale. |
| `- [x]` | done | Verified and, for content, canon-approved. |
| `- [!] + blocked:` | blocked | Claim released; Producer must re-scope, route, or reject. |

Claims use UTC timestamps and a 2-hour lease. See the common protocol for reclaim rules and blocker types. `claim:` and `review: canon` must never coexist after reconciliation.

## Planning around playable slices

A `slice:` is a player-observable sequence with setup, action, feedback, and remembered consequence. Producer plans a thin complete path before adding breadth:

1. **Ground:** Research supplies evidence, confidence, visible forms, and exclusions; Canon resolves interpretations that affect shared truth.
2. **Design:** Narrative names dramatic purpose; Character names motives and knowledge; Quest turns the intended choice into deterministic state; Map identifies player routes and affordances; Art establishes readable production forms.
3. **Express:** Dialogue writes state-aware speech and barks. Map and Art finish approved source and assets.
4. **Integrate:** Dev connects approved content through existing runtime boundaries and supplies focused feature tests.
5. **Accept:** Canon gates content assertions; QA independently verifies the end-to-end player path, failure modes, persistence, inputs, and visual evidence.

These are gates, not a mandatory waterfall. Approved inputs should unlock parallel work. Every three cross-role handoffs must produce a playable or directly inspectable checkpoint.

## Roles and bounded proactivity

| Loop | Accountable for | Own write surface | Scout when no task is ready |
|---|---|---|---|
| Producer | Current focus, task readiness, dependencies, WIP, request triage, recovery | `TODO.md`, `docs/ROADMAP.md`, Producer decisions in work requests | Queue health, missing roles, cycles, stale claims, untagged Current Focus rows, absent playable checkpoint |
| Canon Keeper | Historical and narrative continuity verdicts | `docs/CANON.md`, `docs/HISTORICAL_AUDIT.md`, canon tags | Sample one recent/current-slice artifact for drift, unsupported certainty, or cross-artifact contradiction |
| Research | Sourced evidence and production-ready dossiers | `history/`, `docs/lore/`, self-managed `R-###` rows | Current-slice evidence gaps, unresolved dossier questions, missing visual plates |
| Narrative | Dramatic causality and campaign beats | `story/`, approved pillar decisions | Passive scenes, missing stakes/payoffs, consequence discontinuity, history treated as set dressing |
| Quest | Playable state, objectives, routes, outcomes | quest package JSON and quest schemas when tasked | Approved beats without interactive structure, weak feedback, orphan states, missing fail-forward |
| Dialogue | Spoken state expression and ambient voice | dialogue/bark package JSON and schemas when tasked | Silent states, exposition, voice drift, invalid knowledge, choices with indistinguishable response |
| Character | Motives, identity, knowledge, relationships, actionable briefs | character package JSON, `characters/` | Generic quest dispensers, missing agency, ahistorical daily life, missing visual/action brief |
| Map | Authored spatial source and spatial storytelling | `content/maps/`, `.rrmap` | Unclear routes, weak landmarks/affordances, placeholder fabric, historical layout conflict |
| Art | Production assets, motion, style, provenance | `assets/`, `generated/`, self-managed `A-###` rows | Missing models/motion, anachronism, style drift, unreadable gameplay-camera silhouette |
| Dev | Runtime behavior and integration | `scripts/`, scenes, architecture docs, task-scoped feature tests | Approved content not surfaced, broken player loop, architecture risk, missing runtime feedback |
| QA | Independent risk-based acceptance | acceptance/regression tests and verification tools | Recent deliveries without QA pairing, current-slice smoke gaps, persistence/input/visual regressions |

All specialists may create bounded `idea` follow-ups with the `tasks` tool. This is a coordination exception, not ownership of another role's output. Producer triage promotes accepted ideas to `todo` after checking dependencies and path overlap. Specialists may still create uniquely named proposal cards in `docs/reports/work_requests/` for unresolved decisions; Producer triage atomically replaces request `status: open` with `status: accepted`, `status: rejected`, or `status: merged` and records the matching decision.

## Handoff requirements

A handoff names stable IDs, assumptions, evidence, exact paths, and the check that proves readiness. Role-specific minimums:

- Research to creative roles: short brief, citations, confidence, exclusions, production hooks, and visual plates where form matters.
- Narrative to Quest/Character: dramatic question, player action, faction stakes, branch/convergence, and remembered consequence.
- Quest to Dialogue/Dev: complete state machine, conditions, stable variables, objectives, feedback moments, outcomes, and clean-save path.
- Character to Dialogue/Art: motive, fear, leverage, allegiance, knowledge boundary, voice, social/material status, action and visual brief.
- Map/Art to Dev: stable IDs, source/asset paths, scale, states or clips, provenance, and gameplay-camera evidence.
- Dev to QA: expected player path, changed state, failure paths, focused tests, commands, and representative capture when visual.
- Canon/QA rejection: numbered correction or minimal reproduction, affected owner, and exact clearing condition.

## Queue health and deadlock prevention

The Producer runs these checks every tick:

- Assign `role:` and `slice:` to open Current Focus rows; never leave specialists to infer them.
- Consume and decide open task-board ideas and work requests before planning new breadth.
- Remove stale leases, malformed `claim + review` combinations, and claims held while blocked.
- Detect missing IDs, dependency cycles, self-dependencies, canon-review loops, and blocked dependencies with no owner.
- Prevent overlapping allowed paths across all active rows, not only inside one role.
- Keep at least one ready row for each active slice role and one independent fallback for bottleneck roles, without manufacturing work for inactive roles.
- Pair every player-facing Dev row with a dependent QA row when the Dev row is planned.
- Re-scope or split work whose result cannot be verified in one bounded tick.

Art and Research are scoped structural exceptions. They may maintain only their `A-###` and `R-###` sections. Each refills below three grounded open rows and caps itself at eight; concrete cross-role needs go through task-board follow-ups, while unresolved decisions go through work requests. The Producer remains the only planner of campaign-band rows.

## Concurrency rules

1. Claim before implementation; one active claim per worker.
2. A lease is not a lock on history. Check target paths before reclaiming and preserve useful partial work.
3. Path ownership is the default write barrier. Shared or exceptional paths require exact `allowed files:` and dependency ordering.
4. Content cannot unblock runtime work until Canon marks it approved.
5. QA is independent. Dev feature tests do not replace a linked QA acceptance row.
6. Failures surface immediately through typed blockers and requests. No agent remains active while waiting.
7. Do not stage, commit, revert, or overwrite unrelated changes from another worker.

## Scheduling guidance

Use events and queue pressure rather than running every role continuously:

- Producer: one frequent singleton tick, plus immediate reconciliation when a task-board idea, work request, blocker, rejection, QA failure, or stale lease appears.
- Canon: singleton after content deliveries; prioritize reviews that unblock the current slice.
- Research, Narrative, and Character: wider at slice inception, then bounded scouts.
- Quest, Dialogue, Map, Art, and Dev: run while their slice has ready work; scale only when allowed paths do not overlap.
- QA: remain within one completed player-facing Dev row of development and run a milestone smoke before release.

A healthy empty role queue is allowed. The agent records `idle: healthy` and exits; the scheduler wakes it on a relevant event or the next bounded audit cadence.

## Sources of truth

Agent behavior is defined in this order:

1. `agents/WORK_PROTOCOL.md` - shared state, task-board usage, readiness, proactivity, claims, blockers.
2. `agents/<role>/skills/work-loop/SKILL.md` - role delivery and scout lens.
3. `agents/<role>/agent.yaml` and optional `system.md` - identity, rights, tools, runtime.
4. This document - team topology, handoffs, cadence, and queue-health overview.

If these conflict, stop implementation, create a Producer request naming the conflict, and follow the narrower safety or ownership rule until reconciled.

Validate all definition invariants with:

```bash
python3 agents/verify_workflows.py
python3 -m unittest tests.python.test_verify_agent_workflows -v
```
