# ADR 0036: Layered NPC mind: state machines, decision model, optional local LLM

- **Status:** Proposed (maintainer direction 2026-10-08; needs human approval and the scope offset below before any code)
- **Scope:** How citizens and other NPCs choose where to go and why, what they say, and how they fight. Three layers, each optional above the first.
- **Amends:** [ADR 0003](./0003-authored-offline-dialogue-and-prohibit-runtime-llm.md). It lifts the runtime-LLM prohibition for layer 2 only, under the controls below. It also drops "all NPC behaviour is deterministic" for layers 1 and 2. The rest of ADR 0003 (human review of drafted content, authored story dialogue) stands.
- **Does not supersede:** ADR 0008 (scope), ADR 0033 (spirit dialogue combat stays authored), ADR 0019/0027/0028 (seamless world), ADR 0035 (no runtime audio generation or TTS).
- **Feeds:** [`SYSTEMS/NPC_MIND.md`](../SYSTEMS/NPC_MIND.md).

## Context

The maintainer wants a more immersive, believable city: NPCs whose movement, speech and fighting look motivated rather than scripted. ADR 0003 forbade runtime LLMs and required determinism, mainly for narrative control, QA, and install size. The maintainer has decided that immersion outweighs determinism for ambient NPC behaviour, and that the models must be ones we ship and control, not remote APIs.

Platform rules (researched 2026-10-08, secondary sources; re-verify in Steamworks before release):

- Steam allows runtime-generated AI content but requires a *live-generated* disclosure, a description of guardrails against inappropriate or illegal output, and exposes an overlay tool for player reports. Failure to guard can get the app pulled. Disclosures are public on the store page.
- Epic, GOG and consoles have no published AI-disclosure rule; console certification terms are under NDA and unknown. itch.io has a disclosure field.
- macOS distribution on Steam wants 64-bit, notarised builds, so any bundled inference binary must be signed and notarised too.

## Decision

### 1. Three layers, strict direction of dependence

| Layer | Name | Runs | Cost | Authority |
|---|---|---|---|---|
| 0 | **Reflex**: finite state machines (idle, walk, work, flee, fight states), existing timetables and patrols | every frame | negligible | Always on. Owns movement, collision, navigation, combat execution. Never waits on anything above. |
| 1 | **Decision model**: utility scoring over a closed set of goals using needs, time, weather, Living City Hope/Fear, faction standing, relationships, memory flags | every 0.5-5 s per NPC, staggered | low (pure GDScript) | Picks the next goal for layer 0 and writes a short reason code. Optional seeded RNG for tie-breaks. |
| 2 | **Mind**: local LLM | async, seconds, budgeted | high (CPU/GPU, RAM) | Proposes. Never executes. Optional per player setting. |

Rules that keep the stack safe:

1. **Each layer must work with everything above it absent.** The game ships and is fully playable at layer 0 + 1. Layer 2 off, slow, crashed or timed out means NPCs keep following layer 1.
2. **The LLM never sits in a frame loop.** Requests are queued with a deadline; late answers are dropped.
3. **Closed vocabulary.** The LLM returns structured output chosen from schemas: a goal id from the layer-1 goal list, a mood tag, a speech line plus intent tags from a fixed list (`greet`, `warn`, `gossip`, `refuse`, `trade_offer`, ...). Free-form commands, code, file paths, or new goal ids are rejected by a validator.
4. **The LLM cannot write game state.** Quest flags, faction ledger, inventory, save data and Hope/Fear change only through the existing rules engine. Intent tags are suggestions the rules engine may map to its own effects or ignore.
5. **Canon lock.** Story-critical conversations (quest, faction, prologue, spirit dialogue per ADR 0033) stay authored. LLM speech is limited to ambient citizens, barks, and small talk, and may use only facts from the character card, the district brief, and a canon allowlist. A post-filter rejects anachronism and forbidden-topic hits and falls back to an authored bark.
6. **Combat.** Execution and tactics are layers 0 and 1 (state machines + utility on distance, stamina, morale, allies). The LLM may set temperament or an opening intent at engagement start (aggressive, cautious, parley, flee), never per-frame actions.

### 2. Determinism is relaxed, persistence is not

- Layers 1 and 2 may be non-reproducible. Nothing requires identical replays.
- **Saved state is still exact.** A save stores each NPC's current goal, location, mood, short memory summary and the last N accepted utterances, so loading never regenerates the past. Quest and ledger state keep their existing exact semantics.
- A **decision journal** records layer-1 reason codes and every accepted/rejected layer-2 proposal (ids, validator verdict, latency) for debugging and for the Steam report-handling path. It is bounded and local.
- CI and tests use a **stub provider** with scripted answers, so the whole stack is testable without a model.

### 3. We control the models

- Models, runtime and weights are bundled or fetched from our own storage, pinned by SHA-256, with a license row per model in `assets/SOURCES.csv`. The license allowlist mirrors ADR 0035: commercial use must be confirmed against the primary license text at acquisition.
- Inference runs in-process via a GDExtension (e.g. llama.cpp) or as a sidecar process under our control; no network calls, no telemetry. Choice is made in the layer-2 spike.
- Hardware tiers: Off (default on low-spec), Small (about 1-3B quantised), Medium. Memory and install-size budgets are set in the spike and recorded in `NPC_MIND.md`.
- Fine-tuning or prompt packs are authored offline and reviewed under ADR 0003's approval rule.

### 4. Platform compliance is part of the feature

- Steam live-generated disclosure text, guardrail description, and a player report path are deliverables of the layer-2 phase, not afterthoughts.
- Input guardrails: no free-text player chat in the first release. The player acts through existing verbs; NPC speech is generated from game state, not from typed prompts. That removes the main abuse vector. A typed-chat mode needs its own ADR.
- Output guardrails: validator, profanity/hate/real-world-person filter, canon filter, length cap, authored fallback.
- Signed and notarised inference binaries for macOS.

### 5. Phases

| Phase | Deliverable | Verify |
|---|---|---|
| 0 | Layer 0 formalised: one reusable NPC state machine over the existing timetables, patrols and combat states | Godot tests; no behaviour change in Lower Town |
| 1 | Layer 1: goal list, needs, utility scorer, reason codes, decision journal, save fields | Tests on scoring and save/load; a captured day in Lower Town with reason codes |
| 2 | Layer 2 spike: provider interface, stub provider, one real local model, validator, budget and timeout handling | Stub-driven tests; latency/memory report; model off still plays |
| 3 | Ambient speech and barks through layer 2 with filters and fallbacks | Validator and filter tests; red-team list of bad outputs |
| 4 | Combat temperament hook and Steam/compliance package | Combat test with stub; disclosure text drafted |

Each phase is its own task with allowed files and verification, per AGENTS.md. Phase 1 is useful on its own and carries no policy risk, so it goes first.

## Scope offset (required by AGENTS.md; maintainer must choose)

This adds a major system. Equivalent-cost scope must be named as removed or deferred before approval. Candidates, none chosen yet:

- Defer authored ambient bark volume beyond the slice, since layer 2 covers it later.
- Defer Act 2/3 per-NPC authored routines in favour of layer-1 goals.
- Defer hand-authored night patrol variants.

## Alternatives

- **Keep ADR 0003 unchanged.** Safest and deterministic, but no emergent small talk and rigid routines. Still the fallback behaviour of this design.
- **LLM drives everything (including movement and combat).** Rejected: latency, cost per NPC, and unrecoverable failure modes. The layered design keeps the game playable when the model fails.
- **Remote LLM API.** Rejected: cost, offline play, privacy, dependency on a vendor, and a harder Steam guardrail story.
- **Layer 1 only, no LLM.** A valid stopping point after phase 1; layer 2 stays gated on the spike results and the offset.

## Consequences

- **Positive:** believable motion and reasons from layer 1 with no model; optional richer speech; controlled models; every layer degrades safely.
- **Negative:** non-reproducible behaviour makes bug reports harder (mitigated by the journal); new QA surface (filters, red-teaming); hardware, install-size and notarisation work; Steam live-generated disclosure becomes public on the store page; moderation responsibility for generated text.
- **Process:** when this ADR is accepted, update README, AGENTS.md (Out of scope line, determinism wording), `schemas/README.md`, and the `deterministic_offline` content flag wording in the same change. Add `NPC_MIND.md` to the docs hub. Until acceptance those statements remain true and no layer-2 code may land.
