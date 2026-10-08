# NPC mind: reflex, decision model, local LLM

Status: planned ([ADR 0036](../adr/0036-layered-npc-mind-with-local-llm.md), proposed, not yet approved). Scope: how citizens and other NPCs choose goals, speak, and fight, in three optional layers. Out of scope: story-critical dialogue (stays authored, see [`DIALOGUE.md`](./DIALOGUE.md)), spirit dialogue combat ([`SPIRIT_DIALOGUE.md`](./SPIRIT_DIALOGUE.md)), runtime audio or TTS, free-text player chat, remote LLM APIs.

Nothing here is built. Existing behaviour that layer 0 will wrap lives in [`WORLD_LIFE.md`](./WORLD_LIFE.md), [`CITIZENS.md`](./CITIZENS.md) and [`TIME_AND_PHASES.md`](./TIME_AND_PHASES.md).

## Layers

1. **Reflex (layer 0).** Finite state machines per NPC: idle, walk, work, flee, fight. Runs every frame, owns movement and combat execution, depends on nothing above it.
2. **Decision model (layer 1).** Utility scoring over a closed goal list, using needs, time, weather, Hope/Fear, faction standing, relationships and memory flags. Picks the goal and records a reason code. No model files.
3. **Mind (layer 2).** Optional local LLM, asynchronous and time-boxed. Proposes a goal from the layer-1 list, a mood, or an ambient line with intent tags. A validator accepts or rejects; the rules engine alone changes game state.

Every layer works when everything above it is off, slow or failing.

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
