extends "res://tests/godot/test_case.gd"

const RRMAP_PATH := "res://content/maps/viru_gate_foreland.rrmap"
const ForelandDefinition := preload("res://scripts/map/definitions/outdoor/viru_gate_foreland_definition.gd")


func test_pirita_parses_at_one_and_a_half_size_and_stays_inactive() -> void:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	assert_eq(parsed.blueprint.map_id, &"viru_gate_foreland", "stable transition/save ID must not change")
	assert_eq(parsed.definition.location, &"loc.reval.pirita")
	assert_eq(parsed.definition.size_cells, Vector2i(168, 120))
	assert_eq(parsed.definition.scope, &"prototype")
	assert_false(parsed.definition.active)
	assert_eq(LocationHud.display_name_for(parsed.definition), "Pirita")
	for side in [&"north", &"east", &"south", &"west"]:
		assert_eq(parsed.definition.surroundings_sides.get(side), &"woodland")


func test_pirita_river_meanders_south_to_north_with_one_dry_bridge_crossing() -> void:
	var definition: MapDefinition = ForelandDefinition.create()
	var grid := MapBuilder.build(definition)
	var channel_centers: Dictionary = {}
	var westmost_center := definition.size_cells.x
	var eastmost_center := 0
	for y in range(0, definition.size_cells.y):
		var water_xs: Array[int] = []
		for x in definition.size_cells.x:
			if MapTypes.WATER_TERRAINS.has(grid.get_terrain(Vector2i(x, y))):
				water_xs.append(x)
		if y >= 59 and y < 69:
			assert_true(water_xs.is_empty(), "bridge row %d must stay dry" % y)
			continue
		assert_true(water_xs.size() >= 15, "river channel must continue through row %d" % y)
		var center: int = floori(float(water_xs.front() + water_xs.back()) * 0.5)
		channel_centers[center] = true
		westmost_center = mini(westmost_center, center)
		eastmost_center = maxi(eastmost_center, center)
	assert_true(channel_centers.size() >= 6, "Pirita needs several bends instead of one straight channel")
	assert_true(eastmost_center - westmost_center >= 9, "Pirita meanders must read across the wide landscape")
	assert_eq(grid.get_terrain(Vector2i(75, 63)), MapTypes.TERRAIN_TIMBER_FLOOR)
	assert_eq(grid.get_terrain(Vector2i(85, 63)), MapTypes.TERRAIN_TIMBER_FLOOR)
	assert_eq(grid.get_terrain(Vector2i(96, 63)), MapTypes.TERRAIN_TIMBER_FLOOR)


func test_pirita_current_is_clear_and_plant_free() -> void:
	var definition: MapDefinition = ForelandDefinition.create()
	var grid := MapBuilder.build(definition)
	for y in definition.size_cells.y:
		for x in definition.size_cells.x:
			var cell := Vector2i(x, y)
			if not MapTypes.WATER_TERRAINS.has(grid.get_terrain(cell)):
				continue
			assert_eq(grid.get_terrain(cell), MapTypes.TERRAIN_RIVER_WATER)
			assert_true(grid.get_style_variant(cell).is_empty(), "flowing water must clear inherited meadow plants")
	var river := MapViewMaterials.water_surface(MapTypes.TERRAIN_RIVER_WATER)
	var pond := MapViewMaterials.water_surface(MapTypes.TERRAIN_WATER)
	assert_eq(float(river.get_shader_parameter("bed_vegetation")), 0.0)
	assert_true(
		float(river.get_shader_parameter("depth_absorption"))
		< float(pond.get_shader_parameter("depth_absorption")),
		"fast Pirita water should transmit more bed light than sheltered water"
	)
	for target in MapVisualStyle.ALL_TARGETS:
		assert_ne(MapVisualStyle.terrain_color(MapTypes.TERRAIN_RIVER_WATER, target, MapVisualStyle.TIME_DAY), Color.MAGENTA)

func test_pirita_uses_rural_livestock_and_has_no_early_bridgettine_church() -> void:
	var definition: MapDefinition = ForelandDefinition.create()
	var horse_count := 0
	var sheep_count := 0
	for prop in definition.props:
		if prop.get("kind") == MapTypes.PROP_KIND_HORSE:
			horse_count += 1
		if prop.get("kind") == MapTypes.PROP_KIND_SHEEP:
			sheep_count += 1
	assert_eq(horse_count, 2)
	assert_eq(sheep_count, 3)
	for building in definition.buildings:
		var description := "%s %s" % [building.get("id", ""), building.get("primitive", "")]
		assert_false(description.to_lower().contains("church"))
		assert_false(description.to_lower().contains("brigit"))


func test_pirita_reciprocates_workers_district_with_stable_ids() -> void:
	var pirita: MapDefinition = ForelandDefinition.create()
	var town: MapDefinition = preload(
		"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
	).create()
	var from_town := _transition(town, &"viru_road_boundary")
	var to_town := _transition(pirita, &"to_reval_east")
	assert_eq(from_town["destination_scene_id"], &"viru_gate_foreland")
	assert_eq(from_town["destination_spawn_id"], &"from_reval_east")
	assert_eq(to_town["destination_scene_id"], &"reval_east")
	assert_eq(to_town["destination_spawn_id"], &"viru_road_boundary")
	assert_true(DoorNavigator.has_spawn(&"viru_gate_foreland", &"from_reval_east"))


func test_kalamaja_is_not_a_pirita_neighbor() -> void:
	var kalamaja: MapDefinition = preload(
		"res://scripts/map/definitions/outdoor/reval_harbor_east_definition.gd"
	).create()
	for transition in kalamaja.transitions:
		assert_ne(transition.get("destination_scene_id"), &"reval_east")
	assert_false(DoorNavigator.has_spawn(&"reval_harbor_east", &"from_reval_east"))


func test_pirita_masks_off_limits_edges_with_dense_woodland() -> void:
	var definition: MapDefinition = ForelandDefinition.create()
	var view := MapView3D.create(definition, MapBuilder.build(definition))
	for side in ["north", "east", "south", "west"]:
		assert_true(view.has_node("Surroundings/WoodlandApron_%s" % side))
	assert_true(_tree_instance_count(view.get_node("Surroundings")) > 100)
	view.free()


func _tree_instance_count(root: Node) -> int:
	var total := 0
	for child in root.get_children():
		if child is MultiMeshInstance3D and String(child.name).begins_with("TreeTrunks"):
			total += (child as MultiMeshInstance3D).multimesh.instance_count
	return total


func _transition(definition: MapDefinition, transition_id: StringName) -> Dictionary:
	for transition in definition.transitions:
		if transition["id"] == transition_id:
			return transition
	fail("missing transition %s on %s" % [transition_id, definition.map_id])
	return {}
