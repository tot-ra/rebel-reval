extends "res://tests/godot/test_case.gd"

const NORTH_RRMAP_PATH := "res://content/maps/reval_harbor_north.rrmap"
const EAST_RRMAP_PATH := "res://content/maps/reval_harbor_east.rrmap"
const HarborNorthDefinition := preload("res://scripts/map/definitions/outdoor/reval_harbor_north_definition.gd")
const HarborEastDefinition := preload("res://scripts/map/definitions/outdoor/reval_harbor_east_definition.gd")

var _test_root := ""


func before_each() -> void:
	_test_root = "user://p0_169_harbour_shoreline/%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]


func after_each() -> void:
	_remove_tree(_test_root)


func test_rrmaps_preserve_evidence_bounded_shore_contract() -> void:
	for path in [NORTH_RRMAP_PATH, EAST_RRMAP_PATH]:
		var parsed := MapRrmapParser.parse_file(path)
		assert_true(parsed.is_ok(), "%s must parse: %s" % [path, str(parsed.formatted_diagnostics())])
		if not parsed.is_ok():
			continue
		var canonical_source := MapRrmapParser.canonical_print(parsed.blueprint)
		assert_true("shore.reconstructed_water" in canonical_source, "%s must retain reconstructed water source ID" % path)
		assert_true("shore.reconstructed_reed" in canonical_source, "%s must retain reconstructed reed source ID" % path)
		var confidence_zones: Array[Dictionary] = []
		for zone in parsed.definition.zones:
			if zone.has("shore_confidence"):
				confidence_zones.append(zone)
		assert_eq(confidence_zones.size(), 2, "%s must compile exactly two confidence zones" % path)
		var confidence_terrains: Dictionary = {}
		for zone: Dictionary in confidence_zones:
			assert_eq(zone.get("shore_confidence"), &"reconstructed", "%s shore confidence" % path)
			var terrain: StringName = zone.get("terrain", &"")
			confidence_terrains[terrain] = int(confidence_terrains.get(terrain, 0)) + 1
		assert_eq(confidence_terrains.get(MapTypes.TERRAIN_SHALLOW_WATER, 0), 1, "%s needs one reconstructed shallow-water zone" % path)
		assert_eq(confidence_terrains.get(MapTypes.TERRAIN_MUD, 0), 1, "%s needs one reconstructed mud zone" % path)
		var grid := MapBuilder.build(parsed.definition)
		var deep_sample := Vector2i(parsed.definition.size_cells.x / 2, 12)
		assert_eq(grid.get_terrain(deep_sample), MapTypes.TERRAIN_DEEP_WATER, "%s keeps open deep water outside the wet margin" % path)

func test_rrmap_canonical_round_trip_preserves_shore_fingerprint_and_metadata() -> void:
	for path in [NORTH_RRMAP_PATH, EAST_RRMAP_PATH]:
		var parsed := MapRrmapParser.parse_file(path)
		assert_true(parsed.is_ok(), "%s must parse before round-trip" % path)
		if not parsed.is_ok():
			continue
		var canonical := MapRrmapParser.canonical_print(parsed.blueprint)
		var reparsed := MapRrmapParser.parse(canonical, "%s.canonical.rrmap" % path)
		assert_true(reparsed.is_ok(), "%s canonical form must parse: %s" % [path, str(reparsed.formatted_diagnostics())])
		if reparsed.is_ok():
			assert_eq(reparsed.definition.fingerprint, parsed.definition.fingerprint, "%s fingerprint changed" % path)
			assert_eq(_shore_signature(reparsed.definition), _shore_signature(parsed.definition), "%s shore metadata changed" % path)


func test_harbour_landings_and_salvage_routes_stay_walkable() -> void:
	var north: MapDefinition = HarborNorthDefinition.create()
	var east: MapDefinition = HarborEastDefinition.create()
	var north_grid := MapBuilder.build(north)
	var east_grid := MapBuilder.build(east)
	var north_landing_cells: Array[Vector2i] = [Vector2i(57, 64), Vector2i(57, 47), Vector2i(113, 49)]
	var east_landing_cells: Array[Vector2i] = [Vector2i(26, 43), Vector2i(26, 24), Vector2i(64, 26), Vector2i(111, 27)]
	for cell in north_landing_cells:
		assert_eq(north_grid.get_terrain(cell), MapTypes.TERRAIN_TIMBER_FLOOR, "north landing cell %s must remain timber" % cell)
		assert_true(MapVerification.is_walkable_cell(north, north_grid, cell), "north landing cell %s must remain walkable" % cell)
	for cell in east_landing_cells:
		assert_eq(east_grid.get_terrain(cell), MapTypes.TERRAIN_TIMBER_FLOOR, "east landing cell %s must remain timber" % cell)
		assert_true(MapVerification.is_walkable_cell(east, east_grid, cell), "east landing cell %s must remain walkable" % cell)
	assert_true(
		MapVerification.route_exists_exact(north, north_grid, MapVerification.cell_center(north, Vector2i(57, 64)), MapVerification.cell_center(north, Vector2i(57, 47))),
		"north shore route must reach the landing tip"
	)
	assert_true(
		MapVerification.route_exists_exact(east, east_grid, MapVerification.cell_center(east, Vector2i(26, 43)), MapVerification.cell_center(east, Vector2i(26, 24))),
		"east shore route must reach the landing tip"
	)
	assert_true(MapVerification.route_exists_exact(north, north_grid, MapVerification.anchor_position(north, &"quay_plaza"), MapVerification.cell_center(north, Vector2i(57, 47))), "north quay route must remain connected")
	assert_true(MapVerification.route_exists_exact(east, east_grid, MapVerification.anchor_position(east, &"kalamaja_shore"), MapVerification.cell_center(east, Vector2i(26, 43))), "east shore route must remain connected")


func test_deep_and_shallow_water_are_excluded_from_navigation() -> void:
	for definition: MapDefinition in [HarborNorthDefinition.create(), HarborEastDefinition.create()]:
		var grid := MapBuilder.build(definition)
		var fingerprint_before := definition.fingerprint
		var grid_fingerprint_before := grid.fingerprint()
		var region := MapNavBuilder.create_navigation_region(definition, grid)
		assert_true(region.navigation_polygon != null, "%s must produce navigation" % String(definition.map_id))
		if region.navigation_polygon != null:
			assert_true(region.navigation_polygon.get_polygon_count() > 0, "%s navigation must contain polygons" % String(definition.map_id))
			var deep_cell := Vector2i(definition.size_cells.x / 2, 12)
			var shallow_cell := Vector2i(definition.size_cells.x / 2, 30 if definition.map_id == &"reval_harbor_east" else 50)
			assert_true(MapTypes.WATER_TERRAINS.has(grid.get_terrain(deep_cell)), "deep sample must be water")
			assert_true(MapTypes.WATER_TERRAINS.has(grid.get_terrain(shallow_cell)), "shallow sample must be water")
			assert_false(_navigation_contains(region.navigation_polygon, definition.cell_rect_center(Rect2i(deep_cell, Vector2i.ONE))), "deep water must not be navigable")
			assert_false(_navigation_contains(region.navigation_polygon, definition.cell_rect_center(Rect2i(shallow_cell, Vector2i.ONE))), "shallow water must not be navigable")
		assert_eq(region.navigation_polygon.agent_radius, 16.0, "%s navigation must preserve player clearance" % String(definition.map_id))
		region.free()
		assert_eq(definition.fingerprint, fingerprint_before, "navigation must not mutate map semantics")
		assert_eq(grid.fingerprint(), grid_fingerprint_before, "navigation must not mutate terrain")


func test_harbour_buildings_keep_collision_parity() -> void:
	for definition: MapDefinition in [HarborNorthDefinition.create(), HarborEastDefinition.create()]:
		assert_true(MapVerification.collision_parity(definition), "%s building collision must match authored footprints" % String(definition.map_id))


func test_harbour_location_and_world_state_survive_clean_save_reload() -> void:
	var service := SaveService.new()
	service.save_directory = "%s/save" % _test_root
	var original := GameState.new()
	original.set_phase(GameState.PHASE_INVESTIGATION_MORNING)
	original.player.location_id = &"reval_harbor_north"
	original.player.spawn_id = &"quay_plaza"
	original.set_flag(&"flag.p0_169_shore_seen", true)
	original.map_world_state.set_location_metadata(&"reval_harbor_north", "shoreline-acceptance-fingerprint")
	assert_true(original.map_world_state.record_object_delta(&"reval_harbor_north", &"salvage.route.anchor", {"status": "reachable", "confidence": "reconstructed"}))
	var expected_payload := MapParitySnapshot.serialize_value(original.save_payload())
	assert_true(service.save_game(original), "shoreline acceptance save must succeed")
	var loaded := service.load_game()
	assert_true(loaded["ok"], ", ".join(loaded["errors"]))
	if not loaded["ok"]:
		return
	var restored := loaded["state"] as GameState
	assert_eq(restored.player.location_id, &"reval_harbor_north")
	assert_eq(restored.player.spawn_id, &"quay_plaza")
	assert_eq(restored.get_phase(), GameState.PHASE_INVESTIGATION_MORNING)
	assert_true(restored.get_flag(&"flag.p0_169_shore_seen"))
	assert_eq(MapParitySnapshot.serialize_value(restored.save_payload()), expected_payload, "save/reload must preserve harbour world state")


func _shore_signature(definition: MapDefinition) -> String:
	var rows: Array[String] = []
	for zone in definition.zones:
		if not zone.has("shore_confidence"):
			continue
		var rect: Rect2i = zone["rect"]
		rows.append("%s|%s|%s|%s|%s|%s|%s" % [
			String(zone.get("id", "")),
			String(zone.get("terrain", "")),
			String(zone.get("shore_confidence", "")),
			rect.position.x,
			rect.position.y,
			rect.size.x,
			rect.size.y,
		])
	rows.sort()
	return "\n".join(rows)


func _navigation_contains(polygon: NavigationPolygon, point: Vector2) -> bool:
	var vertices := polygon.get_vertices()
	for polygon_index in polygon.get_polygon_count():
		var indices := polygon.get_polygon(polygon_index)
		var outline := PackedVector2Array()
		for vertex_index in indices:
			outline.append(vertices[vertex_index])
		if Geometry2D.is_point_in_polygon(point, outline):
			return true
	return false


func _remove_tree(path: String) -> void:
	if path.is_empty():
		return
	var dir := DirAccess.open(path)
	if dir == null:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child := path.path_join(entry)
			if DirAccess.dir_exists_absolute(child):
				_remove_tree(child)
			else:
				DirAccess.remove_absolute(child)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
