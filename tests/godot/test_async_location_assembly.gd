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
		var guard := 0
		while not staged.step_assembly(BUDGET_USEC):
			guard += 1
			if guard > 100000:
				break
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
		synchronous_region.free()
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
	region.free()


func test_freeing_threaded_region_before_publish_joins_the_worker() -> void:
	var orphans_before := _orphan_ids()
	var definition: MapDefinition = LowerTownSlice.create()
	var region := MapNavBuilder.create_navigation_region_threaded(
		definition, MapBuilder.build(definition)
	)
	var job := MapNavBuilder.bake_job_of(region)
	region.free()
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
