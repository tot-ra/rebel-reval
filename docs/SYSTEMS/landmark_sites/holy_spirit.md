[Landmark sites index](../CITY_LANDMARK_SITES.md) · [All systems](../README.md)

# Holy Spirit church and almshouse (Pühavaimu)

**Status:** implemented, interim builder. Stable ID: `site.holy_spirit`. [Manifest](../../../content/world/reval_city/sites/holy_spirit.json) · [Model builder](../../../scripts/city/sites/holy_spirit_builder.gd). Built on the footprint of the surviving church (OSM) and compared view by view with photos of the real building (Wikimedia Commons; the manifest's `review_shots` reproduce their viewpoints).

| Church exterior and precinct | Almshouse range |
|---|---|
| ![Holy Spirit church and its precinct from above](../../reports/images/historical_walk/hw5_holy_aerial.jpg) | ![Holy Spirit almshouse range in the seamless city](../../reports/images/historical_walk/hw5_holy_almshouse.jpg) |

**Function in 1343:** parish church by the market (priest attested 1316, church 1319) and the chapel of the Holy Spirit almshouse (*hospice*) for the sick and poor; the council's church by later tradition (council mass before sittings is **not** attested for 1343, so it is not shown as routine).

**Plan:**

- **Two-aisle hall** with a flat timber ceiling (attested); square piers carrying pointed arches between the aisles.
- **Choir:** narrower and lower, rectangular, on the north aisle's axis, three steps up; the high altar.
- **Nave:** plain oak benches with rounded end boards and a cross aisle at the courtyard door, set out so Kalev can walk them (1.8 m middle aisle between the two north blocks, 1.5 m between rows, a free strip along the arcade piers; the site is turned about 26° so Kalev's square footprint needs about 1.06 m across a gap; `test_holy_spirit_nave_benches_leave_walkable_aisles` checks every slot).
- **Doors:** a pointed north portal near the west end and the small pointed door beside it, as today; the south door from the almshouse yard (dual-entrance tradition, attested / composite).
- **Almshouse** (1334): beside the choir, opening into the south aisle through an arch, furnished as the hospice sick-room of the New Game opening (see [Almshouse sick-room](#almshouse-sick-room-adr-0052)).
- **Bells:** an octagonal timber turret with a shingled spire on the west gable.

**Decoration:** white lime render outside, crow-stepped gables; two-light lancets with mullions, roundels and leaded stained glass (smaller than the 1360 windows); a wide-plank nave floor, stone flags and tomb slabs in the choir; iron candle crowns from the beams; a plain painted pulpit on a pier; saint figures on pier consoles; the rood beam with the crucifix, Mary and John; a winged retable as a smaller, plainer form of the later carved altar (predella, gilded shrine of five saints under pointed canopies, painted wings, cresting). Shared glazing, murals and sunlight are in [Church interiors](../CHURCH_INTERIORS.md).

**Left out (later):** rib vaults, the large Gothic windows and the stone tower (all 1360s), the north portal (1597), the clock (1684), the painted galleries (17th c.), Notke's altarpiece (1483), the baroque spire.

**Historical research:**

- Project: [Churches and religious houses](../../../history/dossiers/religion/churches-and-religious-houses.md) (Holy Spirit section); [Liturgical calendar, spring 1343](../../../history/dossiers/religion/liturgical-calendar-spring-1343.md).
- External: Wikipedia, ["Church of the Holy Spirit, Tallinn"](https://en.wikipedia.org/wiki/Church_of_the_Holy_Spirit,_Tallinn) (1316/1319 records, 1360 vaults); HistoryFiles, ["Holy Spirit Church"](https://www.historyfiles.co.uk/ChurchesEurope/Estonia/Harju_Tallinn07.htm) (almshouse church, twin-nave tradition).

**Verify:** `godot --headless --path . --script tools/validate_city_sites.gd`; `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_city_sites` (rooms, choir steps, bench aisles, the almshouse sick-room and its opening ids); `tools/godot_render.sh --script tools/capture_site_rooms.gd`.

**Related work:** R-1613 (`idea`, terrain bank), R-1614 (`idea`, lime-render weathering), R-1615 (`idea`, precinct research). R-1126 / LM-03 (`todo`) targets the legacy district model, not a missing city church. Capture context: walk 5 (2026-10-10).

## Almshouse sick-room (ADR 0052)

The healer's apprentice starts here ([ADR 0052](../../adr/0052-healer-apprentice-and-family-cure-loop.md)): patients arrive at the Holy Spirit almshouse. The 1334 almshouse is **`attested`**; its furnishing is not recorded, so the sick-room is **`plausible composite`** (`period_notes`, [CANON](../../CANON.md)).

- **Room:** `room.almshouse` "Holy Spirit almshouse", floor `floor.almshouse` (planks, 0.12), site-local x 38.0-48.0, z 1.84-7.4 (10 × 5.6 m). Doors: the yard door `door.holy_spirit.almshouse` in the east wall and the open arch into the south aisle in the west wall, so the sick hear mass at the side altar.
- **Furnishing** (catalogue dressing `almshouse.*` in the manifest, existing models only): seven straw-tick box beds (`obj.bed_straw_pallet`) head to the walls in two rows with a 1.6 m aisle between, linen on the sickbed, a bench by the door with a basin and cloth and folded linen, a household table with bowls, a jug and a grease lamp, a stool, a bucket, an open shelf of remedy jars, and a herb drying rack (district life prop, `obj.herb_drying_rack`) in the south-west corner. Built in `holy_spirit_builder.gd` (procedural, no new art): a small altar niche on the west wall (painted recess, plank mensa with a linen cloth, two tallow candlesticks from the catalogue) with a plain wall crucifix (`CityChurchFurnishings.wall_crucifix`, since `obj.crucifix_wall` has no model), and a three-legged iron brazier with glowing charcoal and a low ember light, since the range has no chimney. The earlier procedural box beds are gone; their walk solids now come from the dressing `solid` sizes.
- **Opening ids** (used by the New Game opening; keep them stable). The site is turned -25.886° with its anchor at world (10.435, -86.445); the room floor is at world height 20.038.

| Id | Site-local | World XZ | Notes |
|---|---|---|---|
| spawn `holy_spirit_almshouse` | (45.4, 4.7), `facing_deg` 0 | (53.33, -102.04), facing -25.9° | In the aisle beside the sickbed, facing the yard door; registered in `content/transitions/active_destinations.json` and `CityTravel.SPAWNS` like `kalev_smithy` |
| `anchor.holy_spirit.sickbed` | (44.6, 6.5) | (53.40, -100.07) | `pose: lie` on `almshouse.bed_s3`; `head_at` (44.6, 7.1) = world (53.66, -99.53) by the south wall, `feet_at` (44.6, 5.6) = world (53.00, -100.88); `lie_h` 0.56 m above the floor (world height about 20.60) |
| `anchor.holy_spirit.sickbed_attendant` | (45.75, 6.0), `facing_deg` 180 | (54.21, -101.02) | The hero at the bed's east side, facing the patient |
| `anchor.holy_spirit.almshouse_kalev` | (47.2, 5.25), `facing_deg` 180 | (55.19, -102.33) | Kalev just inside `door.holy_spirit.almshouse`, facing into the room |

All four points are on the room floor and clear of the furniture solids (`test_holy_spirit_almshouse_sick_room_and_opening_ids`).

| Sick-room from the yard door | Beside the sickbed |
|---|---|
| ![Almshouse sick-room from the yard door: two rows of straw-tick beds, the altar niche with its crucifix, the arch into the church](../../reports/images/sites/holy_spirit_almshouse_door.jpg) | ![The south row of beds from beside the sickbed, the herb rack and the arch into the south aisle](../../reports/images/sites/holy_spirit_almshouse_sickbed.jpg) |

| Cutaway |  |
|---|---|
| ![Cutaway of the almshouse: beds, brazier, table and shelf, the altar niche by the arch to the nave](../../reports/images/sites/holy_spirit_almshouse_cutaway.jpg) |  |

Captured with `tools/godot_render.sh --script tools/capture_site_rooms.gd` (2026-10-16; site builder at the compiled placement, studio light; the cutaway lifts `Church/Upper` and `Church/Roof` as the runtime does).

## More views

Model captures, not photos of modern Tallinn or concept art. Ongoing fixes may postdate them. Walk-test frames are first-person or top-down shots taken by the automated site walk (2026-10-13).

| Church and precinct from above (historical walk 5) | Almshouse range |
|---|---|
| ![Church and precinct from above (historical walk 5)](../../reports/images/historical_walk/hw5_holy_aerial.jpg) | ![Almshouse range](../../reports/images/historical_walk/hw5_holy_almshouse.jpg) |

| North windows | South side |
|---|---|
| ![North windows](../../reports/images/historical_walk/hw5_holy_north_windows.jpg) | ![South side](../../reports/images/historical_walk/hw5_holy_south.jpg) |

| From the north-west, runtime camera | From the south, runtime camera |
|---|---|
| ![From the north-west, runtime camera](../../reports/images/historical_walk/hw5_rt_holy_nw.jpg) | ![From the south, runtime camera](../../reports/images/historical_walk/hw5_rt_holy_south.jpg) |

| Nave walls before the mural pass | Nave walls after the mural pass |
|---|---|
| ![Nave walls before the mural pass](../../reports/images/church_interiors/murals_holy_spirit_before.jpg) | ![Nave walls after the mural pass](../../reports/images/church_interiors/murals_holy_spirit_after.jpg) |

| Window sunlight, morning | Window sunlight, noon |
|---|---|
| ![Window sunlight, morning](../../reports/images/church_interiors/sunlight_holy_spirit_morning.jpg) | ![Window sunlight, noon](../../reports/images/church_interiors/sunlight_holy_spirit_noon.jpg) |

| Window sunlight, afternoon | Aerial view |
|---|---|
| ![Window sunlight, afternoon](../../reports/images/church_interiors/sunlight_holy_spirit_afternoon.jpg) | ![Aerial view](../../reports/images/city/sites/holy_spirit_aerial.jpg) |

| Cutaway, roofs lifted | Interior |
|---|---|
| ![Cutaway, roofs lifted](../../reports/images/city/sites/holy_spirit_cutaway.jpg) | ![Interior](../../reports/images/city/sites/holy_spirit_interior.jpg) |

| Aisles (model, photo viewpoint) | Choir (model, photo viewpoint) |
|---|---|
| ![Aisles (model, photo viewpoint)](../../reports/images/city/sites/holy_spirit_photo_aisles.jpg) | ![Choir (model, photo viewpoint)](../../reports/images/city/sites/holy_spirit_photo_choir.jpg) |

| Nave (model, photo viewpoint) | North side (model, from the viewpoint of a photo of the real building) |
|---|---|
| ![Nave (model, photo viewpoint)](../../reports/images/city/sites/holy_spirit_photo_nave.jpg) | ![North side (model, from the viewpoint of a photo of the real building)](../../reports/images/city/sites/holy_spirit_photo_north.jpg) |

| South side (model, photo viewpoint) | Street view |
|---|---|
| ![South side (model, photo viewpoint)](../../reports/images/city/sites/holy_spirit_photo_south.jpg) | ![Street view](../../reports/images/city/sites/holy_spirit_street.jpg) |

| Walk test: arriving at the almshouse | Walk test: just inside the door |
|---|---|
| ![Walk test: arriving at the almshouse](../../reports/images/city/sites/walk_holy_spirit_almshouse.jpg) | ![Walk test: just inside the door](../../reports/images/city/sites/walk_holy_spirit_inside.jpg) |

| Walk test: top-down camera inside | Walk test: arriving from the south |
|---|---|
| ![Walk test: top-down camera inside](../../reports/images/city/sites/walk_holy_spirit_inside_top_down.jpg) | ![Walk test: arriving from the south](../../reports/images/city/sites/walk_holy_spirit_south.jpg) |

| Walk test: first-person view of the almshouse | Walk test: first-person view of the choir |
|---|---|
| ![Walk test: first-person view of the almshouse](../../reports/images/city/sites/walk_holy_spirit_view_almshouse.jpg) | ![Walk test: first-person view of the choir](../../reports/images/city/sites/walk_holy_spirit_view_choir.jpg) |

| Walk test: first-person view of the nave | Walk test: arriving from the west |
|---|---|
| ![Walk test: first-person view of the nave](../../reports/images/city/sites/walk_holy_spirit_view_nave.jpg) | ![Walk test: arriving from the west](../../reports/images/city/sites/walk_holy_spirit_west.jpg) |

| Door plate (closed) | Door plate (open) |
|---|---|
| ![Door plate (closed)](../../reports/images/city/doors/holy_spirit.png) | ![Door plate (open)](../../reports/images/city/doors/holy_spirit_open.png) |

| Door plate (inside) |  |
|---|---|
| ![Door plate (inside)](../../reports/images/city/doors/holy_spirit_inside.png) |   |
