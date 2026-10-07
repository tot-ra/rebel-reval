# Citizens: census, ledger, and deep cards

Status: implemented as data and documentation (task **R-CITIZENS-001**). Not mounted in any scene: no runtime script reads the census yet (see [Limits](#limits)). Scope: who lives in the 641 buildings of the Reval city plan, how many, with what trades, faith, faction, and face, and how a resident becomes a deep card. Out of scope: crowd spawning, schedules in `content/routines/`, dialogue, and quest use (those need their own tasks).

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
```

## Limits

- The crowd runtime ([`WORLD_LIFE.md`](./WORLD_LIFE.md#urban-population)) does not read the ledger, so residents never appear in the 3D city. Wire it, or delete the census, in a task naming the `scripts/world/` files and the performance cap (R-447).
- Cards describe April 1343 only. Siege and aftermath states are hooks in each card, not data.
- No portraits or 3D body specs are generated; the appearance seeds and cards are the input for [`CHARACTER_GENERATION.md`](../CHARACTER_GENERATION.md).
- Demographic shares are plausible composites, not attested statistics.
