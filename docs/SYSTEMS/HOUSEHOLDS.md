# Households: furnished houses and life at home

Status: implemented (task **R-HOUSEHOLDS-001**, proposed: create it on the task board before merging). Scope: the ordinary lived-in houses of the seamless city ([`SEAMLESS_CITY.md`](./SEAMLESS_CITY.md)) are furnished for the census household that lives there ([`CITIZENS.md`](./CITIZENS.md)), split into rooms when they are big, and their people are shown at home: asleep in bed, at table for meals, at the hearth, at the workbench. The hearth fire, the firewood by it and the table light follow the household's day, and residents carry firewood home from the woodyard. Out of scope: player use of furniture (sit, sleep, open, take, steal), quests or dialogue at home, churches, the council hall, landmark sites and Kalev's forge (it keeps its own scene), upper floors and cellars, saving anything.

## What the player sees

- Walk into any lived-in house (all ordinary enterable houses with a census household; about 520 of them). Within 26 m of Kalev the house is furnished; the roof and the upper part of every wall lift as before, so the top-down, third-person and first-person cameras all see the room.
- **Hearth** on the wall under the house's chimney (or the wall farthest from the door), with the household's firewood pile, a water bucket and a pot beside it.
- **Beds** for everyone (two or three share a bed, as households did): a framed bed for the head couple of a better-off house, straw-tick box beds for the rest.
- **Table** in the open floor near the hearth with **benches** on both sides (a chair at the head in better houses), an eating set, bread, a jug and a candle on it. In a cramped room the table goes against a wall with stools in front.
- **Storage**: a plain coffer (poor) or burgher chest by the beds, an open shelf with the kitchen prep set by the hearth, a basket; rich houses add a cupboard and a strongbox.
- **Work**: a craftsman's trestle bench by the door (smiths, joiners, coopers, shoemakers, tailors and other bench trades). Big houses (over 80 m², at least 9 m long) are **split by plank partitions** into a front hall (Diele) at the street door, the living room round the hearth and, past 190 m², a back chamber. The hall holds the goods of the trade (malt and herring barrels for brewers and alewives, nets for fishers, cloth, grain, furs and herring for merchants), the season's firewood stack, a counting table for merchants and a second workbench.
- **The day at home** (pure functions of the clock, `HouseholdDay`): the fire is lit 05:24–08:36, 11:00–13:00 and 16:36–21:24 (shifted up to ±18 min per house) and banked to embers otherwise; the pile by the hearth is full for 7 h after the firewood comes home, half for the next 8 h, then low; the table light (tallow, beeswax or a resinous pine splint) burns on dark mornings and evenings while people are up.
- **People at home** (within 16 m of Kalev, at most 18 shown): someone who has just come home walks in from the door, through the doorways of a partitioned house, to their place. Then they sleep (children from 19:36, adults from 21:12, up at 05:12, jittered per person), sit at table for meals (06:42–07:18, 11:54–12:36, 17:54–18:42), the woman of the house who keeps the domestic timetable tends the fire while it burns, a craftsman works at his bench 07:00–18:30, elders and small children sit, everyone else stands about. They do not block Kalev.
- **Firewood**: residents walking home from the woodyard outside the nearest gate (the `fuel` errand, mostly late morning) carry an armful of split logs on their back; the pile at home is full from then on.

## Runtime entry points

| Piece | File | Role |
|---|---|---|
| `HouseholdLayout` | `scripts/city/household_layout.gd` | Pure: plan building + household → rooms, partitions, placed pieces (catalog object, position, yaw, height), and slots (`sleep`, `sit`, `hearth`, `work`, `stand`) and the indoor path from the door |
| `HouseholdDay` | `scripts/city/household_day.gd` | Pure: hearth state, firewood state, light on/off, each resident's activity by hour |
| `CityInteriors` | `scripts/city/city_interiors.gd` | Node under `CityWorld3D`: furnishes houses near Kalev, swaps hearth/firewood/light states, partitions (upper boards hide with the roof), furniture collision on the logic plane, `indoor_state()` for residents |
| `CitizenRoster` | `scripts/city/citizen_roster.gd` | `households`, `members`, `household_of_building`; `resolve()` now also returns `from` and `arrived` |
| `CitizenActor` / `CityCitizens` | `scripts/city/citizen_actor.gd`, `scripts/city/city_citizens.gd` | Indoor poses (walk, sleep lying on the back, sit on bench height, stand), firewood armful on the back |
| Scene wiring | `scenes/world/reval_city/reval_city.gd` | Creates `interiors`, calls `update_for` each frame |
| Hearth and light models | `scripts/map/view3d/map_view_domestic_hearth_models.gd`, `map_view_medieval_lighting_models.gd` | Reused: flame, ember glow, smoke and flickering lights by state |

## Content and stable IDs

- Every piece is a catalog object ([`OBJECT_CATALOG.md`](./OBJECT_CATALOG.md)); sizes come from the catalog's measured GLB sizes. The table of pieces is `HouseholdLayout.PIECES`.
- New Blender kit `assets/props/furniture/household_kit/household_furniture_kit.glb`, built by `blender --background --factory-startup --python tools/generate_household_furniture_kit.py` (deterministic; report in `generated/blender/household_furniture_kit_v1/`): `obj.bench_plank`, `obj.stool_three_leg`, `obj.bed_straw_pallet`, `obj.firewood_armful`, `obj.firewood_pile_indoor` (states `full`, `half`, `low`), and models for the formerly planned `obj.firewood_log`, `obj.basket_wicker`, `obj.clay_pot`.
- `content/world/reval_city/citizens.json` gains `households`: `hh.<district>.<building>` → `{building, class, trade, size}` (census class `poor`, `master`, `merchant`, `great`; `size` counts infants), compiled by `tools/city/build_citizen_runtime.py`.
- Furnishing tiers: `poor` → poor; `master` → mid; `merchant`, `great` → rich.

## Save and load

Nothing is saved: furnishing, fire, firewood and people at home are pure functions of the plan, the census and the clock.

## Verify

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_household_layout
python3 tools/city/build_citizen_runtime.py --check
python3 tools/validate_object_catalog.py
tools/godot_render.sh --resolution 1600x900 res://tools/capture_city_households.tscn -- --city-spawn=poi.forum --city-hour=18.2 --tag=evening --houses=4
```

The capture puts Kalev inside houses of each class, prints the pieces and who is home doing what, and writes `docs/reports/images/city/households_<tag>_<n>.png` (cutaway from above) and `_top.png` (top-down gameplay camera); it exits 1 if a house Kalev stands in is not furnished.

## Limits

- Kalev cannot use anything: no sitting, sleeping, opening chests, taking or stealing. The catalog `actions` are the contract for that.
- Sleepers are the standing idle laid flat (no lying clip); people at the hearth and workbench stand idle (no cooking or working clip). Seated people use the shared `sit_idle` clip.
- Indoor walking is a straight line between doorways; people may cross a piece of furniture on the way. Two residents can share a slot when a house has more people than seats.
- Partitions are only built while the house is furnished; from far away a big house has no inner walls (not visible from the street through the small windows).
- The table light and hearth are visible only in furnished houses; window glow of other houses at night is not wired.
- Institutions (castle, monasteries), churches, the council hall and landmark sites are not furnished by this system.
- Layout is per house, not authored: an odd footprint can leave a room sparse or put the table off-centre.
