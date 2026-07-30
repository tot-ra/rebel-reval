# NATURAL.md - Seven-aspect progression contract

**Status:** Active design contract (P7-003)  
**Approval basis:** [ADR 0017](../adr/0017-legacy-design-reintroduction.md), [ADR 0003](../adr/0003-authored-offline-dialogue-and-prohibit-runtime-llm.md)  
**Canon labels:** NATURAL aspects are playable **`invented`** / **`folklore`** per [`docs/CANON.md`](../CANON.md). Never present aspect ranks as attested 1343 ethnography.  
**Legacy seeds (reference only):** [`character/BUILD.md`](../../character/BUILD.md), [`character/PSYCHE.md`](../../character/PSYCHE.md)  
**Paired contract:** [`docs/SYSTEMS/PSYCHE.md`](./PSYCHE.md)  
**Magic coupling:** [`docs/SYSTEMS/MAGIC.md`](./MAGIC.md) section 6  
**Runtime implementation:** **P7-011** (GameState fields, spend/grant, save/load, minimal UI host). This file is not runtime truth until that row verifies.

---

## 1. Purpose

Define how Kalev's seven NATURAL aspects grow and modify play without:

- a separate custom-hero creator (Kalev is a fixed protagonist);
- party-controlled companions or follower-cap sims;
- a universal morality score derived from aspect mix;
- restoring superseded NATURAL / element pixel HUD art (ADR 0017 art rule).

Player-facing fantasy: the smith tends seven hearths of the soul. Investing in a hearth hardens body, craft, speech, and the magic elements tied to that hearth.

---

## 2. Aspect catalog

Stable content IDs use the form `aspect.<slug>`. Display names stay English for UI strings; Estonian/Low German flavour may appear in dialogue only.

| Aspect ID | Display | Hingepuu locus (psyche host) | Physical verbs (production) | Mental / magic verbs |
|---|---|---|---|---|
| `aspect.nature` | Nature | Root system | Vitality (max health), Stability (stagger resist), Endurance (stamina) | Empowers `element.earth`, `element.metal`; longer defensive durations |
| `aspect.affection` | Affection | Base of trunk | Agility (move/dodge), Dexterity (light attack tempo), Reaction (parry window) | Empowers `element.water`, `element.air`; shorter cast wind-up |
| `aspect.tenacity` | Tenacity | Main trunk | Strength (heavy melee), Raw Power (guard break), Intimidation (checks / weaker foe hesitation) | Empowers `element.fire`, `element.beast`; offensive cast potency |
| `aspect.unity` | Unity | Large branch | Charisma (prices / social openers), Empathy (mission-ally potency), Healing Power (item/spell heal) | Empowers `element.life`, `element.hope`; support cast potency |
| `aspect.resonance` | Resonance | High windy branch | Persuasion, Deception, Leadership **signal** (bark / rally presentation only) | Empowers `element.deception`, `element.dominion`; control cast potency |
| `aspect.awareness` | Awareness | Treetop perch | Perception (traps / reveals), Wisdom (authored discovery bonuses), Cooldown (ability recovery) | Empowers `element.mind`, `element.time`; shorter cooldowns |
| `aspect.light` | Light | Sky above tree | Faith (divine rite potency / unholy resist), Spirit (`resource.willpower` pool), Elemental Connection (broad elemental scale) | Empowers `element.faith`, `element.spirit`; unlocks later 4-element cookbook band when a named TODO raises the magic cap |

### 2.1 Explicit deferrals from the legacy seed

| Legacy claim | Production decision |
|---|---|
| Character-creation screen that allocates 10 points before play | Rejected. Fixed Kalev starts with authored baselines; discretionary points land at the first Hingepuu allocation beat (section 3). |
| Leadership raises a player-commanded follower cap | Deferred forever under current ADRs. `aspect.resonance` Leadership only affects authored ally scripts, barks, and mission potency - never party control. |
| Open XP grind to level 50 as the only progress path | Softened. Aspect points are primarily **authored grants**; an XP ladder may exist later only under a named TODO and must still emit the same `natural.grant_points` ops. |
| Sub-stat spreadsheets as independent save fields | Deferred. Runtime stores **aspect ranks** only; sub-stats are derived formulas owned by combat/dialogue systems (P7-005 / P7-011). |
| Legacy `assets/UI/character-hud/el-*.png` as production HUD | Forbidden. New art-bible UI only. |

---

## 3. Progression rules

### 3.1 Baseline

| Field | Value |
|---|---|
| Starting rank per aspect | `5` |
| Discretionary points at first allocation | `10` |
| Max rank after first allocation (per aspect) | `10` (5 base + up to 5 of the 10 discretionary) |
| Hard cap per aspect | `50` |
| Points granted on each later advancement beat | `1` (default) unless content specifies otherwise |

First allocation is a **Hingepuu beat**, not a menu before New Game. Until the player completes `flag.natural.initial_allocation`, ranks stay at baseline 5/5/5/5/5/5/5 and magic uses multiplier 1.0 for aspect scaling (per MAGIC.md).

### 3.2 Grant and spend

Content and runtime speak only through these ops (P7-011 implements them):

| Op | Meaning |
|---|---|
| `natural.grant_points` | Add N unspent aspect points (`natural.unspent_points`) |
| `natural.spend_point` | Spend 1 unspent point into a chosen `aspect.*` (fails if at cap or no points) |
| `natural.set_rank` | Authored absolute set (debug / migration / story override only) |
| `natural.lock_aspect` / `natural.unlock_aspect` | Optional content gate for late-act hearths |

Fail-closed codes:

- `natural.fail.no_points`
- `natural.fail.at_cap`
- `natural.fail.locked`
- `natural.fail.unknown_aspect`
- `natural.fail.allocation_incomplete` (systems that require allocation before use)

### 3.3 Advancement sources (act-gated)

| Ship band | How points arrive | Notes |
|---|---|---|
| Slice-safe / Act 1 optional | Authored quest / reflection / forge milestones only | Demo path must run with NATURAL disabled or at baseline |
| Act 2+ | Authored grants plus optional discovery / mission awards | Still no silent dual XP store outside `natural.*` fields |
| Full Hingepuu (P7-011 host) | Visiting aspect loci may *spend* points; visits alone do not mint points | Keeps ADR 0003 / deterministic content ownership |

### 3.4 Temporary modifiers

Psyche states from [`PSYCHE.md`](./PSYCHE.md) may apply **temporary deltas** to effective ranks or derived checks. Temporary modifiers never permanently rewrite stored ranks; they compose at read time:

`effective_rank(aspect) = clamp(stored_rank + sum(psyche_deltas), 1, 50)`

---

## 4. Magic coupling (normative)

Matches MAGIC.md section 6. Each stored rank point above 0 contributes **+2%** effectiveness to associated elements:

| Aspect | Empowers |
|---|---|
| `aspect.nature` | `element.earth`, `element.metal` |
| `aspect.affection` | `element.water`, `element.air` |
| `aspect.tenacity` | `element.fire`, `element.beast` |
| `aspect.unity` | `element.life`, `element.hope` |
| `aspect.resonance` | `element.deception`, `element.dominion` |
| `aspect.awareness` | `element.mind`, `element.time` |
| `aspect.light` | `element.faith`, `element.spirit` |

Formula for an element used by a cast:

`element_multiplier = 1.0 + 0.02 * effective_rank(owning_aspect)`

If NATURAL fields are absent in a save or build, multiplier stays `1.0`. Magic must not hard-crash.

`aspect.light` Elemental Connection (+1% per rank to *all* elemental damage) is an **Act 2+** additive rider owned by P7-011 balance; slice-safe partial ship may omit it.

---

## 5. Save fields

All fields live under GameState (exact nesting is P7-011's choice) and must round-trip through `SaveService`.

| Field | Type | Notes |
|---|---|---|
| `natural.aspects.nature` … `natural.aspects.light` | int | Stored ranks; keys may be short slugs or full `aspect.*` IDs as long as tests freeze one form |
| `natural.unspent_points` | int | Spendable pool |
| `flag.natural.initial_allocation` | bool | True after first discretionary spend session closes |
| `flag.natural.system_enabled` | bool | Content/build gate; false keeps baseline-only behaviour for demo |
| `natural.version` | int | Schema version for migrations (start at 1) |

Psyche temporary deltas are **not** duplicated here; they are derived from active `psyche.state.*` records (PSYCHE.md).

Reflection conviction flags (`flag.reflection.duty` / `fury` / `mercy`) remain owned by the existing reflection system. NATURAL does not overwrite them.

---

## 6. UI needs (art-bible facing)

Required surfaces for P7-011 (no legacy pixel frames):

1. **Allocation panel** - seven named hearths, current rank, unspent points, Confirm that sets `flag.natural.initial_allocation`.
2. **Read-only aspect strip** - optional HUD / pause page showing ranks and temporary psyche tint.
3. **Hingepuu locus markers** - seven visit targets inside the psyche host (PSYCHE.md); selecting a locus opens spend or lore, not a second morality meter.
4. **Plain-text fallback** - accessibility parity with reflection: ranks and unspent points must be readable without colour-only cues.
5. **Codex cross-link** - element→aspect mapping text for magic UI (after P7-010).

Non-goals for UI:

- Restoring `assets/UI/character-hud/**` production icons.
- A pre-game class or ancestry picker.
- Party formation panels driven by Resonance.

---

## 7. Slice-safe partial ship

Vertical-slice MVP and Act 1 remain playable **with NATURAL fully disabled** (`flag.natural.system_enabled = false` or absent fields).

Partial ship (P7-011 acceptance bar):

1. Save fields round-trip with grant/spend failure modes tested.
2. First allocation beat can run as an extended reflection / Hingepuu host without breaking Duty/Fury/Mercy.
3. Magic reads ranks safely when present and uses 1.0 when absent.
4. Demo path does not require opening the allocation panel.
5. No legacy HUD assets referenced by runtime paths.

---

## 8. Content ID forms

| Kind | Form | Example |
|---|---|---|
| Aspect | `aspect.<slug>` | `aspect.tenacity` |
| Grant op | `natural.grant_points` | content effect |
| Spend op | `natural.spend_point` | `{ "aspect": "aspect.unity" }` |
| Fail code | `natural.fail.<slug>` | `natural.fail.at_cap` |
| Flag | `flag.natural.<slug>` | `flag.natural.initial_allocation` |

---

## 9. Worked examples

### 9.1 First allocation

1. Prologue / morning reflection completes as today (Duty/Fury/Mercy).
2. If `flag.natural.system_enabled` and not `flag.natural.initial_allocation`, Hingepuu offers allocation with 10 unspent points.
3. Player raises Tenacity 5→8, Awareness 5→7, Light 5→10 (spends 3+2+5).
4. Confirm writes ranks, zeroes or retains remainder per UI rules, sets `flag.natural.initial_allocation`.

### 9.2 Quest grant

Forging aftermath content applies `{ "op": "natural.grant_points", "amount": 1 }`. Later Hingepuu visit spends it into `aspect.unity` for a social check branch.

### 9.3 Magic scale

`spell.pagan.spark` uses `element.fire`. With `aspect.tenacity` stored rank 8 and no psyche delta, multiplier = `1.0 + 0.02 * 8 = 1.16`.

---

## 10. Non-goals

- Runtime LLM allocation advice or procedural aspect invention.
- Universal good/evil score from high Light vs high Tenacity.
- Party control or army command via Resonance Leadership.
- Replacing faction ledger or Living City meters (P7-004 owns city pressure IDs).
- Shipping legacy NATURAL HUD sprites.

---

## 11. Implementation handoff

| Concern | Owns |
|---|---|
| This contract + PSYCHE.md | P7-003 |
| Explorable host, save/load, allocation UI | P7-011 |
| Combat derived formulas using aspects | P7-005 |
| Magic grant/cast reading multipliers | P7-010 / P7-011 |
| Living City Hope vs `element.hope` naming | P7-004 (keep IDs distinct) |

---

## 12. Source reconciliation summary

| Legacy claim | Production decision |
|---|---|
| Seven aspects Nature…Light | Kept with `aspect.*` IDs |
| Base 5 + 10 discretionary + max 50 | Kept; discretionary moves to first Hingepuu allocation |
| Sub-stat bullets per aspect | Kept as design formulas; not separate save keys |
| Aspect→element +2% | Kept; normative with MAGIC.md |
| Pixel HUD illustrations | Inspiration only |
| Character creator | Rejected for fixed Kalev |
