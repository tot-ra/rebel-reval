# Factions, relationships, district pressure, and prices

Status: implemented (faction ledger, district pressure, trade prices, social reputation, relationship memory). Scope: how the world remembers Kalev's choices without a morality score. Design contracts: README [factions](../../README.md) and [ADR 0008](../adr/0008-three-act-campaign-and-faction-scope.md). Hope/Fear city meters are in [`LIVING_CITY.md`](./LIVING_CITY.md).

## Principle

Every number here derives from **explicit recorded events and flags**. There is no aggregate good/evil value. Content writes events, and models read them.

## Faction ledger

- Eight active factions (`FactionLedger.ACTIVE_FACTIONS`): `danish_crown`, `livonian_order`, `hanseatic`, `harju_kings`, `black_cloaks`, `cult_metsik`, `pskov_novgorod`, `vitalienbruder`.
- Standing per faction is `-3..3` and is derived only from `record_faction_event` effects (`GameState.get_faction_standing`).
- `FactionCandidateSeats` (`scripts/state/faction_candidate_seats.gd`) allows events-only candidate seats (currently `faction.blackheads`, see `docs/data/faction_blackheads_candidate.json`) without promoting a ninth faction. The Lizard Union is an intrigue cell and is never a ledger seat.
- Player view: Journal → faction ledger rows (`FactionLedgerModel.build_snapshot`), with labels from `FactionLedger.standing_label`.
- Conditions: `faction_standing_at_least`.

## Relationships and memories

- `rel.*` trust per character, `-3..3`, through `adjust_relationship`; read with `relationship_at_least`.
- `memory.*` keys (`RelationshipMemory`) are append-only booleans for discrete acts a character can bring up later (`record_memory` / `memory_recorded`).

## District pressure

`DistrictPressureModel` (`scripts/faction/district_pressure_model.gd`) resolves a tier per district from district flags (`…unrest`, `…martial_law`) plus faction standing:

| Tier | Patrol speed | Price multiplier | Bark pool |
|---|---|---|---|
| relaxed | 0.75× | 0.9× | `bark.district.<district>.relaxed` |
| normal | 1.0× | 1.0× | `…normal` |
| tense | 1.25× | 1.15× | `…tense` |
| crackdown | 1.5× | 1.3× | `…crackdown` |

Districts: `district.lower_town` (Lower Town, smithy) and `district.north_merchant` (north quarter). Conditions: `district_pressure_at_least`.

## Trade prices

`TradePriceModel` (`scripts/economy/trade_price_model.gd`) quotes essential goods (`trade.iron`, `trade.bread`) per district from pressure tier, faction standing, supply flags, and material grade, with tiers `low / normal / high / scarce`. Dialogue shows live quotes with the `{trade_price:trade.iron}` token ([`DIALOGUE.md`](./DIALOGUE.md#text-tokens)). Conditions: `district_price_tier_at_least`. There is no wallet or currency simulation.

## Social reputation

`SocialReputationModel` lists authored public moments keyed to standing thresholds (example: `reputation.harju_kings_trusted` at Harju Kings ≥ 2 in Lower Town, reaction `cheer`). `SocialReputationController` fires each one once, sets its `flag.reputation.*`, and plays its bark pool.

## Verify

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_faction
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_district_pressure
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_trade_price
```
