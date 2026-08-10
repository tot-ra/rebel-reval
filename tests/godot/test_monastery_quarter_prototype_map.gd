extends "res://tests/godot/test_case.gd"

const MonasteryQuarterDefinition := preload("res://scripts/map/definitions/prototypes/monastery_quarter_definition.gd")


func test_monastery_district_is_the_wide_lower_half_of_the_northern_ward() -> void:
	var definition: MapDefinition = MonasteryQuarterDefinition.create()
	assert_eq(definition.size_cells, Vector2i(260, 112))
	assert_true(definition.size_cells.x > definition.size_cells.y)
	assert_true(MapBuilder.validate(definition).is_empty())
	for anchor_id in [&"monastery_close", &"st_olaf_frontage", &"guild_frontage", &"from_reval_north"]:
		assert_true(MapVerification.has_anchor(definition, anchor_id), "Missing Monastery District anchor %s" % anchor_id)


func test_monastery_district_uses_earth_base_and_street_spines_not_blanket_cobble() -> void:
	# HISTORICAL_AUDIT monastery ground ranges + cross-map exclusion 1 forbid map-wide cobble.
	var definition: MapDefinition = MonasteryQuarterDefinition.create()
	assert_eq(definition.base_terrain, MapTypes.TERRAIN_DIRT)
	var grid := MapBuilder.build(definition)
	var cobble := 0
	var dirt_or_mud := 0
	var grass := 0
	var stone := 0
	var total: int = definition.size_cells.x * definition.size_cells.y
	for y in range(definition.size_cells.y):
		for x in range(definition.size_cells.x):
			match grid.get_terrain(Vector2i(x, y)):
				MapTypes.TERRAIN_COBBLESTONE:
					cobble += 1
				MapTypes.TERRAIN_DIRT, MapTypes.TERRAIN_MUD:
					dirt_or_mud += 1
				MapTypes.TERRAIN_GRASS:
					grass += 1
				MapTypes.TERRAIN_STONE:
					stone += 1
	assert_true(cobble <= int(total * 0.03), "Cobble must be limited to the primary Pikk spine")
	assert_true(dirt_or_mud >= int(total * 0.25), "Earth/mud/service yard share must reach the 25%% monastery floor")
	assert_true(grass >= int(total * 0.20), "Garden/grass share must remain substantial outside street spines")
	assert_true(stone < int(total * 0.20), "Stone closes must stay compact, not district-scale plazas")
	assert_true(
		MapVerification.has_anchor(definition, &"pikk_street_spine"),
		"Primary Pikk spine anchor must survive the street-surface pass"
	)
	assert_eq(grid.get_terrain(Vector2i(101, 50)), MapTypes.TERRAIN_COBBLESTONE, "Pikk remains the paved primary spine")
	assert_eq(grid.get_terrain(Vector2i(135, 50)), MapTypes.TERRAIN_DIRT, "Lai remains an unpaved secondary lane")


func test_monastery_district_has_dated_early_towers_and_later_wall_positions() -> void:
	var definition: MapDefinition = MonasteryQuarterDefinition.create()
	for wall_id in [&"monastery_city_wall_west_north", &"monastery_city_wall_west_south", &"monastery_city_wall_east"]:
		assert_false(_building_by_id(definition, wall_id).is_empty(), "Missing Monastery District wall %s" % wall_id)
	var east_wall := _building_by_id(definition, &"monastery_city_wall_east")
	assert_eq(
		east_wall["footprint"],
		definition.cell_rect_to_world_rect(Rect2i(225, 0, 3, 112)),
		"east curtain must continue to the southern map edge"
	)
	var workers: MapDefinition = preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd").create()
	var workers_wall := _building_by_id(workers, &"city_wall_north")
	assert_eq(east_wall.get("wall_color"), workers_wall.get("wall_color"), "district walls must share limestone color")
	assert_eq(east_wall.get("wall_height"), workers_wall.get("wall_height"), "district walls must share authored height")
	var view := MapView3D.create(definition, MapBuilder.build(definition))
	var streamer := view.object_streamer()
	for wall_id in [&"monastery_city_wall_east", &"monastery_wall_tower_northeast", &"monastery_wall_tower_east_mid", &"monastery_wall_tower_southeast"]:
		assert_true(
			streamer.loaded_instance(wall_id) != null,
			"%s must stay resident so the east curtain is visible between its towers" % wall_id
		)
	view.free()
	var grid := MapBuilder.build(definition)
	for y in [8, 24, 56, 88, 104]:
		assert_eq(grid.get_terrain(Vector2i(229, y)), MapTypes.TERRAIN_WATER, "outer ditch must follow the east wall")
	for y in [40, 48]:
		assert_eq(grid.get_terrain(Vector2i(229, y)), MapTypes.TERRAIN_DIRT, "outer gate must keep a dirt causeway through the ditch")
	assert_true(MapVerification.is_walkable_cell(definition, grid, Vector2i(229, 44)), "outer wall road causeway must remain walkable")
	for tower_id in [&"monastery_wall_tower_northwest", &"monastery_wall_tower_west_mid"]:
		var tower := _building_by_id(definition, tower_id)
		assert_true(bool(tower.get("tower", false)), "%s must be completed in the conservative 1343 registry" % tower_id)
		var node := MapViewMeshBuilder.build_building(tower, definition.cell_size)
		assert_true((node.get_node("Walls") as MeshInstance3D).mesh is CylinderMesh)
		node.free()
	for unfinished_id in [&"monastery_wall_tower_northeast", &"monastery_wall_tower_east_mid"]:
		assert_false(bool(_building_by_id(definition, unfinished_id).get("tower", true)), "%s must not render as a completed 1343 tower" % unfinished_id)


func test_monastery_district_links_the_merchant_civic_worker_and_toompea_maps() -> void:
	var definition: MapDefinition = MonasteryQuarterDefinition.create()
	var destinations: Dictionary = {}
	var route_destinations: Dictionary = {}
	for transition in definition.transitions:
		var destination: StringName = transition["destination_scene_id"]
		if destination in [&"reval_north", &"reval_east"]:
			route_destinations[transition["id"]] = transition["destination_spawn_id"]
		else:
			destinations[destination] = transition["destination_spawn_id"]
	assert_eq(route_destinations[&"to_reval_north"], &"from_monastery")
	assert_eq(route_destinations[&"to_reval_north_outer"], &"from_monastery_outer")
	assert_eq(destinations[&"reval_center"], &"to_reval_north")
	assert_eq(route_destinations[&"to_reval_east"], &"vene_district_boundary")
	assert_eq(route_destinations[&"to_reval_east_outer"], &"workers_outer_exit")
	assert_eq(destinations[&"reval_toompea"], &"from_reval_north")


func test_monastery_south_edge_previews_civic_and_workers_districts() -> void:
	var definition: MapDefinition = MonasteryQuarterDefinition.create()
	var surroundings := MapViewMeshBuilder.build_surroundings(definition)
	assert_true(surroundings.has_node("Neighbor_south"), "south edge needs the civic-centre preview")
	assert_true(
		surroundings.has_node("Neighbor_south_lower_town_slice/Buildings/Building_city_wall_north"),
		"south-east edge needs the authored Workers' District preview"
	)
	assert_false(
		surroundings.has_node("Neighbor_east"),
		"the travel-only outer-wall road must not place Workers' District east of the city wall"
	)
	surroundings.free()


func test_monastery_quarter_service_life_dressing() -> void:
	var definition: MapDefinition = MonasteryQuarterDefinition.create()
	var service_kinds := {
		MapTypes.PROP_KIND_HERB_DRYING_RACK: false,
		MapTypes.PROP_KIND_WASH_TUB: false,
		MapTypes.PROP_KIND_MARKET_GOODS_PALLET: false,
		MapTypes.PROP_KIND_BOAT_TIMBER_STACK: false,
		MapTypes.PROP_KIND_FARM_CART: false,
	}
	for prop in definition.props:
		var kind: StringName = prop.get("kind", &"")
		if service_kinds.has(kind):
			service_kinds[kind] = true
		var prop_id := String(prop.get("id", ""))
		if prop_id.contains("stall_") or prop_id.contains("well_") or prop_id.contains("workshop_"):
			assert_ne(
				prop.get("kind"),
				MapTypes.PROP_KIND_BARRELS,
				"%s must not remain a barrel placeholder" % prop_id
			)
	for service_kind in service_kinds:
		assert_true(service_kinds[service_kind], "Monastery quarter needs service prop %s" % String(service_kind))
	assert_true(
		_prop_near_prop(definition, &"convent_well_herbs", &"convent_well", 6),
		"Herb drying rack must sit beside convent_well"
	)
	assert_true(
		_prop_near_prop(definition, &"convent_well_wash", &"convent_well", 6),
		"Wash tub must sit beside convent_well"
	)
	assert_true(
		_prop_near_prop(definition, &"convent_well_goods", &"convent_well", 6),
		"Market goods pallet must sit beside convent_well"
	)
	assert_true(
		_prop_near_prop(definition, &"guild_stall_goods", &"guild_stall", 6),
		"Guild stall needs a goods pallet"
	)
	assert_true(
		_prop_near_building(definition, &"workshop_row_west_herbs", &"workshop_row_west", 6),
		"Workshop row west needs herb drying rack"
	)
	assert_true(
		_prop_near_building(definition, &"workshop_row_mid_tub", &"workshop_row_mid", 6),
		"Workshop row mid needs wash tub"
	)
	assert_true(
		_prop_near_building(definition, &"netmakers_timber", &"netmakers_loft", 6),
		"Netmakers loft needs timber stack"
	)
	assert_true(
		_prop_near_building(definition, &"workshop_service_cart", &"workshop_row_west", 10),
		"Service cart must sit in the workshop yard"
	)
	assert_true(
		_prop_near_building(definition, &"almonry_cart", &"convent_almonry", 8),
		"Farm cart must sit beside convent almonry"
	)
	assert_true(
		_prop_by_id(definition, &"service_barrels").is_empty(),
		"Generic service barrels must be retired where dedicated trade props exist"
	)
	var grid := MapBuilder.build(definition)
	for point in (definition.patrols[0]["points"] as Array):
		assert_true(
			MapVerification.is_walkable_point(definition, grid, point),
			"Patrol point %s must stay walkable after monastery dressing" % point
		)


func test_monastery_guild_rowfronts_avoid_later_monument_styles() -> void:
	# P4-023e: later Great Guild / Blackheads monuments must not read as 1343 fabric.
	var definition: MapDefinition = MonasteryQuarterDefinition.create()
	for building_id in [&"great_guild_front", &"blackheads_corner", &"brotherhood_wing"]:
		var building := _building_by_id(definition, building_id)
		assert_false(building.is_empty(), "Missing guild-row building %s" % building_id)
		assert_eq(
			building.get("wall_material", &""),
			&"plaster",
			"%s must use ordinary merchant plaster, not monumental guild limestone" % building_id
		)
		assert_eq(
			int(building.get("wall_height", 0)),
			120,
			"%s must stay at merchant-house height, not guild-hall scale" % building_id
		)


func test_monastery_st_olaf_frontage_opens_oleviste_church_interior() -> void:
	var definition: MapDefinition = MonasteryQuarterDefinition.create()
	var entry := _transition_by_id(definition, &"to_oleviste_church")
	assert_false(entry.is_empty(), "Monastery district must expose a St. Olaf church door")
	assert_eq(entry.get("destination_scene_id"), &"oleviste_church")
	assert_eq(entry.get("destination_spawn_id"), &"from_reval_monastery")
	assert_eq(entry.get("spawn_id"), &"to_oleviste_church")
	assert_eq(entry.get("building_id"), &"st_olaf_silhouette")


func _transition_by_id(definition: MapDefinition, transition_id: StringName) -> Dictionary:
	for transition in definition.transitions:
		if transition.get("id", &"") == transition_id:
			return transition
	return {}


func _building_by_id(definition: MapDefinition, building_id: StringName) -> Dictionary:
	for building in definition.buildings:
		if building["id"] == building_id:
			return building
	return {}


func _prop_by_id(definition: MapDefinition, prop_id: StringName) -> Dictionary:
	for prop in definition.props:
		if prop["id"] == prop_id:
			return prop
	return {}


func _prop_near_prop(
	definition: MapDefinition,
	prop_id: StringName,
	other_prop_id: StringName,
	max_distance_cells: int
) -> bool:
	var prop := _prop_by_id(definition, prop_id)
	var other := _prop_by_id(definition, other_prop_id)
	if prop.is_empty() or other.is_empty():
		return false
	var prop_pos: Vector2 = prop.get("position", Vector2.ZERO)
	var other_pos: Vector2 = other.get("position", Vector2.ZERO)
	return prop_pos.distance_to(other_pos) <= float(max_distance_cells * definition.cell_size)


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
