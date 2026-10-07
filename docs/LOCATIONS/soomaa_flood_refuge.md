# Soomaa Flood Refuge (spring flood plains and raised bog of the Pärnu/Viljandi hinterland; 1343 name unverified)
**Status:** planned (design proposal, not implemented) · **Scope gate:** new (needs ADR + task) · **Act(s):** Act 2 finale aftermath, Act 3 (refuge, Hingepuu link)
**Map id:** `loc.world_soomaa` (proposed; no `content/maps/` file yet) · **Seasons/phases:** Apr-May 1343 (the "fifth season" flood), Jul 1343 (dry bog, berries, mosquitoes), winter 1344 (frozen bog, hard travel)
**Confidence summary:** wetland geography `attested`; the name "Soomaa" and the "fifth season" are modern usage, so their medieval use is `plausible composite`; use of bog paths by rebels is `plausible composite` (see [TOURIST_LANDMARKS.md](../TOURIST_LANDMARKS.md) item 54); dugout boats `plausible composite` for 1343; spirit-world link `folklore` / `invented`.

## 1. Why a player would want to visit
- The one node where the floor is water: spring floods turn meadows, alder carr and forest edge into a lake, and the player poles a dugout boat between tree crowns.
- A hidden refuge for survivors of Sõjamäe/Paide: the player finds out who got away and what they carry.
- A true wilderness with predators (wolf, lynx, bear) and wildfowl; the sound of cranes at dawn.
- A second, quiet spirit-world access point beside the sacred grove: bog pools as mirrors.
- **Signature:** "the node with no ground": dark water, peat, floating mats, mist, boats.

## 2. History in 1343
| Claim | Label | Note |
|---|---|---|
| Large raised bogs and river floodplains lie in the Pärnu/Viljandi hinterland (Raplamaa/Sakala borders, Halliste, Raudna, Navesti rivers; Kuresoo and Öördi bogs by modern names) | `attested` geography | Modern names not used in game dialogue |
| Spring flood in March-May, locally the "fifth season" | `attested` modern ethnography; medieval use `plausible composite` | Fits April-May |
| Dugout/plank boats (haabjas, aspen dugout) used for flood travel | `plausible composite` | Earliest documented use of the exact boat type is later; label |
| Rebel survivors retreat into bog country after Sõjamäe (14 May) and Paide | `plausible composite` | Order horses refuse bog paths ([TOURIST_LANDMARKS.md](../TOURIST_LANDMARKS.md) item 54) |
| Hingepuu / bog pool spirit gate | `folklore` / `invented` | Per [CANON.md](../CANON.md) spirit-world section |
| Bog bodies, ancient wooden causeways | `plausible composite` (prehistoric/medieval bog trackways exist in Baltic) | Do not claim a specific find |
**Phases.** Act 2: refugees arrive wet and hungry; Order scouts probe. Act 3: the refuge is a hidden vault of lost people and resources; winter freeze lets horses in.
**Do NOT show:** modern boardwalks, observation towers, canoe tourists, peat-cutting industry, cranberry plantations, bison/aurochs (aurochs extinct in Estonia early; bison absent).

## 3. Landscape and layout
**Biome:** raised bog, flooded meadow and alder carr (see [BIOMES_AND_WILDLIFE.md](./BIOMES_AND_WILDLIFE.md)). Water level is dynamic: April-May high flood, July low.
**Map footprint (proposed):** about 80 x 30 cells; boat-navigable in spring, walkable on bog paths in summer.

| Zone id | Cells (x) | Content | Season note |
|---|---|---|---|
| `zone_river_ford` | 0-14 | Entry from Pärnu/Sakala road; Halliste-type ford | Flooded in Apr-May: ferry by boat |
| `zone_flood_meadow` | 14-34 | Open sedge meadow turned lake, tree crowns above water | April-May lake; July hay meadow |
| `zone_alder_carr` | 34-50 | Alder and birch swamp forest, aerial roots | Mosquito cloud in July |
| `zone_bog_lagoons` | 50-66 | Raised bog with pools, pine dwarfs, sphagnum, floating mat | Mist, cranes |
| `zone_bog_island` | 66-76 | Dry mineral "island" with refuge huts and stored grain | Camp |
| `zone_hingepuu_pool` | 76-80 | Black pool, a single old birch/pine, spirit gate | `folklore` |

**Landmarks:** `landmark_ford_ferry_post`, `landmark_drowned_meadow_haystack`, `landmark_alder_carr_blind`, `landmark_bog_causeway_logs`, `landmark_refuge_island_huts`, `landmark_crane_dancing_ground`, `landmark_hingepuu_pool`.
**Journey edges:** [parnu.md](./parnu.md) (west by road/ford), [viljandi_fellin.md](./viljandi_fellin.md) (east), [kanavere_bog.md](./kanavere_bog.md) (northern link; different bog, same family of biome), optional spirit-world transit. All explicit travel.

## 4. Architecture and built environment
- `asset.kit.log_hut_refuge` (low log huts on stilts/rafts, bark or sod roof, smoke hole; `plausible composite`).
- `asset.kit.dugout_boat` (aspen dugout ~4-6 m, pole and paddle; `plausible composite`).
- `asset.kit.bog_causeway` (log and brushwood path, `plausible composite`).
- `asset.kit.haystack_on_poles` (flood-meadow hay barn/stack on stilts; `plausible composite`).
- `asset.kit.ferry_and_ford` (shared with [ARCHITECTURE_TYPOLOGY.md](./ARCHITECTURE_TYPOLOGY.md) bridge/ferry/toll types).
No stone, no church; the nearest consecrated site is a small wayside cross on the ford.

## 5. Cultures, languages, and people
| Group | Language | Dress tokens | Religion and custom |
|---|---|---|---|
| Sakala Estonians (South-Estonian dialect) | Estonian, South-Estonian | Wool kirtle, bast shoes, long cloak, felt hat | Baptised but hiis-aware |
| Rebel survivors from Harju | Estonian (north) | Torn campaign clothes, hides | Funerary rites without priests |
| Pärnu boatmen | Estonian + MLG | Tarred jerkin, rope belt | Pilgrim blessings |
| Order patrols | MLG, Latin | Mail, white mantle black cross | |
| Wandering hermit/penitent (`invented`) | Latin fragments | Rough habit | Orthodox or Latin ambiguity |
See [CULTURES_AND_LANGUAGES.md](./CULTURES_AND_LANGUAGES.md).

## 6. Factions present
| Faction id | Presence | Wants | Where | Act-by-act |
|---|---|---|---|---|
| `harju_kings` | Survivors | Hidden supplies, a leader | `zone_bog_island` | A2 end arrive; A3 split |
| `livonian_order` | Scouts, then raids | Capture refugees, grain | `zone_river_ford` | A3 winter incursion |
| `cult_metsik` | Elders | Protect the pool | `zone_hingepuu_pool` | A2-A3 |
| `black_cloaks` | Messenger contact | Forge iron carried in | `zone_bog_island` | A3 |
| `pskov_novgorod` | A trader | Route deals | `zone_river_ford` | A3 |

## 7. Characters
| char id | Name | Role/faction | Language | Confidence | Source | Hook |
|---|---|---|---|---|---|---|
| `char.lembit_helme` | Lembit Helme | Harju Kings elder | Estonian | `plausible composite` | existing, [lembit.md](../CHARACTERS/lembit.md) | Leads survivors |
| `char.ellen` | Ellen Luik | Folklore keeper | Estonian | `plausible composite` | existing, [ellen.md](../CHARACTERS/ellen.md) | Reads the pool |
| `char.kaja` | Kaja | Bilingual courier | Estonian + MLG | `invented` | existing, [kaja.md](../CHARACTERS/kaja.md) | Carries news from Paide |
| `char.mart` | Mart | Apprentice | Estonian | `invented` | existing, [mart.md](../CHARACTERS/mart.md) | Stake in refuge |
| `char.old_toomas` | Old Toomas | Retired smith | Estonian | `invented` | existing, [old_toomas.md](../CHARACTERS/old_toomas.md) | Field-forge repairs |
| `char.soomaa_haabja` | Villu the boatman | Poler, Sakala Estonian | South-Estonian | `invented` | NEW | Ferry and guide |
| `char.soomaa_marta` | Marta Sepp | Widow herbalist | Estonian | `invented` | NEW | Bog herbs, antidotes |
| `char.soomaa_pater` | Pater Anselm | Wandering Latin priest | Latin, MLG | `invented` | NEW | Last rites dilemma |
Crowd archetypes: pole-boatman, reed cutter, peat gatherer, hay-stack keeper, hunter, sentry on a floating mat, wounded rebel.

## 8. Quests, encounters, and discoveries
| id proposal | Act | Type | Hook | Ties |
|---|---|---|---|---|
| `quest.soomaa_the_fifth_season` | 2 end | travel event | Reach the island by boat before the water falls | `flag.sojamae_survivors` (proposed) |
| `quest.soomaa_iron_for_the_island` | 3 | forge commission | Forge nails and hooks for boats | Kalev forge loop |
| `quest.soomaa_pool_that_answers` | 3 | spirit-world | Apprentice reads the pool | [SPIRIT_DIALOGUE.md](../SYSTEMS/SPIRIT_DIALOGUE.md) |
| `quest.soomaa_wolf_winter` | 3 | encounter | Wolf pack stalks refugees | wolf fauna |
**Sights:** crane dancing ground at dawn; flooded meadow with haystacks standing in water; carnivorous sundew (journal); a bog trackway from an earlier age; a boat poled through trees.

## 9. Resources: what must be generated
### 9.1 Structures & architecture
| asset id | Description | Pri | Shared with | Notes |
|---|---|---|---|---|
| `asset.kit.dugout_boat` | Aspen dugout with pole | P1 | [baltic_klint_coast.md](./baltic_klint_coast.md), [parnu.md](./parnu.md), [narva_peipus_east.md](./narva_peipus_east.md) | Defined here |
| `asset.kit.log_hut_refuge` | Raised log huts | P1 | [rebel_kings_camp.md](./rebel_kings_camp.md) | |
| `asset.kit.bog_causeway` | Log path over peat | P1 | [kanavere_bog.md](./kanavere_bog.md) | |
| `asset.kit.haystack_on_poles` | Meadow hay stack/stilt barn | P2 | [harju_village.md](./harju_village.md) | |
### 9.2 Props & craft objects
`asset.prop.fishing_trap_wicker` (weir basket, P2), `asset.prop.bast_shoes_and_snowshoes` (P2), `asset.prop.peat_knife_and_sled` (P3), `asset.prop.birchbark_vessel` (P2), `asset.prop.wolf_pelt_and_antler` (P3). Evidence: ethnographic collections (Estonian National Museum), label `plausible composite`.
### 9.3 Characters
`asset.wardrobe.sakala_peasant` (P1), `asset.wardrobe.wounded_rebel` (P2), `asset.wardrobe.hermit_priest` (P3); reuse MPFB rig.
### 9.4 Fauna
| species | Status | Notes |
|---|---|---|
| Wolf `fauna.wolf`, lynx `fauna.lynx`, brown bear `fauna.brown_bear`, elk `fauna.elk`, beaver `fauna.beaver`, otter `fauna.otter`, wild boar, roe/red deer | EXISTING (catalog) | Wild margin; beaver status in 1343 `plausible composite` (present, reduced) |
| Common crane `bird.common_crane` | MISSING | Signature sound; spring migrant |
| Black stork `bird.black_stork`, capercaillie `bird.capercaillie`, black grouse `bird.black_grouse` | MISSING | Bog edge |
| White-tailed eagle, grey heron, greylag goose, mallard, snipe, lapwing | EXISTING | Wetland |
| Pike `fish.pike`, bream `fish.bream`, burbot `fish.burbot` | MISSING | Flood-meadow spawning |
| Common frog, moor frog, grass snake, adder `amphib.* / reptile.*` | MISSING (no herp system) | Light ambient only |
| Mosquito swarm `insect.mosquito` | MISSING | Visual particle and sound; July |
### 9.5 Flora & ground cover
Existing: `tree.alder`, `tree.birch`, `tree.pine`, `tree.willow`, `bush.bog_rosemary`, `bush.cranberry`, `bush.cloudberry`, `bush.willow_shrub`, `bush.alder_shrub`, `plant.moss`, `plant.reed`, `plant.cattail`, `plant.water_lily`. Missing: `tree.pine_bog_dwarf`, `plant.sedge_tussock`, `plant.cottongrass`, `plant.sundew`, `plant.marsh_marigold`, `plant.horsetail`, `plant.floating_mat` (terrain decal), `bush.labrador_tea` (`plausible composite` for Estonia: native).
### 9.6 Materials / terrain / water
`terrain.peat_black`, `terrain.sphagnum_mat`, `water.tannin_dark_flood` (brown, slow, mirror), `water.flood_level_dynamic` (seasonal height), `fx.mist_low`.
### 9.7 Audio & music direction
Cranes (spring), frogs (April-May dusk), mosquito whine (July), pole splash, wood creak, wolf howl at distance. Languages: South-Estonian-flavored Estonian; Latin murmur of a last-rites scene. Music: bare drone, jaw harp.

## 10. Variety signature and risks
Palette: tannin brown, mist grey, pale green; silhouette: tree crowns over water, pole-man in dugout; sound: crane and silence.
**Risks:** dynamic water on large map (performance); boat controls (new mechanic, needs ADR; may be scripted cutscene instead); "refuge" fantasy vs massacre trauma; confusion with `kanavere_bog.md`. **Open questions:** boat gameplay or scripted travel only; keep spirit gate.

## 11. Sources and next steps
Repo: [CANON.md](../CANON.md), [TOURIST_LANDMARKS.md](../TOURIST_LANDMARKS.md), [FLORA_FAUNA.md](../FLORA_FAUNA.md), [spring-climate-and-living-world.md](../../history/dossiers/nature/spring-climate-and-living-world.md), [belief-omens-and-healing.md](../../history/dossiers/folklore/belief-omens-and-healing.md). External (by name): Soomaa National Park ecology, Estonian National Museum boat collection.
**Verification tasks:** find earliest evidence for dugout boats in Sakala; confirm beaver and elk populations c. 1343; confirm crane/black stork phenology; ADR for new node and boat mechanic.
