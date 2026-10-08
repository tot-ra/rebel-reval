# World life: items, routines, crowds, market, supply

Status: implemented in Lower Town and the smithy (tasks **P2-058/P2-059** smithy routines, **P4-033** supply chain, **P4-036** environmental consequences, **R-207** carts, urban population **R-409..R-448**); Padise monastery and public-event overlays are models without a mounted scene (see [Limits](#limits)). Scope: things that make the city feel inhabited and react to Kalev, apart from quests and combat. Rendering of crowds and animals is in [`WORLD_PRESENTATION.md`](./WORLD_PRESENTATION.md).

## World items

- Pickable objects show a persistent yellow outline. Hovering brightens it and shows a tooltip; left click picks up when the bag has room, or drops the selected inventory item. Pickups play an item-specific bark and sound.
- Taken and placed items persist in `GameState` across scenes and saves. The seized spearhead starts on the smithy anvil.
- Files: `WorldItemController`, `WorldItem`, `WorldItemView`, `WorldItemOverlay`, `WorldItemPickupFeedback`, `WorldItemPickupLabels` (`scripts/world/`). Item records: [`schemas/item.schema.json`](../../schemas/item.schema.json). Bag rules: [`INVENTORY_MECHANICS.md`](../INVENTORY_MECHANICS.md).

## Smithy routines

Mart, Henning, the forge cat, and Kalev's domestic beats follow authored schedules over semantic activity points (anvil, hearth, table, and others) instead of coordinate loops. Talking to an NPC interrupts its routine and it resumes afterwards.

- `SmithyRoutineController`, `SmithyRoutineDefinition`, `SmithyActivityPoint` (`scripts/world/`); wired from `scenes/reval_east/forge/`.
- Data: `content/routines/kalev_smithy.json`, `forge_cat.json`, `henning_smithy_visit.json`.
- Acceptance: `docs/reports/kalev_smithy_domestic_life_acceptance.md`.

## Urban population

Lower Town crowds come from a renderer-agnostic profile: phase and calendar select a profile, actors are placed deterministically on authored zones with walkability and clearance checks, and the crowd renderer draws them. Population never writes `GameState`.

- `UrbanPopulationProfile`, `UrbanPopulationPlacement`, `UrbanPopulationMapBinding`, `UrbanPopulationController` (`scripts/world/`); renderer `scripts/map/view3d/map_view_crowd_renderer.gd`.
- Evidence and caps: `docs/reports/r446_lower_town_population_profiles.md`, `r447_lower_town_crowd_performance_cap.md`, `r448_lower_town_urban_population_acceptance.md`.

## Market day

On market days Lower Town stalls fill, a stall keeper (`StaticNpcActor`) appears, merchant trade dialogue opens, and the crowd bark pool `bark.market_day.crowd` plays. The weekday is an explicit gameplay fallback because the 1340–1343 evidence does not settle it. Files: `MarketDayModel`, `MarketDayController`; date from `GameCalendar` ([`TIME_AND_PHASES.md`](./TIME_AND_PHASES.md#clock-and-calendar)).

## Supply chain and carts

- **Iron convoy** (`SupplyChainModel`, `SupplyChainController`, `SupplyChainConvoy`): a porter hauls bar stock from the north quarter to the Lower Town market along an authored path. Kalev can observe or disrupt it, which records flags and resolves quest branches through `QuestManager` and feeds [trade prices](./FACTIONS_AND_ECONOMY.md#trade-prices).
- **Merchant carts** (`CartTransportModel`, `CartTransportController`): phase-aware ambient cart traffic on authored cart props, with route, road, load, and siege rules; barks in `bark.cart.transport`.

## Environmental consequences

`EnvironmentalConsequenceModel` / `EnvironmentalConsequenceController` turn ledger standing, district flags, and supply-chain state into visible district overlays (for example shuttered or busy frontages), so major choices read in the world without new mechanics.

## NPC bodies

- `scripts/npc.gd`: base logic NPC. The 3D runtime mirrors each logic body onto a character rig ([`CHARACTER_GENERATION.md`](../CHARACTER_GENERATION.md)).
- `StaticNpcActor`: stationary person at a prop (stall, door, post).
- `NpcPush` (`scripts/physics/npc_push.gd`): Kalev gently shoulders non-hostile NPCs aside; walls still block both.
- `CrowdYield` (`scripts/physics/crowd_yield.gd`): the ambient crowd (census citizens, standing site people) sits on `CollisionLayers.CROWD`, which the player does not mask, so a crowd at a door never blocks Kalev. Instead each person eases up to 30 px sideways out of his way (preferring the side of his heading) and drifts back after. Seated people and residents at home do not move. Named NPCs keep `NpcPush`. Test: `tests/godot/test_collision_layers.gd`. No animation yet.

## Verify

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_world_item
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_smithy_routine
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_urban_population
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_market_day
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_supply_chain
```

## Limits

- `PadiseMonasteryController` and `PadiseMonkActor` (two-phase monastic communities and soundscape for Padise) are not mounted by `scenes/world_travel/world_padise.tscn`; only tests use them.
- `EventOverlayModel` (calendar-bound public festivals and processions) is tested but no controller consumes it.
- Urban population runs in Lower Town only.

Both gaps are listed in the [code-health audit](../reports/code_health_audit_2026-10-07.md).
