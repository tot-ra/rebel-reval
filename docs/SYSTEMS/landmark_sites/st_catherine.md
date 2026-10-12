[Landmark sites index](../CITY_LANDMARK_SITES.md) · [All systems](../README.md)

# St Catherine's Dominican friary (task R-1718)

Status: implemented (task **R-1718**, with **R-1727** and **R-1124 / LM-02** folded in; maintainer decision 2026-10-13). Stable ID: `site.st_catherine`, landmark `landmark.st_catherine`. [Manifest](../../../content/world/reval_city/sites/st_catherine.json) · [Model builder](../../../scripts/city/sites/st_catherine_builder.gd). Scope: the friary as a walled close of the seamless city with an enterable church and a walkable cloister, west forecourt and service yard. Out of scope: range interiors, the sanctuary mechanic at the gate, friars and lay brothers as people, 15th-century enlargements.

| Aerial from the south-west | Cloister garth |
|---|---|
| ![St Catherine's friary from above: church, cloister, ranges and yard](../../reports/images/city/st_catherine_aerial.jpg) | ![The garth with the well, the cloister walks and the church's north wall](../../reports/images/city/st_catherine_garth.jpg) |

**Function in 1343:** a friary of the Order of Preachers (re-founded 1246 by Prior Daniel of Visby with eleven friars): preaching to townsfolk, confession, a school, a brewery and fish trade through the port. Not a parish. The precinct is a church-law seam where the town Vogt treads carefully (sanctuary, composite).

**Plan as built** (site-local metres, +x east along Katariina käik, +z south; anchor (159.5, -44.3), rotation 5°; Kühnert's plan reduced to the c. 1300 phase, `plausible composite` unless marked):

- **Close (`close.polygon`):** 72-77 × 52 m between Katariina käik (south and west), the Munga houses (north) and Müürivahe (east), with a notch at the north-west for the Vene corner house. The dossier's 58 × 95 m target does not fit the plan's streets. Limestone rubble wall 3.6 m with an ashlar coping; an open **west gate** (gate W1 of the dossier, off the lane to Vene) and an open **yard gate** onto Katariina käik. The plan compiler drops the 13 strip houses inside or overlapping the close through `replaces`; trees and shrubs stay out of `close.polygon`.
- **Church** (`attested` stone church c. 1300; plan composite): a 50 × 17 m single-span preaching hall, 11 m walls, one tile roof at 45° with an open tie-beam roof inside, no tower (a small louvred timber bell turret on the ridge, as mendicant statutes allowed). Buttresses on the lane and the east end, tall lancets with stained glass, a three-light east window, a two-light west window over the **profiled west portal** (`door.st_catherine.west`, three orders, [City doors](../CITY_DOORS.md#landmark-portals-r-1693)). Inside: nave for the laity with flags and ledger slabs, a pulpit on the south wall, two side altars before a **stone rood screen** with the rood above, the **friars' choir** three steps up with stalls and desks along both walls and the high altar. Doors: west portal, south door onto the lane (laity, the terrace level door), cloister door from the south walk.
- **Cloister:** a garth (31 × 18.5 m) with the friary **well** at `poi.well.dominican` and three plank-edged herb beds, ringed by a limestone arcade on a dwarf wall (entry arches mid-side and opposite the cloister door) under lean-to tile roofs.
- **Ranges** (closed massing, shuttered windows and shut doors): **west range** on the gate side (lay brothers, kitchen stores, granary at the church corner), **north range** (refectory and kitchen, with the smoking kitchen stack), **east range** (sacristy by the choir, chapter house entrance on the cloister, dormitory windows upstairs; `attested` as the first range, finished c. 1300).
- **Service yard** (`reserve`, packed earth and paving): shingled brewhouse, keg stack, malt sacks, cooper's staves, firewood, a cart, herring casks, grain, a fish-splitting table, a tub and baskets. All existing props (`CitySiteProps`, `MapViewMeshBuilderDistrictLifeProps`, `obj.basket_wicker`); no new models.

**Rooms and HUD:** `room.nave` "St Catherine's (nave)", `room.choir` "St Catherine's (friars' choir)" (both lift `Church/Upper` and `Church/Roof`), and the four cloister walks `room.cloister_{south,north,west,east}` "St Catherine's (cloister walk)" (lift `Cloister/Roof`). Anchors: `anchor.st_catherine.high_altar`, `.west_gate`, `.garth_well`, `.yard`.

**Left out (later):** the eight-bay hall (67.7 m) and its vaults, the crypt as a council cannon store, the new refectory in the north wing (c. 1500), the rebuilt two-storey cloister, Black Heads patronage (15th-16th c.), the 1520s works, the Behind-the-Monks tower, the carved vine and oak-leaf capital friezes of the west portal.

**Historical research:**

- Project: [Churches and religious houses](../../../history/dossiers/religion/churches-and-religious-houses.md); [Ecclesiastical precinct boundaries](../../../history/dossiers/religion/ecclesiastical-precinct-boundaries-1343.md) (Dominican polygon); [Dominican brewery and fish yard](../../../history/dossiers/religion/dominican-brewery-fish-yard-1343.md); [Back lanes east of Pikk](../../../history/dossiers/topography/back-lanes-east-of-pikk.md).
- External: Medieval Heritage, ["Tallinn - Dominican Friary"](https://medievalheritage.eu/en/main-page/heritage/estonia/tallinn-monastery-of-st-catherine-puha-katariina-klooster/) (Kühnert plans, sections and room functions); E. Kühnert, *Das Dominikanerkloster zu Reval*, Reval 1926; MNLL, ["De ordine predicatorum de Tolosa in Dacia"](https://medieval.wiki.uib.no/De_ordine_predicatorum_de_Tolosa_in_Dacia) (1229 and 1246 foundations); Mauritanum, [St Catherine's Convent](https://1246.eu) (surviving east-wing rooms).

**Review plates:** `docs/reports/images/city/st_catherine_aerial.jpg`, [garth](../../reports/images/city/st_catherine_garth.jpg), [west gate from the lane](../../reports/images/city/st_catherine_street_gate.jpg), [Katariina käik along the south wall](../../reports/images/city/st_catherine_street_south.jpg), [west portal](../../reports/images/city/st_catherine_west_portal.jpg), [nave](../../reports/images/city/st_catherine_nave.jpg), [service yard](../../reports/images/city/st_catherine_yard.jpg).

**Verify:** `godot --headless --path . --script tools/validate_city_sites.gd`; `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_st_catherine_site`; `tools/godot_render.sh --script tools/capture_reval_city.gd -- --only=st_catherine_aerial,st_catherine_garth,st_catherine_street_gate,st_catherine_street_south,st_catherine_west_portal,st_catherine_nave,st_catherine_yard`; `tools/godot_render.sh --resolution 1600x900 res://tools/capture_reval_city_walk.tscn -- --only-sites` (all three doors walked in, roofs lift, leaves open).

**Limits:** the ranges have no interiors and no people; the gate is not yet a sanctuary seam in gameplay; census households of the 13 removed houses (`hh.lt.osm_<id>` on `katariina_kaik` / `muurivahe` ledger pages) are not rehomed yet; `bldg.osm.w221512373` was a merged OSM polygon across the lane, so the plot south of Katariina käik east of the church is empty; if the water-supply work (WS-4) starts drawing a well at every `poi.well.*`, it must skip `poi.well.dominican`, which this site already models.

## More views

Model captures, not photos of modern Tallinn or concept art. Ongoing fixes may postdate them. Walk-test frames are first-person or top-down shots taken by the automated site walk (2026-10-13).

| Aerial view from the south-west | Cloister garth |
|---|---|
| ![Aerial view from the south-west](../../reports/images/city/st_catherine_aerial.jpg) | ![Cloister garth](../../reports/images/city/st_catherine_garth.jpg) |

| West gate from the lane | Katariina käik along the south wall |
|---|---|
| ![West gate from the lane](../../reports/images/city/st_catherine_street_gate.jpg) | ![Katariina käik along the south wall](../../reports/images/city/st_catherine_street_south.jpg) |

| West portal | Nave |
|---|---|
| ![West portal](../../reports/images/city/st_catherine_west_portal.jpg) | ![Nave](../../reports/images/city/st_catherine_nave.jpg) |

| Service yard | Walk test: just inside the door |
|---|---|
| ![Service yard](../../reports/images/city/st_catherine_yard.jpg) | ![Walk test: just inside the door](../../reports/images/city/sites/walk_st_catherine_inside.jpg) |

| Walk test: top-down camera inside | Walk test: view of the garth |
|---|---|
| ![Walk test: top-down camera inside](../../reports/images/city/sites/walk_st_catherine_inside_top_down.jpg) | ![Walk test: view of the garth](../../reports/images/city/sites/walk_st_catherine_view_garth.jpg) |

| Walk test: first-person view of the nave |  |
|---|---|
| ![Walk test: first-person view of the nave](../../reports/images/city/sites/walk_st_catherine_view_nave.jpg) |   |
