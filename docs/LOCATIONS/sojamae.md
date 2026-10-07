# Sõjamäe and the Lake Ülemiste Shore (Sõjamäe, Ülemiste järv)

**Status:** planned (design proposal, not implemented) · **Scope gate:** existing prototype `loc.world_sojamae` · **Act(s):** 2 (`mission.act2.sojamae`, 14 May 1343), 3 (aftermath and folklore only)
**Map id:** `loc.world_sojamae` (existing: [`content/maps/world_sojamae.rrmap`](../../content/maps/world_sojamae.rrmap), 54x30 cells, biome `meadow`, `scope=prototype`, `active=false`) · **Seasons/phases:** approach (13 May), battle day (14 May), rout and aftermath (15-19 May), later winter variant for Act 3
**Confidence summary:** battle date, the Order victory under Master Burchard von Dreileben and the collapse of the main rebel field army `attested`; the shore layout, troop movements, fieldworks and every named person `plausible composite` or `invented`; the Ülemiste Elder and Linda's tears `folklore` (later-recorded).

## 1. Why a player would want to visit

- It is the tragic hinge of Act 2: the mainland rising dies on this shore. The player is there, can shape who lives and what evidence survives, and cannot change the result ([`CANON.md`](../CANON.md)).
- It is the open-air counterpart to the closed bog of Kanavere: a wide pale shore, a long low ridge, sky and lake instead of fog and peat. Heavy horse is the threat here, not the terrain.
- It lets the player see Reval from outside: smoke, walls and Toompea on the western horizon, the city that the host never took.
- It holds the game's best folklore set-piece: the Elder of Lake Ülemiste, who asks whether the city is finished, on the same water where the rising ends ([`estonian_folklore.md`](../lore/estonian_folklore.md) F-1).
- **Signature:** a wide, pale, windy lake shore under a high sky, a lance line against the ridge, and afterwards a stillness broken by gulls - the most open and most exposed node.

## 2. History in 1343

| Claim | Label | Source | Use |
|---|---|---|---|
| Battle of Sõjamäe, 14 May 1343, near Lake Ülemiste | `attested` | [`CANON.md`](../CANON.md), [`battle_of_sõjamäe.md`](../../wiki/events/battle_of_sõjamäe.md) | Mission anchor |
| Decisive defeat of the main rebel army by Master Burchard von Dreileben's Order forces | `attested` | [`CANON.md`](../CANON.md) | Outcome fixed |
| Chronicle claims of 3,000+ dead and a host of 10,000 | chronicle rhetoric, order-of-magnitude only | [harju-village dossier](../../history/dossiers/hinterland/harju-village-and-manor.md) | Show hundreds to low thousands at most |
| Order mounted knights and sergeants against a host on foot | `plausible composite` | [arms dossier](../../history/dossiers/military/arms-and-armour-livonia-1340s.md) | Cavalry silhouette |
| Reval burghers allied with the Order against the rebels | `attested` | harju-village dossier | Burgher contingent in the field or on the walls |
| Order leverage on Toompea, 16 May; Swedish fleet offshore 18-19 May | `attested` | [`CANON.md`](../CANON.md) | Aftermath beats |
| Exact battlefield position, order of battle, rebel fieldworks | unverified; `plausible composite`/`invented` | - | Greybox only |
| Lake Ülemiste supplies Reval's water | `plausible composite` (medieval use unverified) | [`TOURIST_LANDMARKS.md`](../TOURIST_LANDMARKS.md) row 1 | Dialogue, rumour |
| Ülemiste Elder asks "is Tallinn finished?" | `folklore`, recorded long after 1343 | [`estonian_folklore.md`](../lore/estonian_folklore.md) 5.1; flagged in [belief dossier](../../history/dossiers/folklore/belief-omens-and-healing.md) | Spirit-world only |
| Linda's tears made the lake; Kalev's grave is Toompea | `folklore` (Kalevipoeg, 19th-c. literary synthesis) | [`estonian_folklore.md`](../lore/estonian_folklore.md) 5.2 | Rebel prophecy layer |
| The name "Sõjamäe" ("war hill") in 1343 | unverified; modern district name | [`TOURIST_LANDMARKS.md`](../TOURIST_LANDMARKS.md) row 2 | Use the label; do not claim a medieval place-name |
| Modern district, memorials, Ülemiste airport/rail | NOT 1343 | - | Never show |

**Phases.** A (13 May): the host digs in and argues; rumour of Order scouts; Urmas's omen. B (14 May): Order cavalry on the shore, rebel line on the rise, collapse; the player's scripted tasks (cover a retreat, carry the wounded, deny the Order a key witness). C (15-19 May): scavengers, a field of dead, a priest and Ellen with the burial question, survivors fleeing to Harju, the Swedish sails on 18-19 May as an offshore speck. D (Act 3): grass over the ridge, the lake in winter, the Elder.
**Do not show:** a full cavalry charge as a game-wide spectacle, plate harness, gunpowder, banners with modern heraldry, a battlefield memorial, an army sim with commands to units, or any celebratory Order triumph without cost. Do not show a "finished" Reval to the Elder as a fact: the Elder's riddle is a rite, not a rule.

## 3. Landscape and layout

Biome: sandy lake shore and low glacial ridge on the eastern side of the Reval plain; reed fringe, wet meadow, scattered birch and alder, pine on the dry rise. May weather: wind off the lake, rain squalls, long light; pale green leaf-out.

| Zone | Cells (x,y,w,h) | Prototype id | Notes |
|---|---|---|---|
| Lake (proposed replacement of the northern strip) | 0,0,54,6 | `wet_north` (bog in greybox) | Open water, reed edge; the greybox's bog must become lake |
| Reed and shore flats | 0,6,54,7 | `churned_margin` | Mud, reed, shingle patches, the fishers' landing |
| Battle rise | 2,13,50,6 | `battle_ridge` | Dirt/sand ridge, `landmark_battle_ridge` |
| South meadow | 0,19,54,11 | `south_meadow` | Order approach field; later the rout and the burial ground |
| Fieldworks | 8,10,1,11 / 45,10,1,11 | `west_fieldworks`, `east_fieldworks` | Ditch stakes, `invented` |
| Field shelter | 23,20,8,4 | `field_shelter` | Aid post |
| Fishers' landing (proposed) | 6,7,8,3 | - | Dugouts, nets, a smoke rack |
| Lake-meadow shrine tree (proposed) | 44,5,3,3 | - | Lone willow with cloth strips for the spirit-world scene |

Landmarks (existing): `landmark_battle_ridge` (27,15), `landmark_west_fieldworks` (9,17), `landmark_east_fieldworks` (44,17). Proposed (`invented`): `landmark_lake_edge` (27,6), `landmark_fishers_landing` (9,8), `landmark_elder_willow` (45,6), `landmark_reval_horizon_view` (view only, west edge), `landmark_rout_fords` (36,10, shallow crossing), `landmark_grave_pit` (30,25, aftermath state).

**Journey edges (existing, `alignment=travel`):** `road_to_harju` (0,24) to `world_harju`; `road_to_paide` (50,24) to `world_paide`. Planned: the Reval-side seam `sojamae_approach_road` (new west/north seam, [ADR 0027](../adr/0027-reval-hinterland-streaming-group.md)), after which `world.sojamae` moves into `reval_hinterland`; its Paide exit stays explicit travel. The compass orientation of the existing exits (Harju west, Paide east) is a greybox convention; real geography is unverified here.

## 4. Architecture and built environment

| Element | Form | Material | State | Label |
|---|---|---|---|---|
| Rebel ditch-and-stake works | Short ditch with stakes | Earth, withy | Intact, then trampled | `invented` |
| Aid post / field shelter | Lean-to with straw rows | Poles, thatch | B-C | `plausible composite` |
| Order command spot | A pavilion-less cluster of banners and horses | Cloth, pole | B | `plausible composite` |
| Fishers' landing | Beach landing, drying rack, hut | Plank, tarred rope, log | A-D | `plausible composite` |
| Reval silhouette (distant) | Wall line, a few towers, Toompea outline, smoke | Backdrop only | Horizon | per [`toompea dossier`](../../history/dossiers/architecture/toompea-castle-and-upper-town.md); no Tall Hermann form |
| Burial pit | Open trench, lime, a cross | Earth | C | `plausible composite` |
| Memorial | None in 1343 | - | D (Act 3, optional heap) | `invented` |

Distinguishing rule vs other nodes: almost no architecture; the only large vertical elements are lance and banner lines, one willow and the horizon towers. Contrast with Kanavere (closed, fog) by having long sight lines and big sky.

## 5. Cultures, languages, and people

| Group | Language | Dress | Religion and custom |
|---|---|---|---|
| Rebel host (Harju freeholders, vassal clients, labourers) | North Estonian; Low German curses | Wool, leather, bast shoes; captured caps | Oaths, omens, charms; Latin rites for the dying from a priest |
| Order brothers and sergeants | Middle Low German; Latin prayer; clipped commands | White mantle with black cross, mail, kettle helm; sergeants in grey | Order rule; the field mass |
| Reval burgher contingent (if shown) | Low German | Padded jack, iron cap, crossbow or spear | Guild saints |
| Lake fishers and reed cutters | Estonian, some Finnish | Waxed wool, tarred boots | Water-spirit (*vetevana*) and lake-owner beliefs - `folklore` |
| Camp followers and refugees | Estonian | Layers | Burial rites and keening |
| Toompea observers | Danish, Latin, Low German | Court wool | - |

The Apprentice understands Estonian by default; Low German is gated imagery ([`CULTURES_AND_LANGUAGES.md`](CULTURES_AND_LANGUAGES.md)). The sound design should make the Order a wall of clipped Low German and horn calls against the Estonian crowd's shouts.

## 6. Factions present

| Faction id | Presence | Wants | Where | Act-by-act |
|---|---|---|---|---|
| `livonian_order` | Field army under the Master | Destroy the host, then enter Toompea | West approach, meadow | A2 victor; A3 garrisons and enforcers |
| `harju_kings` | The host and its commanders | Hold the rise, retreat in order | Ridge, fieldworks | A2 broken; A3 remnants |
| `danish_crown` | Observers on Toompea | Survive; hand castles 16 May | Horizon | A2 leverage lost |
| `hanseatic` | Burgher contingent and buyers | Protection, trade | Western meadow | A2 accepts Order fact |
| `black_cloaks` | Survival; records who warned whom | Escape routes | Reeds | A2 aftermath |
| `cult_metsik` | Seers; interpret defeat | Sanctify the dead | Willow, shore | A2-A3 |
| `church` (candidate affinity) | Priests at the pit | Burial, mercy | Aid post, pit | A2 aftermath |
| `pskov_novgorod`, `vitalienbruder` | None (news only, 26 May raid at Otepää) | - | - | - |

## 7. Characters

| char id | Name | Role / faction | Language | Confidence | Source | Hook / quest use |
|---|---|---|---|---|---|---|
| `char.burchard_von_dreileben` | Master Burchard von Dreileben | Livonian Order Master (1340-1345) | Low German, Latin | `attested` person; lines `invented` | [`CANON.md`](../CANON.md) | Distant presence, one cold exchange |
| `char.goswin_von_herike` | Goswin von Herike | Later Master (1345-1359); 1343 rank unverified | Low German | `plausible composite` | [`paide_castle.md`](paide_castle.md) | Optional senior brother |
| `char.juri_ratnik` | Jüri Ratnik | Rearguard commander | Estonian | `invented` | [`juri_ratnik.md`](../../characters/rebels/juri_ratnik.md); [`four_kings_act2_lore.md`](../lore/four_kings_act2_lore.md) | Last stand; player mediates or lets him hold |
| `char.lembit_helme` | Lembit Helme | Elder King | Estonian | `plausible composite` | [`lembit.md`](../CHARACTERS/lembit.md) | Orders retreat; survives for Paide |
| `char.urmas_laar` | Urmas Laar | Seer king | Estonian | `invented` | [`urmas_laar.md`](../../characters/rebels/urmas_laar.md) | Eve omen |
| `char.kaja` | Kaja | Courier | Estonian, Low German | `invented` | [`kaja.md`](../CHARACTERS/kaja.md) | Retreat route, survivor lists |
| `char.ellen` | Ellen Luik | Midwife, songkeeper | Estonian | `plausible composite` | [`ellen.md`](../CHARACTERS/ellen.md) | Aftermath songs; Elder interpretation |
| `char.konrad_preen` | Viceroy Konrad Preen | Danish Crown face | Danish, Low German | `plausible composite` | [`konrad_preen.md`](../CHARACTERS/konrad_preen.md) | Distant observer, only via report |
| `char.brother_hermann` | Brother Hermann | Order handler | Low German, Latin | `plausible composite` | [`brother_hermann.md`](../CHARACTERS/brother_hermann.md) | Offer or demand after the field |
| `char.henning` | Captain Henning | Viru watch commander | Low German | `plausible composite` | [`henning.md`](../CHARACTERS/henning.md) | Watch contingent; hunts fugitives |
| `char.ulemiste_elder` | The Elder of Ülemiste | Lake spirit | Estonian, old speech | `folklore` | NEW; [`estonian_folklore.md`](../lore/estonian_folklore.md) 5.1 | Spirit-world riddle encounter |
| `char.lake_fisher_ants` | Ants the eel-fisher | Fisher with a dugout | Estonian, Finnish | `invented` | NEW | Ferry for the wounded; knows the shoals |
| `char.order_herald_unnamed` | Herald | Order herald | Low German | `invented` | NEW | Terms called across the shore |

Crowd archetypes: Order sergeant on foot; spear-bearer with a scythe-blade; boy with a standard; woman with a water pail at the aid post; priest at the pit; reed cutter hiding; Reval burgher crossbowman.

## 8. Quests, encounters, and discoveries

| Id (proposed) | Act | Type | Hook | Ties |
|---|---|---|---|---|
| `mission.act2.sojamae` | 2 | Night/day mission | Cover the retreat; choices change casualties and survivors only | Existing id ([`p5_001_act2_design.md`](../reports/p5_001_act2_design.md)) |
| `quest.shore_retreat` | 2 | Escort | Carry the wounded across the shallows with Ants's dugout while cavalry sweeps | `flag.sojamae_survivors` (proposed in [`soomaa_flood_refuge.md`](soomaa_flood_refuge.md)) |
| `quest.jyri_last_stand` | 2 | Spirit-world | Mediate between Jüri and Lembit: reduce casualties, lose time, or let him hold | lore bindings in [`four_kings_act2_lore.md`](../lore/four_kings_act2_lore.md) |
| `quest.names_of_the_dead` | 2 | Investigation | Collect names for families, from tally sticks and tokens | Ellen; rebel ledger flags |
| `quest.the_elder_of_ulemiste` | 2-3 | Spirit-world | At the lake the Apprentice meets the Elder; the question "is the city finished?" is a duel about what the rising was for | F-1; ADR 0033 |
| `quest.official_version` | 2 | Investigation | An Order scribe writes a clean story of the battle; find the witness who contradicts it | Order, Hanseatic ledgers |
| `quest.cold_iron_for_the_dead` | 2 | Forge commission | Burial nails, a small iron token for the lost; a smith's gift | F-8 |
| `quest.refuge_rumour` | 2 end | Travel event | A rumour of a flood-island refuge in the south-west | [`soomaa_flood_refuge.md`](soomaa_flood_refuge.md) |

Sights: (1) why the lake is the city's lifeline (medieval use `plausible composite`); (2) Linda's tears and the grave under Toompea (`folklore`, Kalevipoeg); (3) a cavalry line seen from the ridge and why a spear wall matters; (4) the field mass and how the Order buried its own; (5) the Swedish sails on 18-19 May: "too late" as `attested` colour.

## 9. Resources: what must be generated

### 9.1 Structures and architecture
| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.kit.lake_shore_landing` | Fishers' landing: beached dugouts, drying rack, hut, pier stakes; defined here | P2 | [`narva_peipus_east.md`](narva_peipus_east.md), [`viljandi_fellin.md`](viljandi_fellin.md) | Shore debris is for sea beaches only, so a freshwater variant is needed |
| `asset.kit.ditch_and_stake_works` | Cited, defined in [`kanavere_bog.md`](kanavere_bog.md) | P2 | Kanavere | - |
| `asset.kit.camp_lean_to` | Cited from [`rebel_kings_camp.md`](rebel_kings_camp.md) | P1 | camp | Aid post |
| `asset.kit.reval_horizon_backdrop` | Wall-line and Toompea silhouette billboard (no new landmark forms) | P2 | Harju | Distant LOD |
| `asset.kit.burial_pit` | Open trench, lime sacks, cross, tool rack | P2 | Kanavere | Handle with care |

### 9.2 Props and craft objects
| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.prop.order_banner_set` | Plain black-cross pennons, no modern heraldry | P1 | Paide | Order standards |
| `asset.prop.lance_and_spear_rack` | Lances, spear stacks | P1 | camp | Silhouette generator |
| `asset.prop.horse_trappings_heavy` | Barded saddle cloth, bridle, stirrups of 1340s type | P1 | Paide | Horse props on `fauna.horse` |
| `asset.prop.cart_on_shore` | Mired cart (`broken_cart` prototype) | P1 | camp, Kanavere | Reuse `wooden_cart.glb` |
| `asset.prop.burial_tokens_and_tally` | Tally sticks, crosses, cloth scraps | P2 | camp | Names-of-the-dead quest |
| `asset.prop.votive_cloth_strips` | Cited from [`sacred_grove.md`](sacred_grove.md) | P1 | Grove | Elder willow |
| `asset.prop.fish_drying_rack` | Cited from [`harju_village.md`](harju_village.md) | P2 | Harju | - |
| `asset.prop.field_mass_altar_cloth` | Portable altar, chalice, cross | P3 | Paide | Order field mass |

### 9.3 Characters
| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.wardrobe.order_brother` | Cited (hub); mounted variant `.mounted` with surcoat and kettle helm | P1 | Paide, Viljandi | Defined by the hub |
| `asset.char.wardrobe.order_sergeant` | Cited ([`paide_castle.md`](paide_castle.md)) | P1 | Paide | Grey surcoat |
| `asset.wardrobe.knight_vassal` | Cited (hub); invented arms | P2 | Harju | - |
| `asset.wardrobe.burgher_male` | Cited (hub); militia variant `.watch_jack` | P2 | Reval | Padded jack, iron cap |
| `asset.wardrobe.harju_peasant` | Cited (hub); `.rout` variant | P1 | Harju group | - |
| `asset.wardrobe.wounded_rebel` | Cited ([`soomaa_flood_refuge.md`](soomaa_flood_refuge.md)) | P2 | Soomaa | - |
| `asset.char.ulemiste_elder_figure` | Spirit-world figure: indistinct, wet, tall, old-man silhouette with lake-weed textures | P2 | none | `folklore`; no stat block |
| `asset.hair.shore_wind_set` | Wind-blown hair variants, helmet hair | P3 | all | - |

### 9.4 Fauna
| Species | Id | Status | Notes |
|---|---|---|---|
| Horse (war horse variants), dog | `fauna.horse`, `fauna.dog` | cataloged | Heavy barded horse variant is a prop layer |
| Swan, goose, mallard, grey heron, cormorant, gulls, tern, osprey | `bird.*` | cataloged | Lake bird mix |
| Hooded crow, rook | `bird.*` | cataloged | Scavengers |
| Raven | `bird.raven` | missing (hub, P1) | Phase C |
| Common crane, whooper swan | `bird.common_crane`, `bird.whooper_swan` | missing (hub, P2-P3) | Shore passage birds |
| Bream, pike, perch, eel | `fish.*` | missing (hub, prop-first, P2) | Fishers' catch |
| Beaver, otter | `fauna.*` | cataloged | Lake margin |

### 9.5 Flora and ground cover
Existing: `plant.reed`, `plant.cattail`, `plant.water_lily`, `tree.willow`, `tree.alder`, `tree.birch`, `tree.pine`, `plant.nettle`, `grass.*`. Missing (hub): `plant.sedge_tussock` (P2). Proposed: `plant.shore_horsetail` (P3), `tree.willow_elder_cloth` (the Elder willow; `tree.willow` plus cloth strips, P1).

### 9.6 Materials, terrain, water
`asset.water.lake_slate_wide` (P1; shallow, slate-blue, small wavelets, wind streaks; defined here), `asset.terrain.sand_shore_wet` (P1), `asset.terrain.reed_flat` (cited; defined in [`parnu.md`](parnu.md)), `asset.mat.trampled_ridge_dirt` (P1), `asset.mat.blood_stained_sand` (P3, subtle), `asset.mat.lime_pit` (P3); existing `mud`, `dirt`, `meadow`, `shallow_water`.

### 9.7 Audio and music direction
Ambient: wind across open water, reed rustle, gulls, distant Reval bells, wet hooves, snorting horses, Order trumpet and drum signals (`plausible composite`), then silence and crows. Languages: clipped Low German commands and Latin prayer from the Order; Estonian shouts, cries, keening from the host; Finnish phrases from the fishers. Music: none during the fight; after it a solo *regilaul* lament (`folklore`/`plausible composite`) and a low drone; no heroic orchestra ([music dossier](../../history/dossiers/culture/music-and-instruments.md)). The Elder: a water-and-breath soundscape, no melody.

## 10. Variety signature and risks

- **Palette:** slate lake, pale sand, silver reed, Order white and black against grey sky.
- **Silhouette:** long flat horizon with a lance line, one willow, towers far off.
- **Soundscape:** wind over water, hooves and horns, then gulls and crows.
- **Risks:** (1) anachronism - plate, firearms, modern district, memorials; (2) massacre sensitivity: the host dies, the fugitives are hunted, the Order is a Christian order and the rebels' chroniclers are hostile; show individuals, not spectacle ([`CULTURES_AND_LANGUAGES.md`](CULTURES_AND_LANGUAGES.md) risk list); (3) the Elder riddle is later-recorded folklore - the belief dossier says not to import it as a 1343 rite, while the lore compendium calls it the best set-piece; this page uses it only in the spirit world; (4) greybox identical to Kanavere (same terrain rects, shelter, cart, standard positions) - deepening must differentiate it; (5) performance - wide water plus crowd; (6) no unit-command UI (AGENTS.md out of scope).
- **Contradictions found:** character ids for the Order Master differ in the repo (`char.burchard_von_dreileben` vs `char.burchard_von_dreileben`; `char.goswin_von_herike` vs `char.goswin_von_herike`); the `world_sojamae.rrmap` has no lake despite the name and sources.
- **Open questions:** is Reval visible from the shore (distance unverified)? Should the Elder require language skill? How is the "aftermath" state shown without a second map?

## 11. Sources and next steps

Repo: [`world_sojamae.rrmap`](../../content/maps/world_sojamae.rrmap), [`battle_of_sõjamäe.md`](../../wiki/events/battle_of_sõjamäe.md), [`CANON.md`](../CANON.md), [`TOURIST_LANDMARKS.md`](../TOURIST_LANDMARKS.md), [`estonian_folklore.md`](../lore/estonian_folklore.md), [`p5_001_act2_design.md`](../reports/p5_001_act2_design.md), [`ADR 0027`](../adr/0027-reval-hinterland-streaming-group.md), [`arms dossier`](../../history/dossiers/military/arms-and-armour-livonia-1340s.md), [`BIOMES_AND_WILDLIFE.md`](BIOMES_AND_WILDLIFE.md) (section 9). External, by name: Hermann de Wartberge, the Livonian chronicle tradition, Kreutzwald's *Kalevipoeg*, Tallinn city heritage notes on Ülemiste.
Verification tasks: (1) fix the battlefield area against the modern Sõjamäe district and pre-modern lake shoreline (the lake was larger or smaller? unverified); (2) decide the aftermath state mechanism; (3) review the Elder encounter with Narrative/Canon; (4) reconcile the Order Master character ids; (5) layout pass so this map no longer duplicates Kanavere.
