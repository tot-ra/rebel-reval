# Pöide Castle (Peude, Order convent castle with fortified church, Saaremaa)

**Status:** planned (design proposal, not implemented) · **Scope gate:** existing prototype `loc.world_poide` · **Act(s):** 3 (July 1343 siege and surrender; aftermath through 1345)
**Map id:** `loc.world_poide` (existing: [`content/maps/world_poide.rrmap`](../../content/maps/world_poide.rrmap), 50x30 cells, a copy of the Paide greybox, `scope=prototype`, `active=false`; proposal widens it to about 84x52 and retires the Paide-shaped layout) · **Seasons/phases:** A "siege" (24 Jul 1343, hot, dry, thin cloud), B "after" (late July 1343 and following days: slighted castle, burials), C "winter 1345" (optional silent revisit; concept stakes of Maasilinna seen only as a survey sign)
**Confidence summary:** Order convent castle and church at Pöide: `attested`. Surrender on safe-conduct and killing of the garrison, 24 July 1343: `attested` (chronicle tradition, [`CANON.md`](../CANON.md)). Castle destroyed in the rising: `attested` (wiki), degree unverified. Exact plan, garrison numbers and all named people: `plausible composite` / `invented`. Karja (Feb 1344) is an off-map echo; Maasilinna is concept metadata only.

## 1. Why a player would want to visit

- It is the Act 3 climax of the Saaremaa chapter and the moral centre of the game: the player forged the iron that took the castle, and the castle then falls into the worst thing the rising did.
- A real, distinctive building type: a convent castle fused with a fortified church whose roof is a fighting platform. Nothing else in the five pages looks like it.
- The player's choices, made earlier at the oath stone ([`saaremaa.md`](saaremaa.md)), decide who breaks and who refuses at the gate. They do not decide whether the massacre happens.
- A place to feel consequence as a quiet space: the aftermath is walkable, searchable, and silent.
- **Signature:** a squat, heavy island fortress-church of dark limestone under a high hot sky, with a huge tower, thick walls and nothing moving after the column leaves.

## 2. History in 1343

| Fact | Label | Note |
|---|---|---|
| Livonian Order convent castle at Pöide, with a large 13th-century stone church (St Mary) beside it, built defensively | `attested` | The church stands today; its fortified upper level is a standard Baltic type. Details of the 1343 relationship between castle and church: `plausible composite`. |
| Rising on 24 July 1343; lords killed; Pöide besieged | `attested` | [`CANON.md`](../CANON.md), [`HISTORY.md`](../../history/HISTORY.md). |
| Garrison surrendered on promise of free passage; promise broken; defenders killed | `attested` (chronicle tradition) | Numbers, commander's name, rebel commander's name: unverified. Keep them unnamed or `invented`. |
| Castle destroyed afterwards | `attested` (wiki event) | Extent unverified; the church survives (it still stands). |
| Vesse as rebel "king" | `attested` | Specific role at Pöide is not documented: `plausible composite` if he appears. |
| Karja fortress storming and Vesse's execution, Feb 1344 | `attested` | Off-map echo only. |
| Maasilinna (Soneburg) as "castle of atonement" after the 1345 pacification | `attested` as concept | Do not show as built or as complete; see [`CANON.md`](../CANON.md). |
| Kuressaare stone castle, windmills, later tower additions | anachronism | Excluded. |

Phases: A: castle complete and defended; surrender negotiated; column leaves; killing is off-screen. B: broken gates, smoke, burnt roofs, burials, looting dispute. C: demolished or abandoned, a survey stake.
Do NOT show: a ruin as in modern tourism, a bishop's Kuressaare, Maasilinna as built, gunpowder weapons. Number of dead in text: "the garrison" unless a source is added.

## 3. Landscape and layout

Biome: east-central Saaremaa, flat limestone plain with alvar grass, juniper scrub and a few oaks, stone fields, a creek or marshy low ground west of the castle, distant sea haze. Climate: late July dry heat, wind-driven dust, long evenings.

| Zone | Approx cells (84x52) | Reads as | Carries |
|---|---|---|---|
| Western approach (road and causeway) | x0-22, y36-52 | Dirt track over low ground | `road_to_saaremaa`; rebel camp in A |
| Outer ditch and earth bank | x20-68, y6-48 | Wet ditch, bank, palisade | Siege lines (A) |
| Forecourt | x28-60, y30-46 | Stables, granary, smithy, huts | Order labour, hostages |
| Inner court | x32-56, y10-30 | Limestone curtain, gatehouse, keep, convent range | Surrender negotiation, armoury |
| Fortified church | x14-30, y12-28 | Squat nave, huge west tower, defensive attic | Chapel, refuge, relic room |
| Churchyard and cemetery | x8-20, y28-40 | Low wall, graves | Burials in B |
| Sally gate and meadow | x56-72, y24-40 | Open meadow outside the east sally gate | The column's march (off-screen kill zone, B markers only) |
| Sea haze edge | x72-84 | Sky and distant water | Island reading |

Landmarks: existing greybox anchors `landmark_gatehouse`, `landmark_central_keep`, `landmark_island_chapel` (13,15); proposed `landmark_fortified_church_tower`, `landmark_sally_gate`, `landmark_surrender_table`, `landmark_churchyard`, `landmark_armoury_cellar`, `landmark_survey_stake_1345` (C only).

Journey edges: existing `road_to_saaremaa`. No others; the node is a dead end on the island. Karja is mentioned by a rider only.

## 4. Architecture and built environment

- **Convent castle type:** curtain, gate, tall keep-tower, chapel/hall, dormitory, cellars (shared kit `asset.kit.limestone_castle`, defined in [`paide_castle.md`](paide_castle.md)). On Saaremaa the proportions are squatter: lower keep, thicker walls, smaller windows, because the Order built for island defence.
- **Fortified church:** a massive stone church with a high gabled roof over vaults and a defensive upper floor (wehrgeschoss) with loops, a heavy west tower, buttress-free stout walls, and plain portals. This is the dominant silhouette. Marked `plausible composite` for the 1343 appearance.
- **Materials:** local pale dolomite and limestone rubble with dressed corners; lime-wash; oak doors with iron straps; shingle roofs, some thatch in the forecourt.
- **Earthworks:** ditch, bank and palisade; timber hoardings on the walls in A (siege readiness); burnt gate in B.
- **Interiors:** vaulted undercroft armoury (siege-iron storage), convent refectory used as the surrender table, church interior with painted consecration crosses (`plausible composite`).
- **Distinct from Paide:** Paide is clean, tall and white on a plain; Pöide is squat, heavy, dark and island-bound; in B it is broken and quiet.

## 5. Cultures, languages, and people

| Group | Language | Wardrobe / notes |
|---|---|---|
| Order brothers, chaplain | Middle High German, Latin | White mantle with black cross (knights), grey (sergeants) |
| Garrison servants, smith, stable hands | Estonian (island dialect) and German | Wool and leather; kept inside the walls |
| Rebel islanders | Estonian (Saaremaa) | Sheepskin, round shields, spears, axes; some hooded |
| Cult attendants | Estonian | Dark cloaks, ribbons; present at the oath |
| Visiting merchant (trapped) | Low German | Plain cloth |
| German manor refugees inside the walls | Low German | Hastily dressed |

Religion: Latin Mass, garrison vespers; island belief outside. The safe-conduct oath is sworn in both traditions (cross and stone). Customs: truce formulae, hostages, banner lowering. Names: Order brothers by Westphalian places; islanders by Estonian forenames.

## 6. Factions present

| Faction id | Presence | Wants | Where | Act-by-act |
|---|---|---|---|---|
| `livonian_order` | Garrison | Hold until relief; survive the surrender | Inner court, church, keep | A: besieged; B: gone; C: returns for atonement |
| `cult_metsik` | Rebel allies | Legitimacy, iron, grain | West approach, oath table | A: omen carriers; B: martyr and shame cult |
| `harju_kings` | Echo | Solidarity with the island | Rebel camp | Marginal |
| `hanseatic` | Trapped merchant | Survive; goods | Forecourt | A only |
| `vitalienbruder` | Opportunist | Loot, fences | Meadow edge | B: looting dispute |
| `danish_crown`, `black_cloaks`, `pskov_novgorod` | None | - | - | - |
| Bishopric of Ösel-Wiek | Background canon | Lands, tithe | Absent | Rumour only |

## 7. Characters

| char id | Name | Role / faction | Language | Confidence | Source | Hook |
|---|---|---|---|---|---|---|
| `char.poide_komtur` | Komtur Wessel (placeholder; real name unverified) | Garrison commander | MHG | `invented` (NEW) | legacy NPC 1 | Negotiates terms |
| `char.brother_hermann` | Brother Hermann | Order handler / inspector | MHG | `plausible composite` | existing [`brother_hermann.md`](../CHARACTERS/brother_hermann.md) | Appears if the player is in Order service |
| `char.order_squire` | The squire | Young knight against surrender | MHG | `invented` | existing [`order_squire.md`](../CHARACTERS/order_squire.md), legacy [`squire.md`](../../characters/order/squire.md) | Argues; may refuse; may be saved |
| `char.vesse` | Vesse | Rebel leader | Estonian | `attested` (person); role here `plausible composite` | [`CANON.md`](../CANON.md) | Takes the surrender |
| `char.saaremaa_muster_captain` | Captain Kaido | Muster captain | Estonian | `invented` | [`saaremaa.md`](saaremaa.md) | Gives or breaks the oath |
| `char.poide_oath_keeper` | Jaagup | Rebel who believes the promise | Estonian | `invented` (NEW) | legacy NPC 8 | Refuses to join the killing |
| `char.poide_chaplain` | Brother Anselm | Garrison chaplain | Latin, MHG | `invented` (NEW) | legacy NPC 7 | Last prayer; hides relics |
| `char.poide_armourer` | Brother Reinhard | Armourer, hands over arms | MHG | `invented` (NEW) | legacy NPC 16 | Forge link: marked siege-iron stock |
| `char.ellen_luik` | Ellen Luik | Cult leader | Estonian | `invented` | existing [`ellen.md`](../CHARACTERS/ellen.md) | At the oath |
| `char.kaja` | Kaja | Courier | Estonian | `invented` | existing [`kaja.md`](../CHARACTERS/kaja.md) | Warns, or fails to |
| `char.apprentice` / `char.kalev` | Apprentice / Kalev | Protagonists | Estonian | `invented` | existing [`apprentice.md`](../CHARACTERS/apprentice.md), [`kalev.md`](../CHARACTERS/kalev.md) | Siege iron; spirit-world witness |
| `char.poide_stableman` | Mats the stableman | Servant, hides a horse | Estonian | `invented` (NEW) | legacy NPC 17 | A small mercy |

Crowd archetypes: Order sentry, trapped merchant, garrison cook, rebel spearman, island woman at the meadow wall, wounded sergeant, church sexton, child with a helmet (aftermath only).

## 8. Quests, encounters, and discoveries

| id proposal | Act | Type | Hook | Ties |
|---|---|---|---|---|
| `quest.poide_siege_iron_use` | 3 | forge commission | Deliver the siege iron forged at the camp; the work decides how fast the walls fall | `quest.saaremaa_siege_iron`, CANON siege iron |
| `quest.poide_surrender_table` | 3 | investigation | Observe the terms; test the safe-conduct wording for what it does not say | oath at the stone |
| `quest.poide_gate_choice` | 3 | travel event | At the sally gate: warn, delay, escort one person out, or stay out; outcome changes survivors only | Local cost |
| `quest.poide_spirit_witness` | 3 | spirit-world | Apprentice meets the room's "broken oath" as a presence; dialogue combat resolves into testimony | ADR 0033 |
| `quest.poide_burial_detail` | 3 | exploration | In B, help bury and record names; find the chaplain's hidden relics | Aftermath journal |
| `quest.poide_looters_meadow` | 3 | night mission | Stop or join looters stripping the meadow | `faction.vitalienbruder` |
| `quest.poide_karja_rumour` | 3 | travel event | Hear of Karja; decide whether to cross the ice (off-map echo) | Feb 1344 |

Sights: (1) the fortified church's defensive attic and loops, `attested` type; (2) the island's largest medieval church, `attested`; (3) the altar-cloth hidden under the floor, `invented`; (4) a lowered banner folded on a table, `plausible composite`; (5) the survey stake in C, `invented` link to a `attested` concept.

## 9. Resources: what must be generated

`asset.kit.limestone_castle` and the Order wardrobe set are defined in [`paide_castle.md`](paide_castle.md). `asset.kit.island_vernacular` and `asset.saaremaa.kiviaed_wall_set` are defined in [`saaremaa.md`](saaremaa.md). `asset.kit.monastic_timber` is defined in [`padise_monastery.md`](padise_monastery.md). This page defines only Pöide-specific parts.

### 9.1 Structures and architecture

| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.poide.fortified_church` | Massive limestone church: nave, high roof, defensive attic with loops, heavy west tower, two portals, damage states | P1 | | Uses `asset.kit.limestone_castle.chapel` walls; evidence: Baltic fortified church type, Pöide church survives |
| `asset.poide.keep_squat` | Low heavy keep variant | P1 | | Variant of `asset.kit.limestone_castle.keep_tower` |
| `asset.poide.curtain_hoarding` | Timber hoardings and siege boards for the curtain | P2 | | A only |
| `asset.poide.sally_gate` | Small posterns and timber gate | P2 | | |
| `asset.poide.forecourt_huts` | Forecourt huts, stable, granary | P2 | | From `asset.kit.island_vernacular` |
| `asset.poide.damaged_set` | Burnt gate, collapsed roofs, rubble, ash (B) | P1 | Saaremaa burnt manor | Uses kit damage states `scarred`, `burnt`, `slighted` |
| `asset.poide.siege_works` | Ditch ladders, bundled fascines, earth ramp, a battering ram head | P2 | | No trebuchet or cannon |
| `asset.poide.churchyard_wall_and_graves` | Low wall, wooden crosses, grave mounds | P2 | Padise cemetery | |

### 9.2 Props and craft objects

| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.prop.siege_iron_set` | Ram cap, grapnel, crowbar, window-bar cutter (player-forged, quest-specific) | P1 | Saaremaa | Forge pillar |
| `asset.prop.order_banner_white_cross` | Cited from [`paide_castle.md`](paide_castle.md) | - | - | Cited |
| `asset.prop.relic_oath_casket` | Cited from [`paide_castle.md`](paide_castle.md) | - | - | Cited |
| `asset.prop.chalice_and_paten`, `asset.prop.processional_cross`, `asset.prop.reliquary_box` | Cited from [`padise_monastery.md`](padise_monastery.md) | - | - | Cited |
| `asset.prop.altar_cloth_embroidered` | Linen altar cloth with coloured embroidery | P2 | | |
| `asset.prop.surrender_table_set` | Table, tablet, wax seal, banner pole | P1 | | |
| `asset.prop.discarded_helmet_nasal` | Kettle-hat helmet in grass | P3 | | Aftermath object, restrained |
| `asset.prop.garrison_bell` | Church bell, cracked in B | P2 | Paide | |

### 9.3 Characters

| Asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| Order wardrobe | `asset.char.wardrobe.order_knight_brother`, `.order_priest_brother`, `.order_sergeant`: cited from [`paide_castle.md`](paide_castle.md) | - | - | Cited |
| `asset.char.wardrobe.order_garrison_summer` | Light surcoat without mantle, summer wear | P2 | | Heat |
| Islander wardrobe | `asset.char.wardrobe.islander_fisher`, `.islander_woman`, `.muster_fighter`: cited from [`saaremaa.md`](saaremaa.md) | - | - | Cited |
| `asset.char.wardrobe.wounded_bandaged` | Bandaged head, sling, tunic | P3 | | |
| `asset.char.wardrobe.manor_refugee_german` | Low German household clothing | P3 | | |

### 9.4 Fauna

| Species | Status | Notes |
|---|---|---|
| Horse, dog, goose, chicken, sheep, cattle, pig | already cataloged | Stables, forecourt |
| Hooded crow, rook, jackdaw, white-tailed eagle, skylark, lapwing | already cataloged | Crows over the meadow in B (restraint) |
| Hare, red fox, wolf | already cataloged | Margin |
| Warhorse heavy `asset.fauna.horse_destrier` | cited from [`paide_castle.md`](paide_castle.md) | - |
| Carrion flies (`asset.fauna.fly_swarm_decal`) | missing | P3, used sparingly |

### 9.5 Flora and ground cover

Existing: `tree.juniper`, `tree.oak`, `tree.pine`, `bush.juniper_shrub`, `bush.heath`, `grass.dry`, `grass.short`, `plant.thistle`, `plant.yarrow`, `plant.clover`. Missing: those listed in [`saaremaa.md`](saaremaa.md) (`plant.alvar_sedge_pavement`, strand plants). No new species proposed here.

### 9.6 Materials, terrain, water

`asset.mat.limestone_rubble_quoin` cited from [`paide_castle.md`](paide_castle.md). `asset.terrain.dry_alvar_dust` (dust, cracked soil, footprints) P2; `asset.terrain.ditch_water_stagnant` P2; `asset.mat.scorched_stone` P1; `asset.mat.blood_none` (no explicit blood decals; use displaced objects and silence) P1 policy.

### 9.7 Audio and music direction

Languages heard: Middle High German commands, Latin chaplain's prayers (Vespers; litany; office of the dead after), island Estonian, Low German whispers. Ambience: wind across the alvar, a heavy bell, ravens and rooks, boots in dust, crickets in the evening, creak of hoardings. A: tight rhythm, murmured negotiation. B: absence: wind, fly buzz at very low level, a lone bell not rung by anyone. Music: a single low drone and plainchant in A; solo voice and cello in B (matching legacy brief). No battle score during the killing, which is not staged.

## 10. Variety signature and risks

- **Palette:** dark wet-looking limestone, rust-red iron, dun dust, hot pale sky.
- **Silhouette:** a squat fortress-church with a massive west tower, low walls, high roof.
- **Soundscape:** wind, bell, Latin, then absence.
- **Massacre handling (mandatory):** the killing after surrender is `attested` and is shown as consequence, not spectacle. The column leaves through the sally gate; the player is held at the gate, or sees from the wall, or follows later. No killing animation, no cheering crowd, no gore decals, no score cue that rewards it. In phase B the meadow carries objects, a hush, a few named burials and a chaplain's list. Both sides are shown with fear and shame; the rebels are not cartoon barbarians and the Order is not simple victims (the same Order holds Paide). The player may warn or protect individuals, which changes survivors and evidence only (per [`CANON.md`](../CANON.md)). Include a content/accessibility note and a skip option for the gate scene.
- **Anachronism:** no ruin look, no Maasilinna as built, no Kuressaare, no windmills, no gunpowder.
- **Canon risk:** do not turn Pöide into a Paide palette-swap (the greybox copy is the first fix). Do not give the dead a count.
- **Scope:** 84x52 is a widening of the existing greybox; two new parts (`asset.poide.fortified_church`, `asset.poide.sally_gate`) are the cost, offset by reusing the kit.
- **Performance:** one large dense building plus crowds; use phase swaps rather than simultaneous states.
- **Open questions:** (1) May the player prevent the killing entirely? (default: no). (2) How is the player shown to be complicit if siege iron was forged? (3) Is a second church interior visit needed? (4) Should Karja be a short separate node later? (scope gate).

## 11. Sources and next steps

Repo: [`CANON.md`](../CANON.md), [`HISTORY.md`](../../history/HISTORY.md), [`siege_of_pöide_castle.md`](../../wiki/events/siege_of_pöide_castle.md), [`battle_of_karja_fortress.md`](../../wiki/events/battle_of_karja_fortress.md), [`p6_001_act3_design.md`](../reports/p6_001_act3_design.md), [`saaremaa_kaali_location_design.md`](../reports/saaremaa_kaali_location_design.md), [`poide_castle.md` (legacy)](../../scenes/world/poide_castle.md), [`maasilinna_castle.md` (legacy)](../../scenes/world/maasilinna_castle.md), [`livonian_order.md`](../CITIZENS/factions/livonian_order.md). External by name: Livonian Order castle typology; Estonian National Heritage Board records for Pöide church; chronicle tradition on the 1343 rising.

Verification tasks: (1) confirm the castle-church layout and extent of 1343 destruction; (2) check surviving Pöide church architecture (tower, attic) against the proposal; (3) verify chronicle wording on the surrender; (4) replace the Paide-shaped greybox with a Pöide-specific blueprint per [`MAP_AUTHORING.md`](../MAP_AUTHORING.md); (5) sensitivity and accessibility review of the gate scene; (6) coordinate with [`saaremaa.md`](saaremaa.md) on the oath state flags.
