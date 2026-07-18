extends "res://tests/godot/test_case.gd"

const Coast := preload("res://scripts/map/definitions/outdoor/coast_harbor_definitions.gd")
const Villages := preload("res://scripts/map/definitions/outdoor/village_monastery_definitions.gd")
const Castles := preload("res://scripts/map/definitions/outdoor/castle_definitions.gd")
const Wilderness := preload("res://scripts/map/definitions/outdoor/wilderness_event_definitions.gd")
const Factory := preload("res://scripts/map/definitions/outdoor/outdoor_map_factory.gd")


func test_all_seventeen_definitions_validate_and_are_inactive() -> void:
	var definitions := _all()
	assert_eq(definitions.size(), 16)
	var ids: Dictionary = {}
	for definition in definitions:
		assert_eq(definition.scope, &"prototype")
		assert_false(definition.active)
		assert_false(bool(definition.get_meta("playable", true)))
		assert_eq(definition.get_meta("inspection_spawn_id"), &"prototype_inspection")
		assert_true(definition.transitions.is_empty())
		assert_true(definition.validate().is_empty(), "%s: %s" % [definition.map_id, definition.validate()])
		assert_false(ids.has(definition.map_id), "Duplicate outdoor map ID: %s" % definition.map_id)
		ids[definition.map_id] = true


func test_every_map_has_complete_terrain_coverage() -> void:
	for definition in _all():
		var grid := MapBuilder.build(definition)
		assert_eq(grid.cells.size(), definition.size_cells.x * definition.size_cells.y)
		for y in grid.size_cells.y:
			for x in grid.size_cells.x:
				assert_false(grid.get_terrain(Vector2i(x, y)).is_empty(), "Terrain gap in %s" % definition.map_id)


func test_landmarks_are_distinct_and_reusable_primitives_are_used() -> void:
	for definition in _all():
		assert_true(definition.interaction_anchors.size() >= 3, "%s needs distinct landmarks" % definition.map_id)
		var ids: Dictionary = {}
		var positions: Dictionary = {}
		for anchor in definition.interaction_anchors:
			assert_false(ids.has(anchor["id"]))
			assert_false(positions.has(anchor["position"]), "Landmarks overlap in %s" % definition.map_id)
			ids[anchor["id"]] = true
			positions[anchor["position"]] = true
		for building in definition.buildings:
			assert_true(building.has("primitive"))
		for prop in definition.props:
			assert_true(prop.has("primitive"))


func test_collisions_match_all_declared_structure_footprints() -> void:
	for definition in _all():
		for building in definition.buildings:
			var body := MapBuildingRenderer.create_building(building)
			var collision := body.get_child(0) as CollisionShape2D
			var shape := collision.shape as RectangleShape2D
			var actual := Rect2(body.position + collision.position - shape.size * 0.5, shape.size)
			assert_eq(actual, building["footprint"], "Collision drift in %s/%s" % [definition.map_id, building["id"]])
			body.free()


func test_inspection_routes_are_stable_and_clear_of_hard_exclusions() -> void:
	for definition in _all():
		assert_eq(definition.patrols.size(), 1)
		assert_eq(definition.patrols[0]["id"], Factory.INSPECTION_ROUTE)
		var points: Array = definition.patrols[0]["points"]
		assert_true(points.size() >= 5)
		assert_eq(points[0], definition.player_spawn)
		for point in points:
			var cell := Vector2i(floori(point.x / definition.cell_size), floori(point.y / definition.cell_size))
			for exclusion in definition.excluded_areas:
				assert_false(exclusion.has_point(cell), "Route crosses exclusion in %s" % definition.map_id)


func test_fingerprints_are_deterministic() -> void:
	var first := _fingerprints(_all())
	var second := _fingerprints(_all())
	assert_eq(first, second)
	for value in first.values():
		assert_eq(String(value).length(), 64)


func test_outdoor_palette_covers_every_extended_material() -> void:
	var outdoor_terrains: Array[StringName] = [
		MapTypes.TERRAIN_MEADOW,
		MapTypes.TERRAIN_COAST_SAND,
		MapTypes.TERRAIN_STRAW,
		MapTypes.TERRAIN_FARM_SOIL,
		MapTypes.TERRAIN_MUD,
		MapTypes.TERRAIN_FOREST_FLOOR,
		MapTypes.TERRAIN_BOG,
		MapTypes.TERRAIN_CASTLE_PAVING,
		MapTypes.TERRAIN_SHALLOW_WATER,
		MapTypes.TERRAIN_DEEP_WATER,
	]
	for terrain in outdoor_terrains:
		assert_ne(OutdoorTerrainPalette.color(terrain), Color.MAGENTA)


func test_padise_uses_one_definition_with_two_phases() -> void:
	var padise := Villages.padise_monastery()
	assert_eq(padise.get_meta("phases"), [&"before_attack", &"after_attack"])
	assert_eq(_all().filter(func(definition): return String(definition.map_id).contains("padise")).size(), 1)


func test_no_snow_or_legacy_transition_activation() -> void:
	for definition in _all():
		var used := MapBuilder.build(definition).used_terrain_ids()
		assert_false(used.has(&"snow"))
		assert_true(definition.transitions.is_empty())


func _all() -> Array[MapDefinition]:
	var definitions: Array[MapDefinition] = []
	definitions.append_array(Coast.all())
	definitions.append_array(Villages.all())
	definitions.append_array(Castles.all())
	definitions.append_array(Wilderness.all())
	return definitions


func _fingerprints(definitions: Array[MapDefinition]) -> Dictionary:
	var result: Dictionary = {}
	for definition in definitions:
		result[definition.map_id] = definition.fingerprint
	return result
