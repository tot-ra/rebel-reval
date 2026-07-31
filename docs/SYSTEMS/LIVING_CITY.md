# LIVING_CITY.md - Hope / Fear city pressure vs faction ledger

**Status:** Active design contract (P7-004)  
**Approval basis:** [ADR 0017](../adr/0017-legacy-design-reintroduction.md), [ADR 0008](../adr/0008-three-act-campaign-and-faction-scope.md)  
**Canon labels:** Living City Hope / Fear pressure is playable **`invented`** per [`docs/CANON.md`](../CANON.md). Never present meters as attested 1343 municipal statistics.  
**Legacy seeds (reference only):** [`docs/GAMEPLAY.md`](../GAMEPLAY.md), [`docs/GAME-PILLARS.md`](../GAME-PILLARS.md)  
**Shipped layers today:** `FactionLedger` / `record_faction_event` (P4-016), `DistrictPressureModel` (P4-017), slice `pressure.suspicion` / `pressure.solidarity` / `pressure.scarcity`  
**Runtime implementation:** **P7-012** (Living City event ops, save fields, district bark/patrol/price hooks, tests). This file is not runtime truth until that row verifies.

---

## 1. Purpose

Define how Reval Rebel ships city-scale **Hope** and **Fear** without:

- a universal good/evil morality score;
- a single **Balance of Power** aggregate that collapses faction standing;
- silent dual bookkeeping against the per-faction ledger;
- tower-capture strategic loops or army/fleet sims;
- restoring superseded ruler/rebel balance HUD pixel art.

Player-facing fantasy: Kalev's forged work and night deeds do not only change who trusts him. They change how the street feels - whether neighbours dare speak of rising, and whether the watch's grip tightens.

---

## 2. Bookkeeping layers (explicit)

Four layers stay distinct. Content may write more than one in the same effect list; the runtime never infers one layer from another unless an authored bridge effect says so.

| Layer | Stable IDs / keys | Written by | Player-facing home | Role |
|---|---|---|---|---|
| Faction ledger | `faction.*` standing from `ledger.*` events | `record_faction_event` (shipped P4-016) | Journal factions tab | Who remembers what Kalev did for or against that faction |
| Slice personal pressures | `pressure.suspicion`, `pressure.solidarity`, `pressure.scarcity` | `adjust_pressure` (shipped) | Reflection recap / slice aftermath | Immediate personal consequence triad for the vertical slice and Act 1 packages |
| Living City meters | `living_city.hope`, `living_city.fear` | `record_living_city_event` (**P7-012**) | City pressure UI (new art-bible controls) | Broader rebel morale vs civic-order atmosphere |
| District pressure | derived `pressure_tier` | `DistrictPressureModel` (shipped P4-017; extended by P7-012) | Patrol density, prices, bark pools | Local street state for a district |

### 2.1 Complement rule (normative)

Living City **complements** the faction ledger. It does **not** replace ledger standing, and ledger standing is **not** folded into Hope or Fear.

- Ledger answers: "What does this faction believe about Kalev?"
- Hope / Fear answer: "How emboldened or cowed does the city feel?"
- A forged event that only records a ledger delta must not silently change Hope / Fear.
- A Living City event that only changes Hope / Fear must not silently change faction standing.
- When both should move, content authors list both ops in the same effect package.

### 2.2 Rejected aggregates

| Legacy claim | Production decision |
|---|---|
| Single Balance of Power meter from Hope vs Fear or faction power sums | **Rejected.** P4-016 already forbids a GameState balance-of-power / morality aggregate. |
| Victory by controlling 18 of 35 towers | **Rejected.** Tower-capture stays out until a later ADR. |
| City meter = sum of NPC allegiance scores (-1/0/+1) | **Rejected** as an aggregate. Use per-character relationships (P4-031) and explicit Living City events when an influential NPC sway is meant to move the street. |
| Hope = sum(rebel faction standing); Fear = sum(ruler faction standing) | **Rejected.** No automatic ledger roll-up. |

---

## 3. Meters

### 3.1 Hope (`living_city.hope`)

**Display:** Rebel Morale / Hope  
**Meaning:** Confidence and boldness among Estonian rebels and their sympathizers; street willingness to shelter, tip, chalk, or sing coded songs.  
**Range:** integer `0..20`, default `8` (tenuous spring calm).  
**Typical authored deltas:** `+1..+3` or `-1..-2` per named event.

Increases with public defiance that the street notices, successful sabotage framed as rebel courage, aid that neighbours can retell.  
Decreases with crushed uprisings, public humiliations of rebel contacts, or visible failure of a night job.

### 3.2 Fear (`living_city.fear`)

**Display:** Civic Order / Fear  
**Meaning:** Grip and control of ruling factions as felt on the street - watches, curfew bite, tight-lipped neighbours.  
**Range:** integer `0..20`, default `8`.  
**Typical authored deltas:** `+1..+3` or `-1..-2` per named event.

Increases with public arrests, successful counter-insurgency, reliable watch hardware, martial spectacle.  
Decreases when the watch is humiliated, curfew breaks become common knowledge, or Order standing collapses in a district after a visible loss.

### 3.3 Independence of Hope and Fear

Hope and Fear are **not** forced inverses. Both may rise after a bloody night (rebels emboldened, watch also cracking down). Both may fall after a quiet market week. UI may show them as a tug-of-war metaphor, but save state keeps two independent integers.

### 3.4 Naming collisions

| ID | Domain | Must not confuse with |
|---|---|---|
| `living_city.hope` | City meter | `element.hope` (MAGIC.md divine-primary element) |
| `living_city.fear` | City meter | `element.fear` (MAGIC.md shared element) |
| `pressure.solidarity` | Slice personal pressure | Not an alias of Hope; may lean toward Hope presentation in UI copy only |
| `pressure.suspicion` | Slice personal pressure | Not an alias of Fear; may lean toward Fear presentation in UI copy only |

---

## 4. Event model (P7-012 contract)

### 4.1 Record op

```json
{
  "op": "record_living_city_event",
  "key": "living.bell_and_chain.honest_hold",
  "hope_delta": 0,
  "fear_delta": 1,
  "summary": "A true Viru chain steadies the watch's grip on the gate."
}
```

Rules:

1. `key` is a unique event ID (`living.*`). Replaying the same key is a no-op (idempotent, same spirit as ledger events).
2. At least one of `hope_delta` / `fear_delta` must be a non-zero integer in `-5..+5`.
3. Summary is player-visible journal / debug text.
4. Unknown ops fail closed in the content validator.

### 4.2 Save fields (P7-012)

| Field | Type | Notes |
|---|---|---|
| `living_city.hope` | int 0..20 | Current Hope |
| `living_city.fear` | int 0..20 | Current Fear |
| `living_city.events` | map of event_id → {hope_delta, fear_delta, summary} | Explicit history; meters recompute by summing clamped deltas from default, or store current + history (implementation choice documented in P7-012 tests) |

Meters must round-trip through `SaveService` without a morality aggregate key.

### 4.3 Read conditions (P7-012)

Content may gate with:

- `living_city_hope_at_least` / `living_city_hope_at_most`
- `living_city_fear_at_least` / `living_city_fear_at_most`

These sit beside existing `faction_standing_at_least` checks. Quest packages must not invent a `morality_at_least` op.

---

## 5. Interaction with shipped systems

### 5.1 Faction ledger (P4-016)

Unchanged. Standing stays `-3..+3` from explicit `ledger.*` events only. Living City never writes `_faction_events`.

### 5.2 District pressure (P4-017 → P7-012)

Today `DistrictPressureModel` uses district flags + controlling/opposition ledger standing.  
**P7-012** may add Hope / Fear as additional tier inputs with authored thresholds, for example:

- Hope ≥ 14: prefer unrest-leaning bark pools when opposition standing is also high;
- Fear ≥ 14: bump tier toward crackdown unless controlling standing is Ally.

Exact numeric bridges live in P7-012 tests; this contract only requires that bridges are **authored and documented**, not silent averages of all eight factions.

### 5.3 Slice pressures

`pressure.suspicion` / `solidarity` / `scarcity` remain the Act 1 personal triad. They continue to drive reflection plain text and existing slice aftermath. P7-012 must not delete them. Optional content may write both a slice pressure adjust and a Living City event in one package when the beat is both personal and city-visible.

### 5.4 NPC allegiance pressure

Legacy GAMEPLAY.md allegiance scores are reinterpreted as:

1. Per-character relationship memory (shipped P4-031);
2. Optional authored Living City events when a named influential NPC (guild master, priest, carter foreman) is swayed in a way the street would notice;
3. Never a global sum stored as Balance of Power.

### 5.5 Psyche / NATURAL / magic

Hingepuu faces and NATURAL aspects do not drive Hope / Fear. Magic may apply Living City ops only through authored content effects on spells/rites (MAGIC.md ledger/quest hooks), never through automatic school → meter mapping. `element.hope` / `element.fear` remain magic catalog IDs only.

---

## 6. Worked examples

Each example shows **one forged (or climax) event package** updating ledger and Living City together, with no morality score.

### 6.1 Bell and Chain - honest hold (reliable Viru chain)

Shipped ledger today:

```json
{
  "op": "record_faction_event",
  "key": "ledger.bell_and_chain.honest_hold",
  "value": "faction.livonian_order",
  "amount": 1,
  "summary": "Forged a reliable Viru Gate chain and striker for the watch."
}
```

Living City companion (P7-012 content add):

```json
{
  "op": "record_living_city_event",
  "key": "living.bell_and_chain.honest_hold",
  "hope_delta": 0,
  "fear_delta": 1,
  "summary": "A true Viru chain steadies the watch's grip on the gate."
}
```

Result: Order standing +1; Fear +1; Hope unchanged; no universal morality key.

### 6.2 Bell and Chain - secret release pin

Shipped ledger: `faction.harju_kings` +1 (`ledger.bell_and_chain.secret_release`).

Living City companion:

```json
{
  "op": "record_living_city_event",
  "key": "living.bell_and_chain.secret_release",
  "hope_delta": 2,
  "fear_delta": -1,
  "summary": "Word spreads that the eastern gate can open for friends in the night."
}
```

Result: Harju standing +1; Hope +2; Fear -1. Still no aggregate score.

### 6.3 Bell and Chain - hidden fracture (subtle defect)

Shipped ledger: `faction.black_cloaks` +1 (`ledger.bell_and_chain.hidden_fracture`).

Living City companion:

```json
{
  "op": "record_living_city_event",
  "key": "living.bell_and_chain.hidden_fracture",
  "hope_delta": 1,
  "fear_delta": 0,
  "summary": "Quiet hands know the chain will fail when the street needs it."
}
```

Result: Black Cloaks standing +1; Hope +1; Fear unchanged until the fracture is discovered (a later discovery event may raise Fear and drop Order standing via a second ledger event).

### 6.4 Discovery aftermath (second event, not auto-inferred)

If watch smiths discover the fracture later, content fires a **new** pair:

- `ledger.bell_and_chain.fracture_exposed` → `faction.livonian_order` `-2`
- `living.bell_and_chain.fracture_exposed` → Hope `-1`, Fear `+2`

The runtime does not invent this from the original forge choice.

---

## 7. UI needs (art bible; no legacy HUD)

| Surface | Requirement |
|---|---|
| Journal / city tab | Show Hope and Fear as two meters with last few `living.*` summaries |
| HUD (optional later) | Compact two-value read; never a single good/evil needle |
| District feedback | Bark/patrol/price already communicate pressure; Hope/Fear may tint copy |
| Art | New controls under the art bible; do not restore ruler/rebel balance pixel frames |

Accessibility: meters need numeric text equivalents, not color-only encoding (reuse P3 accessibility patterns).

---

## 8. Slice-safe and act gating

| Band | Living City behaviour |
|---|---|
| Demo / vertical slice today | Meters absent or frozen at defaults; ledger + slice pressures only |
| P7-012 foundation | Ops, save fields, tests; may wire one Act 1 package (Bell and Chain) as proof |
| Act 2+ | Wider mission packages write `living.*` events; district bridges active |

Demo and Act 1 packaged acceptance must remain playable if Living City content is disabled (`flag.living_city.system_enabled` default false until P7-012 flips it in targeted tests).

---

## 9. Content ID forms

| Kind | Form | Example |
|---|---|---|
| Meter | `living_city.hope` / `living_city.fear` | save keys |
| Event | `living.<quest_or_beat>.<slug>` | `living.bell_and_chain.honest_hold` |
| Record op | `record_living_city_event` | content effect |
| Conditions | `living_city_hope_at_least` etc. | content conditions |
| Enable flag | `flag.living_city.system_enabled` | feature gate |
| Fail code | `living_city.fail.<slug>` | `living_city.fail.duplicate_event` |

---

## 10. Non-goals

- Universal morality, karma, or Balance of Power save fields.
- Tower-capture, army/fleet, or open-world strategic layers.
- Automatic derivation of Hope/Fear from the eight faction standings.
- Replacing `FactionLedger` UI with a single city meter.
- Shipping legacy balance HUD sprites as production assets.
- Runtime LLM generation of street mood.

---

## 11. Implementation handoff

| Concern | Owns |
|---|---|
| This contract | P7-004 |
| Runtime ops, save/load, district hooks, tests | P7-012 |
| Act 2 night missions writing `living.*` events | P5-004+ after P7-012 |
| Expanded faction cast that may author more events | P7-009 / P4-016 follow-ons |
| Art for city meters | Named art row after art-bible freeze; not this contract |

---

## 12. Source reconciliation summary

| Legacy claim | Production decision |
|---|---|
| Hope (Rebel Morale) meter | Kept as `living_city.hope` |
| Fear (Civic Order) meter | Kept as `living_city.fear` |
| Balance of Power race meter | Rejected as aggregate; act boundaries use authored flags (e.g. Viru Seal/Break/Open) |
| Tower majority victory | Excluded (tower-capture out) |
| NPC allegiance sum as BoP | Rejected; relationships + explicit events only |
| Tug-of-war fiction | Kept as UI metaphor; save keeps two independent meters |
| Forge-to-consequence day/night loop | Kept; Living City events fire from the same authored packages as ledger/forged records |
