#!/usr/bin/env python3
"""Generate docs/TOURIST_LANDMARKS.md with ~100 Tallinn + ~100 Estonia landmarks."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "TOURIST_LANDMARKS.md"

# Each entry: (name, modern, status_1343, lore)
# status_1343 must not be "Does not exist" for inclusion.

TALLINN: dict[str, list[tuple[str, str, str, str]]] = {
    "Toompea (Upper Town)": [
        (
            "Toompea Castle (Toompea loss)",
            "Seat of the Estonian Parliament with a pink Baroque palace and Tall Hermann tower.",
            "A stark Danish stone castle on the hilltop; Tall Hermann tower is not built yet.",
            "Ultimate target of the St. George's Night Uprising; Danish viceroy and Order envoys hold court here.",
        ),
        (
            "St. Mary's Cathedral (Toomkirik)",
            "Oldest church in Tallinn, lined with Baltic German noble coats of arms.",
            "Spiritual center of Toompea serving Danish and German elite since the 13th century.",
            "Ellen Luik aids families the Cathedral's formal charity overlooks.",
        ),
        (
            "Danish King's Garden (Taani Kuninga aed)",
            "Scenic viewpoint tied to the 1219 Dannebrog legend.",
            "Private elevated garden for Danish rulers, steeped in conquest mythology.",
            "Lower-town rebels look up at the garden as a symbol of foreign rule.",
        ),
        (
            "Toompea viewing platforms (Patkuli & Kohtuotsa)",
            "Popular photo terraces overlooking the lower town and harbor.",
            "Unpaved ramparts and patrol walks on the castle's outer edge.",
            "Rebel scouts memorize sightlines from these heights before the siege.",
        ),
        (
            "Long Leg Gate (Pikk jalg värav)",
            "Steep fortified passage linking upper and lower town.",
            "Heavily guarded stone gate controlling movement between All-linn and Toompea.",
            "Kaja times courier runs when the watch changes at dusk.",
        ),
        (
            "Short Leg Gate (Lühike jalg värav)",
            "Narrow stairway between Toompea and the Dominican quarter.",
            "A tight controlled stair under castle surveillance.",
            "Mart uses the passage when monastery contacts want no Viru Gate record.",
        ),
        (
            "Toompea eastern ramparts",
            "Restored wall walks with cannon displays.",
            "Curtain walls and timber hoardings facing the lower town.",
            "Danish archers train here during the April siege alarms.",
        ),
        (
            "Toompea western slope",
            "Tree-lined paths toward the former Bishop's Garden.",
            "Open slope with orchards and service paths outside the main keep.",
            "Archbishop's household staff haul supplies along the western track.",
        ),
        (
            "Danish royal chapel site",
            "Later absorbed into castle fabric; no separate modern chapel.",
            "Small castle chapel serving the garrison and visiting envoys.",
            "Order clerics negotiate safe passage for hostages near this chapel.",
        ),
        (
            "Toompea well courtyard",
            "Paved service yard within the castle complex.",
            "Castle well and storehouses for siege provisions.",
            "Rumors of hidden grain here fuel lower-town bread riots.",
        ),
        (
            "Toompea guard barracks",
            "Administrative wings of the modern parliament complex.",
            "Timber and stone barracks for Danish household troops.",
            "Captain Henning's superiors post elite squads on the hill.",
        ),
        (
            "Toompea powder store (ruin trace)",
            "Archaeological traces inside the castle zone.",
            "Small magazine kept away from residential halls.",
            "A smith's botched hinge repair once nearly got Kalev questioned here.",
        ),
        (
            "Domberg lane houses",
            "Restored burgher houses along Toompea streets.",
            "Modest stone-and-timber homes of castle clerks and lesser nobles.",
            "Jürgen Witte courts officials who control harbor tariffs.",
        ),
        (
            "Toompea flag mast site",
            "Tall Hermann flag ceremony today.",
            "Wooden signal mast; no tall tower yet.",
            "Rebels watch whether the Danish banner is lowered during parleys.",
        ),
        (
            "Castle south gate interior",
            "Museum corridors in the parliament building.",
            "Inner gate separating keep from lower slope roads.",
            "Last checkpoint before messages reach the viceroy.",
        ),
    ],
    "Market and Civic Quarter": [
        (
            "Tallinn Town Hall (Raekoda)",
            "Iconic Gothic town hall dominating Raekoja plats, built 1402-1404.",
            "Smaller stone-and-timber hall on site since at least 1322; no later tower.",
            "Hanseatic merchants like Jürgen Witte negotiate taxes and watch contracts here.",
        ),
        (
            "Town Hall Square (Raekoja plats)",
            "Festival market and Christmas fair hub.",
            "Packed market square with stalls, pillory site, and civic announcements.",
            "Kalev collects mundane city repair commissions announced from the steps.",
        ),
        (
            "Holy Spirit Church (Pühavaimu kirik)",
            "Gothic church with a famous public clock and Danse Macabre painting.",
            "Modest chapel and almshouse recorded by 1316; no later tower or clock.",
            "Ellen Luik coordinates charity for women the almshouse turns away.",
        ),
        (
            "Town Hall Pharmacy (Raeapteek)",
            "One of Europe's oldest continuously operating pharmacies.",
            "A respected apothecary shop serving burghers and visiting merchants.",
            "Aita trades herbs here when monastery stock runs low.",
        ),
        (
            "Great Guild site (Suurgildi hoone)",
            "Monumental Great Guild Hall from 1407-1410.",
            "Wealthy merchants meet in simpler guild rooms; the later hall is not built.",
            "Jürgen Witte's faction pressures guild masters for armed escorts.",
        ),
        (
            "Brotherhood of Blackheads site",
            "Ornate Blackheads House from 1597.",
            "Young unmarried merchants organize in rented rooms; no grand house yet.",
            "Mart hears Blackhead apprentices brag about rural unrest in taverns.",
        ),
        (
            "Civic weighing house",
            "Later rebuilt; marked by guild symbols near the square.",
            "Official scales for grain and wax duties.",
            "Disputes here spark fights Henning's watch must break up.",
        ),
        (
            "Pillory and punishment post",
            "Replica on the square today.",
            "Active stocks for petty thieves and rumor-mongers.",
            "A rebel sympathizer is displayed here days before St. George's Night.",
        ),
        (
            "Merchant beer cellar row",
            "Restaurant cellars under the square fringes.",
            "Stone cellars storing Hanseatic beer and salt fish.",
            "Aita's brewery competes with imported Lübeck barrels.",
        ),
        (
            "Civic well (Raekoja)",
            "Decorative well cover on the square edge.",
            "Primary draw point for market-day water.",
            "Children spread word of rural signal fires while fetching water.",
        ),
        (
            "Vana Turg lane",
            "Tourist lane between square and east quarter.",
            "Busy cart route for inland goods entering the market.",
            "Kaja slips messages into grain sacks along this lane.",
        ),
        (
            "King's Street (Kuninga)",
            "Shops linking civic square toward the south quarter.",
            "Processional route for Danish envoys visiting the lower town.",
            "Guild banners are lowered here when Order knights ride through.",
        ),
        (
            "Harju gate approach (inner)",
            "Street opening toward the western wall.",
            "Tax checkpoint before goods leave toward Paldiski road.",
            "Smugglers test Kalev's honesty with 'scrap iron' jobs.",
        ),
        (
            "Market weighbridge lane",
            "Narrow service alley behind stalls.",
            "Clerks record Hanseatic wax and fur shipments.",
            "Jürgen Witte's ledgers hide rebel bribe lines in wax tallies.",
        ),
        (
            "Civic notice board",
            "Tourist information boards on the square.",
            "Painted ordinances on wood: curfew, grain prices, watch rotations.",
            "Mart copies watch rotations for rebel planners.",
        ),
    ],
    "North Quarter (Pikk and Merchant Street)": [
        (
            "St. Olaf's Church (Oleviste kirik)",
            "Famous spire once among the world's tallest; rebuilt after fires.",
            "Active 13th-century church; west tower and vaulting reflect 1330-era work without the later giant spire.",
            "Mart meets contacts in Oleviste courtyard to trade whispers on the rural rebellion.",
        ),
        (
            "Pikk Street (Pikk tänav)",
            "Long merchant street of guild houses and cafés.",
            "Main Hanseatic artery lined with workshops and stone merchant houses.",
            "Jürgen Witte's warehouses dominate the harbor end.",
        ),
        (
            "St. Olaf's guild workshops",
            "Craft shops in church shadow today.",
            "Metalworkers and ship chandlers under guild regulation.",
            "Kalev competes for city contracts against wealthier masters here.",
        ),
        (
            "Coastal Gate (Suur Rannavärav)",
            "Grand barbican and Fat Margaret not yet built.",
            "Primary sea gate with timber palisades and a simpler stone portal.",
            "Harbor tolls are collected here; rebel scouts note guard rotations.",
        ),
        (
            "Harbor crane site",
            "Reconstructed harbor crane.",
            "Wooden treadwheel crane unloading cogs and barges.",
            "Salt and tar from Novgorod pass through Kalev's forged hooks and chains.",
        ),
        (
            "Pikk Street salt warehouses",
            "Restored merchant storerooms.",
            "Long narrow warehouses for Hanseatic salt and herring.",
            "Kaja hides dispatches between salt barrels.",
        ),
        (
            "Ropewalk lane",
            "Harbor-side service alleys.",
            "Long ropewalk supplying ship rigging.",
            "Captain Henning requisitions rope for watch boats here.",
        ),
        (
            "Shipwright's yard",
            "Maritime museum fringe today.",
            "Boat repair slips for coastal traders.",
            "Forge nails and cleats are steady work for Kalev.",
        ),
        (
            "Novgorod merchant compound",
            "Historic trade ties marked by street names.",
            "Eastern traders maintain a fenced yard near the harbor.",
            "Language and custom friction with Hanseatic Germans.",
        ),
        (
            "Fish market landing",
            "Outdoor harbor market stalls.",
            "Morning herring and dried fish trade.",
            "Lower-town women barter news with fishermen from Viimsi.",
        ),
        (
            "Pikk Street chapel niche",
            "Small street shrine restored for tourists.",
            "Stone niche with votive candles for sailors.",
            "Sailors vow offerings if they survive spring storms.",
        ),
        (
            "Merchant counting house",
            "Banking museum sites nearby.",
            "Timber hall where factors settle letters of credit.",
            "Jürgen Witte ruins smaller rivals with delayed payments.",
        ),
        (
            "Harbor watch tower (early)",
            "Later towers rebuilt; harbor lookout remains.",
            "Low stone lookout over the roadstead.",
            "First sight of rebel campfires is reported from here.",
        ),
        (
            "Packhouse lane",
            "Service road behind Pikk frontages.",
            "Cart access for barrel and crate loading.",
            "Smuggled spearheads travel in 'empty' barrel returns.",
        ),
        (
            "Pikk Street well",
            "Covered well near guild houses.",
            "Fresh water for brewers and dyers.",
            "Aita draws water when her own well runs brackish.",
        ),
    ],
    "South Quarter (Knights and Karja Gate)": [
        (
            "Rataskaevu Street well",
            "Famous 'wishing well' on a picturesque street.",
            "Functioning public well with local superstitions.",
            "Ellen Luik hears old songs whispered here at dusk.",
        ),
        (
            "Karja Gate (Karja värav)",
            "Southern gate toward the mainland road.",
            "Active gate in the Margaret Wall controlling exodus to Harju villages.",
            "Rebel couriers test Henning's patrol gaps at Karja.",
        ),
        (
            "Knights' quarter lanes",
            "Quiet streets with craft shops today.",
            "Houses of lesser knights and armorer workshops.",
            "Order retainers demand rush repairs before the siege.",
        ),
        (
            "St. Michael's convent site",
            "Cistercian convent ruins in the south ward.",
            "Active convent precinct with church and cloister gardens.",
            "Aita trades ale for medicinal herbs from lay sisters.",
        ),
        (
            "South wall tower (early)",
            "Part of the preserved wall ring.",
            "Timber-roofed tower on the Margaret Wall.",
            "Archers rotate here when rural signal fires are reported.",
        ),
        (
            "Karja Street smithies",
            "Tourist craft quarter.",
            "Several competing smithies south of the market.",
            "Kalev undercuts rivals but refuses Order sword orders.",
        ),
        (
            "South quarter tannery row",
            "Boutiques in restored yards.",
            "Smelly but essential leather production downwind of residences.",
            "Mart hates delivering goods through the tannin stench.",
        ),
        (
            "Stable yards near Karja",
            "Hotels in converted barns.",
            "Horse hire for messengers riding to Paide and Harju.",
            "Kaja requisitions a nag for a midnight run to the rebel camp.",
        ),
        (
            "Lay brother dormitory lane",
            "Guesthouse street today.",
            "Lodging for traveling clerics and poor pilgrims.",
            "Rural priests bring word of oath gatherings in Harju.",
        ),
        (
            "South gate guardhouse",
            "Museum display of weapons.",
            "Barracks for the Karja watch shift.",
            "Henning inspects this post personally after St. George's Night.",
        ),
        (
            "Village road milestone",
            "Stone marker toward Ülemiste.",
            "Wooden post naming distances to Harju villages.",
            "Last point inside the wall where peasants may legally gather.",
        ),
        (
            "Knight's chapel (minor)",
            "Small house chapel restored.",
            "Private oratory for Order-affiliated households.",
            "Confession rumors leak to the lower town within a day.",
        ),
    ],
    "East Quarter (Lower Town East and Viru Gate)": [
        (
            "Viru Gate (Viru värav)",
            "Romantic twin towers from the 15th century.",
            "Functional gate in a shorter wall without elaborate foreworks.",
            "Captain Henning patrols this sector; Kaja smuggles messages past his watch.",
        ),
        (
            "Viru Street (Viru tänav)",
            "Shopping artery from gate to square.",
            "Busy retail lane with cloth and spice stalls.",
            "Ellen Luik buys linen here for birthing kits.",
        ),
        (
            "Eastern granary row",
            "Cafés in converted storehouses.",
            "Municipal grain stores against famine.",
            "Bread riots loom when granaries are rumored empty.",
        ),
        (
            "Viru barracks",
            "Historic guard building footprint.",
            "Barracks for the eastern watch company.",
            "Henning's sergeants drill recruits before the uprising.",
        ),
        (
            "Eastern market hall",
            "Weekend market space.",
            "Covered stalls for pottery and coarse cloth.",
            "Mart picks up gossip from upland peddlers.",
        ),
        (
            "Coopers' lane",
            "Craft shops near the gate.",
            "Barrel makers supplying brewers and shippers.",
            "Aita's brewery depends on coopers for export ale.",
        ),
        (
            "Weavers' collective yard",
            "Boutique textiles today.",
            "Shared loom house for lower-status weavers.",
            "Women trade route news while beating wool.",
        ),
        (
            "Eastern tenement courts",
            "Hostel courtyards.",
            "Dense timber housing for laborers and apprentices.",
            "Overcrowding fuels sympathy for the rural rebels.",
        ),
        (
            "Viru Gate foreland",
            "Park outside the walls.",
            "Open marshy ground before the eastern approach road.",
            "Rebel envoys camp here under truce flags during parley.",
        ),
        (
            "Müürivahe (Wall Street)",
            "Craft market along the wall.",
            "Saddlers and furriers in stalls hugging the curtain wall.",
            "Kalev buys leather here when Hanseatic stock is hoarded.",
        ),
        (
            "Eastern chapel of St. Bridget (lay)",
            "Small shrine near Viru.",
            "Lay devotional house, not the later Pirita convent.",
            "Pilgrims bring tales of burned manor houses in Harju.",
        ),
        (
            "Gate tax office",
            "Historic customs footprint.",
            "Clerks record tolls on incoming carts.",
            "Jürgen Witte bribes clerks to undervalue his imports.",
        ),
    ],
    "Monastery Quarter (Dominican and St. Catherine's)": [
        (
            "Dominican Monastery (St. Catherine's)",
            "Ruins and St. Catherine's Passage artisan workshops.",
            "Powerful active monastery (founded 1246) for education and brewing.",
            "Aita trades ale for exotic medicinal ingredients with the monks.",
        ),
        (
            "St. Catherine's Church",
            "Gothic ruin with standing walls.",
            "Convent church serving the Dominican sisters and lay students.",
            "Illuminated manuscripts copied here fetch high prices in Toompea.",
        ),
        (
            "St. Catherine's Passage (Katariina käik)",
            "Picturesque artisan alley.",
            "Covered walkway between monastery workshops and the church.",
            "Mart delivers forged hinges disguised as choir stall repairs.",
        ),
        (
            "Monastery brewery",
            "Craft beer shops nearby.",
            "Major beer production for city and export.",
            "Aita studies their recipes to keep her brewery competitive.",
        ),
        (
            "Scriptorium wing",
            "Museum displays of medieval books.",
            "Copyists produce charters and prayer books.",
            "Forged safe-conduct papers circulate from stolen blank pages.",
        ),
        (
            "Monastery herb garden",
            "Recreated garden beds.",
            "Walled garden for medicinal plants.",
            "Ellen Luik and Aita both source rare roots here.",
        ),
        (
            "St. Nicholas Church (Niguliste kirik)",
            "Art museum with Danse Macabre painting.",
            "Wealthy Hanseatic parish church, practically a fortress.",
            "Jürgen Witte stores sensitive contracts in secure crypts.",
        ),
        (
            "Niguliste merchant tombs",
            "Interior memorial slabs.",
            "Patrician burials advertising Hanseatic wealth.",
            "Kalev sees the economic divide every time he delivers church ironwork.",
        ),
        (
            "Monastery guesthouse",
            "Hotel in former monastic buildings.",
            "Lodging for traveling clerics and students.",
            "Rural deacons bring news of the Four Kings' election.",
        ),
        (
            "Lay brothers' workshop",
            "Artisan studios in monastery fringes.",
            "Wood and metal work for church maintenance.",
            "Kalev subcontracts rush jobs the monks cannot finish.",
        ),
        (
            "Convent lane drainage",
            "Cobble channels today.",
            "Open ditches carrying dye and brewery waste.",
            "Neighbors complain to the Town Hall about monastery pollution.",
        ),
        (
            "St. Catherine's well",
            "Covered well in passage.",
            "Convent water source for brewing and infirmary.",
            "A site of quiet meetings between Aita and a sympathetic lay sister.",
        ),
    ],
    "Harbor and Foreshore": [
        (
            "Great Coastal Gate descent",
            "Broad stair to the harbor.",
            "Timber ramps for rolling barrels to waiting boats.",
            "Harbor master counts every cask leaving before the siege.",
        ),
        (
            "North harbor quay",
            "Ferry terminals and museums.",
            "Working quay for coastal cogs and fishing boats.",
            "Refugees from Harju manors arrive here seeking wall protection.",
        ),
        (
            "South harbor slip",
            "Marina berths.",
            "Smaller slip for local craft and watch boats.",
            "Henning's patrol boat is hauled here for nail repairs by Kalev.",
        ),
        (
            "Customs shed row",
            "Restored warehouse cafes.",
            "Long sheds for inspecting Hanseatic manifests.",
            "Jürgen Witte's factors argue over tariff exemptions daily.",
        ),
        (
            "Harbor signal mast",
            "Flagpole for marine traffic.",
            "Mast showing wind and arrival signals for captains.",
            "A lowered flag once meant plague ships - now it means rebel galleys.",
        ),
        (
            "Boatbuilder's creek",
            "Shallow inlet filled in later.",
            "Muddy creek for caulking fishing boats.",
            "Boys fish here when watch patrols are thin.",
        ),
        (
            "Tar boiling yard",
            "Industrial heritage markers.",
            "Open yard for pine tar used on hulls.",
            "Fire risk keeps Henning's watch extra close during dry weeks.",
        ),
        (
            "Herring smokehouse",
            "Gastropub in old smokehouse.",
            "Smoking sheds for preserving catch.",
            "Protein for the wall garrison during long sieges.",
        ),
        (
            "Anchor forge outstation",
            "Maritime museum annex.",
            "Satellite smithy for large harbor ironwork.",
            "Kalev dreams of graduating from hinges to anchors.",
        ),
        (
            "Roadstead moorings",
            "Open bay view from the wall.",
            "Anchorage for larger Hanseatic cogs offshore.",
            "Merchants watch rebel fires on the mainland from their decks.",
        ),
        (
            "Harbor chapel of St. Nicholas (seamen)",
            "Small seamen's shrine.",
            "Votive altar for fishermen and cog crews.",
            "Sailors swear oaths that leak to Kaja within hours.",
        ),
        (
            "Quarantine post",
            "Historic plague controls marked.",
            "Timber hut where sick crews wait offshore clearance.",
            "Used again when rumor says rebels poison wells.",
        ),
    ],
    "City Walls, Towers, and Gates": [
        (
            "Margaret Wall (general circuit)",
            "Well-preserved medieval wall ring.",
            "Main 13th-century stone wall ordered by Queen Margaret, shorter than later rebuilds.",
            "Every tower rotation is mapped by rebel sympathizers.",
        ),
        (
            "Nunna Tower",
            "Museum tower on the southwest wall.",
            "Defensive tower with hoardings over Viru approaches.",
            "Archers' perch during the April alarm.",
        ),
        (
            "Sauna Tower",
            "Wall tower near Karja.",
            "Named for nearby bathhouses; watch post over south lanes.",
            "Henning doubles patrols here after curfew.",
        ),
        (
            "Kuldjala Tower",
            "Restored round tower.",
            "Round tower segment on the north wall.",
            "Merchants bribe guards for after-hours crane access visible from here.",
        ),
        (
            "Loewenschede Tower",
            "Wall photography spot.",
            "Tower guarding a bend toward the harbor.",
            "Weak mortar noted by rebel scouts in Kaja's reports.",
        ),
        (
            "Epping Tower",
            "Partial ruin along the wall walk.",
            "Early tower later incorporated into rebuilds.",
            "A collapsed parapet becomes a ladder point in rebel plans.",
        ),
        (
            "Harju Gate (Harju värav)",
            "Western gate toward the mainland.",
            "Gate controlling the road to Harju and Padise.",
            "Peasants flee inward when manor houses burn.",
        ),
        (
            "Lühike jalg wall bend",
            "Scenic wall curve near Short Leg.",
            "Sharp corner where attackers lose cover.",
            "Danish crossbowmen train on straw targets below.",
        ),
        (
            "Pikk jalg wall stairs",
            "Long Leg ascent.",
            "Stone stairs under constant surveillance.",
            "Smugglers rarely succeed here; Kaja uses bribes instead.",
        ),
        (
            "Wall patrol walkway",
            "Tourist path on the walls.",
            "Timber catwalk behind parapets.",
            "Watch sergeants log every lantern extinguished after curfew.",
        ),
        (
            "Moat section (east)",
            "Dry park moat.",
            "Shallow ditch, partly wet, before Viru Gate.",
            "Fills with rubbish unless cleaned before sieges.",
        ),
        (
            "Moat section (south)",
            "Grassy depression along Karja wall.",
            "Drier ditch used as vegetable plots by neighbors.",
            "Hidden caches of spear shafts buried under cabbage rows.",
        ),
        (
            "Gate portcullis groove (Viru)",
            "Visible medieval grooves.",
            "Working portcullis and murder hole.",
            "Tested weekly; rebels note the squeal of rusted chains.",
        ),
        (
            "Wall lime kiln",
            "Restoration kiln display.",
            "Kiln producing mortar for ongoing wall repairs.",
            "Kalev supplies iron fittings for the kiln winch.",
        ),
        (
            "Beacon basket site",
            "Replica signal basket.",
            "Basket for tar-soaked signals to warn of land attack.",
            "Lit on April 23 when countryside rises.",
        ),
    ],
}

ESTONIA: dict[str, list[tuple[str, str, str, str]]] = {
    "Harju County (Reval hinterland)": [
        (
            "Ülemiste Lake (Ülemiste järv)",
            "Source of Tallinn drinking water; home of the Ülemiste Elder legend.",
            "Vital freshwater lake; local belief says the lake spirit grants the city water.",
            "Site of the May 14, 1343 Battle of Sõjamäe on its shores.",
        ),
        (
            "Sõjamäe battlefield site",
            "Suburban district and memorial.",
            "Open fields and marsh edge where the main rebel army is crushed.",
            "Decisive Order victory ends the mainland rising near Reval.",
        ),
        (
            "Kanavere Bog",
            "Forested bog with a May 11 memorial.",
            "Marshland where rebels win a brief victory on May 11, 1343.",
            "Boosts rebel morale before Sõjamäe disaster.",
        ),
        (
            "Rebel signal hill (Harju)",
            "Rural lookout hills in the county.",
            "Hilltop bonfire on St. George's Night triggers the uprising.",
            "The Four Kings' election follows the first flames.",
        ),
        (
            "Harju village crossroads",
            "Modern commuter villages.",
            "Farm hamlets supplying grain and labor to Reval.",
            "Kaja's family ties make her trusted on these roads.",
        ),
        (
            "Viimsi coast",
            "Affluent seaside suburbs.",
            "Fishing hamlets and salt evaporation pans.",
            "Fish reach Reval markets within hours of catch.",
        ),
        (
            "Jägala River crossing",
            "Bridge and waterfall park.",
            "Important ford and mill sites on the road east.",
            "Rebel bands ambush Order messengers near the ford.",
        ),
        (
            "Keila stronghold site",
            "Village with manor tourism.",
            "Wooden fort and manor controlling western Harju.",
            "Local knights flee to Reval when peasants rise.",
        ),
        (
            "Harku manor lands",
            "Manor park west of the city.",
            "Agricultural estate worked by taxed Estonian families.",
            "Burned steads send refugees toward the city walls.",
        ),
        (
            "Saku forest paths",
            "Hiking trails south of Tallinn.",
            "Timber and charcoal for city forges.",
            "Hidden rebel messengers use charcoal routes to avoid roads.",
        ),
        (
            "Lake Harku",
            "Small lake and nature reserve.",
            "Fishing and reed harvesting for the capital.",
            "Ellen Luik knows old songs about lake offerings here.",
        ),
        (
            "Maardu salt marsh",
            "Industrial zone today.",
            "Coastal flats for salt and grazing.",
            "Salt pans rival Hanseatic imports when trade is blocked.",
        ),
        (
            "Lagedi manor site",
            "Rural estate ruins.",
            "Knight's holding on the road toward Viru.",
            "First manor torched in the county during the uprising.",
        ),
        (
            "Anija crossing",
            "River village.",
            "Ferry and ford on routes to the east.",
            "Rebel kings move troops across before Kanavere.",
        ),
        (
            "Raasiku woodlands",
            "Forested hinterland.",
            "Hunting preserves of the German nobility.",
            "Peasants poach deer when lords flee to castles.",
        ),
    ],
    "Northern Estonia (Viru and Lääne)": [
        (
            "Rakvere Castle",
            "Large hilltop castle ruins and theme park.",
            "Order-affiliated stronghold over Viru roads.",
            "Garrison sorties threaten rebel flanks in Harju.",
        ),
        (
            "Kunda limestone cliffs",
            "Industrial heritage and cliffs.",
            "Quarries supplying stone to Reval builders.",
            "Kalev's limestone tools come from similar beds.",
        ),
        (
            "Toolse castle ruins",
            "Coastal cliff fortress.",
            "Teutonic coastal fort watching the Gulf.",
            "Signals mirror those on Harju hills during alerts.",
        ),
        (
            "Narva River crossing",
            "Border city with Hermann Castle.",
            "Strategic ford and castle on the eastern trade route.",
            "Distant but vital for Novgorod trade rumors in Reval.",
        ),
        (
            "Padise Cistercian Monastery",
            "Large ruined abbey in forest.",
            "Wealthy monastery with farms and mill rights.",
            "Monks negotiate neutrality when peasants burn nearby manors.",
        ),
        (
            "Haapsalu Bishop's Castle",
            "Coastal cathedral and castle ruins.",
            "Seat of the Ösel-Wiek bishopric on the west coast.",
            "Clerical authority competes with Order power.",
        ),
        (
            "Paldiski coastal road junction",
            "Modern port town.",
            "Small harbor and road node west of Reval.",
            "Padise monks and merchants use this route.",
        ),
        (
            "Keila-Joa waterfall",
            "Park and manor.",
            "Mill site on the Keila River.",
            "Millers spread news faster than official riders.",
        ),
        (
            "Lahemaa forest villages",
            "National park coastal manors.",
            "Sparse hamlets under noble hunting rights.",
            "Coastal smoke seen from watchtowers warns of distant raids.",
        ),
        (
            "Käsmu captain's village",
            "Maritime museum village.",
            "Boatmen know Gulf currents and hidden coves.",
            "Fishermen bring mainland gossip to Reval harbor.",
        ),
        (
            "Vihula manor site",
            "Boutique manor hotel.",
            "Knight's economic base on the Viru road.",
            "Abandoned when serfs rise during St. George's Night.",
        ),
        (
            "Tapa crossroads",
            "Rail town today.",
            "Medieval road junction toward Rakvere and Viru.",
            "Rebel couriers choose paths here to dodge patrols.",
        ),
        (
            "Loksa coast",
            "Industrial port.",
            "Minor fishing and timber landing.",
            "Order boats resupply from here during sieges.",
        ),
        (
            "Lihula stronghold site",
            "Historic Läänemaa center.",
            "Local power center in western Estonia.",
            "Bishopric influence meets Order garrisons.",
        ),
        (
            "Noarootsi churches",
            "Swedish-era churches.",
            "Early Christian wooden churches on coastal Swedes' lands.",
            "Coastal communities hear of the uprising by boat.",
        ),
    ],
    "Central Estonia (Järvamaa and Paide)": [
        (
            "Paide Castle (Ordensburg)",
            "Tower-shaped castle in town center.",
            "Key Order stronghold in central Estonia.",
            "The Four Kings are lured here and executed under truce.",
        ),
        (
            "Paide town walls",
            "Fragments and park.",
            "Modest fortifications around the market.",
            "Refugees crowd inside when countryside burns.",
        ),
        (
            "Järva-Jaani crossroads",
            "Rural church village.",
            "Parish center on roads between Paide and Reval.",
            "Priests debate whether to bless rebel oaths.",
        ),
        (
            "Elistvere mill site",
            "Nature park.",
            "Watermill on central Estonian streams.",
            "Grain shortages reach here before city markets spike.",
        ),
        (
            "Aravete limestone quarry",
            "Quarry lakes.",
            "Building stone for churches and walls.",
            "Paused when laborers join the rising.",
        ),
        (
            "Koeru forest camps",
            "Woodland hiking.",
            "Rebel bands hide in central woods after local victories.",
            "Temporary camps feed men marching to Paide.",
        ),
        (
            "Võhma ford",
            "Small town.",
            "River crossing on southbound roads.",
            "Order patrols tax carts fleeing the rebellion.",
        ),
        (
            "Imavere manor lands",
            "Agricultural fields.",
            "Grain estates supplying Paide garrison.",
            "Torched barns signal widening unrest.",
        ),
        (
            "Roosna-Alliku chapel",
            "Village church.",
            "Wooden parish church on a hill.",
            "Bell rung backward warns villages of approaching knights.",
        ),
        (
            "Türi windmill ridge",
            "Open farmland.",
            "Windmills on a ridge visible for miles.",
            "Used as rally points when signal fires are lit.",
        ),
        (
            "Järva county sacred grove",
            "Forest hiis sites.",
            "Pre-Christian sacred groves still respected.",
            "Ellen Luik's songs reference oaths sworn at hiis stones.",
        ),
        (
            "Mäo hillfort site",
            "Archaeological hill.",
            "Ancient fort inspiring rebel leadership symbols.",
            "Invoked in speeches by the Four Kings.",
        ),
    ],
    "Southern Estonia (Tartu, Viljandi, Pärnu)": [
        (
            "Tartu (Dorpat) Cathedral Hill",
            "University town on the Emajõgi River.",
            "Bishopric town with cathedral and market; contested in 1343 unrest.",
            "News from Dorpat reaches Hanseatic merchants in Reval.",
        ),
        (
            "Tartu stone bridge site",
            "Modern bridges over Emajõgi.",
            "Wooden bridge and toll point on the east road.",
            "Controls trade between Livonia and Pskov.",
        ),
        (
            "Viljandi Order Castle",
            "Large hilltop ruins.",
            "Major Order fortress in southern Estonia.",
            "Sends knights north when Harju rebels threaten Livonia.",
        ),
        (
            "Viljandi town market",
            "Historic center festivals.",
            "Regional market for grain and livestock.",
            "Prices spike when Reval harbor is blockaded by fear.",
        ),
        (
            "Pärnu (Pernau) port",
            "Summer resort city.",
            "Hanseatic port on the southwestern coast.",
            "Alternative sea gate when Reval is unsettled.",
        ),
        (
            "Pärnu river mouth fort",
            "Coastal defense traces.",
            "Timber and earth works guarding the harbor.",
            "Bishopric and Order share garrison duties.",
        ),
        (
            "Otepää hillfort",
            "Ski resort hill with ancient fort.",
            "Strong hilltop associated with early Estonian resistance memory.",
            "Symbolic rally point for southern sympathizers.",
        ),
        (
            "Karula lakes",
            "Lake district on the Latvian border.",
            "Remote farms and fishing lakes.",
            "Far from Order centers; oaths spread quietly.",
        ),
        (
            "Võru parish churches",
            "Wooden churches in forests.",
            "Isolated parishes with late conversion.",
            "Preserve older funeral songs Ellen Luik knows.",
        ),
        (
            "Suure-Jaani church",
            "Baroque church later rebuilt.",
            "Medieval parish church in fertile Järvamaa south.",
            "Bell tower used to warn of passing knights.",
        ),
        (
            "Karksi castle site",
            "Ruins in Viljandi county.",
            "Noble stronghold overlooking the valley.",
            "Abandoned when villeins rise.",
        ),
        (
            "Halliste meadow ford",
            "Soomaa wetland edge.",
            "Marsh crossing toward Pärnu.",
            "Rebels use bog paths Order horses refuse.",
        ),
        (
            "Mooste castle site",
            "Manor ruins.",
            "Small fortified manor in southeastern Estonia.",
            "Local knight flees after St. George's Night.",
        ),
        (
            "Rõuge lake district",
            "Deep lake valleys.",
            "Remote settlements with strong local identity.",
            "Barely touched by city politics until refugees arrive.",
        ),
        (
            "Sangaste manor lands",
            "Famous barn today.",
            "Agricultural estate on southern roads.",
            "Grain requisitioned for Order campaigns.",
        ),
        (
            "Helme castle hill",
            "Ruins in Valga county.",
            "Border fortress toward Livonia.",
            "Watches roads from rebellious Harju.",
        ),
        (
            "Põltsamaa river castle site",
            "Wine manor today.",
            "River stronghold controlling central trade.",
            "Neutral ground for clergy mediating truces.",
        ),
        (
            "Emajõgi river mills",
            "Mill lines near Tartu.",
            "Milling cluster powering bishopric revenues.",
            "Idle when millers join rebel bands.",
        ),
        (
            "Vastseliina castle ruins",
            "Border castle with chapel.",
            "Eastern Livonian fortress near Pskov routes.",
            "Rumors of Russian interference pass through here.",
        ),
        (
            "Antsla valley manors",
            "Forest manors.",
            "Scattered knight holdings in Võru county.",
            "Isolated enough to survive the first April fires.",
        ),
    ],
    "Western Islands (Saaremaa and Hiiumaa)": [
        (
            "Kuressaare Castle (Arensburg)",
            "Moated bishopric castle.",
            "Seat of the Saaremaa bishop with thick walls.",
            "Island politics stay cautious while mainland burns.",
        ),
        (
            "Pöide Church fortress",
            "Fortified church ruins.",
            "Church built like a stronghold in eastern Saaremaa.",
            "Local lords shelter behind thick stone during unrest.",
        ),
        (
            "Kaali meteorite craters",
            "Unique crater field.",
            "Sacred lake and crater revered in local tradition.",
            "Folklore links fire from the sky to omen-reading before battles.",
        ),
        (
            "Angla windmill hill",
            "Restored windmills.",
            "Windmill ridge for island grain.",
            "Grain prices affect ferry traffic to Reval.",
        ),
        (
            "Kihelkonna church",
            "Medieval church with cloister.",
            "Important church controlling western Saaremaa.",
            "Records tithes that spark peasant resentment.",
        ),
        (
            "Vilsandi seal coast",
            "National park islands.",
            "Seal hunting and fishing grounds.",
            "Boats bring island news to mainland harbors.",
        ),
        (
            "Kuressaare town harbor",
            "Marina and ferries.",
            "Island port trading with Reval and Pärnu.",
            "Ferry captains spread exaggerated siege tales.",
        ),
        (
            "Maasilinn castle site",
            "Coastal ruins.",
            "Early castle site on Saaremaa.",
            "Legends of ancient kings invoked by rebel poets.",
        ),
        (
            "Kõpu lighthouse site",
            "One of the world's oldest lighthouse sites.",
            "Early navigation fire on Hiiumaa's highest hill.",
            "Guides coastal traffic around dangerous shoals.",
        ),
        (
            "Hiiumaa Käina church ruins",
            "Coastal church ruin.",
            "Parish church lost to the sea later; active in 1343.",
            "Fishermen vow saints' aid before storm season.",
        ),
        (
            "Kärdla smith tradition",
            "Town smithies.",
            "Island metalwork for ships and farms.",
            "Island smiths rival mainland prices in harbor markets.",
        ),
        (
            "Sõrve peninsula fishing villages",
            "Southern tip villages.",
            "Cod and herring fleets.",
            "First to see sails from Riga or Reval.",
        ),
        (
            "Muhu island crossing",
            "Causeway and ice roads.",
            "Ferry between Saaremaa and mainland.",
            "Strategic choke for island militia.",
        ),
        (
            "Valjala church",
            "Oldest stone church on Saaremaa.",
            "Early stone church center for the island.",
            "Baptism records prove who owes labor to bishops.",
        ),
        (
            "Lihula (Saare) manor coast",
            "Coastal farms.",
            "Bishopric farmsteads.",
            "Serfs withhold grain when mainland rebels win at Kanavere.",
        ),
        (
            "Hiiumaa Suuremõisa lands",
            "Manor park.",
            "Feudal estate on the big island.",
            "Timber for ships requisitioned during alerts.",
        ),
        (
            "Saaremaa sacred stones",
            "Coastal offering stones.",
            "Pre-Christian stones still honored.",
            "Ellen Luik's tradition of lake and stone vows extends here.",
        ),
        (
            "Panga cliff",
            "Highest Saaremaa cliff.",
            "Sacrificial cliff in folk memory.",
            "Used in stories warning against betraying oaths.",
        ),
    ],
    "Eastern borderlands and Narva region": [
        (
            "Narva Hermann Castle",
            "Russian border fortress.",
            "Teutonic castle guarding the Narva crossing.",
            "Trade envy between Reval and Narva merchants.",
        ),
        (
            "Ivangorod opposite bank",
            "Russian fortress town.",
            "Novgorod sphere settlement across the river.",
            "Smugglers move goods when Livonia is at war.",
        ),
        (
            "Lake Peipus north shore",
            "Fishing villages.",
            "Vast lake fisheries and Orthodox villages.",
            "Different faith and custom from Reval Germans.",
        ),
        (
            "Kallaste Orthodox village",
            "Old Believer heritage town.",
            "Eastern Christian fishing community.",
            "Pilgrims bring icons that fascinate lower-town children.",
        ),
        (
            "Mustvee harbor",
            "Lake harbor.",
            "Boat trade across Peipus.",
            "Grain from the east bypasses Hanseatic tolls.",
        ),
        (
            "Alutaguse forest",
            "Large forest wilderness.",
            "Hunting and beekeeping lands.",
            "Refuge for families fleeing burned manors.",
        ),
        (
            "Vasknarva castle site",
            "River castle ruins.",
            "Small fort on the Narva river route.",
            "Contested in earlier wars; garrisoned lightly in 1343.",
        ),
        (
            "Toolamaa hill villages",
            "Eastern Viru parishes.",
            "Mixed agriculture and forest.",
            "Signal fires visible to both Narva and Rakvere.",
        ),
        (
            "Agusalu marsh",
            "Wetland nature reserve.",
            "Difficult terrain slowing Order cavalry.",
            "Rebels mimic Kanavere tactics in smaller skirmishes.",
        ),
        (
            "Jõhvi parish church",
            "Later stone church.",
            "Wooden parish church serving mining and farm villages.",
            "Miners spread rumors of wealth hidden from the Order.",
        ),
    ],
    "Sacred sites, forests, and natural landmarks": [
        (
            "Sacred Grove (Hiis) near Reval south road",
            "Forest shrine marked in campaign lore.",
            "Traditional grove where oaths were sworn before Christian courts.",
            "Kalev's reflection scenes echo hiis taboos.",
        ),
        (
            "Järvi Maarja sacred spring",
            "Forest spring traditions.",
            "Healing spring in Harju woods.",
            "Ellen Luik collects water for difficult births.",
        ),
        (
            "Keila sacred grove",
            "Forest park.",
            "Hiis site west of the capital.",
            "Peasants avoid cutting timber here even when desperate.",
        ),
        (
            "Pagan burial mounds (Tarand-graves)",
            "Archaeological fields.",
            "Iron Age stone graves across Estonia.",
            "Invoked as proof Estonians held the land before knights.",
        ),
        (
            "Soomaa flooded meadows",
            "Bog walking trails.",
            "Seasonal floodplains in central Estonia.",
            "Natural barrier for rebel retreats.",
        ),
        (
            "Endla bog",
            "Large bog in central Estonia.",
            "Remote peat bog with hidden paths.",
            "Order patrols lose tracks in mist here.",
        ),
        (
            "Taevaskoja sandstone outcrop",
            "Scenic river gorge (southern Estonia).",
            "River cliffs and caves in older folklore.",
            "Storytellers link cliffs to ancient spirits.",
        ),
        (
            "Piusa sandstone caves",
            "Sandstone cliff tunnels.",
            "Wind-carved caves in southeastern forests.",
            "Shelter for fugitives after Sõjamäe.",
        ),
        (
            "Suur Munamägi hill",
            "Highest point in Estonia (Haanja).",
            "Forest hill on the Latvian border.",
            "Visibility post for distant signal fires in legend.",
        ),
        (
            "Võrtsjärv lake",
            "Large inland lake.",
            "Fishing and ferry lake in southern Estonia.",
            "Connected to Viljandi trade routes.",
        ),
    ],
}

EXCLUDED = [
    (
        "Alexander Nevsky Cathedral",
        "Built 1900 on Toompea.",
        "Orthodox cathedral absent; castle courtyard occupies the site.",
    ),
    (
        "Kiek in de Kök artillery tower",
        "15th-century cannon tower museum.",
        "Tower not built; standard curtain wall only.",
    ),
    (
        "Fat Margaret (Paks Margareeta)",
        "16th-century harbor artillery tower.",
        "Harbor barbican not yet constructed.",
    ),
    (
        "Kadriorg Palace and Park",
        "Baroque palace of Peter the Great.",
        "Forest and streams; no palace or formal park.",
    ),
    (
        "Pirita St. Bridget's Convent",
        "Ruins of a 1407 convent.",
        "Founded 1407; site is coastal forest in 1343.",
    ),
    (
        "Great Guild Hall (monumental building)",
        "Current hall from 1407-1410.",
        "Guild functions exist in simpler rooms; monumental hall not built.",
    ),
    (
        "House of the Blackheads (ornate house)",
        "Façade from 1597.",
        "Brotherhood exists; grand house not yet built.",
    ),
    (
        "Tallinn TV Tower",
        "20th-century broadcast tower.",
        "No structure; open landscape.",
    ),
    (
        "Linnahall",
        "1970s concert hall on the harbor.",
        "Rocky foreshore and working quays only.",
    ),
    (
        "Song Festival Grounds (Lauluväljak)",
        "Modern amphitheatre.",
        "Open fields outside the wall.",
    ),
]

# Default blueprint / location bindings for each catalog section.
DISTRICT_MAP_LOCATION: dict[str, str] = {
    "Toompea (Upper Town)": "`toompea_quarter` (`loc.toompea.quarter`, inactive prototype)",
    "Market and Civic Quarter": "`market_civic_quarter` (`loc.lower_town.market_civic`, inactive prototype)",
    "North Quarter (Pikk and Merchant Street)": "`north_quarter` (`loc.lower_town.north`, inactive prototype)",
    "South Quarter (Knights and Karja Gate)": "`south_quarter` (`loc.lower_town.south`, inactive prototype)",
    "East Quarter (Lower Town East and Viru Gate)": "`lower_town_slice` (`loc.lower_town.slice`, active slice); foreland `viru_gate_foreland`",
    "Monastery Quarter (Dominican and St. Catherine's)": "`monastery_quarter` (inactive prototype); playable anchors on `lower_town_slice` (`katariina_kaik`, `monastery_gate`)",
    "Harbor and Foreshore": "`reval_harbor_north`, `reval_harbor_east` (inactive harbour prototypes)",
    "City Walls, Towers, and Gates": "Wall registry on `lower_town_slice` and district prototypes (`viru_gate_arch`, `karja_gate_south`, tower IDs in `content/maps/*.rrmap`)",
}

REGION_MAP_LOCATION: dict[str, str] = {
    "Harju County (Reval hinterland)": "World-travel placeholders (`world_harju`, `world_sojamae`, `world_kanavere`) and foreland `viru_gate_foreland`",
    "Northern Estonia (Viru and Lääne)": "Distant placeholders (`world_padise`, `world_rakvere`) on the Estonia global map (`release=false`)",
    "Central Estonia (Järvamaa and Paide)": "`world_paide` placeholder and Järvamaa road nodes on the global map",
    "Southern Estonia (Tartu, Viljandi, Pärnu)": "`world_parnu` and southern placeholders on the global map",
    "Western Islands (Saaremaa and Hiiumaa)": "`world_poide` placeholder; full island campaign in Act 3 (**P6-004**)",
    "Eastern borderlands and Narva region": "Eastern global-map nodes (Narva, Peipus shore); no seamless border play",
    "Sacred sites, forests, and natural landmarks": "Foreland margins, `world_harju`, and narrative-only hiis references (**P1-037a**)",
}

# Featured tourist landmarks for quick CANON / map cross-reference (P0-113 verify).
FEATURED_LANDMARKS: list[tuple[str, str, str, str]] = [
    (
        "Toompea Castle",
        "Danish stone keep; Tall Hermann tower not built",
        "`toompea_quarter`",
        "Siege objective during [St. George's Night](./CANON.md#timeline-aprilmay-1343)",
    ),
    (
        "Tallinn Town Hall",
        "Smaller 1322-era civic hall; no 1404 tower",
        "`market_civic_quarter`",
        "Hanseatic politics via [Jürgen Witte](./CHARACTERS/jurgen.md)",
    ),
    (
        "St. Olaf's Church",
        "1330-era west tower without later spire",
        "`north_quarter` (`st_olaf_silhouette`)",
        "Mart's courtyard contacts in the catalog entry",
    ),
    (
        "Viru Gate",
        "Functional gate without 15th-century twin towers",
        "`lower_town_slice` (`viru_gate_arch`, `checkpoint_east`)",
        "[Captain Henning](./CHARACTERS/henning.md) patrol sector",
    ),
    (
        "Coastal Gate (Suur Rannavärav)",
        "Simpler stone sea gate; no Fat Margaret barbican",
        "`reval_harbor_north` (`great_coast_gate`)",
        "Harbor tolls and [Kalev](./CHARACTERS/kalev.md) forge commissions",
    ),
    (
        "Dominican Monastery (St. Catherine's)",
        "Active 1246 monastery with brewery and school",
        "`monastery_quarter`; `lower_town_slice` (`katariina_kaik`)",
        "[Aita](./CHARACTERS/aita.md) trades ale for medicinal herbs",
    ),
    (
        "Rataskaevu Street well",
        "Public well with local superstitions",
        "`south_quarter`",
        "[Ellen Luik](./CHARACTERS/ellen.md) hears old songs at dusk",
    ),
    (
        "Holy Spirit Church",
        "1316 chapel-almshouse; no public clock yet",
        "`market_civic_quarter`",
        "Ellen's charity network beside formal almshouse rules",
    ),
    (
        "Ülemiste Lake / Sõjamäe",
        "Freshwater lake and May 14 battlefield shore",
        "`world_sojamae` placeholder",
        "Attested [Battle of Sõjamäe](./CANON.md#timeline-aprilmay-1343)",
    ),
    (
        "Paide Castle",
        "Order stronghold in central Estonia",
        "`world_paide` placeholder",
        "Four Kings execution site per [canon timeline](./CANON.md#timeline-aprilmay-1343)",
    ),
    (
        "Kanavere Bog",
        "May 11 rebel victory marsh",
        "`world_kanavere` placeholder",
        "Attested [Battle of Kanavere Bog](./CANON.md#timeline-aprilmay-1343)",
    ),
    (
        "Padise Cistercian Monastery",
        "Wealthy abbey with farm and mill rights",
        "`world_padise` placeholder",
        "Neutral clergy when manors burn in Harju",
    ),
]


def count_entries() -> tuple[int, int]:
    t = sum(len(v) for v in TALLINN.values())
    e = sum(len(v) for v in ESTONIA.values())
    return t, e


def render_featured_section() -> list[str]:
    lines = [
        "## Featured tourist landmarks",
        "",
        "Quick reference for the most-visited Tallinn sites and campaign-adjacent",
        "Estonia locations. Full district catalogs follow in Parts I and II.",
        "",
        "| Landmark | 1343 snapshot | Map binding | Canon / lore |",
        "| --- | --- | --- | --- |",
    ]
    for name, snapshot, map_binding, canon in FEATURED_LANDMARKS:
        lines.append(f"| {name} | {snapshot} | {map_binding} | {canon} |")
    lines.append("")
    return lines


def render() -> str:
    t_count, e_count = count_entries()
    lines: list[str] = [
        "# Tourist Landmarks: Modern Estonia vs. 1343 Reval",
        "",
        "This document catalogs notable tourist landmarks in modern Tallinn and Estonia,",
        "mapping each to its **1343 status** during the events of *Reval Rebel*.",
        "Landmarks that did not exist in 1343 are listed only in the exclusion appendix.",
        "",
        "## Overview",
        "",
        "Each landmark includes:",
        "- **Modern Status**: Current state as a tourist destination",
        "- **1343 Status**: Historical context during the game's setting",
        "- **Map Location**: Blueprint map id, stable anchor or landmark id when authored",
        "- **Lore Tie-in**: Connection to in-game factions, characters, and map locations",
        "",
        f"**Counts:** {t_count} Tallinn landmarks grouped by district; {e_count} elsewhere in Estonia.",
        "",
        "For historical context, factions, and characters see [`docs/CANON.md`](CANON.md).",
        "For map authoring boundaries see [`docs/HISTORICAL_AUDIT.md`](HISTORICAL_AUDIT.md).",
        "",
        "---",
        "",
    ]
    lines.extend(render_featured_section())
    lines.extend(
        [
            "---",
            "",
            "# Part I: Tallinn (Reval) by District",
            "",
        ]
    )

    n = 1
    for district, items in TALLINN.items():
        map_location = DISTRICT_MAP_LOCATION[district]
        lines.append(f"## {district}")
        lines.append("")
        lines.append(f"*District map binding:* {map_location}")
        lines.append("")
        for name, modern, status, lore in items:
            lines.append(f"### {n}. {name}")
            lines.append(f"* **Modern Status:** {modern}")
            lines.append(f"* **1343 Status:** {status}")
            lines.append(f"* **Map Location:** {map_location}")
            lines.append(f"* **Lore Tie-in:** {lore}")
            lines.append("")
            n += 1

    lines.extend(
        [
            "---",
            "",
            "# Part II: Rest of Estonia",
            "",
        ]
    )

    m = 1
    for region, items in ESTONIA.items():
        map_location = REGION_MAP_LOCATION[region]
        lines.append(f"## {region}")
        lines.append("")
        lines.append(f"*Region map binding:* {map_location}")
        lines.append("")
        for name, modern, status, lore in items:
            lines.append(f"### {m}. {name}")
            lines.append(f"* **Modern Status:** {modern}")
            lines.append(f"* **1343 Status:** {status}")
            lines.append(f"* **Map Location:** {map_location}")
            lines.append(f"* **Lore Tie-in:** {lore}")
            lines.append("")
            m += 1

    lines.extend(
        [
            "---",
            "",
            "# Appendix: Excluded Modern Landmarks (not present in 1343)",
            "",
            "These popular tourist sites are **omitted** from the main catalog because",
            "their current buildings or uses did not exist in 1343. Where a guild or",
            "institution existed in simpler form, see the district entries above.",
            "",
        ]
    )
    for name, modern, status in EXCLUDED:
        lines.append(f"- **{name}** - {modern} **1343:** {status}")
        lines.append("")

    return "\n".join(lines)


def main() -> None:
    t, e = count_entries()
    if t < 95:
        raise SystemExit(f"Tallinn count too low: {t}")
    if e < 95:
        raise SystemExit(f"Estonia count too low: {e}")
    OUT.write_text(render(), encoding="utf-8")
    print(f"Wrote {OUT} ({t} Tallinn + {e} Estonia landmarks)")


if __name__ == "__main__":
    main()
