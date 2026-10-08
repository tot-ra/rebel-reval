# Farmland, pastures and woods round Reval

Status: implemented (country pass of the seamless city, ADR 0031; board task not yet filed, no board access in the authoring session). Scope: the open country outside the 1343 walls of the seamless city: strip fields with seasonal crops, kitchen-garden beds, fenced crofts and common pastures with livestock, hay ricks, farmsteads with yard animals, farm hands working the spring fields, and woods. Presentation and plan data only: no collision, no `GameState`, no farming mechanic. Out of scope: a harvest or crop economy, ploughing animation, field ownership, and the distant regions that keep an explicit journey (ADR 0027).

## What the player sees

- **Fields.** Strip parcels (14-24 m wide, 80-150 m long) in blocks on dry, gentle ground 40-620 m from the walls. Crops follow the campaign date (the slice opens on 21 April 1343): winter rye and wheat are green and knee-high, spring barley, oats, peas and flax have just been sown and the soil is bare, gardens hold seedlings (cabbage, turnip, onion, peas, flax), fallow strips are rough grass. Grain ripens to gold in July and August and is stubble from harvest. Rye and barley dominate; winter wheat is a minor crop (CANON diet note). Crop heights and seasons: `CityFarmland.growth` / `tint` (pure functions of the day of year).
- **Pastures.** Fenced crofts beside every farmstead (rail fence, hay rick) and unfenced common grazing along the Karja cattle road, with cows, sheep, goats, horses and geese. A few damp meadows hold sheep and geese.
- **Farmsteads.** The farm-suburb houses (`bldg.karja.*`, `bldg.harju.*`, `bldg.toompea_foot.*`) each get a hen run, one in three a pig pen.
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

## Verify

```bash
python3 tools/city/build_reval_city_plan.py --check
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_city_farmland
tools/godot_render.sh --script tools/capture_city_farmland.gd -- --only=field_rye_game,pasture --date=4-21
```

`capture_city_farmland.gd` writes plates to `build/farmland/` (fields at eye level and from the gameplay camera, a croft, the north wall towers, shore shrubs).

## Limits

- Furrow stripes are not painted on the ground yet, so a field seen from beyond 150 m is a flat soil or grass patch (`DRAW_RANGE`). A far-field raster in the ground shader is the next step.
- Farm hands only walk; there is no sowing, hoeing or ploughing animation and no ox team.
- Crop stage uses fixed day-of-year anchors, not weather.
- Farmsteads reuse the existing suburb houses; no barns or yards are modelled.
