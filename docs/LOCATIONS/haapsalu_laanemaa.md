# Haapsalu (Hapsal, Läänemaa, seat of Ösel-Wiek)

**Status:** planned (design proposal, not implemented) · **Scope gate:** new (needs ADR + task) · **Act(s):** Act 2 (western rising, optional), Act 3 (aftermath, bishop's reckoning)
**Map id:** `loc.world_haapsalu` (proposed; no `.rrmap` exists) · **Seasons/phases:** spring-summer 1343 (siege), autumn 1343 (relief and reprisals), winter 1345
**Confidence summary:** the bishop's seat at Haapsalu, a convent-type castle and a cathedral are `attested`; the Läänemaa siege is `attested` as tradition only (CANON); Estonian Swedes in the region are `attested` as a settlement but exact 1343 details are `plausible composite`; the White Lady is `folklore (later attestation)`; every named person below is `invented` unless stated.

## 1. Why a player would want to visit

- The one node where the **Church, not the Order or the Crown,** is the besieged lord: a bishop in a sea-edge castle with a chapter that argues in its own hall.
- A **distinctive single-nave cathedral and a baptistery**: stone that looks like nothing in Reval.
- **Coast of reeds, mud flats, and shallow water** where tide rarely matters but wind does; the sea is the escape route and the trap.
- **Estonian Swedes** from Noarootsi and Vormsi arriving by boat, with their own language and costume: the only non-Estonian, non-German, non-Russian culture on the map.
- **Signature:** a pale stone castle-cathedral ensemble on a flat reed bay, besieged by Läänemaa farmers who know every ford.

## 2. History in 1343

| Claim | Label | Note |
|---|---|---|
| Haapsalu is the seat of the Bishop of Ösel-Wiek | `attested` | The see moved from Lihula to Haapsalu in the 13th century; exact year unverified here |
| Convent-type castle (quadrangular ranges around a court) with a cathedral attached | `attested` (type) / `plausible composite` (1343 extent) | Parts of the later castle date after 1343; show a smaller core |
| Cathedral as a single-nave church with an unusual baptistery | `attested` (the building type) / `plausible composite` (what is complete in 1343) | Construction phases unverified; treat the baptistery as an early-14th-century addition, unverified |
| Bishop Hermann II Osenbrügge (see doubt below) | `attested` (bishop of the period) | Date range conflict flagged |
| Läänemaa rebels besiege the seat in 1343 | `attested` (siege tradition per [CANON.md](../CANON.md)); event note at [siege_of_haapsalu_castle.md](../../wiki/events/siege_of_haapsalu_castle.md) is one line | No detailed chronicle; all siege beats are `invented` |
| Swedes on Vormsi, Noarootsi and Rickul under the bishop | `attested` (settlement) / `plausible composite` (rights, customs) | Treat language and dress with care |
| White Lady ghost | `folklore (later attestation)` | A later local tradition; keep optional and never required for a main quest |

Factual doubt: [characters/bishopric_osel_wiek/README.md](../../characters/bishopric_osel_wiek/README.md) gives Hermann's reign as 1338-1362; other sources suggest a longer reign. The legacy [haapsalu_castle.md](../../scenes/world/haapsalu_castle.md) makes the bishop "in his 60s" while his brief says late 50s, and says "the Order has a strong interest in defending" it. Neither is verified; this page keeps him late 50s and the Order as a visitor, not a garrison.

Phases:
- **Act 2:** rebels gather, siege begins; relief expected from Order and the Reval side.
- **Act 3:** relief or fall depends on offstage events; bishop negotiates and seeks the Archbishop of Riga and Dorpat.
- Do not show: Haapsalu spa buildings, Kuursaal, the long promenade, Haapsalu shawls (19th c.), the 16th-century Swedish-period bastions, a railway station.

## 3. Landscape and layout

Biome: **flat west-coast bay**, wide reed beds, shallow mud, low juniper meadow with alvar-like limestone patches. Light is grey-silver. Wind, gulls, and long horizons.

Proposed map size **92 x 40 cells**.

| Zone | Cells | Reads as | Carries |
|---|---|---|---|
| Landward road and rebel lines | x0-22, y10-34 | Cut field, earthworks, sapper trench, ox carts | `road_from_lihula`, `landmark_siege_line` |
| Outer town | x22-42, y18-36 | Timber streets, fish racks, chapel | `landmark_market_place` |
| Castle ward | x42-70, y8-28 | Convent-type castle, court, well, chapter hall | `landmark_castle_gate`, `landmark_court` |
| Cathedral | x48-66, y10-22 | Single-nave church, baptistery | `landmark_cathedral`, `landmark_baptistery` |
| Bay shore and quay | x58-92, y22-40 | Reed, mud, boat landing, tar pit | `ferry_to_vormsi`, `landmark_quay` |
| Reed island | x74-92, y26-40 | Reed-cutter huts, hide | Optional spirit-world scene |
| Coastal meadow and juniper | x0-24, y34-40 | Cattle track | Wild margin |

Journey edges:

| Edge id (proposed) | To | Notes |
|---|---|---|
| `road_to_harju` | `loc.world_harju` | Overland east; long road |
| `boat_to_saaremaa` | `loc.world_saaremaa` ([map](../../content/maps/world_saaremaa.rrmap)) | Sea; Act 3 route |
| `boat_to_vormsi` | optional sub-zone | Swedes' arrival; not a new map |
| `road_to_padise` | `loc.world_padise` (`map`) | Overland |

## 4. Architecture and built environment

| Element | 1343 state | Material and form | Distinguishing feature |
|---|---|---|---|
| Castle | Convent-type quadrangle: four ranges around a court, one gate tower, chapter hall; timber galleries over stone | Limestone and rubble, lime plaster, shingle or ceramic tile | Court inside a plain stone rectangle, sea-flat setting |
| Cathedral | Single-nave stone church, steep roof, small tower or ridge turret | Limestone ashlar with plain buttresses | Single wide nave, no side aisles |
| Baptistery | Large stone annex on the church | Same stone, high windows | Unusual size for the region (`plausible composite` on form) |
| Chapter hall | Stone first-floor hall | Same | Canons' meetings |
| Outer town | Timber houses, fish-drying racks, tar sheds | Log, wattle, shingle | Fishing town, not Hanseatic |
| Swedish farm and boat sheds | Low log houses | Timber, thatch | Different house proportions (unverified) |

## 5. Cultures, languages, and people

| Group | Language | Dress and craft | Religion and custom |
|---|---|---|---|
| Läänemaa Estonian peasants (rebel and non-rebel) | West-Estonian (Läänemaa) dialect | Wool tunic, belt knife, bast shoes, sheepskin | Catholic with older custom |
| Bishop's household and canons | Latin, Low German | Black or purple wool, rochet | Catholic |
| Bishop's vassal knights | Low German | Mail, tabard in diocesan colours (unverified) | Catholic |
| Estonian Swedes (Noarootsi, Vormsi) | Old Swedish dialect (Estonian Swedish) | Striped wool, distinctive caps (details `plausible composite`) | Catholic |
| Coastal fishers and reed-cutters | Estonian | Oiled wool, net floats | Folk custom |
| Hanseatic or Lübeck traders | Low German | Merchant wool | Catholic |

Names: Estonian forenames per [estonian-forenames-harju-1340s.md](../../history/dossiers/language/estonian-forenames-harju-1340s.md) (proxy), Swedish names from later Estonian Swedish records are `plausible composite`.

## 6. Factions present

Note: Bishoprics are background canon / candidate lines (ADR 0017), not launch factions; the bishop appears through `church` affinity and as a power inside the other ledgers.

| Faction id | Presence | Wants | Where | Act-by-act |
|---|---|---|---|---|
| `church` (affinity) | Bishop, chapter, priests | Hold the see, survive, avoid Order help | Castle, cathedral | A2 besieged; A3 reckoning |
| `harju_kings` | Läänemaa leaders (a western branch) | Break the seat, free the land | Siege line | A2 |
| `livonian_order` | Envoy knight, observer | Intervene as protector | Gate | A2-A3 |
| `hanseatic` | Boat merchants | Open the quay | Quay | Constant |
| `danish_crown` | Low | Neutral | - | Background |
| `cult_metsik` | Reed-island shaman | Spirit-place, omens | Reed island | Optional |
| `vitalienbruder` | None in 1343 | - | - | Do not place; tie only through the Act 3 sea |

## 7. Characters

| char id | Name | Role | Language | Confidence | Source | Hook |
|---|---|---|---|---|---|---|
| `char.hermann_osenbrugge` | Bishop Hermann II Osenbrügge | Bishop | Latin, Low German | `attested` (person), `plausible composite` (behaviour) | legacy [brief](../../characters/bishopric_osel_wiek/hermann_osenbrugge.md) | Negotiation |
| `char.brother_hermann` | Brother Hermann | Order handler | German | `plausible composite` | existing ([brief](../CHARACTERS/brother_hermann.md)) | Relief offer |
| `char.apprentice` | Apprentice | Protagonist | Estonian | existing | [brief](../CHARACTERS/apprentice.md) | Spirit scenes |
| `char.kalev` | Kalev | Smith | Estonian | existing | [brief](../CHARACTERS/kalev.md) | Chain and bell repair |
| `char.haapsalu_captain` | Captain of the castle guard | Defender | Low German | `invented` | legacy seed [haapsalu_castle.md](../../scenes/world/haapsalu_castle.md) | Gate mission |
| `char.haapsalu_siege_leader` | Läänemaa rebel siege leader | Rebel | West Estonian | `invented` | legacy seed | Parley |
| `char.haapsalu_chaplain_scribe` | Bishop's scribe | Chronicler | Latin | `invented` | legacy seed | Records |
| `char.haapsalu_healer` | Castle healer | Healer | Estonian | `invented` | legacy seed | Herbs |
| `char.swedish_skipper` | Skipper Olof (placeholder) | Estonian Swede | Swedish dialect | `invented` | NEW | Boat to Vormsi |
| `char.reed_cutter_old` | Old reed-cutter Ants | Local guide | West Estonian | `invented` | NEW | Hidden path |
| `char.canon_traitor` | A canon, name TBD | Possibly negotiating | Latin | `invented` | legacy seed (cathedral chapter in README) | Betrayal |

Crowd archetypes: salt fisher, reed-cutter, tar-burner, bishop's servant, chandler, ferrywoman, siege carter.

## 8. Quests, encounters, and discoveries

| id | Act | Type | Hook | Ties |
|---|---|---|---|---|
| `quest.haapsalu_gate_chain` | 2 | forge commission | Gate chain broken in the siege | `quest.bell_and_chain` echo |
| `quest.canon_letter` | 2 | investigation | Who writes to the Order? | `faction.livonian_order` |
| `quest.reed_path` | 2 | night mission | Carry medicine through the reeds | - |
| `quest.swedes_boat` | 3 | travel event | Help Swedes cross to Vormsi | - |
| `quest.white_lady_tale` | any | spirit-world (optional) | A voice tied to a later tradition | `folklore (later attestation)` |

Sights: the single-nave cathedral and baptistery; the reed bay at dawn; a Swedish boat; the bishop's chapter seal; a fish-drying rack.

## 9. Resources: what must be generated

### 9.1 Structures & architecture

| asset id | Description | Priority | Shared with | Notes |
|---|---|---|---|---|
| `asset.kit.convent_castle` | Convent-type quadrangle castle kit: four ranges, court, gate, galleries | P1 | Padise (monastic ranges) | Defined here |
| `asset.struct.haapsalu_cathedral` | Single-nave cathedral | P1 | - | Plain buttresses |
| `asset.struct.baptistery_annex` | Baptistery | P2 | - | Label dates |
| `asset.kit.limestone_castle` | See [rakvere_wesenberg.md](./rakvere_wesenberg.md) | - | cited only | - |
| `asset.kit.fish_rack_town` | Fish racks, tar shed, boat sheds | P2 | Narva | - |
| `asset.struct.swedish_farmstead` | Low log house, boat shed | P2 | - | `plausible composite` |

### 9.2 Props & craft objects

| asset id | Description | Priority | Shared with | Notes |
|---|---|---|---|---|
| `asset.prop.episcopal_crozier` | Silver-and-wood crozier | P2 | - | - |
| `asset.prop.chapter_seal` | Seal die | P2 | Rakvere | - |
| `asset.prop.reliquary_plain` | Small reliquary | P2 | Padise | Not a real relic |
| `asset.prop.siege_pavise` | Wooden shield | P2 | - | - |
| `asset.prop.fish_net_float` | Net and floats | P2 | Narva | - |
| `asset.prop.swedish_textile_stripe` | Striped wool cloth | P3 | - | - |

### 9.3 Characters

| asset id | Description | Priority | Shared with | Notes |
|---|---|---|---|---|
| `asset.char.wardrobe.bishop` | Cassock, rochet, cope, mitre | P1 | Reval clergy | - |
| `asset.char.wardrobe.canon` | Canon's black habit | P2 | - | - |
| `asset.char.wardrobe.estonian_swede` | Striped wool, caps | P2 | - | Careful |
| `asset.char.wardrobe.reed_cutter` | Oiled wool, bast waders | P2 | - | - |
| `asset.char.wardrobe.western_rebel` | Sheepskin, bearskin cloak per legacy seed | P2 | - | - |

### 9.4 Fauna

| Species | Status | Notes |
|---|---|---|
| Herring gull, common tern, mallard, mute swan, grey heron, cormorant, greylag goose | already cataloged | Bay |
| Grey seal, ringed seal, otter | already cataloged | Coast |
| Cattle, sheep, pig, chicken, horse | already cataloged | - |
| Avocet, redshank, bar-tailed godwit | missing (P3) | Bay waders |
| Eider, tufted duck | missing (P3) | - |
| Flounder, perch, pike (fish props) | missing (P2) | Fish racks |

### 9.5 Flora & ground cover

| Item | Status | Notes |
|---|---|---|
| `plant.reed`, `plant.cattail`, `tree.juniper`, `tree.alder`, `tree.willow`, `grass.dry` | existing | Core |
| `plant.sea_lavender`, `plant.glasswort`, `plant.sea_buckthorn` | missing, P3 | Coastal margin |
| `ground.mudflat` | missing, P1 | Reed bay |

### 9.6 Materials / terrain / water

| asset id | Description | Priority |
|---|---|---|
| `water.shallow_bay_mud` | Silty shallow water | P1 |
| `mat.limestone_grey_plastered` | Plastered stone | P2 |
| `terrain.reed_belt` | Reed belt | P1 |

### 9.7 Audio & music direction

Languages: West Estonian, Low German, church Latin, Swedish dialect. Ambient: wind in reeds, gulls, bells, ropes, tar fires, distant siege horns. Music: plainchant for the cathedral, a thin female choir for the besieged, drums for the rebels, a dry kantele-like strumming for the Swedes (unverified). The White Lady cue is optional: a solo voice only, never a glass harmonica (that instrument is a later invention; legacy seed note flagged).

## 10. Variety signature and risks

Palette: grey-silver water, pale plaster, rust-brown reed, black cassocks. Silhouette: low castle block and one steep church roof against a flat horizon. Soundscape: reeds, gulls, plainchant.

Risks: anachronism (spa, shawls, bastions, glass harmonica); the siege has only a one-line source so all beats must carry `invented`; sensitivity around Swedes (ethnicity and rights) and around killings of priests; scope (a castle plus cathedral is the heaviest kit).

**Scope gate:** `new`. Could replace or compress: the Act 2 side content for `world_parnu`, or merge Haapsalu's siege as a short travel event reached from `world_saaremaa` so only the bay and cathedral exist as one reduced map. Both halves of the Church story (chapter and bishop) should reuse the Padise monastery kit.

Open questions: Is a bishop's siege required, or can it be a rumour? Should the White Lady be omitted entirely? Which date for the baptistery?

## 11. Sources and next steps

- Repo: [CANON.md](../CANON.md), [TOURIST_LANDMARKS.md](../TOURIST_LANDMARKS.md), [siege_of_haapsalu_castle.md](../../wiki/events/siege_of_haapsalu_castle.md), [haapsalu_castle.md](../../scenes/world/haapsalu_castle.md), [bishopric README](../../characters/bishopric_osel_wiek/README.md), [saaremaa_kaali_location_design.md](../reports/saaremaa_kaali_location_design.md), [FLORA_FAUNA.md](../FLORA_FAUNA.md), [church](../CITIZENS/factions/church.md).
- External by name only: Estonian heritage records on Haapsalu castle and cathedral; Estonian Swedes studies; Henry of Livonia for the pre-1343 background.
- Verification tasks: bishop's reign dates; cathedral and baptistery construction phases; Läänemaa siege sources; date of the Noarootsi Swedes' privileges; confirm Lihula-to-Haapsalu transfer date.
