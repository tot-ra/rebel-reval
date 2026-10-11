# Game systems

One page per implemented or planned feature. Each page opens with a `Status:` line (implemented, partial, or design contract), then covers player-facing behavior, runtime entry points, content, saved state, verification, and limits. The rule that every feature ships with its page is in [`AGENTS.md`](../../AGENTS.md#feature-documentation-mandatory).

| Page | Status |
|---|---|
| [Physical object catalog](./OBJECT_CATALOG.md) | Implemented (data, validator, bag rules); gameplay verbs and map gating unwired |
| [Quests, commissions, investigations](./QUESTS.md) | Implemented (Act 1); Act 2 finale and Act 3 ending are models only |
| [Dialogue, barks, localization](./DIALOGUE.md) | Implemented |
| [Sound effects](./AUDIO.md) | Implemented (Phases 0-1: catalog, SfxPlayer, buses, license gate; ADR 0035) |
| [Cutscenes](./CUTSCENES.md) | Implemented (stills tier, ADR 0034); video tier and audio reserved |
| [Game state, rules, saves](./STATE_AND_SAVES.md) | Implemented |
| [Time, phases, patrols](./TIME_AND_PHASES.md) | Implemented |
| [Factions, relationships, pressure, prices](./FACTIONS_AND_ECONOMY.md) | Implemented |
| [NPC mind: reflex, decision model, local LLM](./NPC_MIND.md) | Planned (ADR 0037 proposed) |
| [World life](./WORLD_LIFE.md) | Implemented in Lower Town; Padise and public events unwired |
| [Citizens: census, ledger, deep cards](./CITIZENS.md) | Implemented: census residents live in the seamless city with timetables, blank bodies and a click-for-info panel |
| [Citizen wardrobe: dress by rank, age, trade and arms](./CITIZEN_WARDROBE.md) | Implemented: per-body fitted layers (hoods, coifs, veils, aprons, aketon, mail, surcoat, helmets, keys, beads, scrips, sacks) chosen from the census; mantles, gowns, textiles, footwear planned (R-1664..R-1672) |
| [Named NPCs: registry and city presence](./NAMED_NPCS.md) | Implemented (R-1562, R-1563): registry of Wave A/B named NPCs, clock-driven posts in the seamless city, click panel with portrait and faction; overhead marker (R-1564), faction livery, chip and badge (R-1565); models planned |
| [Households: furnished houses and life at home](./HOUSEHOLDS.md) | Implemented in the seamless city: furniture by household, rooms, hearth and firewood day, people at home; no player use of furniture |
| [Gate garrisons and patrols](./GATE_GARRISONS.md) | Implemented: census residents hold every gate by shift and walk the town and wall patrols, in their own clothes with a hat and spear |
| [World presentation (3D view)](./WORLD_PRESENTATION.md) | Implemented |
| [Cloud cells, seasonal cumulus, shadows and storm lightning](./CLOUD_CELLS.md) | Implemented: discrete clouds and weather phenomena visual atlas with seasonal cumulus scaling |
| [Weather on the ground: puddles, drought and cracked earth](./WEATHER_GROUND.md) | Implemented (R-1516): drought spells, sun-baked dryness, cracked clay in dried puddle basins, rain soaks cracks before puddles return; after-rain cobble puddles and wet paving (R-1748) |
| [Night sky: stars and the Milky Way](./NIGHT_SKY.md) | Implemented (R-1443): round twinkling Hipparcos stars, Milky Way placed for Tallinn in 1343, seasonal sidereal drift |
| [Seamless Reval city (1343)](./SEAMLESS_CITY.md) | Playable preview (ADR 0031); no quests or saves yet |
| [City doors: wealth and landmark entrances](./CITY_DOORS.md) | Implemented (R-1692): separate wood/iron geometry, household tiers and explicit civic/church entrance profiles |
| [Regional sites (distant destinations)](./REGIONAL_SITES.md) | Implemented for the Paide pilot (R-1520, ADR 0042): site-parameterised builder and runtime, inland site with sky and weather, no sea; other sites planned |
| [Landmark sites in the seamless city](./CITY_LANDMARK_SITES.md) | Implemented for Raekoja plats (ADR 0032); other sites planned |
| [Church interiors](./CHURCH_INTERIORS.md) | In progress (R-1392): glazing implemented (R-1393, eight plates, per-church programmes); ornamental wall paintings (R-1396: consecration crosses, dado curtain, foliage band); liturgical objects, seating, figural murals planned |
| [City sea, shore and harbour life](./CITY_SEA.md) | Implemented (FFT sea with storm swell, beach relief, shore stones, boardable boats, fish) |
| [Hanseatic cog](./SHIPS.md) | Implemented (lofted clinker hull, walkable interior, wind-driven sail and rope shaders, rudder) |
| [Village and house windows](./COTTAGE_WINDOWS.md) | Implemented (7 styles: platbands, shutters, slit, stone surround) |
| [Farmland, pastures and woods](./FARMLAND.md) | Implemented (fields, crops by date, pastures, woods; no far-field LOD yet) |
| [Living vegetation: trees, shrubs, grass and ground cover](./LIVING_VEGETATION.md) | Implemented: 20 tree species, shrubs, blade grass, 3D wild plants, ecology placement, moss and fungi, seasons, shared wind, budgets, animated visual tour; grain fields and tree LOD chain planned (R-1319) |
| [Vegetation engineering: budgets, workflow, roadmap](./VEGETATION_ENGINEERING.md) | Implemented (R-1320, R-1329): procedural texture pipeline, performance budgets, change workflow, capture and test commands, known limits, grain/LOD roadmap |
| [Hoist ropes](./HOIST_ROPE.md) | Implemented (wind-swung rope and hook on hoist beams) |
| [Bestiary: spirit and physical creature roster](./BESTIARY.md) | Planned (R-1578): roster, card template and validator implemented; no cards yet |
| [Combat runtime](./COMBAT.md) | Foundation implemented; tower bosses unwired |
| [Combat animation](./COMBAT_ANIMATION.md) | Implemented |
| [HUD, menus, journal, maps](./HUD_AND_MENUS.md) | Implemented |
| [Settings and accessibility](./SETTINGS_AND_ACCESSIBILITY.md) | Implemented |
| [Performance monitor (F3)](./PERFORMANCE_MONITOR.md) | Implemented (developer overlay) |
| [Magic](./MAGIC.md) | Design contract; runtime foundation and cookbook implemented |
| [Hammer combat and night missions](./COMBAT_NIGHT.md) | Design contract |
| [Living City](./LIVING_CITY.md) | Design contract; state only |
| [Living World routines](./LIVING_WORLD.md) | Implemented (R-1344): hourly civilian schedule |
| [NATURAL aspects](./NATURAL.md) | Design contract; state and display only |
| [Hingepuu psyche](./PSYCHE.md) | Design contract; state and display only |
| [Spirit dialogue combat](./SPIRIT_DIALOGUE.md) | Planned (ADR 0033); nothing implemented |
| [Spirit sight, auras and soul lights](./SPIRIT_SIGHT.md) | Partial: toggle (R-1484) and aura data (R-1485) implemented; auras on screen planned (epic R-1483) |
| [Muscle-driven procedural locomotion](./MUSCLE_LOCOMOTION.md) | Planned; build-time research prototype only (planar quadruped and biped walk) |

## All files in this folder

<!-- docs-index:start (generated by tools/docs_index.py; do not edit) -->

- [Flag cloth](FLAG_CLOTH.md)
- [Renderer, post-process grade and HDR output](POST_PROCESS.md)
- [Seasons](SEASONS.md)
- [Sky and atmosphere: clouds, sunbeams, fog and haze](SKY_ATMOSPHERE.md)
- [Vegetation realism (merged)](VEGETATION_REALISM.md)
- [Water sandbox](WATER_SANDBOX.md)

<!-- docs-index:end -->
