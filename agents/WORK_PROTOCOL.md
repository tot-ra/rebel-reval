# Reval Rebel Agent Work Protocol

This protocol is binding for every agent under `agents/`. Role-specific work-loop skills add detail but must not weaken these rules. `README.md` owns product intent, `TODO.md` owns executable work, `docs/ROADMAP.md` owns current milestone order, and `docs/CANON.md` owns approved historical-fiction truth.

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

Claim a task only when its row provides or names:

- `role:` and, for player-facing work, `slice:`;
- a concrete player-facing goal or production risk;
- resolved `deps:` and approved content dependencies;
- exact `deliverable:` and either `allowed files:` or an owned-path write set that is unambiguous from the deliverable, with no active path overlap;
- historical evidence or an explicit evidence dependency for period-visible content;
- constraints and non-goals sufficient to prevent scope invention;
- a reproducible `verify:` clause and the expected downstream handoff.

A cheap capability preflight also belongs to readiness. Confirm required binaries, credentials, generation services, write paths, and test commands before claiming. If the contract or environment is not ready, do not hold the task while waiting. Report the blocker and create one bounded request.

## One tick: Orient, Recover, Deliver, Improve, Report

A tick is one bounded 20-60 minute unit. Perform these steps in order.

### 1. Orient

- Read `git status`, `TODO.md`, `docs/ROADMAP.md` Current Focus, this protocol, and the role work loop.
- Read only the canon, evidence, schemas, and neighboring artifacts relevant to the top candidate.
- Preserve unrelated or already modified files. Never stage, revert, or absorb another worker's changes.

### 2. Recover

- Resume a valid claim held by this instance before claiming new work.
- A row carrying `review: canon` is pending review, not stale worker work.
- If another claim's lease expired, follow the stale-claim rules below rather than overwriting work blindly.

### 3. Deliver mode

If a ready row exists, claim the highest priority eligible row and deliver the smallest complete result. Do not start a second row before the first is verified, reported, or explicitly released.

### 4. Improve mode

If no row is claimable, do not wait for another agent and do not invent a feature. Choose one bounded mode:

- **Unblock:** inspect the nearest blocked dependency. Fix only a stale marker or issue inside your owned paths and existing task authority. Otherwise create a work request for the decision owner.
- **Scout:** audit one current-slice surface using the role's proactive lens. Compare stated intent with files, runtime evidence, or tests. Create at most two deduplicated work requests, then stop.
- **Healthy exit:** if no grounded current-slice gap exists, run one cheap role health check when useful, report `idle: healthy`, and exit. Proactivity is bounded discovery, not endless speculative scope.

Do not create a new request while two open requests from the same role remain untriaged. Art and Research retain their explicitly scoped `A-###` and `R-###` self-managed backlogs, but use the same evidence, deduplication, and WIP limits defined in their work loops.

### 5. Report and release

End every tick in exactly one state: delivered, pending canon review, blocked with a request, or healthy exit. Leave no silent notes and no active claim on work that is waiting for another role or environment.

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

Cross-role and no-row discoveries go to a unique request card under `docs/reports/work_requests/` using its `TEMPLATE.md`. Name it:

`<role>-<UTC-date>-<short-slug>.md`

An author may create a new card but may not accept, prioritize, or edit an already triaged card. The Producer atomically changes frontmatter `status: open` to `status: accepted`, `status: rejected`, or `status: merged`, records the matching decision, and creates a dependency-safe row when accepted. A request is not permission to implement.

A request must include player value, evidence, proposed owner, exact deliverable and allowed paths, dependencies, verification, and non-goals. Missing research is routed to Research; unsupported historical interpretation is routed to Canon; missing product scope is routed to Producer.

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
- Every blocked row names an owner and clearing condition; every cross-role need becomes a request, not an idle agent.
- Every player-facing Dev row is planned with a linked QA acceptance row. Every content row closes through Canon before implementation depends on it.
- Long chains must yield a playable checkpoint at least every three role handoffs.

## Completion standard

A deliverable is done only when its task verification passes, owned documentation and provenance are current, historical uncertainty remains visible, downstream stable IDs and assumptions are explicit, and the next role can proceed without guessing. Report commands and evidence, not confidence language such as "should work".
