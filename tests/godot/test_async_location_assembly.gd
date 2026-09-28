extends "res://tests/godot/test_case.gd"

## WB-07 (R-979): staged MapView3D assembly, threaded navigation bake, cancellation
## and threaded scene loading. The staged path must reproduce the synchronous view
## node for node; the threaded bake must reproduce the synchronous polygon byte for byte.

const KalevSmithyDefinition := preload(
	"res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd"
)
const LowerTownSlice := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const HarborEastDefinition := preload(
	"res://scripts/map/definitions/outdoor/reval_harbor_east_definition.gd"
)
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const Job := preload("res://scripts/map/view3d/map_view_worker_job.gd")
const TerrainStaged := preload("res://scripts/map/view3d/map_view_mesh_builder_terrain_staged.gd")
const PropModels := preload("res://scripts/map/view3d/map_view_mesh_builder_prop_models.gd")
const PUBLIC_BATH_GLB := "res://assets/props/architecture/buildings/public_bath/public_bath.glb"
const CLUTTER_KIT_GLB := "res://assets/props/domestic/household/smithy_household_clutter_kit.glb"

const BUDGET_USEC := 4000
const NAV_RUNS := 10


func _definitions() -> Array[MapDefinition]:
	return [LowerTownSlice.create(), KalevSmithyDefinition.create(), HarborEastDefinition.create()]


func test_staged_assembly_matches_synchronous_tree() -> void:
	for definition in _definitions():
		var grid: MapTerrainGrid = MapBuilder.build(definition)
		var synchronous := MapView3D.create(definition, grid)
		var staged := MapView3D.create_staged(definition, grid)
		assert_false(staged.is_assembly_complete(), "staged view must start unbuilt")
		assert_eq(staged.get_child_count(), 0, "create_staged must not build anything up front")
		_drain_staged(staged)
		assert_true(staged.is_assembly_complete(), "%s staged assembly finishes" % definition.map_id)
		var expected := _tree_signature(synchronous)
		var actual := _tree_signature(staged)
		assert_eq(actual.size(), expected.size(), "%s node count" % definition.map_id)
		var first_difference := ""
		for index in mini(actual.size(), expected.size()):
			if actual[index] != expected[index]:
				first_difference = "%s != %s" % [actual[index], expected[index]]
				break
		assert_eq(first_difference, "", "%s staged tree equals synchronous" % definition.map_id)
		assert_eq(
			staged.object_streamer().duplicate_instance_ids(),
			[],
			"%s staged assembly creates no duplicate stable handles" % definition.map_id
		)
		_free_view(synchronous)
		_free_view(staged)


## WB-07b: a step that only awaits a worker job returns at once, so drain by
## wall time and sleep briefly between steps instead of counting steps.
func _drain_staged(staged: MapView3D, timeout_msec := 180000) -> void:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while not staged.step_assembly(BUDGET_USEC):
		if Time.get_ticks_msec() > deadline:
			break
		OS.delay_usec(200)


func test_every_stage_is_timed_in_order_on_both_paths() -> void:
	var definition: MapDefinition = KalevSmithyDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var synchronous := MapView3D.create(definition, grid)
	var staged := MapView3D.create_staged(definition, grid)
	while not staged.step_assembly(BUDGET_USEC):
		pass
	for view in [synchronous, staged]:
		var timings: Dictionary = (view as MapView3D).assembly_stage_timings_usec()
		var seen: Array[StringName] = []
		for stage in timings.keys():
			seen.append(stage)
		var expected: Array[StringName] = []
		for stage in MapView3D.Assembly.STAGES:
			if timings.has(stage):
				expected.append(stage)
		assert_eq(seen, expected, "stage timings follow Assembly.STAGES order")
		for stage in [&"height_field", &"terrain_mesh", &"lighting", &"sky_weather"]:
			assert_true(timings.has(stage), "stage %s is timed" % stage)
	_free_view(synchronous)
	_free_view(staged)


## A unit is atomic, so a step may overrun by the unit that crossed the budget,
## but it must never start another unit after the budget is spent.
func test_scheduler_yields_once_the_frame_budget_is_spent() -> void:
	var definition: MapDefinition = LowerTownSlice.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var staged := MapView3D.create_staged(definition, grid)
	var total_units := staged.pending_assembly_unit_count()
	assert_true(total_units > MapView3D.Assembly.STAGES.size(), "chunks become separate units")
	var steps := 0
	var consumed := 0
	var violations: Array[String] = []
	while not staged.is_assembly_complete():
		staged.step_assembly(BUDGET_USEC)
		steps += 1
		var unit_log := staged.assembly_unit_timings()
		var step_units := unit_log.slice(consumed)
		consumed = unit_log.size()
		var before_last := 0
		for index in step_units.size() - 1:
			before_last += int(step_units[index]["usec"])
		if before_last >= BUDGET_USEC:
			violations.append("step %d ran past the budget: %d usec" % [steps, before_last])
	assert_eq(violations, [], "no unit starts after the frame budget is spent")
	assert_eq(staged.pending_assembly_unit_count(), 0, "the queue drains")
	# Chunk units expand into one unit per streamed object, so more units run
	# than were planned up front.
	assert_true(consumed > total_units, "object chunks expand into per-object units")
	assert_true(steps > 1, "lower_town_slice assembly spans more than one frame")
	_free_view(staged)


func test_zero_budget_runs_exactly_one_unit_per_step() -> void:
	var definition: MapDefinition = KalevSmithyDefinition.create()
	var staged := MapView3D.create_staged(definition, MapBuilder.build(definition))
	var pending := staged.pending_assembly_unit_count()
	staged.step_assembly(0)
	assert_eq(staged.pending_assembly_unit_count(), pending - 1)
	_free_view(staged)


func test_cancel_mid_assembly_leaks_no_nodes_or_handles() -> void:
	var definition: MapDefinition = LowerTownSlice.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var orphans_before := _orphan_ids()
	var staged := MapView3D.create_staged(definition, grid)
	# Stop inside the per-chunk building units, after the streamer exists.
	while staged.object_streamer() == null or staged.object_streamer().loaded_instance_count() == 0:
		staged.step_assembly(0)
	staged.step_assembly(0)
	var cancelled := [false]
	staged.assembly_cancelled.connect(func() -> void: cancelled[0] = true)
	staged.cancel_assembly()
	assert_true(cancelled[0], "cancel emits assembly_cancelled")
	assert_true(staged.is_assembly_cancelled())
	assert_eq(staged.pending_assembly_unit_count(), 0)
	assert_false(staged.step_assembly(BUDGET_USEC), "a cancelled view never completes")
	assert_eq(staged.object_streamer().duplicate_instance_ids(), [])
	_free_view(staged)
	assert_eq(
		_unreleased_orphans(orphans_before),
		[],
		"freeing a cancelled view releases every node it built"
	)


## WB-07b (R-1005): a height field no view has baked yet is computed on a worker
## and published by a later unit; the terrain then fans its array bakes out to the
## pool. A reseeded definition gets its own cache key, so the staged build below
## is cold. The synchronous build afterwards reads the published field, and both
## trees and every terrain surface array must match.
func test_cold_height_field_and_terrain_bake_on_workers() -> void:
	var definition: MapDefinition = HarborEastDefinition.create()
	definition.seed += 7919
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	assert_true(
		MapViewMeshBuilderTerrain.cached_height_field(definition, grid).is_empty(),
		"the reseeded field starts cold"
	)
	var staged := MapView3D.create_staged(definition, grid)
	_drain_staged(staged)
	assert_true(staged.is_assembly_complete(), "cold staged assembly finishes")
	var labels: Array[String] = []
	for unit in staged.assembly_unit_timings():
		labels.append("%s/%s" % [unit["stage"], unit["label"]])
	for expected: String in [
		"height_field/await_height_field",
		"height_field/publish_height_field",
		"terrain_mesh/await_ground_bands",
		"terrain_mesh/ground_publish",
		"terrain_mesh/await_shore_swash",
		"terrain_mesh/await_pier_cribs",
		"surroundings/await_tree_band",
	]:
		assert_true(labels.has(expected), "unit %s runs" % expected)
	assert_false(
		MapViewMeshBuilderTerrain.cached_height_field(definition, grid).is_empty(),
		"the worker-baked field is published"
	)
	var synchronous := MapView3D.create(definition, grid)
	assert_eq(_tree_signature(staged), _tree_signature(synchronous), "cold staged tree")
	assert_eq(
		_surface_hashes(staged.get_node("Terrain")),
		_surface_hashes(synchronous.get_node("Terrain")),
		"worker-baked terrain arrays equal the synchronous ones"
	)
	_free_view(synchronous)
	_free_view(staged)


## R-1024 / R-1028: harbour water rest Y must not rebuild the playable grid
## inside surroundings/backdrops, and shader parse must land in
## backdrops_water_warm so the named backdrops unit stays under 4 ms. Dummy
## warm meshes are never parented to Surroundings, so WORLD_SIDES order stays
## the tree signature.
func test_harbor_east_water_backdrops_stay_under_frame_budget() -> void:
	var definition: MapDefinition = HarborEastDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var staged := MapView3D.create_staged(definition, grid)
	_drain_staged(staged)
	assert_true(staged.is_assembly_complete(), "harbor east staged assembly finishes")
	var labels: Array[String] = []
	var overruns: Array[String] = []
	for unit in staged.assembly_unit_timings():
		if unit["stage"] != &"surroundings":
			continue
		var label := String(unit["label"])
		labels.append(label)
		if label == "backdrops" and int(unit["usec"]) > BUDGET_USEC:
			overruns.append("backdrops %d usec" % int(unit["usec"]))
	assert_true(
		labels.has("backdrops_water_warm"),
		"harbor east must warm water shaders before backdrops"
	)
	assert_true(
		labels.find("backdrops_water_warm") < labels.find("backdrops"),
		"backdrops_water_warm must run before the named backdrops unit"
	)
	assert_eq(overruns, [], "harbor east backdrops must stay under 4 ms after water shader warm")
	var surroundings := staged.find_child("Surroundings", true, false)
	assert_true(surroundings != null, "harbor east builds Surroundings")
	var water_children: Array[String] = []
	for child in surroundings.get_children():
		assert_false(
			String(child.name).begins_with("WaterWarm"),
			"shader-warm dummies must not stay under Surroundings"
		)
		if String(child.name).begins_with("Water_"):
			water_children.append(String(child.name).trim_prefix("Water_"))
	var side_order: Array[String] = []
	for side in MapDefinition.WORLD_SIDES:
		if water_children.has(String(side)):
			side_order.append(String(side))
	assert_eq(
		water_children,
		side_order,
		"water backdrop children must follow WORLD_SIDES, not shader-warm order"
	)
	_free_view(staged)


## Cancelling while worker jobs are in flight joins them: nothing is published,
## nothing leaks, and a later build still bakes the field.
func test_cancel_with_worker_jobs_in_flight_joins_them() -> void:
	var definition: MapDefinition = HarborEastDefinition.create()
	definition.seed += 104729
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var orphans_before := _orphan_ids()
	var staged := MapView3D.create_staged(definition, grid)
	staged.step_assembly(0)
	assert_eq(
		staged.assembly_unit_timings()[0]["label"], "height_field", "the bake has started"
	)
	staged.cancel_assembly()
	assert_true(staged.is_assembly_cancelled())
	assert_true(
		MapViewMeshBuilderTerrain.cached_height_field(definition, grid).is_empty(),
		"a cancelled bake is never published"
	)
	_free_view(staged)
	assert_eq(_unreleased_orphans(orphans_before), [], "a cancelled cold view leaks no nodes")
	var terrain := MapViewMeshBuilder.build_terrain(definition, grid)
	assert_true(terrain.get_node_or_null("Terrain_Ground") != null, "a later build still bakes")
	terrain.free()


func test_threaded_nav_bake_is_byte_identical_to_synchronous() -> void:
	for definition in _definitions():
		var grid: MapTerrainGrid = MapBuilder.build(definition)
		var reference := _polygon_bytes(MapNavBuilder.bake_navigation_polygon(definition, grid))
		var synchronous_region := MapNavBuilder.create_navigation_region(definition, grid)
		assert_eq(
			_polygon_bytes(synchronous_region.navigation_polygon),
			reference,
			"%s synchronous region keeps the reference polygon" % definition.map_id
		)
		MapNavBuilder.release_navigation_region(synchronous_region)
		var jobs: Array = []
		for run in NAV_RUNS:
			jobs.append(MapNavBuilder.start_bake(definition, grid))
		for run in NAV_RUNS:
			var polygon: NavigationPolygon = (jobs[run] as MapNavBuilder.NavBakeJob).wait()
			assert_eq(
				_polygon_bytes(polygon),
				reference,
				"%s threaded bake run %d is byte-identical" % [definition.map_id, run]
			)


func test_threaded_region_publishes_atomically() -> void:
	var definition: MapDefinition = KalevSmithyDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var region := MapNavBuilder.create_navigation_region_threaded(definition, grid)
	assert_true(region.navigation_polygon == null, "no partial polygon before publish")
	var job := MapNavBuilder.bake_job_of(region)
	assert_true(job != null, "threaded region carries its pending job")
	var publisher := region.get_node(MapNavBuilder.NAV_BAKE_PUBLISHER_NAME)
	publisher.call("publish")
	assert_eq(
		_polygon_bytes(region.navigation_polygon),
		_polygon_bytes(MapNavBuilder.bake_navigation_polygon(definition, grid)),
		"published polygon equals the synchronous bake"
	)
	MapNavBuilder.release_navigation_region(region)


func test_freeing_threaded_region_before_publish_joins_the_worker() -> void:
	var orphans_before := _orphan_ids()
	var definition: MapDefinition = LowerTownSlice.create()
	var region := MapNavBuilder.create_navigation_region_threaded(
		definition, MapBuilder.build(definition)
	)
	var job := MapNavBuilder.bake_job_of(region)
	MapNavBuilder.release_navigation_region(region)
	assert_true(job.is_done(), "a cancelled bake is joined, not abandoned")
	assert_eq(_unreleased_orphans(orphans_before), [], "the region and publisher are released")


func test_async_flags_default_off_with_a_stated_budget() -> void:
	assert_false(MapView3D.Assembly.enabled(), "ADR 0019: streaming ships flag-off")
	assert_eq(
		MapView3D.Assembly.frame_budget_msec(), MapView3D.Assembly.DEFAULT_FRAME_BUDGET_MSEC
	)


func test_door_navigator_uses_threaded_requests_and_keeps_lru() -> void:
	DoorNavigator.load_manifest(true)
	assert_true(DoorNavigator.request_scene_preload(&"forge"), "forge preload starts")
	assert_true(DoorNavigator.request_scene_preload(&"forge"), "a second request joins the first")
	var scene := DoorNavigator._get_scene_resource(&"forge")
	assert_true(scene != null, "threaded request resolves to the PackedScene")
	assert_true(DoorNavigator.scene_cache.has(&"forge"))
	assert_eq(DoorNavigator.cache_order, [&"forge"])
	assert_true(DoorNavigator.is_scene_resource_ready(&"forge"), "cached scenes never block")
	assert_eq(DoorNavigator._threaded_requests, {}, "collected requests are released")
	assert_false(DoorNavigator.request_scene_preload(&"no_such_scene"))
	DoorNavigator.load_manifest(true)


## WB-07d (R-1010): a pattern painted on a worker is byte-identical to the same
## request painted on the main thread, for every family the staged terrain,
## neighbor-preview and backdrop materials bake (including normal maps and the
## RGBA cobble surface). Only the pixel painting moves; the bytes do not change.
func test_worker_pattern_bakes_are_byte_identical_to_main_thread() -> void:
	var noise_seed := 7_340_033
	var requests: Array[Dictionary] = (
		MapViewMaterials.TERRAIN_MATERIALS.blended_ground_bake_requests(noise_seed)
	)
	for terrain_id in MapViewMaterials.BLEND_TERRAIN_ORDER:
		requests.append_array(
			MapViewMaterials.TERRAIN_MATERIALS.terrain_bake_requests(terrain_id, noise_seed)
		)
	requests.append_array(MapViewMaterials.PROP_MATERIALS.backdrop_bake_requests())
	requests.append_array(MapViewMaterials.PROP_MATERIALS.hewn_timber_bake_requests())
	var bakeable: Array[Dictionary] = []
	for request in requests:
		# missing_bakes() filters by cache, so ask for the worker-safe set directly.
		if request.get("pattern", &"") != MapViewMaterials.PATTERN_FAMILIES.PATTERN_LIMESTONE:
			bakeable.append(request)
	var job: RefCounted = Job.run_group(
		func(index: int) -> Image: return MapViewMaterialPatterns.bake_image(bakeable[index]),
		bakeable.size(),
		"test pattern bakes"
	)
	var worker_images: Array = job.values()
	for index in bakeable.size():
		var main_image := MapViewMaterialPatterns.bake_image(bakeable[index])
		var worker_image: Image = worker_images[index]
		assert_eq(worker_image.get_format(), main_image.get_format(), bakeable[index]["key"])
		assert_true(worker_image.has_mipmaps(), "%s has mipmaps" % bakeable[index]["key"])
		assert_eq(
			worker_image.get_data(), main_image.get_data(), "%s bytes" % bakeable[index]["key"]
		)


## R-1070: scene-kind workers (Door instantiate / package inspect) wait until
## compute jobs finish, so the two kinds never share the pool.
func test_scene_worker_kind_waits_for_compute_jobs() -> void:
	var events: Array = []
	var compute: RefCounted = Job.run(
		func() -> int:
			events.append(&"compute_start")
			OS.delay_msec(40)
			events.append(&"compute_end")
			return 1
	)
	var waited := 0
	while events.is_empty() and waited < 200:
		OS.delay_msec(1)
		waited += 1
	assert_eq(events, [&"compute_start"], "compute must enter before the scene kind is queued")
	var scene_id := WorkerThreadPool.add_task(
		func() -> void:
			Job.begin_scene_work()
			events.append(&"scene")
			Job.end_scene_work(),
		true,
		"r1070 scene kind"
	)
	compute.wait()
	WorkerThreadPool.wait_for_task_completion(scene_id)
	assert_eq(events, [&"compute_start", &"compute_end", &"scene"])
	assert_eq(compute.value(), 1)


## The staged units of a cold ground material bake its patterns on workers,
## publish every texture under the synchronous cache key, and build the same
## material the synchronous getter returns afterwards.
func test_cold_ground_material_bakes_on_workers() -> void:
	var noise_seed := 5_767_169
	var terrain_materials := MapViewMaterials.TERRAIN_MATERIALS
	assert_false(terrain_materials.has_blended_ground(noise_seed), "the seed starts cold")
	var units: Array[Dictionary] = TerrainStaged.blended_ground_units(&"terrain_mesh", noise_seed)
	var labels: Array[String] = []
	for unit in units:
		labels.append(unit["label"])
	assert_true(labels.has("await_ground_material_patterns"), "patterns bake on a worker")
	assert_true(labels.has("ground_material"), "the material is its own unit")
	MapView3D.Assembly.drain(units)
	assert_true(terrain_materials.has_blended_ground(noise_seed), "the material is published")
	for request in terrain_materials.blended_ground_bake_requests(noise_seed):
		var texture: Texture2D = (
			MapViewMaterialPatterns.cobble_surface_texture(request["seed"])
			if request.get("cobble_surface", false)
			else MapViewMaterialPatterns.pattern_texture_at_size(
				request["pattern"], request["seed"], request["size"]
			)
		)
		assert_eq(
			texture.get_image().get_data(),
			MapViewMaterialPatterns.bake_image(request).get_data(),
			"published %s equals a main-thread paint" % request["key"]
		)
	var material := MapViewMaterials.blended_ground(noise_seed)
	var layers: Texture2DArray = material.get_shader_parameter("terrain_patterns")
	# The headless dummy renderer cannot read Texture2DArray layers back; the layer
	# images come from the textures checked above through the synchronous code.
	assert_eq(layers.get_layers(), MapViewMaterials.BLEND_TERRAIN_ORDER.size())
	assert_eq(layers, MapViewMaterials.terrain_pattern_array(noise_seed), "one cached array")
	assert_eq(TerrainStaged.blended_ground_units(&"terrain_mesh", noise_seed), [], "warm: no units")


## Water materials prefetch their cold resources with threaded loads and pack
## the caustic tiles on a worker; a threaded load job resolves to the resources
## in path order and joins safely when waited more than once.
func test_threaded_resource_prefetch_resolves_in_order() -> void:
	var paths := PackedStringArray(
		[
			MapViewMaterials.TERRAIN_MATERIALS.MUD_ALBEDO_PATH,
			MapViewMaterials.TERRAIN_MATERIALS.HAY_ALBEDO_PATH,
		]
	)
	var job: RefCounted = Job.load_resources(paths)
	var loaded: Array = job.value()
	job.wait()
	assert_eq(loaded.size(), 2)
	for index in paths.size():
		assert_true(loaded[index] is Texture2D, "%s loads" % paths[index])
		assert_eq((loaded[index] as Resource).resource_path, paths[index], "path order")
	var water_materials := MapViewMaterials.WATER_MATERIALS
	var sources: Array = water_materials.caustic_tile_sources()
	var packed_job: RefCounted = Job.run(
		func() -> Image: return water_materials.pack_caustic_tiles(sources[0], sources[1]),
		"test caustic pack"
	)
	var packed: Image = packed_job.value()
	var main_packed: Image = water_materials.pack_caustic_tiles(sources[0], sources[1])
	if main_packed == null:
		assert_true(packed == null, "missing tiles pack to null on both threads")
	else:
		assert_eq(packed.get_data(), main_packed.get_data(), "caustic tiles pack identically")
		var tiles := water_materials.caustic_tiles_texture()
		assert_eq(tiles.get_image().get_data(), main_packed.get_data(), "published tiles")


## WB-07e (R-1027): crib timber plates go through the same bake units, and the
## masonry publish unit is always queued so pier_cribs does not paint wood.
func test_crib_wood_and_masonry_bake_on_workers() -> void:
	var masonry: Array[Color] = [MapViewPierCribBuilder.WET_RUBBLE_COLOR]
	var units: Array[Dictionary] = TerrainStaged.building_wood_masonry_units(
		&"terrain_mesh", "cribs", masonry
	)
	var labels: Array[String] = []
	for unit in units:
		labels.append(unit["label"])
	assert_true(labels.has("await_cribs_masonry_plates"), "library plates prefetch")
	assert_true(labels.has("cribs_building_materials"), "materials publish as one unit")
	MapView3D.Assembly.drain(units)
	for variant: int in 3:
		_assert_published_wood(
			MapViewMaterialPatterns.door_wood_texture(variant),
			MapViewMaterialPatterns.door_wood_bake_request(variant, false)
		)
		_assert_published_wood(
			MapViewMaterialPatterns.door_wood_normal_texture(variant),
			MapViewMaterialPatterns.door_wood_bake_request(variant, true)
		)
		for grain_along_u: bool in [false, true]:
			_assert_published_wood(
				MapViewMaterialPatterns.beam_wood_texture(variant, grain_along_u),
				MapViewMaterialPatterns.beam_wood_bake_request(variant, grain_along_u, false)
			)
			_assert_published_wood(
				MapViewMaterialPatterns.beam_wood_normal_texture(variant, grain_along_u),
				MapViewMaterialPatterns.beam_wood_bake_request(variant, grain_along_u, true)
			)
	var masonry_material := MapViewMaterials.fortification_masonry(
		MapViewPierCribBuilder.WET_RUBBLE_COLOR
	)
	assert_true(masonry_material.albedo_texture != null, "crib masonry has an albedo")


func _assert_published_wood(texture: Texture2D, request: Dictionary) -> void:
	assert_eq(
		texture.get_image().get_data(),
		MapViewMaterialPatterns.bake_image(request).get_data(),
		"published %s equals a main-thread paint" % request["key"]
	)


## R-1079: after a main-thread warmup, a compute worker only reads the tint
## cache. It must match the main-thread colors and must not first-load species
## catalogs (that path called /root.propagate_notification and SIGSEGV'd).
func test_worker_ground_color_tint_matches_warmed_cache() -> void:
	TerrainVegetation.warmup_ground_color_tints()
	var variants: Array[StringName] = [
		&"",
		&"grass.flowers",
		&"plant.nettle",
		&"bush.bilberry",
		&"tree.oak",
	]
	var expected: Dictionary = {}
	for variant in variants:
		expected[variant] = TerrainVegetation.ground_color_tint(variant)
	var job: RefCounted = Job.run(
		func() -> Dictionary:
			var got := {}
			for variant in variants:
				got[variant] = TerrainVegetation.ground_color_tint(variant)
			return got,
		"r1079 ground color tints"
	)
	var got: Dictionary = job.value()
	for variant in variants:
		assert_eq(got[variant], expected[variant], String(variant))
	assert_eq(expected[&"grass.flowers"], Color(0.98, 1.03, 0.9))


## A job dropped without wait() joins its task while it is freed, so a cancelled
## assembly never leaves an un-waited task behind, even for a bake whose await
## unit was not queued yet.
func test_dropped_worker_job_joins_its_task() -> void:
	var finished := [false, false]
	var job: RefCounted = Job.run(
		func() -> int:
			OS.delay_msec(50)
			finished[0] = true
			return 1,
		"test dropped job"
	)
	var group: RefCounted = Job.run_group(
		func(_index: int) -> int:
			OS.delay_msec(50)
			finished[1] = true
			return 1,
		2,
		"test dropped group"
	)
	job = null
	group = null
	assert_eq(finished, [true, true], "freeing an unwaited job waits for its task")


static func _orphan_ids() -> Dictionary:
	var ids := {}
	for id in Node.get_orphan_node_ids():
		ids[id] = true
	return ids


## New orphans that will not be released. StaticBatcher detaches merged source
## meshes and queue_free()s them, which completes at the end of a frame this
## synchronous harness never reaches, so queued nodes are excluded.
static func _unreleased_orphans(before: Dictionary) -> Array[String]:
	var leaked: Array[String] = []
	for id in Node.get_orphan_node_ids():
		if before.has(id):
			continue
		var node := instance_from_id(id) as Node
		if node != null and not node.is_queued_for_deletion():
			leaked.append("%s (%s)" % [node.name, node.get_class()])
	return leaked


static func _polygon_bytes(polygon: NavigationPolygon) -> PackedByteArray:
	if polygon == null:
		return PackedByteArray()
	var polygons: Array = []
	for index in polygon.get_polygon_count():
		polygons.append(polygon.get_polygon(index))
	return var_to_bytes([polygon.get_vertices(), polygons])


## Path, class, transform, visibility, mesh bounds and stable ID for every node,
## in tree order. Enough to prove the staged build is the synchronous build.
## Path and surface-array hash of every ArrayMesh surface below root.
static func _surface_hashes(root: Node) -> Array[String]:
	var hashes: Array[String] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh as ArrayMesh
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			hashes.append(
				"%s#%d:%d"
				% [root.get_path_to(node), surface, hash(var_to_bytes(mesh.surface_get_arrays(surface)))]
			)
	return hashes


static func _tree_signature(root: Node) -> Array[String]:
	var lines: Array[String] = []
	_append_signature(root, root, lines)
	return lines


static func _append_signature(root: Node, node: Node, lines: Array[String]) -> void:
	var line := "%s|%s" % [root.get_path_to(node), node.get_class()]
	if node is Node3D:
		var node_3d := node as Node3D
		line += "|%s|%s" % [_rounded(node_3d.transform), node_3d.visible]
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh := (node as MeshInstance3D).mesh
		line += "|mesh:%d:%s" % [mesh.get_surface_count(), mesh.get_aabb()]
	if node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
		line += "|multimesh:%d" % (node as MultiMeshInstance3D).multimesh.instance_count
	if node.has_meta(&"stable_id"):
		line += "|id:%s" % node.get_meta(&"stable_id")
	lines.append(line)
	for child in node.get_children():
		_append_signature(root, child, lines)


static func _rounded(transform: Transform3D) -> String:
	var values: Array[String] = []
	for vector in [transform.basis.x, transform.basis.y, transform.basis.z, transform.origin]:
		for axis in 3:
			values.append("%.4f" % vector[axis])
	return ",".join(values)


func _free_view(view: MapView3D) -> void:
	MapView3D._strip_geometry_materials(view)
	view.free()


## WB-07c (R-1006): a scatter chunk collected in row bands and emitted in two
## units is the same chunk build_scatter() makes in one call.
func test_scatter_row_bands_match_one_call_build() -> void:
	for definition: MapDefinition in [LowerTownSlice.create(), HarborEastDefinition.create()]:
		var grid: MapTerrainGrid = MapBuilder.build(definition)
		var bounds := grid.chunk_bounds(Vector2i(1, 1))
		var whole := MapViewMeshBuilderScatter.build_scatter(definition, grid, bounds)
		var state := MapViewMeshBuilderScatter.begin_scatter(definition, grid, bounds)
		var row: int = state["next_row"]
		var done := false
		while not done:
			row += 3
			done = MapViewMeshBuilderScatter.collect_rows(state, row)
		MapViewMeshBuilderScatter.emit_layers(state)
		var banded := MapViewMeshBuilderScatter.emit_shore(state)
		assert_true(whole.get_child_count() > 0, "%s chunk has scatter" % definition.map_id)
		assert_eq(
			_scatter_signature(banded),
			_scatter_signature(whole),
			"%s banded scatter equals one call" % definition.map_id
		)
		whole.free()
		banded.free()


## WB-07c (R-1006): the building GLBs and kit plates a view loads stay pinned for
## the view's lifetime, and no pin set leaks past the assembly units.
func test_assembly_pins_production_scenes_for_the_view() -> void:
	var definition: MapDefinition = LowerTownSlice.create()
	var staged := MapView3D.create_staged(definition, MapBuilder.build(definition))
	_drain_staged(staged)
	var pins: Dictionary = staged._assembly.scene_pins
	assert_true(pins.has(PUBLIC_BATH_GLB), "the service-building GLB is pinned by the view")
	assert_true(pins[PUBLIC_BATH_GLB] is PackedScene, "pins hold the loaded scene")
	var plates := MapViewBurgherHouseSurfaceVariety.kit_texture_paths()
	assert_true(plates.size() > 0 and pins.has(plates[0]), "kit surface plates are pinned")
	assert_true(MapViewPackedScenes._pin_stack.is_empty(), "no pin set stays pushed")
	var labels: Array[String] = []
	for entry in staged.assembly_unit_timings():
		labels.append(String(entry["label"]))
	assert_true(labels.has("objects_scene_pins"), "building GLBs prefetch before object_index")
	_free_view(staged)


## WB-07c (R-1006): prop kits have no path up front; the set a map's assembly
## pinned is prefetched by the next assembly of the same map.
func test_learned_scenes_prefetch_on_the_next_assembly() -> void:
	var definition: MapDefinition = KalevSmithyDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	_free_view(MapView3D.create(definition, grid))
	var learned := MapViewPackedScenes.learned_paths(MapViewPackedScenes.map_key(definition))
	assert_true(learned.has(CLUTTER_KIT_GLB), "the smithy clutter kit is remembered")
	var staged := MapView3D.create_staged(definition, grid)
	_drain_staged(staged)
	assert_true(staged._assembly.scene_pins.has(CLUTTER_KIT_GLB), "the next assembly pins it")
	_free_view(staged)


## WB-07c (R-1006): fishing boats no longer rebuild the playable grid per boat;
## every boat reads one field per definition, the same field the old path used.
func test_fishing_boats_share_one_rest_field() -> void:
	var definition: MapDefinition = HarborEastDefinition.create()
	var boats: Array[Dictionary] = []
	for prop in definition.props:
		if prop.get("kind") == MapTypes.PROP_KIND_FISHING_BOAT:
			boats.append(prop)
	assert_true(boats.size() >= 2, "Harbor East has several fishing boats")
	var expected := MapViewMeshBuilderTerrain.ensure_height_field(
		definition, MapBuilder.build(definition)
	)
	for boat in boats:
		MapViewMeshBuilder.build_prop(boat, definition.cell_size, definition).free()
	var shared: Dictionary = PropModels._boat_rest_field(definition)
	assert_true(is_same(shared, expected), "boats reuse the published height field")


static func _scatter_signature(root: Node) -> Array[String]:
	var result: Array[String] = []
	for child in root.get_children():
		var line := "%s:%s" % [child.name, child.get_class()]
		var multi := child as MultiMeshInstance3D
		if multi != null and multi.multimesh != null:
			line += ":%d:%d" % [multi.multimesh.instance_count, hash(multi.multimesh.buffer)]
		line += ":%d" % child.get_child_count()
		result.append(line)
	return result
