# City sea, shore and harbour life

Status: implemented (country and harbour pass of the seamless city, ADR 0031; board task not yet filed). Scope: the Baltic off Reval and its shore in the seamless city: the sea surface and storm swell, seabed and beach relief, shore dressing, boardable boats and the working craft of the two shores; the Hareapea stream and moat water, their water plants and the wake Kalev leaves in any city water. Out of scope: swimming mechanics (ADR 0021), shipping routes, fishing as gameplay, and anything below one metre of water being visible (see Limits). Harbour layout and sources: [`FARMLAND.md`](./FARMLAND.md#harbour-and-kalamaja).

## What the player sees

- **Sea.** The same FFT ocean as the district maps (`MapViewMaterials.water_surface(TERRAIN_SHALLOW_WATER)`): baked waves, whitecaps and foam, shore swash, caustics, refraction and sun glint, driven by the sky weather (`apply_sea_weather` is called from `CityWorld3D.apply_time`). The open sea is 1 m per unit, so `SEA_WAVE_BOOST` (5.0, `CityWorld3D`) scales displaced crest height: a calm sea moves a few centimetres, a gale lifts crests to about 1.7 m and boats and swimmers ride it (`WATER_MATERIALS.set_wave_height_boost`, mirrored in the CPU hull sampler).
- **Seabed.** The generator (`build_reval_city_plan.py`) shapes the bed with shore-parallel sandbars and troughs, undulation and boulder fields, so depth varies instead of one tilted plane. Beaches get berms and runnels near the water and drift-sand hummocks.
- **Ground shader** (`city_ground.gdshader`): two sands, a dark wet strand, shingle just above the swash, and below the waterline weed, bare stone and ripple-marked sand.
- **Shore dressing** (`CityShore`): granite erratics clustered in the shallows (with weed skirts), stone clusters, shingle lenses and wrack lines, reusing the district maps' CO-02 meshes. Deterministic from the plan heightfield.
- **Boats.** `CityBoats` builds lofted clinker hulls: fishing clinker boat, skiff, flat-bottomed cargo lighter and the boat turned over on trestles. Cogs are `CogModel` ([`SHIPS.md`](./SHIPS.md)). **Cogs, boats and lighters at anchor or beached can be boarded**: Kalev swims alongside and steps onto the hull (`CityShips.deck_height_at`, hooked into `CityPlan.walk_height` through `dynamic_deck`). The sailing cog under way cannot be boarded.
- **Crane and shore furniture** (`CityHarbour`): a Hanseatic treadwheel crane (timber tower, spoked tread drum, jib with rope and hook) at the merchant landing, cargo stacks, net yards with pole racks.
- **Fish** (`CityFish`): shoals of herring and a few perch circle in the clear shallows near Kalev.

## Stream, moat and wake

- **Hareapea stream** (`CityWorld3D._build_water`, `_stream_mesh`): a mitred grid ribbon (1.5 m cells) along the plan trace. Its width is measured per trace point out to where the carved bank climbs above the surface (`_stream_wet_halves`, plus `STREAM_BANK_OVERLAP` 1.5 m that the terrain hides), so the water meets the bank at the waterline instead of ending in a step over a dry pit. It uses the moat's murky shader (`city_moat_water.gdshader`) in a peat-brown tint (`_stream_material`): colour deepens with the water column and the edge fades into mud; ripples run downstream along the ribbon UV. The column comes from the vertices (`vertex_depth`: depth over the plan ground baked into `COLOR.r`), not the depth texture, which read about zero in perspective under GL Compatibility and left the stream fully clear.
- **Water plants** (`CityMoatPlants`): reed and cattail clumps in the shallows (bed up to 0.8 m under the surface) of the moat and, now, both stream banks; on the stream the belt also climbs onto wet bank up to 0.3 m above the surface, and floating lily pads and duckweed are at 40 % of the moat's density.
- **No trees in water** (`CityWorld3D._clear_wet_trees`): the plan scatters open-country trees, woods and bank thickets without knowing the stream bed, so at build time every plan tree and bush whose foot is under, or within 0.25 m of, a stream, moat or sea surface is dropped from `plan.data` (about 136 stood in the Hareapea bed).
- **Wake** (`CityMapView._create_city_ripple_sim`): the district maps' WS-15 ripple sim (`WaterRippleSim`, 64-unit window, off on tiers with `ripple_sim_size` 0) runs in the city, centred 6 units ahead of the camera. `MapViewSwimmerPresenter` feeds it, so wading and swimming leave a V wake and an entry splash. It binds the sea material and every city water material; the moat shader reads it as normal slope, a little sheen and bubbly foam.
- Review plates: [bank](../reports/images/city/city_stream_bank.png) (murky water to the waterline, reed and cattail fringe), [wake](../reports/images/city/city_stream_wake.png) (ripple rings behind a wader).
- **Depth.** The stream bed is 0.9 m under the surface (`build_reval_city_plan.py`), below the 1.25 m swim threshold (`PlayerSwimState.SWIM_ENTER_DEPTH`): Kalev wades the Hareapea and swims in the sea and the deeper moat.

## Verify

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_city_shore
tools/godot_render.sh --script tools/capture_city_sea.gd -- --only=sea_storm_wide,sea_calm_beach_close,fish
tools/godot_render.sh --script tools/capture_city_stream.gd -- --tag=x   # build/stream/{bank_up,bank_low,bank_mouth,top,wake}_x.png
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_city_stream
```

## Limits

- The sea shader hides anything below about a metre of water, so fish only show in the shallows and boulders and weed deeper down are felt as colour, not seen. Fish were not seen in a plate; treat them as unverified until someone looks.
- Storm swell is 5 times the district value; boats were not re-tuned for it, so a gale may bury a small boat's gunwale.
- Boarding a cog drops Kalev onto the deck (`CogModel.walk_height`) with no climb animation.
- The ground shader's seabed layers are cheap noise, not authored plates.
- The Hareapea has no deep pools: it is wade-only. Trees are filtered at build time, not in the plan generator, so `plan.json` still lists them.
- The moat still takes its water column from the depth texture; check it in perspective plates for the same clear-water fault.
- The ripple window follows the camera, so in the top-down overview a wake far from the screen centre is not drawn.
