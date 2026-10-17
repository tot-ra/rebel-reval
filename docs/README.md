# Documentation hub

Every document in this repository is reachable from here. Start with the root [`README.md`](../README.md) for the game's vision and scope, and [`AGENTS.md`](../AGENTS.md) for how work is done. `python3 tools/docs_index.py --check` fails when a Markdown file is not reachable from the root README.

## Game systems (implemented features)

One page per feature, with status, behavior, code entry points, content, saved state, and verification. Index: [`SYSTEMS/`](./SYSTEMS/README.md).

| Area | Pages |
|---|---|
| Core loop | [Household cure (planned)](./SYSTEMS/HOUSEHOLD_CURE.md) · [Quests, commissions, investigations](./SYSTEMS/QUESTS.md) · [Dialogue and barks](./SYSTEMS/DIALOGUE.md) · [Cutscenes](./SYSTEMS/CUTSCENES.md) · [Sound effects](./SYSTEMS/AUDIO.md) · [Game state, rules, saves](./SYSTEMS/STATE_AND_SAVES.md) · [Time and phases](./SYSTEMS/TIME_AND_PHASES.md) · [Seasons](./SYSTEMS/SEASONS.md) |
| Consequences | [Factions, relationships, pressure, prices](./SYSTEMS/FACTIONS_AND_ECONOMY.md) · [Living City Hope/Fear](./SYSTEMS/LIVING_CITY.md) · [World life](./SYSTEMS/WORLD_LIFE.md) · [Daily routines](./SYSTEMS/LIVING_WORLD.md) · [Households and life at home](./SYSTEMS/HOUSEHOLDS.md) · [Water supply: wells and household water](./SYSTEMS/WATER_SUPPLY.md) · [Social life: venues and the week](./SYSTEMS/SOCIAL_LIFE.md) · [Pastimes: games and leisure](./SYSTEMS/PASTIMES.md) · [Named NPCs](./SYSTEMS/NAMED_NPCS.md) · [Citizen wardrobe](./SYSTEMS/CITIZEN_WARDROBE.md) · [Citizens: census, ledger, deep cards](./SYSTEMS/CITIZENS.md) · [Gate garrisons and patrols](./SYSTEMS/GATE_GARRISONS.md) · [Undress interaction](./SYSTEMS/UNDRESS_INTERACTION.md) |
| Action | [Combat runtime](./SYSTEMS/COMBAT.md) · [Combat animation](./SYSTEMS/COMBAT_ANIMATION.md) · [Motion style (ice, cold, wind, wounds)](./SYSTEMS/MOTION_STYLE.md) · [Hero exposure (wet, cold, warming)](./SYSTEMS/HERO_EXPOSURE.md) · [Hammer combat and night missions](./SYSTEMS/COMBAT_NIGHT.md) · [Magic](./SYSTEMS/MAGIC.md) · [Spirit dialogue combat](./SYSTEMS/SPIRIT_DIALOGUE.md) |
| Kalev's inner world | [NATURAL aspects](./SYSTEMS/NATURAL.md) · [Hingepuu psyche](./SYSTEMS/PSYCHE.md) · [Spirit sight, auras and soul lights](./SYSTEMS/SPIRIT_SIGHT.md) · [NPC mind: reflex, decision model](./SYSTEMS/NPC_MIND.md) |
| Player interface | [HUD, menus, journal, maps](./SYSTEMS/HUD_AND_MENUS.md) · [Inventory](./INVENTORY_MECHANICS.md) · [Physical object catalog](./SYSTEMS/OBJECT_CATALOG.md) · [Controls](./CONTROLS.md) · [Settings and accessibility](./SYSTEMS/SETTINGS_AND_ACCESSIBILITY.md) · [Performance monitor (F3)](./SYSTEMS/PERFORMANCE_MONITOR.md) · [Renderer, post-process grade and HDR](./SYSTEMS/POST_PROCESS.md) |

## World building

| Topic | Pages |
|---|---|
| The 3D world (camera, sky, weather, water, vegetation, fauna, lighting) | [World presentation](./SYSTEMS/WORLD_PRESENTATION.md) · [Sky and atmosphere: clouds, fog, haze](./SYSTEMS/SKY_ATMOSPHERE.md) · [Cloud cells and seasonal visual atlas](./SYSTEMS/CLOUD_CELLS.md) · [Puddles, drought and cracked earth](./SYSTEMS/WEATHER_GROUND.md) · [Animal dung on roads and pastures](./SYSTEMS/ANIMAL_DUNG.md) · [Night sky and Milky Way](./SYSTEMS/NIGHT_SKY.md) · [Night lighting and fire](./SYSTEMS/NIGHT_LIGHTING.md) · [Seamless Reval city](./SYSTEMS/SEAMLESS_CITY.md) · [Regional sites (Paide)](./SYSTEMS/REGIONAL_SITES.md) · [Landmark sites](./SYSTEMS/CITY_LANDMARK_SITES.md) · [City doors](./SYSTEMS/CITY_DOORS.md) · [Church interiors](./SYSTEMS/CHURCH_INTERIORS.md) · [Farmland and woods](./SYSTEMS/FARMLAND.md) · [City sea and shore](./SYSTEMS/CITY_SEA.md) · [Hanseatic cog](./SYSTEMS/SHIPS.md) · [Living vegetation: trees, grass, wild plants, moss](./SYSTEMS/LIVING_VEGETATION.md) · [Vegetation engineering](./SYSTEMS/VEGETATION_ENGINEERING.md) · [Vegetation realism](./SYSTEMS/VEGETATION_REALISM.md) · [Hoist ropes](./SYSTEMS/HOIST_ROPE.md) · [Flag cloth](./SYSTEMS/FLAG_CLOTH.md) · [Sky/weather state contract](./SKY_WEATHER_STATE_CONTRACT.md) · [World-building visual gate](./WORLD_BUILDING_VISUAL_GATE.md) |
| Map system | [Map authoring (blueprints, compiler, stable IDs)](./MAP_AUTHORING.md) · [Map conversion plan](./MAP_CONVERSION_PLAN.md) · [Map alignment editor](./MAP_ALIGNMENT_EDITOR.md) · [Large-map chunking](./LARGE_MAP_CHUNKING_PLAN.md) · [Seamless streaming](./SEAMLESS_STREAMING_PLAN.md) |
| Locations beyond Reval (journey nodes, variety, resources to generate) | [Locations hub](./LOCATIONS/README.md) |
| City and landmarks | [Landmark narrative integration](./LANDMARK_NARRATIVE_INTEGRATION.md) · [Tourist landmarks](./TOURIST_LANDMARKS.md) · [1343 fortifications](./reports/reval_fortifications_1343.md) · [Legacy location notes](../scenes/README.md) |
| Nature | [Flora and fauna of 1343](./FLORA_FAUNA.md) · [Plants: one card per tree, shrub, herb and crop with pictures](./FLORA/README.md) · [Animals and birds: one card per species with 3D model links](./FAUNA/README.md) · [Animal 3D sourcing and animation strategy](./ANIMAL_3D_SOURCING.md) · [Muscle-driven procedural locomotion](./SYSTEMS/MUSCLE_LOCOMOTION.md) |
| Task specs by stream | [World tasks](./tasks/README.md) (architecture, coast, urban form, water/sky, world) |
| Water sandbox | [Water sandbox](./SYSTEMS/WATER_SANDBOX.md) |
| Village architecture | [Cottage windows](./SYSTEMS/COTTAGE_WINDOWS.md) |

## Characters

- Active cast briefs (the seven core characters and promoted faction figures): [`CHARACTERS/`](./CHARACTERS/README.md)
- Creatures the apprentice meets, spirit and physical: roster, layers and card format in [`BESTIARY/`](./BESTIARY/README.md); system docs: [Bestiary](./SYSTEMS/BESTIARY.md)
- The city's people: a census of every resident of the 641-building city plan, a ledger per street, deep citizen cards, and faction pages: [`CITIZENS/`](./CITIZENS/README.md) (method in [`CITIZENS/CENSUS.md`](./CITIZENS/CENSUS.md))
- Full legacy roster by faction (seeds for promotion): [`characters/`](../characters/README.md); promotion order: [cast and faction promotion](./cast_faction_promotion.md)
- How characters are built (MPFB humans, shared rig, animation, wardrobe): [character generation](./CHARACTER_GENERATION.md), [realism backlog](./CHARACTER_REALISM_BACKLOG.md), [visual fidelity plan](./VISUAL_FIDELITY_PLAN.md), [Witcher 3 realism notes](./WITCHER3_REALISM_INSPIRATION.md)
- Legacy build and skill design notes: [`character/`](../character/README.md)

## Story, lore, and history

- Canon, timeline, and confidence labels: [`CANON.md`](./CANON.md) · historical audit: [`HISTORICAL_AUDIT.md`](./HISTORICAL_AUDIT.md)
- Quest scene scripts and branch maps: [`SCENES/`](./SCENES/README.md) · faction quest seeds: [`quests/`](./quests/README.md) · [quest idea log](./quests/IDEAS.md) · [quest seed shortlist](./quest_seed_shortlist.md)
- Folklore and Act 2 lore: [`lore/`](./lore/README.md)
- Story drafts and image prompts: [`story/`](../story/README.md) · cinematics: [`cinematics/`](../cinematics/README.md)
- Historical research (start here for evidence): [`history/RESEARCH_INDEX.md`](../history/RESEARCH_INDEX.md) · people and events wiki: [`wiki/`](../wiki/README.md)

## Content and data

- Content records and schemas: [`schemas/README.md`](../schemas/README.md) · [`content/`](../content/README.md) (examples, demo, quest packages, save fixtures)
- Dialogue localization and voice handoff: [`localization/README.md`](../localization/README.md)
- Manifests and budgets consumed by tools: `docs/data/*.json`

## Art and audio

- Visual baseline: [`ART_BIBLE.md`](./ART_BIBLE.md) · [material style-lock kit](./MATERIAL_STYLE_LOCK_KIT.md) · [equipment variants and art bible](./SYSTEMS/EQUIPMENT_VARIANTS.md) · [AI texture generation](./TEXTURE_AI_GENERATION.md) · [fonts](./FONTS.md)
- Assets: [asset inventory](./ASSET_INVENTORY.md) · [storage policy](./ASSET_STORAGE_POLICY.md) · [storage backlog](./STORAGE_SIZE_BACKLOG.md) · [asset folders](../assets/README.md) · [generated asset runs](../generated/README.md) · [third-party notices](./THIRD_PARTY_NOTICES.md)
- Audio: [music library and attribution](../music/README.md) · [credits](../CREDITS.md) · [sound effects top 100](./SOUND_EFFECTS_TOP_100.md)

## Engineering

- [Runtime architecture and file ownership](./ARCHITECTURE.md) · [setup and headless commands](./SETUP.md) · [performance report](./PERFORMANCE_REPORT.md) · [known runtime defects](./reports/known_runtime_defects.md)
- Decisions: [`adr/`](./adr/README.md) · [content-maturity policy (ADR 0060, proposed)](./adr/0060-content-maturity-policy.md)
- Evidence, acceptance, and audits: [`reports/`](./reports/README.md), including the [code-health audit](./reports/code_health_audit_2026-10-07.md) of dead code and unwired features

## Planning and process

- Roadmap: [`ROADMAP.md`](./ROADMAP.md) · [`TODO.md`](../TODO.md) ID index · [task archive](./TASK_ARCHIVE.md) · [coordination archive](./ROADMAP_COORDINATION_ARCHIVE_2026-08-13.md)
- Agent roles and loops: [`agents/`](../agents/README.md) · [agent loops](./AGENT_LOOPS.md)
- Legacy design reintroduction (ADR 0017): [`LEGACY_REINTRODUCTION.md`](./LEGACY_REINTRODUCTION.md) and the seed documents [game pillars](./GAME-PILLARS.md), [gameplay](./GAMEPLAY.md), [night gameplay](./GAMEPLAY-NIGHT.md), [mini-games](./MINI_GAMES.md), [quests](./QUESTS.md), [research ideas](./IDEAS_RESEARCH.md)
- Archived material: [`archive/`](../archive/README.md)

## Unsorted root files

[`playbook.md`](../playbook.md) still sits at the repository root; the [code-health audit](./reports/code_health_audit_2026-10-07.md) suggests moving it under `agents/`. The other stray file, `rebel_art_status_report_2026-07-29.md`, has been moved to [`docs/reports/rebel_art_status_report_2026-07-29.md`](./reports/rebel_art_status_report_2026-07-29.md).

## All files in this folder

<!-- docs-index:start (generated by tools/docs_index.py; do not edit) -->

#### `BESTIARY/`

- [Creature card template](BESTIARY/TEMPLATE.md)
- [Black Cloak fighter](BESTIARY/cards/black_cloak_fighter.md)
- [Brute](BESTIARY/cards/brute.md)
- [Domovoy](BESTIARY/cards/domovoi.md)
- [Hiid](BESTIARY/cards/hiid.md)
- [Hiie hirv (the grove deer)](BESTIARY/cards/hiie_hirv.md)
- [Hinged](BESTIARY/cards/hinged.md)
- [Katk](BESTIARY/cards/katk.md)
- [Kodukäija](BESTIARY/cards/kodukaija.md)
- [Kratt](BESTIARY/cards/kratt.md)
- [Külmking](BESTIARY/cards/kulmking.md)
- [Libahunt](BESTIARY/cards/libahunt.md)
- [Luupainaja](BESTIARY/cards/luupainaja.md)
- [Maa-alused](BESTIARY/cards/maa_alused.md)
- [Majahaldjas](BESTIARY/cards/majahaldjas.md)
- [Marras (omen-double)](BESTIARY/cards/marras.md)
- [Metsavana (Metsik, Leshy)](BESTIARY/cards/metsavana.md)
- [Myling (Näkiline)](BESTIARY/cards/myling.md)
- [Näkk](BESTIARY/cards/nakk.md)
- [Nõid (cunning-folk)](BESTIARY/cards/noid.md)
- [Põhja Konn](BESTIARY/cards/pohja_konn.md)
- [Puuk](BESTIARY/cards/puuk.md)
- [Rehepapp](BESTIARY/cards/rehepapp.md)
- [Road bandit](BESTIARY/cards/road_bandit.md)
- [Saboteur](BESTIARY/cards/saboteur.md)
- [Spirit-caller](BESTIARY/cards/spirit_caller.md)
- [Street thug](BESTIARY/cards/street_thug.md)
- [Tulihänd](BESTIARY/cards/tulihand.md)
- [Tulukesed (grave-lights)](BESTIARY/cards/tulukesed.md)
- [Vanapagan](BESTIARY/cards/vanapagan.md)
- [Vanapagan cultist](BESTIARY/cards/vanapagan_cultist.md)
- [Vetevana](BESTIARY/cards/vetevana.md)
- [Virmalised (the sky battle)](BESTIARY/cards/virmalised.md)
- [Vodyanoy](BESTIARY/cards/vodyanoy.md)

#### `concept/`

- [Faction concept art](concept/factions/README.md)

#### `FLORA/`

- [Barley](FLORA/crops/barley.md)
- [Broad bean](FLORA/crops/broad_bean.md)
- [Cabbage](FLORA/crops/cabbage.md)
- [Flax](FLORA/crops/flax.md)
- [Garlic](FLORA/crops/garlic.md)
- [Hemp](FLORA/crops/hemp.md)
- [Hops](FLORA/crops/hops.md)
- [Oat](FLORA/crops/oat.md)
- [Onion](FLORA/crops/onion.md)
- [Pea](FLORA/crops/pea.md)
- [Rye](FLORA/crops/rye.md)
- [Turnip](FLORA/crops/turnip.md)
- [Wheat](FLORA/crops/wheat.md)
- [Burdock](FLORA/herbs/burdock.md)
- [Caraway](FLORA/herbs/caraway.md)
- [Bulrush / cattail](FLORA/herbs/cattail.md)
- [Chamomile](FLORA/herbs/chamomile.md)
- [Dandelion](FLORA/herbs/dandelion.md)
- [Bracken / male fern](FLORA/herbs/fern.md)
- [Mint](FLORA/herbs/mint.md)
- [Sphagnum moss](FLORA/herbs/moss.md)
- [Mugwort](FLORA/herbs/mugwort.md)
- [Stinging nettle](FLORA/herbs/nettle.md)
- [Oxeye daisy](FLORA/herbs/oxeye_daisy.md)
- [Broadleaf plantain](FLORA/herbs/plantain.md)
- [Red clover](FLORA/herbs/red_clover.md)
- [Common reed](FLORA/herbs/reed.md)
- [St John's wort](FLORA/herbs/st_johns_wort.md)
- [Creeping thistle](FLORA/herbs/thistle.md)
- [White water lily](FLORA/herbs/water_lily.md)
- [White clover](FLORA/herbs/white_clover.md)
- [Yarrow](FLORA/herbs/yarrow.md)
- [Alder shrub](FLORA/shrubs/alder_shrub.md)
- [Bilberry](FLORA/shrubs/bilberry.md)
- [Blackthorn](FLORA/shrubs/blackthorn.md)
- [Bog rosemary](FLORA/shrubs/bog_rosemary.md)
- [Cloudberry](FLORA/shrubs/cloudberry.md)
- [Cowberry](FLORA/shrubs/cowberry.md)
- [Cranberry](FLORA/shrubs/cranberry.md)
- [Crowberry](FLORA/shrubs/crowberry.md)
- [Dog rose](FLORA/shrubs/dog_rose.md)
- [Elder](FLORA/shrubs/elder.md)
- [Guelder rose](FLORA/shrubs/guelder_rose.md)
- [Hawthorn](FLORA/shrubs/hawthorn.md)
- [Hazel shrub](FLORA/shrubs/hazel_shrub.md)
- [Heather](FLORA/shrubs/heather.md)
- [Juniper shrub](FLORA/shrubs/juniper_shrub.md)
- [Raspberry](FLORA/shrubs/raspberry.md)
- [Sea buckthorn](FLORA/shrubs/sea_buckthorn.md)
- [Spindle](FLORA/shrubs/spindle.md)
- [Wild strawberry](FLORA/shrubs/wild_strawberry.md)
- [Willow shrub](FLORA/shrubs/willow_shrub.md)
- [Alder](FLORA/trees/alder.md)
- [Apple](FLORA/trees/apple.md)
- [Ash](FLORA/trees/ash.md)
- [Aspen](FLORA/trees/aspen.md)
- [Birch](FLORA/trees/birch.md)
- [Blackthorn](FLORA/trees/blackthorn.md)
- [Sour cherry](FLORA/trees/cherry.md)
- [Elm](FLORA/trees/elm.md)
- [Hawthorn](FLORA/trees/hawthorn.md)
- [Hazel](FLORA/trees/hazel.md)
- [Juniper](FLORA/trees/juniper.md)
- [Linden](FLORA/trees/linden.md)
- [Norway maple](FLORA/trees/maple.md)
- [Oak](FLORA/trees/oak.md)
- [Pear](FLORA/trees/pear.md)
- [Scots pine](FLORA/trees/pine.md)
- [Plum](FLORA/trees/plum.md)
- [Rowan](FLORA/trees/rowan.md)
- [Norway spruce](FLORA/trees/spruce.md)
- [Willow](FLORA/trees/willow.md)

#### `LOCATIONS/`

- [Architecture Typology across the journey nodes](LOCATIONS/ARCHITECTURE_TYPOLOGY.md)
- [Biomes and Wildlife across the journey nodes](LOCATIONS/BIOMES_AND_WILDLIFE.md)
- [Cultures and Languages across the journey nodes](LOCATIONS/CULTURES_AND_LANGUAGES.md)
- [Baltic Klint Coast (Glint coast; Estonian Põhjaranniku klint, Low German de Strand, 1343 name unverified)](LOCATIONS/baltic_klint_coast.md)
- [Haapsalu (Hapsal, Läänemaa, seat of Ösel-Wiek)](LOCATIONS/haapsalu_laanemaa.md)
- [Harju Village and Countryside (Harria / Harrien, Rävala)](LOCATIONS/harju_village.md)
- [Kanavere Bog (Kanavere raba, eastern Harria)](LOCATIONS/kanavere_bog.md)
- [Narva and the Peipus shore (Narwa, Narova crossing)](LOCATIONS/narva_peipus_east.md)
- [Otepää and Vastseliina Frontier (Odenpäh, Neuhausen, Ugandi borderland)](LOCATIONS/otepaa_vastseliina_frontier.md)
- [Padise Monastery (Padis, Cistercian abbey on the Kloostri river)](LOCATIONS/padise_monastery.md)
- [Paide Castle (Wittenstein / Weissenstein, Paide)](LOCATIONS/paide_castle.md)
- [Pärnu (Pernau, New Pernau and Old Pernau)](LOCATIONS/parnu.md)
- [Pöide Castle (Peude, Order convent castle with fortified church, Saaremaa)](LOCATIONS/poide_castle.md)
- [Rakvere (Wesenberg, Tarvanpea)](LOCATIONS/rakvere_wesenberg.md)
- [The Rebel Kings' Camp (Harju command camp, eastern Harria corridor)](LOCATIONS/rebel_kings_camp.md)
- [Saaremaa (Ösel; north coast, alvar and the Kaali crater)](LOCATIONS/saaremaa.md)
- [The Sacred Grove (Hiis, Metsik's oak)](LOCATIONS/sacred_grove.md)
- [Sõjamäe and the Lake Ülemiste Shore (Sõjamäe, Ülemiste järv)](LOCATIONS/sojamae.md)
- [Soomaa Flood Refuge (spring flood plains and raised bog of the Pärnu/Viljandi hinterland; 1343 name unverified)](LOCATIONS/soomaa_flood_refuge.md)
- [Tartu (Dorpat, Terra Mariana / Bishopric of Dorpat)](LOCATIONS/tartu_dorpat.md)
- [Viljandi (Fellin, Sakala county)](LOCATIONS/viljandi_fellin.md)

<!-- docs-index:end -->
