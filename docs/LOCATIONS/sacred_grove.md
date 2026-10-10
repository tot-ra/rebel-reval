# The Sacred Grove (Hiis, Metsik's oak)

**Status:** planned (design proposal, not implemented) · **Scope gate:** existing prototype `loc.world_sacred_grove` · **Act(s):** 2 (`mission.act2.travel.sacred_grove`, investment phase), 3 (persecution and winter variant); an optional Act 1 glimpse via Ell and Mari
**Map id:** `loc.world_sacred_grove` (regional site, 500 m: [`scenes/world/sites/sacred_grove.tscn`](../../scenes/world/sites/sacred_grove.tscn) from [`content/world/sacred_grove/plan.json`](../../content/world/sacred_grove/plan.json), ADR 0042, R-1529; the 64x36 `world_sacred_grove.rrmap` greybox is retired and the landmark list below is design history) · **Seasons/phases:** April bare oak and wood anemone; May leaf flush; Act 3 winter (frost-white moss, black oaks)
**Confidence summary:** the existence of sacred groves (*hiis*, *lucus sanctus*) `attested`; offering customs `plausible composite` (18th-c. ethnography projected back); every named spirit, the Cult's organisation, Ellen at the grove, Hingepuu link and the grove's position `invented` or `folklore`.

## 1. Why a player would want to visit

- It is the quietest place in the game: no bells, no hammers, no crowds. After the Lower Town and the camp, the player arrives in near silence under oaks that are not yet in leaf.
- It is where the game's inner world touches the outer one. The ancient oak is the real tree that the Hingepuu hub (the forge-hub reflection space, `invented`/`folklore` per [`CANON.md`](../CANON.md)) is modelled on; the clairvoyant Apprentice can see the same crown in both.
- It lets the player see the Cult of Metsik as people, not villains: a web of households with bread, wool and a knotted thread, not a coven and not a state.
- The spring pool on the bog edge gives a folk-Christian overlap (an offering spring re-named for the Virgin) that the player can read as holy, criminal or diabolical depending on who is looking ([`belief-omens-and-healing.md`](../../history/dossiers/folklore/belief-omens-and-healing.md)).
- **Signature:** a vertical, green-black node of oak columns and moss around one colossal crown, soundscape of wind, water and near-silence - the only place with no visible human building at all.

## 2. History in 1343

| Claim | Label | Source | Use |
|---|---|---|---|
| Sacred groves existed and were sites of offering and assembly (Tharapita grove, 1220) | `attested` | Henry of Livonia, via [`belief-omens-and-healing.md`](../../history/dossiers/folklore/belief-omens-and-healing.md) | Anchor for "hiis" |
| A *lucus sanctus* near "Wærkæla" in the Liber Census Daniae (1241); identification disputed | `attested` wording; place `plausible composite` | [`harju-hiis-sites-within-walk-1343.md`](../../history/dossiers/folklore/harju-hiis-sites-within-walk-1343.md) | Never a surveyed polygon |
| Iru, Rebala-Maardu, Saha are archaeological candidates within a day's walk | `plausible composite` | same | Rumour sources, not the grove itself |
| Continued offerings after baptism (syncretism) | `attested` pattern | same | Households keep it quietly |
| Offerings of bread, wool, yarn, wax, coins at stones, trees, springs | `plausible composite` | 18th-c. ethnography projected back | Props |
| Animal sacrifice at the grove | `folklore`/`plausible composite` | later ethnography | Implied (blood on moss), never staged |
| Antler crown, tattooed priestess, standing-stone circle, grove-guardian bear (legacy roster) | `invented` | [`scenes/world/sacred_grove.md`](../../scenes/world/sacred_grove.md) (legacy, archive) | Not adopted as 1343 fact; see section 10 |
| "Cult of Metsik" as an organised faction; the name "Metsik" as a harvest effigy | `plausible composite` (web of households); effigy `folklore` | [`cult_metsik.md`](../CITIZENS/factions/cult_metsik.md), [`estonian_folklore.md`](../lore/estonian_folklore.md) | No temple, no creed |
| Church fines and floggings for rites ("superstition") | `plausible composite`; no dated 1343 trial | belief dossier | Risk and cost for NPCs |
| Hingepuu | `invented`/`folklore` | [`CANON.md`](../CANON.md) | Game reflection entity |
| "Järvi-Maarja-style" spring (brief reference) | unverified; no repo source found | - | Treated as a generic Marian-rededicated offering spring (*ohvriallikas*) |

**Phases.** (A) Act 1 rumour: carters and Ell talk of the oak. (B) Act 2 investment: the grove is a refuge and a meeting place; Urmas Laar and Ellen both appear; Order watchers circle. (C) After Sõjamäe: reprisals and fear; households stop visiting. (D) Act 3: a winter grove, a few survivors, the oak untouched or marked for felling.
**Do not show:** a roofed temple or altar building, a stone circle with a Stonehenge look, robed druids, a human sacrifice, a church inside the grove, Kreutzwald-era pantheon figures (Vanemuine) as cult doctrine.

## 3. Landscape and layout

Biome: mixed hiis forest on slightly drier ground at the edge of a raised-bog fringe. Old oaks (the ring), linden, hazel, ash, spruce edge; moss, fern, wood anemone, wet sedge at the spring. No hill claim ([HISTORICAL_AUDIT](../HISTORICAL_AUDIT.md), `world.sacred_grove` row: built share 0-3 %, forest floor 45-60 %).

| Zone | Cells (x,y,w,h) | Prototype id | Notes |
|---|---|---|---|
| Grove road | 3,25,58,4 | `grove_road` | Muddy track from the west exit; wheel ruts end at the treeline |
| Ritual clearing | 21,10,22,16 | `grove_clearing` | Meadow floor inside the oak ring |
| Oak ring | N 21,9,22,1; W 20,10,1,16; E 43,10,1,16 | `oak_ring_*` | Tree-line collision envelopes |
| Bog edge and spring | 43,8,14,18 / 45,11,6,11 | `eastern_bog`, `spring_water` | Excluded from walkable (`spring_exclusion`) |
| Outer forest belt | perimeter | `boundary_forest_*` | Broken belt; horizon stays wooded |
| Felled edge (proposed) | 8,10,10,10 | - | Stump field, the grove cut back by a manor |
| Keeper's lean-to (proposed) | 24,5,6,4 | - | North tree-line niche, hermit/grove-keeper |

Landmarks (existing): `landmark_ancient_oak` (32,13), `landmark_offering_stone` (32,18), `landmark_bog_spring` (44,22). Proposed (`invented`): `landmark_erratic_ring` (house-size erratics, NW; see the boulder set in [`baltic_klint_coast.md`](baltic_klint_coast.md)), `landmark_felled_stumps` (13,15), `landmark_keeper_leanto` (27,7), `landmark_wolf_path` (2,18, deer-trail exit used by hunters).

**Journey edges (existing, `alignment=travel`):** `to_reval` (0,25) to `reval_south` (the Karja Gate side, `south_quarter.rrmap` `to_world_sacred_grove`); `road_to_harju` (60,24) to `world_harju`. ADR 0027 keeps this node explicit travel; it is not in the seamless hinterland group ([ADR 0027](../adr/0027-reval-hinterland-streaming-group.md)). Proposed: none new. The Karja Gate edge is the only door; the grove should never feel one step from the city.

## 4. Architecture and built environment

There is almost none, by design. All entries are reversible props, not buildings.

| Element | Form | Material | Label |
|---|---|---|---|
| Offering stone | Squat boulder with shallow cupmarks, bread and wool on top | Granite erratic | `plausible composite` (cupmarked stones attested archaeologically; use here is composite) |
| Ancient oak (*hingepuu* in play) | Buttressed trunk, huge limbs, hanging moss; GLB exists | `assets/props/environment/sacred_grove_ancient_oak` | `invented`/`folklore` |
| Spring pool | Clay-lined seep with a plank sill, strips of cloth on a rowan | Wood, linen strips | `plausible composite` |
| Keeper's lean-to | Pole frame, bark and turf cover, smoke hole | Poles, bark, turf | `plausible composite` |
| Boundary markers | Heaped stones at the treeline, carved notches in birch | Stone, bark | `plausible composite` |
| Felled-stump field | Cut oak stumps, ox-drag scars | Wood | `invented` (fictional manor clearance, cf. Kadri's grove in [`cult_metsik.md`](../CITIZENS/factions/cult_metsik.md)) |

Distinguishing rule vs other nodes: no roofline except the lean-to; no straight line except the grove road and the plank sill. Compare Harju (low ridgelines) and the camp (angular shelters): here the skyline is a single round crown.

## 5. Cultures, languages, and people

| Group | Language | Dress | Religion and customs |
|---|---|---|---|
| Harju Estonian households (Cult web) | North Estonian; regilaul fragments, charm formulae | Undyed wool and linen, bast shoes, headscarves; a rowan twig or knotted thread at the throat | Baptized, "keep it" at thresholds and the grove; new-moon visits - `folklore` |
| Ellen and Hingepuu-aware elders | Estonian; Latin prayer blended with charm-song (`plausible composite`) | Plain wool; no antler crown | Cunning-woman (*tark*), midwife, keeper of memory |
| Seers and rebel mystics (Urmas) | Estonian, prophetic cadence | Bone/feather trim (legacy visual) - `invented` | Frames the rising as Kalevipoeg's return - `folklore` |
| Hunters, charcoal-burners, hermits | Estonian | Hide coats, felt hats | Forest owner spirits (*metsaema*, *metsavana*) - `folklore` |
| Order watchers and clergy (visitors) | Middle Low German, Latin | Order surcoat or disguise | Treat the same acts as heresy |

Names follow Harju forms ([`estonian-forenames-harju-1340s.md`](../../history/dossiers/language/estonian-forenames-harju-1340s.md)). The Apprentice understands Estonian by default; Latin and Low German lines are flavour or gated imagery per [`CULTURES_AND_LANGUAGES.md`](CULTURES_AND_LANGUAGES.md).

## 6. Factions present

| Faction id | Presence | Wants | Where | Act-by-act |
|---|---|---|---|---|
| `cult_metsik` | Dense but invisible; households, one core keeper | Keep the grove secret and unburned | Clearing, spring | A1 rumour; A2 refuge and recruiting; A3 hunted, thinner |
| `harju_kings` | Visitors (Urmas, couriers) | Ritual cover for the rising, omens | Clearing, grove road | A2 oath-taking; A3 survivors hide |
| `livonian_order` | Watchers, later a patrol | Evidence of heresy, rebel meetings | Grove road, treeline | A2 spy; A3 felling threat |
| `church` (candidate affinity) | Absent, a priest's warning | Obedience, tithe | At the margins | Fines and floggings in rumour |
| `danish_crown` | None | - | - | - |
| `hanseatic` | None (hemp buyers via cult web) | Hemp, herbs | Road | - |

## 7. Characters

| char id | Name | Role / faction | Language | Confidence | Source | Hook / quest use |
|---|---|---|---|---|---|---|
| `char.ellen` | Ellen Luik | Midwife and keeper of old songs; folklore perspective | Estonian, Latin prayer | `plausible composite` | Existing [`ellen.md`](../CHARACTERS/ellen.md); legacy [`ellen_luik.md`](../../characters/metsik_cult/ellen_luik.md) | Teaches the Apprentice what a grove is; refuses a pure ancestral cause |
| `char.urmas_laar` | Urmas Laar | Seer, one of the Four Kings | Estonian | `invented` | Legacy [`urmas_laar.md`](../../characters/rebels/urmas_laar.md); [`four_kings_act2_lore.md`](../lore/four_kings_act2_lore.md) | Reads omens; calls Kalev the giant-king |
| `char.ell` | Ell | Miller's wife; Metsik thread | Estonian | `plausible composite` | Citizen card [`ell.md`](../CITIZENS/people/harju_road/ell.md) | Walks to the oak at new moon with her dead daughter's name |
| `char.mari` | Mari | Ostler; cell member | Estonian | `plausible composite` | [`mari.md`](../CITIZENS/people/harju_road/mari.md) | Carters' gossip; the road in |
| `char.kadri_partli_tutar` | Kadri Pärtli tütar | Maid, circle leader, grief at a felled grove | Estonian | `plausible composite` | [`kadri_partli_tutar.md`](../CITIZENS/people/lower_town/kadri_partli_tutar.md) | Guides the Apprentice to the felled stumps |
| `char.priidik` | Priidik | Porter; carries salt to a stump | Estonian | `plausible composite` | [`priidik.md`](../CITIZENS/people/kalarand/priidik.md) | Offering delivery, a safe courier |
| `char.grove_keeper_tonu` | Old Tõnu | Grove-keeper (*hiie-hoidja*), the unnamed "core" of the web | Estonian | `invented` | NEW | Gatekeeper to the oak; tests respect before the spring |
| `char.hunter_lost_rein` | Rein | Hunter who stumbled into the grove | Estonian | `invented` | NEW; legacy "hunter who has lost his way" | Wolf-path encounter; fear, not menace |
| `char.order_watcher_unnamed` | A traveller in grey | Order watcher in disguise | Low German, Estonian | `invented` | NEW; legacy "knight on a secret mission" | Tail him, bribe him, or lead him astray |
| `char.marta_spirit` | Marta (shade of Ell's daughter) | Spirit-world figure | Estonian | `folklore`/`invented` | NEW | Spirit-dialogue beat for Ell |

Crowd archetypes: pilgrim woman with bread; young man with a twig under his shirt (cf. Jüri Marteni poeg, [cult_metsik.md](../CITIZENS/factions/cult_metsik.md)); charcoal-burner; herb-gatherer; boy with a knot-net; wounded rebel hiding.

## 8. Quests, encounters, and discoveries

| Id (proposed) | Act | Type | Hook | Ties |
|---|---|---|---|---|
| `quest.the_oak_and_the_ax` | 2 | Investigation | Who is felling the outer belt, and for whom? Evidence in stump marks and ox-drag ruts | Felled edge; `cult_metsik` ledger |
| `quest.new_moon_bread` | 2 | Exploration | Follow Priidik's offering route from the Sand Gate to the grove without being tailed | [`cult_metsik.md`](../CITIZENS/factions/cult_metsik.md) |
| `quest.marta_at_the_spring` | 2 | Spirit-world | Ell's dead daughter at the spring; a duel-free dialogue about grief | ADR 0033 spirit dialogue |
| `quest.hingepuu_root` | 2-3 | Spirit-world | Sit under the oak to enter the Hingepuu hub and allocate a NATURAL beat; visits alone mint no points | [`NATURAL.md`](../SYSTEMS/NATURAL.md), [`PSYCHE.md`](../SYSTEMS/PSYCHE.md), existing `quest.root_and_ember` |
| `quest.libahunt_edge` | 2 | Travel event | A "wolf" among the sheep is a cursed woman; persuade, free or kill (F-7); silver from Kalev's forge | [`estonian_folklore.md`](../lore/estonian_folklore.md) F-7 |
| `quest.iron_at_the_threshold` | 2 | Forge commission | Forge a nail or small knife to be set in a threshold, without claiming that it works | belief dossier "iron and thresholds" |
| `quest.urmas_omen` | 2 end | Spirit-world | A funeral vision of the Four Kings before Paide (F-12); warning the player may act on | `mission.act2.paide` knowledge states |

Sights (journal entries): (1) why a grove is a place with *owners*, not a building; (2) the cupmarked offering stone and what people leave on it; (3) the difference between the 1220 Tharapita grove and the 1241 *lucus sanctus*, and why the map gives no exact polygon; (4) the Marian re-dedication of the spring; (5) the iron-at-the-door belief and why a smith matters.

## 9. Resources: what must be generated

### 9.1 Structures and architecture
| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.kit.hiis_clearing` | Oak ring dressing, boundary heaps, bark notches, lean-to; defined here | P1 | [`kanavere_bog.md`](kanavere_bog.md) margin | Reversible props per HISTORICAL_AUDIT |
| `asset.struct.keeper_leanto` | Pole-frame bark-and-turf lean-to | P2 | none | `plausible composite` |
| `asset.kit.log_farmstead` | Hermit/charcoal-burner hut (cited from [`harju_village.md`](harju_village.md)) | P3 | Harju | - |

### 9.2 Props and craft objects
| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.prop.offering_stone_cupmarked` | Cupmarked boulder with bread, wool, wax, cloth | P1 | cited from [`baltic_klint_coast.md`](baltic_klint_coast.md) | Defined there; this page owns the offering-state variants |
| `asset.prop.votive_cloth_strips` | Linen strips on a rowan at the spring (re-dedicated spring) | P1 | none | Owned here per hub list |
| `asset.prop.carved_hiis_stone` | Rough boundary stone with carved notches | P2 | none | Owned here per hub list |
| `asset.prop.wax_and_wool_offerings` | Candle stubs, wool hanks, bread heels, knotted threads | P1 | Harju | `plausible composite` |
| `asset.prop.erratic_boulder_set` | House-size granite erratics, lichen | P1 | cited from [`baltic_klint_coast.md`](baltic_klint_coast.md) | Existing shore boulders are too small |
| `asset.prop.cold_iron_threshold_charm` | Nail, scissors, small blade for a doorway | P3 | Harju | Smith-craft sight |
| `asset.prop.regilaul_birchbark_roll` | A rolled bark with knot-marks used as a mnemonic (not writing) | P3 | none | `invented` mnemonic; flag |

### 9.3 Characters
| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.wardrobe.harju_peasant` | Cited (hub); undyed variant `.grove_visitor` | P1 | Harju | One shared rig + MPFB |
| `asset.wardrobe.grove_keeper` | Hooded wool coat, pouch, bark-fibre cord, rowan token | P2 | none | No antlers; legacy crown not adopted |
| `asset.wardrobe.hunter_hide` | Cited ([`otepaa_vastseliina_frontier.md`](otepaa_vastseliina_frontier.md)) | P2 | Frontier | - |
| `asset.hair.braid_and_thread_set` | Braids with thread, older white hair, bound beards | P2 | Harju | Ellen visual brief |

### 9.4 Fauna
| Species | Id | Status | Notes |
|---|---|---|---|
| Brown bear, wolf, lynx, boar, elk, roe deer, badger, marten, squirrel, bat | `fauna.*` | cataloged | Bear is the "grove guardian" only as a distant shape (`invented` guardian) |
| Tawny owl, woodpecker, great tit, robin, thrush, nightingale (May margin), chaffinch | `bird.*` | cataloged | Dawn/dusk layers |
| Raven | `bird.raven` | missing (hub list, P1) | Carrion and omen bird |
| Cuckoo, wood pigeon | `bird.cuckoo`, `bird.wood_pigeon` | missing (hub, P3) | May only |
| Glow-worm | `insect.glow_worm` | missing (hub, P3) | Night light, optional |
| Common frog | `amphibian.common_frog` | missing (hub, P3) | Spring pool |

### 9.5 Flora and ground cover
Existing: `tree.oak` (+ authored ancient oak GLB), `tree.linden`, `tree.ash`, `tree.hazel`, `tree.rowan`, `tree.spruce`, `tree.juniper`, `plant.fern`, `plant.moss`, `plant.reed`, `plant.nettle`, `bush.bilberry`, `bush.cowberry`. Missing (hub ids): `plant.wood_anemone` (P1), `plant.hepatica` (P2), `plant.lily_of_the_valley` (P3). Proposed: `plant.marsh_marigold` (P2, spring pool), `tree.oak_stump_felled` (P1), `plant.sedge_tussock` (hub, P2).

### 9.6 Materials, terrain, water
`asset.mat.oak_bark_ancient` (exists in GLB), `asset.mat.moss_thick`, `asset.mat.leaf_litter_oak`, `asset.mat.peat_seep_dark`; terrain `forest_floor`, `meadow`, `bog`, `shallow_water` exist; add `asset.water.spring_clear_pool` (P1; clear water, slow ring ripples) and `asset.terrain.cupmark_boulder_decal` (P3).

### 9.7 Audio and music direction
No bells, no hammers. Layers: wind through oak crowns, dripping, woodpecker, owl at dusk, spring trickle, bark creak; the player's own footsteps loud. Languages: Estonian murmured, charm-formulae, a Latin prayer fragment from Ellen. Music: none by default; a single unaccompanied voice (*regilaul*, `folklore`/`plausible composite`) at the oak; a low drone and a hand-drum only inside spirit-world scenes (`invented`). Legacy "heavy rhythmic drumming and guttural chanting" is not adopted for the real grove; reserve it for rebel-ritual contrast if a task asks. Reference: [`music-and-instruments.md`](../../history/dossiers/culture/music-and-instruments.md).

## 10. Variety signature and risks

- **Palette:** green-black canopy, emerald moss, bone-white cloth and wax, rust of the bog edge.
- **Silhouette:** vertical oak columns around one huge round crown; no roofs.
- **Soundscape:** near-silence, wind and water, one human voice.
- **Risks:** (1) anachronism and exoticism - antler crowns, tattoos, stone circles and blood altars from the legacy roster are not 1343 evidence; (2) religion - treat the Cult with the same respect as the Church, and show the Church's fear as framework, not fact; (3) the grove location is `invented`, never "the" Harju grove; (4) performance - canopy density and moss decals on a 64x36 map; (5) scope - Hingepuu linkage is a design claim for a later task, not a feature; (6) the hub's mission id `mission.act2.travel.sacred_grove` is "folklore-labelled beats only" and must stay that way.
- **Contradictions found:** active brief makes Ellen a baptized midwife in Reval; legacy makes her the grove's high priestess. This page uses the active brief and puts a different, unnamed keeper at the oak.
- **Open questions:** should Hingepuu be physically reachable from the oak? Is Marian re-dedication of the spring acceptable canon? Should animal-offering residue be shown at all?

## 11. Sources and next steps

Repo: `world_sacred_grove.rrmap`, [`scenes/world/sacred_grove.md`](../../scenes/world/sacred_grove.md) (legacy), [`metsik_cult README`](../../characters/metsik_cult/README.md), [`CANON.md`](../CANON.md), [`estonian_folklore.md`](../lore/estonian_folklore.md), [`HISTORICAL_AUDIT.md`](../HISTORICAL_AUDIT.md), [`SPIRIT_DIALOGUE.md`](../SYSTEMS/SPIRIT_DIALOGUE.md), [`FLORA_FAUNA.md`](../FLORA_FAUNA.md), [`BIOMES_AND_WILDLIFE.md`](BIOMES_AND_WILDLIFE.md). External, by name: Henry of Livonia (Tharapita, 1220), Liber Census Daniae (1241), Jonuks and Valk on sacred natural places, Loorits on *haldjas*.
Verification tasks: (1) identify the "Järvi-Maarja" reference or drop it; (2) confirm cupmarked-stone use in medieval Harju; (3) check bear-cult usage before placing a bear shape; (4) decide the Hingepuu-oak linkage with the NATURAL/PSYCHE owners; (5) review sensitive handling of the Cult for Act 3 persecution.
