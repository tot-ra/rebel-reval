# The 1343 census: how many people, where, and who

Status: implemented as data and documentation (task **R-CITIZENS-001**, see [`docs/SYSTEMS/CITIZENS.md`](../SYSTEMS/CITIZENS.md)). Not yet wired to the crowd runtime.
Confidence: every number here is a `plausible composite` built from the dated brackets in [`estonian-and-german-populations.md`](../../history/dossiers/people/estonian-and-german-populations.md). No April 1343 headcount survives.

## Why a census

The seamless city plan ([ADR 0031](../adr/0031-continuous-reval-city-plan.md)) holds 641 buildings. An immersive city needs people in them, and those people must make the economy work: guards, porters, bakers, brewers, fishers, servants, clerks, clergy, soldiers, children and the old, in proportions a historian would not laugh at. This census derives the population **from the buildings**, so a plot's size, street, and zone decide who lives in it, and every resident has a seed (age, trade, faction, face) that a card, a model, and a portrait can be built from without inventing a "generic NPC".

## Result

Generated tables: [`census_tables.md`](./census_tables.md). Headline numbers:

| Measure | Value | Source bracket |
|---|---|---|
| Residents modelled | **4,247** (inside the walls, Toompea, and the six immediate suburbs/districts) | 3,000-4,500 for the whole urban complex in April 1343 (Johansen & von zur Mühlen, Naum, Salminen proxy). The model sits at the upper end because it includes transient sailors, a garrison, clergy and hospital inmates. |
| Households | 607 populated of 643 | one per plot, plus 10 institutions |
| Plot buildings | 633 houses; 5 churches, 1 chapel, 1 town hall are institutions | `content/world/reval_city/plan.json` |
| Children under 15 | 33% | pre-modern towns 28-35% |
| Aged 60+ | 6.5% | towns 4-8% |
| Estonian / German / Swedish and Finnish / Danish / Russian | 44% / 36% / 14% / 3% / 3% | Naum ~50% Estonian, 30-40% German; Johansen Germans under 50% |
| Female share | 49% | seasonal sailors, garrison and friars pull it down |
| With a faction affinity | 26% (74% have none) | most townspeople are not political |
| Residents with a deep card | see [`census_tables.md`](./census_tables.md) | one card per resident is the long-term goal |

What is *not* in the count: the Harju hinterland and its manors, the rebel levy, villages, the Order's later garrison, Novgorod caravans beyond the resident court, and the active cast under [`docs/CHARACTERS/`](../CHARACTERS/README.md) (Kalev's smithy household and the promoted faces live on the older `lower_town_slice` map until their anchors are re-homed onto the plan; add about 20 people when they are).

## From buildings to households

Each of the 633 plot houses gets one household, classified by footprint and place:

| Class | Footprint | Typical use | Household size |
|---|---|---|---|
| shed | under 45 m2 | warehouse, stable, workshop shed (most hold nobody; a few a caretaker) | 0-3 |
| poor | 45-115 m2 | labourer or fisher dwelling, boda, cellar rooms | 2-5 |
| master | 115-260 m2 | master craftsman's house and workshop; small merchant | 4-7 |
| merchant | 260-460 m2 | merchant house with rear court and storehouse | 6-10 |
| great | over 460 m2 | great house with clerks and many servants | 8-12 |

Zones come from the street name and position: merchant streets (Pikk, Lai, Vana turg, Raekoja, Vene, Dunkri, Mündi and others), craft lanes, the harbour strip (north of the market toward the Coastal Gate), the fishing beach, the Toompea hill and its foot, and the three road suburbs (Viru, Karja, Harju). In the fishing and suburb zones small footprints are huts and cottages, so they are dwellings, not sheds.

A household is built from a head (13% widows), a spouse (88% of married heads), surviving children (about 62% survive to 12, most leave home by 15 to 21), an elderly parent (30-42%), and staff or lodgers up to the size target: apprentices and journeymen in craft houses, clerks, maids, cooks and servants in merchant houses, lodgers in poor houses. Heads and their trade are drawn from weights per zone (see `HEAD_TRADES` in `tools/city/build_city_census.py`), then ethnic priors adjust them: shoes lean Swedish, masonry and haulage Estonian, long-distance trade German, furs Russian.

**Institutions** are not plot houses and carry fixed rosters: St Catherine's Dominican friary (24 friars, 8 lay brothers, servants), St Michael's Cistercian nunnery (22 nuns, 8 lay sisters, servants, 2 chaplains), the Holy Spirit hospital (20 inmates), the St Olaf and St Nicholas parish houses, the Novgorod merchants' court (8 merchants, 4 clerks, a priest, servants), the town hall staff, the cathedral chapter of St Mary on Toompea (12 canons, 8 vicars, servants), the Danish castle (about 100 including garrison, clerks, servants and a falconer), and a seasonal harbour pool of about 110 sailors, skippers, pilgrims and pedlars.

**Civic offices** are assigned afterwards from the existing residents: two burgomasters and eighteen councillors from the wealthiest German merchant heads (one burgomaster carries the attested name Dietrich Zierenberg, d. 1345), eight gatekeepers (one per gate), an Estonian night-watch squad of eight, the city herdsman, and the executioner. The militia watch is every adult German burgher household master and journeyman, not a standing corps.

## What each resident carries

| Field | Meaning |
|---|---|
| `id` | `cit.<district>.<building>.<nn>`, stable; derived from the building ID and a seeded draw |
| `name`, `slug` | German burghers: forename plus hereditary or occupational byname (`van Lubeke`, `Smed`); Estonians: forename plus optional patronymic (`poeg`/`tütar`), never a family name; Swedes and Finns: patronymics; Russians: patronymics; Danes: byname. Children carry the head's byname or patronymic. |
| `age`, `sex`, `ethnicity`, `segment`, `status`, `trade`, `household_role` | `segment` follows the tags in the populations dossier. |
| `faction`, `faction_role` | one of ten affinities (see [`factions/`](./factions/README.md)) and a role from sympathiser to courier. |
| `literacy`, `languages` | Middle Low German is the town's tongue; Latin only for the lettered. |
| `appearance` | height (cm), build, hair colour and greying, eye colour, complexion, up to three marks, facial hair, handedness, voice. Distributions follow period and ethnicity (men about 169 cm, women about 157 cm, standard deviation about 6; greying with age; trade wear). |
| `office` | council, gate, watch, and similar. |

The same seed drives the card text, the character spec in [`CHARACTER_GENERATION.md`](../CHARACTER_GENERATION.md) (MakeHuman macros), and the portrait prompt, so two neighbours cannot silently collapse into the same face.

## Is it enough to run a city?

A coverage check against what 1343 Reval needed (counts of residents; households are in the ledger):

| Need | Who | Count |
|---|---|---|
| Walls and gates | militia (every adult German household master and journeyman, about 380), 8 gatekeepers, 8 Estonian watchmen, 2 watch sergeants at the hall, castle garrison 36 plus squires | ample for 8 gates and the wall-walk rota of 4-8 men per section |
| Bread and beer | 28 bakers, 39 brewers and 29 alewives, 26 tavern keepers, plus household brewing | about one baker per 150 people, one brewing house per 100 |
| Meat, fish, dairy | 19 butchers, 21 fishmongers, 15 fishers and their families, 40 dairy-women, market gardeners | thin on fresh fish (the plan's fishing beach is small); herring and salt fish come by sea |
| Building and metal | 29 carpenters, 28 masons, 28 smiths, 17 coopers, 15 knife-smiths, 10 armourers | enough for a town still raising its walls |
| Cloth and leather | 35 shoemakers, 32 tailors, 22 furrier households, 15 weavers, 13 saddlers, 10 cap-makers, 7 tanners, spinners (372) | cloth is imported; spinning is household work |
| Harbour and haul | 102 sailors, 76 day labourers, 23 porters, 10 carters, 8 ropemakers, 10 skippers, 8 boat-builders | spring ice-out population is seasonal |
| Money and paper | 88 long-distance merchants, 67 retailers, 135 clerks, 8 scribes, a Stadtschreiber, a moneychanger | the council and Kindergilde |
| Care and church | 13 midwives, 13 herb-wives, 4 barber-surgeons, 2 bathkeepers, 98 clergy, 20 hospital inmates | below modern ratios; most care is household |
| Rich and poor | 20 council households, about 60 great and merchant houses, about 160 poor dwellings, 20 hospital inmates and licensed beggars | |

If a number looks off for a scene, change the weights in the generator and **regenerate before any card exists**; after cards exist, edit or add records instead (see below).

## Using and extending the data

1. **Read:** the [ledger](./ledger/README.md) lists every household and resident per street, with the seed values and a link to a card where one exists.
2. **Promote a resident:** copy the seed into a card using [`WRITING_CARDS.md`](./WRITING_CARDS.md) and [`TEMPLATE.md`](./TEMPLATE.md); add the person's id to `FORCE_CARDS` in `tools/city/plan_citizen_cards.py` or raise `TARGET_CARDS`, rerun the planner (cards already written are unaffected because the plan is deterministic per person), then rerun `tools/city/build_citizen_ledger.py`.
3. **Freeze rule:** `docs/data/city_census.json` is the source of truth once cards exist. Never change the generator's random draws to "re-roll" people; change data deliberately and fix the affected cards in the same commit. `tools/city/build_city_census.py --check` fails when the committed file differs from the generator output, so a deliberate change updates both.
4. **Crowd runtime (not built):** `UrbanPopulationProfile` can pick named residents for a street's phase from the ledger. This needs a task naming `scripts/world/` files; until then the census is content.

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

- The plan holds modern plot footprints trimmed to 1343, so plot counts and sizes are plausible, not measured. Small footprints (outbuildings) may hide cellar and yard dwellings the model does not count.
- Hinterland and suburb populations beyond the six districts are not modelled.
- Seasonal and siege effects (refugees at the gates, rebel levy, Order troops) are narrative overlays, not census rows.
- Ethnic and faction proportions are plausible, not attested; the 74% unaffiliated majority is a deliberate choice.
