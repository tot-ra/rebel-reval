extends "res://tests/godot/test_case.gd"

const NORTH_RRMAP_PATH := "res://content/maps/reval_harbor_north.rrmap"
const EAST_RRMAP_PATH := "res://content/maps/reval_harbor_east.rrmap"
const HarborNorthDefinition := preload("res://scripts/map/definitions/outdoor/reval_harbor_north_definition.gd")
const HarborEastDefinition := preload("res://scripts/map/definitions/outdoor/reval_harbor_east_definition.gd")


func test_split_harbor_rrmaps_parse_and_are_larger() -> void:
	var north := MapRrmapParser.parse_file(NORTH_RRMAP_PATH)
	assert_true(north.is_ok(), str(north.formatted_diagnostics()))
	if north.is_ok():
		assert_eq(north.blueprint.map_id, &"reval_harbor_north")
		assert_eq(north.definition.size_cells, Vector2i(160, 72))
		assert_eq(north.definition.surroundings_sides.get(&"north"), &"water")
	var east := MapRrmapParser.parse_file(EAST_RRMAP_PATH)
	assert_true(east.is_ok(), str(east.formatted_diagnostics()))
	if east.is_ok():
		assert_eq(east.blueprint.map_id, &"reval_harbor_east")
		assert_eq(east.definition.size_cells, Vector2i(144, 64))
		assert_eq(east.definition.surroundings_sides.get(&"north"), &"water")
		assert_eq(east.definition.surroundings_sides.get(&"west"), &"town")


func test_harbors_extend_open_water_past_northern_edge() -> void:
	for definition: MapDefinition in [HarborNorthDefinition.create(), HarborEastDefinition.create()]:
		var view := MapView3D.create(definition, MapBuilder.build(definition))
		assert_true(
			view.has_node("Surroundings/Water_north"),
			"%s must continue the Baltic basin northward" % String(definition.map_id)
		)
		assert_false(view.has_node("Surroundings/Apron"), "%s must not paint a default meadow apron" % String(definition.map_id))
		assert_false(view.has_node("Surroundings/SpruceCanopies"), "%s must not spawn woodland past the quay" % String(definition.map_id))
		view.free()


func test_fishing_harbor_has_boats_moored_on_water() -> void:
	var definition: MapDefinition = HarborEastDefinition.create()
	var grid := MapBuilder.build(definition)
	var boats: Array[Dictionary] = []
	for prop in definition.props:
		if prop.get("kind") == MapTypes.PROP_KIND_FISHING_BOAT:
			boats.append(prop)
	assert_eq(boats.size(), 6, "Fishing Harbour needs working boats at its three piers")
	for boat in boats:
		assert_true(boat.has("footprint"), "%s must reserve an authored water footprint" % boat["id"])
		var footprint: Rect2 = boat["footprint"]
		var cell_rect := Rect2i(
			Vector2i(footprint.position / float(definition.cell_size)),
			Vector2i(footprint.size / float(definition.cell_size))
		)
		for y in range(cell_rect.position.y, cell_rect.end.y):
			for x in range(cell_rect.position.x, cell_rect.end.x):
				assert_true(
					MapTypes.WATER_TERRAINS.has(grid.get_terrain(Vector2i(x, y))),
					"%s must stay in the harbour basin" % boat["id"]
				)


func test_east_harbor_connects_back_to_lower_town() -> void:
	var definition: MapDefinition = HarborEastDefinition.create()
	var transition_by_id: Dictionary = {}
	for transition in definition.transitions:
		transition_by_id[transition["id"]] = transition
	assert_true(transition_by_id.has(&"to_reval_east"))
	var to_town: Dictionary = transition_by_id[&"to_reval_east"]
	assert_eq(to_town["destination_scene_id"], &"reval_east")
	assert_eq(to_town["destination_spawn_id"], &"viru_road_boundary")
	assert_eq(to_town["spawn_id"], &"from_reval_east")
	assert_true(DoorNavigator.has_spawn(&"reval_harbor_east", &"from_reval_east"))
	assert_true(DoorNavigator.has_spawn(&"reval_east", &"viru_road_boundary"))


func test_split_harbor_maps_connect_to_each_other() -> void:
	var north: MapDefinition = HarborNorthDefinition.create()
	var east: MapDefinition = HarborEastDefinition.create()
	var north_transitions: Dictionary = {}
	for transition in north.transitions:
		north_transitions[transition["id"]] = transition
	var east_transitions: Dictionary = {}
	for transition in east.transitions:
		east_transitions[transition["id"]] = transition
	assert_eq(north_transitions[&"to_harbor_east"]["destination_scene_id"], &"reval_harbor_east")
	assert_eq(north_transitions[&"to_harbor_east"]["destination_spawn_id"], &"from_harbor_north")
	assert_eq(east_transitions[&"to_harbor_north"]["destination_scene_id"], &"reval_harbor_north")
	assert_eq(east_transitions[&"to_harbor_north"]["destination_spawn_id"], &"from_harbor_east")


func test_lower_town_routes_to_harbor_not_warehouse() -> void:
	var definition: MapDefinition = preload(
		"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
	).create()
	for transition in definition.transitions:
		if transition["id"] == &"viru_road_boundary":
			assert_eq(transition["destination_scene_id"], &"reval_harbor_east")
			return
	push_error("viru_road_boundary transition missing")
