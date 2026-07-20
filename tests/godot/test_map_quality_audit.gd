extends "res://tests/godot/test_case.gd"

const Registry := preload("res://scripts/map/map_audit_registry.gd")
const MANIFEST_PATH := "res://content/map_audit_manifest.json"
## P0-062b: temporary spawn-adjacent loops must not regress on these prototypes.
## Span is measured in cells so short courtyard laps fail while multi-street routes pass.
const MULTI_STREET_PATROL_REQUIREMENTS := {
	"north_quarter": {"min_points": 6, "min_span_x": 20, "min_span_y": 20},
	"south_quarter": {"min_points": 6, "min_span_x": 20, "min_span_y": 20},
	"toompea_quarter": {"min_points": 6, "min_span_x": 20, "min_span_y": 20},
}

var _manifest: Dictionary = {}


func before_each() -> void:
	_failures.clear()
	if _manifest.is_empty():
		_manifest = _load_manifest()


func test_manifest_exactly_matches_executable_definitions() -> void:
	var rows: Array = _manifest.get("maps", [])
	var definitions := Registry.by_id()
	assert_eq(rows.size(), definitions.size(), "Manifest and executable registry counts must match")
	var seen: Dictionary = {}
	for row in rows:
		var map_id := String(row.get("id", ""))
		assert_false(seen.has(map_id), "Duplicate manifest map ID: %s" % map_id)
		seen[map_id] = true
		assert_true(definitions.has(map_id), "Manifest map is not executable: %s" % map_id)
	for map_id in definitions:
		assert_true(seen.has(map_id), "Executable definition is missing from manifest: %s" % map_id)


func test_every_definition_validates_and_fingerprint_is_deterministic() -> void:
	var first := Registry.by_id()
	var second := Registry.by_id()
	for map_id in first:
		var definition: MapDefinition = first[map_id]
		assert_true(definition.validate().is_empty(), "%s validation: %s" % [map_id, definition.validate()])
		assert_false(definition.fingerprint.is_empty(), "%s fingerprint is empty" % map_id)
		assert_eq(definition.fingerprint, (second[map_id] as MapDefinition).fingerprint, "%s fingerprint drift" % map_id)


func test_every_cell_has_known_terrain_and_full_coverage() -> void:
	for definition in Registry.all():
		var grid := MapBuilder.build(definition)
		assert_eq(grid.cells.size(), definition.size_cells.x * definition.size_cells.y, "%s terrain cell count" % definition.map_id)
		for y in definition.size_cells.y:
			for x in definition.size_cells.x:
				var terrain := grid.get_terrain(Vector2i(x, y))
				assert_false(terrain.is_empty(), "%s terrain gap at %s" % [definition.map_id, Vector2i(x, y)])
				assert_true(MapTypes.ALL_TERRAINS.has(terrain), "%s unknown terrain %s" % [definition.map_id, terrain])


func test_known_ids_in_bounds_footprints_and_collision_parity() -> void:
	for definition in Registry.all():
		var world := Rect2(Vector2.ZERO, definition.world_size())
		for building in definition.buildings:
			assert_true(MapTypes.ALL_BUILDING_KINDS.has(building.get("kind")), "%s unknown building kind" % definition.map_id)
			var footprint: Rect2 = building.get("footprint", Rect2())
			assert_true(footprint.size.x > 0.0 and footprint.size.y > 0.0, "%s empty building footprint" % definition.map_id)
			assert_true(world.encloses(footprint), "%s out-of-bounds footprint %s" % [definition.map_id, building.get("id")])
		for prop in definition.props:
			assert_true(MapTypes.ALL_PROP_KINDS.has(prop.get("kind")), "%s unknown prop kind" % definition.map_id)
			assert_true(world.has_point(prop.get("position", Vector2(-1, -1))), "%s out-of-bounds prop %s" % [definition.map_id, prop.get("id")])
		assert_true(MapVerification.collision_parity(definition), "%s collision footprint drift" % definition.map_id)


func test_required_spawns_transitions_and_mandatory_points_are_reachable() -> void:
	var definitions := Registry.by_id()
	for row in _manifest.get("maps", []):
		var map_id := String(row["id"])
		var definition: MapDefinition = definitions[map_id]
		var grid := MapBuilder.build(definition)
		assert_true(MapVerification.is_walkable_point(definition, grid, definition.player_spawn), "%s spawn is not walkable" % map_id)
		for anchor_id in row.get("mandatory_anchors", []):
			var anchor := StringName(anchor_id)
			assert_true(MapVerification.has_anchor(definition, anchor), "%s missing anchor %s" % [map_id, anchor_id])
			var target := MapVerification.anchor_position(definition, anchor)
			assert_true(MapVerification.route_exists(definition, grid, definition.player_spawn, target), "%s cannot navigate near anchor %s" % [map_id, anchor_id])
		for transition_id in row.get("mandatory_transitions", []):
			var transition := StringName(transition_id)
			var rect := MapVerification.transition_rect(definition, transition)
			assert_false(rect == Rect2(), "%s missing transition %s" % [map_id, transition_id])
			assert_true(MapVerification.is_walkable_point(definition, grid, rect.get_center()), "%s transition %s is not reachable terrain" % [map_id, transition_id])
			assert_true(MapVerification.route_exists_exact(definition, grid, definition.player_spawn, rect.get_center()), "%s cannot navigate spawn -> transition %s" % [map_id, transition_id])
		for patrol in definition.patrols:
			var points: Array = patrol.get("points", [])
			for index in range(1, points.size()):
				assert_true(MapVerification.route_exists_exact(definition, grid, points[index - 1], points[index]), "%s patrol segment %d is blocked" % [map_id, index])
			if MULTI_STREET_PATROL_REQUIREMENTS.has(map_id):
				_assert_multi_street_patrol_coverage(map_id, definition, points)


func test_shared_y_sort_policy_for_every_definition() -> void:
	for definition in Registry.all():
		var parent := Node2D.new()
		var actors := Node2D.new()
		parent.add_child(actors)
		var grid := MapBuilder.build(definition)
		var result := MapAssembler.assemble(parent, definition, grid, actors)
		var terrain: MapTerrainRenderer = result["terrain"]
		var streamer: MapObjectChunkStreamer = result["object_streamer"]
		terrain.load_all_chunks()
		streamer.update_active_chunks(terrain.loaded_chunk_coordinates())
		var buildings_root: Node2D = result["building_root"]
		var props_root: Node2D = result["prop_root"]
		assert_true(actors.y_sort_enabled, "%s Actors must share Y-sort" % definition.map_id)
		assert_true(buildings_root.y_sort_enabled, "%s Buildings layer must Y-sort" % definition.map_id)
		assert_true(props_root.y_sort_enabled, "%s Props layer must Y-sort" % definition.map_id)
		for building in definition.buildings:
			var body := streamer.loaded_instance(building["id"]) as StaticBody2D
			assert_true(body != null, "%s missing building %s" % [definition.map_id, building["id"]])
			var footprint: Rect2 = building["footprint"]
			assert_eq(body.get_parent(), buildings_root, "%s building outside Buildings Y-sort layer" % definition.map_id)
			assert_eq(body.get_meta("y_sort_anchor"), MapBuildingRenderer.footprint_y_sort_anchor(footprint), "%s building Y-sort anchor" % definition.map_id)
		for prop in definition.props:
			var prop_node := streamer.loaded_instance(prop["id"]) as Node2D
			assert_true(prop_node != null, "%s missing prop %s" % [definition.map_id, prop["id"]])
			assert_eq(prop_node.get_parent(), props_root, "%s prop outside Props Y-sort layer" % definition.map_id)
			assert_eq(prop_node.get_meta("y_sort_anchor"), prop["position"], "%s prop Y-sort anchor" % definition.map_id)
		parent.free()


func test_source_references_resolve_and_archive_sources_remain_present() -> void:
	var definitions := Registry.by_id()
	for row in _manifest.get("maps", []):
		var definition: MapDefinition = definitions[String(row["id"])]
		assert_true(FileAccess.file_exists("res://%s" % row["scene"]), "Missing source scene %s" % row["scene"])
		assert_false(definition.source_references.is_empty(), "%s source references are empty" % definition.map_id)
		for reference in definition.source_references:
			var path := reference if reference.begins_with("res://") else "res://%s" % reference
			assert_true(FileAccess.file_exists(path), "%s stale source reference: %s" % [definition.map_id, reference])


func test_capture_policy_and_pngs_are_present() -> void:
	var capture: Dictionary = _manifest.get("capture", {})
	assert_eq(capture.get("viewport_px"), [1600.0, 900.0])
	assert_eq(capture.get("world_scale"), 0.5)
	assert_true(bool(capture.get("legend", false)))
	for row in _manifest.get("maps", []):
		var path := "res://%s/%s" % [capture.get("directory", ""), row.get("capture", "")]
		assert_true(FileAccess.file_exists(path), "Missing map audit capture: %s" % path)


func _assert_multi_street_patrol_coverage(map_id: String, definition: MapDefinition, points: Array) -> void:
	var requirement: Dictionary = MULTI_STREET_PATROL_REQUIREMENTS[map_id]
	assert_true(points.size() >= int(requirement["min_points"]), "%s patrol needs multi-street coverage (>= %d points)" % [map_id, int(requirement["min_points"])])
	assert_false(points.is_empty(), "%s patrol points missing" % map_id)
	var min_cell := Vector2i(9999, 9999)
	var max_cell := Vector2i(-9999, -9999)
	var cell_size := float(definition.cell_size)
	for point in points:
		var cell := Vector2i(int(floor(float(point.x) / cell_size)), int(floor(float(point.y) / cell_size)))
		min_cell = Vector2i(mini(min_cell.x, cell.x), mini(min_cell.y, cell.y))
		max_cell = Vector2i(maxi(max_cell.x, cell.x), maxi(max_cell.y, cell.y))
	var span := max_cell - min_cell
	assert_true(span.x >= int(requirement["min_span_x"]), "%s patrol span.x %d below multi-street minimum %d" % [map_id, span.x, int(requirement["min_span_x"])])
	assert_true(span.y >= int(requirement["min_span_y"]), "%s patrol span.y %d below multi-street minimum %d" % [map_id, span.y, int(requirement["min_span_y"])])


func _load_manifest() -> Dictionary:
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		fail("Cannot read %s" % MANIFEST_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		fail("Invalid map audit manifest JSON")
		return {}
	return parsed
