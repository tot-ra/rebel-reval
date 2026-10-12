[Landmark sites index](../CITY_LANDMARK_SITES.md) · [All systems](../README.md)

# St Nicholas' church (Niguliste)

**Status:** implemented, interim builder. Stable ID: `site.st_nicholas`. [Manifest](../../../content/world/reval_city/sites/st_nicholas.json) · [Model builder](../../../scripts/city/sites/st_nicholas_builder.gd). Strict 1343, compared with photos of today's church.

| Church and cemetery | South side and St Barbara chapel |
|---|---|
| ![St Nicholas church, low tower and cemetery from above](../../reports/images/historical_walk/hw6_nic_aerial.jpg) | ![St Nicholas south elevation with St Barbara charnel chapel](../../reports/images/historical_walk/hw6_nic_south_chapel.jpg) |

**Function in 1343:** the wealthiest parish, founded by Westphalian merchants from Gotland; patron of merchants and seafarers; family and guild altars; built with barred doors and loopholes as a refuge before the town wall enclosed it (attested).

**Plan:**

- **Nave and two aisles** (hall church, 1230s to c. 1290, attested) with a square chancel and a sacristy.
- **Low west tower** with defensive loopholes; the nave west wall (`nave.west.mid`) runs across the tower front with the tower arch, which has its own floor (`floor.tower_arch`).
- **North porch** (first half of the 14th c., attested); a beggar's place.
- **Walkable nave:** benches (1.6 m) leave a 1.6 m middle aisle and stop 0.4 m short of the pier faces, so a row is entered from the aisle or the side aisle and never through a slot that only just fits Kalev's footprint (0.875 × 0.625 m); `test_st_nicholas_nave_is_walkable_and_west_wall_closed` checks every gap.
- **St Barbara chapel** (first recorded 1342): a charnel house at the cemetery edge with bones and skulls on low benches and an altar of St Barbara.
- **Cemetery:** wooden grave crosses, slabs and mounds, levelled with the church.

**Decoration:** bare grey limestone piers and grey vault ribs against whitewashed walls and webs, as inside today; a stone-flag floor with many tomb slabs; single lancets with stained glass; candle crowns; a pulpit; a winged retable; side altars of merchant families and guilds. Outside: grey limestone rubble with stepped buttresses; a whitewashed tower with pointed blind arcading under a steep shingled helm.

**Left out (later):** the basilica nave and ambulatory choir (1405–20 and later); the high tower and baroque spire; the later side chapels (1470s+); Rode's altar (1478–81); the organ and brass chandeliers.

**Historical research:**

- Project: [Churches and religious houses](../../../history/dossiers/religion/churches-and-religious-houses.md) (St Nicholas section); [Niguliste placement contract](../../tasks/urban_form/UF-10_niguliste_exterior.md) (legacy district target).
- External: Medieval Heritage, ["Tallinn - St Nicholas' Church"](https://medievalheritage.eu/en/main-page/heritage/estonia/tallinn-st-nicholas-church-niguliste-kirik/) (build phases, 1342 St Barbara chapel); Niguliste Museum, ["St. Nicholas' Church"](https://nigulistemuuseum.ekm.ee/en/introduction/st-nicholas-church/).

**Related work:** R-1651 (`in_progress`, churchyard enclosure and paths), R-1654 (`idea`, north porch). R-1134 / LM-08 (`todo`) is legacy-targeted model work. Capture context: walk 6 (2026-10-11); the plates precede the ongoing churchyard pass.

## More views

Model captures, not photos of modern Tallinn or concept art. Ongoing fixes may postdate them. Walk-test frames are first-person or top-down shots taken by the automated site walk (2026-10-13).

| Church and cemetery from above (historical walk 6) | South side and St Barbara chapel |
|---|---|
| ![Church and cemetery from above (historical walk 6)](../../reports/images/historical_walk/hw6_nic_aerial.jpg) | ![South side and St Barbara chapel](../../reports/images/historical_walk/hw6_nic_south_chapel.jpg) |

| East end | West tower front |
|---|---|
| ![East end](../../reports/images/historical_walk/hw6_nic_east.jpg) | ![West tower front](../../reports/images/historical_walk/hw6_nic_west.jpg) |

| North porch | North, runtime camera |
|---|---|
| ![North porch](../../reports/images/historical_walk/hw6_nic_north_porch.jpg) | ![North, runtime camera](../../reports/images/historical_walk/hw6_rt_nic_north.jpg) |

| South, runtime camera | East, runtime camera |
|---|---|
| ![South, runtime camera](../../reports/images/historical_walk/hw6_rt_nic_south.jpg) | ![East, runtime camera](../../reports/images/historical_walk/hw6_rt_nic_east.jpg) |

| West, runtime camera | Stained glass along the axis |
|---|---|
| ![West, runtime camera](../../reports/images/historical_walk/hw6_rt_nic_west.jpg) | ![Stained glass along the axis](../../reports/images/church_interiors/glazing_st_nicholas_axis.png) |

| Stained glass, side view A | Stained glass, side view B |
|---|---|
| ![Stained glass, side view A](../../reports/images/church_interiors/glazing_st_nicholas_side_a.png) | ![Stained glass, side view B](../../reports/images/church_interiors/glazing_st_nicholas_side_b.png) |

| Walls before the mural pass | Walls after the mural pass |
|---|---|
| ![Walls before the mural pass](../../reports/images/church_interiors/murals_st_nicholas_before.jpg) | ![Walls after the mural pass](../../reports/images/church_interiors/murals_st_nicholas_after.jpg) |

| Aerial view | Aisle (model, photo viewpoint) |
|---|---|
| ![Aerial view](../../reports/images/city/sites/st_nicholas_aerial.jpg) | ![Aisle (model, photo viewpoint)](../../reports/images/city/sites/st_nicholas_photo_aisle.jpg) |

| Nave (model, photo viewpoint) | North side (model, from the viewpoint of a photo of the real building) |
|---|---|
| ![Nave (model, photo viewpoint)](../../reports/images/city/sites/st_nicholas_photo_nave.jpg) | ![North side (model, from the viewpoint of a photo of the real building)](../../reports/images/city/sites/st_nicholas_photo_north.jpg) |

| South side (model, photo viewpoint) | Walk test: just inside the door |
|---|---|
| ![South side (model, photo viewpoint)](../../reports/images/city/sites/st_nicholas_photo_south.jpg) | ![Walk test: just inside the door](../../reports/images/city/sites/walk_st_nicholas_inside.jpg) |

| Walk test: top-down camera inside | Walk test: first-person view of the nave |
|---|---|
| ![Walk test: top-down camera inside](../../reports/images/city/sites/walk_st_nicholas_inside_top_down.jpg) | ![Walk test: first-person view of the nave](../../reports/images/city/sites/walk_st_nicholas_view_nave.jpg) |

| Door plate (closed) | Door plate (open) |
|---|---|
| ![Door plate (closed)](../../reports/images/city/doors/st_nicholas.png) | ![Door plate (open)](../../reports/images/city/doors/st_nicholas_open.png) |

| Door plate (inside) | Door plate (south) |
|---|---|
| ![Door plate (inside)](../../reports/images/city/doors/st_nicholas_inside.png) | ![Door plate (south)](../../reports/images/city/doors/st_nicholas_south.png) |

| Door plate (south open) | Door plate (west) |
|---|---|
| ![Door plate (south open)](../../reports/images/city/doors/st_nicholas_south_open.png) | ![Door plate (west)](../../reports/images/city/doors/st_nicholas_west.png) |

| Door plate (west open) |  |
|---|---|
| ![Door plate (west open)](../../reports/images/city/doors/st_nicholas_west_open.png) |   |
