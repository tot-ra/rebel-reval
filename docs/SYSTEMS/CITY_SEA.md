# City sea, shore and harbour life

Status: implemented (country and harbour pass of the seamless city, ADR 0031; board task not yet filed). Scope: the Baltic off Reval and its shore in the seamless city: the sea surface and storm swell, seabed and beach relief, shore dressing, boardable boats and the working craft of the two shores. Out of scope: swimming mechanics (ADR 0021), shipping routes, fishing as gameplay, and anything below one metre of water being visible (see Limits). Harbour layout and sources: [`FARMLAND.md`](./FARMLAND.md#harbour-and-kalamaja).

## What the player sees

- **Sea.** The same FFT ocean as the district maps (`MapViewMaterials.water_surface(TERRAIN_SHALLOW_WATER)`): baked waves, whitecaps and foam, shore swash, caustics, refraction and sun glint, driven by the sky weather (`apply_sea_weather` is called from `CityWorld3D.apply_time`). The open sea is 1 m per unit, so `SEA_WAVE_BOOST` (5.0, `CityWorld3D`) scales displaced crest height: a calm sea moves a few centimetres, a gale lifts crests to about 1.7 m and boats and swimmers ride it (`WATER_MATERIALS.set_wave_height_boost`, mirrored in the CPU hull sampler).
- **Seabed.** The generator (`build_reval_city_plan.py`) shapes the bed with shore-parallel sandbars and troughs, undulation and boulder fields, so depth varies instead of one tilted plane. Beaches get berms and runnels near the water and drift-sand hummocks.
- **Ground shader** (`city_ground.gdshader`): two sands, a dark wet strand, shingle just above the swash, and below the waterline weed, bare stone and ripple-marked sand.
- **Shore dressing** (`CityShore`): granite erratics clustered in the shallows (with weed skirts), stone clusters, shingle lenses and wrack lines, reusing the district maps' CO-02 meshes. Deterministic from the plan heightfield.
- **Boats.** `CityBoats` builds lofted clinker hulls: fishing clinker boat, skiff, flat-bottomed cargo lighter and the boat turned over on trestles. Cogs stay `MapViewMerchantBoatBuilder`. **Cogs, boats and lighters at anchor or beached can be boarded**: Kalev swims alongside and steps onto the hull (`CityShips.deck_height_at`, hooked into `CityPlan.walk_height` through `dynamic_deck`). The sailing cog under way cannot be boarded.
- **Crane and shore furniture** (`CityHarbour`): a Hanseatic treadwheel crane (timber tower, spoked tread drum, jib with rope and hook) at the merchant landing, cargo stacks, net yards with pole racks.
- **Fish** (`CityFish`): shoals of herring and a few perch circle in the clear shallows near Kalev.

## Verify

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_city_shore
tools/godot_render.sh --script tools/capture_city_sea.gd -- --only=sea_storm_wide,sea_calm_beach_close,fish
```

## Limits

- The sea shader hides anything below about a metre of water, so fish only show in the shallows and boulders and weed deeper down are felt as colour, not seen. Fish were not seen in a plate; treat them as unverified until someone looks.
- Storm swell is 5 times the district value; boats were not re-tuned for it, so a gale may bury a small boat's gunwale.
- Deck heights are approximate: boarding a cog drops Kalev about 3 m onto the deck with no climb animation.
- The ground shader's seabed layers are cheap noise, not authored plates.
