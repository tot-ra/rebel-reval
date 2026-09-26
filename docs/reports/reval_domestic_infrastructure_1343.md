# 1343 Reval domestic infrastructure

Recorded: 2026-09-26
Board: **R-984** / WB-12
Scope: household water, food, fuel, heat, sanitation, and waste for later plot prefabs
(R-985) and the Lower Town density pass (R-986). Not building form (that is AR-01 /
R-959). Not art direction (ADR 0018).

This report is the evidence gate for `docs/tasks/world/WB-12_domestic_infrastructure_dossier.md`.
It does not add assets, maps, or runtime code. It does not change the signed P0-072
built/open or surface bands in `docs/HISTORICAL_AUDIT.md`.

## Confidence labels

Two vocabularies are in use. Map them; do not invent a third.

`docs/CANON.md`:

- **`attested`**: contemporary document, dated fabric, or published excavation
- **`plausible composite`**: a 1343 gameplay type built from dated local or named
  comparanda, with the gap named
- **`invented`**: a number or feature with no source (must not appear as fact)
- **`folklore`**: not used for household services

P0-072 evidence classes in `docs/HISTORICAL_AUDIT.md`:

- **`A`**: attested support for the decision
- **`B`**: a bounded authoring range inferred from several attested observations.
  The range is a testable hypothesis, never a measured 1343 statistic
- **`C`**: later survival used only for general form
- **`D`**: gameplay assignment inside A-C limits
- **`U`**: reviewed evidence does not establish a useful 1343 answer

An uncited number is not allowed. If a source does not give the field, the table
says **unknown**. A figure from another town or a later century stays a labelled
comparandum and is **`U`** for Reval 1343 counts.

## How R-985 and R-986 should read this

1. Dress every burgher rear yard with a **service set**, not a decorative clutter
   pile. The default set is privy, well or shared-well access, woodpile, chip or
   manure heap, and a kitchen-garden bed where the plot has open ground ([1], [2],
   [5]).
2. Do not fill the street with livestock or wells. Cattle dominate **bone**
   assemblages, not live animals on every Lower Town plot ([7]). Public wells are
   scarce named points; private wells sit in yards ([1], [5], [8]).
3. Drain yards to open gutters, soakage, moat, or the coast. Do not add a
   citywide sewer or the later Viru timber pipes ([3], [4], [9]).
4. Keep `MarketDayModel` Wednesday/Saturday as an **`invented`** fallback. The
   1343 market weekday is unknown ([10]).
5. Leave flue geometry, cellar-hatch form, and pentice carpentry to AR-01. This
   report only says those services exist and where they sit.

## 1. Water

### Wells

Wells are attested in 1343-relevant Reval archaeology and institutional
descriptions: courtyard wells and gutters in the western Lower Town NUKU
excavation ([1]), a medieval well in the Bishop's Garden on Toompea ([8]), and a
courtyard well at the Dominican friary of St Catherine ([11]). Rataskaevu is
named from a wheel-well; the street-name tradition records a well mention in
1325 and a rebuild in 1375, so the **name** is earlier than 1343 and the
standing rebuild is later ([12]).

Construction of a typical 1343 household well (stone-lined shaft versus timber
box, depth, lining) is **unknown** in the reviewed register. Do not copy a
later Cat's Well superstructure onto every plot.

Who used which well is also **unknown** as a census. The burgher-house typology
places a well sweep in the rear yard of a strip plot ([2]). Labourer wash water
is a shared yard bucket or well sweep in the hygiene dossier, labelled
`plausible composite` ([13]). That is an authoring hypothesis, not a household
count.

Water carriers as a named 1343 Reval trade are **unknown**. Estonian labourers
may haul under burgher direction in the street-cleaning composite ([9]); that
does not prove a licensed water-carrier craft.

### Rainwater and drains

P0-072 drainage is **A/B/U**: streets and yards shed toward open ditches, wall
moats, coast, wells or soakage, or localized stone and wood gutters. Covered
stone drainage is allowed where attested, especially the slab-lined rainwater
channel at the Great Coastal Gate that drains toward the sea ([4], [5]).

Wooden roof channels for roof water, and a licensed bath wasting into a
peripheral drain, are `plausible composite` in the hygiene dossier ([13]). They
are not a measured gutter inventory.

Later timber water pipes found near Viru **cannot** be assumed medieval ([3]).

### Watermills

A watermill is placed with the Viru main gate in the mid-14th century ([3]).
Karja Gate archaeology leaves the 1343 watermill superstructure **uncertain**;
the name *Kariestrate* is 1365 ([6]). Author a simple mid-14th-century mill
mass at Viru only as **B/U**, and do not treat a Karja mill as a 1343 fact.

These mills grind grain. They are not the household drinking supply.

### Harbour and moat water

No reviewed source states a 1343 Reval ban on drinking harbour or moat water.
Drinking and wash water in the food and hygiene dossiers are wells and cisterns
([14], [13]). Author **no drinking from harbour, ditch, or moat**. That is a
**B** placement rule from well-centric evidence, not an attested ordinance.
Harbour water remains for boats, fish work, and waste outflow ([4]).

### Authoring table: water

| Service | Prop / structure | Per plot | Per district | Placement | Class |
|---|---|---|---|---|---|
| Private well | Yard well with sweep or windlass; timber collar, no later stone monument | 0-1 on a burgher or craft plot that has a rear yard. Labourer *boda* plots may share. Do not force a well on every cell. | Several private wells in a dense block, plus the named public or precinct wells below | Rear yard, away from the privy pit | **B** from [2], [13]; construction **U** |
| Public / precinct well | Simple well head, not the 1375 Cat's Well rebuild | 0 | Dominican courtyard ([11]) **A**; Bishop's Garden ([8]) **A**; at most one street well on the Rataskaevu / *sub monte* belt as a 1325-named point ([12]) **B/C** | Precinct close or street node, never the bath itself ([12]) | **A** / **B** / **C** as marked |
| Roof drain | Wooden eaves channel or short downpipe to a barrel | 0-1 water butt or barrel under the eaves on plots with a timber roof channel | Not a street furniture run | Against the rear or side wall, feeding soakage or the yard gutter | **B** from [13]; count **U** |
| Yard / street gutter | Open wood or stone gutter; packed-earth channel | 1 shallow fall on each rear yard | Street-side channels on primary lanes; not a closed sewer | Fall toward moat, coast, or a soakage / well point ([5]) | **A/B** from [1], [5] |
| Covered drain | Slab-lined channel | 0 on ordinary plots | Only where H11 supports it (Coastal Gate rainwater run to the sea) | Gate / cliff line, draining seaward | **A** from [4] |
| Viru watermill | Compact mill mass at the gate / moat | 0 | 0-1 at Viru, construction-in-progress allowed | Gate waterworks, not a house prop | **B/U** from [3] |
| Karja watermill | None as a 1343 fact | 0 | 0 | Omit or hold as **U** placeholder mass without a working wheel | **U** from [6] |
| Water carrier NPC | None required | 0 | 0 as a named craft. A haulier with a yoke or barrel may appear as **D** colour | Street, not a well franchise | **U** |

`lower_town_slice` currently has two wells for 19 456 cells. That is below the
**B** yard-well hypothesis (most burgher yards can show a well or a shared
sweep). It is not a measured deficit. R-986 should raise well props toward the
per-plot band, not toward an invented citywide density.

## 2. Food

### Household storage

Stone and timber houses combine living space with storage. Cellars take beer
and grain; upper floors under the gable can be granaries reached by a hoist on
merchant houses ([2], [15]). Chests and cupboards hold dry goods and linen
([16]). Exact 1343 household inventories are **unknown**.

Salt fish and salt sit with the harbour and cellar trade, not as a measured
barrel count ([14], [17]). Root crops and brewing stock are `plausible
composite` cellar and loft goods ([14]). Moisture in a wet April is a risk, not
a quantity.

### Gardens

H05 records Cistercian vegetable and fruit gardens in one western Lower Town
quarter ([1]). H15 gives the Dominicans a small courtyard garden ([11]). H12
supports garden or orchard land use on western Toompea without defining every
plot ([8]). H17 confirms medieval urban plant remains in Estonian towns and
warns that sampling cannot set a 1343 species mix or planted-area share ([18]).

P0-072 already bounds inside-wall kitchen and fruit plots on the Lower Town
card at 3-10% of developable land (**B/U**). This report does not tighten that
band.

### Livestock

H18: cattle, sheep, goats, pigs, and horses dominate studied domestic mammal
assemblages; cattle are most abundant; Tallinn suburban sites are included.
Bones do not prove live-animal density or a 1343 plot assignment ([7]). H19:
chicken is the most common bird across most sites ([19]).

P0-072 fauna bands stay in force. Inside the wall, domestic presence is
**`low`**: contained chickens preferred; one tethered horse or ox, or one small
pig, sheep, or goat yard, where routes allow. Wild mammals stay `none` in the
dense core ([5]).

Do not stock every yard with cattle because cattle bones are common. Cattle
are the consumption signal. Live cattle belong at the suburb, gate apron, or a
rare tether, not as a street herd.

### Baking

Rye bread is the daily staple in the food dossier (`plausible composite`)
([14]). Town bakers are a regulated craft in that composite. **No attested
1343 Reval bakery street name** was found in the reviewed topography dossiers
([14]). Cooking is at the open hearth or hooded fire in the living bay or a
rear-yard kitchen shed ([14], [2]).

A commercial bakehouse may appear as a **D** craft landmark inside the physical
limits (stone or clay oven, fire-separated). It is not a named 1343 address.
Do not label the `MarketDayModel` weekday as historical ([10]).

### Market rhythm

The civic market is the *forum* at Raekoja plats, attested from 1313 ([10]).
Vanaturu kael is a cart throat, not a second market square. The weekly weekday
is a gap. Keep `market_weekday` unset in canon. After 23 April, siege pressure
may thin inland supply without revealing the normal market day ([10], [17]).

### Authoring table: food

| Service | Prop / structure | Per plot | Per district | Placement | Class |
|---|---|---|---|---|---|
| Grain / beer store | Cellar neck, loft bins, or barrel row | 1 cellar or loft store on merchant and craft houses that have a cellar or gable loft | Merchant streets show hoists; *boda* plots may have only a chest and a sack | Cellar or upper granary, not the street | **A** type from [2]; contents **B** from [14] |
| Salt fish / salt | Barrel or sack pile | 0-1 on harbour and affluent cellar plots | Kalamaja and cellar streets, not every inland yard | Cool cellar or shore store | **B** from [14], [17]; count **U** |
| Kitchen garden | Raised or fenced bed; fruit tree only on selected plots | 0-1 bed on plots with open rear ground. Not on a fully built interior | District garden share stays the P0-072 3-10% inside-wall band | Rear yard, monastic close, Bishop's Garden land use | **A/B/U** from [1], [8], [11], [18], [5] |
| Drying line | Line between shed and plot wall | 0-1 | Sparse | Rear yard, not the street frontage | **D** inside the yard typology [2] |
| Chicken coop | Small wattle coop or basket coop | 0-1 where domestic fauna is `low` | A few per block, never a street flock | Rear yard, gated | **B/U** from [19], [5] |
| Larger livestock | Tether, short rail, or one small pen | 0 on most plots. At most one horse/ox tether or one small pig/sheep/goat pen per allowed yard | Gate apron, suburb, or rare inner-wall working animal | Off the required walking route | **B/U** from [7], [5] |
| Household hearth kitchen | Corner mantel hearth or hooded fire; kettle gear | 1 per dwelling | - | Diele, living bay, or rear kitchen shed | **A/B** from [2], [14] |
| Commercial bakery | Oven house | 0 | 0-1 **D** landmark if a craft node is needed. No named street | Fire-separated rear or side of a craft plot | **D**; street name **U** ([14]) |
| Forum stalls | Temporary boards and baskets | 0 | Forum only, when `market_open` | Raekoja plats, not Vanaturu kael as a second square | **A** location [10]; weekday **U** |

## 3. Fuel and heat

### Household fuel

A rear-yard firewood stack is part of the burgher-house exterior prop list
([2]). Birch, alder, and pine are the charcoal-wood candidates in the smithing
dossier (`plausible composite`) ([20]). **Household winter volume, stack
duration, and cartloads per plot are unknown.** Do not import a later or
foreign cordwood figure as a 1343 Reval fact.

Fuel entered the town as timber and charcoal on carts from the hinterland
([17], [20]). After 23 April those routes tighten in the trade composite
([17]). That is a supply story, not a litre count.

### Forge and bath fuel

Kalev's forge burns **charcoal**, stored in a roofed crib at least about 2 m
from the sleeping partition (`plausible composite`) ([21], [20]). A full
commission day in that dossier uses 8-15 kg of charcoal; a single heat about
0.5-2 kg ([20]). Those bands are smithing hypotheses, not household hearths,
and they are not a measured Reval price series.

AWB 553 (1342 register sequence) binds three *stupa* (bath) sites to wood and
wood-hauling payments at Michaelmas (`unam mc. arg.` on two sites, `4 mc. den.`
on the third, abbreviation unexpanded) ([22]). That is **attested** civic bath
fuel obligation. It is not a household fuel tariff and not a *Badpacht*.

Peat is not attested as Kalev's smithing fuel ([20]).

### Hearth versus forge

- Ordinary dwelling: corner mantel hearth or hooded fire in the diele or living
  bay ([2], [14]). **A/B**
- Affluent stone house: possible hypocaust from a cellar furnace to the dornse.
  Surviving systems are later or undated for 1343 share. Label **C** for the
  surviving fabric, **U** for the 1343 percentage ([2])
- Forge: separate hot-work hearth, stone-footed, banked at the evening bell
  (`plausible composite`). **No attested 1343 Reval Feuerordnung** was found
  ([21])

Brick chimney pots are a later reject ([21]). A smoke hole or a simple flue
mass may read on timber houses; the exact 1340s split is **U**. AR-01 owns the
flue form.

### Authoring table: fuel and heat

| Service | Prop / structure | Per plot | Per district | Placement | Class |
|---|---|---|---|---|---|
| Firewood stack | Split-log pile, optionally under a lean-to | 1 on every plot that has a dwelling hearth | Visible in rear yards, rare on the street | Rear yard, clear of the privy and the well | **A** as a yard prop type [2]; volume **U** |
| Charcoal crib | Roofed bin or sack stack | 1 at a forge or other hot trade. 0 on ordinary dwellings | Forge yards and, as colour, bath service yards | >= 2 m from sleeping space; dry | **B** from [21], [20] |
| Dwelling hearth | Corner hearth or hooded fire | 1 per dwelling | - | Diele / living bay / yard kitchen shed | **A/B** from [2], [14] |
| Hypocaust furnace | Cellar furnace mouth | 0-1 on affluent stone houses only | Rare | Cellar under the dornse | **C** surviving; 1343 share **U** ([2]) |
| Forge hearth | Raised hearth, side tuyere, quench trough | 1 in the smithy | Hot-trade plots only | Stone-footed work floor; quench to a short gutter or soakage, no sewer ([21], [5]) | **B/U** |
| Bath wood obligation | Stack at a municipal *stupa* | 0 on houses | Only at documented bath sites | Bath service yard | **A** payment [22]; stack form **B** |
| Chimney pot | None | 0 | 0 | Omit brick pots | reject ([21]) |

## 4. Sanitation and waste

This is the largest map gap. H05 records manure and chip yard layers with
wells, gutters, and wattle in a western Lower Town courtyard ([1]). That is
**A** for yard waste as archaeology. It is not a citywide pit census.

### Latrines and cesspits

The burgher-house and hygiene dossiers place a privy shed in the rear yard,
over a pit or barrel ([2], [13]). Stone-lined reusable pits and professional
emptying are argued from Tartu latrine dendrochronology of 1335 ([13]). Tartu
is another town. For Reval 1343 that construction and emptying trade are
**U**. Author a rear-yard privy shed as **B**. Do not claim stone lining or a
named emptier as Reval fact.

Night soil and dung go to a cart or a pit beyond the gate, not into the street
gutter, under council pressure (`plausible composite`) ([13], [9]). There is
**no attested 1343 Reval municipal dung-cart contract** in the reviewed AWB or
Bunge material ([9]). Do not show a named weekly municipal roster.

### Street duty

Council street orders rest on the 1282 Reval Lübeck-law codex Art. 31 (council
orders are council-judged) plus neighbour-path articles in the Lübeck
transmission for keeping the frontage passable ([9]). A fine amount for forum
dumping is **unset** in the published Reval record. Quest figures of 4-12
schillings are Hanse comparanda only ([9]).

The AWB 1340-1343 pass did not yield a *Mist*, *Gasse*, or street-cleaning
tariff ([22]). That is an edition-local negative, not proof that no such rule
existed.

### Where refuse sat

- Chip, ash, and manure layers in the rear yard ([1]) **A**
- Frontage ash or stable muck belongs in the yard or on a cart, not in the
  forum throat or gate apron ([9]) **B**
- Smith slag and ash go to a yard pit, not the living floor ([21]) **B**
- P0-072 ground already includes dung-darkened soil and chips in yards ([5])
  **A/B**

### Authoring table: sanitation

| Service | Prop / structure | Per plot | Per district | Placement | Class |
|---|---|---|---|---|---|
| Privy | Timber shed over a pit or barrel | 1 on every burgess plot with a rear yard. Labourer plots may share a shed | One shed per yard, not a street row | Rear yard, downslope of the well | **B** from [2], [13]; lining **U** |
| Cesspit / barrel | Unseen or lid-only | 1 under or beside the privy | - | Rear yard | **B** presence; stone lining **U** |
| Midden / chip heap | Low chip, ash, and manure pile | 1 small heap per rear yard | Yards look used, not sterile | Rear yard, not the forum or gate apron | **A** layers [1]; size **U** |
| Street gutter | Open channel | Frontage fall on the plot mouth | Primary lanes | Shed toward ditch, moat, or coast | **A/B** from [1], [5] |
| Extra-mural dung pit | Pit or field heap | 0 | 1 implied beyond Viru or the harbour gate | Outside the wall, off the playable street if the map stops at the gate | **B** from [13], [9]; location **U** |
| Municipal dung cart | Hired cart, not a livery | 0 as a weekly roster | Occasional **D** cart at a gate | Gate road | **U** contract; **D** if shown ([9]) |
| Forge waste pit | Slag and ash scoop | 1 at the smithy | Hot trades only | Yard, not the diele floor | **B** from [21] |

## 5. What this means for authoring (R-985 input)

R-985 `burgher_plot` should expand to this **minimum rear-yard set** on a
standard strip plot (7-11 m frontage band from H04, form owned by AR-01):

1. House hearth (inside) and a rear **firewood stack**
2. **Privy shed** downslope of water
3. **Well or shared-well access** (sweep visible, or a path to a neighbour well)
4. **Chip / manure heap**
5. **Kitchen-garden bed** if any open ground remains after sheds
6. Optional **water butt**, **drying line**, and **chicken coop**

Do not add a byre, hay barn, or cattle herd to an ordinary inner-wall burgher
plot. Keep larger animals on the P0-072 `low` band.

`lower_town_slice` today: two wells, one firewood stack, one malt sack pile,
one wash tub, and no latrine, midden, gutter, drain, water butt, kitchen
garden, byre, or hay store. The missing props are the ones in the tables
above, not a new building family.

## 6. Reject list

Do not add any of the following as 1343 Reval fact or default dressing:

- Later Viru **timber water pipes** as medieval household plumbing ([3], [5])
- A **citywide underground sewer** or modern sewer grates ([5], [13])
- **Brick chimney pots** and a default open courtyard forge ([21])
- **Chimneys and window glass** as the ordinary timber-house package (glass and
  chimney share are **U**; do not upgrade every plot)
- **Saunatorn** as a 1343 stone tower (tower 1371+) ([12])
- **Nuns' Gate (1355)** and the **1391** poor-bath / Thursday free-bath law
  ([12], [9])
- **Cat's Well as a bath** (it is a drinking well; 1375 rebuild is later)
  ([12])
- A named **weekly municipal dung-cart roster** or an AWB *Badpacht* /
  manure-fine tariff as attested 1343 money ([9], [22])
- Expanding AWB `4 mc. den.` to "4 denarii" without a denomination note ([22])
- **Night soil in the street gutter** as the accepted norm ([13], [9])
- **Potatoes, coffee, tea, refined sugar**, and daily fresh meat for every
  labourer in late April ([14])
- **Post-1343 monuments** already excluded by P0-072: Fat Margaret, later
  Great Guild and Blackheads frontages, later St Olaf basilica and spire,
  completed later Holy Spirit church, later Cathedral west tower, post-1420
  Bishop's House, Viru barbicans, mature Karja barbican ([5])
- Regular long **stone harbour quays** as required 1343 fabric ([5])
- A **Wednesday or Saturday market** stated as the historical weekday ([10])
- **Peat** as Kalev's forge fuel; blast furnace, coke, or yard ore smelting
  ([20])
- Live **cattle herds** inside dense Lower Town streets because H18 bones are
  mostly cattle ([7])
- Tartu 1335 stone latrine dimensions copied as Reval measurements ([13])

## Open questions

Leave these empty. Do not fill them from another town.

- Measured 1343 well depth, lining, and wells-per-street
- A named water-carrier craft or a public-well map
- Operational state of the Viru and Karja watermills in April 1343
- Household firewood volume and a 1343 Reval Feuerordnung text
- Denkelbuch payments to dung carriers or street sweepers in 1342-1343
- A Reval bakery street name
- The weekly market weekday

## Sources

Register IDs **H05, H09, H10, H11, H12, H15, H17, H18, H19** are the P0-072
rows in `docs/HISTORICAL_AUDIT.md`. Dossier paths are under `history/dossiers/`.

1. H05. Heinloo, NUKU courtyard archaeology. Wells, gutters, manure and chip
   yard layers, Cistercian gardens. One western quarter only.
2. `architecture/burgher-house-plan.md`. Strip-plot rear yard: privy, well
   sweep, firewood stack, cellar, diele hearth.
3. H09. Kraut and Nurk, Viru / Vana Turg / Kuninga. Mid-14th-century gate and
   watermill; later timber pipes not medieval.
4. H11. Reppo and Kadakas, Great Coastal Gate. Slab-lined rainwater channel
   toward the sea.
5. `docs/HISTORICAL_AUDIT.md` P0-072 shared constraints 6-11 and the Lower Town
   map card.
6. H10. Nurk et al., Karja Gate. 1343 watermill state uncertain; name 1365.
7. H18. Rannamäe and Aguraiuja-Lätti, livestock and game. Cattle most abundant
   in assemblages; not a live-plot census.
8. H12. Reppo, Toompea Bishop's Garden. Medieval well; Bishop's House from
   1420 only.
9. `power/reval-street-cleaning-ordinances-1340s.md`. Art. 31 authority;
   no attested 1343 dung-cart contract or fine amount.
10. `economy/reval-market-weekday-1340s.md`. Forum attested; weekday unknown;
    `MarketDayModel` is an implementation fallback.
11. H15. Dominican friary of St Catherine. Courtyard well and small garden.
12. `topography/public-bath-locations-1343.md`. Rataskaevu well versus bath;
    Saunatorn and 1391 law excluded.
13. `dailylife/hygiene-and-grooming-1343.md`. Rear-yard privy; Tartu 1335
    latrine held as a foreign comparandum.
14. `dailylife/food-and-drink.md`. Cellar stores, hearth kitchen, no bakery
    street name.
15. `docs/CANON.md` Daily Life, Gothic tenement storage loft.
16. `architecture/domestic-storage-furniture.md`. Chests and cupboards; later
    linenfold rejected.
17. `economy/hanseatic-trade-and-season.md`. Grain, salt, fish, charcoal-cart
    pressure after 23 April.
18. H17. Johanson, Unt and Hiie, archaeobotany. Presence without 1343 shares.
19. H19. Ehrlich, Aguraiuja-Lätti and Haak, bird exploitation. Chicken most
    common.
20. `crafts/blacksmith-materials-and-techniques.md`. Charcoal masses for
    smithing only.
21. `architecture/smithy-workshop-layout.md`. Forge hearth, charcoal crib,
    no 1343 Feuerordnung.
22. `power/awb-sanitation-clauses-1340-1343.md`. AWB 553 wood obligation;
    no *Badpacht* or manure fine in the reviewed band.
