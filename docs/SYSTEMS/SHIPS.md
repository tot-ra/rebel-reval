# Hanseatic cog

Status: implemented (ship detail pass of the seamless city, ADR 0031; board task not yet filed). Scope: the cog (`CogModel`) seen anchored and under way off Reval, in true metres, with a walkable deck, cabins and hold. Out of scope: ship physics and steering, mast climbing as a mechanic, boarding the cog under way, cargo or trade gameplay. Small boats stay in [`CITY_SEA.md`](./CITY_SEA.md).

## What the player sees

- **Hull** (`CogHull`): one lofted clinker shell, ~21 m over the stems and ~7 m abeam, flat-floored amidships with a raked stem and sternpost, ten lapped side strakes and bottom planks. Plank tones vary per strake and the lap edges carry a ledge, so the hull reads as overlapping boards, not a smooth shell. The inner skin is built from the same loft, so the deck seen from above shows no gaps through the hull.
- **Interior** (`CogInterior`): laid deck, through-beams, a hold well with a stair to the hold floor, a cargo hatch, a stern cabin and a forecastle store (both with a door, roof and fittings), windlass and bitts, deck cargo, and a boarding ladder over the side.
- **Rig** (`CogRig`): mast with a masthead top, a yard, a square sail, stays, shrouds with ratlines up to the top, backstays, halyard, lifts, braces, sheets, tacks and bowlines. The ratlines are how a crewman gets aloft.
- **Rudder**: hung on the raked sternpost with pintles and gudgeons (`RudderPivot/Rudder`); the tiller enters the stern cabin. `CityShips` swings it a few degrees at anchor and holds a constant helm under way.
- **Wind**: ropes and sail are not simulated on the CPU. `cog_rope.gdshader` sags and bellies every rope with the shared world wind; `cog_sail.gdshader` fills the sail from the wind seen in the ship's own frame (from astern: bellied forward; from ahead: laid back against the mast; abeam: part-filled), pins its head to the yard and its foot to the clews, and shivers the free edges in a luff. A cog at anchor has the sail furled on the yard; the cog under way has it set.
- **Scale**: the hull is true metres with no rescale (Kalev is ~1.8 m). The waterline is the node origin.

## Entry points

`CogModel.build(faction, sail_set, anchored)`; `CogModel.walk_height(x, z)` (deck, cabins and hold well; used by `CityShips.deck_height_at` through `CityPlan.dynamic_deck`); `CogModel.rudder_of(node)`. `CityShips` builds one anchored cog and duplicates it per hull (meshes are shared).

## Sources

Dimensions and the attested/composite split are in [`docs/reports/baltic_vessels_1343.md`](../reports/baltic_vessels_1343.md) (Bremen cog 1380, Lootsi wreck). Shroud and brace counts are plausible composites, not attested.

## Verify

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_cog_model
tools/godot_render.sh --script tools/capture_cog.gd -- --tag=x   # build/cog/<shot>_x.png
```

## Limits

- Ratlines are visual: there is no climb-the-mast mechanic yet; Kalev walks the decks, cabins and hold only.
- The cog under way cannot be boarded.
- Fishing boats at the landing are still the legacy `MapViewFishingBoatBuilder` hull (angular next to the cog); only `CityBoats` kinds are lofted clinker.
- Plank texture is the shared hewn-timber material with vertex tones, not a dedicated hull plate.
