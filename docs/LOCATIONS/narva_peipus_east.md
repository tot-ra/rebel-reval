# Narva and the Peipus shore (Narwa, Narova crossing)

**Status:** planned (design proposal, not implemented) · **Scope gate:** new (needs ADR + task) · **Act(s):** Act 2 (rumour and emissary corridor), Act 3 (smuggling, 1346 sale)
**Map id:** `loc.world_narva` (proposed; no `.rrmap` exists) · **Seasons/phases:** late spring 1343 (river in flood), summer 1343, deep winter 1345 (frozen river and lake)
**Confidence summary:** Danish Narva castle and the river crossing are `attested` (details of 1343 extent `plausible composite`); Novgorod-sphere east bank, Orthodox Votic/Izhorian/Russian culture and Peipus fisheries are `attested` in outline; the Narva rapids and salmon are `attested` (natural facts); all named persons are `invented` or `plausible composite`.

> **Corrections to existing repo text.** [TOURIST_LANDMARKS.md](../TOURIST_LANDMARKS.md) rows 81-82 call Narva a "Teutonic castle" with "Hermann Castle" and "Ivangorod" opposite. In 1343 Narva belonged to the **Danish crown** (sold with the Duchy in 1346), the tall Hermann tower and its later Order stone castle are not 1343 form, and the **Ivangorod fortress was founded in 1492**. This page uses only a generic Novgorod-sphere bank and settlement. Row 84 (Kallaste Old Believers, 17th c.) and Petseri (1473) are likewise excluded.

## 1. Why a player would want to visit

- A **border river**: Danish castle on one bank, Novgorod-sphere settlement on the other, with a rapids and a bridge-less ford or ferry between them.
- **Another faith and rite**: Orthodox chapels, icons, bells, beeswax, birch-bark documents. The visit shows what Reval's `pskov_novgorod` faction left behind.
- **Salmon, lamprey, and Lake Peipus fishing**, with ice-fishing in winter.
- **Smuggling and the emissary corridor** between Reval and Pskov/Novgorod.
- **Signature:** a roaring river, wooden Orthodox chapels and a Danish stone castle facing each other across rapids.

## 2. History in 1343

| Claim | Label | Note |
|---|---|---|
| Narva castle and settlement belong to the Danish crown | `attested` | Passes with the Duchy in 1346 |
| Castle form: small stone and timber fort at the crossing with a vogt/captain | `plausible composite` | Exact 1343 stone state unverified; Hermann tower is later |
| Town charter under Lübeck law | `plausible composite` | Reported around the mid-14th century; unverified, avoid dating on screen |
| East bank under Novgorod (Vod pyatina administration, pogost parishes) | `attested` (institution) / `plausible composite` (local detail) | No fortress named; use generic "east bank pogost" |
| Votes (Vod) and Izhorians live east and southeast of Narva; Estonians live west and along the Peipus coast | `attested` (general ethnography) | Mixed villages are `plausible composite` |
| Narva rapids and waterfall; Narva salmon and lamprey fishing | `attested` | Natural; the large mill and factory complex at Kreenholm is 19th c. |
| Battle on the Ice, 1242, remembered | `attested` (event) / `folklore` (how locals tell it) | Optional lore |
| Pskov effectively separate from Novgorod by 1343; Prince Ivan of Pskov in May 1343 | `attested` (see [CANON.md](../CANON.md)) | Emissary corridor, not an army |
| Old Believers | **Not present** | They arrive after the 17th century; do not show |

Phases:
- **Act 2:** rumours of the Order and rebels travel along the road; Pskov force heads to Otepää.
- **Act 3:** after the uprising, Danish control slips; in 1346 the sale changes the flag, not the people.
- Do not show: Ivangorod fortress, Hermann tower in its late form, Kreenholm, Petseri, Kallaste Old Believers, brick Orthodox churches with onion domes (use a small timber chapel with a simple cupola, `plausible composite`).

## 3. Landscape and layout

Biome: **river gorge and limestone-edged banks** with alder and willow, then wide **reed lakeshore** at Peipus. Spring flood, summer mist at the rapids, deep winter ice.

Proposed map size **96 x 40 cells**: river in the middle, west bank Danish, east bank Novgorod sphere. A Peipus shore sub-zone is a second strip of the same map (not another node).

| Zone | Cells | Reads as | Carries |
|---|---|---|---|
| West road and customs | x0-20, y14-34 | Road, toll post, wagons | `road_from_rakvere`, `landmark_toll_post` |
| Danish castle and town | x20-44, y6-26 | Small stone and timber castle, timber houses | `landmark_castle_gate`, `landmark_vogt_hall` |
| Rapids and falls | x40-58, y10-34 | White water, rocks, fish weirs | `landmark_rapids`, `landmark_salmon_weir` |
| Crossing | x44-56, y22-30 | Ferry rope or ice road | `landmark_ford_crossing` |
| East bank settlement | x56-80, y8-32 | Log houses, a small timber chapel, bell frame, trade court | `landmark_east_chapel`, `landmark_trade_yard` |
| Smugglers' islets and reed | x60-96, y30-40 | Reed, hidden boats | `landmark_smuggler_cache` |
| Peipus shore strip | x80-96, y4-30 | Sand, reed, net racks, small wood chapel | `exit_to_peipus` |

Journey edges:

| Edge id (proposed) | To | Notes |
|---|---|---|
| `road_to_rakvere` | `loc.world_rakvere` ([page](./rakvere_wesenberg.md)) | West road |
| `gulf_boat_to_reval` | Reval (existing global map) | Coast boat, explicit loading |
| `east_road_stub` | Offstage | Pskov/Novgorod cities stay non-playable per [CANON.md](../CANON.md) |

## 4. Architecture and built environment

| Element | 1343 state | Material and form | Distinguishing feature |
|---|---|---|---|
| Danish castle | Small fort at the crossing | Limestone rubble, timber hoardings | Smaller than Rakvere; river bound |
| West town | Log houses, tolls, warehouses | Log, shingle | Customs-minded |
| East chapel | Small timber Orthodox chapel with a cupola and bell frame | Log, shingle, painted door (`plausible composite`) | Orthodox cross, iconostasis inside |
| Trade yard | Log courtyard with warehouse | Log, birch bark | Novgorod-style |
| Fish weirs and drying racks | Stakes, nets, racks | Pole and willow | Natural craft |
| Smuggler hides | Reed islets | Reed and boat | Hidden cache |

## 5. Cultures, languages, and people

| Group | Language | Dress and craft | Religion and custom |
|---|---|---|---|
| Danish crown garrison | Danish, German | Gambeson, crown tabard | Catholic |
| West-bank Estonians | North-eastern Estonian dialect | Wool, bast shoes | Catholic and older custom |
| Votes (Vod) and Izhorians | Votic and Izhorian (Finnic languages, `attested` in outline) | Linen and wool, beaded headwear (`plausible composite`) | Orthodox with older custom |
| Russians of the Novgorod sphere | Old Russian (Novgorod dialect) | Long kaftan, belted tunic, fur hat | Orthodox rite |
| Peipus Estonian fishers | Estonian | Oiled wool, felted hats | Mixed rite, `plausible composite` |
| Merchants and couriers | Low German, Russian | Merchant wool | Catholic or Orthodox |

Names: Russian patronymic style (see [anisia_of_novgorod.md](../CHARACTERS/anisia_of_novgorod.md) for the naming rule), Votic names are `plausible composite`.

## 6. Factions present

| Faction id | Presence | Wants | Where | Act-by-act |
|---|---|---|---|---|
| `pskov_novgorod` | Emissaries, traders, icon painters | Pass messages to Reval, weaken the Order | East bank, trade yard | A2 corridor; A3 trade |
| `danish_crown` | Vogt and small garrison | Keep tolls and the crossing | Castle | Sale in 1346 |
| `livonian_order` | Agents buying toll rights | Prepare to inherit | Customs | A2-A3 |
| `hanseatic` | Merchants | Control grain and furs | West trade | Constant |
| `harju_kings` | Eastern Viru contingents (small) | Close the road | Forest edge | A2 only |
| `black_cloaks` | Couriers | Smuggle messages | Smugglers' islets | A2 |
| `vitalienbruder` | Not in 1343 | - | - | Use an `invented` Gulf captain only in Act 3 |
| `cult_metsik` | Rumour | Spirit place | Rapids | Optional |

## 7. Characters

| char id | Name | Role | Language | Confidence | Source | Hook |
|---|---|---|---|---|---|---|
| `char.goytan` | Goytan | Icon painter, Novgorod | Old Russian | `invented` | legacy ([brief](../../characters/novgorod/goytan.md)) | Chapel commission |
| `char.prokhor_gorodets` | Prokhor of Gorodets | Young icon master | Old Russian | `invented` | legacy ([brief](../../characters/novgorod/prokhor_of_gorodets.md)) | Pigment errand |
| `char.mihail_kolovrat` | Mihail Kolovrat | Pskov scout | Old Russian | `invented` (name echoes a later hero; anachronism risk) | legacy ([brief](../../characters/pskov/mihail_kolovrat.md)) | Emissary guide; rename if the maintainer prefers |
| `char.anisia_of_novgorod` | Anisia, Ivan's daughter | Caravan girl | Old Russian | `invented` | existing ([brief](../CHARACTERS/anisia_of_novgorod.md)) | Cameo only |
| `char.dmitri_stepanovich` | Dmitri Stepanovich | Orthodox priest from Reval's Novgorod court | Old Russian | `plausible composite` | existing ([census page](../CITIZENS/people/lower_town/dmitri_stepanovich.md)) | Travels home |
| `char.konrad_preen` | Konrad Preen | Viceroy (offstage) | Danish, German | `plausible composite` | existing ([brief](../CHARACTERS/konrad_preen.md)) | Letter |
| `char.apprentice` | Apprentice | Protagonist | Estonian | existing | [brief](../CHARACTERS/apprentice.md) | Spirit-world salmon scene |
| `char.narva_vogt` | Vogt Eske (placeholder) | Danish captain | Danish | `invented` | NEW | Toll and bribe |
| `char.votic_fisher` | Old Vote fisherwoman Irja | Peipus fisher | Votic | `invented` | NEW | Weir guide |
| `char.smuggler_gulf` | Captain Raud | Gulf smuggler | Estonian, Low German | `invented` | NEW | Cache |
| `char.border_priest_east` | Father Sava | Orthodox priest | Old Russian | `invented` | NEW | Blessing, confession |

Crowd archetypes: salmon weir keeper, toll clerk, ferryman, beeswax trader, bell-ringer, net mender.

## 8. Quests, encounters, and discoveries

| id | Act | Type | Hook | Ties |
|---|---|---|---|---|
| `quest.narva_emissary` | 2 | travel event | Escort a Pskov emissary to the road west | `faction.pskov_novgorod` |
| `quest.chapel_bell_hinge` | 2 | forge commission | A bell frame hinge for the east chapel | Kalev's craft |
| `quest.smuggler_cache` | 2 | night mission | Retrieve a cache before the toll post inspects | `faction.black_cloaks` |
| `quest.salmon_spirit` | 3 | spirit-world | The river's spirit demands a measure | ADR 0033 |
| `quest.peipus_ice_road` | 3 | exploration | Cross the frozen lake with a fisher | Winter |

Sights: birch-bark letter written in Old Russian; the rapids at spring flood; a Votic woman's headdress; a salmon weir; an icon panel in the chapel.

## 9. Resources: what must be generated

### 9.1 Structures & architecture

| asset id | Description | Priority | Shared with | Notes |
|---|---|---|---|---|
| `asset.struct.narva_castle_1343` | Small stone river fort | P1 | Rakvere kit (`asset.kit.limestone_castle`) | Cited from [rakvere_wesenberg.md](./rakvere_wesenberg.md) |
| `asset.struct.orthodox_timber_chapel` | Log chapel with cupola and bell frame | P1 | Reval Vene church | Defined here |
| `asset.kit.log_trade_yard` | Log courtyard, warehouse, gate | P2 | Rakvere inn kit | - |
| `asset.struct.salmon_weir` | Stake weir and platform | P1 | Peipus | - |
| `asset.struct.ferry_rope_landing` | Rope ferry | P2 | Haapsalu quay | - |
| `asset.kit.fish_rack_town` | See [haapsalu_laanemaa.md](./haapsalu_laanemaa.md) | - | cited | - |

### 9.2 Props & craft objects

| asset id | Description | Priority | Shared with | Notes |
|---|---|---|---|---|
| `asset.prop.icon_panel` | Egg-tempera panel, saint with gold ground | P1 | Reval Vene | No post-1400 style; Rublev-era wink only |
| `asset.prop.birch_bark_letter` | Birch-bark document | P1 | Reval | Novgorod finds |
| `asset.prop.beeswax_cake` | Wax cakes | P2 | Reval | - |
| `asset.prop.orthodox_cross_eight` | Eight-point cross, wood/silver | P2 | - | - |
| `asset.prop.bell_small` | Hand bell | P2 | - | - |
| `asset.prop.votic_headdress` | Beaded woman's headdress | P3 | - | Careful |
| `asset.prop.lamprey_basket` | Wicker trap | P2 | - | - |
| `asset.prop.fur_bundle` | Marten and squirrel furs | P2 | Reval | - |

### 9.3 Characters

| asset id | Description | Priority | Shared with | Notes |
|---|---|---|---|---|
| `asset.char.wardrobe.novgorod_kaftan` | Long tunic, belt, fur hat | P1 | Reval Vene | - |
| `asset.char.wardrobe.orthodox_priest` | Cassock, kamilavka-type cap (unverified form) | P2 | - | - |
| `asset.char.wardrobe.votic_woman` | Linen with beaded headwear | P2 | - | - |
| `asset.char.wardrobe.peipus_fisher` | Oiled wool, felt hat | P2 | - | - |
| `asset.char.beard.orthodox_full` | Full beards | P2 | - | MPFB |

### 9.4 Fauna

| Species | Status | Notes |
|---|---|---|
| Common gull, osprey, white-tailed eagle, grey heron, mallard, hooded crow | already cataloged | - |
| Otter, beaver, elk, wolf | already cataloged | - |
| Horse, cow, sheep, chicken | already cataloged | - |
| Atlantic salmon, lamprey, pike, whitefish, smelt, bream (fish) | missing, P1 (fish props and weir) | Rapids |
| Sand martin | missing, P3 | Banks |

### 9.5 Flora & ground cover

| Item | Status | Notes |
|---|---|---|
| `tree.alder`, `tree.willow`, `tree.pine`, `tree.birch`, `plant.reed`, `plant.cattail`, `plant.fern`, `plant.moss` | existing | - |
| `ground.river_gravel` | missing, P2 | Shore |
| `plant.meadowsweet`, `plant.angelica` | missing, P3 | Wet meadow |

### 9.6 Materials / terrain / water

| asset id | Description | Priority |
|---|---|---|
| `water.rapids_foam` | White-water shader with foam | P1 |
| `water.frozen_river_ice` | Ice surface | P2 |
| `mat.log_weathered_grey` | Grey weathered logs | P1 |

### 9.7 Audio & music direction

Languages: Old Russian, Votic, Estonian, Danish, Low German. Ambient: rapids roar, bells, nets, ravens, ice cracking in winter. Music: unaccompanied Orthodox chant (`plausible composite`), gusli-like plucked string, and a plain pipe. The roar of the falls should mask dialogue at the weir.

## 10. Variety signature and risks

Palette: foam white, wet black logs, gold of icon grounds. Silhouette: two banks, a cupola against a stone tower. Soundscape: rapids and bells.

Risks: anachronism (Ivangorod, Hermann tower, Old Believers, brick onion domes, Kreenholm); ethnicity and religion handled with care (Votes, Izhorians, Russians); `char.mihail_kolovrat` name echoes a later figure; scope (two banks, water shaders); sensitivity of the border and modern Narva today.

**Scope gate:** `new`. Could replace or compress: the `pskov_novgorod` Act 2/3 mission content already planned in Reval (fold the emissary corridor into a single travel event), or the unactivated `world_parnu` side content. The Peipus strip stays inside this map, not a separate node.

Open questions: Is a river crossing worth a standalone map versus one cutscene? Rename Mihail Kolovrat? Which date for the Narva charter?

## 11. Sources and next steps

- Repo: [CANON.md](../CANON.md), [TOURIST_LANDMARKS.md](../TOURIST_LANDMARKS.md), [pskov_novgorod](../CITIZENS/factions/pskov_novgorod.md), [danish_crown](../CITIZENS/factions/danish_crown.md), [anisia_of_novgorod.md](../CHARACTERS/anisia_of_novgorod.md), [FLORA_FAUNA.md](../FLORA_FAUNA.md), legacy rosters in [characters/novgorod](../../characters/novgorod/goytan.md).
- External by name only: Novgorod birch-bark letters corpus; Estonian and Russian histories of Narva; Votic and Izhorian ethnography.
- Verification tasks: confirm Narva's 1343 castle form and charter date; confirm Novgorod pogost naming on the east bank; confirm Danish crown banner; decide naming for the Pskov scout; verify salmon and lamprey fishery rights.
