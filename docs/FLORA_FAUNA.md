# Flora and Fauna of Reval (Estonia, 1343)

This document tracks the native vegetation and animals present in the game engine versus the target historical scope for the 1343 Reval environment. It serves as a reference for environment authoring, prop creation, and ambient wildlife systems.

## Currently Implemented

**Trees (10 types)**
Supported in `MapViewTreeSpecies` (`scripts/map/view3d/map_view_tree_species.gd`):
- Spruce (`tree.spruce`)
- Pine (`tree.pine`)
- Birch (`tree.birch`)
- Oak (`tree.oak`)
- Alder (`tree.alder`)
- Aspen (`tree.aspen`)
- Maple (`tree.maple`)
- Linden (`tree.linden`)
- Apple (`tree.apple`)
- Cherry (`tree.cherry`)

**Bushes and Shrubs (2 types)**
Supported in `TerrainVegetation` (`scripts/map/terrain_vegetation.gd`):
- Dense Bush (`bush.dense`)
- Scrub Bush (`bush.scrub`)

**Plants and Grasses (8 types)**
Supported in `TerrainVegetation` (`scripts/map/terrain_vegetation.gd`):
- Short Grass (`grass.short`)
- Tall Grass (`grass.tall`)
- Flowers (`grass.flowers`)
- Dry Grass (`grass.dry`)
- Mossy Grass (`grass.mossy`)
- Clover (`grass.clover`)
- Fern (`grass.fern`)
- Shore Reed (`reed.shore`)

**Animals and Birds (0 types)**
- None currently implemented in the ambient or combat systems (beyond legacy bestiary folklore enemies like Kratt and Puuk).

---

## Target Historical Scope (1343 Native Species)

Below is the sourced listing of native flora and fauna for expansion to reach the ~20 tree, ~20 bush, ~30 plant, ~30 bird, and animal targets. Ensure mapped vegetation and spawned entities draw from this regional palette rather than generic fantasy stand-ins.

### Trees (~20 types target)
The northern Baltic canopy is dominated by conifers and cold-hardy broadleaves.
1. **Scots Pine** (*Mänd*) - Dominant in sandy soils and bogs. [IMPLEMENTED]
2. **Norway Spruce** (*Kuusk*) - Common in dense, dark forests. [IMPLEMENTED]
3. **Silver Birch** (*Kask*) - Ubiquitous, pioneers clearings. [IMPLEMENTED]
4. **Eurasian Aspen** (*Haab*) - Common in mixed woodlands. [IMPLEMENTED]
5. **Grey/Black Alder** (*Lepp*) - Thrives in wet soils. [IMPLEMENTED]
6. **Pedunculate Oak** (*Tamm*) - Rare but massive. [IMPLEMENTED]
7. **Small-leaved Linden** (*Pärn*) - Richer soils. [IMPLEMENTED]
8. **Norway Maple** (*Vaher*) - Mixed broadleaf forests. [IMPLEMENTED]
9. **Wild/Orchard Apple** (*Õunapuu*) - Gardens. [IMPLEMENTED]
10. **Sour Cherry** (*Kirsipuu*) - Cultivated. [IMPLEMENTED]
11. **European Ash** (*Saar*) - Coastal and nutrient-rich soils.
12. **Wych Elm** (*Jalakas*) - River valleys.
13. **White/Goat Willow** (*Paju*) - Near water bodies.
14. **Rowan** (*Pihlakas*) - Common understory, culturally significant.
15. **Common Hazel** (*Sarapuu*) - Understory, historically managed for nuts.
16. **Common Juniper** (*Kadakas*) - Abundant on coastal alvars.
17. **Primitive Plum / Damson** (*Ploomipuu*) - Brought by monks/traders.
18. **European Pear** (*Pirnipuu*) - Rare, high-status gardens.
19. **Common Hawthorn** (*Viirpuu*) - Hedgerows and forest edges.
20. **Blackthorn** (*Laukapuu*) - Coastal thickets.

### Bushes and Shrubs (~20 types target)
1. **Red Raspberry** (*Vaarikas*) - Forest edges.
2. **European Blueberry / Bilberry** (*Mustikas*) - Pine/spruce forest floor.
3. **Lingonberry** (*Pohl*) - Dry pine forests.
4. **Cranberry** (*Jõhvikas*) - Bogs and mires.
5. **Cloudberry** (*Murakas*) - Bogs.
6. **Wild Gooseberry** (*Karusmari*) - Forest margins.
7. **Redcurrant** (*Punane sõstar*) - Damp woodlands.
8. **Blackcurrant** (*Must sõstar*) - Wet forests.
9. **Guelder-rose** (*Koerakoolpuu*) - Understory.
10. **European Spindle** (*Kikkapuu*) - Rare woodland shrub.
11. **Alder Buckthorn** (*Paakspuu*) - Wet scrubland.
12. **Sea-buckthorn** (*Astelpaju*) - Coastal dunes.
13. **Dog Rose / Rosehip** (*Kibuvits*) - Coastal areas, hedges.
14. **Fly Honeysuckle** (*Kuslapuu*) - Forest understory.
15. **Elderberry** (*Leeder*) - Near human settlements.
16. **Bog-myrtle** (*Raba-porss*) - Wetlands, used in beer brewing.
17. **Common Heather** (*Kanarbik*) - Bogs and poor sandy soils.
18. **Crowberry** (*Kukemari*) - Bogs.
19. **Wild Blackberry** (*Põldmari*) - Scrublands.
20. **Dwarf Birch** (*Vaevakask*) - Bogs.

### Plants, Herbs, and Crops (~30 types target)
1. **Stinging Nettle** (*Nõges*) - Around settlements, used for fiber/soup.
2. **Mugwort** (*Puju*) - Weedy areas, medicinal/magical use.
3. **Yarrow** (*Raudrohi*) - Meadows, wound healing.
4. **Broadleaf Plantain** (*Teeleht*) - Paths, disturbed ground.
5. **Dandelion** (*Võilill*) - Meadows.
6. **Burdock** (*Takjas*) - Near habitations.
7. **Creeping Thistle** (*Ohakas*) - Fields.
8. **Red/White Clover** (*Ristik*) - Pastures. [IMPLEMENTED]
9. **Bracken / Male Fern** (*Sõnajalg*) - Forest floor. [IMPLEMENTED]
10. **Sphagnum Moss** (*Turbasammal*) - Bogs.
11. **Common Reed** (*Pilliroog*) - Coast, thatching. [IMPLEMENTED]
12. **Bulrush** (*Hundinui*) - Shallow waters.
13. **White Water Lily** (*Vesiroos*) - Lakes.
14. **Cabbage** (*Kapsas*) - Primary garden crop.
15. **Turnip** (*Naeris*) - Staple root crop.
16. **Onion** (*Sibul*) - Gardens.
17. **Garlic** (*Küüslauk*) - Gardens, medicinal.
18. **Peas** (*Hernes*) - Field crop.
19. **Broad Beans** (*Oad*) - Field crop.
20. **Rye** (*Rukis*) - Dominant cereal, winter crop.
21. **Wheat** (*Nisu*) - High-status cereal.
22. **Barley** (*Oder*) - Used for bread and ale.
23. **Oats** (*Kaer*) - Animal feed, porridge.
24. **Flax** (*Lina*) - Crucial for linen clothing.
25. **Hemp** (*Kanep*) - Ropes, coarse cloth.
26. **Hops** (*Humal*) - Brewing.
27. **Mint** (*Münt*) - Gardens.
28. **Caraway** (*Köömne*) - Meadows, seasoning.
29. **Chamomile** (*Kummel*) - Medicinal.
30. **St. John's Wort** (*Naistepuna*) - Medicinal, protective herb.

### Birds (~30 types target)
1. **White Stork** (*Valge-toonekurg*) - Nests near settlements.
2. **Black Stork** (*Must-toonekurg*) - Deep old-growth forests.
3. **Common Crane** (*Sookurg*) - Bogs and fields.
4. **Grey Heron** (*Hallhaigur*) - Wetlands.
5. **Mute Swan** (*Kühmnokk-luik*) - Coastal waters.
6. **Mallard** (*Sinikael-part*) - Ponds, lakes.
7. **Black-headed Gull** (*Naerukajakas*) - Coastline.
8. **Arctic Tern** (*Randtiir*) - Coastal.
9. **Western Capercaillie** (*Metsis*) - Pine forests, hunted.
10. **Black Grouse** (*Teder*) - Bogs and clearings.
11. **Hazel Grouse** (*Laanepüü*) - Dense mixed woods.
12. **Grey Partridge** (*Nurmkana*) - Farmland.
13. **Great Spotted Woodpecker** (*Suur-kirjurähn*) - Forests.
14. **Black Woodpecker** (*Musträhn*) - Old-growth forests.
15. **Eurasian Eagle-Owl** (*Kassikakk*) - Large predator.
16. **Tawny Owl** (*Kodukakk*) - Woods and ruins.
17. **Northern Goshawk** (*Kanakull*) - Forest predator.
18. **Peregrine Falcon** (*Rabapistrik*) - Bogs/cliffs.
19. **White-tailed Eagle** (*Merikotkas*) - Coasts and large lakes.
20. **Common Raven** (*Kaaren* / *Ronk*) - Scavenger, battlefield presence.
21. **Hooded Crow** (*Vares*) - Common.
22. **Eurasian Magpie** (*Harakas*) - Thickets and farms.
23. **Eurasian Jay** (*Pasknäär*) - Oak/mixed woods.
24. **House Sparrow** (*Koduvarblane*) - Urban Reval.
25. **Great Tit** (*Rasvatihane*) - Woodlands, gardens.
26. **Common Chaffinch** (*Metsvint*) - Common songbird.
27. **Barn Swallow** (*Suitsupääsuke*) - Barns and eaves.
28. **Eurasian Skylark** (*Põldlõoke*) - Open fields.
29. **Thrush** (various) (*Rästas*) - Woodlands.
30. **Thrush Nightingale** (*Ööbik*) - Famous singer in dense bushes.

### Mammals (Target)
1. **Brown Bear** (*Pruunkaru*) - Apex predator, deep forests.
2. **Grey Wolf** (*Hunt*) - Highly feared, threatens livestock.
3. **Red Fox** (*Rebane*) - Common predator.
4. **Eurasian Lynx** (*Ilves*) - Stealthy forest predator.
5. **Elk / Moose** (*Põder*) - Largest herbivore, bogs and forests.
6. **Roe Deer** (*Metskits*) - Forest edges.
7. **Wild Boar** (*Metssead*) - Deciduous and mixed forests.
8. **Eurasian Beaver** (*Kobras*) - Rivers, hunted for fur and castoreum.
9. **European River Otter** (*Saarmas*) - Clean rivers and lakes.
10. **European Badger** (*Mäger*) - Woodlands.
11. **Wolverine** (*Ahm*) - Dense northern forests (historically present).
12. **Pine Marten** (*Metsnugis*) - Tree canopy predator.
13. **European Polecat** (*Tuhkur*) - Near farms, kills poultry.
14. **Stoat / Ermine** (*Kärp*) - Important fur source.
15. **Least Weasel** (*Nirk*) - Smallest carnivore.
16. **Brown Hare** (*Halljänes*) - Fields and meadows.
17. **Mountain Hare** (*Valgejänes*) - Forests, white in winter.
18. **Red Squirrel** (*Orav*) - Pine forests.
19. **European Hedgehog** (*Siil*) - Gardens and edges.
20. **Grey Seal** (*Hallhüljes*) - Hunted on the coastal ice.
21. **Ringed Seal** (*Viigerhüljes*) - Coastal.
22. **Various Bats, Voles, Mice, and Shrews.**
