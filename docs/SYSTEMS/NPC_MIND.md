# NPC mind: reflex, decision model, local LLM

Status: planned ([ADR 0037](../adr/0037-layered-npc-mind-with-local-llm.md), proposed, not yet approved). Scope: how citizens and other NPCs choose goals, speak, and fight, in three optional layers. Out of scope: story-critical dialogue (stays authored, see [`DIALOGUE.md`](./DIALOGUE.md)), spirit dialogue combat ([`SPIRIT_DIALOGUE.md`](./SPIRIT_DIALOGUE.md)), runtime audio or TTS, free-text player chat, remote LLM APIs.

Nothing here is built. Existing behaviour that layer 0 will wrap lives in [`WORLD_LIFE.md`](./WORLD_LIFE.md), [`CITIZENS.md`](./CITIZENS.md) and [`TIME_AND_PHASES.md`](./TIME_AND_PHASES.md).

## Layers

1. **Reflex (layer 0).** Finite state machines per NPC: idle, walk, work, flee, fight. Runs every frame, owns movement and combat execution, depends on nothing above it.
2. **Decision model (layer 1).** Utility scoring over a closed goal list, using needs, time, weather, Hope/Fear, faction standing, relationships and memory flags. Picks the goal and records a reason code. No model files.
3. **Mind (layer 2).** Optional local LLM, asynchronous and time-boxed. Proposes a goal from the layer-1 list, a mood, or an ambient line with intent tags. A validator accepts or rejects; the rules engine alone changes game state.

Every layer works when everything above it is off, slow or failing.

## Architecture for scale (planned)

Starting point in code: 4,247 census residents; `CitizenRoster.resolve` gives each one a position as a pure function of the clock, a 128 m spatial grid indexes them, and `CityCitizens` keeps at most 30 live actors within about 60 m of Kalev, scanning 250 residents per frame. There is no per-resident state to save. The design keeps that cost profile and adds state only where it pays off. Figures below are targets to be measured in phase 0/1, not results.

- **No node per citizen.** Residents are rows in one packed store (struct of arrays: state id, goal id, position, route cursor, next-event time, mood, memory flags). One manager owns it; only the live tier has scene nodes.
- **Three detail tiers by distance and relevance.**
  - *Live* (about 30, near the player): real rig, state machine stepped every physics frame for steering and animation, goal re-evaluated every 0.5-2 s.
  - *Abstract* (rest of the loaded area): no node. Position is interpolated along the cached street route; the state changes only at scheduled events held in a time-ordered queue. Cost scales with events per game day (about 10-20 per resident), not with frames.
  - *Dormant* (outside streaming range): schedule and next-event time only. On wake-up the record is fast-forwarded to "now".
  - Promotion and demotion copy state between a row and its actor, so nobody teleports.
- **Plan plus deviations.** The timetable stays the baseline plan. A resident departs from it only through a sparse *override* (goal, until-time, reason code), set by layer 1 or an event such as alarm, weather, market day, or a quest. Position is `plan(clock)` unless an override is active. Saves store overrides and short memory only, so they stay small and the 4,247-resident census is never serialized.
- **Layer 1 is event-driven.** Scoring runs on arrival, interrupt or a slow staggered heartbeat (hash of the resident ID), never every frame for everybody. A budgeted scheduler spends at most a fixed slice of each frame, as the roster scan already does.
- **Perception through the grid.** Alarms, crowds and "who sees this" use cell lookups on the existing grid, never pairwise checks.
- **Routes are cached.** Street-graph routes per (door, destination) are precomputed or memoised; live NPCs follow them with lane offsets. Navigation-server agents are reserved for the few live NPCs that need local avoidance.
- **Optional worker thread.** Abstract and dormant updates work on packed arrays only, so they can run on `WorkerThreadPool` and hand results to the main thread. Start single-threaded; move only if the benchmark demands it.
- **Crowds in the distance** keep using the multimesh crowd renderer.

### Dialogue at scale

Cost follows player attention, not population.

1. **Authored** (`DialogueRunner`): quest, faction and the 737 deep-card characters.
2. **Rule-selected barks**: role x mood x situation x location, with conditions. This covers most ordinary citizens at near-zero cost.
3. **LLM speech** (layer 2): only for the NPC the player is addressing or standing next to. One queue, one or two requests at a time, late answers dropped. Small fixed prompt: character card, district brief, structured state summary (goal, mood, last few facts), never raw history. The shared prefix is cached. Approaching the NPC may start a speculative greeting; an authored filler animation or bark covers the wait.
4. **NPC-to-NPC talk is not generated.** Background conversations are abstract events that move *facts* (rumours with source, age, confidence) through the social graph in the abstract tier, and surface as barks or ambient animation when the player is near. Facts are IDs, so they stay small and can feed layer 1 and the rules engine.

### Verify the scale claim

First evidence: [`reports/npc_mind_scale_spike_2026-10-08.md`](../reports/npc_mind_scale_spike_2026-10-08.md). The spike (`tools/benchmarks/npc_mind_scale_benchmark.gd`) puts the abstract tier at 0.002 ms mean per frame for 4,247 residents and under 1 ms worst case for 20,000, against 0.75 ms per frame for a naive object-per-resident update. Local-model latency is not measured yet (`tools/benchmarks/llm_npc_latency.py` is ready).

A headless benchmark with synthetic populations (5,000 and 20,000 rows) must report per-frame cost of the manager, event throughput, promotion/demotion cost, and save size; it goes into `tools/run_performance_report.sh`. Phase 0 is not done until it exists. Local model latency, memory and install size are measured in the layer-2 spike, not assumed.

## Local stack and offline contract (planned)

System 1 is layers 0 and 1 (state machines plus utility scoring, GDScript, no model). System 2 is the optional LLM. Candidates, all pending benchmark and primary-licence checks: Qwen3-0.6B (Tiny), Qwen3-1.7B (Small, default when on), Qwen3-4B (Medium), run through our own llama.cpp GDExtension with grammar-constrained output. Llama and Gemma are out unless their downstream terms are acceptable in our EULA. Everything ships in the depot: no download, no network calls, no telemetry, SHA-256 pins, fallback to layer 1 when files are absent or mismatched. Reasons and the full contract are in [ADR 0037](../adr/0037-layered-npc-mind-with-local-llm.md#3a-recommended-local-stack-fully-offline-candidates-until-the-benchmark-and-licence-checks-pass).

## Controls (planned)

- Closed output schemas; invalid output is dropped and the authored bark or layer-1 choice is used.
- Canon allowlist and post-filters (anachronism, forbidden topics, language, length).
- Models pinned by SHA-256 with a license row in `assets/SOURCES.csv`; in-process or sidecar inference, no network.
- Player setting: Off / Small / Medium. Default Off on low-spec hardware.
- Stub provider for CI; decision journal for debugging and player reports.

## Saved state (planned)

Per NPC: current goal id, location, mood, short memory summary, last accepted utterances. Loading never regenerates earlier output. Quest and ledger state are unchanged.

## Platform notes

Steam needs a live-generated AI disclosure, a guardrail description and a report path once layer 2 ships. Signed and notarised inference binaries are needed on macOS. Details and sources are in the ADR.

## Verify

Per phase (see the ADR table). Until phase 0 lands there is nothing to run.

## Limits

Everything. This page is the design contract; update the status line as phases land.
