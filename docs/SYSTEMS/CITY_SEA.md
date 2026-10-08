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

Status: implemented (task **R-1440**, deterministic swim pools and generator vegetation exclusion).

- **Hareapea stream** (`CityWorld3D._build_water`, `_stream_mesh`): a mitred grid ribbon (1.5 m cells) along the plan trace. Its width is measured per trace point out to where the carved bank climbs above the surface (`_stream_wet_halves`, plus `STREAM_BANK_OVERLAP` 1.5 m that the terrain hides), so the water meets the bank at the waterline instead of ending in a step over a dry pit. It uses the moat's murky shader (`city_moat_water.gdshader`) in a peat-brown tint (`_stream_material`): colour deepens with the water column and the edge fades into mud; ripples run downstream along the ribbon UV. The column comes from the vertices (`vertex_depth`: depth over the plan ground baked into `COLOR.r`), not the depth texture, which read about zero in perspective under GL Compatibility and left the stream fully clear.
- **Water plants** (`CityMoatPlants`): reed and cattail clumps in the shallows (bed up to 0.8 m under the surface) of the moat and, now, both stream banks; on the stream the belt also climbs onto wet bank up to 0.3 m above the surface, and floating lily pads and duckweed are at 40 % of the moat's density.
- **No trees in the stream plan.** `stream_vegetation_exclusion()` in the generator rejects serialized tree/bush positions on the bed and wet banks, comparing interpolated water level with terrain plus 0.26 m clearance (runtime clearance plus quantisation tolerance). `plant()` and `shrubs()` guard their placement sinks; `countryside()` woods and orchard trees use the same guarded `add()`. Rejected candidates still reserve their spacing cell so unrelated seeded placements and stable land-use IDs do not shift. `CityWorld3D._clear_wet_trees` remains a safety net for stale/imported plans and the moat/sea, not the normal stream cleanup.
- **Wake** (`CityMapView._create_city_ripple_sim`): the district maps' WS-15 ripple sim (`WaterRippleSim`, 64-unit window, off on tiers with `ripple_sim_size` 0) runs in the city, centred 6 units ahead of the camera. `MapViewSwimmerPresenter` feeds it, so wading and swimming leave a V wake and an entry splash. It binds the sea material and every city water material; the moat shader reads it as normal slope, a little sheen and bubbly foam.
- Review plates: [bank](../reports/images/city/city_stream_bank.png) (murky water to the waterline, reed and cattail fringe), [wake](../reports/images/city/city_stream_wake.png) (ripple rings behind a wader).
- **Depth.** `stream_depth()` grades the bed from 0.9 m margins to a 1.05 m thalweg in ordinary reaches. Three compact, smooth pools deepen its centre: 2.0 m targets 18 m downstream of the Viru and Tartu road crossings (outside their decks), and a 1.8 m target on the approach to the lower bend, 16 m upstream of its vertex. The committed 2 m height grid gives swim-capable columns of roughly 1.7-2.0 m, with shallow exit margins. Pool profiles use deterministic distance along the existing trace, no RNG. Bed lowering happens after land-use placement so underwater slope changes do not rename fields or pastures. Water levels, banks, crossings and stable plan IDs are unchanged.
- **Playing and persistence.** Walk into a pool using the usual keyboard/mouse or gamepad movement: `CityMapView.water_depth_at()` feeds the existing `PlayerSwimState` (enter at 1.25 m, exit below 1.05 m); no new button or control mapping. The unchanged swimmer presenter floats and strokes the rig. No new save fields, flags or content IDs: reload continues to derive the medium from position and depth. Pool labels `pool.viru`, `pool.tartu`, `pool.lower_bend` are generator-local profile names, not saved entities.
- **Historical limits.** Scoured bend/bridge pools and a mill-pond-like deep reach are a **plausible composite**, not measured or attested 1343 bathymetry; no dam, named mill or pond site is added. See [canon confidence](../CANON.md). The lower pool stays upstream of the sea-datum boundary because the current runtime water query prioritises sea level wherever ground is below zero.
- **Pool proof.** [Kalev swimming below Viru](../reports/images/city/city_stream_pool_swim.png). The capture runs the real player water-depth provider and swimmer presenter through 120 controlled traversal frames, requiring `SWIM` on every frame, rather than forcing an enum or posing a mesh. This is not an end-to-end input or save/load capture. The current shared GL capture emits a particles-shader cleanup diagnostic at shutdown after writing the plate; no script/shader compilation error occurs during the pool traversal.

## Verify

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_city_shore
tools/godot_render.sh --script tools/capture_city_sea.gd -- --only=sea_storm_wide,sea_calm_beach_close,fish
tools/godot_render.sh --script tools/capture_city_stream.gd -- --tag=x   # build/stream/{bank_up,bank_low,bank_mouth,top,wake,pool_swim}_x.png
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_city_plan,test_city_stream
python3 -m unittest tests.python.test_build_reval_city_plan -v
python3 tools/city/build_reval_city_plan.py --check
```

## Perspective sea visibility (R-1437)

The FFT surface keeps discrete cloud-cell shadows but does not include the extra
continuous-deck sampler: that helper made the FFT sea disappear on macOS GL
Compatibility, even with no shader error in the capture log. Lightweight stream,
moat and horizon water retain their deck shadows. City sea meshes opt into
`sea_physical_depth` and use the existing vertex-sampled bathymetry as a minimum
optical column, independent of screen-depth failures. District meshes default off.
Shared material weather updates remain intact; the switch is mesh-instance state.
No input, stable content IDs or save format changes.

Verification: `tools/godot_render.sh --script tools/capture_city_sea.gd -- --tag=restored
--only=sea_calm_wide,sea_calm_shore,sea_storm_shore` (put both arguments on one line).
Run `tools/run_godot_tests.gd` with `--filter=test_cloud_cells,test_city_stream`.

## Limits

- The sea shader hides anything below about a metre of water, so fish only show in the shallows and boulders and weed deeper down are felt as colour, not seen. Fish were not seen in a plate; treat them as unverified until someone looks.
- Storm swell is 5 times the district value; boats were not re-tuned for it, so a gale may bury a small boat's gunwale.
- Boarding a cog drops Kalev onto the deck (`CogModel.walk_height`) with no climb animation.
- The ground shader's seabed layers are cheap noise, not authored plates.
- The moat still takes its water column from the depth texture; check it in perspective plates for the same clear-water fault.
- The ripple window follows the camera, so in the top-down overview a wake far from the screen centre is not drawn.
