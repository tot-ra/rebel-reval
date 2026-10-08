# Farmland, pastures and woods round Reval

Status: implemented (country pass of the seamless city, ADR 0031; board task not yet filed, no board access in the authoring session). Scope: the open country outside the 1343 walls of the seamless city: strip fields with seasonal crops, kitchen-garden beds, fenced crofts and common pastures with livestock, hay ricks, fenced orchards, farmsteads with yard animals, farm hands working the spring fields, and woods. Presentation and plan data only, except that hay stacks are solid (see Hay stacks): no other collision, no `GameState`, no farming mechanic. Out of scope: a harvest or crop economy, ploughing animation, field ownership, and the distant regions that keep an explicit journey (ADR 0027).

## What the player sees

- **Fields.** Strip parcels (14-24 m wide, 80-150 m long) in blocks on dry, gentle ground 40-620 m from the walls. Crops follow the campaign date (the slice opens on 21 April 1343): winter rye and wheat are green and knee-high, spring barley, oats, peas and flax have just been sown and the soil is bare, gardens hold seedlings (cabbage, turnip, onion, peas, flax), fallow strips are rough grass. Grain ripens to gold in July and August and is stubble from harvest. Rye and barley dominate; winter wheat is a minor crop (CANON diet note). Crop heights and seasons: `CityFarmland.growth` / `tint` (pure functions of the day of year).
- **Pastures.** Fenced crofts beside every farmstead (hay rick; fence type by enclosure id: about 62% woven wattle, 24% rough pole fence on stakes, 14% low field-stone wall, all in grey weathered wood or stone, no sawn boards because timber was dear in a 1343 village, `CityFences`, `scripts/city/city_fences.gd`; review plate `tools/capture_country_fences.gd`, test `tests/godot/test_city_fences.gd`; the same builder also dresses Kalamaja net yards and the `timber_fence` map prop through `CityFences.build_run`, wattle or pole by prop id, no sawn box posts and rails) and unfenced common grazing along the Karja cattle road, with cows, sheep, goats, horses and geese. A few damp meadows hold sheep and geese.
- **Orchards.** About 30 fenced fruit gardens (plan key `orchards`): most farmsteads keep one 24-34 m x 30-44 m beside the yard, a few more stand on dry ground 45-260 m from the walls. Trees stand in loose planted rows 5-6 m apart with the odd gap, apple dominant with cherry, plum and pear (the existing `apple`/`cherry`/`plum`/`pear` tree species, so no new model was needed). The enclosure is a wattle/pole/stone fence like a croft (`CityFences`). They are claimed before the fields, so strips go round them. Review plate: `tools/capture_city_farmland.gd --only=orchard`; test `test_orchards_hold_fruit_trees_and_stay_clear_of_fields`. Limits: no blossom or ripe-fruit seasonal state, no ladders or baskets, and the fruit trees are ordinary plan `trees` (not separate streamed objects).
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
| `orchards` | `{id, fence, trees, polygon}` | `orchard.<n>`; the fruit trees themselves are entries in `trees` |

Generation is deterministic (seeded value noise, no filesystem walk). Woods claim damp, steep and far ground first, then pastures, then fields; nothing is placed inside the plan's 24 m edge margin. The ground splat paints tilled soil under spring fields and gardens, a green-through-soil wash under winter grain. The review plate and minimap colour fields by `sowing`.

Runtime entry points:

- `CityFarmland` (`scripts/city/city_farmland.gd`, mounted by `CityWorld3D`, updated from `reval_city.gd`): streams one field or pasture per frame within 95 m of Kalev (freed beyond 135 m). Crops are `MapViewPlantMeshes` MultiMeshes in rows; fences are `CityFences` meshes (one rod mesh per enclosure, MultiMesh stones for walls); ricks are `MapViewHayMeshes` (see Hay stacks). `set_calendar_date` rebuilds crops when the date changes.
- `CityFauna.groups_for`: pasture and farmstead animal groups.
- `CityNpcs._stream_field_workers`: the farm hands (the shared `Walker`).
- `CityVegetationBuilder`: `juniper_shrub` and `sea_buckthorn` now draw with the real-size leaf-card tree meshes (the shared block-shaped shrub meshes read as giant flat stalks beside a 1.83 m figure).

## Historical basis for the yard

From [`history/dossiers/architecture/rural-smoke-dwelling-and-farmstead-1343.md`](../../history/dossiers/architecture/rural-smoke-dwelling-and-farmstead-1343.md): the combined barn-dwelling (*rehemaja*, *rehielamu*) is attested at type level from the 14th century; the chimneyless oven-heated log smoke cottage is the archaeological baseline (8th to 15th century); chambers (*kambrid*) are an early-17th-century addition and are excluded; museum facades (18th and 19th century) are analogies, not 1343 fact. Exact 1343 roof forms and the chronology of standalone livestock shelters are dossier gaps, so every outbuilding is `plausible composite`. **Rabbit hutches are deliberately absent**: domestic rabbits reached England about 1176 and the Low Countries from 1250, and nothing evidences them in 1343 Estonia (Sweden keeps them from the 16th century).

## Harbour and Kalamaja

Sources: [`harbour-and-shoreline.md`](../../history/dossiers/topography/harbour-and-shoreline.md), [`kalamaja-fishing-shore-1343.md`](../../history/dossiers/topography/kalamaja-fishing-shore-1343.md). Plan key `harbour` plus `bridges` entries of kind `jetty` / `beach_deck`, built by `harbour_features` in the generator.

- **Merchant landing** under the Coastal Gate: two short timber jetties (walkable), one treadwheel crane (`CityHarbour`, a reversible plausible composite), cargo and bale stacks, plank cargo sheds, cogs in the roadstead (`CityShips`). No continuous stone quay, no foregate, no Fat Margaret.
- **Kalamaja fishing shore**: three beach decks, three net yards with pole racks (`CityHarbour`), fenced with `CityFences` wattle or pole runs (grey weathered wood, never stone, `forced_kind`), two smoke sheds, a salt shed, the boatwright's timber and cart, and 8 clinker boats drawn up on the sand. The existing `bldg.kalarand.*` huts are the fisher dwellings.
- The yard and boat counts (3 yards, 6 to 8 boats) are bounded gameplay composites; documentary support is thin (dossier open question).

## Field soil (2026-10-09)

Tilled fields and gardens are black earth, never turf. `render_splat` paints each non-fallow field as full packed earth plus a mud-channel marker `FIELD_MUD_LEVEL` (110/255), with the outline warped by smooth noise so strips are not ruler-straight. `city_ground.gdshader` (`field_zone`, `field_height`) reads that band as ploughed soil: dark desaturated earth, lighter dry clods, warped ridges, scattered stones, plus clod relief in the normal map. `CityGrass.field_share` keeps the grass scatter off it. Fallow strips stay rough grass. Review: `tools/godot_render.sh --script tools/capture_city_farmland.gd -- --only=field_rye_game --date=4-21`. Limits: no straight furrow lines in the ground (rows come from the crop plants), and a house seam in the mud channel at the same value would read as field soil.

## Far fields

`CityFarmland._rebuild_far` draws every sown field as a translucent, row-banded crop wash (`FAR_SHEET_ALPHA`) that hugs the ground, thins to a ragged margin and fades in with the plants (bare soil gets no sheet, the ground shader shows it), so fields read from the whole city and beyond `DRAW_RANGE`. Colour follows crop and date (`far_color`): tilled soil, greening, then gold. In April winter grain is green and spring fields are brown; wheat and barley turn gold in July and August (`--date=7-25` in the capture tool).

## Bridges and the east moat

- **Bridges.** Plan key `bridges` (`bridge.viru`, `bridge.tartu`): where an extramural road crosses the Hareapea the generator records the crossing and `CityBridges` builds a plank deck on pile trestles. `CityPlan.bridge_deck_height` makes the deck walkable (ramped between bank heights) and keeps Kalev out of the swim state. No 1343 bridge is attested: a reversible reconstruction. The Viru (Narva) road now bends inland to cross the stream instead of running into the bay. The stream is graded (2026-10-08): plan `harjapea.surfaces` gives the water level per trace point (valley floor minus 1.6 m, never rising downstream, 0 at the mouth), the bed is 0.9 m under it and the banks blend over 14 m, so the deck meets the banks instead of hanging over a 12 m gorge. Stream segments feed `water_surface_at` like the moat pools. Test: `test_stream_is_graded_and_bridges_sit_on_the_banks`. Weathering (2026-10-08): the deck is individual planks (one MultiMesh per hewn-oak grain variant, per-board jitter, tone and rot via instance colour) on three stringers, rails are two-rail hewn beams, piles split into a dark glossy water-soaked foot (up to `SPLASH_HEIGHT` over `water_surface_at`) with a darker green-tinted tone, and dark checks across the deck. Boards use Leonardo-generated 1024x128 weathered-oak strips with matching normals (`assets/materials/pbr/bridge_timber/`, moss and lichen baked in), UV-fitted via `hewn_timber_for_size`. Moss/lichen discs were dropped: they read as stray circles. Test: `test_bridge_builds_weathered_planked_deck`.
- **Moat.** The ditch now runs up the east curtain from the Viru gate to the Sand gate as well as round the south (canon: new irrigated moat on the southern and eastern sections; Ülemiste water rights only 1345, so the water is a presentation choice, see `docs/CANON.md`).
- **Not built, by canon.** The four-tower Viru barbican and round foregate towers are 1370s to 1460s (`history/dossiers/topography/walls-gates-towers.md`: "Viru: present/unfinished, no foregates or barbicans in April 1343"). Viru is a plain gate house between two slim round drums (`w` 6.5, cone `roof_h` 6.5; maintainer direction 2026-10-08, the four-tower barbican was withdrawn the same day, so `plan.barbicans` is empty).

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


## Moat (east and south ditch)

`tools/city/build_reval_city_plan.py` rounds the ditch line (`smooth_ditch`, kept 11.5 m from the curtain), cuts it with a long soft bank profile, grades the splat from grass through wet earth to mud, and cuts the ditch unbroken: every road crosses it on a timber bridge (`bridges` entries with `kind: "moat"`, `bridge.moat.viru|karja|harju`), not an earth dam.
Both ends of the ditch run out gently (2026-10-08): depth and width fade by smoothstep over the last `MOAT_TAPER_M` (80 m) in the generator (`build_reval_city_plan.py`), and `CityWorld3D._moat_pools` narrows the water ribbon over the same stretch, so the ditch no longer stops at a blunt cut-off at the south-west corner.
`CityWorld3D` draws the water with `city_moat_water.gdshader` (murky silt colour, depth-buffer edge fade) on a ribbon `CityPlan.MOAT_WATER_HALF_FACTOR` wide, so it meets the sloping bank. `CityMoatPlants` adds reed and cattail clumps rooted in the shallows plus floating lily pads and duckweed. `CityPlan.in_moat` keeps trees, shrubs and fauna (horses at the gates) out of the ditch. Review shots: `tools/capture_city_farmland.gd --only=viru_aerial,moat_reeds,bridge_moat_viru_side`. Limits: no flow, plants are static, bridge piles are the Hareapea trestle kit.

## Hay stacks

Status: implemented. Review plates: `tools/godot_render.sh --script tools/capture_hay_stack.gd -- --tag=<t>` writes `build/hay/hay_{sizes,close,pushed}_<t>.png`. Tests: `tests/godot/test_hay_stack.gd`.

- **Shape.** `MapViewHayMeshes` builds the tall field stack of the Baltic hayfield (forked up round a pole): 2.8 m canonical height (small 2.2 m, medium 2.8 m, tall 3.5 m), taller than a man and taller than wide (belly about 2.2 m across), narrow foot, belly at a third of the height, long convex shoulder and a tight leaning crown. The surface is one dense mass with soft lumps, combed vertical streaks and faint horizontal courses (periodic value noise, no loose stalks poking out). Three contour variants (seeded by prop id) differ in lean and plan oval.
- **Ground litter.** A flat second mesh (`GroundLitter`) lays strands and forkfuls round the foot, with a denser drag fan on the side the hay was carried from, so the base is not a clean disc. It is excluded from the stack bounds.
- **Solid.** In the seamless city `CityFarmland` adds a `StaticBody2D` circle (`MapViewHayMeshes.collision_radius`, layer `WORLD`) per rick under `collision_parent` (set by `reval_city.gd`); it is freed with its field. Hay stacks on the district maps are no longer climbable (`MapClimbableProps`): a 2.8 m stack is a wall, not a step.
- **Yielding flank.** `HayRickReaction` (the node `add_rick` returns) reads the actor pose that `update_grass_interaction` already feeds the grass (static `set_actor`). Within 0.7 m of the blocking radius the body mesh compresses on the actor side, widens across the push and leans its crown away (about 11 % squash, 0.13 shear), harder when the actor runs into it, then springs back with a damped wobble. Idle (one distance check) when nobody is near.
- **Fur and colour.** The body is drawn by `map_view_hay_stack.gdshader` (`MapViewMaterials.hay_stack(layer)`): an opaque body plus three fur shells (`FurN` children of `HayBody`, no shadows) that keep only pixels on a strand lattice in the stack's model space, so the silhouette and lit surface are hairy rather than an egg. Colour is grey-gold (damp dark root, bleached tips, per-strand tone, biplanar `hay_fibers.png`), not saturated yellow; the shared `hay` role colour used by litter and wagon loads is muted the same way.
- **Wind.** Both shaders read the global gust field (`wind_field.gdshaderinc`, ADR VEGR-2): the mass leans with height squared, and the outer fur shells lean downwind and flutter more, so a gust front ripples the loose top layer. Wagon loads get the same body and fur, no wisps.
- **Shed wisps.** `Wisps` (`MapViewHayMeshes.wisp_mesh`, `map_view_hay_wisps.gdshader`): 28 loose strands tucked on the upper stack. Stateless from `TIME`: at each cycle start the gust at the stack is compared with the wisp's own threshold (breeze lets a few go, a gale most); a released strand lifts, tumbles downwind with drag, falls to the ground, lies, then shrinks away. Review plate `build/hay/hay_gale_<tag>.png` from `tools/capture_hay_stack.gd`. Limit: the ground plane is the stack's base height, so on steep ground strands land at that level.
- **Wagon loads** use `add_rick(..., as_load = true)`: the same profile squashed into a low loaf, no litter and no reaction.
- **Limits.** The give is a transform on the body mesh, not true vertex deformation; no dent shape, and NPCs and animals do not press the stack. Hay left on the ground is static (not trampled or kicked). Collision exists only in the city scene; stacks on district maps keep their prop footprint. Not saved.
