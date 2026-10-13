# Citizens: census, ledger, and deep cards

Status: implemented as data, documentation and, since 2026-10-08, runtime in the seamless city (task **R-CITIZENS-001**; runtime board task to be filed). Scope: who lives in the 641 buildings of the Reval city plan, how many, with what trades, faith, faction, and face, how a resident becomes a deep card, and how residents walk the seamless city from their own door with a daily timetable, in a blank body that fits their build, and can be inspected by click. Out of scope: authored per-resident dialogue (generic talk is in [`DIALOGUE.md`](./DIALOGUE.md#talk-to-anyone-r-1887)), quest use, per-resident faces and textures, hair and night life. Life at home inside furnished houses is [`HOUSEHOLDS.md`](./HOUSEHOLDS.md).

## In the city

- The generic townsfolk pool and market folk of the seamless city are gone. People within about 60 m of Kalev are the census residents of the houses around him, at most 30 live at once (`CityCitizens`, `scripts/city/city_citizens.gd`). Gate guards and watch patrols are census residents on duty ([`GATE_GARRISONS.md`](./GATE_GARRISONS.md)); landmark sites carry no posted people any more (only census citizens are shown); farm hands are still a posted role (`CityNpcs`).
- Each resident has a timetable by trade (`patterns` in `content/world/reval_city/citizens.json`) with long spells indoors and short outings, each to a real place: the well for water, the bakers' ovens, butchers' benches or forum for food, a woodyard outside the nearest gate for firewood, the nearest street gutter to empty the slops, and the supply their trade needs (iron at the smiths' street, grain at the granary quay, fish at the landing, timber and clay at the mill, water for dyers and tanners). Workplaces: own doorway for craftsmen (in and out of the workshop), the forum for traders, the fish landing and granary quay for sailors and porters, the town hall for clerks, a church door for clergy, a gate or guard post for men-at-arms, a well for washerwomen. Children of the better-off (boys from mid-ranking households, girls only from rich ones, age 7 and over) go to the parish school at the nearest church (morning and afternoon sessions); the other children fetch and carry. About three in four residents (all clergy) go to church (mornings for the old, vespers for most), and three in five take an evening walk to the forum, the fish landing, a well, a gate or the bath house. Infants under 3 and children under 6 stay indoors. Times shift per resident by up to ±36 minutes; walking speed is 1.0–1.45 m/s.
- Position is a pure function of the clock hour (`CitizenRoster.resolve`): no simulation state, nothing to save, any resident near Kalev appears at the right spot, mid-street or at their door. They walk the street graph (`graph` in the JSON) from their door. Residents are spread by a stable personal offset (door frontage, a spiral round a market spot, a lane across the street) so a household or a market crowd never stacks on one point.
- Click a resident (left mouse) or press `interact` near them (gamepad too) for the information card; within 4 m this also starts a conversation, or a spirit duel in spirit sight ([`DIALOGUE.md`](./DIALOGUE.md#talk-to-anyone-r-1887), R-1887). The card shows name, age, ethnicity, trade, status, faction, household, languages, literacy, looks, marks, what they are doing now, and the deep-card blurb when one exists (737 residents). Hover or select shows the name above their head. `Esc` or the × closes it.
- Bodies: 30 blank Tier 2 bodies (`assets/characters/variants/citizen_*.tscn`) built by `tools/assets/realistic_humans/citizen_bodies.py`: sex × life stage (child, adult, elder) × build (thin, average, sturdy, heavy; the 14 census build phrases fold into these) with bust size and belly following the build, plus a second adult outfit (long tunic or gown and apron, mostly for the better-off) and, for women, the patrician kirtle with sideless surcoat and the Estonian shift with wrap skirt (R-1665). Stature is a runtime scale of the body from the resident's height in cm, head size a runtime bone scale, garment colours are period dyes by wealth (`cloth`, `under`). Over the base outfit each resident wears layers fitted to their body and chosen by status, trade, age, faction and duty (hoods, coifs, veils, aprons, armour kits, keys, beads, scrips, sacks: [`CITIZEN_WARDROBE.md`](./CITIZEN_WARDROBE.md)). Face, hair and per-person textures come later and will replace these blanks.
- Named NPCs from `characters/**` (Konrad Preen, Hinrik, Martin...) walk the same streets with their own registry and a separate cap, and use the same information panel with a portrait; a resident a named NPC replaces is not spawned here ([`NAMED_NPCS.md`](./NAMED_NPCS.md)).
- Clock: the city's day/night cycle (`MapViewRuntime.cycle_progress`). `--city-hour=H` on the command line pins the hour for review.

Rebuild after changing the census, plan or bodies: `python3 tools/city/build_citizen_runtime.py`; bodies `tools/assets/realistic_humans/rebuild.sh citizen_m_adult_thin ...` then `write_scenes.py`. Review plates: `tools/godot_render.sh --script tools/capture_citizen_bodies.gd` (all bodies) and `tools/godot_render.sh --resolution 1600x900 res://tools/capture_city_citizens.tscn -- --city-spawn=poi.forum --city-hour=10`.

## Religious houses in their sites

A landmark site may house a census institution (`community` block in the site manifest): St Catherine's Dominican friary (`hh.inst_st_catherine_friary`) lives in its close with a horarium instead of the generic `cleric` day: the night office, lauds, chapter, terce and mass, dinner in the refectory, none, vespers, supper and compline, with study, preaching at the market cross, questing for alms or confessions between the hours; lay brothers brew, garden and keep the granary, stores and gate; servants fetch and cook. Seats (choir stalls, chapter bench, refectory benches) are exact per resident (`exact` keys), one bell keeps everyone within minutes, and the close's walkways join the street graph only at its gates. Friars wear the white habit and black hood. Households of houses a landmark site replaced are not compiled until the census rehomes them. Details and the full timetable: [St Catherine's friary](./landmark_sites/st_catherine.md#community-the-friars-day). St Michael's nuns still use the generic day (R-1721).

## Fights

Every resident has health and stamina once struck: men fight back, others run, the fallen stay down for the session. See [Brawls with citizens](./COMBAT.md#brawls-with-citizens) (task **R-1756**).

## What exists

- **Census** ([`docs/data/city_census.json`](../data/city_census.json)): 4,247 residents in 607 households (one per plot plus ten institutions) derived deterministically from `content/world/reval_city/plan.json`. Method, brackets, and a coverage check against the economy: [`docs/CITIZENS/CENSUS.md`](../CITIZENS/CENSUS.md); generated statistics: [`census_tables.md`](../CITIZENS/census_tables.md).
- **Ledger** ([`docs/CITIZENS/ledger/`](../CITIZENS/ledger/README.md)): every household and resident per street, with trade, ethnicity, faction, and an appearance seed (height, build, hair, eyes).
- **Deep cards** ([`docs/CITIZENS/people/`](../CITIZENS/people/README.md)): a stratified sample, written in whole households with a planned social network, validated against the seed.
- **Faction pages** ([`docs/CITIZENS/factions/`](../CITIZENS/factions/README.md)): ten pages, each with a generated census roster.

## How a person is made

The seed fixes age, sex, ethnicity, trade, household, faction, literacy, and appearance numbers. A card adds biography, motives, routine, voice, relationships, and game hooks without contradicting the seed. Relationships between cards are planned in [`citizen_cards_plan.json`](../data/citizen_cards_plan.json) with one agreed fact per edge, so both sides write the same history. See [`WRITING_CARDS.md`](../CITIZENS/WRITING_CARDS.md).

## Stable IDs

| Kind | Form | Example |
|---|---|---|
| Resident | `cit.<district>.<building>.<nn>` | `cit.lt.osm_w64299235.01` |
| Card | `char.<slug>` (file name) | `char.dietrich_zierenberg` |
| Household | `hh.<district>.<building>` | `hh.lt.osm_w64299235` |
| Institution | `hh.<district>.inst_<name>` | `hh.tp.inst_castle_toompea` |

Building IDs are the plan's (`bldg.osm.w…`, `bldg.harju.01`) and never change. District codes: `lt` Lower Town, `tp` Toompea, `tf` vassal yards below the castle, `kr` fishing beach, `vi` Viru road, `ha` Harju road, `ka` Cattle road.

## Church services (planned, ADR 0046)

Status: planned (task **R-1737**, epic **R-1735**; [ADR 0046](../adr/0046-church-services-and-collective-channeling.md) is **proposed**). Today residents only have a generic `church` slot in their timetable and no service takes place.

Planned: the bells call 15 minutes ahead; on Sundays and feasts the whole parish (household members aged 7+, except infants, the sick and the watch on duty) goes to high mass at its nearest parish church (St Olaf's, St Nicholas', Holy Spirit) about 09:00; on ordinary evenings the devout few and the clergy go to vespers about 17:00. A parish priest says mass at the altar. This schedule replaces the generic `church` slot. The spirit-layer effect of a service is in [`SPIRIT_SIGHT.md`](./SPIRIT_SIGHT.md#soot-and-church-services-planned-adr-0046).

## Save and load

None: the census is static content. A future runtime that records "met", "spoke with" or "harmed" must use new `memory.*` keys, never edit the census.

## Verify

```bash
python3 tools/city/build_city_census.py --check
python3 tools/city/plan_citizen_cards.py --check
python3 tools/city/build_citizen_ledger.py --check
python3 tools/city/build_faction_rosters.py --check
python3 tools/validate_citizen_cards.py --require-all
python3 -m unittest tests.python.test_citizen_census -v
python3 tools/city/build_citizen_runtime.py --check
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_citizen_roster
```

## Limits

- Residents appear in the seamless city only. The older Lower Town district crowd ([`WORLD_LIFE.md`](./WORLD_LIFE.md#urban-population)) still does not read the census.
- Timetables come from trade and status, not from each card's "Daily routine" table. Residents vanish at their door unless their house is furnished near Kalev ([`HOUSEHOLDS.md`](./HOUSEHOLDS.md)); they never use night life, and ignore weather, market days and quests.
- No conversation: the panel is read-only. Body shape is bucketed (30 bodies), so two residents of one bucket differ only in stature, head size, dyes and wardrobe layers.
- Cards describe April 1343 only. Siege and aftermath states are hooks in each card, not data.
- No portraits are generated; blank bodies exist, faces and textures follow from the appearance seeds and cards ([`CHARACTER_GENERATION.md`](../CHARACTER_GENERATION.md)).
- Demographic shares are plausible composites, not attested statistics.
