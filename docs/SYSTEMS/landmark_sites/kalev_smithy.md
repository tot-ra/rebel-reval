[Landmark sites index](../CITY_LANDMARK_SITES.md) · [All systems](../README.md)

# Kalev's smithy (task R-1643)

Status: implemented (task **R-1643**, maintainer request 2026-10-10), interim shell with reused GLB furnishings. Stable ID: `site.kalev_smithy`. [Manifest](../../../content/world/reval_city/sites/kalev_smithy.json) · [Model builder](../../../scripts/city/sites/kalev_smithy_builder.gd). Scope: the smithy as one building of the seamless city, modelled from scratch as a landmark site, and the new-game start inside it. Out of scope: the forge gameplay (Mart, the anvil pickup, commissions, saves), the loft as a walkable floor, Blender GLB of the shell.

| Street exterior | Interior cutaway |
|---|---|
| ![Kalev's smithy street front, shop window and shingle roof](../../reports/images/city/kalev_smithy_street.jpg) | ![Cutaway of Kalev's forge bay and living bay](../../reports/images/city/kalev_smithy_cutaway.jpg) |

**Function in 1343:** a master smith's workshop and home, the game's hub. No Reval smithy plan of 1343 survives, so it is a plausible composite: a stone-footed street-front craft house, hot work in limestone (Hanseatic fire practice), forge bay about 55% of the floor behind the street door, living bay behind a stone partition, smoke out through a rubble stack in the gable.

**Plan:**

- **Outside (14 × 9.4 m):** limestone rubble walls 0.62 m thick under a 48° shingle roof, plain gables, the chimney stack in the east gable with a lit plume, plank shutters folded back, the street window as a shop front (fold-down counter on brackets with horseshoes, nails and a knife; awning leaf on props), a loft door in the west gable, and an open lean-to on oak posts with the charcoal crib, cordwood, a crank grindstone (Luttrell Psalter, c. 1330) and bar iron. The yard behind the yard door is the site's `reserve`.
- **Forge bay (`room.forge`):** beaten-earth floor, sooted rubble walls, tie beams under open rafters. The old forge's GLB kit in its old relative layout, turned so the hearth backs onto the east gable: raised hearth under the clay hood with live embers, flames, sparks and the flickering forge light (`MapViewSmithyPropBuilder.add_smithy_furnace`), great bellows on the smith's left, anvil about 2.4 m down-fire, slack tub beside it, stock rack, scrap crate, finishing bench, charcoal bin.
- **Living bay (`room.living`):** lime-washed walls, board floor, the boarded loft on joists with a ladder, bed, chest, table with a candle and jug, chair, bench, shelf.

**Decoration and art reuse:** the walls use the old smithy's photoreal plates (`MapViewKalevSmithyInterior.material_for`: limestone rubble, lime wash, beaten earth, boards), re-scaled from the old 0.87 m district unit to metres and tinted warm; kit GLBs are mounted at 0.87 scale; their contact-shadow cards (`ksi_loft_shadow`) are drawn clear.

**Left out:** trip-hammers, water power, brick chimney pots, glazing, a screw vice (per the dossier).

**Start:** the almshouse prologue and every `forge` redirect arrive at spawn `kalev_smithy` (manifest `spawns`, site-local (10.5, 5.6), facing 52°): in the forge bay by the hearth, the 6 m third-person camera inside the room by the street door. The HUD reads "Inside: Kalev's smithy (forge)"; the `forge` music zone (`zone.smithy`) is centred on the site.

**Historical research:** [Smithy workshop layout](../../../history/dossiers/architecture/smithy-workshop-layout.md); [Blacksmith materials and techniques](../../../history/dossiers/crafts/blacksmith-materials-and-techniques.md); [Schmiede-Amt ordinances before 1363](../../../history/dossiers/crafts/schmiede-amt-ordinances-pre-1363.md); [Earlier smithy interior redesign](../../reports/kalev_smithy_interior_redesign.md) (source of the reused kit, not proof of gameplay integration).

**Review plates:** `docs/reports/images/city/kalev_smithy_street.jpg`, `kalev_smithy_street_east.jpg`, `kalev_smithy_aerial.jpg`, `kalev_smithy_cutaway.jpg`, [forge bay](../../reports/images/city/kalev_smithy_forge_bay.jpg), [living bay](../../reports/images/city/kalev_smithy_living.jpg), [new-game arrival](../../reports/images/city/kalev_smithy_new_game_start.jpg).

**Verify:** `godot --headless --path . --script tools/validate_city_sites.gd`; `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_city_sites` (`test_kalev_smithy_*`); `tools/godot_render.sh --script tools/capture_reval_city.gd -- --only=kalev_smithy_street,kalev_smithy_street_east,kalev_smithy_aerial,kalev_smithy_cutaway,kalev_smithy_forge_bay,kalev_smithy_living`.

**Limits:** the census bathkeeper household `hh.lt.osm_r7239857` still lives on the replaced plot (needs rehoming); the forge's gameplay controllers are not mounted here (see [Seamless city limits](../SEAMLESS_CITY.md#limits)); the loft is not walkable. R-1643 is the implementation reference retained from this document; the 2026-10-11 board lookup did not return that row.

## More views

Model captures, not photos of modern Tallinn or concept art. Ongoing fixes may postdate them. Walk-test frames are first-person or top-down shots taken by the automated site walk (2026-10-13).

| Street exterior | Street exterior from the east |
|---|---|
| ![Street exterior](../../reports/images/city/kalev_smithy_street.jpg) | ![Street exterior from the east](../../reports/images/city/kalev_smithy_street_east.jpg) |

| Aerial view | Interior cutaway |
|---|---|
| ![Aerial view](../../reports/images/city/kalev_smithy_aerial.jpg) | ![Interior cutaway](../../reports/images/city/kalev_smithy_cutaway.jpg) |

| Forge bay | Living bay |
|---|---|
| ![Forge bay](../../reports/images/city/kalev_smithy_forge_bay.jpg) | ![Living bay](../../reports/images/city/kalev_smithy_living.jpg) |

| New-game arrival by the hearth | Interior overview, day |
|---|---|
| ![New-game arrival by the hearth](../../reports/images/city/kalev_smithy_new_game_start.jpg) | ![Interior overview, day](../../reports/images/kalev_smithy_interior/overview_day.jpg) |

| Interior overview, night | Forge bay, day |
|---|---|
| ![Interior overview, night](../../reports/images/kalev_smithy_interior/overview_night.jpg) | ![Forge bay, day](../../reports/images/kalev_smithy_interior/forge_bay_day.jpg) |

| Forge bay, night | Hearth close-up, day |
|---|---|
| ![Forge bay, night](../../reports/images/kalev_smithy_interior/forge_bay_night.jpg) | ![Hearth close-up, day](../../reports/images/kalev_smithy_interior/hearth_close_day.jpg) |

| Hearth close-up, night | Anvil close-up, day |
|---|---|
| ![Hearth close-up, night](../../reports/images/kalev_smithy_interior/hearth_close_night.jpg) | ![Anvil close-up, day](../../reports/images/kalev_smithy_interior/anvil_close_day.jpg) |

| Bellows close-up, day | Tool wall, day |
|---|---|
| ![Bellows close-up, day](../../reports/images/kalev_smithy_interior/bellows_close_day.jpg) | ![Tool wall, day](../../reports/images/kalev_smithy_interior/tool_wall_day.jpg) |

| From the forge towards the street door, day | Living bay, day |
|---|---|
| ![From the forge towards the street door, day](../../reports/images/kalev_smithy_interior/forge_to_door_day.jpg) | ![Living bay, day](../../reports/images/kalev_smithy_interior/living_day.jpg) |

| Living bay looking to the forge, night | Top-down, forge bay, day |
|---|---|
| ![Living bay looking to the forge, night](../../reports/images/kalev_smithy_interior/living_to_forge_night.jpg) | ![Top-down, forge bay, day](../../reports/images/kalev_smithy_interior/topdown_forge_day.jpg) |

| Top-down, living bay, day | Third-person camera, day |
|---|---|
| ![Top-down, living bay, day](../../reports/images/kalev_smithy_interior/topdown_living_day.jpg) | ![Third-person camera, day](../../reports/images/kalev_smithy_interior/third_person_day.jpg) |

| Third-person camera, night | Roof frame and loft boards, day |
|---|---|
| ![Third-person camera, night](../../reports/images/kalev_smithy_interior/third_person_night.jpg) | ![Roof frame and loft boards, day](../../reports/images/kalev_smithy_interior/ceiling_day.jpg) |

| Walk test: just inside the door | Walk test: top-down camera inside |
|---|---|
| ![Walk test: just inside the door](../../reports/images/city/sites/walk_kalev_smithy_inside.jpg) | ![Walk test: top-down camera inside](../../reports/images/city/sites/walk_kalev_smithy_inside_top_down.jpg) |

| Walk test: view of the forge bay | Walk test: view of the living bay |
|---|---|
| ![Walk test: view of the forge bay](../../reports/images/city/sites/walk_kalev_smithy_view_forge.jpg) | ![Walk test: view of the living bay](../../reports/images/city/sites/walk_kalev_smithy_view_living.jpg) |
