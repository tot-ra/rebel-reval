# Harju Village and Countryside (Harria / Harrien, Rävala)

**Status:** planned (design proposal, not implemented) · **Scope gate:** existing prototype `loc.world_harju` (core); optional sub-zones are `new (needs ADR + task)` · **Act(s):** 1 (end), 2, 3
**Map id:** `loc.world_harju` (built as the 700 m regional site `scenes/world/sites/harju.tscn`, see [`REGIONAL_SITES.md`](../SYSTEMS/REGIONAL_SITES.md), R-1527; the 52x30 `world_harju.rrmap` greybox is retired) · **Seasons/phases:** spring 1343 (pre-23 Apr boon-day phase; 23 Apr-14 May burned-manor and refugee phase; post-Sõjamäe punitive phase); Act 3 reconstruction under Order-enforced dues, 1343-1346
**Confidence summary:** settlement form, dues and field economy `attested` framework; farm graph, facades and the manor node `plausible composite`; signal hill, hamlet names and every named NPC `invented`; folk belief `folklore`.

## 1. Why a player would want to visit

- It is the ground the rising grows from: the player sees the grievance (boon-day labour, last stored grain, a levy cart) before the fire, then sees the same lane after the fire.
- It is the first node with no stone at all: smoke-blackened log, thatch, mud, strips and cattle. After the Lower Town's limestone and brick, the contrast is the point.
- The language flips. Estonian is the home tongue on the lane; Low German is a tool spoken at the manor gate and by the reeve; Swedish and Finnish are heard on the shore sub-zone. Under ADR 0033 foreign speech is imagery until comprehension grows, so the player literally hears the hierarchy.
- Optional sub-zones reward wandering: a Jägala ford ambush, a manor yard with a stone cellar, a Viimsi fishing hamlet where fish reach Reval within hours of the catch ([`TOURIST_LANDMARKS.md`](../TOURIST_LANDMARKS.md) Part II, rows 6, 7, 9).
- **Signature:** the compact cluster village in mud season - a knot of low long-roofed log farms, split strips beyond, a well and a muddy common - with the same lane readable in three states (working, burned, occupied).

## 2. History in 1343

| Claim | Label | Source | Use |
|---|---|---|---|
| North Harju villages are compact clusters with open strips, not street rows | `attested` framework | [harju-village-and-manor](../../history/dossiers/hinterland/harju-village-and-manor.md) | Cluster of 3-6 farms; built share 8-18 % |
| Tax unit `vakus` (Low German *wacke*), ~30 ploughlands (*adramaa*) in the Liber Census Daniae | `attested` | same | Dialogue vocabulary only; no measured plot map |
| ~21 attested fiefs in Harria before 1343, densest in Estonia | `attested` | same (Moisio) | Manor node 1-2 km off the village |
| Tithes, rent in kind, corvée (*rüüt*), extraordinary crown taxes 1340-1343 | `attested` (taxes), `plausible composite` (about 2 days/week) | same | Boon-day quest, levy cart |
| Rising is multi-status (freeholders, elders, vassal clients, manor labourers), not pure peasant | `attested` scholarship | same | Mixed crowd, no uniform costume |
| Signal fire on a Harria hill on 23 Apr | `attested` event; hill unnamed | [rebel-camp dossier](../../history/dossiers/hinterland/harju-rebel-camp-and-pirita-approach-1343.md) | Hill is an `invented` anchor |
| Manors destroyed so thoroughly the fief count does not recover until the 15th c. | `attested` | harju-village-and-manor | Burned-manor phase |
| Serfdom juridically complete | NOT 1343 (15th-17th c.) | same | Never say "serf" as a legal status |
| Jägala ford, mill sites on the road east | `plausible composite` | [`TOURIST_LANDMARKS.md`](../TOURIST_LANDMARKS.md) Part II row 7 | Optional ford encounter |
| Salt pans on the Maardu/Viimsi coast | `invented` (doubtful) | contradicts [kalamaja dossier](../../history/dossiers/topography/kalamaja-fishing-shore-1343.md): salt there is imported Hanseatic stock | See section 3 sub-zone C; flagged in section 10 |

**Phases.** (A) to 22 Apr: boon day, ploughing, lambing, Lent tail, St George's feast eve. (B) 23 Apr-13 May: manor yard burned or looted, German refugees on the road, rebel recruiters, hidden grain. (C) after 14 May: Order columns and a punitive levy; roofs burned, strips unsown; (Act 3) thin re-sowing, Order-enforced dues.
**Do not show:** a plastered Baltic-German manor palace, 19th-c. *mõis* park, Lutheran church, street-row village, chimneys on peasant roofs, glazed windows, chamber rows (*kambrid*; first evidence early 17th c.), tidy "museum" farms copied from the Open-Air Museum, the high-thatched three-part *rehielamu* with chambers and the 18th-19th c. buildings of the Open Air Museum as 1343 forms, a tight street of houses touching each other.

## 3. Landscape and layout

Biome: rolling north Estonian farmland on glacial till, limestone close to the surface, birch/alder/spruce edges, wet meadow. Weather band per [spring-climate](../../history/dossiers/nature/spring-climate-and-living-world.md): 8-14 C, wind, mud, pale green leaf-out, last year's hay stacks.

| Zone | Cells (x,y,w,h) | Prototype id | Notes |
|---|---|---|---|
| West strips | 2,2,15,9 | `west_fields` | Ploughing in progress, rye/barley stubble greening |
| Elder farmstead yard | 16,5,14,7 | `elder_yard` | Barn-dwelling, root-cellar mound, cart |
| Threshing yard | 29,6,13,7 | `barn_yard` | Rehi (threshing barn) beside the elder's house |
| East strips | 35,3,14,8 | `east_fields` | Split strips; `landmark_split_fields` |
| Village spine road | 0,13,52,5 | `village_road` | Packed earth; exits W and E |
| Well and common | 20,16,8,4 | `muddy_common` | `landmark_village_well`; mud, geese |
| West croft | 4,18,12,5 | `croft_yard` | Smoke cottage, kitchen garden |
| Hay meadow | 4,23,10,5 | `hay_field` | Three hay ricks |
| Pasture | 28,21,14,6 | `cattle_fence` | Cattle, sheep, palisade |
| East wood | 43,18,9,12 | `east_wood` | Birch/spruce edge; hiding place |

Landmarks (existing ids kept): `landmark_village_well` (25,15), `landmark_threshing_barn` (35,12), `landmark_split_fields` (42,6). Proposed additions (stable ids new, `invented`): `landmark_signal_hill_view` (view only, hill is off-map east, a long glow on the horizon in phase B), `landmark_wayside_cross` (a roadside timber cross at the west exit; Christian marker in a rural setting, `plausible composite`).

**Journey edges (existing, all `alignment=travel`):** `road_to_reval` (0,13) to `viru_gate_foreland`; `road_to_sacred_grove` (16,26); `road_to_rebel_kings` (48,7); `road_to_kanavere` (48,20); `road_to_sojamae` (27,0). ADR 0027 moves `world.harju` and `world.sojamae` into the seamless `reval_hinterland` group once UF-15 authors the connectors ([ADR 0027](../adr/0027-reval-hinterland-streaming-group.md)); the Viru side then becomes a width-matched road seam via `viru_approach_road`. The other four exits stay explicit journeys.

**Optional sub-zones (Scope gate: new).** Each is a bounded inset, not a district, and must stay at world-node scale (46-110 cells wide):

| Id (proposed) | Form | Size | Pays for itself by | Cost offset |
|---|---|---|---|---|
| A. `loc.world_harju_manor` manor yard | Timber palisade yard, stone cellar and chapel, mill, granary; burned in phase B | 48x28 | Gives phase B a destination and the Rehepapp heist a target | Could be folded into the NE 16x10 corner of the existing map instead (shrink `east_fields`); names the cheaper option |
| B. Jägala ford | Road-and-water crossing event on the Viru-Iru axis | edge event, no map | Ambush of Order messengers ([`TOURIST_LANDMARKS.md`](../TOURIST_LANDMARKS.md) row 7) | Reuse the invented-crossing primitive from the Pirita dossier |
| C. `loc.world_viimsi_coast` fishing hamlet | Beach landings, net yards, smoke and salt sheds, 2-4 huts | 60x26 | Swedish/Finnish speech, fish-to-Reval clock; shares the shore kit with `reval_harbor_east` | Replaces planned connector `kalamaja_hinterland` stub with a real destination, not an addition to it |

## 4. Architecture and built environment

| Type | Form | Materials | State by phase | Label |
|---|---|---|---|---|
| Smoke cottage (*suitsutuba*, small) | One heated room, corner stone oven, no chimney, one low boarded door, no windows | Horizontal round logs, split-board or thatch roof | A: smoke at the door; C: collapsed ridge | `plausible composite` (matches `smoke_cottage_1343` style) |
| Smoke-room dwelling (*elurehi*, the 1343 stage of the *rehielamu*) | Heated smoke room (*rehetuba*) with a stone heap oven that also dries the grain, plus a threshing anteroom under the same roof; low door with a high sill | Log, low split-board roof under birch bark (about 30 degrees), limestone-slab or rammed-earth floor | Every farmstead (built: R-1627, walk-in and furnished); B: grain hidden in the floor | `plausible composite` (Lavi 2001; the high-thatched three-part *rehielamu* is 15th-17th c.) |
| Threshing barn (*rehi*) | Double-gated, smoke-dark | Log, thatch | A: flail work; B: cart staging | `plausible composite` (matches `rural_barn_1343`) |
| Root cellar mound, granary stilt-store | Earth-covered cellar; raised store on stone pads | Turf, log | Hiding place | `plausible composite`; mound already in `assets/props/environment/root_cellar_mound` |
| Cattle pen, wattle and palisade fences | Low palisade, wattle field edges | Split stakes, withies | B: gaps cut by raiders | `plausible composite` |
| Well with sweep | Timber frame, bucket | Oak, rope | Poisoned-well rumour hook | `plausible composite` |
| Wayside cross, village chapel | Timber cross; chapel only at the parish centre, not every hamlet | Timber (stone later) | - | `plausible composite` |
| Manor yard (sub-zone A) | Palisaded timber yard, stone cellar or short tower, granary, mill, chapel | Timber, limestone cellar | A: boon day; B: burned, dead livestock props; C: Order garrison tent | `plausible composite`; no baroque wings |

Distinguishing rule vs other nodes: no stone above the foundation, no plaster, low log walls under low board-and-bark roofs, smoke at doors and eaves, farmsteads spread round their own yards. (Earlier drafts asked for very high thatch; that roof spreads only from the 15th-16th c., R-1627.) Padise (stone) and Paide (Order castle) are the stone counter-examples; do not use their kits here.

## 5. Cultures, languages, and people

| Group | Language (in-game voice) | Dress | Religion and custom |
|---|---|---|---|
| Estonian freeholders, bound tenants, elders | North Estonian rural dialect, forename + patronymic (*poeg* / *tütar*), no hereditary surnames before c. 1380; saints' names (Jüri, Mart, Ell) plus older Finnic names | Wool and linen, bare legs in mud, wooden or bark shoes, headscarf or bare head; no knightly kit | Baptized, practise household rites (first cup under the threshold, rowan over the stable) - `folklore` |
| German vassal household, reeve, bailiff | Middle Low German; address *Herr* | Mid-calf tunic, hose, belted purse, fur only for the lord | Latin Mass in the chapel; call rural rites superstition |
| Danish crown official (rare) | Old Danish/Latin, mostly by interpreter | Better wool, cloak pin | Tax collection |
| Priest of a nearby parish | Latin; Estonian pastoral speech; sympathetic or fearful | Plain cassock | Tithes; conflicted loyalty |
| Swedish and Finnish fishermen (sub-zone C) | Swedish dialect and Finnish; Estonian pidgin for trade; Low German with buyers | Tarred boots, wool layers, boat-master's better cap | Baptized; sea-spirit (*vetevana*) and luck rites - `folklore` |
| Rebel recruiters, runaways, refugees | Estonian; Low German widows in phase B | Mixed | - |

Oaths and names follow [names-address-and-oaths](../../history/dossiers/language/names-address-and-oaths.md) and [estonian-forenames-harju-1340s](../../history/dossiers/language/estonian-forenames-harju-1340s.md); use German-record spellings only in Latin/German text. Swedish presence on this particular shore is `plausible composite`: Kalamaja is the attested Swedish/Finnish fishing area (names from 1352), Viimsi-specific settlement in 1343 is unverified.

## 6. Factions present

| Faction id | Presence here | Wants | Where | Act-by-act |
|---|---|---|---|---|
| `harju_kings` | Strong; recruiters, couriers, hidden stores | Men, grain, silence | Elder farmstead, east wood | A1 rumour; A2 open host staging; A3 survivors, safe lofts |
| `danish_crown` | Weak, tax collectors | Extraordinary levy collected | Road, manor gate | A1 levy cart; A2 gone; A3 absent (sold 1346) |
| `livonian_order` | None until May | Suppress, then hold | East road, manor yard | A2 appears after 11 May; A3 garrison dues |
| `cult_metsik` | Quiet household web | Keep the grove reachable | Croft, well, east wood | A1 offerings; A2 grove route; A3 persecuted |
| `hanseatic` | Marginal (levy buyers, fish buyers) | Grain, herring | Road, coast | A1 buyers; A2 grain levy 11 May |
| `church` (candidate affinity) | Parish priest, tithes | Tithe, obedience | Chapel, cross | Torn loyalty |
| `vitalienbruder` | None | - | - | - |

## 7. Characters

| char id | Name | Role / faction | Language | Confidence | Source | Hook / quest use |
|---|---|---|---|---|---|---|
| `char.lembit_helme` | Lembit Helme | Village elder, later Elder King, `harju_kings` | Estonian; Low German only as a tool | `plausible composite` | Existing brief [`lembit.md`](../CHARACTERS/lembit.md); legacy [`harju_village.md`](../../scenes/world/harju_village.md) | Fire Sermon; King's Council |
| `char.kaja` | Kaja | Bilingual courier | Estonian, High/Low German | `invented` | [`kaja.md`](../CHARACTERS/kaja.md); legacy [`kaja_lahekivi.md`](../../characters/rebels/kaja_lahekivi.md) | Trusted on these roads; carries the boon-day warning |
| `char.ell` | Ell | Miller's wife on the Harju road, Metsik thread | Estonian | `plausible composite` | Citizen card [`ell.md`](../CITIZENS/people/harju_road/ell.md) | Takes the player to the oak at new moon |
| `char.veronika` | Veronika | Drover, Harju Kings courier | Estonian | `plausible composite` | Citizen card [`veronika.md`](../CITIZENS/people/harju_road/veronika.md) | Cattle-road information; hidden-grain route |
| `char.mari` | Mari | Ostler, Metsik cell | Estonian | `plausible composite` | Citizen card [`mari.md`](../CITIZENS/people/harju_road/mari.md) | Carters' gossip, ford rumours |
| `char.rehepapp_harju` | Rehepapp | Barn-keeper who feeds the village from the manor granary | Estonian | `invented` (from `folklore` archetype) | NEW; [`estonian_folklore.md`](../lore/estonian_folklore.md) F-3 | Granary heist, kratt upkeep |
| `char.reeve_hinrik` | Reeve Hinrik | Estonian reeve in German service | Estonian, Low German | `invented` | NEW | Corvée dispute; the man between |
| `char.bertold_wulf` | Bertold Wulf | German vassal of the manor | Low German | `invented` | NEW (no real family name used) | Phase A boon day; phase B refugee or corpse |
| `char.vassal_widow_gese` | Gese Wulf | Refugee German widow | Low German, some Estonian | `plausible composite` | NEW | Post-23 Apr road scene; no villain-or-victim flattening |
| `char.priest_parish_harju` | Sir Johannes | Parish priest | Latin, Estonian | `invented` | NEW; legacy "priest from a nearby parish" | Torn between tithe and flock |
| `char.boat_master_anders` | Anders | Swedish boat master (*mündrik*) | Swedish, Estonian pidgin | `plausible composite` | NEW; cf. [`gunnar_bengtsson.md`](../CITIZENS/people/kalarand/gunnar_bengtsson.md) | Coast sub-zone; fish clock |
| `char.salt_boiler_aino` | Aino the salt-boiler | Runs the failing boiling shed | Finnish, Estonian | `invented` | NEW | Salt-pan economics quest |

Crowd archetypes: plough-team ox driver; woman at the well with a wooden pail; goose-girl on the common; hay-rick forker; refugee carter with a German family; Swedish net-mender; Finnish ferryman at the ford.

## 8. Quests, encounters, and discoveries

| Id (proposed) | Act | Type | Hook | Ties |
|---|---|---|---|---|
| `quest.boon_day` | 1 end | Investigation | A corvée dispute turns on who counted the days; evidence in the reeve's tally sticks | `flag.manor_oppression` (0-5 track from dossier, proposed) |
| `quest.hidden_grain` | 2 | Exploration | Find which root cellar the levy cart will miss | `mission.act2.travel.harju_village` |
| `quest.rehepapp_granary` | 2 | Night mission | Feed a kratt, rob the manor granary, keep it busy | [`estonian_folklore.md`](../lore/estonian_folklore.md) F-3 |
| `quest.jagala_ford` | 2 | Travel event | Order courier ambush; stop it, mark it, or warn the courier | `mission.act2.travel.harju_camp` |
| `quest.wrong_levy_cart` | 2 | Forge commission | Re-iron a cart axle for a levy that the village does not mean to deliver | Forge loop; `quest.stolen_iron` echo |
| `quest.katk_at_the_ford` | 2-3 | Spirit-world | A blue-eyed stranger begs passage; ferry, trick or refuse (F-5) | Ellen branch |
| `quest.fish_clock` | 2 | Travel event | Get boats to Reval's market before the Lent catch spoils, while Order patrols close the road | Coast sub-zone |

Sights (journal entries): (1) why the roof is taller than the wall, and why the room is dark; (2) the *vakus* and ploughland count, told by the elder; (3) a barn-dwelling threshing floor with a drying kiln; (4) a boundary stone attributed to a giant (*folklore*, Kalevipoeg stone-throws); (5) where the signal hill glows from, framed as "no one agrees which hill" (`invented` anchor, honestly marked).

## 9. Resources: what must be generated

### 9.1 Structures and architecture
| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.kit.log_farmstead` | Barn-dwelling, smoke cottage, rehi, root-cellar mound; wall/roof/gate modules; defined here | P1 | [`rebel_kings_camp.md`](rebel_kings_camp.md), [`kanavere_bog.md`](kanavere_bog.md) (huts), [`sacred_grove.md`](sacred_grove.md) (hermit shelter) | [rural-smoke-dwelling dossier](../../history/dossiers/architecture/rural-smoke-dwelling-and-farmstead-1343.md); existing styles `rural.barn_dwelling`, `rural.smoke_cottage`, `rural.barn` |
| `asset.kit.timber_manor_yard` | Palisade segments, gate, stone cellar, granary, small chapel, mill | P2 | `rebel_kings_camp` (burned manor view) | Moisio fief density; no baroque wings |
| `asset.kit.burn_state_thatch` | Collapsed-thatch and blackened-log damage variants for all farm modules | P1 | `sojamae`, `kanavere_bog` | Required for phases B/C |
| `asset.kit.fishing_hamlet` | Huts, net frames, smoke and salt sheds, boat cradles; reuses `asset.kit.fish_rack_town` (defined in [`haapsalu_laanemaa.md`](haapsalu_laanemaa.md)) for racks | P2 | `reval_harbor_east` shore | Walraversijde plate in the Kalamaja dossier |
| `asset.kit.ford_and_timber_footbridge` | Reversible `invented_reconstruction` crossing | P3 | `rebel_kings_camp` (Pirita) | Mark `crossing_status: invented_reconstruction` |

### 9.2 Props and craft objects
| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.kit.haystack_on_poles` | Cited, defined in [`soomaa_flood_refuge.md`](soomaa_flood_refuge.md); hay-rick variants `.tall`, `.medium`, `.small` match the greybox | P2 | Soomaa | Existing `hay_stack` primitive |
| `asset.prop.field_strip_set` | Ridge-and-furrow strips, stubble, sprouting rye | P1 | `sojamae` | Existing `field_strip` primitive |
| `asset.prop.wooden_plough_ard` | Light ard plough with iron share, ox yoke | P1 | none | Tacuinum Sanitatis plate (c. 1400, comparandum) |
| `asset.prop.flail_and_winnowing_set` | Flail, wooden shovel, winnowing tray, threshing sheaves | P2 | none | Dossier: rehi use |
| `asset.prop.kerchief_and_hand_spindle` | Spindle, distaff, wool baskets | P2 | `kanavere_bog` | Textile craft sight |
| `asset.prop.levy_cart` | Heavy two-wheel levy cart with sacks, tally sticks | P1 | [`rebel_kings_camp.md`](rebel_kings_camp.md) | Reuse `wooden_cart.glb` base; refugee variant is `asset.prop.refugee_bundle_cart` ([`paide_castle.md`](paide_castle.md)) |
| `asset.prop.household_offering_set` | Threshold bread, first-cup bowl, rowan twig, knotted net-thread | P2 | [`sacred_grove.md`](sacred_grove.md) | Cult of Metsik citizen cards |
| `asset.prop.salt_boiling_pan` | Iron pan on stone hearth, wood piles, ash heaps (doubtful use) | P3 | none | Section 10 flag |
| `asset.prop.fish_drying_rack` | Racks with split herring, barrels | P2 | `reval_harbor_east` | Kalamaja dossier |
| `asset.prop.wayside_cross` | Timber cross, small offerings; same object as `asset.struct.wayside_cross_wood` in [`rakvere_wesenberg.md`](rakvere_wesenberg.md) (dedupe in hub pass) | P2 | all rural nodes | `plausible composite` |

### 9.3 Characters
Wardrobe ids follow the hub ([`CULTURES_AND_LANGUAGES.md`](CULTURES_AND_LANGUAGES.md) Table B); this page adds variants only.
| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.wardrobe.harju_peasant` | Hub id (cited). Variants proposed here: `.mud`, `.burn_soot`, `.boon_day_work`, child, elder; wool kirtle, apron, bast shoes, headband, bronze brooch | P1 | all five Harju-group pages | Shared rig + MPFB ([`CHARACTER_GENERATION.md`](../CHARACTER_GENERATION.md)) |
| `asset.wardrobe.knight_vassal` | Hub id (cited). German vassal household variant `.household_reeve`, `.bailiff` | P1 | [`sojamae.md`](sojamae.md) | Fur only for lords |
| `asset.wardrobe.swedish_coast_man`, `swedish_coast_woman`, `finnic_trader` | Hub ids (cited) for the Viimsi sub-zone; add `.boat_master` cap variant | P2 | [`baltic_klint_coast.md`](baltic_klint_coast.md) | Kalamaja dossier |
| `asset.hair.rural_set` | Braids, unshaved beards, elder white beard, child bowl cut | P1 | all | Lembit visual brief |
| `asset.wardrobe.parish_priest_plain` | Plain cassock, rope belt | P3 | [`padise_monastery.md`](padise_monastery.md) | - |

### 9.4 Fauna
| Species | Id | Status | Notes |
|---|---|---|---|
| Cattle, sheep, pig, goose, chicken, duck, horse, dog | `fauna.cow`, `fauna.sheep`, `fauna.pig`, `fauna.goose`, `fauna.chicken`, `fauna.duck`, `fauna.horse`, `fauna.dog` | cataloged | Lambing and calving young as variants |
| Draught ox | `fauna.ox` (proposed) | missing | Yoked cow-body variant with horn set; ox-plough team prop; P2 |
| Domestic goat | `fauna.goat` | missing (hub list, P2) | See [`BIOMES_AND_WILDLIFE.md`](BIOMES_AND_WILDLIFE.md) |
| Skylark, lapwing, rook, jackdaw, barn swallow (late Apr) | `bird.*` | cataloged | Meadow soundscape |
| White stork | `bird.white_stork` | missing (hub list, P1) | Arrives mid-April, nests on high farm trees |
| Herring, bream, pike | `fish.baltic_herring`, `fish.bream`, `fish.pike` | missing (hub list, prop-first, P2) | Market and rack props, not swimming agents |

### 9.5 Flora and ground cover
Existing: `crop.rye`, `crop.barley`, `crop.oat`, `crop.flax`, `crop.hemp`, `crop.pea`, `tree.birch`, `tree.alder`, `tree.spruce`, `tree.rowan`, `tree.hazel`, `tree.juniper`, `plant.nettle`, `plant.dandelion`, `plant.clover`, `bush.dog_rose`, `bush.juniper_shrub`, `grass.*`. Missing (hub ids, P2): `plant.coltsfoot`, `plant.wood_anemone`, `plant.cowslip`; proposed here: `tree.willow_pollard` (catkins, pollarded for wattle). P3: wooded-meadow (*puisniit*) cover mix, see hub biome 12.

### 9.6 Materials, terrain, water
`asset.mat.smoke_blackened_log`, `asset.mat.thatch_weathered_rye`, `asset.mat.wattle_withy`, `asset.mat.till_mud_wet` (shared with `rebel_kings_camp`), `asset.mat.burnt_thatch_ash`; terrain `farm_soil`, `mud`, `dirt`, `hay` exist in the rrmap; add `asset.terrain.ridge_furrow` (P2; cited by other Harju-group pages). Water: ford shallows, spring-flooded ditch (P3).

### 9.7 Audio and music direction
Ambient: wind in thatch, cattle lowing, axe on wood, cartwheels in mud, rooks, skylarks, wooden pail on well chain, geese. Languages: Estonian dialect on the lane (home tongue), Low German at the manor gate (clipped, commanding), Swedish/Finnish on the shore, Latin at the wayside cross. Music: sparse, sung rather than played - *regilaul* (rural runic song, `folklore`/`plausible composite`, rural scenes only, per [music dossier](../../history/dossiers/culture/music-and-instruments.md)); horn shouts for mobilisation in phase B; no organ, no town pipers. Legacy "bagpipes and kannel" in the 2D roster are unverified for 1343 and not adopted.

## 10. Variety signature and risks

- **Palette:** peat-dun, smoke-brown, thatch gold-grey, mud umber, first-leaf pale green; warm and low.
- **Silhouette:** long horizontal ridges with huge roofs on low walls; no vertical accents but a well sweep and a timber cross.
- **Soundscape:** livestock, wind, voices in a language the town player must learn to read; singing rather than instruments.
- **Risks:** (1) anachronism - museum-farm facades, chimneys, windows; (2) scope - sub-zones A and C are new maps and need an ADR and an equivalent-cost offset; (3) sensitivity - chronicle claims of sexual violence and massacre are hostile-source `attested`; show consequences, not spectacle; keep Germans as people (refugees); (4) performance - strips and thatch are cheap, but burned variants double the farm kit; (5) ADR 0027 will make this node seamless from the Viru side, so the western edge must be a width-matched road, not a loading door.
- **Flags for the maintainer:** (a) `TOURIST_LANDMARKS.md` lists "salt evaporation pans" at Maardu; the Kalamaja dossier says Reval salt is imported - the pans are shown only as an `invented` failing shed; (b) legacy Kaja is a noble's daughter, the active brief is a bilingual courier; (c) one dossier ([forenames](../../history/dossiers/language/estonian-forenames-harju-1340s.md)) writes the uprising as "13 April"; CANON says 23 April.

## 11. Sources and next steps

Repo: [`REGIONAL_SITES.md`](../SYSTEMS/REGIONAL_SITES.md) (the built site), [`harju_1343_overlay.json`](../../tools/city/sites/harju_1343_overlay.json), [`scenes/world/harju_village.md`](../../scenes/world/harju_village.md) (legacy), [`global_map_mockups.md`](../reports/global_map_mockups.md), [`CANON.md`](../CANON.md), [`FLORA_FAUNA.md`](../FLORA_FAUNA.md), [`ADR 0027`](../adr/0027-reval-hinterland-streaming-group.md), [`ADR 0033`](../adr/0033-teen-protagonist-and-spirit-dialogue-combat.md), dossiers cited above. External, by name: Liber Census Daniae, Moisio on Harria fiefs, Estonian Open-Air Museum rehielamu comparanda (18th-19th c.), Tacuinum Sanitatis.
Verification tasks: (1) confirm Swedish/Finnish presence on the Viimsi shore in the 14th c.; (2) decide sub-zone A as inset or map; (3) review the burn-state kit budget; (4) check `flag.manor_oppression` against the quest id registry; (5) run the map-authoring gate if a blueprint is added ([`MAP_AUTHORING.md`](../MAP_AUTHORING.md)).
