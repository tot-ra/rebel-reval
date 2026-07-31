> **Legacy status:** `reconciled` (P7-007)  
> **Reason:** Priority pass completed under [ADR 0017](./adr/0017-legacy-design-reintroduction.md). Naval and castle-building sims stay deferred without a new ADR.  
> **Scope reconciliation:** [ADR 0017](./adr/0017-legacy-design-reintroduction.md), [`LEGACY_REINTRODUCTION.md`](./LEGACY_REINTRODUCTION.md)  
> **Current source of truth:** This file for mini-game planning; implementation requires per-game `TODO.md` rows.

# Mini-Game Priority Pass (P7-007)

Evaluated against ADR 0008 slice scope, ADR 0017 reintroduction rules, and `docs/CANON.md` (Hope/Fear meters, no Chaos meter, no plague epilogue).

## Legend

| Label | Meaning |
|-------|---------|
| **accept** | Fits Reborn scope; may ship in slice or Act 1 when an implementation row lands |
| **defer** | Valid hook but blocked on act gate, night/travel systems, or a future ADR |
| **reject** | Conflicts with scope, canon, or design rules; do not implement |

Act tags: **slice** = vertical-slice MVP district, **A1** = Act 1 (Simmering City).

## Hard exclusions (no new ADR)

| Category | Examples | Status |
|----------|----------|--------|
| Naval mini-games | ship combat, piracy sims, open-coast sailing | **defer** until a later ADR |
| Castle-building sims | stronghold/base builder loops | **defer** until a later ADR |
| Army/fleet battle sims | ADR 0017 still excludes | **reject** |
| Blacksmith rhythm minigames | README carve-out unless explicitly reinstated | **reject** (forge stays narrative problem-solving) |

## Legacy idea reconciliation

| Idea | Source section | Label | Target | Notes |
|------|----------------|-------|--------|-------|
| Castle Building | Player-Suggested | **defer** | A2+ | Stronghold/base builder is a castle-building sim; needs a dedicated ADR before design returns |
| Pirate Ship | Player-Suggested | **defer** | A3+ | Naval trade/piracy; excluded until naval ADR |
| Catching Fish on a Ship | Player-Suggested | **defer** | A2+ | Ship fishing is naval-adjacent; dock-side fishing without a boat may return as a separate **defer** economy beat after harbor content lands |
| Tavern Brawling | Additional Recommendations | **accept** | slice / A1 | Social combat in Lower Town taverns; uses existing hammer combat presentation with authored room rules |
| Smuggling Run | Additional Recommendations | **accept** | A1 | Night patrol evasion for illicit goods; aligns with P5 night templates and rebel/ruler interception hooks |
| Market Haggling | Additional Recommendations | **accept** | slice | Barter loop for Civic Quarter merchants; extends commission/commerce without a separate economy sim |
| Ritual Chanting | Additional Recommendations | **defer** | A2+ | Rhythm ritual needs P7-011 magic/NATURAL runtime; reframe boons off rejected Chaos meter onto Hope/Fear and authored rites |
| Herbalism & Alchemy | Additional Recommendations | **defer** | A2+ | Gathering/crafting extension; wait until combinatorial magic and expanded reagent content (P7-010/011) define inputs |

## Signed shortlist: slice / Act 1 candidates (3)

Only these three may open implementation rows before Act 2 design closes. Each names a player-facing goal and a verification sketch for a future dev row.

### 1. Market Haggling (`minigame.market_haggle`)

| Field | Detail |
|-------|--------|
| **Target** | slice (Civic Quarter / market merchants) |
| **Player-facing goal** | Negotiate buy/sell prices with a merchant by reading mood cues and choosing counter-offers so Kalev funds commissions and stock without grinding combat |
| **Integration** | Faction ledger discounts, `living_city.hope`/`living_city.fear` nudges on fair vs. harsh deals, journal evidence for economic quests (P4-021 Hanseatic line) |
| **Verify sketch** | Headless or room test: start haggle with stub merchant, three counter-offer branches resolve to distinct final prices and ledger ops; save round-trip preserves last agreed tariff flag |

### 2. Smuggling Run (`minigame.smuggling_run`)

| Field | Detail |
|-------|--------|
| **Target** | A1 (night Lower Town / harbor edge) |
| **Player-facing goal** | Carry contraband through patrolled streets without being spotted; deliver to a drop point or escape pursuit |
| **Integration** | Rebel and City Watch ledger events, night mission template (P5-004), optional ruler-path interception variant |
| **Verify sketch** | Fixture night map with two guard patrols: success path reaches drop anchor with zero `flag.smuggling_spotted`; failure path triggers chase or combat spawn id; outcome writes one ledger op and one living-city meter delta |

### 3. Tavern Brawling (`minigame.tavern_brawl`)

| Field | Detail |
|-------|--------|
| **Target** | slice / A1 (Lower Town tavern interior) |
| **Player-facing goal** | Win a bounded tavern fight (knockout or yield) to intimidate an NPC, earn street respect, or unlock a dialogue branch |
| **Integration** | Short hammer-combat arena with furniture collision; `living_city.fear` bump on brutality; faction respect for Black Cloaks vs. rebels depending on outcome |
| **Verify sketch** | Instanced tavern room: interact prompt starts brawl, three-hit KO ends with `flag.tavern_brawl_won` and opens stub dialogue node; leaving bounds forfeits with reputation penalty |

## Deferred backlog (post-Act 1)

| Idea | Blocker | Revisit when |
|------|---------|------------|
| Dock fishing (no ship) | Harbor slice dressing incomplete | Harbor east map + economy row |
| Ritual Chanting | P7-011 NATURAL/magic runtime | Magic foundation ships |
| Herbalism & Alchemy | Reagent catalog + combinatorial inputs | P7-010/011 content |
| Castle Building | Naval/castle ADR | Maintainer ADR |
| Pirate Ship / ship fishing | Naval ADR | Maintainer ADR |

## Implementation dependency map

| Future TODO pattern | Mini-games enabled |
|---------------------|-------------------|
| P5-004 night mission template | Smuggling Run |
| P4-021 faction quest lines | Haggling evidence hooks, Smuggling outcomes |
| P2 combat room / hammer presentation | Tavern Brawling |
| Per-game `minigame.*` row | Each accepted candidate above |
