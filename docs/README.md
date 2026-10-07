# Documentation hub

Every document in this repository is reachable from here. Start with the root [`README.md`](../README.md) for the game's vision and scope, and [`AGENTS.md`](../AGENTS.md) for how work is done. `python3 tools/docs_index.py --check` fails when a Markdown file is not reachable from the root README.

## Game systems (implemented features)

One page per feature, with status, behavior, code entry points, content, saved state, and verification. Index: [`SYSTEMS/`](./SYSTEMS/README.md).

| Area | Pages |
|---|---|
| Core loop | [Quests, commissions, investigations](./SYSTEMS/QUESTS.md) · [Dialogue and barks](./SYSTEMS/DIALOGUE.md) · [Cutscenes](./SYSTEMS/CUTSCENES.md) · [Game state, rules, saves](./SYSTEMS/STATE_AND_SAVES.md) · [Time and phases](./SYSTEMS/TIME_AND_PHASES.md) |
| Consequences | [Factions, relationships, pressure, prices](./SYSTEMS/FACTIONS_AND_ECONOMY.md) · [Living City Hope/Fear](./SYSTEMS/LIVING_CITY.md) · [World life](./SYSTEMS/WORLD_LIFE.md) |
| Action | [Combat runtime](./SYSTEMS/COMBAT.md) · [Combat animation](./SYSTEMS/COMBAT_ANIMATION.md) · [Hammer combat and night missions](./SYSTEMS/COMBAT_NIGHT.md) · [Magic](./SYSTEMS/MAGIC.md) |
| Kalev's inner world | [NATURAL aspects](./SYSTEMS/NATURAL.md) · [Hingepuu psyche](./SYSTEMS/PSYCHE.md) |
| Player interface | [HUD, menus, journal, maps](./SYSTEMS/HUD_AND_MENUS.md) · [Inventory](./INVENTORY_MECHANICS.md) · [Physical object catalog](./SYSTEMS/OBJECT_CATALOG.md) · [Controls](./CONTROLS.md) · [Settings and accessibility](./SYSTEMS/SETTINGS_AND_ACCESSIBILITY.md) |

## World building

| Topic | Pages |
|---|---|
| The 3D world (camera, sky, weather, water, vegetation, fauna, lighting) | [World presentation](./SYSTEMS/WORLD_PRESENTATION.md) · [Seamless Reval city](./SYSTEMS/SEAMLESS_CITY.md) · [Landmark sites](./SYSTEMS/CITY_LANDMARK_SITES.md) · [Vegetation realism plan](./SYSTEMS/VEGETATION_REALISM.md) · [Hoist ropes](./SYSTEMS/HOIST_ROPE.md) · [Sky/weather state contract](./SKY_WEATHER_STATE_CONTRACT.md) · [World-building visual gate](./WORLD_BUILDING_VISUAL_GATE.md) |
| Map system | [Map authoring (blueprints, compiler, stable IDs)](./MAP_AUTHORING.md) · [Map conversion plan](./MAP_CONVERSION_PLAN.md) · [Map alignment editor](./MAP_ALIGNMENT_EDITOR.md) · [Large-map chunking](./LARGE_MAP_CHUNKING_PLAN.md) · [Seamless streaming](./SEAMLESS_STREAMING_PLAN.md) |
| Locations beyond Reval (journey nodes, variety, resources to generate) | [Locations hub](./LOCATIONS/README.md) |
| City and landmarks | [Landmark narrative integration](./LANDMARK_NARRATIVE_INTEGRATION.md) · [Tourist landmarks](./TOURIST_LANDMARKS.md) · [1343 fortifications](./reports/reval_fortifications_1343.md) · [Legacy location notes](../scenes/README.md) |
| Nature | [Flora and fauna of 1343](./FLORA_FAUNA.md) |
| Task specs by stream | [World tasks](./tasks/README.md) (architecture, coast, urban form, water/sky, world) |

## Characters

- Active cast briefs (the seven core characters and promoted faction figures): [`CHARACTERS/`](./CHARACTERS/README.md)
- The city's people: a census of every resident of the 641-building city plan, a ledger per street, deep citizen cards, and faction pages: [`CITIZENS/`](./CITIZENS/README.md) (method in [`CITIZENS/CENSUS.md`](./CITIZENS/CENSUS.md))
- Full legacy roster by faction (seeds for promotion): [`characters/`](../characters/README.md); promotion order: [cast and faction promotion](./cast_faction_promotion.md)
- How characters are built (MPFB humans, shared rig, animation, wardrobe): [character generation](./CHARACTER_GENERATION.md), [realism backlog](./CHARACTER_REALISM_BACKLOG.md), [visual fidelity plan](./VISUAL_FIDELITY_PLAN.md), [Witcher 3 realism notes](./WITCHER3_REALISM_INSPIRATION.md)
- Legacy build and skill design notes: [`character/`](../character/README.md)

## Story, lore, and history

- Canon, timeline, and confidence labels: [`CANON.md`](./CANON.md) · historical audit: [`HISTORICAL_AUDIT.md`](./HISTORICAL_AUDIT.md)
- Quest scene scripts and branch maps: [`SCENES/`](./SCENES/README.md) · faction quest seeds: [`quests/`](./quests/README.md) · [quest seed shortlist](./quest_seed_shortlist.md)
- Folklore and Act 2 lore: [`lore/`](./lore/README.md)
- Story drafts and image prompts: [`story/`](../story/README.md) · cinematics: [`cinematics/`](../cinematics/README.md)
- Historical research (start here for evidence): [`history/RESEARCH_INDEX.md`](../history/RESEARCH_INDEX.md) · people and events wiki: [`wiki/`](../wiki/README.md)

## Content and data

- Content records and schemas: [`schemas/README.md`](../schemas/README.md) · [`content/`](../content/README.md) (examples, demo, quest packages, save fixtures)
- Dialogue localization and voice handoff: [`localization/README.md`](../localization/README.md)
- Manifests and budgets consumed by tools: `docs/data/*.json`

## Art and audio

- Visual baseline: [`ART_BIBLE.md`](./ART_BIBLE.md) · [material style-lock kit](./MATERIAL_STYLE_LOCK_KIT.md) · [AI texture generation](./TEXTURE_AI_GENERATION.md) · [fonts](./FONTS.md)
- Assets: [asset inventory](./ASSET_INVENTORY.md) · [storage policy](./ASSET_STORAGE_POLICY.md) · [storage backlog](./STORAGE_SIZE_BACKLOG.md) · [asset folders](../assets/README.md) · [generated asset runs](../generated/README.md) · [third-party notices](./THIRD_PARTY_NOTICES.md)
- Audio: [music library and attribution](../music/README.md) · [credits](../CREDITS.md) · [sound effects top 100](./SOUND_EFFECTS_TOP_100.md)

## Engineering

- [Runtime architecture and file ownership](./ARCHITECTURE.md) · [setup and headless commands](./SETUP.md) · [performance report](./PERFORMANCE_REPORT.md) · [known runtime defects](./reports/known_runtime_defects.md)
- Decisions: [`adr/`](./adr/README.md)
- Evidence, acceptance, and audits: [`reports/`](./reports/README.md), including the [code-health audit](./reports/code_health_audit_2026-10-07.md) of dead code and unwired features

## Planning and process

- Roadmap: [`ROADMAP.md`](./ROADMAP.md) · [`TODO.md`](../TODO.md) ID index · [task archive](./TASK_ARCHIVE.md) · [coordination archive](./ROADMAP_COORDINATION_ARCHIVE_2026-08-13.md)
- Agent roles and loops: [`agents/`](../agents/README.md) · [agent loops](./AGENT_LOOPS.md)
- Legacy design reintroduction (ADR 0017): [`LEGACY_REINTRODUCTION.md`](./LEGACY_REINTRODUCTION.md) and the seed documents [game pillars](./GAME-PILLARS.md), [gameplay](./GAMEPLAY.md), [night gameplay](./GAMEPLAY-NIGHT.md), [mini-games](./MINI_GAMES.md), [quests](./QUESTS.md), [research ideas](./IDEAS_RESEARCH.md)
- Archived material: [`archive/`](../archive/README.md)

## Unsorted root files

[`playbook.md`](../playbook.md) and [`rebel_art_status_report_2026-07-29.md`](../rebel_art_status_report_2026-07-29.md) sit at the repository root. They should move or be archived; see the [code-health audit](./reports/code_health_audit_2026-10-07.md).

## All files in this folder

<!-- docs-index:start (generated by tools/docs_index.py; do not edit) -->

#### `concept/`

- [Core character concept art](concept/characters/README.md)
- [Faction concept art](concept/factions/README.md)

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
