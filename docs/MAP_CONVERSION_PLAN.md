# Map Conversion Plan

Recorded: 2026-07-16
Planning baseline: repository state after P0-034 and P0-042
Execution gate: P0-040 must be approved before any conversion task in this plan starts

## Purpose and non-goals

This document is the executable conversion program for every tracked Godot scene and every map or level scene currently represented by a `.tscn`. It records disposition, canonical responsibility or location, terrain treatment, bounds, required set dressing, transitions, collision and navigation, source references, and the target declarative definition.

This planning change does not implement, convert, activate, or remove a map. The dimensions below are authoring bounds in cells. P0-043 must derive world-pixel dimensions from the P0-040-approved cell size and camera metrics before production conversion begins. The current P0-042 prototype uses 32 world pixels per cell.

## Scope and activation rule

- The only production-playable map portfolio before the vertical-slice gate is the connected Lower Town slice: Kalev's smithy interior, smithy courtyard and street, brewery approach, cistern, and watch checkpoint.
- `reval_center`, its market interiors, and `reval_north` may be converted only as `active=false`, developer-only prototypes after the slice gate. Prototype work must not edit `content/transitions/active_destinations.json`, the main menu Start flow, or release export inclusion.
- Harbor, Toompea, world locations, castles, sacred grove, and campaign event scenes are archived concepts. Their source notes and reference images may be retained, but their `.tscn` shells are not conversion commitments.
- No map outside the approved slice may become playable until a maintainer accepts a written scope-change artifact under `AGENTS.md` "Scope-change rule". That artifact must name equivalent scope removal and a strict TODO task with exact allowed files and verification.
- A map is considered active if it is reachable from Start, listed active in the transition manifest, loaded by active content, or included in a release traversal. Renaming it "prototype" is not sufficient.

## Disposition semantics

| Status | Meaning |
|--------|---------|
| `convert` | Replace legacy authored geometry with a declarative map definition after its dependencies and gates pass. |
| `retain` | Keep the scene as a support, test, or non-production reference. Retention does not approve gameplay activation. |
| `archive` | Do not convert. Preserve useful source references, then remove or exclude the scene shell from runtime import and traversal in the archive tasks. |

Roles `level`, `map`, and `event` have full conversion specifications later in this document. Other roles are inventoried so scene coverage remains exact, but terrain and world geometry are not applicable to them.

## Complete `.tscn` disposition index

| Scene | Role | Status | Canonical location or responsibility | Scope and activation | Target definition |
|-------|------|--------|--------------------------------------|----------------------|-------------------|
| `game.tscn` | support | `archive` | Obsolete main-menu wrapper | Never active; `project.godot` already starts the menu directly | none - archive |
| `player.tscn` | actor | `convert` | Shared Kalev actor | Shared by approved maps after P0-037 and P0-040 | not a map definition; P0-034 actor conversion |
| `assets/characters/cat/cat_rig.tscn` | actor | `retain` | Forge cat ambient actor rig | Smithy interior only; not a player or commission target | not a map definition; P0-037 ambient actor |
| `assets/characters/kalev/kalev.tscn` | actor | `convert` | Kalev player variant on shared rig | Approved maps after P0-037 and P0-040 | not a map definition; P0-037 actor conversion |
| `assets/characters/shared/hammer.tscn` | support | `retain` | Shared hammer equipment mesh | Equipment swap on shared rig; combat and forge feedback | not a map definition |
| `assets/characters/shared/shared_character_rig.tscn` | actor | `convert` | Shared low-poly character rig base | Kalev and NPC variants after P0-037 and P0-040 | not a map definition; P0-037 actor conversion |
| `assets/characters/shared/spear.tscn` | support | `retain` | Shared spear equipment mesh | Demo forge pickup visual; D-003 and future commissions | not a map definition |
| `assets/characters/showcase/character_rig_showcase.tscn` | test | `retain` | Character rig animation showcase | Developer-only P0-037 verification; never release-playable | not a map definition |
| `assets/characters/variants/henning.tscn` | actor | `retain` | Henning NPC variant | Smithy ambient NPC; slice cast after P0-037 | not a map definition; P0-037 actor conversion |
| `assets/characters/variants/innkeeper.tscn` | actor | `retain` | Innkeeper NPC variant | Future slice cast; texture and equipment swap only | not a map definition; P0-037 actor conversion |
| `assets/characters/variants/mart.tscn` | actor | `retain` | Mart NPC variant | Demo dialogue target; slice cast after P0-037 | not a map definition; P0-037 actor conversion |
| `scenes/comparison_room/comparison_room.tscn` | level | `retain` | `dev.comparison_room.baseline` | Developer-only reference; never release-playable | none - retained procedural reference |
| `scenes/comparison_room/diamond_isometric_8_direction.tscn` | level | `archive` | `dev.comparison_room.legacy_isometric` | Superseded after P0-040; screenshots and report remain | none - archive |
| `scenes/comparison_room/orthogonal_4_direction.tscn` | level | `retain` | `dev.comparison_room.orthogonal` | Developer-only reference; never release-playable | none - retained procedural reference |
| `scenes/elements/FadeArea.tscn` | support | `convert` | Shared foreground fade volume | Approved-map component only | not a map definition; P0-034 component conversion |
| `scenes/elements/UI.tscn` | ui | `archive` | Superseded NATURAL aspects HUD | Remove under P0-041; never active afterward | none - archive |
| `scenes/elements/building.tscn` | support | `convert` | Shared building visual and footprint | Approved-map component only | not a map definition; P0-034 component conversion |
| `scenes/elements/door.tscn` | support | `convert` | Shared transition and spawn component | Approved destinations only | not a map definition; P0-034 component conversion |
| `scenes/elements/gameplay_help_hud.tscn` | ui | `retain` | Legacy control-hint scene (empty) | Hints unified into bottom `QuickAccessMenu` on `player.tscn`; scene kept for inventory retain | not a map definition |
| `scenes/elements/location_hud.tscn` | ui | `retain` | District location title HUD | Active overlay on approved maps; replaces legacy NATURAL HUD scope | not a map definition |
| `scenes/elements/minimap_hud.tscn` | ui | `retain` | In-scene minimap HUD | P1-032 terrain and player overlay on approved maps; toggles with `toggle_minimap` (`N`) | not a map definition |
| `scenes/elements/npc.tscn` | actor | `convert` | Shared NPC actor | Approved maps after rig conversion | not a map definition; P0-034 actor conversion |
| `scenes/elements/turret.tscn` | support | `convert` | Shared wall or tower component | Approved-map component only | not a map definition; P0-034 component conversion |
| `scenes/events/paldiski.tscn` | event | `archive` | `loc.paldiski` legacy pirate outpost concept | Outside campaign scope; never activate | none - archive |
| `scenes/interaction/interactable.tscn` | support | `retain` | Shared focus and prompt interaction component | Demo and slice interaction loop via `Interactable` | not a map definition |
| `scenes/interaction/interaction_test.tscn` | test | `retain` | Interaction controller verification scene | Developer-only D-003 and input checks; never release-playable | not a map definition |
| `scenes/events/pernau.tscn` | event | `archive` | `loc.parnu` legacy battle concept | Playable Pärnu is explicitly excluded; never activate | none - archive |
| `scenes/events/pskov_arrival_battle.tscn` | event | `archive` | `event.pskov_arrival_battle` | Army battle and playable Pskov are excluded; never activate | none - archive |
| `scenes/events/rebel_kings.tscn` | event | `archive` | `event.rebel_kings_camp` | Multi-army campaign concept; never activate | none - archive |
| `scenes/events/saaremaa.tscn` | event | `archive` | `loc.saaremaa` legacy campaign hub | Playable Saaremaa is explicitly excluded; never activate | none - archive |
| `scenes/events/swedesh_outpost.tscn` | event | `archive` | `loc.swedish_outpost` legacy Finland concept | Playable Sweden is explicitly excluded; never activate | none - archive |
| `scenes/events/swedish_arrival.tscn` | event | `archive` | `event.swedish_arrival` | Fleet intervention campaign concept; never activate | none - archive |
| `scenes/harbor/harbor.tscn` | level | `archive` | `loc.reval_harbor` legacy combined-harbour shell | Replaced by the split Trade and Fishing Harbour prototypes; never activate | none - archive |
| `scenes/harbor/harbor_north.tscn` | level | `convert` | `loc.reval_harbor.trade` | `active=false` Trade Harbour prototype until separate approval artifact | `scripts/map/definitions/outdoor/reval_harbor_north_definition.gd` |
| `scenes/harbor/harbor_east.tscn` | level | `convert` | `loc.reval_harbor.fishing` | `active=false` Fishing Harbour prototype until separate approval artifact | `scripts/map/definitions/outdoor/reval_harbor_east_definition.gd` |
| `scenes/reval_east/viru_gate_foreland/viru_gate_foreland.tscn` | level | `convert` | `loc.reval.pirita` | `active=false` Pirita River crossing prototype (stable map ID `viru_gate_foreland`); developer traversal only until a separate approval artifact | `scripts/map/definitions/outdoor/viru_gate_foreland_definition.gd` |
| `scenes/harbor/warehouse.tscn` | level | `archive` | `loc.reval_harbor.warehouse` legacy interior prototype | Retired by P0-046; definition and markdown remain for audit only | none - archive |
| `scenes/intro/intro.tscn` | support | `archive` | Empty legacy intro shell | Main menu owns intro presentation; never active | none - archive |
| `scenes/map/map.tscn` | map | `archive` | `ref.estonia_world_map` | Static reference image retained under `.gdignore`; runtime Estonia UI uses `assets/UI/estonia_world_map.png` | none - archive |
| `scenes/world_travel/world_sacred_grove.tscn` | level | `convert` | `loc.world_sacred_grove` | Developer-only global-map placeholder south of Reval; `release=false` | `scripts/map/definitions/outdoor/distant_location_definitions.gd` |
| `scenes/world_travel/world_harju.tscn` | level | `convert` | `loc.world_harju` | Developer-only global-map placeholder east via Viru road; `release=false` | `scripts/map/definitions/outdoor/distant_location_definitions.gd` |
| `scenes/world_travel/world_padise.tscn` | level | `convert` | `loc.world_padise` | Developer-only global-map placeholder west via Toompea; `release=false` | `scripts/map/definitions/outdoor/distant_location_definitions.gd` |
| `scenes/world_travel/world_saaremaa.tscn` | level | `convert` | `loc.world_saaremaa` | Developer-only global-map island placeholder via Trade Harbour; `release=false` | `scripts/map/definitions/outdoor/distant_location_definitions.gd` |
| `scenes/world_travel/world_rebel_kings.tscn` | level | `convert` | `loc.world_rebel_kings` | Developer-only global-map Act 2 Harju command camp; `release=false` | `scripts/map/definitions/outdoor/distant_location_definitions.gd` |
| `scenes/world_travel/world_kanavere.tscn` | level | `convert` | `loc.world_kanavere` | Developer-only global-map May 11 battlefield placeholder; `release=false` | `scripts/map/definitions/outdoor/distant_location_definitions.gd` |
| `scenes/world_travel/world_sojamae.tscn` | level | `convert` | `loc.world_sojamae` | Developer-only global-map May 14 battlefield placeholder; `release=false` | `scripts/map/definitions/outdoor/distant_location_definitions.gd` |
| `scenes/world_travel/world_paide.tscn` | level | `convert` | `loc.world_paide` | Developer-only global-map Act 2 Paide Castle placeholder; `release=false` | `scripts/map/definitions/outdoor/distant_location_definitions.gd` |
| `scenes/world_travel/world_parnu.tscn` | level | `convert` | `loc.world_parnu` | Developer-only global-map southern campaign town placeholder; `release=false` | `scripts/map/definitions/outdoor/distant_location_definitions.gd` |
| `scenes/world_travel/world_poide.tscn` | level | `convert` | `loc.world_poide` | Developer-only global-map Act 3 Saaremaa castle placeholder; `release=false` | `scripts/map/definitions/outdoor/distant_location_definitions.gd` |
| `scenes/map_prototype/smithy_courtyard.tscn` | level | `retain` | `loc.smithy_courtyard` authoring spike | Developer-only P0-042 prototype; not an active destination | `scripts/map/smithy_courtyard_definition.gd` |
| `scenes/menu/main_menu.tscn` | ui | `retain` | Main menu and Start flow | Active UI, not a map | not a map definition |
| `scenes/ui/forge_commission_overlay.tscn` | ui | `retain` | Forge commission flow overlay | P1-019a smithy commission UI; blocks movement until closed | not a map definition |
| `scenes/ui/inventory_overlay.tscn` | ui | `retain` | Session bag overlay | Demo D-003 inventory UI; persists via `GameState` | not a map definition |
| `scenes/ui/journal_overlay.tscn` | ui | `retain` | Quest journal overlay | P1-016 objective and evidence UI; toggles with quick-access menu or `J` | not a map definition |
| `scenes/ui/reflection_overlay.tscn` | ui | `retain` | Hingepuu reflection overlay | P2-011 morning reflection; Duty/Fury/Mercy conviction choice | not a map definition |
| `scenes/reval_center/market_civic_quarter/olaf_guild_hall.tscn` | level | `convert` | `loc.lower_town.st_olafs_guild_hall` | `active=false` prototype only until separate approval artifact | `scripts/map/definitions/prototypes/st_olafs_guild_hall_definition.gd` |
| `scenes/reval_archbishops_garden/reval_archbishops_garden.tscn` | level | `convert` | `loc.toompea.archbishops_garden` | `active=false` western Toompea prototype; developer traversal only until a separate approval artifact | `scripts/map/definitions/prototypes/archbishops_garden_definition.gd` |
| `scenes/reval_center/reval_center.tscn` | level | `convert` | `loc.lower_town.market_civic_quarter` | `active=false` prototype only until separate approval artifact | `scripts/map/definitions/prototypes/market_civic_quarter_definition.gd` |
| `scenes/reval_east/forge/forge.tscn` | level | `convert` | `loc.kalev_smithy` | Approved vertical-slice interior | `scripts/map/definitions/lower_town/kalev_smithy_definition.gd` |
| `scenes/reval_east/forge/forge_cat.tscn` | actor | `retain` | Smithy ambient cat | `loc.kalev_smithy` interior only; navigation and idle behavior | not a map definition |
| `scenes/reval_east/forge/smithy_henning.tscn` | actor | `retain` | Smithy apprentice Henning | `loc.kalev_smithy` interior patrol and idle | not a map definition |
| `assets/characters/variants/townswoman.tscn` | actor | `retain` | Shared-rig townswoman variant | Ambient Lower Town NPC body; not a map destination | not a map definition |
| `scenes/reval_east/reval_east.tscn` | level | `convert` | `loc.lower_town.slice` | Approved vertical-slice exterior; replaces legacy east-district scale | `scripts/map/definitions/lower_town/lower_town_slice_definition.gd` |
| `scenes/reval_monastery/reval_monastery.tscn` | level | `convert` | `loc.lower_town.monastery_quarter` | `active=false` prototype only until separate approval artifact | `scripts/map/definitions/prototypes/monastery_quarter_definition.gd` |
| `scenes/reval_north/reval_north.tscn` | level | `convert` | `loc.lower_town.north_quarter` | `active=false` prototype only until separate approval artifact | `scripts/map/definitions/prototypes/north_quarter_definition.gd` |
| `scenes/reval_south/reval_south.tscn` | level | `convert` | `loc.lower_town.south_quarter` | `active=false` prototype only until separate approval artifact | `scripts/map/definitions/prototypes/south_quarter_definition.gd` |
| `scenes/reval_toompea/reval_toompea.tscn` | level | `convert` | `loc.toompea.quarter` | `active=false` prototype only until separate approval artifact | `scripts/map/definitions/prototypes/toompea_quarter_definition.gd` |
| `scenes/reval_toompea/domberg.tscn` | level | `archive` | `loc.toompea.castle` legacy concept | Legacy shell retained as evidence; runtime Toompea uses `reval_toompea.tscn` | none - archive |
| `scenes/reval_toompea/maria_toomkirik.tscn` | level | `archive` | `loc.toompea.cathedral` legacy concept | Legacy shell retained as evidence; runtime Toompea uses `reval_toompea.tscn` | none - archive |
| `scenes/tests/font_glyph_render_test.tscn` | test | `retain` | Font and diacritic verification | Developer-only test | not a map definition |
| `scenes/tests/dialogue_ui_test.tscn` | test | `retain` | Dialogue UI and settings review | Developer-only P1-012/P1-013 test | not a map definition |
| `scenes/tests/dialogue_overflow_test.tscn` | test | `retain` | Pseudo-localization overflow review | Developer-only P1-014 layout stress test | not a map definition |
| `scenes/tests/combat_room.tscn` | test | `retain` | Combat integration room | Developer-only P1-024 hammer/guard/Iron smoke host | not a map definition |
| `scenes/tests/night_encounter_stub.tscn` | test | `retain` | Night consequence integration stub | Developer-only P1-025b/P1-027a host; never release-playable | not a map definition |
| `scenes/world/haapsalu_castle.tscn` | level | `archive` | `loc.haapsalu_castle` legacy concept | Outside Reval and slice; never activate | none - archive |
| `scenes/interaction/world_item.tscn` | support | `retain` | Pickup world-item component | Demo D-003 forge pickup via `WorldItemController` | not a map definition |
| `scenes/world/harju_village.tscn` | level | `archive` | `loc.harju_village` legacy concept | Open-world countryside is excluded; never activate | none - archive |
| `scenes/world/karja_fortress.tscn` | level | `archive` | `loc.karja_fortress` legacy concept | Saaremaa battle map is excluded; never activate | none - archive |
| `scenes/world/maasilinna_castle.tscn` | level | `archive` | `loc.maasilinna_castle` post-uprising legacy concept | Outside campaign timeline and scope; never activate | none - archive |
| `scenes/world/padise/padise_monastery1.tscn` | level | `archive` | `loc.padise_monastery.before` legacy concept | Outside Reval and slice; never activate | none - archive |
| `scenes/world/padise/padise_monastery2.tscn` | level | `archive` | `loc.padise_monastery.after` legacy concept | Outside Reval and slice; never activate | none - archive |
| `scenes/world/paide_castle.tscn` | level | `archive` | `loc.paide_castle` legacy concept | Multi-year uprising campaign is excluded; never activate | none - archive |
| `scenes/world/poide_castle.tscn` | level | `archive` | `loc.poide_castle` legacy concept | Playable Saaremaa is excluded; never activate | none - archive |
| `scenes/world/sacred_grove.tscn` | level | `archive` | `loc.sacred_grove` speculative folklore concept | Not the approved ambiguous folklore quest; never activate | none - archive |
| `scenes/world/viljandi_castle.tscn` | level | `archive` | `loc.viljandi_castle` legacy concept | Castle infiltration campaign is excluded; never activate | none - archive |
| `tools/benchmarks/large_map_benchmark.tscn` | test | `retain` | Large-map CI benchmark host | Developer and CI map-pipeline performance probe; never release-playable | not a map definition |
| `tools/benchmarks/lower_town_scene_benchmark.tscn` | test | `retain` | Lower Town scene benchmark host | Developer and CI slice scene-load probe; never release-playable | not a map definition |
| `tools/capture_demo_walkthrough_host.tscn` | test | `retain` | Packaged demo walkthrough capture host | Developer/CI host for D-004 frame capture; never release-playable | not a map definition |

## Detailed map, level, and event specifications

`none - archive` in a terrain, bounds, transition, or collision field is an explicit decision not to build gameplay geometry. Source references remain available for historical or layout research but are not approved runtime assets.

### Development references and atlas

| Scene | Status | Terrain palette | World bounds | Required buildings and props | Transitions and spawns | Collision and navigation | Source references | Target declarative definition |
|-------|--------|-----------------|--------------|------------------------------|------------------------|--------------------------|-------------------|-------------------------------|
| `scenes/comparison_room/comparison_room.tscn` | `retain` | Procedural neutral greybox with distinct floor, wall, door, foreground, actor, and interaction values | Fixed 1280 x 720 comparison frame | Equivalent doorway, foreground wall, six NPC bodies, dialogue target, combat target | Local reset points only; no manifest destination | Retain verified wall, doorway, body, Y-sort, fade, and combat probes | `docs/reports/comparison_room_p0_033.md`<br>`scenes/comparison_room/comparison_room.gd` | none - retained procedural reference |
| `scenes/comparison_room/diamond_isometric_8_direction.tscn` | `archive` | none - archive; retained screenshot records the legacy diamond greybox | none - archive; retained capture uses a fixed 1280 x 720 frame only | Preserve the matched comparison screenshot and report; build no gameplay set | No destination or spawn | No collision or navigation; retained report records the superseded probes | `docs/reports/comparison_room_p0_035.md`<br>`docs/reports/images/p0_035_diamond_isometric_8_direction.png` | none - archive |
| `scenes/comparison_room/orthogonal_4_direction.tscn` | `retain` | Procedural orthogonal greybox with P0-040 value hierarchy applied during review | Fixed 1280 x 720 comparison frame | Same doorway, occluder, NPC, dialogue, and combat anchors as baseline | Local reset points only; no manifest destination | Retain four-direction collision, navigation equivalence, Y-sort, and foreground fade probes | `docs/reports/comparison_room_p0_035.md`<br>`docs/reports/images/p0_035_orthogonal_4_direction.png` | none - retained procedural reference |
| `scenes/map/map.tscn` | `archive` | none - archive; satellite image is reference-only | none - archive; no world travel plane | Preserve map image and PDF as research; runtime UI copies the basemap under `assets/UI/` | No destination or spawn | No collision or navigation | `scenes/map/map.png`<br>`scenes/map/map.md`<br>`assets/UI/estonia_world_map.png` | none - archive |
| `scenes/world_travel/world_sacred_grove.tscn` | `convert` | Outdoor forest-floor / meadow / bog placeholder palette | Compact outdoor placeholder envelope | Grove ring trees, offering stone, return road | `from_reval_south` arrival; return to `reval_south` / `from_world_sacred_grove` | Footprint collision and nav from outdoor factory | `scripts/map/definitions/outdoor/distant_location_definitions.gd`<br>`scenes/world/sacred_grove.md` | `scripts/map/definitions/outdoor/distant_location_definitions.gd` |
| `scenes/world_travel/world_harju.tscn` | `convert` | Outdoor meadow / farm-soil placeholder palette | Compact outdoor placeholder envelope | Farmsteads, barn, well, return road | `from_reval_east` arrival; return to `viru_gate_foreland` / `from_world_harju` | Footprint collision and nav from outdoor factory | `scripts/map/definitions/outdoor/distant_location_definitions.gd`<br>`scenes/world/harju_village.md` | `scripts/map/definitions/outdoor/distant_location_definitions.gd` |
| `scenes/world_travel/world_padise.tscn` | `convert` | Outdoor meadow / castle-paving placeholder palette | Compact outdoor placeholder envelope | Monastery massing, gatehouse, return road | `from_reval_west` arrival; return to `reval_toompea` / `from_world_padise` | Footprint collision and nav from outdoor factory | `scripts/map/definitions/outdoor/distant_location_definitions.gd`<br>`scenes/world/padise/padise_monastery.md` | `scripts/map/definitions/outdoor/distant_location_definitions.gd` |
| `scenes/world_travel/world_saaremaa.tscn` | `convert` | Outdoor bog / coast placeholder palette | Compact outdoor placeholder envelope | Shore camps, signal fire, return ferry marker | `from_reval_harbor` arrival; return to `reval_harbor_north` / `from_world_saaremaa` | Footprint collision and nav from outdoor factory | `scripts/map/definitions/outdoor/distant_location_definitions.gd`<br>`scenes/events/saaremaa.md` | `scripts/map/definitions/outdoor/distant_location_definitions.gd` |
| `scenes/world_travel/world_rebel_kings.tscn` | `convert` | Outdoor meadow / camp-soil placeholder palette | Compact outdoor placeholder envelope | Rebel command tents, signal fire, return road | `from_world_harju` arrival; roads to `world_harju` / `world_kanavere` | Footprint collision and nav from outdoor factory | `scripts/map/definitions/outdoor/distant_location_definitions.gd`<br>`docs/reports/global_map_mockups.md` | `scripts/map/definitions/outdoor/distant_location_definitions.gd` |
| `scenes/world_travel/world_kanavere.tscn` | `convert` | Outdoor bog / battlefield placeholder palette | Compact outdoor placeholder envelope | Marsh markers, camp debris, return roads | `from_world_harju` arrival; roads to `world_harju` / `world_rebel_kings` / `world_paide` | Footprint collision and nav from outdoor factory | `scripts/map/definitions/outdoor/distant_location_definitions.gd`<br>`docs/reports/global_map_mockups.md` | `scripts/map/definitions/outdoor/distant_location_definitions.gd` |
| `scenes/world_travel/world_sojamae.tscn` | `convert` | Outdoor meadow / battlefield placeholder palette | Compact outdoor placeholder envelope | Battlefield markers, return roads | `from_world_harju` arrival; roads to `world_harju` / `world_paide` | Footprint collision and nav from outdoor factory | `scripts/map/definitions/outdoor/distant_location_definitions.gd`<br>`docs/reports/global_map_mockups.md` | `scripts/map/definitions/outdoor/distant_location_definitions.gd` |
| `scenes/world_travel/world_paide.tscn` | `convert` | Outdoor castle-paving / hill placeholder palette | Compact outdoor placeholder envelope | Castle massing, gatehouse, return roads | `from_world_kanavere` or `from_world_sojamae` arrival; roads to `world_kanavere` / `world_sojamae` / `world_parnu` | Footprint collision and nav from outdoor factory | `scripts/map/definitions/outdoor/distant_location_definitions.gd`<br>`docs/reports/global_map_mockups.md` | `scripts/map/definitions/outdoor/distant_location_definitions.gd` |
| `scenes/world_travel/world_parnu.tscn` | `convert` | Outdoor meadow / river-town placeholder palette | Compact outdoor placeholder envelope | Town markers, ferry dock, return roads | `from_world_paide` or `from_world_padise` arrival; roads to `world_padise` / `world_paide`; ferry to `world_saaremaa` | Footprint collision and nav from outdoor factory | `scripts/map/definitions/outdoor/distant_location_definitions.gd`<br>`docs/reports/global_map_mockups.md` | `scripts/map/definitions/outdoor/distant_location_definitions.gd` |
| `scenes/world_travel/world_poide.tscn` | `convert` | Outdoor castle-paving / coast placeholder palette | Compact outdoor placeholder envelope | Castle massing, return road | `from_world_saaremaa` arrival; road to `world_saaremaa` | Footprint collision and nav from outdoor factory | `scripts/map/definitions/outdoor/distant_location_definitions.gd`<br>`docs/reports/global_map_mockups.md` | `scripts/map/definitions/outdoor/distant_location_definitions.gd` |
| `scenes/map_prototype/smithy_courtyard.tscn` | `retain` | P0-042 prototype IDs: grass, sand, hay, dirt, cobblestone, water, stone | 50 x 28 cells; 1600 x 896 at current 32-pixel cell size | Smithy hall, coal store, street shop, courtyard walls, anvil, hay stack, cart, well, barrels | One local `player_spawn`; no transition-manifest entry | Building footprint collision, full-grid coverage, shared Y-sort; no production nav graph | `docs/MAP_AUTHORING.md`<br>`scripts/map/smithy_courtyard_definition.gd`<br>`scenes/revel-map.jpg`<br>`scenes/reval_walls_towers/wall-map.png` | `scripts/map/smithy_courtyard_definition.gd` |

### Approved Lower Town slice

| Scene | Status | Terrain palette | World bounds | Required buildings and props | Transitions and spawns | Collision and navigation | Source references | Target declarative definition |
|-------|--------|-----------------|--------------|------------------------------|------------------------|--------------------------|-------------------|-------------------------------|
| `scenes/reval_east/forge/forge.tscn` | `convert` | `forge_interior`: stone floor, packed dirt, ash, timber, iron, ember and water accents using P0-040 day and night values | 40 x 24 cells; one-screen interior envelope with camera clamp | Forge and chimney, anvil, quench bucket or trough, repair bench, ledger, bed alcove, chest, shelves, tool rack, ingots, furnace, food table, foreground wall and courtyard door | Required stable anchors and spawns: `door_courtyard`, `bed_alcove`, `anvil`; P2-020 retired the temporary `main` alias | Closed perimeter; footprint collision for furnace, bed, storage and heavy furniture; walkable work triangle; nav exclusion under foreground wall; fade volume at occluder. Retained `MAP_CHUNK_BOUNDARY_AMBIGUOUS` subjects are owned under P0-067b / [`docs/reports/map_chunk_boundary_review_p0_067b.md`](./reports/map_chunk_boundary_review_p0_067b.md) (ADR 0010 lex-smallest owner); do not treat object chunk streaming as production-ready until that gate is revisited | `scenes/reval_east/forge/forge.tscn`<br>`scenes/reval_east/forge/forge.md`<br>`scenes/reval_east/forge/Screenshot 2025-08-11 at 00.57.04.png`<br>`docs/SCENES/the-makers-mark.md`<br>`content/locations/loc.kalev_smithy.json` | `scripts/map/definitions/lower_town/kalev_smithy_definition.gd` |
| `scenes/reval_east/reval_east.tscn` | `convert` | `lower_town_street`: cobblestone, packed dirt, mud, drainage water, foundation stone, timber threshold, hay and sparse grass under P0-040 day and night palettes | 64 x 36 cells; bounded connected exterior replacing the legacy city-scale canvas | Smithy facade and courtyard, Foaming Mug brewery, municipal cistern or well, watch checkpoint, compact tenements and workshops, wall or Viru Gate silhouette; carts, barrels, crates, drainage, signs and evidence props | Required stable anchors and spawns: `street_start`, `forge`, `smithy_door`, `brewery_door`, `checkpoint_west`, `checkpoint_east`; P2-020 retired legacy district-edge spawn IDs from the active manifest | Continuous walkable route among smithy, brewery, cistern and checkpoint; building and wall footprints; water and midden exclusion; authored checkpoint chokepoint; NPC patrol nav; Y-sort and fade for tall facades. Retained `MAP_CHUNK_BOUNDARY_AMBIGUOUS` subjects are owned under P0-067b / [`docs/reports/map_chunk_boundary_review_p0_067b.md`](./reports/map_chunk_boundary_review_p0_067b.md) (ADR 0010 lex-smallest owner); do not treat object chunk streaming as production-ready until that gate is revisited | `scenes/reval_east/reval_east.tscn`<br>`scenes/revel-map.jpg`<br>`scenes/reval_walls_towers/wall-map.png`<br>`docs/SCENES/the-makers-mark.md`<br>`docs/SCENES/a-bitter-brew.md`<br>`content/locations/loc.lower_town_slice.json` | `scripts/map/definitions/lower_town/lower_town_slice_definition.gd` |

### Approval-gated Lower Town prototypes

These conversions can preserve layout research without expanding the playable portfolio. Their scene runners and catalog records must be `active=false`; tests must fail if any appears in active destinations.

| Scene | Status | Terrain palette | World bounds | Required buildings and props | Transitions and spawns | Collision and navigation | Source references | Target declarative definition |
|-------|--------|-----------------|--------------|------------------------------|------------------------|--------------------------|-------------------|-------------------------------|
| `scenes/reval_east/viru_gate_foreland/viru_gate_foreland.tscn` | `convert` | `pirita_prototype`: meadow, farm soil, hay, reed/mud banks, deep/shallow river water, timber bridge deck and woodland edge | 168 x 120 cells; Pirita River south-to-north with Reval-Iru/Harju road crossing | Timber bridge, west croft and east farmstead, fields/fallow, hay meadow, future-convent meadow without church, sheep, tethered/pack horses, carts, hay and dense off-limits woodland | Local inspection spawn and authored outbound `to_reval_east` / `to_world_harju`; developer traversal only with `release=false`; `active=false` until a separate approval artifact | Continuous road and bridge deck; building/fence footprints and woodland exclusion keep the inspection route bounded | `content/maps/viru_gate_foreland.rrmap`<br>`scenes/reval_east/viru_gate_foreland/viru_gate_foreland.tscn`<br>`docs/HISTORICAL_AUDIT.md`<br>`docs/reports/pirita_1343_research.md` | `scripts/map/definitions/outdoor/viru_gate_foreland_definition.gd` |
| `scenes/reval_archbishops_garden/reval_archbishops_garden.tscn` | `convert` | `archbishops_garden_prototype`: elevated orchard grass, cathedral stone and guarded terrace | 144 x 48 cells with `elevation=2.8`; western Toompea connector | Bishop's Garden plot, medieval well, orchard walk, canon lodging, cliff wall and round towers; no anachronistic post-1420 Bishop's House | Reciprocal developer transitions north to Toompea, east to Central District and south to Knights District; `active=false` until a separate approval artifact | Connected garden circuit; stepped outer walls, gate arches and circular towers | `history/AVE2018_12_Reppo_Toompea.pdf`<br>`docs/HISTORICAL_AUDIT.md` | `scripts/map/definitions/prototypes/archbishops_garden_definition.gd` |
| `scenes/reval_center/reval_center.tscn` | `convert` | `market_civic_prototype`: worn cobble, dressed stone, packed dirt, timber threshold and drainage water | 80 x 48 cells | Unified Town Hall market square, early Town Hall on the south edge, Holy Spirit chapel and almshouse on the north, guild and merchant frontages, stalls, carts, well and civic notice props | Reciprocal developer transitions: Vana Turg east to Lower Town `vana_turg_boundary`, Pikk north to the north quarter, Lühike Jalg west to Toompea, and King's Street south to the southern quarter; Karja Gate's wall exit stays on Lower Town and routes to `reval_south`, never back into the civic map | Open street-edge transitions, landmark footprints, connected market circulation nav and Y-sort; no quest patrol graph. Retained `MAP_CHUNK_BOUNDARY_AMBIGUOUS` subjects are owned under P0-067b / [`docs/reports/map_chunk_boundary_review_p0_067b.md`](./reports/map_chunk_boundary_review_p0_067b.md) (ADR 0010 lex-smallest owner); do not activate chunk-streaming playable use until that gate is revisited | `content/maps/market_civic_quarter.rrmap`<br>`scenes/reval_center/reval_center.tscn`<br>`scenes/revel-map.jpg`<br>`scenes/reval_center/market_civic_quarter/town_hall_square.md`<br>`scenes/reval_center/market_civic_quarter/town_hall.md`<br>`scenes/reval_center/market_civic_quarter/church_of_the_holy_spirit.md` | `scripts/map/definitions/prototypes/market_civic_quarter_definition.gd` |
| `scenes/reval_center/market_civic_quarter/olaf_guild_hall.tscn` | `convert` | `guild_interior_prototype`: dressed stone, timber floor, plaster, iron and hearth accents | 32 x 20 cells | Guild hall, dais, long tables, benches, chests, banner anchors, hearth and street door | Prototype inspection spawn only; door remains inert until approval | Closed interior shell, furniture footprints, central assembly nav and foreground fade | `scenes/reval_center/market_civic_quarter/olaf_guild_hall.tscn`<br>`scenes/reval_center/market_civic_quarter/st_olafs_guild_hall.md` | `scripts/map/definitions/prototypes/st_olafs_guild_hall_definition.gd` |
| `scenes/reval_monastery/reval_monastery.tscn` | `convert` | `monastery_quarter_prototype`: packed-earth base; cobble limited to Pikk/Lai/civic/vene spines; mud secondary lanes; convent garden/grass margins; small stone closes only; service/workshop yards | 208 x 112 cells; 30% wider lower half of the former northern ward, with fortified west/east edges | St. Michael's Cistercian precinct, St. Olaf's close, period-safe generic merchant frontages on `great_guild_front` / `blackheads_corner` / `brotherhood_wing` (P4-023e; later Great Guild / Blackheads monumental forms excluded), Pikk/Lai approaches and service rows | Reciprocal developer transitions north to Merchant District, south to civic and Workers' districts, and west to Toompea; new `reval_monastery` scene is developer-only | Open street-edge transitions and connected precinct/guild circulation. Retained chunk-boundary warnings inherit the P0-068/P0-067a ADR 0010 ownership note. Street/surface pass closed in **P4-023a**; exceptional landmark models by **P4-023c** / **P4-023d** | `content/maps/monastery_quarter.rrmap`<br>`scenes/reval_monastery/reval_monastery.tscn`<br>`scenes/revel-map.jpg`<br>`scenes/reval_north/st_olafs_church.md`<br>`docs/HISTORICAL_AUDIT.md`<br>`docs/MAP_AUTHORING.md` | `scripts/map/definitions/prototypes/monastery_quarter_definition.gd` |
| `scenes/reval_north/reval_north.tscn` | `convert` | `merchant_district_prototype`: cobble, dock mud, merchant stone and maritime work yards | 208 x 140 cells; 20% wider and 30% taller upper half, with fortified west/east/north edges and the turreted Great Coast Gate | Pikk and Lai merchant spines, coast gate, goldsmith and merchant courts, warehouses, shipwrights and ropemakers | Reciprocal developer transitions south to Monastery District and north to Trade Harbour; stable `north_quarter` map ID retained | Open north/south street transitions and connected merchant circulation. Retained chunk-boundary warnings inherit the P0-068/P0-067a ADR 0010 ownership note | `content/maps/north_quarter.rrmap`<br>`scenes/reval_north/reval_north.tscn`<br>`scenes/revel-map.jpg`<br>`scenes/reval_north/pikk_street.md` | `scripts/map/definitions/prototypes/north_quarter_definition.gd` |
| `scenes/reval_south/reval_south.tscn` | `convert` | `knights_district_prototype`: cobble, stone, dirt, inner grass and Karja glacis mud | 336 x 96 cells; compact western connector and dense eastern ward inside an irregular stepped wall | Rataskaev well, Dunkri and King's Street lanes, knights' hall and dormitory, stable, swordsmith, chapter house, houses and Karja approach | Reciprocal developer transitions north to civic and Workers' districts and west to Toompea; `active=false` | Irregular outer fortification with connected internal streets instead of a rectangular enclosure. Retained chunk-boundary warnings inherit the P0-068/P0-067a ADR 0010 ownership note | `content/maps/south_quarter.rrmap`<br>`scenes/reval_south/reval_south.tscn`<br>`scenes/reval_south/rataskaev_well.md`<br>`scenes/reval_south/knights_quarters.md` | `scripts/map/definitions/prototypes/south_quarter_definition.gd` |
| `scenes/reval_toompea/reval_toompea.tscn` | `convert` | `toompea_prototype`: elevated plateau grass, castle/cathedral stone and slope dirt | 144 x 192 cells with `elevation=2.8`; wider fortified hill | South-west castle compound, St Mary's cathedral close, bishop/canonical/noble plots, stables, Pikk Jalg and Lühike Jalg gates | Reciprocal developer transitions east to civic and Monastery districts and south to Knights District; stable IDs retained; `active=false` | Connected plateau routes; 3D terrain elevation tapers at transition edges without changing 2D nav/collision. Retained chunk-boundary warnings inherit the P0-068/P0-067a ADR 0010 ownership note | `content/maps/toompea_quarter.rrmap`<br>`scenes/reval_toompea/reval_toompea.tscn`<br>`scenes/revel-map.jpg`<br>`scenes/reval_toompea/domberg.md`<br>`scenes/reval_toompea/cathedral_of_saint_mary.md`<br>`history/AVE2018_12_Reppo_Toompea.pdf` | `scripts/map/definitions/prototypes/toompea_quarter_definition.gd` |

### Harbor and Toompea archive set

| Scene | Status | Terrain palette | World bounds | Required buildings and props | Transitions and spawns | Collision and navigation | Source references | Target declarative definition |
|-------|--------|-----------------|--------------|------------------------------|------------------------|--------------------------|-------------------|-------------------------------|
| `scenes/harbor/harbor.tscn` | `archive` | none - archive; legacy combined-harbour screenshot shell | none - archive | Preserve the combined harbour reference only | No destination or spawn | No collision or navigation | `scenes/harbor/harbor.tscn`<br>`scenes/harbor/harbor.md` | none - archive |
| `scenes/harbor/harbor_north.tscn` | `convert` | `trade_harbour`: Baltic basin, broad quays, warehouses and cargo yards | 160 x 88 cells | Great Coast Gate approach, warehouse rows, piers, cranes, cargo and quay plaza | Developer traversal south to Merchant District and east to Fishing Harbour | Water exclusion and connected quay circulation; P0-068/P0-067a warning ownership applies | `content/maps/reval_harbor_north.rrmap`<br>`scenes/harbor/harbor.md`<br>`scenes/harbor/great_coast_gate.md` | `scripts/map/definitions/outdoor/reval_harbor_north_definition.gd` |
| `scenes/harbor/harbor_east.tscn` | `convert` | `fishing_harbour`: shallow basin, fishers' sheds, net house and working piers | 144 x 80 cells | Fishing sheds, net house, fish tables, boats, nets and east quay | Developer traversal west to Workers' District and west to Trade Harbour through separate gates | Water exclusion and connected quay circulation; P0-068/P0-067a warning ownership applies | `content/maps/reval_harbor_east.rrmap`<br>`scenes/harbor/harbor.md` | `scripts/map/definitions/outdoor/reval_harbor_east_definition.gd` |
| `scenes/harbor/warehouse.tscn` | `archive` | none - archive; timber floor, stone threshold, and packed dirt notes only | none - archive | Preserve loading bay, crate stacks, cart, and quay-stair notes only | No destination or spawn | No collision or navigation | `scenes/harbor/warehouses.md`<br>`scenes/harbor/harbor.md`<br>`scripts/map/definitions/prototypes/harbor_warehouse_definition.gd` | none - archive |
| `scenes/reval_toompea/domberg.tscn` | `archive` | none - archive; castle stone and timber notes require new approval | none - archive | Preserve notes for castle walls, courtyard, barracks, hall, chapel and dungeon only | No destination or spawn | No collision or navigation | `scenes/reval_toompea/domberg.tscn`<br>`scenes/reval_toompea/domberg.md`<br>`scenes/revel-map.jpg` | none - archive |
| `scenes/reval_toompea/maria_toomkirik.tscn` | `archive` | none - archive; cathedral stone and interior value notes require new approval | none - archive | Preserve cathedral nave, altar, tomb and service-space notes only | No destination or spawn | No collision or navigation | `scenes/reval_toompea/maria_toomkirik.tscn`<br>`scenes/reval_toompea/cathedral_of_saint_mary.md` | none - archive |

### World locations, castles, monastery, and sacred grove archive set

| Scene | Status | Terrain palette | World bounds | Required buildings and props | Transitions and spawns | Collision and navigation | Source references | Target declarative definition |
|-------|--------|-----------------|--------------|------------------------------|------------------------|--------------------------|-------------------|-------------------------------|
| `scenes/world/haapsalu_castle.tscn` | `archive` | none - archive; coastal stone and siege-ground notes only | none - archive | Preserve bishop's castle, walls, gate, chapel and siege props as notes | No destination or spawn | No collision or navigation | `scenes/world/haapsalu_castle.tscn`<br>`scenes/world/haapsalu_castle.md` | none - archive |
| `scenes/world/harju_village.tscn` | `archive` | none - archive; grass, dirt, field and timber notes only | none - archive | Preserve farmsteads, fields, well, barn and village lane as notes | No destination or spawn | No collision or navigation | `scenes/world/harju_village.tscn`<br>`scenes/world/harju_village.md` | none - archive |
| `scenes/world/karja_fortress.tscn` | `archive` | none - archive; earthwork, timber and winter-ground notes only | none - archive | Preserve rebel palisade, ditch, gate, camp and siege props as notes | No destination or spawn | No collision or navigation | `scenes/world/karja_fortress.tscn`<br>`scenes/world/karja_fortress.md` | none - archive |
| `scenes/world/maasilinna_castle.tscn` | `archive` | none - archive; post-uprising stone and coast notes only | none - archive | Preserve castle-of-atonement concept notes only | No destination or spawn | No collision or navigation | `scenes/world/maasilinna_castle.tscn`<br>`scenes/world/maasilinna_castle.md` | none - archive |
| `scenes/world/padise/padise_monastery1.tscn` | `archive` | none - archive; monastery stone, field and timber notes only | none - archive | Preserve pre-attack monastery, church, cloister, gate and work-yard notes | No destination or spawn | No collision or navigation | `scenes/world/padise/padise_monastery1.tscn`<br>`scenes/world/padise/padise_monastery.md`<br>`scenes/world/padise/padise-map.png` | none - archive |
| `scenes/world/padise/padise_monastery2.tscn` | `archive` | none - archive; burned stone, ash and debris notes only | none - archive | Preserve post-attack state notes as a phase variant, not a second map | No destination or spawn | No collision or navigation | `scenes/world/padise/padise_monastery2.tscn`<br>`scenes/world/padise/padise_monastery.md`<br>`scenes/world/padise/padise-map.png` | none - archive |
| `scenes/world/paide_castle.tscn` | `archive` | none - archive; limestone castle and road notes only | none - archive | Preserve tower, gate, negotiation hall and execution-site notes | No destination or spawn | No collision or navigation | `scenes/world/paide_castle.tscn`<br>`scenes/world/paide_castle.md` | none - archive |
| `scenes/world/poide_castle.tscn` | `archive` | none - archive; island stone, mud and siege notes only | none - archive | Preserve fortress, gate, chapel and siege props as notes | No destination or spawn | No collision or navigation | `scenes/world/poide_castle.tscn`<br>`scenes/world/poide_castle.md` | none - archive |
| `scenes/world/sacred_grove.tscn` | `archive` | none - archive; moss, roots, leaf litter and water notes are not an approved supernatural palette | none - archive | Preserve ancient trees, offering stones and ambiguous ritual traces as research only | No destination or spawn | No collision or navigation; no ritual gameplay | `scenes/world/sacred_grove.tscn`<br>`scenes/world/sacred_grove.md`<br>`docs/CANON.md` | none - archive |
| `scenes/world/viljandi_castle.tscn` | `archive` | none - archive; castle stone, rye road and timber notes only | none - archive | Preserve castle, gate, storehouse and rye-sack infiltration notes | No destination or spawn | No collision or navigation | `scenes/world/viljandi_castle.tscn`<br>`scenes/world/viljandi_castle.md` | none - archive |

### Event scene archive set

| Scene | Status | Terrain palette | World bounds | Required buildings and props | Transitions and spawns | Collision and navigation | Source references | Target declarative definition |
|-------|--------|-----------------|--------------|------------------------------|------------------------|--------------------------|-------------------|-------------------------------|
| `scenes/events/paldiski.tscn` | `archive` | none - archive; coastal dirt, timber and water notes only | none - archive | Preserve outpost, tavern, pier, shipyard and smuggling props as notes | No destination or spawn | No collision or navigation | `scenes/events/paldiski.tscn`<br>`scenes/events/paldiski.md` | none - archive |
| `scenes/events/pernau.tscn` | `archive` | none - archive; town cobble, earthworks and fire notes only | none - archive | Preserve town wall, barricade, cellar and battlefield props as notes | No destination or spawn | No collision or navigation; no army battle simulation | `scenes/events/pernau.tscn`<br>`scenes/events/pernau.md` | none - archive |
| `scenes/events/pskov_arrival_battle.tscn` | `archive` | none - archive; field, mud and road notes only | none - archive | Preserve opposing camps, standards and battlefield landmarks as notes | No destination or spawn | No collision or navigation; no army battle simulation | `scenes/events/pskov_arrival_battle.tscn`<br>`scenes/events/pskov_arrival_battle.md` | none - archive |
| `scenes/events/rebel_kings.tscn` | `archive` | none - archive; trampled grass, mud and campfire notes only | none - archive | Preserve mobile camp, council fire, smith area, stores and sentry ring as notes | No destination or spawn | No collision or navigation; no army command space | `scenes/events/rebel_kings.tscn`<br>`scenes/events/rebel_kings.md` | none - archive |
| `scenes/events/saaremaa.tscn` | `archive` | none - archive; island overview is not a gameplay palette | none - archive | Preserve island, sacred lake, coast and settlement references as notes | No destination or spawn | No collision or navigation; no island travel layer | `scenes/events/saaremaa.tscn`<br>`scenes/events/saaremaa.md` | none - archive |
| `scenes/events/swedesh_outpost.tscn` | `archive` | none - archive; forest, timber stockade and snow notes only | none - archive | Preserve bailiff hall, stockade, forge and diplomatic set dressing as notes | No destination or spawn | No collision or navigation | `scenes/events/swedesh_outpost.tscn`<br>`scenes/events/swedesh_outpost.md` | none - archive |
| `scenes/events/swedish_arrival.tscn` | `archive` | none - archive; Baltic water, shore and ship notes only | none - archive | Preserve fleet silhouettes, shore defenses, signals and emissary ship as notes | No destination or spawn | No collision or navigation; no fleet simulation | `scenes/events/swedish_arrival.tscn`<br>`scenes/events/swedish_arrival.md` | none - archive |

## Declarative definition contract required by P0-043

P0-042 proves terrain zones, buildings, props, a player spawn, bounds validation, deterministic rendering, and footprint collision. Production definitions must extend that contract before any scene conversion:

1. `map_id`, canonical `location_id`, `scope` (`slice`, `prototype`, or `archive`) and `active` flag.
2. Cell bounds and P0-040-approved palette ID, with day and night variants where required.
3. Stable building and prop IDs, semantic kind, cell footprint or feet anchor, visual layer, collision policy and phase-state visibility.
4. Stable transition and spawn IDs with destination IDs. A prototype definition must reject active destinations.
5. Walkable zones, hard exclusions, patrol routes, interaction anchors, camera bounds, Y-sort anchors and foreground fade volumes.
6. Source-reference paths and a visual-parity anchor list so conversion decisions remain auditable.
7. A deterministic fingerprint used by tests and captures.

Definitions stay in typed GDScript factories under `scripts/map/definitions/`. This preserves the P0-042 approach and does not introduce a second JSON map framework. `content/locations/*.json` remains narrative content and points to scene IDs; it does not duplicate geometry.

## Execution order

1. **Approve P0-040.** Record the final projection, cell or world scale, viewport, zoom, palette, pivots, shadows, outlines and day/night rules.
2. **Land P0-043 contract and guard.** Extend `MapDefinition`, add scope and transition validation, and make this inventory verifier part of CI.
3. **Classify runtime activation.** P0-044 introduces a catalog or equivalent check that rejects archived or prototype maps from active destinations and Start flow.
4. **Archive empty and visual shells.** P0-045 and P0-046 preserve markdown and image sources while removing obsolete `.tscn` shells from runtime paths. P0-046 retires `harbor_warehouse` from the transition manifest, keeps `reval_harbor` as `release=false` dev traversal only, and excludes `scenes/map/` from Godot import via `.gdignore`. `game.tscn`, `scenes/intro/intro.tscn`, and `scenes/comparison_room/diamond_isometric_8_direction.tscn` remain as inactive evidence shells. This step does not wait for production art.
5. **Finish the modular environment kit.** P2-003 and P1-029 provide approved, linted terrain, building and prop modules.
6. **Convert the smithy.** P2-018 creates the interior definition and preserves every prologue interaction anchor.
7. **Convert the Lower Town exterior.** P2-019 creates one bounded slice definition containing the smithy route, brewery, cistern and checkpoint.
8. **Cut over transitions atomically.** P2-020 updates content locations and the manifest only after both maps validate and load. Legacy aliases are removed in the same task after traversal passes.
9. **Prove visual and gameplay parity.** P2-021 captures matched before and after views and executes topology, interaction, collision, navigation and scope checks.
10. **Optional prototypes after the slice gate.** P4-014 and P4-015 may convert center, market, guild hall and north as inactive prototypes. Activation is a separate, intentionally absent task that requires a new approval artifact.

P2-012 depends on P2-021, so the vertical slice cannot close on legacy map geometry or before the parity gate passes.

## Visual parity criteria

Conversion is semantic, not pixel-identical. Legacy isometric scale and unapproved art must not be reproduced merely to match pixels.

### Required evidence per converted production scene

- One reference capture and one converted capture at matched player-facing framing and P0-040 gameplay scale.
- An annotated anchor checklist. Every required building, prop, interaction, door, spawn, evidence point and occluder in the scene specification must be present or explicitly rejected with rationale.
- A topology trace showing the same required route endpoints are reachable. The Lower Town trace must cover `street_start -> smithy_door -> brewery_door -> checkpoint_west -> checkpoint_east`; the smithy trace must cover `door_courtyard -> anvil -> ledger -> bed_alcove`.
- Collision overlays showing no walk through structural footprints, no blocked required doorway, no spawn overlap and no unreachable interaction anchor.
- Navigation evidence for player routes and every declared NPC patrol. Dynamic actors must not enter water, walls, furniture footprints or foreground-only visual space.
- Y-sort and foreground-fade captures with the player both north and south of the relevant facade or prop.
- Day and night captures at identical framing. Value hierarchy, interactable readability and walkable-ground separation must pass without relying on hue alone.
- Deterministic definition fingerprint, full bounds coverage, unique stable IDs and successful headless scene load.
- Transition traversal from a clean Start flow, plus confirmation that every prototype and archive scene remains unreachable.

### Acceptance thresholds

- 100 percent of declared anchors accounted for.
- 100 percent of required route pairs reachable and 100 percent of hard exclusions blocked.
- Zero missing resources, parser errors, invalid stable references or spawn overlaps.
- Zero archive or prototype scene IDs in active destinations or release traversal.
- No unexplained world-bounds increase beyond the bounds in this plan. Any change requires updating this document and the owning TODO task before implementation.
- Human visual review confirms composition, depth order, silhouette separation, interaction readability and day/night value hierarchy at gameplay scale.

## Automatic completeness verification

Run:

```bash
python3 tools/verify_map_conversion_plan.py
python3 -m unittest tests.python.test_verify_map_conversion_plan -v
```

The verifier compares the disposition index to all repository `.tscn` files, compares both against `docs/reports/scene_inventory.md`, requires one detailed specification for every `level`, `map`, and `event` row, validates statuses and target rules, resolves every source-reference path, and confirms that all map-conversion TODO tasks declare exact allowed files and objective verification.

At this baseline the expected repository scene count is **61**. P0-018 recorded 41 before P0-042 added `scenes/map_prototype/smithy_courtyard.tscn`; ADR 0006 adds `scenes/harbor/warehouse.tscn`. P0-055 adds character rigs, interaction components, inventory and world-item scenes, smithy ambient actors, and CI benchmark hosts.

## Review checklist

- [ ] P0-040 is approved before implementation starts.
- [ ] Every tracked `.tscn` appears exactly once in the disposition index.
- [ ] Every `level`, `map`, and `event` scene appears exactly once in the detailed specifications.
- [ ] Convert targets are declarative definition paths; archive targets are `none - archive`.
- [ ] Active production work is limited to the smithy and one connected Lower Town slice.
- [ ] Prototype tasks cannot modify the active transition manifest or Start flow.
- [ ] Archive source markdown and images remain available and are not treated as approved runtime art.
- [ ] Visual parity checks topology, interactions, collision, navigation, depth and palette rather than pixel copying.
- [ ] Automated verification and its seeded-failure tests pass.


## Inactive outdoor prototype evidence (ADR 0005)

The archive disposition of the legacy harbor, world, castle, grove, and event `.tscn` shells is unchanged. ADR 0005 permits separate declarative definitions solely as `scope=prototype`, `active=false` verification artifacts. They are not conversion commitments and are absent from Start, active destinations, and release traversal.

| Package | Definitions | Evidence |
|---|---|---|
| Coast/harbor | Paldiski coastal outpost | `scripts/map/definitions/outdoor/coast_harbor_definitions.gd` |
| Villages/monasteries | Harju village, Padise monastery with before/after phase metadata | `scripts/map/definitions/outdoor/village_monastery_definitions.gd` |
| Castles | Haapsalu, Paide, Viljandi, Poide, Maasilinna, Karja | `scripts/map/definitions/outdoor/castle_definitions.gd` |
| Wilderness/events | Sacred grove, Pärnu, Pskov arrival, rebel kings camp, Saaremaa, Swedish outpost, Swedish arrival | `scripts/map/definitions/outdoor/wilderness_event_definitions.gd` |

All 17 definitions use one `OutdoorMapFactory`, full base terrain coverage with ordered zones, shared structure/prop primitives, footprint-derived collision, a stable developer inspection spawn, a deterministic inspection route, at least three landmarks, and a SHA-256 definition fingerprint. Snow is intentionally absent because no approved canonical phase requires it. Existing images are layout references only; captures are procedural renders.
es are procedural renders.
