# Gate garrisons and patrols

Status: implemented (task **R-GATES-001**; board ref to be filed). Scope: who guards each gate of the seamless Reval city, which census residents they are, when they work, where they live, how they dress, and the patrols that walk between the posts. Out of scope: guard behaviour towards Kalev (challenge, toll, curfew, arrest), a barracks building model, off-duty life inside barracks, combat AI for guards, weather and siege states.

The generic watchman and Danish man-at-arms bodies (`watchman.tscn`, `danish_warrior.tscn`, `sergeant.tscn`) no longer stand at gates. Every guard is a real census resident ([`CITIZENS.md`](./CITIZENS.md)) on a duty timetable, in their own clothes, with a name, a house, a household and an information panel (click or `interact`: "On guard duty: watchman, Viru Gate and barbican (day shift)").

## Who stands where

The full generated roster, one row per resident with house street and walking distance to the post, is [`docs/CITIZENS/gate_garrisons.md`](../CITIZENS/gate_garrisons.md). The staffing table is `GATES` in `tools/city/gate_garrisons.py`:

| Gate (`gate.*`) | Gatekeepers (day) | Burgher watch per shift | Danish men-at-arms per shift | Why |
|---|---|---|---|---|
| `coastal` Coastal Gate | 1 | 2 | - | harbour traffic |
| `sand` Sand Gate | 1 | 1 | - | small beach gate |
| `viru` Viru Gate and barbican | 2 (inner gate and foregate) | 3 | - | main land road |
| `karja` Cattle Gate | 1 | 2 | - | herds and carts |
| `harju` Smiths' Gate | 1 | 2 | - | road south |
| `nuns` Nuns' Gate | 1 | 1 | - | quiet convent gate |
| `long_hill` Long Hill Gate | 1 (council) | - | 3 | to the castle |
| `short_hill` Short Hill Gate | - | - | 3 | Danish castle watch only |

Patrols: the town watch walks **Pikk**, **Lai** and **Vene** (one burgher per shift each; the day sergeant `cit.lt.inst_town_hall.009` and the night sergeant `cit.lt.inst_town_hall.010` both lead the Pikk patrol); four Danish men-at-arms per shift walk the **Toompea wall** (set 3 m inside the wall line). 58 residents in all. The other 16 Danish men-at-arms and the 21 knights stay in and around the castle (`poi.barracks.castle`).

Where the people come from, nobody is invented:

- **Gatekeepers**: the 8 census `gatekeeper` residents, matched to the 8 gate slots so the total walk from house to gate is shortest (`itertools.permutations`; all 8 are in Lower Town houses, so a gatekeeper can live up to about 470 m from the gate).
- **Watch sergeants**: the 2 census `watch_sergeant` residents, who live in the town hall institution (`hh.inst_town_hall`, the council watch, `poi.watch.town_hall`).
- **Danish men-at-arms**: the 36 census `man_at_arms` residents of the castle household (`hh.inst_castle_toompea`): 12 at the two hill gates, 8 on the wall, 16 in the castle.
- **Burgher watch**: the town's duty levy. Men aged 22-50 of Lower Town households (labourers, journeymen, master craftsmen, free commoners) in physical trades (traders, clerks, healers, innkeepers and the like are exempt), picked by a stable hash from the households nearest the post (radius 140 m, widening to 260 and 520 m when too few). They keep their trade and household; the watch replaces their workshop timetable. 28 residents.

## When and how they work

Timetables are patterns in `content/world/reval_city/citizens.json` (`watch_day`, `watch_night`), still a pure function of the clock hour ([`CITIZENS.md`](./CITIZENS.md)):

- **Day shift**: walks to the post at about 5:40, stays until about 12:00, goes home for the midday meal, back about 12:50, relieved at 18:00 and walks home.
- **Night shift**: at home all day, arrives at the post about 17:40 and holds it until about 5:30, then walks home. Night guards stand a rank deeper (10.2 m inside the passage instead of 8.5 m) so a changeover never stacks two men on one spot.
- **Gatekeepers** work the day shift only (the gate is the shift's; at night the watch holds it).
- Times shift per resident by up to +-36 minutes (the `jitter` of every resident), so relief is staggered.
- **Standing**: gate guards stand on an exact spot flanking the passage (lateral 2.8, 4.6, 6.4 m), looking out of the town; gatekeepers sit at a toll table 5.2 m to the side so the passage stays clear for Kalev. The town side is the side facing the forum (the hill gates: the castle side, with the Danes looking out at the town).
- **Patrolling**: walk their route back and forth at 0.9 m/s, each man 5 m (town) or 40 m (wall) behind the one before; the route is a street centreline of the plan, so patrols follow the real street.

Where they live: their census house, as for every resident (a gatekeeper or levy man in his Lower Town house, the sergeants and Danes in the hall and castle institutions). There is no separate barracks building yet (see Limits).

## Dress and gear

Their own clothes are the blank Tier 2 citizen body of their sex and build, dyed per resident. On duty:

| Kit (`duty.kit`) | Who | Dye | Gear |
|---|---|---|---|
| `keeper` | gatekeepers | their own colours | none: keys are the badge |
| `watch` | burgher watchmen | their own tunic colour, darkened | kettle hat, spear |
| `sergeant` | watch sergeants | dark blue town coat | kettle hat, sword |
| `crown` | Danish men-at-arms | crown red | kettle hat, spear |

`CitizenGear.arm` (`scripts/city/citizen_gear.gd`) mounts the skinned `kettle_hat.glb` as a garment on the shared skeleton and the shipped `spear.tscn` / `sword.tscn` in the right hand slot. These are existing assets; no new art. No individual armour is fitted to the 22 citizen bodies (the fitted armour wearables are tied to the old watchman and Danish warrior bodies), so there is no mail or surcoat yet.

## Runtime entry points and data

- `tools/city/gate_garrisons.py`: the assignment; called from `tools/city/build_citizen_runtime.py`, which writes `duty` on each resident (`post`, `role`, `shift`, `kit`, `label`, and `exact` for posts or `route` and `offset` for patrols), the new `patrols` list and the duty places into `content/world/reval_city/citizens.json`.
- `scripts/city/citizen_roster.gd` (`CitizenRoster`): resolves a post as an exact spot, a patrol as a position along its route (`PATROL_SPEED`), and describes the duty.
- `scripts/city/city_citizens.gd` / `citizen_actor.gd`: seat the guard like any resident within 60 m of Kalev; `CitizenGear` equips them.
- `scripts/city/city_npcs.gd` (`CityNpcs`): no longer spawns guards or patrols (only site people and field workers).
- Stable IDs: resident `cit.*`, post and patrol ids `gate.*` and `patrol.pikk|lai|vene|toompea_wall`. Nothing new is persisted: duty is a pure function of the hour; no save data.

## Rebuild and verify

```bash
python3 tools/city/build_citizen_runtime.py            # recompile citizens.json
python3 tools/city/build_gate_garrison_doc.py          # regenerate docs/CITIZENS/gate_garrisons.md
python3 tools/city/build_citizen_runtime.py --check
python3 tools/city/build_gate_garrison_doc.py --check
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_citizen_roster
tools/godot_render.sh --resolution 1600x900 res://tools/capture_city_citizens.tscn -- --city-spawn=gate.viru --city-hour=10 --tag=gate_viru
```

Tests (`tests/godot/test_citizen_roster.gd`): every gate has a day and a night garrison, all 8 gatekeepers hold a gate, shifts relieve each other, a gate guard stands still on his post, a patrol covers ground and turns back and is described as a patrol.

## Limits

- No barracks or guardhouse building: off-duty guards go to their own houses (Danes: the castle institution, which has no walkable interior). Guard rooms in the gate towers are a follow-up.
- Guards do nothing towards Kalev: no challenge, toll or curfew ([`WORLD_LIFE.md`](./WORLD_LIFE.md) and the hill gate curfew controller cover the old district maps only).
- At most 30 residents are live at once near Kalev (`CityCitizens.MAX_LIVE`); a crowded gate competes with the street for those slots.
- The Danes are 36 residents for a castle and two gates: an abstract garrison, not an attested strength. The burgher levy is a plausible composite (watch duty by turns), not a documented 1343 roster. Confidence: plausible composite.
- Field workers (`CityNpcs`) still use crowd and blank rigs, not census residents; the old 2D district crowd ([`WORLD_LIFE.md`](./WORLD_LIFE.md#urban-population)) is unchanged.
