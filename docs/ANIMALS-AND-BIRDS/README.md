# Animals and birds

Status: living roster (2026-10-10). One card per real animal or bird that is in the game, or that must be made for it. Folklore beings are not here; they live in the [bestiary](../BESTIARY/README.md). The ecological ledger is [`FLORA_FAUNA.md`](../FLORA_FAUNA.md) and the 3D sourcing research is [`ANIMAL_3D_SOURCING.md`](../ANIMAL_3D_SOURCING.md).

## Scope and IDs

- Mammals: the 30-species catalogue in `map_view_mammal_species.gd` (`fauna.*`), plus the goat, which is used in game but missing from the catalogue.
- Birds: the 30-species catalogue in `map_view_bird_species.gd` (`bird.*`).
- Bestiary animals (`bst.wolf`, `bst.boar`, `bst.bear`) are linked from their `fauna.*` card. The wolf card is the bestiary card, moved here from `docs/BESTIARY/cards/`.
- File names are the ID without the prefix. Domestic and wild birds that share an ID stem get distinct names (`domestic_duck` for `fauna.duck`, `mallard` for `bird.mallard`).

## 3D model status

| Status | Meaning | Count |
|---|---|---|
| Authored GLB (third-party, CC BY 4.0) | Licensed sculpt in the repo, rebuilt for the runtime | 12 |
| Project-authored GLB | Project-authored geometry | 1 |
| Project-built GLB (procedural) | Built by project scripts, not a real species sculpt; the maintainer wants these replaced where they read poorly | 7 |
| Procedural only, no 3D model | Only the procedural mesh in code; **needs a 3D model** | 41 |

Every GLB is listed with its licence in [`assets/SOURCES.csv`](../../assets/SOURCES.csv). CC BY 4.0 sources need credit in the in-game Credits screen (`python3 tools/generate_credits.py`).

## Mammals

| Species | Latin | Runtime ID | 3D model status | Model file | Card |
|---|---|---|---|---|---|
| Brown bear | *Ursus arctos* | `fauna.brown_bear` | Procedural only, no 3D model | - | [brown_bear.md](./brown_bear.md) |
| Wolf | *Canis lupus* | `fauna.wolf` | Procedural only, no 3D model | - | [wolf.md](./wolf.md) |
| Red fox | *Vulpes vulpes* | `fauna.red_fox` | Authored GLB | [GLB](../../assets/storybook/fox/fox.glb) | [red_fox.md](./red_fox.md) |
| Eurasian lynx | *Lynx lynx* | `fauna.lynx` | Procedural only, no 3D model | - | [lynx.md](./lynx.md) |
| Elk | *Alces alces* | `fauna.elk` | Procedural only, no 3D model | - | [elk.md](./elk.md) |
| Red deer | *Cervus elaphus* | `fauna.red_deer` | Procedural only, no 3D model | - | [red_deer.md](./red_deer.md) |
| Roe deer | *Capreolus capreolus* | `fauna.roe_deer` | Procedural only, no 3D model | - | [roe_deer.md](./roe_deer.md) |
| Wild boar | *Sus scrofa* | `fauna.wild_boar` | Authored GLB | [GLB](../../assets/storybook/boar/boar.glb) | [wild_boar.md](./wild_boar.md) |
| Beaver | *Castor fiber* | `fauna.beaver` | Procedural only, no 3D model | - | [beaver.md](./beaver.md) |
| Eurasian otter | *Lutra lutra* | `fauna.otter` | Procedural only, no 3D model | - | [otter.md](./otter.md) |
| European badger | *Meles meles* | `fauna.badger` | Procedural only, no 3D model | - | [badger.md](./badger.md) |
| Stoat | *Mustela erminea* | `fauna.stoat` | Procedural only, no 3D model | - | [stoat.md](./stoat.md) |
| Pine marten | *Martes martes* | `fauna.pine_marten` | Procedural only, no 3D model | - | [pine_marten.md](./pine_marten.md) |
| European polecat | *Mustela putorius* | `fauna.polecat` | Procedural only, no 3D model | - | [polecat.md](./polecat.md) |
| European hare | *Lepus europaeus* | `fauna.hare` | Authored GLB | [GLB](../../assets/storybook/hare/hare.glb) | [hare.md](./hare.md) |
| Red squirrel | *Sciurus vulgaris* | `fauna.squirrel` | Procedural only, no 3D model | - | [squirrel.md](./squirrel.md) |
| European hedgehog | *Erinaceus europaeus* | `fauna.hedgehog` | Procedural only, no 3D model | - | [hedgehog.md](./hedgehog.md) |
| Grey seal | *Halichoerus grypus* | `fauna.grey_seal` | Procedural only, no 3D model | - | [grey_seal.md](./grey_seal.md) |
| Ringed seal | *Pusa hispida* | `fauna.ringed_seal` | Procedural only, no 3D model | - | [ringed_seal.md](./ringed_seal.md) |
| Common bat | *Pipistrellus pipistrellus* | `fauna.common_bat` | Procedural only, no 3D model | - | [common_bat.md](./common_bat.md) |
| Domestic cat | *Felis catus* | `fauna.cat` | Authored GLB | [GLB](../../assets/storybook/forge_cat/forge_cat.glb) | [cat.md](./cat.md) |
| Domestic dog | *Canis lupus familiaris* | `fauna.dog` | Authored GLB | [GLB](../../assets/storybook/dog/dog.glb) | [dog.md](./dog.md) |
| Horse | *Equus ferus caballus* | `fauna.horse` | Project-authored GLB | [GLB](../../assets/storybook/horse/horse.glb) | [horse.md](./horse.md) |
| Brown rat | *Rattus norvegicus* | `fauna.rat` | Authored GLB | [GLB](../../assets/storybook/rat/rat.glb) | [rat.md](./rat.md) |
| Chicken | *Gallus gallus domesticus* | `fauna.chicken` | Authored GLB | [GLB](../../assets/storybook/hen/hen.glb) | [chicken.md](./chicken.md) |
| Domestic duck | *Anas platyrhynchos domesticus* | `fauna.duck` | Project-built GLB | [GLB](../../assets/storybook/duck/duck.glb) | [domestic_duck.md](./domestic_duck.md) |
| Domestic goose | *Anser anser domesticus* | `fauna.goose` | Project-built GLB | [GLB](../../assets/storybook/goose/goose.glb) | [domestic_goose.md](./domestic_goose.md) |
| Domestic pig | *Sus scrofa domestica* | `fauna.pig` | Authored GLB | [GLB](../../assets/storybook/pig/pig.glb) | [pig.md](./pig.md) |
| Cattle | *Bos taurus* | `fauna.cow` | Authored GLB | [GLB](../../assets/storybook/cow/cow.glb) | [cattle.md](./cattle.md) |
| Sheep | *Ovis aries* | `fauna.sheep` | Authored GLB | [GLB](../../assets/storybook/sheep/sheep.glb) | [sheep.md](./sheep.md) |
| Goat | *Capra hircus* | `fauna.goat` | Authored GLB | [GLB](../../assets/storybook/goat/goat.glb) | [goat.md](./goat.md) |

## Birds

| Species | Latin | Runtime ID | 3D model status | Model file | Card |
|---|---|---|---|---|---|
| Herring gull | *Larus argentatus* | `bird.herring_gull` | Project-built GLB | [GLB](../../assets/storybook/gull/gull.glb) | [herring_gull.md](./herring_gull.md) |
| Common gull | *Larus canus* | `bird.common_gull` | Project-built GLB | [GLB](../../assets/storybook/gull/gull.glb) | [common_gull.md](./common_gull.md) |
| Common tern | *Sterna hirundo* | `bird.common_tern` | Procedural only, no 3D model | - | [common_tern.md](./common_tern.md) |
| Mute swan | *Cygnus olor* | `bird.mute_swan` | Procedural only, no 3D model | - | [mute_swan.md](./mute_swan.md) |
| Mallard | *Anas platyrhynchos* | `bird.mallard` | Project-built GLB | [GLB](../../assets/storybook/duck/duck.glb) | [mallard.md](./mallard.md) |
| Greylag goose | *Anser anser* | `bird.greylag_goose` | Procedural only, no 3D model | - | [greylag_goose.md](./greylag_goose.md) |
| Great cormorant | *Phalacrocorax carbo* | `bird.great_cormorant` | Procedural only, no 3D model | - | [great_cormorant.md](./great_cormorant.md) |
| Grey heron | *Ardea cinerea* | `bird.grey_heron` | Procedural only, no 3D model | - | [grey_heron.md](./grey_heron.md) |
| Northern lapwing | *Vanellus vanellus* | `bird.northern_lapwing` | Procedural only, no 3D model | - | [northern_lapwing.md](./northern_lapwing.md) |
| Common snipe | *Gallinago gallinago* | `bird.common_snipe` | Procedural only, no 3D model | - | [common_snipe.md](./common_snipe.md) |
| White-tailed eagle | *Haliaeetus albicilla* | `bird.white_tailed_eagle` | Procedural only, no 3D model | - | [white_tailed_eagle.md](./white_tailed_eagle.md) |
| Osprey | *Pandion haliaetus* | `bird.osprey` | Procedural only, no 3D model | - | [osprey.md](./osprey.md) |
| Common buzzard | *Buteo buteo* | `bird.common_buzzard` | Procedural only, no 3D model | - | [common_buzzard.md](./common_buzzard.md) |
| Common kestrel | *Falco tinnunculus* | `bird.common_kestrel` | Procedural only, no 3D model | - | [common_kestrel.md](./common_kestrel.md) |
| Tawny owl | *Strix aluco* | `bird.tawny_owl` | Procedural only, no 3D model | - | [tawny_owl.md](./tawny_owl.md) |
| House sparrow | *Passer domesticus* | `bird.house_sparrow` | Authored GLB | [GLB](../../assets/birds/house_sparrow/perched.glb) | [house_sparrow.md](./house_sparrow.md) |
| Hooded crow | *Corvus cornix* | `bird.hooded_crow` | Project-built GLB | [GLB](../../assets/storybook/hooded_crow/hooded_crow.glb) | [hooded_crow.md](./hooded_crow.md) |
| Rook | *Corvus frugilegus* | `bird.rook` | Procedural only, no 3D model | - | [rook.md](./rook.md) |
| Western jackdaw | *Coloeus monedula* | `bird.western_jackdaw` | Procedural only, no 3D model | - | [western_jackdaw.md](./western_jackdaw.md) |
| Eurasian magpie | *Pica pica* | `bird.eurasian_magpie` | Procedural only, no 3D model | - | [eurasian_magpie.md](./eurasian_magpie.md) |
| Barn swallow | *Hirundo rustica* | `bird.barn_swallow` | Procedural only, no 3D model | - | [barn_swallow.md](./barn_swallow.md) |
| Skylark | *Alauda arvensis* | `bird.skylark` | Procedural only, no 3D model | - | [skylark.md](./skylark.md) |
| Yellowhammer | *Emberiza citrinella* | `bird.yellowhammer` | Procedural only, no 3D model | - | [yellowhammer.md](./yellowhammer.md) |
| Common chaffinch | *Fringilla coelebs* | `bird.common_chaffinch` | Procedural only, no 3D model | - | [common_chaffinch.md](./common_chaffinch.md) |
| Great tit | *Parus major* | `bird.great_tit` | Procedural only, no 3D model | - | [great_tit.md](./great_tit.md) |
| European robin | *Erithacus rubecula* | `bird.european_robin` | Project-built GLB | [GLB](../../assets/storybook/robin/robin.glb) | [european_robin.md](./european_robin.md) |
| Common blackbird | *Turdus merula* | `bird.common_blackbird` | Procedural only, no 3D model | - | [common_blackbird.md](./common_blackbird.md) |
| Song thrush | *Turdus philomelos* | `bird.song_thrush` | Procedural only, no 3D model | - | [song_thrush.md](./song_thrush.md) |
| Common nightingale | *Luscinia megarhynchos* | `bird.common_nightingale` | Procedural only, no 3D model | - | [common_nightingale.md](./common_nightingale.md) |
| Great spotted woodpecker | *Dendrocopos major* | `bird.great_spotted_woodpecker` | Procedural only, no 3D model | - | [great_spotted_woodpecker.md](./great_spotted_woodpecker.md) |

## Models still to create

Procedural-only species, grouped by what they need first. Search links are starting points, not verified models.

Priority for the Act 1 slice:

- [wolf](./wolf.md): physical fight outside the city (`bst.wolf`).
- [brown bear](./brown_bear.md) and [wild boar](./wild_boar.md) (`bst.bear`, `bst.boar`, backlog): wild-margin threats. The boar has a GLB; the bear does not.
- Eagle, osprey, buzzard, kestrel: one raptor archetype rig (large flapping and gliding bird).
- Heron, lapwing, snipe, swan, cormorant, greylag goose, tern: waterfowl and wader archetype (large bird with long neck or legs).

Other procedural species can wait until their district spawn weight matters for play.

Count: 41 of 61 entries have only a procedural mesh and need a 3D model.

## Adding a species

1. Add the catalogue row first (`map_view_mammal_species.gd` or `map_view_bird_species.gd`), then a card here with the same slug.
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
