extends "res://tests/godot/test_case.gd"

const NorthQuarterDefinition := preload("res://scripts/map/definitions/prototypes/north_quarter_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")


func test_north_quarter_prototype_bounds_and_spine() -> void:
	var definition: MapDefinition = NorthQuarterDefinition.create()
	assert_eq(definition.size_cells, Vector2i(260, 140))
	assert_true(MapBuilder.validate(definition).is_empty())
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	assert_true(MapVerification.has_anchor(definition, &"pikk_street_spine"))
	assert_true(MapVerification.has_anchor(definition, &"merchant_court"))
	assert_true(
		MapVerification.route_exists(
			definition,
			grid,
			definition.player_spawn,
			MapVerification.anchor_position(definition, &"pikk_street_spine")
		)
	)
	assert_true(
		MapVerification.route_exists(
			definition,
			grid,
			definition.player_spawn,
			MapVerification.anchor_position(definition, &"merchant_court")
		)
	)


func test_merchant_district_uses_cobble_only_on_the_primary_port_road() -> void:
	var definition: MapDefinition = NorthQuarterDefinition.create()
	assert_eq(definition.base_terrain, MapTypes.TERRAIN_DIRT)
	var grid := MapBuilder.build(definition)
	var cobble := 0
	var earth := 0
	var grass := 0
	var total: int = definition.size_cells.x * definition.size_cells.y
	for y in range(definition.size_cells.y):
		for x in range(definition.size_cells.x):
			match grid.get_terrain(Vector2i(x, y)):
				MapTypes.TERRAIN_COBBLESTONE:
					cobble += 1
				MapTypes.TERRAIN_DIRT, MapTypes.TERRAIN_MUD, MapTypes.TERRAIN_SAND:
					earth += 1
				MapTypes.TERRAIN_GRASS:
					grass += 1
	assert_true(cobble > 0, "Pikk and the Coastal Gate approach still need a paved primary road")
	assert_true(cobble <= int(total * 0.05), "Cobble must be rare rather than a merchant-ward default")
	assert_true(earth >= int(total * 0.80), "Earth, mud, and compacted sand must dominate streets and work yards")
	assert_true(grass >= int(total * 0.10), "Wall verges and rear court greenery must remain visible")
	assert_eq(grid.get_terrain(Vector2i(104, 100)), MapTypes.TERRAIN_COBBLESTONE, "Pikk remains the paved port spine")
	assert_eq(grid.get_terrain(Vector2i(138, 100)), MapTypes.TERRAIN_DIRT, "Lai remains an unpaved secondary lane")
	assert_eq(grid.get_terrain(Vector2i(50, 20)), MapTypes.TERRAIN_SAND, "Loading aprons use compacted sand rather than dressed stone")


func test_merchant_district_has_dense_varied_houses_warehouses_and_yards() -> void:
	var definition: MapDefinition = NorthQuarterDefinition.create()
	var ordinary_buildings := 0
	var warehouse_buildings := 0
	var material_pairs: Dictionary = {}
	for building in definition.buildings:
		if building.get("kind") != MapTypes.BUILDING_KIND_HOUSE:
			continue
		ordinary_buildings += 1
		if String(building["id"]).contains("warehouse") or String(building["id"]).contains("storehouse"):
			warehouse_buildings += 1
		var pair := "%s/%s" % [building.get("wall_material", &""), building.get("roof_material", &"")]
		material_pairs[pair] = true
	assert_true(ordinary_buildings >= 70, "Merchant ward should read as property rows, not isolated houses in a plaza")
	assert_true(warehouse_buildings >= 12, "Warehousing should become conspicuous toward the Coastal Gate")
	assert_true(material_pairs.size() >= 7, "Stone, plaster, timber/log and varied roofs must break repeated facade runs")

	for prop_kind in [
		MapTypes.PROP_KIND_CARGO_CRATES,
		MapTypes.PROP_KIND_TRADE_GOODS,
		MapTypes.PROP_KIND_TIMBER_FENCE,
	]:
		assert_true(_has_prop_kind(definition, prop_kind), "Missing merchant-yard prop kind %s" % prop_kind)
	assert_false(_has_prop_kind(definition, MapTypes.PROP_KIND_CATTLE), "Cattle are runtime penned fauna (P4-023g)")
	assert_false(_has_prop_kind(definition, MapTypes.PROP_KIND_SHEEP), "Sheep are runtime penned fauna (P4-023g)")
	assert_true(_pen_fence_count(definition) >= 8, "Merchant pens keep static timber-fence dressing")


func test_merchant_district_has_three_sided_walls_dated_towers_and_harbor_gate() -> void:
	var definition: MapDefinition = NorthQuarterDefinition.create()
	for wall_id in [&"city_wall_north_west", &"city_wall_north_east", &"city_wall_west", &"city_wall_east"]:
		assert_false(_building_by_id(definition, wall_id).is_empty(), "Missing Merchant District wall %s" % wall_id)
	for tower_id in [&"coast_gate_west_tower", &"merchant_wall_tower_northwest"]:
		var tower := _building_by_id(definition, tower_id)
		assert_true(bool(tower.get("tower", false)), "%s must be completed in the conservative 1343 registry" % tower_id)
		var node := MapViewMeshBuilder.build_building(tower, definition.cell_size)
		assert_true((node.get_node("Walls") as MeshInstance3D).mesh is CylinderMesh)
		node.free()
	for unfinished_id in [&"coast_gate_east_tower", &"merchant_wall_tower_west_mid", &"merchant_wall_tower_east_mid"]:
		assert_false(bool(_building_by_id(definition, unfinished_id).get("tower", true)), "%s must not render as completed 1343 fabric" % unfinished_id)
	var harbor_transition := _transition_by_id(definition, &"to_reval_harbor")
	var coast_gate := _landmark_by_id(definition, &"coast_gate_arch")
	assert_eq(harbor_transition.get("view_landmark_id", &""), &"coast_gate_arch")
	assert_true((coast_gate["rect"] as Rect2).encloses(harbor_transition["rect"]), "Great Coast Gate must cover the route to Trade Harbour")


func test_coastal_gate_preserves_1343_single_tower_profile() -> void:
	var definition: MapDefinition = NorthQuarterDefinition.create()
	var completed_tower := _building_by_id(definition, &"coast_gate_west_tower")
	var eastern_mass := _building_by_id(definition, &"coast_gate_east_tower")
	assert_true(
		bool(completed_tower.get("tower", false)),
		"The 1343 Coastal Gate keeps its probable completed tower"
	)
	assert_false(
		bool(eastern_mass.get("tower", true)),
		"The eastern gate mass must not become a second completed tower"
	)

	var gate_arch := _landmark_by_id(definition, &"coast_gate_arch")
	assert_false(gate_arch.is_empty(), "The Coastal Gate arch keeps its stable landmark ID")
	assert_eq(gate_arch.get("id", &""), &"coast_gate_arch")

	for building: Dictionary in definition.buildings:
		var building_id := String(building.get("id", &"")).to_lower()
		assert_false(
			building_id.contains("barbican"),
			"1343 exterior must omit barbican markers"
		)
		assert_false(
			building_id.contains("fat") and building_id.contains("margaret"),
			"1343 exterior must omit Fat Margaret markers"
		)
	for landmark: Dictionary in definition.view_landmarks:
		var landmark_id := String(landmark.get("id", &"")).to_lower()
		assert_false(
			landmark_id.contains("barbican"),
			"1343 landmarks must omit barbican markers"
		)
		assert_false(
			landmark_id.contains("fat") and landmark_id.contains("margaret"),
			"1343 landmarks must omit Fat Margaret markers"
		)


func test_coastal_gate_1343_exceptional_contract_is_inactive_and_timber() -> void:
	var definition: MapDefinition = NorthQuarterDefinition.create()
	assert_false(definition.active, "North Quarter must remain an inactive prototype")

	var gate_arch := _landmark_by_id(definition, &"coast_gate_arch")
	assert_eq(gate_arch.get("kind", &""), &"gate_arch")
	assert_eq(
		gate_arch.get("door_material", &""),
		&"wood",
		"The 1343 Coastal Gate keeps a timber leaf rather than a later masonry/barbican treatment"
	)
	assert_eq(
		gate_arch.get("top_px", 0),
		240.0,
		"The exceptional gate remains a restrained low gate mass"
	)

	var completed_tower := _building_by_id(definition, &"coast_gate_west_tower")
	var eastern_mass := _building_by_id(definition, &"coast_gate_east_tower")
	assert_true(
		bool(completed_tower.get("tower", false)),
		"The west gate tower remains the only completed tower"
	)
	assert_false(
		bool(eastern_mass.get("tower", true)),
		"The east gate mass must stay below the single-tower profile"
	)


func test_merchant_district_connects_to_monastery_district() -> void:
	var definition: MapDefinition = NorthQuarterDefinition.create()
	var transition_by_id: Dictionary = {}
	for transition in definition.transitions:
		transition_by_id[transition["id"]] = transition
	assert_true(transition_by_id.has(&"to_monastery"))
	var to_monastery: Dictionary = transition_by_id[&"to_monastery"]
	assert_eq(to_monastery["destination_scene_id"], &"reval_monastery")
	assert_eq(to_monastery["destination_spawn_id"], &"from_reval_north")
	assert_eq(to_monastery["spawn_id"], &"from_monastery")


func test_north_quarter_workshop_life_dressing() -> void:
	var definition: MapDefinition = NorthQuarterDefinition.create()
	var workshop_kinds := {
		MapTypes.PROP_KIND_SAIL_CLOTH_BALE: false,
		MapTypes.PROP_KIND_COOPER_STAVES: false,
		MapTypes.PROP_KIND_ROPE_COIL: false,
		MapTypes.PROP_KIND_MARKET_GOODS_PALLET: false,
	}
	for prop in definition.props:
		var kind: StringName = prop.get("kind", &"")
		if workshop_kinds.has(kind):
			workshop_kinds[kind] = true
	for workshop_kind in workshop_kinds:
		assert_true(workshop_kinds[workshop_kind], "Merchant ward needs workshop prop %s" % String(workshop_kind))
	assert_true(
		_prop_near_building(definition, &"sailmakers_loft_bales", &"sailmakers_loft", 6),
		"Sail cloth bales must sit beside sailmakers_loft"
	)
	assert_true(
		_prop_near_building(definition, &"cooperage_shed_staves", &"cooperage_shed", 6),
		"Cooper staves must sit beside cooperage_shed"
	)
	assert_true(
		_prop_near_building(definition, &"ropemakers_shed_coils", &"ropemakers_shed", 8),
		"Rope coils must sit beside ropemakers_shed"
	)
	assert_true(
		_prop_near_building(definition, &"warehouse_west_court_pallet", &"warehouse_west_court_a", 8),
		"West warehouse court needs a goods pallet"
	)
	assert_true(
		_prop_near_building(definition, &"warehouse_east_court_pallet", &"warehouse_east_court_a", 8),
		"East warehouse court needs a goods pallet"
	)
	var grid := MapBuilder.build(definition)
	var patrol := definition.patrols[0]["points"] as Array
	for point in patrol:
		assert_true(
			MapVerification.is_walkable_point(definition, grid, point),
			"Patrol point %s must stay walkable after workshop dressing" % point
		)


func test_north_quarter_connects_to_harbor() -> void:
	var definition: MapDefinition = NorthQuarterDefinition.create()
	var transition_by_id: Dictionary = {}
	for transition in definition.transitions:
		transition_by_id[transition["id"]] = transition
	assert_true(transition_by_id.has(&"to_reval_harbor"))
	var to_harbor: Dictionary = transition_by_id[&"to_reval_harbor"]
	assert_eq(to_harbor["destination_scene_id"], &"reval_harbor_north")
	assert_eq(to_harbor["destination_spawn_id"], &"from_reval_north")
	assert_eq(to_harbor["spawn_id"], &"to_reval_harbor")


func _transition_by_id(definition: MapDefinition, transition_id: StringName) -> Dictionary:
	for transition in definition.transitions:
		if transition["id"] == transition_id:
			return transition
	return {}


func _building_by_id(definition: MapDefinition, building_id: StringName) -> Dictionary:
	for building in definition.buildings:
		if building["id"] == building_id:
			return building
	return {}


func _landmark_by_id(definition: MapDefinition, landmark_id: StringName) -> Dictionary:
	for landmark in definition.view_landmarks:
		if landmark["id"] == landmark_id:
			return landmark
	return {}


func _has_prop_kind(definition: MapDefinition, prop_kind: StringName) -> bool:
	for prop in definition.props:
		if prop["kind"] == prop_kind:
			return true
	return false


func _pen_fence_count(definition: MapDefinition) -> int:
	var count := 0
	for prop in definition.props:
		if prop["kind"] == MapTypes.PROP_KIND_TIMBER_FENCE:
			count += 1
	return count


func _prop_near_building(
	definition: MapDefinition,
	prop_id: StringName,
	building_id: StringName,
	max_distance_cells: int
) -> bool:
	var prop := _prop_by_id(definition, prop_id)
	var building := _building_by_id(definition, building_id)
	if prop.is_empty() or building.is_empty():
		return false
	var prop_pos: Vector2 = prop.get("position", Vector2.ZERO)
	var footprint: Rect2 = building["footprint"]
	var closest := Vector2(
		clampf(prop_pos.x, footprint.position.x, footprint.end.x),
		clampf(prop_pos.y, footprint.position.y, footprint.end.y)
	)
	return prop_pos.distance_to(closest) <= float(max_distance_cells * definition.cell_size)


func _prop_by_id(definition: MapDefinition, prop_id: StringName) -> Dictionary:
	for prop in definition.props:
		if prop["id"] == prop_id:
			return prop
	return {}
