extends "res://tests/godot/test_case.gd"

## WB-03 (R-975, ADR 0023): the compiled relief drives actor height, slope cost,
## walkability, navigation, 2D collision and the camera line of sight, while every
## registered map (none authors relief yet) keeps its walkable-cell census.

const FIXTURE_PATH := "res://tests/fixtures/maps/rrmap_relief_example.rrmap"
const STEEP_SOURCE := (
	"rrmap 1\n"
	+ "map relief_steep_probe loc.relief_steep_probe 24 20 grass scope=prototype"
	+ " active=false palette=clean_painted seed=5 cell_size=32\n"
	+ "relief_hill relief.spike 12 10 3 6\n"
	+ "spawn spawn.main 2 2\n"
)
## Cells of the WB-02 fixture: its spawn, the relief.hill crown, the terrace
## top, a terrace worked-edge cell, and the pit relief.cliff lowers.
const SPAWN_CELL := Vector2i(24, 16)
const HILL_TOP := Vector2i(10, 10)
const TERRACE_TOP := Vector2i(32, 14)
const TERRACE_EDGE := Vector2i(28, 14)
const CLIFF_PIT := Vector2i(44, 16)


func _fixture() -> MapDefinition:
	var parsed := MapRrmapParser.parse_file(FIXTURE_PATH)
	assert_true(parsed.is_ok(), "relief fixture compiles: %s" % [parsed.formatted_diagnostics()])
	return parsed.definition if parsed.is_ok() else null


func _cell_center(definition: MapDefinition, cell: Vector2i) -> Vector2:
	return MapVerification.cell_center(definition, cell)


func test_actor_height_is_view_detail_over_compiled_relief() -> void:
	var definition := _fixture()
	if definition == null:
		return
	# The same map without relief renders only the view detail (noise, pads), so
	# the difference between the two view fields must be the compiled relief.
	var flat := _fixture()
	flat.relief_heights = PackedFloat32Array()
	flat.relief_features.clear()
	flat.fingerprint = "%s.flat" % definition.fingerprint
	MapViewMeshBuilder.ensure_height_field(definition, MapBuilder.build(definition))
	MapViewMeshBuilder.ensure_height_field(flat, MapBuilder.build(flat))
	var worst := 0.0
	var cells: Array[Vector2i] = [
		SPAWN_CELL, HILL_TOP, TERRACE_TOP, TERRACE_EDGE, Vector2i(9, 13), Vector2i(20, 34)
	]
	var offsets: Array[Vector2] = [Vector2(0.5, 0.5), Vector2(0.1, 0.9), Vector2(0.97, 0.03)]
	for cell in cells:
		for offset in offsets:
			var logic := (Vector2(cell) + offset) * float(definition.cell_size)
			var world := MapViewBridge.logic_to_world(logic, definition.cell_size)
			var xz := Vector2(world.x, world.z)
			var derived := (
				MapViewMeshBuilder.ground_height(definition, xz)
				- MapViewMeshBuilder.ground_height(flat, xz)
			)
			worst = maxf(worst, absf(derived - definition.height_at_world(logic)))
	assert_almost_eq(worst, 0.0, 0.0001, "actor Y = height_at_world + view detail")


func test_actor_height_has_no_step_at_cell_boundaries() -> void:
	var definition := _fixture()
	if definition == null:
		return
	# Bilinear sampling between cell centres is the smoothing window: a walk across
	# the hill flank at 1/50 cell steps never jumps more than the local slope allows.
	var max_step := 0.0
	var previous := definition.height_at_world(Vector2(3.0, 10.5) * definition.cell_size)
	for index in range(1, 700):
		var x := 3.0 + float(index) / 50.0
		var height := definition.height_at_world(Vector2(x, 10.5) * definition.cell_size)
		max_step = maxf(max_step, absf(height - previous))
		previous = height
	assert_true(max_step > 0.0, "the walk crosses relief")
	assert_true(
		max_step <= tan(MapDefinition.RELIEF_MAX_WALKABLE_SLOPE) / 50.0 + 0.0001,
		"no step at a cell boundary (max %.5f per 1/50 cell)" % max_step
	)


func test_uphill_cost_is_monotonic_in_slope() -> void:
	var previous := MapTerrainMovement.slope_cost_multiplier(0.0)
	assert_eq(previous, 1.0, "flat ground costs nothing")
	for step in range(1, 41):
		var slope := MapDefinition.RELIEF_MAX_WALKABLE_SLOPE * float(step) / 40.0
		var multiplier := MapTerrainMovement.slope_cost_multiplier(slope)
		assert_true(multiplier < previous, "cost strictly rises with slope at %.3f rad" % slope)
		previous = multiplier
	assert_almost_eq(previous, cos(MapDefinition.RELIEF_MAX_WALKABLE_SLOPE), 0.000001)
	assert_eq(
		MapTerrainMovement.slope_cost_multiplier(1.2),
		previous,
		"the curve stops at the walkable limit; steeper ground is impassable instead"
	)
	var definition := _fixture()
	if definition == null:
		return
	var grid := MapBuilder.build(definition)
	var flank := Vector2(5.0, 10.5) * definition.cell_size
	var flank_slope := definition.slope_at_world(flank)
	assert_true(flank_slope > 0.1, "hill flank is sloped")
	assert_almost_eq(
		MapTerrainMovement.speed_multiplier_at(definition, grid, flank),
		cos(flank_slope),
		0.0001,
		"movement speed on the flank is cos(slope)"
	)
	assert_eq(
		MapTerrainMovement.speed_multiplier_at(definition, grid, _cell_center(definition, SPAWN_CELL)),
		1.0,
		"flat spawn keeps full speed"
	)


func test_cell_above_slope_maximum_is_not_walkable() -> void:
	var parsed := MapRrmapParser.parse(STEEP_SOURCE, "res://relief_steep_probe.rrmap")
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var codes := {}
	for diagnostic in parsed.diagnostics:
		codes[diagnostic.code] = true
	assert_true(codes.has(&"MAP_RELIEF_SLOPE"), "the spike is an unauthored steep face")
	var definition := parsed.definition
	var grid := MapBuilder.build(definition)
	var steep := Vector2i(11, 10)
	var rise := absf(definition.height_at(steep) - definition.height_at(Vector2i(10, 10)))
	assert_true(rise > tan(MapDefinition.RELIEF_MAX_WALKABLE_SLOPE), "face %s is steep" % steep)
	assert_true(MapTerrainMovement.is_relief_blocked_cell(definition, steep))
	assert_false(MapVerification.is_walkable_cell(definition, grid, steep), "steep cell blocks")
	assert_true(MapVerification.is_walkable_cell(definition, grid, Vector2i(2, 2)), "open ground")
	assert_false(
		MapVerification.route_exists_exact(
			definition,
			grid,
			_cell_center(definition, Vector2i(2, 2)),
			_cell_center(definition, Vector2i(12, 10))
		),
		"the spike crown is ringed by impassable faces"
	)


func test_relief_cliff_obstructs_navigation_and_collision() -> void:
	var definition := _fixture()
	if definition == null:
		return
	var grid := MapBuilder.build(definition)
	var rects := MapNavBuilder.relief_obstruction_rects(definition)
	assert_false(rects.is_empty(), "the cliff contributes obstruction rects")
	var face_cells: Array[Vector2i] = [Vector2i(40, 16), Vector2i(41, 16)]
	for cell in face_cells:
		var covered := false
		for rect in rects:
			covered = covered or rect.has_point(cell)
		assert_true(covered, "cliff face cell %s is obstructed" % cell)
		assert_false(MapVerification.is_walkable_cell(definition, grid, cell))
	# The bake must leave the face cells out of the navigation polygon.
	var polygon := MapNavBuilder.bake_navigation_polygon(definition, grid)
	var face := _cell_center(definition, Vector2i(40, 16))
	var open := _cell_center(definition, SPAWN_CELL)
	assert_false(_polygon_contains(polygon, face), "nav mesh excludes the cliff face")
	assert_true(_polygon_contains(polygon, open), "nav mesh keeps open ground")
	# Keyboard/gamepad movement is blocked by the same rects as 2D collision.
	var host := Node2D.new()
	var body := MapSceneBootstrap._create_relief_blocks(definition, host)
	assert_true(body != null, "relief blocks exist on a relief map")
	if body != null:
		assert_eq(body.get_child_count(), rects.size(), "one collision shape per rect")
		assert_true(body.is_in_group(&"map_relief_collision"))
	host.free()


func test_terrace_edge_and_hill_stay_walkable_and_reachable() -> void:
	var definition := _fixture()
	if definition == null:
		return
	var grid := MapBuilder.build(definition)
	for y in range(9, 21):
		for x in range(27, 39):
			assert_true(
				MapVerification.is_walkable_cell(definition, grid, Vector2i(x, y)),
				"terrace and its worked edge stay walkable at %s" % Vector2i(x, y)
			)
	var spawn := _cell_center(definition, SPAWN_CELL)
	var targets: Array[Vector2i] = [TERRACE_TOP, TERRACE_EDGE, HILL_TOP]
	for target in targets:
		assert_true(
			MapVerification.route_exists_exact(definition, grid, spawn, _cell_center(definition, target)),
			"%s is reachable from the spawn" % target
		)
	assert_false(
		MapVerification.route_exists_exact(definition, grid, spawn, _cell_center(definition, CLIFF_PIT)),
		"the pit behind relief.cliff is closed by its faces"
	)


func test_single_cell_cliff_predicate_matches_compiler_mask() -> void:
	var definition := _fixture()
	if definition == null:
		return
	var size := definition.size_cells
	var checked := 0
	for feature in definition.relief_features:
		if feature.get("kind") != &"cliff":
			continue
		var mask := MapBlueprintCompilerExpandTerrain.cliff_lowered_mask(feature, size)
		for y in size.y:
			for x in size.x:
				assert_eq(
					MapTerrainMovement.is_cliff_lowered(feature, Vector2i(x, y)),
					mask[y * size.x + x] == 1,
					"cliff side at %s" % Vector2i(x, y)
				)
				checked += 1
	assert_eq(checked, size.x * size.y, "the fixture has exactly one cliff")


func test_relief_obstruction_is_deterministic() -> void:
	var first := _fixture()
	var second := _fixture()
	if first == null or second == null:
		return
	assert_eq(
		MapNavBuilder.relief_obstruction_rects(first),
		MapNavBuilder.relief_obstruction_rects(second),
		"two compiles obstruct the same rects"
	)


func test_save_round_trip_derives_the_same_height() -> void:
	var definition := _fixture()
	if definition == null:
		return
	var state := GameState.new()
	state.player.location_id = definition.location
	state.player.spawn_id = &"main"
	var payload := GameStatePersistence.save_payload(state)
	var player: Dictionary = payload.get("player", {})
	for key in player:
		assert_false(
			"height" in String(key) or "elevation" in String(key),
			"the player save record carries no height (%s)" % key
		)
	var restored := GameState.new()
	var errors := GameStatePersistence.load_payload(
		restored, JSON.parse_string(JSON.stringify(payload))
	)
	assert_true(errors.is_empty(), str(errors))
	assert_eq(restored.player.location_id, state.player.location_id)
	assert_eq(restored.player.spawn_id, state.player.spawn_id)
	# Reloading recompiles the map; the spawn resolves to the same cell and the
	# same derived height on the hill flank as before the save.
	var reloaded := _fixture()
	var on_slope := Vector2(5.25, 10.5) * definition.cell_size
	assert_true(definition.slope_at_world(on_slope) > 0.1, "sample sits on a slope")
	assert_eq(reloaded.height_at_world(on_slope), definition.height_at_world(on_slope))
	assert_eq(reloaded.player_spawn, definition.player_spawn)


func test_camera_line_of_sight_detects_a_rising_bank() -> void:
	var definition := _fixture()
	if definition == null:
		return
	MapViewMeshBuilder.ensure_height_field(definition, MapBuilder.build(definition))
	# Player on the plain east of relief.hill, camera low on the far (west) side:
	# the hill crown (+3) sits between them.
	var ground_at := func(cell_x: float, cell_z: float) -> float:
		return MapViewMeshBuilder.ground_height(definition, Vector2(cell_x, cell_z))
	var player := Vector3(19.5, float(ground_at.call(19.5, 10.5)), 10.5)
	var low_camera := Vector3(1.5, float(ground_at.call(1.5, 10.5)) + 1.2, 10.5)
	var high_camera := Vector3(1.5, 12.0, 10.5)
	var chest := player + Vector3.UP * MapViewRuntimeCameraSafety.TERRAIN_SIGHT_HEIGHT
	assert_true(
		MapViewRuntimeCameraSafety.segment_under_ground(definition, low_camera, chest),
		"a low camera behind the hill looks into the bank"
	)
	assert_false(
		MapViewRuntimeCameraSafety.segment_under_ground(definition, high_camera, chest),
		"a raised camera clears the crown"
	)


func test_registered_maps_keep_their_walkable_census() -> void:
	# No registered map authors relief_* yet and no datum is steep enough to block,
	# so relief must remove no cell from any map: navigation input, collision and
	# every flood-fill audit are unchanged. The per-map census is in
	# docs/reports/relief_traversal_2026-09-26.md.
	var compiled := 0
	var entries := MapBlueprintRegistry.entries()
	for entry in entries:
		var definition := MapBlueprintCompiler.compile(MapBlueprintRegistry.create_blueprint(entry))
		if definition == null:
			fail("%s compiles" % entry.get("id", ""))
			continue
		compiled += 1
		assert_false(
			MapTerrainMovement.relief_can_block(definition),
			"%s ground cannot block any cell" % definition.map_id
		)
		assert_true(MapNavBuilder.relief_obstruction_rects(definition).is_empty())
		assert_false(MapTerrainMovement.is_relief_blocked_cell(definition, definition.size_cells / 2))
	assert_true(entries.size() > 0, "the registry lists maps")
	assert_eq(compiled, entries.size(), "every registered map compiles")


static func _polygon_contains(polygon: NavigationPolygon, point: Vector2) -> bool:
	var vertices := polygon.get_vertices()
	for index in polygon.get_polygon_count():
		var outline := PackedVector2Array()
		for vertex in polygon.get_polygon(index):
			outline.append(vertices[vertex])
		if Geometry2D.is_point_in_polygon(point, outline):
			return true
	return false
