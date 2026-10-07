# Biomes and Wildlife across the journey nodes
**Status:** planned (design proposal, not implemented) · **Scope:** cross-cutting reference for the `loc.world_*` nodes and the proposed new nodes; no runtime change · **Confidence:** biome geography `attested`; 1343 species lists `plausible composite` (modern Estonian fauna filtered by medieval presence); sound cues `invented`.

How to read: `EXISTING` = id present in the runtime catalogs ([`FLORA_FAUNA.md`](../FLORA_FAUNA.md), `scripts/map/view3d/map_view_{tree,plant,bush,bird,mammal}_species*.gd`). `MISSING` = no catalog entry; needs generating. The runtime has no catalog for fish, amphibians, reptiles, or visible insects (insects are audio-only Orthoptera: grasshopper, bush-cricket, cricket, mole cricket). All fish, amphibian, reptile and butterfly/bee/mosquito rows are therefore MISSING.

## Global species status (1343 Estonia)
| Species | 1343 status | Label | Catalog |
|---|---|---|---|
| Wolf, lynx, brown bear | Present, widespread in forest; hunted | `attested` (large carnivores native) | EXISTING `fauna.wolf`, `fauna.lynx`, `fauna.brown_bear` |
| Elk | Present, forest and bog edge | `plausible composite` | EXISTING `fauna.elk` |
| Red deer | Rare/local in medieval Estonia; label | `plausible composite` | EXISTING `fauna.red_deer` |
| Roe deer, wild boar | Present; boar numerous in the Middle Ages | `plausible composite` | EXISTING |
| Beaver | Present but declining; heavily hunted later | `plausible composite` | EXISTING `fauna.beaver` |
| Aurochs, wisent (bison) | Aurochs extinct in the region before 1343; bison absent. Do not place | `attested` absence (aurochs); bison `plausible composite` absence | not in catalog (correct) |
| Fallow deer, rabbit, pheasant, potato, turkey, maize | Not present until later | `attested` absence | not in catalog (correct) |
| Domestic: cattle, sheep, pig, horse, goat, geese, chickens, ducks, dogs, cats | Present | `attested` | EXISTING (goat MISSING) |
| Grey and ringed seal | Present, sealing on coast and islands | `attested` | EXISTING |
| Bees (wild-hive and skep), honey | Present | `plausible composite` | MISSING |

## 1. Hanseatic harbour and coast
| Field | Content |
|---|---|
| Nodes | Reval harbour (existing maps), [parnu.md](./parnu.md), [haapsalu_laanemaa.md](./haapsalu_laanemaa.md), [narva_peipus_east.md](./narva_peipus_east.md) (river port) |
| Look Apr / May / Jul / winter | Apr: muddy quay, last ice pans, grey water. May: pale green on foreland, ships arrive. Jul: stinking tidal wrack, bright, many boats. Winter: ice shore, frozen roads |
| Flora | EXISTING `tree.willow`, `bush.sea_buckthorn`, `plant.reed`, `plant.mugwort`, `plant.plantain`; MISSING `plant.sea_kale`, `plant.glasswort` |
| Fauna | Gulls, terns, cormorant (EXISTING); grey/ringed seal (EXISTING); rat, cat, dog, horse (EXISTING); goat MISSING; Baltic herring, cod, flounder, pike-perch, eel, lamprey `fish.*` MISSING; barnacle/mussel prop decal MISSING |
| Missing to generate | Fish (market and net props), `bird.eider`, `bird.black_guillemot`, mussel beds, harbour wrack decals |
| Sound | Rope creak, hull knock, gulls, hawsers, Low German shouts, bell of Oleviste (distant) |

## 2. Harju farmland and field strips
| Field | Content |
|---|---|
| Nodes | [harju_village.md](./harju_village.md), [rebel_kings_camp.md](./rebel_kings_camp.md) (edge), [sojamae.md](./sojamae.md) |
| Look | Apr: thaw, brown strips, pale shoots. May: green rye, plum blossom, ploughing. Jul: gold rye, haystacks. Winter: stubble under snow, frozen cart ruts |
| Flora | EXISTING `crop.rye`, `crop.barley`, `crop.oat`, `crop.flax`, `crop.hemp`, `crop.pea`, `crop.turnip`, `plant.dandelion`, `plant.yarrow`, `plant.clover`, `tree.birch`, `tree.oak`; MISSING `plant.cornflower`, `plant.poppy_field_weed`, `plant.coltsfoot` |
| Fauna | Cow, sheep, pig, horse, goose, hen (EXISTING); hare, fox, roe deer (EXISTING); lapwing, skylark, yellowhammer, rook (EXISTING); stork `bird.white_stork` MISSING (arrival late April, `plausible composite`); bees MISSING |
| Missing | Ox team with plough prop, white stork nest, goat, field-strip boundary stones |
| Sound | Skylark, ox harness, cartwheel, distant church bell, crows |

## 3. Hiis forest (sacred grove)
| Field | Content |
|---|---|
| Nodes | [sacred_grove.md](./sacred_grove.md), [kanavere_bog.md](./kanavere_bog.md) (margin) |
| Look | Apr: bare oaks, wood anemone. May: leaf flush, bird chorus. Jul: dark green closed canopy, fireflies. Winter: black oaks, frost-white moss |
| Flora | EXISTING `tree.oak` (+ authored ancient oak GLB), `tree.linden`, `tree.ash`, `tree.hazel`, `plant.fern`, `plant.moss`; MISSING `plant.wood_anemone`, `plant.hepatica`, `plant.lily_of_the_valley` |
| Fauna | Tawny owl, woodpecker, great tit, robin, thrush (EXISTING); squirrel, marten, badger, wolf, boar (EXISTING); raven `bird.raven` MISSING; wood pigeon, cuckoo MISSING; glow-worm MISSING |
| Missing | Votive ribbon/offering props and carved hiis stones (owned by [sacred_grove.md](./sacred_grove.md)) |
| Sound | Wind in leaves, woodpecker, owl at dusk, no bells |

## 4. Raised bog
| Field | Content |
|---|---|
| Nodes | [kanavere_bog.md](./kanavere_bog.md), [soomaa_flood_refuge.md](./soomaa_flood_refuge.md) |
| Look | Apr: bog dull brown, ice in hollows, early cranes. May: cottongrass white. Jul: pools black, berries ripening. Winter: frozen but treacherous under snow |
| Flora | EXISTING `bush.bog_rosemary`, `bush.cranberry`, `bush.cloudberry`, `bush.heather`, `plant.moss`, `tree.pine`; MISSING `plant.cottongrass`, `plant.sundew`, `bush.labrador_tea`, `tree.pine_bog_dwarf` |
| Fauna | Wolf, lynx, elk, bear (EXISTING); crane, black grouse, capercaillie, snipe (snipe EXISTING, others MISSING); adder, common frog MISSING; mosquito, dragonfly MISSING |
| Sound | Crane, snipe drumming, bubbling peat, silence |

## 5. Flooded meadow and alder carr
| Field | Content |
|---|---|
| Nodes | [soomaa_flood_refuge.md](./soomaa_flood_refuge.md), [parnu.md](./parnu.md) (river meadows) |
| Look | Apr-May: lake with tree crowns, sedge mats, willow catkins. Jul: hay meadow. Winter: ice sheet with grass tufts |
| Flora | EXISTING `tree.alder`, `tree.willow`, `bush.alder_shrub`, `plant.reed`, `plant.cattail`; MISSING `plant.sedge_tussock`, `plant.marsh_marigold`, `plant.horsetail` |
| Fauna | Greylag goose, mallard, heron, lapwing, otter, beaver (EXISTING); crane, white stork, whooper swan `bird.whooper_swan` MISSING; pike, bream, frogs MISSING |
| Sound | Honk of geese, frogs, pole splashes |

## 6. Limestone alvar and juniper heath
| Field | Content |
|---|---|
| Nodes | [saaremaa.md](./saaremaa.md), [haapsalu_laanemaa.md](./haapsalu_laanemaa.md), [poide_castle.md](./poide_castle.md) |
| Look | Apr: grey and dry, snow patches in cracks. May: yellow and white alvar flowers. Jul: dry cracked pavement, juniper green-grey. Winter: wind-scoured ice |
| Flora | EXISTING `tree.juniper`, `bush.juniper_shrub`, `bush.heather`, `bush.crowberry`, `plant.yarrow`, `plant.thistle`; MISSING `plant.alvar_stonecrop`, `plant.pasqueflower`, `plant.thyme_wild` |
| Fauna | Sheep (EXISTING), hare, fox, skylark, kestrel (EXISTING); wheatear `bird.wheatear` MISSING; adder MISSING; grasshopper audio (EXISTING) |
| Sound | Wind, sheep bells, skylark |

## 7. Glint cliff coast and klint forest
| Field | Content |
|---|---|
| Nodes | [baltic_klint_coast.md](./baltic_klint_coast.md) |
| Look | Apr-May: spray and flood falls, hepatica. Jul: cliff-forest dim and green, falls thin. Winter: ice columns |
| Flora | EXISTING `tree.ash`, `tree.elm`, `tree.maple`, `tree.spruce`, `bush.sea_buckthorn`; MISSING `plant.hepatica`, `plant.sea_kale`, lichen/moss rock layers |
| Fauna | Seals, sea eagle, gull, tern (EXISTING); raven, peregrine, eider, crane MISSING; sea trout MISSING |
| Sound | Waterfall roar, surf |

## 8. Island coast with seals
| Field | Content |
|---|---|
| Nodes | [saaremaa.md](./saaremaa.md), [haapsalu_laanemaa.md](./haapsalu_laanemaa.md) |
| Look | Apr: ice breaking. May: seal pups end. Jul: bright shallows, reeds. Winter: ice road, sealers |
| Flora | EXISTING `bush.sea_buckthorn`, `tree.juniper`, `plant.reed`; MISSING `plant.sea_pea`, `plant.thrift` |
| Fauna | Grey seal, ringed seal (EXISTING); eider, goosander, black guillemot, tern colony (tern EXISTING, rest MISSING); fox; fish: herring, flounder MISSING |
| Sound | Seal bark, surf, gulls, boat hull |

## 9. Big lakes (Peipus, Võrtsjärv, Ülemiste)
| Field | Content |
|---|---|
| Nodes | [narva_peipus_east.md](./narva_peipus_east.md), [viljandi_fellin.md](./viljandi_fellin.md), [otepaa_vastseliina_frontier.md](./otepaa_vastseliina_frontier.md); Ülemiste near Reval (existing foreland) |
| Look | Apr: grey lake with ice floes. May: lake surface calm, reed shoots. Jul: shallow, warm, algae. Winter: ice fishing and ice roads |
| Flora | EXISTING `plant.reed`, `plant.cattail`, `plant.water_lily`, `tree.willow`; MISSING `plant.sedge_tussock` |
| Fauna | Swan, goose, mallard, cormorant, heron, osprey (EXISTING); bream, pike-perch, smelt, vendace (Peipus), lamprey MISSING |
| Sound | Ice groan, wind on wide water, fishermen's calls in Estonian and Russian |

## 10. River valleys with sandstone
| Field | Content |
|---|---|
| Nodes | [otepaa_vastseliina_frontier.md](./otepaa_vastseliina_frontier.md) (Taevaskoja/Piusa type: label `plausible composite`, geography `attested`) |
| Look | Apr: swollen river, wet red sandstone. May: green slope. Jul: shade, cool caves. Winter: icicles |
| Flora | EXISTING `tree.spruce`, `tree.pine`, `tree.ash`, `plant.fern`, `plant.moss`; MISSING `plant.hart_tongue_fern`, lichen |
| Fauna | Beaver, otter, kingfisher `bird.kingfisher`, dipper `bird.dipper`, sand martin `bird.sand_martin` MISSING; bats (EXISTING) in caves |
| Missing | `terrain.red_sandstone_layered`, cave mouth kit |
| Sound | River flow, bat flutter |

## 11. Border forest and hillfort
| Field | Content |
|---|---|
| Nodes | [otepaa_vastseliina_frontier.md](./otepaa_vastseliina_frontier.md), [rakvere_wesenberg.md](./rakvere_wesenberg.md) |
| Look | Apr: bare, mud. May: spring green. Jul: dense, dark. Winter: snow, deep drifts |
| Flora | EXISTING `tree.spruce`, `tree.pine`, `tree.birch`, `tree.aspen`, `bush.bilberry`, `bush.cowberry` |
| Fauna | Wolf, bear, lynx, elk, boar (EXISTING); capercaillie, black woodpecker MISSING |
| Sound | Axe ring, wind in pines, distant horn |

## 12. Wooded meadow
| Field | Content |
|---|---|
| Nodes | [harju_village.md](./harju_village.md), [haapsalu_laanemaa.md](./haapsalu_laanemaa.md) |
| Look | Apr: bare oaks, anemone. May: orchid and cowslip. Jul: mowing with scythes, hay. Winter: bare |
| Flora | EXISTING `tree.oak`, `tree.hazel`, `tree.linden`, `grass.flowers`, `plant.clover`; MISSING `plant.cowslip`, `plant.orchid_early_purple`, `plant.oxeye_daisy` |
| Fauna | Roe deer, hare, songbirds, cuckoo MISSING; butterfly, bumblebee MISSING |
| Sound | Scythe whetstone, bees, cuckoo |

## 13. Narva rapids
| Field | Content |
|---|---|
| Nodes | [narva_peipus_east.md](./narva_peipus_east.md) (river crossing; Narva was Danish crown castle in 1343) |
| Look | Apr: roaring melt. May: foam, salmon run. Jul: low rapids, rock shelves. Winter: ice rim |
| Flora | EXISTING `tree.spruce`, `tree.birch`, `plant.moss`; MISSING `plant.riverbank_willow_herb` |
| Fauna | Gulls, osprey, otter (EXISTING); salmon, trout, lamprey MISSING |
| Sound | Rapids roar, gulls |

## What needs generating (consolidated)
| Group | Items | Priority |
|---|---|---|
| Birds | `bird.common_crane`, `bird.white_stork`, `bird.raven`, `bird.black_stork`, `bird.capercaillie`, `bird.black_grouse`, `bird.common_eider`, `bird.whooper_swan`, `bird.kingfisher`, `bird.cuckoo`, `bird.wood_pigeon` | P1 crane, stork, raven; rest P2-P3 |
| Mammals | goat `fauna.goat` | P2 |
| Fish | `fish.baltic_herring`, `fish.pike`, `fish.bream`, `fish.salmon`, `fish.sea_trout`, `fish.eel`, `fish.lamprey` (prop-first, not swimming agents) | P2 |
| Herps and insects | frog, adder, grass snake; mosquito, bumblebee, butterfly, dragonfly | P3 |
| Flora | `plant.cottongrass`, `plant.sundew`, `plant.sedge_tussock`, `plant.hepatica`, `plant.wood_anemone`, `plant.cowslip`, `plant.sea_kale`, `tree.pine_bog_dwarf` | P1 cottongrass, sedge, anemone |

## Rules for authors
- Add a species only with a catalog profile, mesh test and authored location, per [`FLORA_FAUNA.md`](../FLORA_FAUNA.md).
- Do not show aurochs, bison, or post-medieval plants and crops.
- Wildlife is ambient; no hunting or survival systems (out of scope, [AGENTS.md](../../AGENTS.md)).

## Sources
[`FLORA_FAUNA.md`](../FLORA_FAUNA.md), [`LIVING_VEGETATION.md`](../SYSTEMS/LIVING_VEGETATION.md), [`spring-climate-and-living-world.md`](../../history/dossiers/nature/spring-climate-and-living-world.md), [`TOURIST_LANDMARKS.md`](../TOURIST_LANDMARKS.md), [`CANON.md`](../CANON.md). Verification tasks: check each `plausible composite` species against Estonian medieval archaeozoology (bone assemblages); confirm red deer and beaver status.
