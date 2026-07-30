# MAGIC.md - Dual-school magic contract

**Status:** Active design contract (P7-002)  
**Approval basis:** [ADR 0017](../adr/0017-legacy-design-reintroduction.md), [ADR 0003](../adr/0003-authored-offline-dialogue-and-prohibit-runtime-llm.md)  
**Canon labels:** Dual-school magic is playable **`folklore`** / **`invented`** per [`docs/CANON.md`](../CANON.md). Never present spells or rites as attested 1343 historical practice.  
**Legacy seeds (reference only):** [`character/MAGIC-ELEMENTS.md`](../../character/MAGIC-ELEMENTS.md), [`character/PAGAN-MAGIC.md`](../../character/PAGAN-MAGIC.md), [`character/CHRISTIAN-MAGIC.md`](../../character/CHRISTIAN-MAGIC.md)  
**Runtime implementation:** **P7-010** (schemas, GameState, forge-conduit hooks, tests). This file is not runtime truth until that row verifies.

---

## 1. Purpose

Define how Reval Rebel ships deterministic dual-school magic without:

- runtime LLM or procedural spell invention (ADR 0003);
- a universal morality score;
- party control or army/fleet magic;
- restoring superseded NATURAL/element pixel HUD art (ADR 0017 art rule).

Player-facing fantasy: Kalev shapes power the way he shapes metal - through the hammer as conduit - while pagan combinatorial practice and Christian divine rites remain philosophically distinct schools.

---

## 2. Schools

| School ID | Display | Core fantasy | Composition model | Primary resource |
|---|---|---|---|---|
| `school.pagan` | Pagan Magic / Old Ways | Direct imposition of will on living world and spirits | Authored **element sequences** looked up into fixed spell records | `resource.willpower` |
| `school.divine` | Divine Rites / New Faith | Petition and conduit for ordered grace / judgment | Authored **fixed rites** (no free recombination at cast time) | `resource.piety` |

Shared rules:

- Both schools resolve through the same cast pipeline: grant → validate → spend resource → apply authored effects → ledger/quest hooks.
- Unknown or locked combinations **fail closed** with a deterministic reason code. They never synthesize a new effect at runtime.
- Kalev may unlock access to both schools over the campaign; access is content-gated, not automatic omniscience.

### 2.1 Pagan spellforging (deterministic)

Legacy prose allows combining up to four elements. Production rule:

1. A cast request is an ordered list of `element.*` IDs, length 1..3 for shipped runtime (**P7-010**). Length 4 remains a later-act content option only if a named TODO raises the cap.
2. The runtime normalizes the sequence to a canonical key and looks up an authored `spell.*` record.
3. If no record exists, or the player lacks grant/teacher flags, cast fails with `magic.fail.unknown_sequence` or `magic.fail.locked`.
4. UI may present forging as creative composition; the data model is a closed cookbook. Offline tools may help authors draft recipes; players never invent spells in the client.

First element = intent / delivery family (projectile, self, touch, area, melee-enhance). Later elements = authored modifiers already baked into that recipe's effect block - not free-form runtime modifiers.

### 2.2 Divine rites (fixed liturgy)

1. Rites are learned as whole `rite.*` records. Players do not assemble element chips at cast time.
2. Element tags on a rite are catalog metadata (for NATURAL scaling, teachers, and codex UI), not a second forging UI.
3. **Martyrdom path:** selected rites may spend `resource.health` instead of or in addition to piety, per authored `cost` blocks. Death-triggered rites (e.g. final radiance) are explicit content, not generic on-death scripting.
4. **Endowment rites** that permanently or long-duration imbue equipment are out of the slice-safe partial ship; they may land after Act 1 via a named content row once P7-010 foundations exist.
5. **Congregational rites** that require multiple faithful participants stay deferred until a mission/ally framework can host them without party-control UI (see P5 / P7-005).

---

## 3. Element budget

Legacy seeds list many pagan, Christian, and shared elements. Production keeps a **catalog** and a **ship budget**.

### 3.1 Catalog (design authority)

Retain the legacy element vocabulary as the long-term catalog. Each element is a stable content ID:

| Family | Element IDs |
|---|---|
| Pagan-primary | `element.life`, `element.death`, `element.spirit`, `element.chaos`, `element.fire`, `element.water`, `element.earth`, `element.air`, `element.blood`, `element.beast`, `element.freedom` |
| Divine-primary | `element.order`, `element.faith`, `element.hope`, `element.dominion`, `element.sacrifice`, `element.light`, `element.judgment` |
| Shared | `element.time`, `element.mind`, `element.metal`, `element.deception`, `element.fear` |

Canon: every element and spell/rite effect is **`invented`** gameplay framed through **`folklore`** belief in fiction. Do not cite them as historical liturgy or ethnography.

### 3.2 Ship budgets (act-gated)

| Ship band | Max distinct elements granted to the player | Max authored castables in the band | Notes |
|---|---|---|---|
| Slice-safe partial (P7-010 foundation demos) | 6 | 8 (`spell.*` + `rite.*` combined) | Forge-path starter only; demo must still run with magic disabled |
| Act 1 optional deepen | 10 | 20 | Teacher NPCs / quest grants only; no open cookbook dump |
| Act 2+ | catalog ceiling | content-budgeted per act package | Faction three-element signatures may unlock here |

**Slice-safe starter set (authoritative for P7-010 examples):**

- Pagan: `element.fire`, `element.metal`, `element.earth`, `element.water`, `element.life`, `element.mind`
- Divine (hammer-as-holy-symbol path): `element.faith`, `element.order`, `element.sacrifice` (tags on rites; not free chips)
- Shared used by starter recipes: `element.metal`, `element.mind`

Deferred from partial ship (keep in catalog, do not grant by default): `element.chaos`, `element.blood`, `element.beast`, `element.freedom`, `element.death`, `element.spirit`, `element.air`, `element.hope`, `element.dominion`, `element.light`, `element.judgment`, `element.time`, `element.deception`, `element.fear`.

Legacy faction spell lists (Metsik, Novgorod, Veiled Council, Black Cloaks, Hanseatic, Livonian Order, Pskov) are **seed catalogs**, not auto-ship content. Promote per act package with teacher flags and ledger consequences.

---

## 4. Hammer as conduit (Kalev)

Kalev's hammer is the unique bridge between craft identity and both schools.

| Mode | School | Player-visible rule |
|---|---|---|
| `conduit.forge_spell` | `school.pagan` | While hammer is equipped (or forge-bound in a consecrated smithy interaction), pagan casts that list `requires_conduit: hammer` may resolve. Striking / quench / anvil gestures are presentation hooks, not separate combat verbs beyond existing hammer combat. |
| `conduit.forge_rite` | `school.divine` | The hammer may act as holy symbol for rites tagged `allows_hammer_symbol: true`. Anvil or ground strike can be the cast animation for those rites. |
| Unarmed / other weapon | either | Casts without conduit requirement still work if granted; conduit-gated recipes fail with `magic.fail.needs_hammer`. |

Constraints:

- Hammer conduit does **not** invent new hammer combat techniques by itself. Combat technique expansion stays on combat/P7-005 rows.
- Conduit state is saveable (`flag` / equipment / grant), never inferred from opaque LLM narrative.
- Non-Kalev casters (future NPCs) use their own authored conduits or none; they do not silently share Kalev's forge bridge.

---

## 5. Resources and failure modes

| Resource ID | Used by | Regen / spend policy (design) |
|---|---|---|
| `resource.willpower` | pagan spells | Spent per spell `cost.willpower`; regen via rest, items, and authored beats (P7-010 details) |
| `resource.piety` | divine rites | Spent per rite `cost.piety`; raised/lowered by authored devotion and faction-adjacent events - not a universal good meter |
| `resource.health` | martyrdom rites | Only when rite `cost.health` is present |

Stable failure codes for tests and UI:

- `magic.fail.unknown_sequence`
- `magic.fail.locked`
- `magic.fail.needs_hammer`
- `magic.fail.insufficient_willpower`
- `magic.fail.insufficient_piety`
- `magic.fail.insufficient_health`
- `magic.fail.wrong_school`
- `magic.fail.suppressed` (zone, silence, quest block)

Grant / revoke must be explicit content ops (`magic.grant`, `magic.revoke`) so P7-010 can test them without shipping a full spell list.

---

## 6. NATURAL aspect coupling

Legacy rule: each NATURAL aspect point adds **+2%** effectiveness to associated elements.

Normative mapping (closed by **P7-003** in [`NATURAL.md`](./NATURAL.md)):

| Aspect | Empowers elements |
|---|---|
| `aspect.nature` | `element.earth`, `element.metal` |
| `aspect.affection` | `element.water`, `element.air` |
| `aspect.tenacity` | `element.fire`, `element.beast` |
| `aspect.unity` | `element.life`, `element.hope` |
| `aspect.resonance` | `element.deception`, `element.dominion` |
| `aspect.awareness` | `element.mind`, `element.time` |
| `aspect.light` | `element.faith`, `element.spirit` |

- Runtime must read aspect ranks from the NATURAL/psyche save fields defined in NATURAL.md / PSYCHE.md (**P7-011**).
- If NATURAL is not yet granted in a build, magic uses baseline effectiveness (multiplier 1.0). Magic must not hard-crash when aspects are absent.
- Do not restore legacy pixel aspect HUD assets; new UI is art-bible work.

---

## 7. Content ID forms

| Kind | Form | Example |
|---|---|---|
| School | `school.<slug>` | `school.pagan` |
| Element | `element.<slug>` | `element.fire` |
| Spell (pagan) | `spell.<school_slug>.<slug>` | `spell.pagan.spark` |
| Rite (divine) | `rite.<slug>` | `rite.blade_of_judgment` |
| Grant op | `magic.grant` / `magic.revoke` | content effect ops |
| Resource | `resource.<slug>` | `resource.willpower` |
| Failure | `magic.fail.<slug>` | `magic.fail.locked` |
| Conduit mode | `conduit.<slug>` | `conduit.forge_spell` |
| Teacher / recipe unlock flag | `flag.magic.<slug>` | `flag.magic.taught_forgefire` |

Recipe identity for pagan multi-element spells is the authored spell ID, not the raw sequence string. Sequences are an alternate key on the record (`sequence: ["element.fire", "element.air"]`) for lookup and codex display.

JSON packages live under future `content/packages/` or examples owned by **P7-010**; this design forbids ad-hoc runtime dictionaries as the long-term escape hatch.

---

## 8. Slice-safe partial ship

The vertical-slice MVP and Act 1 release remain playable **with magic fully disabled**.

Partial ship (P7-010 acceptance bar):

1. Schemas + validator accept example `spell.*` / `rite.*` / grant ops.
2. GameState fields for willpower, piety, and known grants round-trip in save tests.
3. Forge-conduit hooks exist on Kalev hammer equip / smithy interaction.
4. At most the starter budget in section 3.2 is granted in example content.
5. Demo path (menu → Lower Town → forge → Mart / spearhead loop) does not require casting.
6. **P4-007 Root and Ember** remains valid: quest stays understandable without literal magic confirmation. Later packages may add optional literal branches behind flags without rewriting that quest's historical verify line.

Out of partial ship:

- full 21-element player unlock;
- endowment / congregational rite frameworks;
- faction signature three-element libraries;
- magic-required critical path in slice or Act 1;
- legacy element HUD sprites.

---

## 9. Worked starter recipes (examples for P7-010)

These are design stubs, not shipped balance.

| ID | School | Sequence / tags | Effect summary | Conduit |
|---|---|---|---|---|
| `spell.pagan.spark` | pagan | `[fire]` | Minor fire projectile | optional |
| `spell.pagan.reinforce` | pagan | `[metal]` | Short self armor buff | optional |
| `spell.pagan.tremor` | pagan | `[earth]` | Short foot stagger pulse | optional |
| `spell.pagan.healing_mist` | pagan | `[water, life]` | Small ally heal area | optional |
| `spell.pagan.forgefire_weapon` | pagan | `[fire, metal, mind]` | Temporary fire on melee strikes | `conduit.forge_spell` |
| `spell.pagan.earthen_wall` | pagan | `[earth, metal, life]` | Short blocking earth segment | `conduit.forge_spell` |
| `rite.blessing` | divine | tags `faith` | Short self damage buff | optional / hammer symbol allowed |
| `rite.blood_for_belief` | divine | tags `sacrifice`, `faith` | Spend health for ally area heal | `conduit.forge_rite` preferred |

---

## 10. Non-goals

- Runtime free-text spell chat or LLM-authored combinations.
- Procedural quest generation that invents spells.
- Party-controlled mage companions.
- Tower-capture or strategic-layer magic.
- Universal good/evil score driven by school choice (pagan vs divine is philosophical access, not morality).
- Shipping legacy `assets/UI/character-hud` element icons as production UI.

---

## 11. Implementation handoff

| Concern | Owns |
|---|---|
| This contract | P7-002 (closed when verify line passes) |
| NATURAL / psyche fields that scale elements | P7-003 (closed: NATURAL.md / PSYCHE.md), P7-011 |
| Living City Hope/Fear vs piety / hope element naming collision | P7-004 must keep `resource.piety` and city `meter.hope` distinct IDs |
| Combat verbs / night templates using casts | P7-005 |
| Schemas, GameState, forge hooks, tests | P7-010 |
| Full aspect-scaled casting UI | P7-011 |

---

## 12. Source reconciliation summary

| Legacy claim | Production decision |
|---|---|
| Two schools, hammer conduit, aspect→element power | Kept |
| Flexible pagan forging up to 4 elements | Kept as fantasy; runtime cookbook length 1..3 until a later TODO raises cap; unknown combos fail closed |
| Divine fixed rites, martyrdom health spend, endowments, congregational rites | Fixed rites + martyrdom kept; endowments/congregational deferred |
| Large faction spell lists | Seed catalogs; promote per act package |
| Full element zoo immediately | Catalog kept; ship budgets act-gated |
| Spell lists as open creativity at runtime | Rejected under ADR 0003 - authored offline only |
