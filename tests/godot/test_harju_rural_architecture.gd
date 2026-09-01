extends "res://tests/godot/test_case.gd"

const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")

const RRMAP_PATH := "res://content/maps/world_harju.rrmap"
const REQUIRED_ANCHOR_CELLS := {
	&"landmark_village_well": Vector2i(25, 15),
	&"landmark_threshing_barn": Vector2i(35, 12),
	&"landmark_split_fields": Vector2i(42, 6),
}


func test_harju_parses_as_an_inactive_evidence_linked_rural_prototype() -> void:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	assert_eq(parsed.definition.map_id, &"world.harju")
	assert_eq(parsed.definition.size_cells, Vector2i(52, 30))
	assert_eq(parsed.definition.scope, &"prototype")
	assert_false(parsed.definition.active)
	assert_true(
		"history/dossiers/hinterland/harju-village-and-manor.md"
		in parsed.definition.source_references
	)
	assert_true(
		"history/dossiers/architecture/rural-smoke-dwelling-and-farmstead-1343.md"
		in parsed.definition.source_references
	)


func test_harju_required_anchors_are_clear_and_reachable() -> void:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var definition: MapDefinition = parsed.definition
	var grid := MapBuilder.build(definition)
	var diagnostics := parsed.formatted_diagnostics()
	assert_false(
		diagnostics.has("MAP_ANCHOR_BLOCKED"),
		"Harju anchors must stay clear: %s" % str(diagnostics)
	)
	for anchor_id in REQUIRED_ANCHOR_CELLS:
		var expected_cell: Vector2i = REQUIRED_ANCHOR_CELLS[anchor_id]
		var anchor_position := MapVerification.anchor_position(definition, anchor_id)
		var anchor_cell := Vector2i(
			floori(anchor_position.x / definition.cell_size),
			floori(anchor_position.y / definition.cell_size)
		)
		assert_eq(
			anchor_cell,
			expected_cell,
			"Harju anchor %s moved unexpectedly" % anchor_id
		)
		assert_true(
			MapVerification.is_walkable_point(definition, grid, anchor_position),
			"Harju anchor %s must remain walkable" % anchor_id
		)
		assert_true(
			MapVerification.route_exists_exact(definition, grid, definition.player_spawn, anchor_position),
			"Harju inspection spawn must reach %s" % anchor_id
		)


func test_harju_village_well_anchor_matches_authored_prop() -> void:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var definition: MapDefinition = parsed.definition
	assert_eq(
		MapVerification.anchor_position(definition, &"landmark_village_well"),
		MapVerification.prop_position(definition, &"village_well"),
		"the village-well landmark must stay attached to its authored prop"
	)


func test_barn_dwelling_keeps_two_bays_and_rejects_late_rural_features() -> void:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var building := _building(parsed.definition, &"elder_farmstead")
	assert_eq(building.get("primitive"), &"barn_dwelling_1343")
	assert_eq(
		MapViewMeshBuilderBuildingHouses.house_style(building),
		MapViewMeshBuilderConfig.HOUSE_STYLE_LOG
	)
	assert_eq(
		MapViewMeshBuilderBuildingHouses.roof_style(building),
		MapViewMeshBuilderConfig.ROOF_STYLE_THATCH
	)
	var node := MapViewMeshBuilder.build_building(building, parsed.definition.cell_size)
	assert_true(node.has_node("DwellingDoor"), "rehetuba needs its own low boarded door")
	assert_true(node.has_node("ThreshingGate"), "rehealune needs a broad working gate")
	assert_true(
		node.has_node("BarnDwellingBaySeam"),
		"the conservative two-part plan must read externally"
	)
	assert_true(node.has_node("SmokeVent"), "the heated room needs an unglazed smoke/light aperture")
	assert_true(node.has_node("LogEnd_0_-1_-1"), "horizontal log construction needs corner heads")
	assert_true(node.has_node("ThatchRidge"), "barn-dwelling uses the conservative thatch lane")
	assert_true(node.has_node("FoundationPad_-1_-1"), "rural sill uses local packing stones")
	assert_false(node.has_node("Plinth"), "rural dwelling must not inherit a continuous urban plinth")
	assert_false(node.has_node("Chimney"), "1343 smoke-room oven is flueless")
	assert_false(node.has_node("Window0"), "later glazed window rhythms must not be back-projected")
	assert_false(node.has_node("DoorStep"), "rural doorway must not inherit the urban stone step")
	assert_false(node.has_node("WindowLights"), "unglazed smoke vents must not glow like city windows")
	node.free()


func test_rural_primitive_material_guard_rejects_masonry_and_tile_defaults() -> void:
	var building := {
		"id": &"guarded_smoke_cottage",
		"kind": MapTypes.BUILDING_KIND_HOUSE,
		"primitive": &"smoke_cottage_1343",
		"wall_material": &"stone",
		"roof_material": &"tile",
	}
	assert_eq(
		MapViewMeshBuilderBuildingHouses.house_style(building),
		MapViewMeshBuilderConfig.HOUSE_STYLE_LOG
	)
	assert_eq(
		MapViewMeshBuilderBuildingHouses.roof_style(building),
		MapViewMeshBuilderConfig.ROOF_STYLE_THATCH
	)
	building["roof_material"] = &"shingle"
	assert_eq(
		MapViewMeshBuilderBuildingHouses.roof_style(building),
		MapViewMeshBuilderConfig.ROOF_STYLE_SHINGLE
	)


func test_harju_farmyard_has_work_surfaces_storage_and_spring_livestock() -> void:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var required: Array[StringName] = [
		MapTypes.PROP_KIND_ROOT_CELLAR_MOUND,
		MapTypes.PROP_KIND_FARM_CART,
		MapTypes.PROP_KIND_KITCHEN_GARDEN,
		MapTypes.PROP_KIND_FIELD_STRIP,
		MapTypes.PROP_KIND_PASTURE_FENCE,
		MapTypes.PROP_KIND_CATTLE,
		MapTypes.PROP_KIND_SHEEP,
	]
	var present: Dictionary = {}
	for prop in parsed.definition.props:
		present[prop["kind"]] = true
	for kind in required:
		assert_true(present.has(kind), "Harju working yard is missing %s" % kind)


func test_harju_hay_ricks_form_a_field_group_clear_of_buildings() -> void:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var definition: MapDefinition = parsed.definition
	var hay_field := definition.cell_rect_to_world_rect(Rect2i(4, 23, 10, 5))
	var hay_ricks: Array[Dictionary] = []
	for prop in definition.props:
		if prop["kind"] == MapTypes.PROP_KIND_HAY_STACK:
			hay_ricks.append(prop)
	assert_eq(
		hay_ricks.size(),
		3,
		"the hay meadow needs a visible group rather than one barn-side stack"
	)
	var sizes: Dictionary = {}
	for rick in hay_ricks:
		var position: Vector2 = rick["position"]
		assert_true(
			hay_field.has_point(position),
			"%s must stand in the authored hay field" % rick["id"]
		)
		sizes[rick.get("style_variant", &"")] = true
		for building in definition.buildings:
			var footprint: Rect2 = building["footprint"]
			var closest := Vector2(
				clampf(position.x, footprint.position.x, footprint.end.x),
				clampf(position.y, footprint.position.y, footprint.end.y)
			)
			assert_true(
				position.distance_to(closest) > float(definition.cell_size * 3),
				"%s must not visually merge with %s" % [rick["id"], building["id"]]
			)
	assert_true(sizes.has(&"hay_stack.small"))
	assert_true(sizes.has(&"hay_stack.medium"))
	assert_true(sizes.has(&"hay_stack.tall"))


func test_harju_world_routes_keep_all_authored_neighbors_and_spawns() -> void:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var expected_routes := {
		&"road_to_reval": [&"viru_gate_foreland", &"from_world_harju", &"from_reval_east"],
		&"road_to_sacred_grove": [
			&"world_sacred_grove", &"from_world_harju", &"from_world_sacred_grove"
		],
		&"road_to_rebel_kings": [
			&"world_rebel_kings", &"from_world_harju", &"from_world_rebel_kings"
		],
		&"road_to_kanavere": [&"world_kanavere", &"from_world_harju", &"from_world_kanavere"],
		&"road_to_sojamae": [&"world_sojamae", &"from_world_harju", &"from_world_sojamae"],
	}
	var transitions_by_id: Dictionary = {}
	for transition in parsed.definition.transitions:
		transitions_by_id[transition["id"]] = transition
	assert_eq(transitions_by_id.size(), expected_routes.size())
	for transition_id in expected_routes:
		assert_true(transitions_by_id.has(transition_id), "Missing Harju route %s" % transition_id)
		if not transitions_by_id.has(transition_id):
			continue
		var transition: Dictionary = transitions_by_id[transition_id]
		var expected: Array = expected_routes[transition_id]
		assert_eq(transition["destination_scene_id"], expected[0])
		assert_eq(transition["destination_spawn_id"], expected[1])
		assert_eq(transition["spawn_id"], expected[2])


func _building(definition: MapDefinition, building_id: StringName) -> Dictionary:
	for building in definition.buildings:
		if building["id"] == building_id:
			return building
	fail("missing building %s" % building_id)
	return {}
