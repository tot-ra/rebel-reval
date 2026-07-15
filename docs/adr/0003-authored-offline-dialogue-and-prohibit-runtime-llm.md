# ADR 0003: Authored Offline Dialogue and Prohibition of Runtime LLMs

**Reference:** TODO P0-005

## Status
Accepted

## Context
"Reval Rebel" aims to deliver a narrative-driven RPG experience with branching quests, character dialogues, and faction mechanics set in 1343 Estonia. The rapid adoption of generative AI and Large Language Models (LLMs) in game development presents an opportunity to generate infinite dialogue and dynamic NPC interactions. However, runtime generation introduces significant risks: non-deterministic gameplay, hallucinations that break canon or narrative logic, uncontrollable latency, ongoing API costs, and a lack of editorial control over the game's tone and scope. Furthermore, players expect a cohesive, finely crafted story, which is difficult to guarantee with procedural runtime text generation. We must decide on a definitive approach for dialogue and narrative content.

## Decision
We select an authored offline dialogue system and explicitly prohibit any runtime LLM dependencies in the game client. 

### Deterministic Offline Behavior
All dialogue, barks, quest text, and NPC behaviors must be statically authored, pre-computed, and bundled with the game release. The game client must execute deterministically, relying entirely on local, predefined data structures to evaluate dialogue conditions, branch choices, and trigger state changes. 

### Allowed Content Formats
Content can be drafted using AI/LLM tools *during the offline production phase*, but the final artifacts integrated into the game must be structured, deterministic formats:
- Dialogue trees and nodes stored in JSON schemas or Godot resource files.
- Static strings for UI, quests, and character barks.
- Fixed logic scripts (e.g., `DialogueRunner`) supporting conditional branching and state effects based on predefined game variables.

### What is Forbidden at Runtime
The following are strictly prohibited in the released game client:
- Runtime calls to external LLM APIs (e.g., OpenAI, Anthropic, local LLMs) for generating text, quests, or behaviors.
- Free-text input fields allowing players to "chat" with NPCs in a generative manner.
- Procedurally generated quests or dialogue that are not pre-approved and statically stored in the game data.

### Content Approval Requirements
Since AI agents may assist in drafting the content offline, all generated drafts require human editorial review before being integrated into the main build. Specifically:
- AI-generated dialogue, quests, and lore must undergo continuity, historical accuracy, tone, and gameplay checks.
- Drafts must receive explicit human approval (e.g., via pull request reviews or an `approved` status in the content pipeline) before being marked as canon or included in the final asset bundle.

## Alternatives
- **Runtime LLM API Integration:** Allowing NPCs to chat dynamically using remote APIs. Rejected due to latency, ongoing costs, canon-breaking hallucinations, and the inability to guarantee a cohesive narrative arc.
- **Local Small Language Models:** Embedding a small LLM in the game client. Rejected due to increased hardware requirements, bloat in the installation size, and the same fundamental issues with non-deterministic output and tone control.
- **Procedural Text Generation without LLMs:** Using complex grammar engines to generate text at runtime. Rejected because it complicates narrative design and localization, making QA testing significantly harder.

## Consequences
- **Positive:** Guaranteed narrative consistency, predictable performance, deterministic QA testing, full control over historical canon, and zero recurring server costs for dialogue generation.
- **Negative:** Infinite "dynamic" conversations are not possible. Content volume is strictly limited by the production budget (e.g., the planned 2,500-word limit for slice dialogue).
- **Process Impact:** Requires robust tooling for dialogue editing and strict adherence to the offline content approval pipeline.
