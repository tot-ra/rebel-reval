# ADR 0008: Widen the campaign to a three-act faction RPG spanning 1343–1346

- **Status:** Accepted (maintainer-directed, 2026-07-17)
- **Supersedes:** the "single first campaign, one district, no faction sandbox" scope boundary in README (pre-0008) and the corresponding exclusions in `AGENTS.md`. Does **not** supersede ADR 0003 (no runtime LLM), ADR 0007 (AI-generated isometric presentation), or the MVP-first delivery order.

## Context

The project began as a broad RPG vision (15+ factions, Living City meters, tower capture, multi-act
story from 1342 to 1351) and was deliberately compressed into a compact 5–7 hour single-district
narrative action RPG so that a vertical slice could be proven. That compression worked: the repo now
has a tested declarative map system, a 3D orthographic view layer (ADR 0007), content schemas and
validators, a quest manager, and a demo track in flight.

Meanwhile a large amount of wider-scope material was preserved rather than deleted: legacy faction
and quest documents, and — critically — **inactive, contract-tested map prototypes** for the market
civic quarter, market square, guild hall, north quarter, Reval harbor surroundings, Paldiski, Harju
village, Padise monastery (two phases), six fortified locations (Haapsalu, Paide, Viljandi, Pöide,
Maasilinna, Karja), sacred groves, and six campaign event sites (Pärnu, Pskov arrival battle, rebel
kings' camp, Saaremaa, Swedish outpost, Swedish arrival). The maintainer has directed that the game
return to its fully fledged RPG ambition — factions, many scenes, quest lines — while keeping the
forge-choice mechanic as the unique core, keeping the game action- and story-driven, staying inside
the historical/lore guardrails of `docs/CANON.md`, shipping a playable MVP first, and producing the
entire game with AI agents.

## Decision

1. **Three-act campaign following the attested timeline.**
   - **Act 1 — The Simmering City** (spring 1343, up to the night of April 23): the current
     five-cycle Lower Town campaign, extended with the market/civic and north quarters and two
     faction quest lines. Ends at Viru Gate on St. George's Night; the former Open/Seal/Break
     *game endings* become the **act-boundary state** that shapes Act 2.
   - **Act 2 — The Fire of Rebellion** (April–May 1343): the uprising and the siege of Reval.
     Night-mission gameplay, world travel to activated outdoor locations, authored Kanavere Bog and
     Sõjamäe events, ending with the fate of the Four Kings at Paide. Attested milestones occur on
     schedule; the player steers local cost, survivors, and what each side carries into battle.
   - **Act 3 — The Iron Harvest** (1344–1346): occupation and aftermath. The forced-forge arc,
     Padise and the Saaremaa campaign (Pöide), and the campaign close at the attested 1346 sale of
     the Duchy of Estonia to the Teutonic Order. Final ending families and epilogues live here.

2. **Factions as a ledger, not a meter.** Eight active factions (Danish Crown, Livonian Order,
   Hanseatic guilds, Harju Kings, Black Cloaks, Cult of Metsik, Pskov/Novgorod emissaries,
   Vitalienbrüder), each with visible standing derived from explicit recorded events — forged
   records, quests, betrayals. No universal Hope/Fear/Chaos meters, no single morality score, no
   NPC-allegiance arithmetic, no tower-capture map game. Remaining legacy factions stay background
   canon material.

3. **The forge remains the heart, scaled up.** Faction power flows through commissions; forged
   objects are persistent narrative tokens that recur across acts (an Act 1 sabotage resurfaces in
   an Act 2 siege encounter). Kalev's own combat gear is self-forged under the same
   honest/defect/secret-feature system.

4. **MVP-first delivery order is unchanged.** D-track demo → P1 runtime foundation → P2 vertical
   slice (the playable MVP) → P3 slice validation → P4 Act 1 → P5 Act 2 → P6 Act 3. No widened-scope
   task may pull work ahead of the slice gates.

5. **AI-agent production model is a constraint, not an aspiration.** All code, content, art, and
   docs are produced by AI agents against the AGENTS.md task contract: declarative contract-tested
   maps, schema-validated content packages, AI-generated materials under the style-lock kit,
   rig-based characters, authored offline dialogue (ADR 0003 stands — no runtime LLM). Act 2/3
   content volume is only viable through the P4 quest-content pipeline task, which makes a quest an
   agent-authorable data package with generated traversal tests.

## Equivalent scope accounting (per AGENTS.md scope-change rule)

- Reinstated: multiple districts and world locations (from existing prototypes), faction standing,
  faction quest lines, three acts, night-mission templates, world travel layer.
- Removed / still excluded, named here as the offsetting scope: seamless open world; runtime LLM or
  procedural quests; party control; army/fleet battle simulation; tower-capture strategic loop;
  Living City meters and NPC-allegiance scoring; combinatorial magic, 21 elements, and NATURAL
  aspects; playable campaigns in Riga, Dorpat, or other cities; the 1351 plague epilogue (non-canon
  per `docs/CANON.md`).

## Alternatives considered

- **Keep the compact single campaign.** Rejected by maintainer direction; the preserved prototypes
  and faction material would remain dead weight.
- **Return to the full legacy vision (meters, towers, magic, 15+ factions).** Rejected: conflicts
  with canon guardrails, explodes verification surface, and reintroduces systems already judged
  incoherent with the forge-choice core.
- **Widen breadth-first (all districts before a playable loop).** Rejected: violates the MVP-first
  directive; activation of any location stays gated by the parity/activation guards.

## Consequences

- README.md is rewritten as the widened product source of truth; TODO.md gains P4 (Act 1 +
  faction/pipeline systems), P5 (Act 2), and P6 (Act 3) tracks; AGENTS.md scope lists sync to this
  ADR.
- Prototype activation tasks (market, north quarter, outdoor waves) cite this ADR as the required
  approval artifact but must still pass the existing activation and parity gates.
- `docs/CANON.md` needs Act 2/3 timeline entries (Paide, Pöide, the 1346 sale) before those acts
  enter content production.
- Legacy documents (`GAME-PILLARS.md`, `QUESTS.md`, `characters/README.md`, `story/STORY.md`)
  remain reference material; individual seeds are reactivated only through reconciled TODO tasks.
