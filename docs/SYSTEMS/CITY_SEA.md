# City sea, shore and harbour life

Status: implemented (tasks **R-885**, **R-1437**, **R-1440**; city integration follow-up, 2026-10-09; ADR 0031). Scope: the Baltic off Reval and its shore in the seamless city: the sea surface and storm swell, seabed and beach relief, shore dressing, boardable boats and the working craft of the two shores; the Hareapea stream and moat water, their water plants and the wake Kalev leaves in any city water. Out of scope: swimming mechanics (ADR 0021), shipping routes, fishing as gameplay. Harbour layout and sources: [`FARMLAND.md`](./FARMLAND.md#harbour-and-kalamaja).

## What the player sees

- **Sea.** The same FFT ocean as the district maps (`MapViewMaterials.water_surface(TERRAIN_SHALLOW_WATER)`): baked waves, whitecaps and foam, shore swash, caustics, refraction and sun glint, driven by the sky weather (`apply_sea_weather` is called from `CityWorld3D.apply_time`). The open sea is 1 m per unit, so `SEA_WAVE_BOOST` (5.0, `CityWorld3D`) scales displaced crest height: a calm sea moves a few centimetres, a gale lifts crests to about 1.7 m and boats and swimmers ride it (`WATER_MATERIALS.set_wave_height_boost`, mirrored in the CPU hull sampler).
- **Seabed.** The generator (`build_reval_city_plan.py`) shapes the bed with shore-parallel sandbars and troughs, undulation and boulder fields, so depth varies instead of one tilted plane. Beaches get berms and runnels near the water and drift-sand hummocks.
- **Ground shader** (`city_ground.gdshader`): two sands, a dark wet strand, shingle just above the swash, and below the waterline weed, mottled natural bedrock and ripple-marked sand. Land paving is suppressed below sea level; the shared masonry plate is not used for submerged rock.
- **Shore dressing** (`CityShore`): granite erratics clustered in the shallows (with weed skirts), stone clusters, shingle lenses and wrack lines, reusing the district maps' CO-02 meshes. Deterministic from the plan heightfield.
- **Boats.** `CityBoats` builds lofted clinker hulls: fishing clinker boat, skiff, flat-bottomed cargo lighter and the boat turned over on trestles. Cogs are `CogModel` ([`SHIPS.md`](./SHIPS.md)). **Cogs, boats and lighters at anchor or beached can be boarded**: Kalev swims alongside and steps onto the hull (`CityShips.deck_height_at`, hooked into `CityPlan.walk_height` through `dynamic_deck`). The sailing cog under way cannot be boarded.
- **Crane and shore furniture** (`CityHarbour`): a Hanseatic treadwheel crane (timber tower, spoked tread drum, jib with rope and hook) at the merchant landing, cargo stacks, net yards with pole racks.
- **Fish** (`CityFish`): deterministic shoals of herring and perch circle in the clear shallows near Kalev. Each school uses one `MultiMesh`, with a tapered body, forked tail and fins; `city_fish.gdshader` animates the tail from the shared ocean clock. Full body and fin bounds stay above the sampled bed and below the mean surface. Seven schools at most, with 11 herring or 5 perch each; school centres and seeds are unchanged.

## Stream, moat and wake

Status: implemented (task **R-1440**, deterministic swim pools and generator vegetation exclusion).

- **Hareapea stream** (`CityWorld3D._build_water`, `_stream_mesh`): a mitred grid ribbon (1.5 m cells) along the plan trace. Its width is measured per trace point out to where the carved bank climbs above the surface (`_stream_wet_halves`, plus `STREAM_BANK_OVERLAP` 1.5 m that the terrain hides), so the water meets the bank at the waterline instead of ending in a step over a dry pit. It uses the moat's murky shader (`city_moat_water.gdshader`) in a peat-brown tint (`_stream_material`): colour deepens with the water column and the edge fades into mud; ripples run downstream along the ribbon UV. The column comes from the vertices (depth over the plan ground baked into `COLOR.r`), not the depth texture, which read about zero in perspective under GL Compatibility and left the stream fully clear.
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
`sea_physical_depth` and use signed terrain height in vertex `UV2.y` as a minimum
optical column, independent of screen-depth failures. District meshes default off.
Shared material weather updates remain intact; the switch is mesh-instance state.
No input, stable content IDs or save format changes.

Verification: `tools/godot_render.sh --script tools/capture_city_sea.gd -- --tag=restored
--only=sea_calm_wide,sea_calm_shore,sea_storm_shore` (put both arguments on one line).
Run `tools/run_godot_tests.gd` with `--filter=test_cloud_cells,test_city_stream`.

## Surf, run-up and spray (shore field)

Status: implemented (city follow-up to **R-885**, WS-08).

The sea shader draws all surf (breaker foam, wave crest, run-up film, quay slosh) analytically from a per-map shore distance field. The city bound none, so its sea met the land as a hard cut with no foam. The district defaults also make a breaker only about 0.25 m tall and 2 m wide, which does not read on a metre-per-unit sea. What the city does now:

- **Shore field** (`CityShoreField.bake`, `scripts/city/city_shore_field.gd`): marching squares on plan ground height 0, then nearest-contour distance, landward direction and a beach flag (contour slope under 0.42 m per unit is beach, above 0.75 is quay, rock or bluff). Distances are divided by `DISTANCE_SCALE` (3), so the shader's 8-unit surf zone spans 24 world units; `shore_depth_scale` carries the same factor into the shader. Bake time is about 0.5 s.
- **Continuous surf and run-up** (`CityShoreField.build_band`): the 4 m coarse sea grid joins an indexed 0.5 m mesh in 128 m tiles, extending about 22.5 m offshore and 10.5 m inland. Both use one coarse-cell ownership predicate (`covers_coarse_cell`), preventing overlapping transparent triangles. Coarse boundary cells subdivide their shared edge at 0.5 m intervals and fan triangles to the centre, so their displaced edges meet the fine mesh without cracks. The inland extension belongs to this same surface: the separate city `ShoreSwashSheet` and its mesh builder have been removed.
- **Raised advancing front:** signed terrain height in `UV2.y`, with fine triangles matching the terrain's parent diagonal, carries the sea up the sand. Horizontal chop fades before the bank; the front gains 0.10–0.42 m of wind-dependent roller height plus the thinning water layer. Its shading normal follows that rise, using an interpolated bed gradient so reflections do not expose the terrain triangle diagonals. All potential run-up vertices retain a floor 1.8 cm above the encoded bed, including dry corners of triangles that cross the moving front; partial beach weights cannot sink wet triangles into the sand. Actual bed height controls permanent sea coverage; filtered shore distance controls only the advancing inland edge. Disagreement between the two zero contours can no longer expose a dry strip between meshes. Foam uses one multiscale patch pattern on the sea, breaking crest and run-up, with denser foam at the front and a fading trail. Existing tile channels provide metre-scale clumps, irregular lace and centimetre-scale grain; large circular rims are no longer the main close-camera pattern. The common foam mask suppresses mirror reflection and specular light and raises roughness. The shader displacement has a 6 m culling margin.
- **Surf strength** (`CityWorld3D.SURF_*`, applied through `MapViewMaterials.apply_surf_gain`): breaker height gain 2.0, run-up gain 1.8, crest geometry scale 1.3 (district 0.12), foam gain 2.2, depth scale 3. `apply_shore_field` resets all of them for district maps. The sea state, so the wind, scales the energy: a calm day laps, a fresh wind rolls breakers in with white crests, a gale floods the beach.
- **Spray** (`CityShoreSpray`, `scripts/city/city_shore_spray.gd`): 10 GPU particle emitters keep to the waterline nearest the camera, 5 units offshore, throwing droplets up and landward. Wind 0.35 starts them, 0.9 is full strength (`CityWorld3D.apply_time` feeds `set_wind`).

Earlier side-on review plates (`tools/capture_city_sea.gd`, before the continuous-surface correction below):

![Calm: swash film with a foam bead on wet sand](../reports/images/city/city_surf_calm_swash.png)

![Fresh wind: breakers with white crests rolling in and the run-up film](../reports/images/city/city_surf_fresh.png)

![Gale: tall foamy surf, flooded beach and spray droplets in the air](../reports/images/city/city_surf_storm_spray.png)

Verify: `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_city_shore_field`; plates `tools/godot_render.sh --script tools/capture_city_sea.gd -- --tag=x --advance=6 --only=surf_side_calm,surf_side_fresh,surf_side_storm` (`--advance` shifts the wave phase; `surf_*` are the front plates).

Limits: the crest is a displaced mesh with foam, not a curling wave with a hollow face; steep silhouettes can still reveal the 0.5 m mesh. Inland run-up is visual: the existing camera medium and swim-depth queries still classify coastal positions by the mean waterline (`bed < 0`), so they do not classify a camera inside the thin inland bore as underwater. The ground shader has no wet-sand band tied to the field; spray droplets are soft billboards without a splash sprite; quays and rocks get slosh foam only (no climbing water).

## Optical and camera integration (R-885 / R-1437 follow-up)

The 2026-10-09 pass follows the existing [water/sky contracts](../tasks/water_sky/README.md): WS-01 transmission, WS-06/08 foam and shore, WS-11 lighting, WS-13 underwater and WS-15 ripples, plus CO-08 water life. The recorded [R-885 acceptance packet](../reports/r885_water_sky_pack_acceptance.md) identifies R-887/R-1150 and R-896/R-940 reviews, underwater follow-ups R-934/R-1031/R-1068/R-1087, and R-910 swimming. This does **not** close those gates or assert current board status; the live task-board tool was unavailable during this pass. No new tasks were created.

- **Transmission:** city sea uses metre-scale Beer–Lambert extinction (`physical_extinction`, RGB 0.40/0.24/0.30 per metre), multiplied by weather turbidity. Actual bed geometry replaces the synthetic floor. Fresnel controls the reflected share rather than a fixed reflection floor. In GL the city alpha path exposes opaque submerged geometry and reads its optical column only from bathymetry, skipping unreliable screen-depth/refraction reads; the opaque underwater face uses the sky LUT for its Snell window. Existing district material profiles retain their optical scale.
- **Wind, rain and flow:** `water_capillary.gdshaderinc` supplies two derivative-filtered waves from the shared wind direction, strength and ocean clock, without extra textures. City ground puddles, district puddle decals and stream/moat use it. Rain rings use current precipitation, not retained ground wetness. Stream and moat read baked bathymetry directly without a depth-buffer sampler/copy. Stream current follows the ribbon tangent and world-distance UV; shallow foam travels downstream, while still moat water only responds to wind and local wakes.
- **Camera:** `CityMapView` now creates and updates `UnderwaterPass`. `CityWorld3D.water_medium_at()` returns the actual sea, elevated stream or moat surface and rejects dry overlap at the banks. `CityWaterSurface` samples FFT, tide, shore shelter, analytic crest/slosh and the near-bank raised surface on the CPU using the retained shore field. The near-plane pass receives the local surface and one metre per world unit, with hysteresis at entry/exit. City surface triangles use their consistently authored face orientation for the underwater-face shader; a crest above a low camera must not turn into a false underwater strip. The underwater sea uses the same `physical_extinction × water_turbidity` as its top surface. Stream and moat use distinct, stronger humic profiles (blue attenuates fastest); all media take current day/night lighting from the shared sky-driven water material, even before the camera visits the sea.
- **Shore foam continuity:** surf phase and run-up variation use continuous world-space noise, shared with the CPU height probe. Projecting absolute city coordinates onto a changing shoreline tangent produced phase islands and white wedges at bends; that projection is removed. Bore foam forms over 0.18 seconds, then decays behind the front. City surf reuses the existing foam tile for bubble holes, with less entrained air in calm water than a gale; its downwind texture drift wraps by a whole number of tiles with the ocean clock. No new texture or simulation buffer.
- **Air bubbles:** entering the underwater state emits at most 24 small lit bubbles for 2.4 seconds. A single `MultiMesh` rises from the entry position, removes bubbles at the surface and becomes hidden when the burst ends or the camera exits. The underwater pass also hides completely once the existing wet-lens effect dries.
- **Cost and state:** no new per-frame textures, GPU readback, physics bodies, saved fields, content IDs or controls. Fish and bubbles have fixed budgets. The CPU shore field is retained once per city; fine surf generation visits only owned shoreline cells. Weather/save restoration continues through the existing R-715 environment envelope. Keyboard and gamepad still use the existing swim controls; this pass adds no new binding.

Water-body clarity is an authored optical profile, not a universal "Estonian water" setting. Sea transmission fades over metres; the stream's brown profile attenuates faster than the green moat, while puddles retain their visible ground. Wind/rain raise the sea turbidity. [HELCOM's water-transparency assessment](https://indicators.helcom.fi/indicator/water-transparency/) supports differentiating basins and the effect of coloured dissolved organic matter; its modern monitoring is a visual reference, **not** evidence for medieval Reval or a calibration of these shader coefficients. No lakes, algal-bloom simulation or seasonal water-quality model are introduced.

The camera sample is an approximation: it does not invert the shore crest's horizontal curl or reproduce every interpolated GPU triangle/local wake. It substantially improves coastal entry classification, but does not claim exact CPU/GPU surface parity. Fish containment uses mean sea level; waves can temporarily uncover the very shallowest school edges. Caustics remain on the existing screen-refraction path; the GL transparency fallback does not project them onto the real bed.

### Reproduce and inspect

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_city_water_realism,test_city_shore_field,test_city_stream,test_shore_distance_field,test_r715_water_material_contract,test_r715_water_weather_sync,test_sea_state_ladder,test_r715_water_save_envelope,test_r715_water_surface_geometry
tools/godot_render.sh --script tools/capture_city_sea.gd -- --tag=review --only=fish,fish_under,fish_straddle,fish_under_up,fish_night,stream,sea_calm_wide,surf_side_storm --bench=180 --motion=96
tools/godot_render.sh --script tools/capture_city_sea.gd -- --tag=minimum --tier=minimum --only=fish,fish_under,stream,sea_calm_wide
tools/godot_render.sh --rendering-method mobile --rendering-driver metal --script tools/capture_city_sea.gd -- --tag=metal --only=fish,fish_under,stream
```

The capture uses the real `CityMapView` camera/underwater integration. `--advance=N` offsets the wave phase; `--motion=N` writes N frames at a fixed 24 Hz simulation step. For recording only, a shader copy replaces the water material's secondary `TIME` inputs with the stepped ocean clock; slow PNG readback must not accelerate the fine ripples/foam in the resulting video. Runtime shader files are unchanged by this override. `--bench=N` measures N frames after warm-up with VSync disabled and without screenshot readback inside the timing loop, writing mean/p95 milliseconds and draw calls to `build/city_sea/benchmark_<tag>.json`. This is **whole-scene frame time**, not isolated GPU water time. `--baseline` loads the locally preserved pre-edit sea shader from `build/scratch/water_before/`; it compares that shader only, with current geometry, fish and city systems, and fails if the snapshot is absent. Benchmark both variants serially without another GPU capture running. `--hide-water` is a diagnostic control: hide the city Water subtree (including water plants) to measure the remaining scene, retaining the same camera and other systems. It is not a gameplay quality preset. `--shader=res://…` loads a diagnostic sea shader without replacing the runtime source. `sea_morning`, `sea_evening`, `sea_night`, `sea_windy`, `sea_rain`, `sea_gale` pin actual sky presets; morning/evening use the calendar's sunrise/sunset ±36 minutes. Sky weather is held during each pose, and the log records sun elevation, wind and rain. The game's storm preset represents local thunderclouds with possible clear sky between cells; the rain preset is the overcast front.

The focused tests cover dry-bank rejection, elevated water, underwater state transitions, night lighting on first stream entry, bubble lifetime, full fish body/fin bounds, rain cessation, shared wind, continuous crest phase at shore bends, exclusive mesh ownership and stitched edge vertices. Shore regressions also check matching terrain triangles, the full inland run-up extent, raised moving fronts/backwash, and uninterrupted wet-bed coverage when the shore-field zero disagrees with the real terrain. They do not replace manual swim/input or gameplay save/reload acceptance.

### Captured evidence and performance (2026-10-09)

Generated review media and JSON are local output, intentionally ignored by Git under the storage policy. This session keeps them in `docs/reports/images/water_realism_20261009/`; raw repeatable captures are in `build/city_sea/`. Filenames below refer to that review directory. Reproduce the raw scenes with the commands above.

Prior sea shader (`before.jpg`), clear shallows and fish (`shallows.jpg`), underwater and bubbles (`underwater.jpg`), night (`night.jpg`), stream (`stream.jpg`), storm (`storm.jpg`), Metal refraction (`metal_shallows.jpg`), and surf motion at 24 fps (`surf_calm_motion.mp4`, six seconds; `surf_motion.mp4`, three seconds). Motion clips: fish (`fish_motion.mp4`), stream current (`stream_motion.mp4`), puddle wind (`puddle_wind_motion.mp4`), rain on puddles (`puddle_rain_motion.mp4`). Puddle land views: rain (`puddle_rain.jpg`), calm (`puddle_calm.jpg`), wind (`puddle_wind.jpg`). The weather/time comparison (`sea_conditions.jpg`) shows sunrise, cloud/wind, rain, evening, night and a gale from one camera; it precedes only the final textured shore-foam refinement. Final calm/storm surf clips and fish motion include that refinement.

Measured on Apple M5 Pro, Godot 4.7.1, GL Compatibility, 1600×900, recommended tier, 240 frames per pose after warm-up. Recorded frame times and control runs (`frame_times.json`):

| Scene | Mean frame time | p95 | Mean FPS equivalent |
|---|---:|---:|---:|
| Clear shallows / fish | 19.69 ms | 35.61 ms | 50.8 |
| Underwater | 15.11 ms | 28.13 ms | 66.2 |
| Camera at waterline | 18.50 ms | 35.60 ms | 54.0 |
| Open harbour view | 12.22 ms | 19.90 ms | 81.8 |
| Storm surf | 16.10 ms | 19.03 ms | 62.1 |
| Stream, including the surrounding city | 69.37 ms | 73.97 ms | 14.4 |

These are whole-scene samples, not a stable 60 FPS guarantee. The prior-sea-shader control measured 25.61 ms at the fish and 18.38 ms at the open harbour, with the same current geometry; it does not establish a whole-project speedup. Minimum tier still measured 66.84 ms at the stream, so lowering water quality alone does not meet the frame budget there. GPU captures on GL and Mobile/Metal produced no in-frame shader compilation errors; both retain the pre-existing particles-shader cleanup diagnostic at process exit.


The final 180-frame surf checks measured 13.86 ms mean / 20.21 ms p95 in calm water and 17.78 / 30.03 ms in storm surf. The weather/time matrix measured 14.00–26.15 ms mean per scene (sun elevations about +4.1° for morning/evening and −13.9° at night). These shorter runs include the shoreline-phase correction and sea clarity profile; the matrix precedes the final foam-texture refinement. One final capture also encountered a transient, unrelated `UserSettingsStore.load_graphics_settings` startup error in the shared checkout; the explicit capture tier was still applied.

Initial optical-pass focused gate: **green**, 9 files / 63 tests / zero failures / zero captured errors (`build/city_sea/focused_tests.log`). A second read-only reviewer confirmed mesh stitching, bounded fish/bubble costs, lighting, scope and the documented limitations. The subsequent foam clock-wrap correction also passed the 16-test material contract (`build/city_sea/wrap_contract.log`) and a GL surf capture. The shoreline follow-up below adds another regression.

After removing the stream's unused depth-buffer read, a separate 360-frame control measured **55.88 ms without the Water subtree versus 57.29 ms with it** (p95 74.80 / 83.83 ms). That pair includes water plants and shows a 1.41 ms mean difference; host/frame variation prevents treating it as an exact GPU cost. The scene remains about 17 FPS even with water hidden, so this pass cannot claim a smooth whole-city frame budget.

Full workspace gate at the initial optical pass: **not green** — 382 loaded files, 2,257 tests, 369 failed assertions and 1,172 captured errors (failure groups (`suite_summary.json`); raw log `build/city_sea/full_suite.log`). Failures include inactive map-transition destinations, missing house production evidence, vegetation checks and world traversal. The two R-715 rollout/inventory failures also concern maps rejected by the current transition registry. The changed city-water tests pass within that run. The shared checkout contains other in-progress changes, so this is not a clean regression baseline and does not close the pack-wide acceptance gate. `docs_index.py --check`, GDScript lint for changed water scripts, and `git diff --check` pass. The active-docs report recorded 150 workspace link/anchor issues at that point; the later shoreline verification regenerated it against the updated shared checkout with zero documentation issues.

### Low-camera shoreline regression (2026-10-09)

The reported screenshot exposed a gap between the sea and the independent terrain sheet, which the earlier coarse/fine sea-grid test did not exercise. The continuous surface described above removes that second owner and adds signed-bed and full-run-up coverage checks. City coarse and fine meshes also have a tested clockwise top face and identical bed values at shared edge vertices; only the city opts into face-based underwater shading. District sheet meshes and their minimum-tier rule remain unchanged. The city retains its joined surface on every tier.

Reproduce the low-angle views and a nine-second wave cycle:

```bash
tools/godot_render.sh --script tools/capture_city_sea.gd -- --tag=join --advance=4 --only=shore_reverse_fresh --motion=216 --bench=180
tools/godot_render.sh --script tools/capture_city_sea.gd -- --tag=conditions --advance=4 --only=shore_join_calm,shore_reverse_storm,fish_under,fish_under_up --bench=180
tools/godot_render.sh --script tools/capture_city_sea.gd -- --tag=minimum --tier=minimum --advance=4 --only=shore_join_fresh
```

Local ignored evidence is in `docs/reports/images/water_shore_join_20261009/`: `shore_cycle.mp4` (216 frames at 24 fps), `raised_front.png`, `shore_before.png`, `shore_join.png`, `calm.png`, `storm.png`, `underwater.png`, test/capture logs and `frame_times.json`. The static `shore_join.png` precedes only the city face-orientation refinement; the complete reverse-view movie includes it. GL calm/fresh/storm and underwater shots, plus Mobile/Metal fresh/storm shots, compile and render without in-frame shader errors. A diagnostic face-colour render confirmed consistent top faces; it encountered an unrelated transient sky-shader edit in the shared checkout and is not acceptance evidence for lighting. Final water regression: **9 files / 64 tests / zero failures / zero errors**. That review missed a separate numerical failure: later user screenshots and GPU diagnostics exposed dark polygons from a non-finite wave profile. This historical capture is superseded by the close-camera regression below; it is not acceptance evidence for the final appearance.

Whole-scene GL measurements at 1600×900, recommended tier, Apple M5 Pro, 180 frames after warm-up: calm shoreline **18.96 ms mean / 33.34 ms p95**, fresh wind reverse view **23.90 / 37.92 ms**, storm reverse view **25.40 / 43.01 ms**. An earlier same-direction forward view measured **21.38 ms before / 24.32 ms after** the geometry change (p95 31.40 / 36.83 ms); these short samples in a concurrently edited checkout do not isolate GPU water cost or establish a speedup. There are no added rendering passes, textures or per-frame mesh rebuilds; the removed city sheet saves its separate draw, while the joined mesh extends farther inland. These results do **not** meet a stable 60 FPS budget.

### Close-camera foam and non-finite surface regression (2026-10-09)

The sharp sea/shore bands were not just a foam-density mismatch. GLES evaluation of `cos(PI)` could undershoot −1 by one ulp; the fractional power of `0.5 + 0.5*cos(phase)` then yielded NaN in the shared shore height and subsequently the shading normal. GPU diagnostic plates showed invalid values exactly over the reported dark bands. `shore_swash.gdshaderinc` now clamps the power base to a positive epsilon; squared Gaussian coordinates use multiplication. The CPU shore-height mirror keeps the same bound.

Exact-zero height nodes retain a landward field direction from the local terrain gradient; their formerly zero direction grew small invalid shore islands under texture filtering. A separate sharp colour boundary came from the sediment tint stepping at the mean waterline. City sediment now continues across that contour and scales with absorbed light, so a thin run-up cannot scatter like a deep bore.

The city surface also smooths the ocean/run-up join and preserves the terrain floor at mixed beach weights. Its 0.5 m mesh is indexed: approximately four unique vertices per square metre replace six unindexed vertices on the old 1 m grid. This bounds repeated vertex-shader work, but increases triangle count fourfold and adds one-time mesh indexing/bed-normal baking; it is not a blanket performance improvement. No extra render pass, sampler, production texture or per-frame mesh rebuild is added. Three samples of the existing foam tile replace the previous two whitecap samples plus one bore sample. The GL city alpha path explicitly skips synthetic-bed and caustic evaluations whose result would be discarded; Metal and district transmission retain them.

`tools/capture_city_sea.gd` adds `close_…` views on an open strand and `sea_level_calm/fresh/storm` views at swimmer-eye height. `--validate-surface=N` samples N phases of a full wave period after timing/capture. The default-off `debug_surface_validity` shader mode marks finite water green and invalid vertices/normals/colours magenta; only in this diagnostic are invalid vertices restored so they cannot silently disappear before fragment checks. The capture fails on any magenta samples or insufficient green coverage in any phase, writes `validity_<tag>.json`, and saves a diagnostic plate. Pixel readback is outside the benchmark and absent in gameplay. An intentionally unguarded scratch shader is the negative control.

```bash
tools/godot_render.sh --script tools/capture_city_sea.gd -- --tag=close --advance=4 --only=close_shore_reverse_fresh,sea_level_storm --validate-surface=12 --motion=216 --bench=240
tools/godot_render.sh --rendering-method mobile --rendering-driver metal --script tools/capture_city_sea.gd -- --tag=close_metal --advance=4 --only=close_shore_reverse_fresh,sea_level_storm --validate-surface=12
```

The exact-zero regression in `test_city_shore_field.gd` checks interpolated directions and beach type across a synthetic zero-height contour. Its mixed-beach floor regression sweeps wave phases, partial beach flags and terrain heights, including dry vertices needed by front-straddling triangles. Geometry tests still require matching terrain triangles, exclusive ownership and stitched bed values. This pass changes presentation only: controls, persistent state and stable content IDs are unchanged. The earlier full-workspace gate limitations still apply.

Local ignored evidence is in `docs/reports/images/water_close_20261009/`: `before.png`, `close_shore.png`, `sea_level_storm.png`, `shore_cycle.mp4`, `sea_level_storm.mp4`, phase contact sheets, renderer/weather plates and validity/performance JSON. Production GL/Metal and calm/morning/rain/night checks found no invalid water values across 72 sampled phases. The negative control, reverting only the positive power-base guard in a scratch shader, found 416,050 invalid sampled pixels over four phases and exited with failure. Independent review accepted the removal of the reported dark bands, dry island and contour seam; Metal still shows stronger specular highlights and small refraction facets, so this is not renderer parity or a claim of perfect realism. The focused water suite passed **9 files / 66 tests / zero failures / zero errors**. Captures retain the known particles-shader cleanup diagnostic at process exit; it is not an in-frame shader compile failure.

A 240-frame GL run at 1600×900/recommended tier measured **35.54 ms mean / 53.07 ms p95** at storm swimmer height and **36.27 / 53.80 ms** along the close shore. Matching Water-hidden controls measured **32.03 / 50.14 ms** and **33.09 / 54.04 ms**. The roughly 3.2–3.5 ms mean difference includes the whole Water subtree and host/frame variation; it is not a precise isolated GPU shader cost. The city remains above a 16.7 ms frame budget without water. These samples precede only the explicit discarded-bed-work guard and the capture-only secondary clock fix; no stable 60 FPS claim is made.

The final guard passed the 16-test material contract and a further six-phase GL validity check. The synchronized GL recordings added twelve valid phases; a minimum-tier Mobile/Metal run added six, with no invalid samples or in-frame shader errors. Its shorter 120-frame GL shoreline sample measured **46.78 ms mean / 68.18 ms p95** (`frame_times_final_gl_static.json`); it does not demonstrate a speedup. The guard avoids logically unused work, but varying whole-scene timings cannot establish its GPU benefit. The two final nine-second clips use the synchronized recording clock described above. Their phase sheets retain a connected surface throughout; steep crests can still reveal the mesh and storm foam can appear overly dense.


## Water realism v2 (WR-1, WR-2)

Status: implemented (tasks **R-1499** WR-1 and **R-1500** WR-2; pack [WR - Water realism v2](../tasks/water_sky/WR_water_realism_v2.md), epic **R-1497**). Scope: the city sea's wave geometry and foam. Out of scope (planned in the pack): camera-distance LOD and tier presets (WR-3), depth refraction and breaker types (WR-4), wave interaction with rocks (WR-5), event-driven spray (WR-6), a persistent foam buffer (WR-7), gusts and rain on the sea (WR-8), beach wetting (WR-9). District maps are unchanged: every switch below is gated on the city's `sea_physical_depth` instance flag or on `shore_crest_shape`, which `apply_shore_field` resets to 0.

Verified on the [water sandbox](./WATER_SANDBOX.md) (synthetic coast, R-1498) and in the city.

**Wave geometry (WR-1).**

- **Real troughs.** The district guard `FFT_TROUGH_FLOOR` clamps every trough to 1.5 mm below rest, because district beds sit centimetres down. The city has metres of water, but used the same clamp, so its sea was crests over a flat plane with a kink at the clamp: the sharp ridges players saw. The city path now uses `_fft_bed_trough` (`ocean_fft_common.gdshaderinc`): troughs keep their full depth and only ease, with a 0.08 m polynomial smooth max, onto the actual bed plus `CITY_TROUGH_CLEARANCE` (0.05 m).
- **Band-limited displacement.** Cascade C1 (4-16 m waves) no longer displaces the city's 4 m open-sea grid (`CITY_C1_GEOMETRY` 0, `_fft_displacement_foam_with_c1`): below Nyquist it drew triangular spikes. C1 and C2 stay in the per-pixel normal, so the small waves still shade. Both city meshes (coarse grid and 0.5 m surf band) use the same rule, so their shared edges still meet. C1 returns to the geometry near the camera with the LOD rings of WR-3.
- **Rounded spilling crest.** `shore_crest_shape` (city 1.0, `CityWorld3D.SURF_CREST_SHAPE`) widens the breaker by 30 %, softens the skew (shoreward face 0.65 instead of 0.4 of the width), lowers the peaking exponent from 1+2s to 1+0.8s and keeps 30 % of the curl that pushed the crest over its own face into a lip.
- **CPU parity.** `CityWaterSurface.sea_height` (camera medium, swimmers) uses the same no-C1 displacement (`OceanFftSampler.height_at(..., c1_geometry)`), `OceanFftSampler.bed_trough` and the crest shape.

**Foam attached to the water (WR-2).**

- **No conveyor.** The former `_city_foam_pattern` scrolled all layers downwind at a fixed speed, independent of the water, and read as a foam sheet sliding over the sea. `_city_foam_cells` has no clock term: it is sampled at the rest (Lagrangian) position, which the FFT vertex displacement carries with the surface, so foam rides its crest. Structure: warped value-noise patches (metres, decimetres) carry the shape and the foam tile's bubble cells and grain add detail. The domain warp keeps the tile's round Worley rims from showing as rings.
- **Surf foam moves with the swash.** `shore_state` exports `surge`: the shallow-water excursion of water under a broken wave (about H/2 sqrt(g/h) T / 2 pi, capped at 4 m), with a quick landward lunge as the bore passes and a slow return. The surf samples its foam at the rest position minus that surge, so foam surges in and out with every breaker. On the run-up sheet the coordinate follows the swash front instead, carrying foam up the sand and back with the backwash.
- **Foam ages into lace.** `_foam_dissolve` keeps only the brightest part of the structure as coverage falls, so dying foam shrinks to rims and holes instead of fading as a sheet. Its edge widens with `fwidth`, so distant and grazing foam averages instead of producing moire. Surf coverage follows the bore's age (`shore_state.foam_age`): a dense roller about 0.35 s behind the front, lace that decays over `CITY_SURF_FOAM_LIFE` (4 s), and a 12 % patchy scum over the surf zone between sets. Quays and rocks keep their slosh foam. The run-up film is a narrow bead at its leading edge plus sparse lace, no longer a white blanket. The scrolling edge ribbons (`edge_foam`) are off on the city sea.
- **Whitecap coverage.** Only the part of the baked fold mask above `CITY_WHITECAP_THRESHOLD` (0.5) breaks, dissolved at gain 0.6. In the sandbox, the open sea shows isolated caps in a fresh breeze and large foam fields with dark water between them in a gale, the Beaufort 3-4 versus 8-9 progression. Wind streaks keep 35 % of the tile's streak channel and meander with the warp.
- **Interim spray.** Shore spray droplets shrank from 0.45 m to 0.11 m quads (twice as many) and are lit (`SHADING_MODE_PER_VERTEX`) instead of unshaded, so they no longer look like floating cotton balls or glow at night. Event-driven spray is WR-6.

![Before and after, fresh breeze along the strand: a white foam skin becomes clear water with attached lace](../reports/images/city/water_v2_close_shore_reverse_fresh.jpg)

![Before and after, storm surf at the merchant landing: rectified ridges and saturated foam become a rolling breaker with a foam band](../reports/images/city/water_v2_surf_side_storm.jpg)

![Before and after, storm at swimmer height](../reports/images/city/water_v2_sea_level_storm.jpg)

![Sandbox, one second apart: the run-up front and its foam bead advance and retreat with the swash](../reports/images/city/water_v2_swash_motion.jpg)

![Sandbox, stack / open sea / quay / sand at fresh and gale](../reports/images/city/water_v2_sandbox_open_gale.jpg)

![Sandbox light matrix (reef, stack, quay): noon, sunset, night, overcast at fresh and gale](../reports/images/city/water_v2_sandbox_matrix.jpg)

All plates show the final version except the motion strip, captured before the foam-structure warp. A GPU validity pass on the three city shots (`--validate-surface=12`) found no invalid (NaN/Inf) samples in 36 sampled phases.

Verify:

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_water_realism_v2,test_city_water_realism,test_city_shore_field,test_r715_water_material_contract,test_city_shore,test_shore_distance_field,test_r715_water_surface_geometry
tools/godot_render.sh --script tools/water_sandbox/capture.gd -- --tag=x --case=sand,reef,stack,quay --shot=close,side,open --wind=fresh,gale
tools/godot_render.sh --script tools/water_sandbox/capture.gd -- --tag=x --case=sand --shot=side --motion=144
tools/godot_render.sh --script tools/capture_city_sea.gd -- --tag=x --advance=4 --only=close_shore_reverse_fresh,sea_level_storm,surf_side_storm,sea_storm_wide
```

`test_water_realism_v2` covers the bed trough (deep troughs kept, shallow ones eased onto the bed, continuous), C1 weighting, the shader contracts (city-only band limit, bed trough, clock-free foam cells, surge and age-driven coverage), the crest-shape reset for district maps and the sandbox build. No controls, saved fields or content IDs change.

Limits: boats (`BoatFloat3D`) still sample the district trough floor, so in a city gale a hull can sit above a deep trough instead of dropping into it. Foam coverage is analytic: it has no memory between waves (WR-7). Wave height is not attenuated behind rocks or reefs below the 2 m height grid (WR-5). Gale whitecap coverage was tuned by eye in sandbox plates, not measured against photographs (WR-10). Spray is still emitted continuously at the waterline near the camera, not at breaking events.

## Limits

- GL Compatibility uses alpha transmission with scalar luminance extinction and an analytic sky window underwater. It does not provide distorted screen-space refraction, coloured transmission of individual background objects, off-screen object reflections or full depth-resolved underwater fog. Metal retains the screen-depth/refraction path. These renderer differences are deliberate and are not visual parity.
- Storm swell is 5 times the district value; boats were not re-tuned for it, so a gale may bury a small boat's gunwale.
- Boarding a cog drops Kalev onto the deck (`CogModel.walk_height`) with no climb animation.
- The ground shader's seabed layers are cheap noise, not authored plates.
- Stream and moat use baked vertex depth for their optical column on GL; they are murkier than the sea. Their small surface displacement is not included in the CPU waterline query.
- The ripple window follows the camera, so in the top-down overview a wake far from the screen centre is not drawn.
