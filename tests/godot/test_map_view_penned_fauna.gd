extends "res://tests/godot/test_case.gd"

const FaunaContext := preload("res://scripts/map/view3d/map_view_fauna_context.gd")
const KalevSmithy := preload("res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd")
const LowerTownSlice := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const MapViewBridge := preload("res://scripts/map/view3d/map_view_bridge.gd")
const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")
const PennedFauna := preload("res://scripts/map/view3d/map_view_penned_fauna.gd")
const ForelandDefinition := preload(
	"res://scripts/map/definitions/outdoor/viru_gate_foreland_definition.gd"
)
const NorthQuarterDefinition := preload(
	"res://scripts/map/definitions/prototypes/north_quarter_definition.gd"
)


func test_penned_fowl_walks_in_straight_segments_instead_of_circling() -> void:
	var fauna := PennedFauna.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(fauna)
	fauna.configure(&"lower_town_slice", MammalSpecies.CONTEXT_LOWER_TOWN, 32)
	var fowl_species: Array[StringName] = [
		MammalSpecies.SPECIES_CHICKEN,
		MammalSpecies.SPECIES_DUCK,
		MammalSpecies.SPECIES_GOOSE,
	]
	var previous: Dictionary = {}
	var previous_heading: Dictionary = {}
	var moving_steps: Dictionary = {}
	var turns: Dictionary = {}
	for step in 200:
		for actor in fauna.fauna_actors():
			previous[actor.name] = actor.position
		fauna.sync(MammalSpecies.CONTEXT_LOWER_TOWN, 0.1, Vector3.ZERO, true)
		for actor in fauna.fauna_actors():
			if actor.get_meta(&"species", &"") not in fowl_species:
				continue
			var movement: Vector3 = actor.position - Vector3(previous[actor.name])
			if movement.length() < 0.0001:
				continue
			var heading := movement.normalized()
			moving_steps[actor.name] = int(moving_steps.get(actor.name, 0)) + 1
			if previous_heading.has(actor.name) and heading.dot(previous_heading[actor.name]) < 0.999:
				turns[actor.name] = int(turns.get(actor.name, 0)) + 1
			previous_heading[actor.name] = heading

	var checked := 0
	for actor in fauna.fauna_actors():
		if actor.get_meta(&"species", &"") not in fowl_species:
			continue
		var steps := int(moving_steps.get(actor.name, 0))
		if steps < 10:
			continue
		checked += 1
		assert_true(
			float(turns.get(actor.name, 0)) <= float(steps) * 0.25,
			"%s changes heading every step, which reads as circling" % actor.name
		)
	assert_eq(checked, fowl_species.size(), "every penned fowl species must actually walk")
	fauna.queue_free()


func test_penned_fauna_stays_on_the_ground_plane() -> void:
	var fauna := PennedFauna.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(fauna)
	fauna.configure(&"viru_gate_foreland", MammalSpecies.CONTEXT_FORELAND, 32)
	for step in 64:
		fauna.sync(MammalSpecies.CONTEXT_FORELAND, 0.1, Vector3.ZERO, true)
		for actor in fauna.fauna_actors():
			var home: Vector3 = actor.get_meta(&"home", Vector3.ZERO)
			assert_true(
				is_equal_approx(actor.position.y, home.y),
				"%s must not drift off the ground" % actor.name
			)
	fauna.queue_free()


func test_lower_town_surfaces_all_five_domestic_species() -> void:
	var species := PennedFauna.distinct_domestic_species_for_map(&"lower_town_slice")
	assert_eq(species.size(), 5)
	for required in PennedFauna.DOMESTIC_SPECIES:
		assert_true(required in species, "Missing domestic species %s" % required)


func test_foreland_surfaces_domestic_and_wild_species() -> void:
	var domestic := PennedFauna.distinct_domestic_species_for_map(&"viru_gate_foreland")
	var wild := PennedFauna.distinct_wild_species_for_map(&"viru_gate_foreland")
	assert_eq(domestic.size(), 5)
	assert_eq(wild.size(), 5)
	for required in PennedFauna.WILD_SPECIES:
		assert_true(required in wild, "Missing wild species %s" % required)


func test_lower_town_authors_five_placements_under_cap() -> void:
	assert_eq(PennedFauna.placement_count_for_map(&"lower_town_slice"), 5)
	assert_true(
		PennedFauna.placement_count_for_map(&"lower_town_slice") <= PennedFauna.MAX_CONCURRENT_FAUNA
	)


func test_foreland_authors_ten_placements_under_cap() -> void:
	assert_eq(PennedFauna.placement_count_for_map(&"viru_gate_foreland"), 11)
	assert_true(
		PennedFauna.placement_count_for_map(&"viru_gate_foreland") <= PennedFauna.MAX_CONCURRENT_FAUNA
	)


func test_north_quarter_authors_cattle_and_sheep_under_cap() -> void:
	assert_eq(PennedFauna.placement_count_for_map(&"north_quarter"), 6)
	assert_true(
		PennedFauna.placement_count_for_map(&"north_quarter") <= PennedFauna.MAX_CONCURRENT_FAUNA
	)
	var seen: Dictionary = {}
	for placement: Dictionary in PennedFauna.MAP_PLACEMENTS[&"north_quarter"]:
		seen[placement.get("species", &"")] = true
	assert_true(seen.has(MammalSpecies.SPECIES_COW))
	assert_true(seen.has(MammalSpecies.SPECIES_SHEEP))


func test_north_quarter_livestock_stays_outside_pikk_patrol_corridor() -> void:
	var definition: MapDefinition = NorthQuarterDefinition.create()
	var corridor := _merchant_patrol_corridor_cells(definition, 2)
	for placement: Dictionary in PennedFauna.MAP_PLACEMENTS[&"north_quarter"]:
		var cell: Vector2i = placement.get("cell", Vector2i.ZERO)
		assert_false(
			corridor.has(cell),
			"Livestock at %s must not spawn on the Pikk patrol corridor" % cell
		)
		var nearest := _nearest_manhattan_distance(cell, corridor)
		assert_true(
			nearest >= 20,
			"Livestock at %s must stay west of the Pikk/Lai spine (nearest=%d)" % [cell, nearest]
		)


func test_north_quarter_pen_actors_stay_within_authored_radius() -> void:
	var fauna := PennedFauna.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(fauna)
	fauna.configure(&"north_quarter", MammalSpecies.CONTEXT_MARKET, 32)
	for step in 48:
		fauna.sync(MammalSpecies.CONTEXT_MARKET, 0.25, Vector3.ZERO, true)
	for actor in fauna.fauna_actors():
		var radius := float(actor.get_meta(&"radius", 0.0))
		assert_true(
			fauna.actor_offset_from_home(actor) <= radius * 1.05,
			"Merchant pen actor drifted outside authored radius"
		)
	fauna.queue_free()


func test_north_quarter_supports_penned_fauna_via_context() -> void:
	var definition: MapDefinition = NorthQuarterDefinition.create()
	assert_false(definition.suppresses_exterior_surroundings())
	assert_true(FaunaContext.supports_penned_fauna(definition.map_id))
	assert_eq(FaunaContext.context_for_map(definition.map_id), MammalSpecies.CONTEXT_MARKET)


func test_fauna_actors_carry_no_collision_shapes() -> void:
	var fauna := PennedFauna.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(fauna)
	fauna.configure(&"lower_town_slice", MammalSpecies.CONTEXT_LOWER_TOWN, 32)
	for actor in fauna.fauna_actors():
		assert_false(fauna.actor_has_collision(actor), "Penned fauna must stay visual-only")
	fauna.queue_free()


func test_lower_town_penned_livestock_stays_outside_building_volumes() -> void:
	var definition: MapDefinition = LowerTownSlice.create()
	var fauna := PennedFauna.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(fauna)
	fauna.configure(
		definition.map_id, MammalSpecies.CONTEXT_LOWER_TOWN, definition.cell_size, definition
	)
	var shed: Dictionary = {}
	for building: Dictionary in definition.buildings:
		if building.get("id", &"") == &"artisan_shed":
			shed = building
			break
	assert_false(shed.is_empty(), "Lower Town must still author artisan_shed")
	var shed_world := MapViewBridge.logic_rect_to_world_xz(
		shed["footprint"], definition.cell_size
	)
	var found_cow := false
	for actor in fauna.fauna_actors():
		assert_false(
			_world_point_in_buildings(definition, actor.position),
			"%s spawned inside a building footprint" % actor.name
		)
		if actor.get_meta(&"species", &"") != MammalSpecies.SPECIES_COW:
			continue
		found_cow = true
		assert_false(
			shed_world.grow(0.5).has_point(Vector2(actor.position.x, actor.position.z)),
			"Cow must not start inside artisan_shed"
		)
		var saw_world_shed := false
		for blocked_rect: Rect2 in actor.get_meta(&"blocked_rects", []):
			if not blocked_rect.has_point(shed_world.get_center()):
				continue
			saw_world_shed = true
			assert_true(
				blocked_rect.size.x < 64.0,
				"Blocked rects must be world metres, not logic pixels"
			)
		assert_true(saw_world_shed, "Cow wander must treat artisan_shed as blocked")
	assert_true(found_cow, "Lower Town must still spawn a penned cow")
	fauna.queue_free()


func test_pen_and_tether_actors_stay_within_authored_radius() -> void:
	var fauna := PennedFauna.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(fauna)
	fauna.configure(&"lower_town_slice", MammalSpecies.CONTEXT_LOWER_TOWN, 32)
	for step in 48:
		fauna.sync(MammalSpecies.CONTEXT_LOWER_TOWN, 0.25, Vector3.ZERO, true)
	for actor in fauna.fauna_actors():
		var behavior: StringName = actor.get_meta(&"behavior", &"")
		if behavior == PennedFauna.BEHAVIOR_FLEE:
			continue
		var radius := float(actor.get_meta(&"radius", 0.0))
		assert_true(
			fauna.actor_offset_from_home(actor) <= radius * 1.05,
			"%s drifted outside authored radius" % behavior
		)
	fauna.queue_free()


func test_wild_margin_actors_flee_listener_on_foreland() -> void:
	var fauna := PennedFauna.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(fauna)
	fauna.configure(&"viru_gate_foreland", MammalSpecies.CONTEXT_FORELAND, 32)
	var flee_actor: Node3D = null
	for actor in fauna.fauna_actors():
		if actor.get_meta(&"behavior", &"") == PennedFauna.BEHAVIOR_FLEE:
			flee_actor = actor
			break
	assert_true(flee_actor != null, "Foreland should author at least one wild-margin actor")
	var home: Vector3 = flee_actor.get_meta(&"home", Vector3.ZERO)
	var before := fauna.actor_offset_from_home(flee_actor)
	for step in 24:
		fauna.sync(MammalSpecies.CONTEXT_FORELAND, 0.25, home, true)
	var after := fauna.actor_offset_from_home(flee_actor)
	assert_true(after > before + 0.5, "Wild-margin actor should flee when listener is at home")
	fauna.queue_free()


func test_wild_predators_stay_outside_required_route_corridor() -> void:
	var definition: MapDefinition = ForelandDefinition.create()
	var corridor := _foreland_patrol_corridor_cells(definition, 4)
	for placement: Dictionary in PennedFauna.MAP_PLACEMENTS[&"viru_gate_foreland"]:
		var species: StringName = placement.get("species", &"")
		if species != MammalSpecies.SPECIES_WOLF and species != MammalSpecies.SPECIES_BROWN_BEAR:
			continue
		var cell: Vector2i = placement.get("cell", Vector2i.ZERO)
		assert_false(
			corridor.has(cell),
			"Predator %s must not spawn on the Viru road patrol corridor" % species
		)
		var nearest := _nearest_manhattan_distance(cell, corridor)
		assert_true(
			nearest >= 8,
			(
				"Predator %s at %s must stay outside the required route corridor (nearest=%d)"
				% [species, cell, nearest]
			)
		)


func test_concurrent_fauna_cap_is_enforced() -> void:
	var fauna := PennedFauna.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(fauna)
	fauna.configure(&"viru_gate_foreland", MammalSpecies.CONTEXT_FORELAND, 32)
	fauna.sync(MammalSpecies.CONTEXT_FORELAND, 1.0, Vector3.ZERO, true)
	assert_true(fauna.active_fauna_count() <= PennedFauna.MAX_CONCURRENT_FAUNA)
	fauna.queue_free()


func test_disabling_fauna_leaves_game_state_unchanged() -> void:
	var state := GameState.new()
	var before := state.save_payload()
	var fauna := PennedFauna.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(fauna)
	fauna.configure(&"lower_town_slice", MammalSpecies.CONTEXT_LOWER_TOWN, 32)
	fauna.set_fauna_enabled(false)
	fauna.sync(MammalSpecies.CONTEXT_LOWER_TOWN, 1.0, Vector3.ZERO, false)
	assert_eq(fauna.active_fauna_count(), 0)
	assert_eq(state.save_payload(), before)
	fauna.queue_free()


func test_interior_maps_suppress_penned_fauna_via_context() -> void:
	var smithy: MapDefinition = KalevSmithy.create()
	assert_true(smithy.suppresses_exterior_surroundings())
	assert_false(FaunaContext.supports_penned_fauna(smithy.map_id))

	var lower_town: MapDefinition = LowerTownSlice.create()
	assert_false(lower_town.suppresses_exterior_surroundings())
	assert_true(FaunaContext.supports_penned_fauna(lower_town.map_id))
	assert_eq(FaunaContext.context_for_map(lower_town.map_id), MammalSpecies.CONTEXT_LOWER_TOWN)


func _foreland_patrol_corridor_cells(definition: MapDefinition, radius: int) -> Dictionary:
	var corridor: Dictionary = {}
	for patrol: Dictionary in definition.patrols:
		if patrol.get("id", &"") != &"pirita_crossing_watch":
			continue
		for point in patrol.get("points", []):
			var cell := Vector2i(point)
			for dx in range(-radius, radius + 1):
				for dy in range(-radius, radius + 1):
					corridor[cell + Vector2i(dx, dy)] = true
	return corridor


func _merchant_patrol_corridor_cells(definition: MapDefinition, radius: int) -> Dictionary:
	var corridor: Dictionary = {}
	for patrol: Dictionary in definition.patrols:
		if patrol.get("id", &"") != &"merchant_watch":
			continue
		for point in patrol.get("points", []):
			var cell := Vector2i(point)
			for dx in range(-radius, radius + 1):
				for dy in range(-radius, radius + 1):
					corridor[cell + Vector2i(dx, dy)] = true
	return corridor


func _nearest_manhattan_distance(cell: Vector2i, corridor: Dictionary) -> int:
	var nearest := 9999
	for corridor_cell: Vector2i in corridor.keys():
		var distance := absi(cell.x - corridor_cell.x) + absi(cell.y - corridor_cell.y)
		nearest = mini(nearest, distance)
	return nearest


func _world_point_in_buildings(definition: MapDefinition, world: Vector3) -> bool:
	var point := Vector2(world.x, world.z)
	for building: Dictionary in definition.buildings:
		var footprint: Rect2 = building.get("footprint", Rect2())
		if footprint.size == Vector2.ZERO:
			continue
		if MapViewBridge.logic_rect_to_world_xz(footprint, definition.cell_size).has_point(point):
			return true
	return false


func test_pen_herds_render_companions_through_instanced_path() -> void:
	var definition: MapDefinition = LowerTownSlice.create()
	var fauna := PennedFauna.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(fauna)
	fauna.configure(
		definition.map_id, MammalSpecies.CONTEXT_LOWER_TOWN, definition.cell_size, definition
	)
	var authored := PennedFauna.herd_count_for_map(&"lower_town_slice")
	assert_true(authored > 0, "Lower Town pens must author herd companions")
	assert_true(fauna.herd_companion_count() > 0)
	assert_true(fauna.herd_companion_count() <= mini(authored, PennedFauna.MAX_HERD_COMPANIONS))
	var drawn := 0
	for renderer in fauna.herd_renderers():
		assert_false(renderer.part_instances().is_empty())
		for part: MultiMeshInstance3D in renderer.part_instances():
			assert_eq(part.visibility_range_end, PennedFauna.HERD_VISIBILITY_RANGE)
		drawn += renderer.drawn_count()
		for position: Vector3 in renderer._actor_positions.values():
			assert_false(
				_world_point_in_buildings(definition, position),
				"herd companion must stand outside building footprints"
			)
	assert_eq(drawn, fauna.herd_companion_count(), "every companion is one MultiMesh instance")
	fauna.queue_free()


func test_herd_companions_stay_inside_their_pen() -> void:
	var definition: MapDefinition = LowerTownSlice.create()
	var fauna := PennedFauna.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(fauna)
	fauna.configure(
		definition.map_id, MammalSpecies.CONTEXT_LOWER_TOWN, definition.cell_size, definition
	)
	var homes: Array = []
	for actor in fauna.fauna_actors():
		if actor.has_meta(&"herd_home"):
			homes.append(actor.get_meta(&"herd_home"))
	var max_radius := 0.0
	for placement: Dictionary in PennedFauna.LOWER_TOWN_PLACEMENTS:
		max_radius = maxf(max_radius, float(placement.get("radius", 0.0)))
	for renderer in fauna.herd_renderers():
		for position: Vector3 in renderer._actor_positions.values():
			var nearest := INF
			for home: Vector3 in homes:
				nearest = minf(nearest, Vector2(position.x - home.x, position.z - home.z).length())
			assert_true(nearest <= max_radius, "companion strayed outside its pen")
	fauna.queue_free()


func test_fauna_actors_switch_to_instanced_stand_in_past_detail_range() -> void:
	var fauna := PennedFauna.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(fauna)
	fauna.configure(&"lower_town_slice", MammalSpecies.CONTEXT_LOWER_TOWN, 32)
	fauna.sync(MammalSpecies.CONTEXT_LOWER_TOWN, 0.25, Vector3.ZERO, true)
	var actors := 0
	for actor in fauna.fauna_actors():
		if not actor.has_meta(&"herd_model_key"):
			continue
		actors += 1
		for geometry: GeometryInstance3D in actor.find_children("*", "GeometryInstance3D", true, false):
			assert_eq(geometry.visibility_range_end, PennedFauna.FAUNA_DETAIL_RANGE)
	assert_true(actors > 0)
	var stand_ins := 0
	for renderer in fauna.herd_renderers():
		var part := renderer.part_instances()[0]
		if part.visibility_range_begin <= 0.0:
			continue
		assert_eq(part.visibility_range_begin, PennedFauna.FAUNA_DETAIL_RANGE)
		stand_ins += renderer.drawn_count()
	assert_eq(stand_ins, actors, "every animated actor needs a far stand-in instance")
	fauna.set_fauna_enabled(false)
	assert_eq(fauna.herd_companion_count(), 0, "disabling fauna hides herds")
	fauna.queue_free()
