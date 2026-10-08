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
| [Households: furnished houses and life at home](./HOUSEHOLDS.md) | Implemented in the seamless city: furniture by household, rooms, hearth and firewood day, people at home; no player use of furniture |
| [Gate garrisons and patrols](./GATE_GARRISONS.md) | Implemented: census residents hold every gate by shift and walk the town and wall patrols, in their own clothes with a hat and spear |
| [World presentation (3D view)](./WORLD_PRESENTATION.md) | Implemented |
| [Cloud cells, cloud shadows, storm-cell lightning](./CLOUD_CELLS.md) | Implemented (R-1400): world-space cumulus and cumulonimbus, per-cloud ground shadows, lightning only from storm cells |
| [Night sky: stars and the Milky Way](./NIGHT_SKY.md) | Implemented (R-1443): round twinkling Hipparcos stars, Milky Way placed for Tallinn in 1343, seasonal sidereal drift |
| [Seamless Reval city (1343)](./SEAMLESS_CITY.md) | Playable preview (ADR 0031); no quests or saves yet |
| [Landmark sites in the seamless city](./CITY_LANDMARK_SITES.md) | Implemented for Raekoja plats (ADR 0032); other sites planned |
| [Church interiors](./CHURCH_INTERIORS.md) | In progress (R-1392): glazing implemented (R-1393, eight plates, per-church programmes); ornamental wall paintings (R-1396: consecration crosses, dado curtain, foliage band); liturgical objects, seating, figural murals planned |
| [Local fog banks, horizon haze, heat mirage](./LOCAL_ATMOSPHERE.md) | Implemented (R-1430): patchy weather-driven fog near water with own lighting, perspective-only distance haze, midsummer shimmer |
| [City sea, shore and harbour life](./CITY_SEA.md) | Implemented (FFT sea with storm swell, beach relief, shore stones, boardable boats, fish) |
| [Hanseatic cog](./SHIPS.md) | Implemented (lofted clinker hull, walkable interior, wind-driven sail and rope shaders, rudder) |
| [Village and house windows](./COTTAGE_WINDOWS.md) | Implemented (7 styles: platbands, shutters, slit, stone surround) |
| [Farmland, pastures and woods](./FARMLAND.md) | Implemented (fields, crops by date, pastures, woods; no far-field LOD yet) |
| [Living vegetation](./LIVING_VEGETATION.md) | Implemented (seasons, weather, leaf fall on hits) |
| [Vegetation realism (grass, grain fields, trees)](./VEGETATION_REALISM.md) | In progress: benchmark and budgets (R-1320) and procedural vegetation textures (R-1329) implemented; later phases planned |
| [Hoist ropes](./HOIST_ROPE.md) | Implemented (wind-swung rope and hook on hoist beams) |
| [Combat runtime](./COMBAT.md) | Foundation implemented; tower bosses unwired |
| [Combat animation](./COMBAT_ANIMATION.md) | Implemented |
| [HUD, menus, journal, maps](./HUD_AND_MENUS.md) | Implemented |
| [Settings and accessibility](./SETTINGS_AND_ACCESSIBILITY.md) | Implemented |
| [Magic](./MAGIC.md) | Design contract; runtime foundation and cookbook implemented |
| [Hammer combat and night missions](./COMBAT_NIGHT.md) | Design contract |
| [Living City](./LIVING_CITY.md) | Design contract; state only |
| [Living World routines](./LIVING_WORLD.md) | Implemented (R-1344): hourly civilian schedule |
| [NATURAL aspects](./NATURAL.md) | Design contract; state and display only |
| [Hingepuu psyche](./PSYCHE.md) | Design contract; state and display only |
| [Spirit dialogue combat](./SPIRIT_DIALOGUE.md) | Planned (ADR 0033); nothing implemented |
| [Muscle-driven procedural locomotion](./MUSCLE_LOCOMOTION.md) | Planned; build-time research prototype only (planar quadruped and biped walk) |

## All files in this folder

<!-- docs-index:start (generated by tools/docs_index.py; do not edit) -->

- [Flag cloth](FLAG_CLOTH.md)

<!-- docs-index:end -->
