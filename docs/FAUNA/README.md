# Fauna

Status: living roster (2026-10-11). One card per real animal, bird or fish that is in the game, or that must be made for it. Cards are grouped in [`animals/`](./animals) (mammals), [`birds/`](./birds) and [`fish/`](./fish). Folklore beings are not here; they live in the [bestiary](../BESTIARY/README.md). The ecological ledger is [`FLORA_FAUNA.md`](../FLORA_FAUNA.md) and the 3D sourcing research is [`ANIMAL_3D_SOURCING.md`](../ANIMAL_3D_SOURCING.md).

## Scope and IDs

- Mammals: the 30-species catalogue in `map_view_mammal_species.gd` (`fauna.*`), plus the goat, which is used in game but missing from the catalogue. The domestic fowl (`fauna.chicken`, `fauna.duck`, `fauna.goose`) are in that catalogue but their cards are filed under `birds/`.
- Fish: the two species that swim in game, the herring and the perch of `CityFish` (`scripts/city/city_fish.gd`, species keys `herring` and `perch`). They have no catalogue file, so the card IDs `fish.herring` and `fish.perch` are documentation IDs only.
- Birds: the 30-species catalogue in `map_view_bird_species.gd` (`bird.*`).
- Real animals, including wolf, bear and boar, are catalogued here. Their encounter-design IDs (`bst.wolf`, `bst.bear`, `bst.boar`) are retained on their species pages; folklore beings and spirit-layer adversaries remain in the [bestiary](../BESTIARY/README.md).
- File names are the ID without the prefix. Domestic and wild birds that share an ID stem get distinct names (`domestic_duck` for `fauna.duck`, `mallard` for `bird.mallard`).

## 3D model status

| Status | Meaning | Count |
|---|---|---|
| Authored GLB (third-party, CC BY 4.0) | Licensed sculpt in the repo, rebuilt for the runtime | 12 |
| Project-authored GLB | Project-authored geometry | 1 |
| Project-built GLB (procedural) | Built by project scripts, not a real species sculpt; the maintainer wants these replaced where they read poorly | 7 |
| Procedural only, no 3D model | Only the procedural mesh in code; **needs a 3D model** | 41 |
| Project-built textured model (fish) | Generated glTF per species under `assets/animals/fish/`, loaded by `CityFish` | 2 |

Every GLB is listed with its licence in [`assets/SOURCES.csv`](../../assets/SOURCES.csv). CC BY 4.0 sources need credit in the in-game Credits screen (`python3 tools/generate_credits.py`).

## Concept art

Status: reference only (not runtime assets, not imported by Godot; no `assets/SOURCES.csv` rows). Every card carries one cinematic photorealistic image in [`images/`](./images) (1024x1024), generated with Leonardo Lucid Origin from the prompts in [IMAGE_PROMPTS.md](./IMAGE_PROMPTS.md), in the same moody low-key look and muted earth palette as the character concept art in [`docs/CHARACTERS/img/`](../CHARACTERS/img/README.md). `tools/gen_animal_concept_art.py` (local ComfyUI, DreamShaper 8) produced the earlier set and still holds the subject prompts; re-link cards with `python3 tools/add_animal_images_to_cards.py`. These are mood and anatomy reference only, not 3D or in-game textures. `images/.gdignore` keeps Godot from importing them.

## Mammals

| Species | Latin | Runtime ID | 3D model status | Model file | Card |
|---|---|---|---|---|---|
| Brown bear | *Ursus arctos* | `fauna.brown_bear` | Procedural only, no 3D model | - | [brown_bear.md](./animals/brown_bear.md) |
| Wolf | *Canis lupus* | `fauna.wolf` | Procedural only, no 3D model | - | [wolf.md](./animals/wolf.md) |
| Red fox | *Vulpes vulpes* | `fauna.red_fox` | Authored GLB | [GLB](../../assets/storybook/fox/fox.glb) | [red_fox.md](./animals/red_fox.md) |
| Eurasian lynx | *Lynx lynx* | `fauna.lynx` | Procedural only, no 3D model | - | [lynx.md](./animals/lynx.md) |
| Elk | *Alces alces* | `fauna.elk` | Procedural only, no 3D model | - | [elk.md](./animals/elk.md) |
| Red deer | *Cervus elaphus* | `fauna.red_deer` | Procedural only, no 3D model | - | [red_deer.md](./animals/red_deer.md) |
| Roe deer | *Capreolus capreolus* | `fauna.roe_deer` | Procedural only, no 3D model | - | [roe_deer.md](./animals/roe_deer.md) |
| Wild boar | *Sus scrofa* | `fauna.wild_boar` | Authored GLB | [GLB](../../assets/storybook/boar/boar.glb) | [wild_boar.md](./animals/wild_boar.md) |
| Beaver | *Castor fiber* | `fauna.beaver` | Procedural only, no 3D model | - | [beaver.md](./animals/beaver.md) |
| Eurasian otter | *Lutra lutra* | `fauna.otter` | Procedural only, no 3D model | - | [otter.md](./animals/otter.md) |
| European badger | *Meles meles* | `fauna.badger` | Procedural only, no 3D model | - | [badger.md](./animals/badger.md) |
| Stoat | *Mustela erminea* | `fauna.stoat` | Procedural only, no 3D model | - | [stoat.md](./animals/stoat.md) |
| Pine marten | *Martes martes* | `fauna.pine_marten` | Procedural only, no 3D model | - | [pine_marten.md](./animals/pine_marten.md) |
| European polecat | *Mustela putorius* | `fauna.polecat` | Procedural only, no 3D model | - | [polecat.md](./animals/polecat.md) |
| European hare | *Lepus europaeus* | `fauna.hare` | Authored GLB | [GLB](../../assets/storybook/hare/hare.glb) | [hare.md](./animals/hare.md) |
| Red squirrel | *Sciurus vulgaris* | `fauna.squirrel` | Procedural only, no 3D model | - | [squirrel.md](./animals/squirrel.md) |
| European hedgehog | *Erinaceus europaeus* | `fauna.hedgehog` | Procedural only, no 3D model | - | [hedgehog.md](./animals/hedgehog.md) |
| Grey seal | *Halichoerus grypus* | `fauna.grey_seal` | Procedural only, no 3D model | - | [grey_seal.md](./animals/grey_seal.md) |
| Ringed seal | *Pusa hispida* | `fauna.ringed_seal` | Procedural only, no 3D model | - | [ringed_seal.md](./animals/ringed_seal.md) |
| Common bat | *Pipistrellus pipistrellus* | `fauna.common_bat` | Procedural only, no 3D model | - | [common_bat.md](./animals/common_bat.md) |
| Domestic cat | *Felis catus* | `fauna.cat` | Authored GLB | [GLB](../../assets/storybook/forge_cat/forge_cat.glb) | [cat.md](./animals/cat.md) |
| Domestic dog | *Canis lupus familiaris* | `fauna.dog` | Authored GLB | [GLB](../../assets/storybook/dog/dog.glb) | [dog.md](./animals/dog.md) |
| Horse | *Equus ferus caballus* | `fauna.horse` | Project-authored GLB | [GLB](../../assets/storybook/horse/horse.glb) | [horse.md](./animals/horse.md) |
| Brown rat | *Rattus norvegicus* | `fauna.rat` | Authored GLB | [GLB](../../assets/storybook/rat/rat.glb) | [rat.md](./animals/rat.md) |
| Chicken | *Gallus gallus domesticus* | `fauna.chicken` | Authored GLB | [GLB](../../assets/storybook/hen/hen.glb) | [chicken.md](./birds/chicken.md) |
| Domestic duck | *Anas platyrhynchos domesticus* | `fauna.duck` | Project-built GLB | [GLB](../../assets/storybook/duck/duck.glb) | [domestic_duck.md](./birds/domestic_duck.md) |
| Domestic goose | *Anser anser domesticus* | `fauna.goose` | Project-built GLB | [GLB](../../assets/storybook/goose/goose.glb) | [domestic_goose.md](./birds/domestic_goose.md) |
| Domestic pig | *Sus scrofa domestica* | `fauna.pig` | Authored GLB | [GLB](../../assets/storybook/pig/pig.glb) | [pig.md](./animals/pig.md) |
| Cattle | *Bos taurus* | `fauna.cow` | Authored GLB | [GLB](../../assets/storybook/cow/cow.glb) | [cattle.md](./animals/cattle.md) |
| Sheep | *Ovis aries* | `fauna.sheep` | Authored GLB | [GLB](../../assets/storybook/sheep/sheep.glb) | [sheep.md](./animals/sheep.md) |
| Goat | *Capra hircus* | `fauna.goat` | Authored GLB | [GLB](../../assets/storybook/goat/goat.glb) | [goat.md](./animals/goat.md) |

## Birds

| Species | Latin | Runtime ID | 3D model status | Model file | Card |
|---|---|---|---|---|---|
| Herring gull | *Larus argentatus* | `bird.herring_gull` | Project-built GLB | [GLB](../../assets/storybook/gull/gull.glb) | [herring_gull.md](./birds/herring_gull.md) |
| Common gull | *Larus canus* | `bird.common_gull` | Project-built GLB | [GLB](../../assets/storybook/gull/gull.glb) | [common_gull.md](./birds/common_gull.md) |
| Common tern | *Sterna hirundo* | `bird.common_tern` | Procedural only, no 3D model | - | [common_tern.md](./birds/common_tern.md) |
| Mute swan | *Cygnus olor* | `bird.mute_swan` | Procedural only, no 3D model | - | [mute_swan.md](./birds/mute_swan.md) |
| Mallard | *Anas platyrhynchos* | `bird.mallard` | Project-built GLB | [GLB](../../assets/storybook/duck/duck.glb) | [mallard.md](./birds/mallard.md) |
| Greylag goose | *Anser anser* | `bird.greylag_goose` | Procedural only, no 3D model | - | [greylag_goose.md](./birds/greylag_goose.md) |
| Great cormorant | *Phalacrocorax carbo* | `bird.great_cormorant` | Procedural only, no 3D model | - | [great_cormorant.md](./birds/great_cormorant.md) |
| Grey heron | *Ardea cinerea* | `bird.grey_heron` | Procedural only, no 3D model | - | [grey_heron.md](./birds/grey_heron.md) |
| Northern lapwing | *Vanellus vanellus* | `bird.northern_lapwing` | Procedural only, no 3D model | - | [northern_lapwing.md](./birds/northern_lapwing.md) |
| Common snipe | *Gallinago gallinago* | `bird.common_snipe` | Procedural only, no 3D model | - | [common_snipe.md](./birds/common_snipe.md) |
| White-tailed eagle | *Haliaeetus albicilla* | `bird.white_tailed_eagle` | Procedural only, no 3D model | - | [white_tailed_eagle.md](./birds/white_tailed_eagle.md) |
| Osprey | *Pandion haliaetus* | `bird.osprey` | Procedural only, no 3D model | - | [osprey.md](./birds/osprey.md) |
| Common buzzard | *Buteo buteo* | `bird.common_buzzard` | Procedural only, no 3D model | - | [common_buzzard.md](./birds/common_buzzard.md) |
| Common kestrel | *Falco tinnunculus* | `bird.common_kestrel` | Procedural only, no 3D model | - | [common_kestrel.md](./birds/common_kestrel.md) |
| Tawny owl | *Strix aluco* | `bird.tawny_owl` | Procedural only, no 3D model | - | [tawny_owl.md](./birds/tawny_owl.md) |
| House sparrow | *Passer domesticus* | `bird.house_sparrow` | Authored GLB | [GLB](../../assets/birds/house_sparrow/perched.glb) | [house_sparrow.md](./birds/house_sparrow.md) |
| Hooded crow | *Corvus cornix* | `bird.hooded_crow` | Project-built GLB | [GLB](../../assets/storybook/hooded_crow/hooded_crow.glb) | [hooded_crow.md](./birds/hooded_crow.md) |
| Rook | *Corvus frugilegus* | `bird.rook` | Procedural only, no 3D model | - | [rook.md](./birds/rook.md) |
| Western jackdaw | *Coloeus monedula* | `bird.western_jackdaw` | Procedural only, no 3D model | - | [western_jackdaw.md](./birds/western_jackdaw.md) |
| Eurasian magpie | *Pica pica* | `bird.eurasian_magpie` | Procedural only, no 3D model | - | [eurasian_magpie.md](./birds/eurasian_magpie.md) |
| Barn swallow | *Hirundo rustica* | `bird.barn_swallow` | Procedural only, no 3D model | - | [barn_swallow.md](./birds/barn_swallow.md) |
| Skylark | *Alauda arvensis* | `bird.skylark` | Procedural only, no 3D model | - | [skylark.md](./birds/skylark.md) |
| Yellowhammer | *Emberiza citrinella* | `bird.yellowhammer` | Procedural only, no 3D model | - | [yellowhammer.md](./birds/yellowhammer.md) |
| Common chaffinch | *Fringilla coelebs* | `bird.common_chaffinch` | Procedural only, no 3D model | - | [common_chaffinch.md](./birds/common_chaffinch.md) |
| Great tit | *Parus major* | `bird.great_tit` | Procedural only, no 3D model | - | [great_tit.md](./birds/great_tit.md) |
| European robin | *Erithacus rubecula* | `bird.european_robin` | Project-built GLB | [GLB](../../assets/storybook/robin/robin.glb) | [european_robin.md](./birds/european_robin.md) |
| Common blackbird | *Turdus merula* | `bird.common_blackbird` | Procedural only, no 3D model | - | [common_blackbird.md](./birds/common_blackbird.md) |
| Song thrush | *Turdus philomelos* | `bird.song_thrush` | Procedural only, no 3D model | - | [song_thrush.md](./birds/song_thrush.md) |
| Common nightingale | *Luscinia megarhynchos* | `bird.common_nightingale` | Procedural only, no 3D model | - | [common_nightingale.md](./birds/common_nightingale.md) |
| Great spotted woodpecker | *Dendrocopos major* | `bird.great_spotted_woodpecker` | Procedural only, no 3D model | - | [great_spotted_woodpecker.md](./birds/great_spotted_woodpecker.md) |

## Fish

| Species | Latin | Card ID | 3D model status | Model file | Card |
|---|---|---|---|---|---|
| Baltic herring | *Clupea harengus membras* | `fish.herring` | Project-built textured model | [glTF](../../assets/animals/fish/herring/herring.gltf) | [herring.md](./fish/herring.md) |
| European perch | *Perca fluviatilis* | `fish.perch` | Project-built textured model | [glTF](../../assets/animals/fish/perch/perch.gltf) | [perch.md](./fish/perch.md) |

Fish are visual shoals only (see [`CITY_SEA.md`](../SYSTEMS/CITY_SEA.md)). Herring also exists as trade and food objects (`obj.herring_fresh`, `obj.herring_filleted`, `obj.cargo_herring_barrels`, `obj.fish_smoked`), which are items, not creatures. Archaeology from the Kadriorg ship finds (`history/AVE2015_15_Roiojt_Kadriorg.txt`) names pike, cod and turbot as period fish; none is in game, so they have no card yet.

## Models still to create

Procedural-only species, grouped by what they need first. Search links are starting points, not verified models.

Priority for the Act 1 slice:

- [wolf](./animals/wolf.md): physical fight outside the city (`bst.wolf`).
- [brown bear](./animals/brown_bear.md) and [wild boar](./animals/wild_boar.md) (`bst.bear`, `bst.boar`, backlog): wild-margin threats. The boar has a GLB; the bear does not.
- Eagle, osprey, buzzard, kestrel: one raptor archetype rig (large flapping and gliding bird).
- Heron, lapwing, snipe, swan, cormorant, greylag goose, tern: waterfowl and wader archetype (large bird with long neck or legs).

Other procedural species can wait until their district spawn weight matters for play.

Count: 41 of 63 entries have only a procedural mesh and need a 3D model.

## Adding a species

1. Add the catalogue row first (`map_view_mammal_species.gd` or `map_view_bird_species.gd`; fish live in `city_fish.gd` and `assets/animals/fish/`), then a card in the matching `animals/`, `birds/` or `fish/` folder with the same slug.
2. Source the model under the asset rules: CC0 or CC BY only, record the URL, author, SHA-256 and edits in `assets/SOURCES.csv`, and keep the runtime GLB self-contained.
3. New production art needs a task naming the exact files (asset freeze P0-040).
4. Update the status row above and the card's 3D model table in the same change.

## Known discrepancies

- `FLORA_FAUNA.md` says the common tern has an authored GLB flap cycle. No `assets/birds/common_tern/` exists; the loader falls back to procedural.
- The gull entries share a project-built storybook GLB, not a species model. `FLORA_FAUNA.md` lists them as authored.
- The hare GLB is a rabbit proxy (`mammal_sources.json` note).
- The goat is used at runtime but missing from the mammal catalogue.

<!-- docs-index:start (generated by tools/docs_index.py; do not edit) -->

_Every file in this folder is linked above._
<!-- docs-index:end -->
