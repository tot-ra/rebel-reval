# Reval Rebel Agent Work Protocol

This protocol is binding for every agent under `agents/`. Role-specific work-loop skills add detail but must not weaken these rules. `README.md` owns product intent, the project task board is the preferred operational queue, `TODO.md` remains the durable/legacy task contract, `docs/ROADMAP.md` owns current milestone order, and `docs/CANON.md` owns approved historical-fiction truth.

## Mission

Build a playable historical-fiction RPG, not a collection of disconnected artifacts. Every change must improve a player action, choice, consequence, readable place, believable person, or production safety condition needed by the current playable slice.

Use five lenses throughout production:

1. **Historical grounding:** cite evidence, apply `attested` / `plausible composite` / `folklore` / `invented`, preserve uncertainty, and name exclusions that prevent anachronism.
2. **Gameplay value:** state what the player does, understands, risks, and receives as feedback. Lore without a playable use is research, not a feature.
3. **Narrative causality:** connect people, factions, objectives, and consequences. A branch must change remembered state, not only wording.
4. **Visual and audio communication:** judge form, motion, hierarchy, atmosphere, and affordances from the gameplay camera and target input flow.
5. **Integration evidence:** preserve stable IDs, deterministic state, schemas, provenance, tests, captures, and clean-save replay where relevant.

A small complete slice that satisfies these lenses outranks broad disconnected output.

## Decision rights

- The **Producer** decides priority, scope, dependency order, and task readiness. It does not decide historical truth or implement deliverables.
- The **Canon Keeper** decides whether historical and narrative assertions may enter canon. It does not approve gameplay quality, code quality, or art polish by taste.
- **Research** describes what the evidence supports and where it ends. It does not alter canon or downstream content.
- **Narrative** owns dramatic intent and causality; **Quest** owns playable state and consequence; **Dialogue** owns spoken expression; **Character** owns people and their knowledge, motives, and reusable identity.
- **Map** owns authored spatial source; **Art** owns production assets and visual coherence; **Dev** owns runtime integration; **QA** owns independent acceptance evidence.

When decision rights conflict, do not guess or negotiate by editing another role's files. Record a work request for the decision owner.

## Definition of Ready

Claim a task only when its board item or legacy row provides or names:

- `role:` and, for player-facing work, `slice:`;
- a concrete player-facing goal or production risk;
- resolved `deps:` and approved content dependencies;
- exact `deliverable:` and either `allowed files:` or an owned-path write set that is unambiguous from the deliverable, with no active path overlap;
- historical evidence or an explicit evidence dependency for period-visible content;
- constraints and non-goals sufficient to prevent scope invention;
- a reproducible `verify:` clause and the expected downstream handoff.

A cheap capability preflight also belongs to readiness. Confirm required binaries, credentials, generation services, write paths, and test commands before claiming. If the contract or environment is not ready, do not hold the task while waiting. Report the blocker and create one bounded task-board follow-up when the clearing work is executable, otherwise create one bounded request.

## Task board contract

The project task board is the preferred operational queue. Use the `tasks` tool for executable work,
claims, progress, completion, and bounded follow-up tasks; do not leave a concrete need only in prose,
`TODO.md`, or a work-request card.

- Orient with `tasks.stats`, `tasks.list`, and `tasks.get`. Use the board `ref` as the task identity and
  cite the legacy `TODO.md` ID in the title or body when one exists; these identifiers may differ.
- Claim only the selected ready item with `tasks.next` (`claim: true`) or `tasks.update` to
  `in_progress`. Keep one active task per worker and never claim a task whose allowed paths overlap
  another active task.
- Record progress, evidence, blockers, and handoff in `tasks.update`. Release blocked work back to
  `todo` with a typed blocker and clearing condition; do not leave a waiting task `in_progress`.
  Use `in_review` for delivered content awaiting Canon, `testing` for QA handoff, and `done` only
  after the task's verification and required gates pass. Use `cancelled`, not deletion, for obsolete
  work so the decision history survives.
- Create a task with `tasks.create` whenever a follow-up is executable in one bounded tick. Its body
  must include parent task/ref, role, slice, player or production value, exact deliverable, allowed
  files, dependencies, constraints/non-goals, verification, and handoff. Add a role tag and the
  `follow-up` tag. A cross-role discovery or an item needing Producer triage starts as `idea`; the
  Producer promotes it to `todo` only after checking scope, dependencies, and path overlap.
- A markdown work request remains appropriate for an unresolved decision, missing evidence, rights
  question, or underspecified need. Once the request contains an independently verifiable deliverable,
  create or link the corresponding task-board item instead of waiting for prose triage alone. Agents
  may propose work for another role but must not claim or implement that role's task.

## One tick: Orient, Recover, Deliver, Improve, Report

A tick is one bounded 20-60 minute unit. Perform these steps in order.

### 1. Orient

- Read `git status`, task-board state (`tasks.stats` plus scoped `tasks.list`/`tasks.get`), `TODO.md`, `docs/ROADMAP.md` Current Focus, this protocol, and the role work loop.
- Read only the canon, evidence, schemas, and neighboring artifacts relevant to the top candidate.
- Preserve unrelated or already modified files. Never stage, revert, or absorb another worker's changes.

### 2. Recover

- Resume a valid `in_progress` task held by this instance before claiming new work.
- A row carrying `review: canon` is pending review, not stale worker work.
- If another claim's lease expired, follow the stale-claim rules below rather than overwriting work blindly.

### 3. Deliver mode

If a ready board item or legacy row exists, claim the highest priority eligible item and deliver the smallest complete result. Do not start a second row before the first is verified, reported, or explicitly released.

### 4. Improve mode

If no row is claimable, do not wait for another agent and do not invent a feature. Choose one bounded mode:

- **Unblock:** inspect the nearest blocked dependency. Fix only a stale marker or issue inside your owned paths and existing task authority. Otherwise create a typed task-board follow-up when the deliverable is clear, or a work request for the decision owner when it is not.
- **Scout:** audit one current-slice surface using the role's proactive lens. Compare stated intent with files, runtime evidence, or tests. Create at most two deduplicated task-board follow-ups, using a request card only for unresolved decisions, then stop.
- **Healthy exit:** if no grounded current-slice gap exists, run one cheap role health check when useful, report `idle: healthy`, and exit. Proactivity is bounded discovery, not endless speculative scope.

Do not create a new follow-up while two open/idea follow-ups from the same role remain untriaged. Art and Research retain their explicitly scoped `A-###` and `R-###` self-managed backlogs, but use the same evidence, deduplication, and WIP limits defined in their work loops.

### 5. Report and release

End every tick in exactly one state: delivered, pending canon review, blocked with a task-board follow-up or request, or healthy exit. Leave no silent notes and no active claim on work that is waiting for another role or environment.

## Claims, leases, and state transitions

Use UTC timestamps. A claim is a lease, not ownership:

`claim: <role>-<instance>@<ISO-8601> | lease-until: <ISO-8601>`

- Default lease: 2 hours. Refresh with `heartbeat: <ISO-8601>` only after meaningful saved progress.
- A worker may reclaim an expired same-role claim only after checking the target paths and repository status. Preserve usable partial work and append `reclaimed-from:`.
- The Producer may release any expired claim during reconciliation.
- A task waiting on a person, service, dependency, approval, or missing decision must release its claim immediately.

State transitions:

- `- [ ]` to `- [~] + claim:` before implementation.
- Content delivery removes `claim:` and remains `- [~] + review: canon`; workers never self-approve.
- Canon approval becomes `- [x] + canon: approved`.
- Non-content Dev and QA work becomes `- [x]` only after its verify clause passes.
- Any unrecoverable tick becomes `- [!] + blocked: <type>(<reason>)`; remove the claim.
- Canon rejection returns content to `- [ ] + canon: rejected(...)` with actionable corrections.

`[~] + review: canon` never expires as a worker claim. A malformed row carrying both `claim:` and `review: canon` is reconciled by removing the obsolete worker claim.

## Blockers and work requests

Use one blocker type: `dependency`, `decision`, `evidence`, `environment`, `scope`, `rights`, or `verification`. Name the smallest condition that clears it. Never write only "waiting for X".

Unresolved cross-role and no-row discoveries go to a unique request card under `docs/reports/work_requests/` using its `TEMPLATE.md`. Name it. Concrete executable discoveries go to the task board first:

`<role>-<UTC-date>-<short-slug>.md`

An author may create a new request card but may not accept, prioritize, or edit an already triaged card. The Producer atomically changes frontmatter `status: open` to `status: accepted`, `status: rejected`, or `status: merged`, records the matching decision, and creates or links a dependency-safe task-board item when accepted. A request or `idea` task is not permission to implement.

A request must include player value, evidence, proposed owner, exact deliverable and allowed paths, dependencies, verification, and non-goals. Missing research is routed to Research; unsupported historical interpretation is routed to Canon; missing product scope is routed to Producer.

### Task-board follow-up examples

A Research dossier may discover that a street decision is ready for Map, that a documented tool,
person, animal, or building needs an authored model, or that Dev must place an approved asset. The
Research agent should create separate `idea` task-board items for those bounded handoffs, each naming
its role, stable IDs, allowed paths, evidence, verification, and parent dossier/task. The same rule
applies to every role: create a focused follow-up for the next owner instead of burying the need in a
handoff paragraph. Producer triage turns accepted ideas into dependency-safe `todo` work.

## Vertical slice contract

Producer plans around named `slice:` values. A slice is a player-observable loop from setup through action and feedback to remembered consequence. Slice tasks may run in parallel when their inputs are approved, but the plan must expose these gates:

1. Evidence and exclusions are sufficient for the visible historical claim.
2. Narrative purpose, character stakes, and player verbs are explicit.
3. Quest state, dialogue conditions, map affordances, and art needs have stable handoffs.
4. Runtime integrates approved content without parallel state stores or duplicate identities.
5. QA verifies clean-save behavior, failure paths, input/readability, and representative visual evidence.

Avoid department waterfalls. Split work so research, character, map, and visual exploration can proceed in parallel from an approved slice brief, then integrate one thin end-to-end path before expanding breadth.

## Deadlock prevention

- No dependency cycles, missing dependency IDs, self-dependencies, or task that depends on its own review.
- No two active rows across any roles may write the same path unless ordered by an explicit dependency.
- Keep WIP low: one active claim per worker, one canonical decision owner, and bounded role backlogs.
- Every blocked row names an owner and clearing condition; every concrete cross-role need becomes a task-board follow-up, while unresolved needs become a request, never an idle agent.
- Every player-facing Dev row is planned with a linked QA acceptance row. Every content row closes through Canon before implementation depends on it.
- Long chains must yield a playable checkpoint at least every three role handoffs.

## Completion standard

A deliverable is done only when its task verification passes, owned documentation and provenance are current, historical uncertainty remains visible, downstream stable IDs and assumptions are explicit, and the next role can proceed without guessing. Report commands and evidence, not confidence language such as "should work".
