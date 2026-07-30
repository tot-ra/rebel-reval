# PSYCHE.md - Hingepuu psyche and inner-state contract

**Status:** Active design contract (P7-003)  
**Approval basis:** [ADR 0017](../adr/0017-legacy-design-reintroduction.md), [ADR 0003](../adr/0003-authored-offline-dialogue-and-prohibit-runtime-llm.md)  
**Canon labels:** Hingepuu, psyche states, and inner faces are playable **`invented`** / **`folklore`** per [`docs/CANON.md`](../CANON.md). Jungian labels are design shorthand for authored NPC-like faces, not clinical claims.  
**Legacy seeds (reference only):** [`character/PSYCHE.md`](../../character/PSYCHE.md), Ego notes in [`docs/GAME-PILLARS.md`](../GAME-PILLARS.md)  
**Paired contract:** [`docs/SYSTEMS/NATURAL.md`](./NATURAL.md)  
**Shipped slice host today:** `ReflectionModel` / reflection overlay (Duty, Fury, Mercy) - retained and extended, not deleted  
**Runtime implementation:** **P7-011** (inner-world or extended reflection host, psyche state apply/clear, save/load). This file is not runtime truth until that row verifies.

---

## 1. Purpose

Define how Kalev's inner world grows from the current **reflection-only screen** into an explorable **Hingepuu** host without:

- replacing the shipped Duty / Fury / Mercy conviction beat;
- introducing a universal morality meter;
- party control, tower-capture, or strategic Ego sims;
- restoring legacy pixel psyche / NATURAL HUD art.

Player-facing fantasy: sleep or meditation returns Kalev to the soul-tree. There he reckons with the night's work, tends NATURAL hearths, speaks with the faces of his soul, and confronts afflictions born from his deeds.

---

## 2. Relationship to the shipped reflection screen

| Layer | Status | Role |
|---|---|---|
| Reflection conviction (Duty / Fury / Mercy) | **Shipped** (P2-011) | One allowlisted morning conviction after the slice night; sets `flag.reflection.*` and one authored effect |
| Recap marks / plain summary | **Shipped** | Shows forged work and pressures under the tree |
| Explorable Hingepuu host | **P7-011** | Contains reflection as the entry rite, then optional loci (aspects, faces, demons) |
| NATURAL allocation / spend | **P7-011** | Panel or locus interaction inside the same host (NATURAL.md) |
| Full inner-demon encounters | Act-gated after P7-011 foundation | Authored confrontations; not open procedural generation |

**Extension rule:** P7-011 must keep the existing reflection API behaviour for the vertical slice. New host modes are additive flags / phases, not a rewrite that breaks `--filter=test_reflection_overlay`.

Conviction → face pressure (design default, not a morality score):

| Conviction | Face lean | Meaning |
|---|---|---|
| Duty | `face.persona` | Mask / role / obligation |
| Fury | `face.shadow` | Raw force / repressed heat |
| Mercy | `face.anima` | Empathy / connective intuition |

These leans may grant temporary dialogue tags or integration progress toward `face.self`. They do **not** create a good/evil axis and do not replace faction ledger standing.

---

## 3. Hingepuu host model

### 3.1 Entry

Allowed entry verbs (content-gated):

- morning reflection phase (existing);
- sleep / bed rest when content sets `flag.hingepuu.offer_visit`;
- authored meditation interactables (later acts).

### 3.2 Spatial metaphor (logic graph, not open world)

Hingepuu is a **small authored graph** of loci, not a seamless open map and not a second city.

| Locus ID | Kind | Player verb |
|---|---|---|
| `hingepuu.locus.reflection` | rite | View recap; choose conviction when available |
| `hingepuu.locus.nature` … `hingepuu.locus.light` | aspect hearth | Inspect rank; spend `natural.unspent_points` |
| `hingepuu.locus.persona` | face | Authored dialogue with The Persona |
| `hingepuu.locus.shadow` | face | Authored dialogue with The Shadow |
| `hingepuu.locus.anima` | face | Authored dialogue with The Anima |
| `hingepuu.locus.self` | face | Unlocks when integration threshold is met |
| `hingepuu.locus.affliction.<state>` | demon / state | Confront or study an active psyche state |

Presentation may be tree-shaped UI, staged 3D diorama, or enhanced overlay. Art choice is deferred to art-bible tasks; design only requires stable locus IDs and keyboard/gamepad focus travel.

---

## 4. Four faces (Inner Council)

| Face ID | Display | Represents | Associated aspects | Gameplay impact when integrated |
|---|---|---|---|---|
| `face.persona` | The Persona / The Smith | Mask, reputation, volition, logic | Resonance, Tenacity | Better persuasion/deception tags; `element.dominion` / `element.deception` lean |
| `face.shadow` | The Shadow / The Beast | Repressed anger, fear, raw power | Nature, Affection | Offensive burst tags; `element.fire` / `element.beast` / `element.chaos` lean |
| `face.anima` | The Anima / The Muse | Empathy, creativity, intuition | Unity, Awareness | Empathy dialogue; `element.life` / `element.hope` / `element.spirit` / `element.mind` lean |
| `face.self` | The Self / The Sage | Integrated conscience | Light | Rare permanent small bonuses to all aspects or willpower; never a win-button morality score |

Integration is tracked as integer ranks `psyche.face.<id>.integration` (0..5 design default). Raising ranks is **authored** (dialogue outcomes, demon resolutions, conviction leans), never LLM-inferred.

---

## 5. Psyche states

Psyche states are temporary (or until cleared) modifiers. Each active state is a record, not a free-text scar.

### 5.1 Catalog (ship budget)

| State ID | Type | Inspiration (legacy) | Positive effects (design) | Negative effects (design) | Example triggers (authored) |
|---|---|---|---|---|---|
| `psyche.state.ruthless` | volatile | Ruthless / Sadist | Intimidation / crit lean | Blocks empathy options; Charisma penalty | Cruel finishers; cruel dialogue ops |
| `psyche.state.exalted` | volatile | Exalted / Maniac | Faster casts / move lean | Extra damage taken; aim penalty | Near-death boss survival; monumental victory |
| `psyche.state.melancholy` | affliction | Melancholy | Intimidation resist (apathy) | Slower authored discovery bonuses; stamina regen down | Failed rescue; destroyed friendly place |
| `psyche.state.pride` | volatile | Pride / Hubris | Damage lean at full health | Defense down when hurt; blocks ask-for-help options | Undamaged win streaks; stacked intimidation success |
| `psyche.state.apathy` | affliction | Apathy / Burnout | Resist other psyche debuffs | Halved discovery bonuses; ally potency down | Ignoring repeated pleas; indifferent dialogue pattern |
| `psyche.state.paranoid` | affliction | Paranoid / Fear | Perception lean | Charisma down; some neutrals cool | Repeated ambush; betrayal beats |
| `psyche.state.obsession` | affliction | Obsession / Fixation | Bonus on tagged obsession tasks | Penalty on unrelated checks; fixated bark bias | Authored fixation flags on side goals |

Legacy creature art prompts are **inspiration only**. Production demons need new art under the art bible.

### 5.2 Apply / clear ops

| Op | Meaning |
|---|---|
| `psyche.apply_state` | Add or refresh a state with intensity 1..3 and optional expiry beat ID |
| `psyche.clear_state` | Remove a state after confrontation or authored cure |
| `psyche.confront_state` | Start authored confrontation package; success typically clears or downgrades intensity |

Fail codes: `psyche.fail.unknown_state`, `psyche.fail.already_active`, `psyche.fail.blocked`, `psyche.fail.confrontation_locked`.

### 5.3 Coupling to NATURAL

States may publish temporary deltas consumed by NATURAL.md section 3.4. Example defaults (tunable in P7-011):

| State | Example deltas |
|---|---|
| `psyche.state.ruthless` | `aspect.tenacity +2`, `aspect.unity -2` |
| `psyche.state.melancholy` | `aspect.awareness -2` |
| `psyche.state.exalted` | `aspect.affection +1`, `aspect.nature -1` (glass cannon) |
| `psyche.state.apathy` | `aspect.unity -2`, `aspect.resonance -1` |

Exact numbers are balance data; contracts only require that deltas are data-driven and save-safe.

---

## 6. Gameplay loop

1. **Action in the living city** - combat, dialogue, forge branch, or mission op emits an authored psyche hook (or none).
2. **State birth / face pressure** - `psyche.apply_state` and/or face integration delta is recorded. Presentation may show a mark on the next Hingepuu visit.
3. **Visit** - player enters the host (reflection morning or offered visit).
4. **Reckon** - reflection conviction when available; inspect marks; optional locus travel.
5. **Tend** - spend NATURAL points; speak with faces; confront demons.
6. **Return** - clear visit flag; temporary or resolved states affect the waking day.

Ignoring an affliction does not auto-resolve it. Intensity may escalate only through further authored ops, never through hidden decay clocks that invent new states.

---

## 7. Save fields

| Field | Type | Notes |
|---|---|---|
| `psyche.states` | array of `{ id, intensity, source_beat, applied_phase }` | Active states |
| `psyche.face.persona.integration` … `psyche.face.self.integration` | int | 0..5 |
| `flag.hingepuu.offer_visit` | bool | Bed / meditation offer |
| `flag.hingepuu.visit_active` | bool | Currently inside host (should clear on exit / load recovery) |
| `flag.psyche.system_enabled` | bool | Build/content gate |
| `psyche.version` | int | Start at 1 |

Retained existing fields (do not rename):

- `flag.reflection.completed`
- `flag.reflection.duty` / `fury` / `mercy`

Living City meters (`meter.hope`, `meter.fear`, etc.) are **out of scope** here; P7-004 owns them and must keep IDs distinct from `element.hope` and psyche state names.

---

## 8. UI needs (art-bible facing)

1. **Extended reflection shell** - keeps current title/recap/marks/options; adds navigation to loci when systems are enabled.
2. **Locus map or list** - seven aspect hearths + four faces + active afflictions; focus travel for keyboard/gamepad.
3. **Face dialogue host** - reuses ordinary dialogue pipeline with `char.face.*` or equivalent stable speaker IDs.
4. **Confrontation card / scene** - plain-text summary of state effects before accept/reject resolution choices.
5. **Tree vitality presentation** - optional visual of healthy vs troubled tree driven by active affliction count / face imbalance; must have plain-text equivalent.
6. **No legacy pixel HUD dependency** - new controls only.

Accessibility: every state effect listed in the confrontation UI must appear in prose, matching reflection's plain-summary precedent.

---

## 9. Slice-safe partial ship

Demo and Act 1 stay valid if psyche systems remain disabled:

1. Reflection overlay behaviour unchanged.
2. No mandatory demon confrontation on the demo path.
3. When disabled, face integration and state arrays are absent or empty and ignored.
4. Root and Ember (P4-007) stays an ambiguous folklore quest; psyche may later add optional literal inner beats behind flags without rewriting that quest's verify line.

P7-011 minimum green bar:

- apply/clear/confront failure modes tested;
- save/load round-trip for states and face ranks;
- host can open allocation (NATURAL) without breaking conviction;
- UI references no `assets/UI/character-hud` paths.

---

## 10. Content ID forms

| Kind | Form | Example |
|---|---|---|
| Face | `face.<slug>` | `face.shadow` |
| Psyche state | `psyche.state.<slug>` | `psyche.state.melancholy` |
| Locus | `hingepuu.locus.<slug>` | `hingepuu.locus.awareness` |
| Apply / clear ops | `psyche.apply_state` / `psyche.clear_state` | content effects |
| Confront op | `psyche.confront_state` | content effect |
| Fail code | `psyche.fail.<slug>` | `psyche.fail.unknown_state` |
| Speaker (optional) | `char.face.<slug>` | `char.face.persona` |

---

## 11. Non-goals

- Runtime free-text psychoanalysis or LLM-generated demons.
- A single good/evil meter labelled Ego or Conscience.
- Replacing faction standing or Living City Hope/Fear with psyche ranks.
- Party-controlled inner companions.
- Shipping legacy inspiration PNGs under `character/` as runtime assets.
- Open-world Hingepuu traversal comparable to city districts.

---

## 12. Implementation handoff

| Concern | Owns |
|---|---|
| This contract + NATURAL.md | P7-003 |
| Host runtime, save fields, tests | P7-011 |
| Combat/night verbs that apply states | P7-005 |
| City Hope/Fear bookkeeping | P7-004 / P7-012 |
| Magic reading temporary aspect deltas | P7-010 / P7-011 |

---

## 13. Source reconciliation summary

| Legacy claim | Production decision |
|---|---|
| Explorable Hingepuu soul-tree | Kept as authored locus graph inside extended reflection host |
| Seven aspect locations on the tree | Kept; shared with NATURAL.md |
| Four Jungian faces | Kept with `face.*` IDs; integration ranks authored |
| Inner demons ↔ psyche states | Kept as catalogued states with confront ops |
| Rich visual demon prompts | Inspiration only until art tasks |
| Reflection-only screen as final form | Extended, not replaced; Duty/Fury/Mercy retained |
| Individuation as ultimate goal | Kept as long-horizon `face.self` unlock, not Act 1 critical path |
