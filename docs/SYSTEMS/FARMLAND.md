# Farmland, pastures and woods round Reval

Status: implemented (country pass of the seamless city, ADR 0031; board task not yet filed, no board access in the authoring session). Scope: the open country outside the 1343 walls of the seamless city: strip fields with seasonal crops, kitchen-garden beds, fenced crofts and common pastures with livestock, hay ricks, farmsteads with yard animals, farm hands working the spring fields, and woods. Presentation and plan data only: no collision, no `GameState`, no farming mechanic. Out of scope: a harvest or crop economy, ploughing animation, field ownership, and the distant regions that keep an explicit journey (ADR 0027).

## What the player sees

- **Fields.** Strip parcels (14-24 m wide, 80-150 m long) in blocks on dry, gentle ground 40-620 m from the walls. Crops follow the campaign date (the slice opens on 21 April 1343): winter rye and wheat are green and knee-high, spring barley, oats, peas and flax have just been sown and the soil is bare, gardens hold seedlings (cabbage, turnip, onion, peas, flax), fallow strips are rough grass. Grain ripens to gold in July and August and is stubble from harvest. Rye and barley dominate; winter wheat is a minor crop (CANON diet note). Crop heights and seasons: `CityFarmland.growth` / `tint` (pure functions of the day of year).
- **Pastures.** Fenced crofts beside every farmstead (rail fence, hay rick) and unfenced common grazing along the Karja cattle road, with cows, sheep, goats, horses and geese. A few damp meadows hold sheep and geese.
- **Farmsteads.** Each farm-suburb house (`bldg.karja.*`, `bldg.harju.*`, `bldg.toompea_foot.*`) is a smoke cottage with a yard of outbuildings by wealth tier (`FARM_TIERS` in the generator). Types, sizes and roofs differ so the silhouettes read apart: `barn_dwelling` (the *rehemaja*: long, high log mass, one dwelling door, no chimney), `barn` (threshing and storage), `byre`, `sheep_shed`, `pigsty`, `hen_house`, `store`. They are plan `buildings` of `kind: outbuilding` (solid, never enterable, ignored by the census) with the animals kept at their own sheds (`CityFauna.YARD_STOCK`).
- **Farm hands.** A man or woman walks the furrow of every other spring-sown field or garden bed while Kalev is within 75 m (at most six at once).
- **Woods.** Clustered spruce-pine, pine on the sandy ridges, alder-birch in the damp, oak-linden mixed stands, thinning toward the walls and open at the glacis. About 5,000 trees; the old scatter of single trees is gone from fields and pastures.

## How it is built

`tools/city/build_reval_city_plan.py` (`countryside`) writes four lists into `content/world/reval_city/plan.json`:

| Key | Record | Notes |
|---|---|---|
| `fields` | `{id, crop, sowing, ploughed, angle, polygon}` | `sowing` is `winter`, `spring`, `garden` or `fallow`; ids `field.<block>.<strip>` |
| `pastures` | `{id, kind, fence, stock, polygon}` | `kind` is `croft`, `common` or `meadow`; `stock` lists species and counts |
| `woods` | `{id, kind, at, area_m2, cells}` | the trees themselves are in `trees` |
| `farmsteads` | `{id, building, at}` | `farmstead.<suburb>.<n>` |

Generation is deterministic (seeded value noise, no filesystem walk). Woods claim damp, steep and far ground first, then pastures, then fields; nothing is placed inside the plan's 24 m edge margin. The ground splat paints tilled soil under spring fields and gardens, a green-through-soil wash under winter grain. The review plate and minimap colour fields by `sowing`.

Runtime entry points:

- `CityFarmland` (`scripts/city/city_farmland.gd`, mounted by `CityWorld3D`, updated from `reval_city.gd`): streams one field or pasture per frame within 95 m of Kalev (freed beyond 135 m). Crops are `MapViewPlantMeshes` MultiMeshes in rows; fences are post and rail MultiMeshes; ricks are `MapViewHayMeshes`. `set_calendar_date` rebuilds crops when the date changes.
- `CityFauna.groups_for`: pasture and farmstead animal groups.
- `CityNpcs._stream_field_workers`: the farm hands (the shared `Walker`).
- `CityVegetationBuilder`: `juniper_shrub` and `sea_buckthorn` now draw with the real-size leaf-card tree meshes (the shared block-shaped shrub meshes read as giant flat stalks beside a 1.83 m figure).

## Historical basis for the yard

From [`history/dossiers/architecture/rural-smoke-dwelling-and-farmstead-1343.md`](../../history/dossiers/architecture/rural-smoke-dwelling-and-farmstead-1343.md): the combined barn-dwelling (*rehemaja*, *rehielamu*) is attested at type level from the 14th century; the chimneyless oven-heated log smoke cottage is the archaeological baseline (8th to 15th century); chambers (*kambrid*) are an early-17th-century addition and are excluded; museum facades (18th and 19th century) are analogies, not 1343 fact. Exact 1343 roof forms and the chronology of standalone livestock shelters are dossier gaps, so every outbuilding is `plausible composite`. **Rabbit hutches are deliberately absent**: domestic rabbits reached England about 1176 and the Low Countries from 1250, and nothing evidences them in 1343 Estonia (Sweden keeps them from the 16th century).

## Harbour and Kalamaja

Sources: [`harbour-and-shoreline.md`](../../history/dossiers/topography/harbour-and-shoreline.md), [`kalamaja-fishing-shore-1343.md`](../../history/dossiers/topography/kalamaja-fishing-shore-1343.md). Plan key `harbour` plus `bridges` entries of kind `jetty` / `beach_deck`, built by `harbour_features` in the generator.

- **Merchant landing** under the Coastal Gate: two short timber jetties (walkable), one treadwheel crane (`CityHarbour`, a reversible plausible composite), cargo and bale stacks, plank cargo sheds, cogs in the roadstead (`CityShips`). No continuous stone quay, no foregate, no Fat Margaret.
- **Kalamaja fishing shore**: three beach decks, three fenced net yards with pole racks (`CityHarbour`), two smoke sheds, a salt shed, the boatwright's timber and cart, and 8 clinker boats drawn up on the sand. The existing `bldg.kalarand.*` huts are the fisher dwellings.
- The yard and boat counts (3 yards, 6 to 8 boats) are bounded gameplay composites; documentary support is thin (dossier open question).

## Far fields

`CityFarmland._rebuild_far` draws every cropped field as one coloured, row-banded sheet that hugs the ground, so fields read from the whole city and beyond `DRAW_RANGE`. Colour follows crop and date (`far_color`): tilled soil, greening, then gold. In April winter grain is green and spring fields are brown; wheat and barley turn gold in July and August (`--date=7-25` in the capture tool).

## Bridges and the east moat

- **Bridges.** Plan key `bridges` (`bridge.viru`, `bridge.tartu`): where an extramural road crosses the Hareapea the generator records the crossing and `CityBridges` builds a plank deck on pile trestles. `CityPlan.bridge_deck_height` makes the deck walkable (ramped between bank heights) and keeps Kalev out of the swim state. No 1343 bridge is attested: a reversible reconstruction. The Viru (Narva) road now bends inland to cross the stream instead of running into the bay. The stream is graded (2026-10-08): plan `harjapea.surfaces` gives the water level per trace point (valley floor minus 1.6 m, never rising downstream, 0 at the mouth), the bed is 0.9 m under it and the banks blend over 14 m, so the deck meets the banks instead of hanging over a 12 m gorge. Stream segments feed `water_surface_at` like the moat pools. Test: `test_stream_is_graded_and_bridges_sit_on_the_banks`.
- **Moat.** The ditch now runs up the east curtain from the Viru gate to the Sand gate as well as round the south (canon: new irrigated moat on the southern and eastern sections; Ülemiste water rights only 1345, so the water is a presentation choice, see `docs/CANON.md`).
- **Not built, by canon.** The four-tower Viru barbican and round foregate towers are 1370s to 1460s (`history/dossiers/topography/walls-gates-towers.md`: "Viru: present/unfinished, no foregates or barbicans in April 1343"). The round flanking towers once drawn at Viru were removed (2026-10-08): the gate is one plain stone gate house with a low shed roof (`state: unfinished`). The east moat now reaches the causeway dam at the gate.

## Verify

```bash
python3 tools/city/build_reval_city_plan.py --check
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_city_farmland
tools/godot_render.sh --script tools/capture_city_farmland.gd -- --only=field_rye_game,pasture --date=4-21
```

`capture_city_farmland.gd` writes plates to `build/farmland/` (fields at eye level and from the gameplay camera, a croft, the north wall towers, shore shrubs).

## Limits

- Beyond 150 m a field is a banded colour sheet, not plants.
- Farm hands only walk; there is no sowing, hoeing or ploughing animation and no ox team.
- Crop stage uses fixed day-of-year anchors, not weather.
- Outbuildings use the shared log and thatch kit: no yard fences, wells, hay or manure clutter, and no dedicated model art pass the dossier asks for (log variation, corner joinery, smoke-darkened doors).
- Outbuildings have no interiors.
