extends "res://tests/godot/test_case.gd"

const FaunaContext := preload("res://scripts/map/view3d/map_view_fauna_context.gd")
const KalevSmithy := preload("res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd")
const LowerTownSlice := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")
const SouthQuarterDefinition := preload("res://scripts/map/definitions/prototypes/south_quarter_definition.gd")
const UrbanFauna := preload("res://scripts/map/view3d/map_view_urban_fauna.gd")


func test_lower_town_surfaces_all_four_urban_species() -> void:
	var species := UrbanFauna.distinct_species_for_map(&"lower_town_slice")
	assert_eq(species.size(), 4)
	for required in UrbanFauna.URBAN_SPECIES:
		assert_true(required in species, "Missing urban species %s" % required)


func test_lower_town_authors_eight_placements_under_cap() -> void:
	assert_eq(UrbanFauna.placement_count_for_map(&"lower_town_slice"), 8)
	assert_true(UrbanFauna.placement_count_for_map(&"lower_town_slice") <= UrbanFauna.MAX_CONCURRENT_FAUNA)


func test_fauna_actors_carry_no_collision_shapes() -> void:
	var fauna := UrbanFauna.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(fauna)
	fauna.configure(&"lower_town_slice", MammalSpecies.CONTEXT_LOWER_TOWN, 32)
	for actor in fauna.get_children():
		assert_false(fauna.actor_has_collision(actor), "Urban fauna must stay visual-only")
	fauna.queue_free()


func test_wander_and_tether_actors_stay_within_authored_radius() -> void:
	var fauna := UrbanFauna.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(fauna)
	fauna.configure(&"lower_town_slice", MammalSpecies.CONTEXT_LOWER_TOWN, 32)
	for step in 48:
		fauna.sync(MammalSpecies.CONTEXT_LOWER_TOWN, 0.25, Vector3.ZERO, true)
	for actor in fauna.get_children():
		var behavior: StringName = actor.get_meta(&"behavior", &"")
		if behavior == UrbanFauna.BEHAVIOR_FLEE:
			continue
		var radius := float(actor.get_meta(&"radius", 0.0))
		assert_true(
			fauna.actor_offset_from_home(actor) <= radius * 1.05,
			"%s drifted outside authored radius" % behavior
		)
	fauna.queue_free()


func test_urban_fauna_stays_on_the_ground_plane() -> void:
	var fauna := UrbanFauna.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(fauna)
	fauna.configure(&"lower_town_slice", MammalSpecies.CONTEXT_LOWER_TOWN, 32)
	for step in 64:
		fauna.sync(MammalSpecies.CONTEXT_LOWER_TOWN, 0.1, Vector3.ZERO, true)
		for actor in fauna.get_children():
			var home: Vector3 = actor.get_meta(&"home", Vector3.ZERO)
			assert_true(
				is_equal_approx(actor.position.y, home.y),
				"%s must not drift off the ground" % actor.name
			)
	fauna.queue_free()


func test_urban_fauna_uses_the_visible_terrain_height() -> void:
	var definition: MapDefinition = SouthQuarterDefinition.create()
	var grid := MapBuilder.build(definition)
	MapViewMeshBuilder.ensure_height_field(definition, grid)
	var fauna := UrbanFauna.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(fauna)
	fauna.configure(definition.map_id, MammalSpecies.CONTEXT_LOWER_TOWN, definition.cell_size, definition)
	for actor in fauna.get_children():
		var expected := MapViewMeshBuilder.ground_height(definition, Vector2(actor.position.x, actor.position.z))
		assert_true(
			is_equal_approx(actor.position.y, expected),
			"%s must share Terrain_Ground height (expected %s, got %s)" % [actor.name, expected, actor.position.y]
		)
	fauna.queue_free()

func test_moving_fauna_walks_in_straight_segments_instead_of_circling() -> void:
	var fauna := UrbanFauna.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(fauna)
	fauna.configure(&"lower_town_slice", MammalSpecies.CONTEXT_LOWER_TOWN, 32)
	var previous: Dictionary = {}
	var previous_heading: Dictionary = {}
	var moving_steps: Dictionary = {}
	var turns: Dictionary = {}
	for step in 200:
		for actor in fauna.get_children():
			previous[actor.name] = actor.position
		fauna.sync(MammalSpecies.CONTEXT_LOWER_TOWN, 0.1, Vector3.ZERO, true)
		for actor in fauna.get_children():
			var movement: Vector3 = actor.position - Vector3(previous[actor.name])
			if movement.length() < 0.0001:
				continue
			var heading := movement.normalized()
			moving_steps[actor.name] = int(moving_steps.get(actor.name, 0)) + 1
			if previous_heading.has(actor.name):
				# Circular motion re-aims every frame; waypoint walking only turns
				# when a leg of the route ends.
				if heading.dot(previous_heading[actor.name]) < 0.999:
					turns[actor.name] = int(turns.get(actor.name, 0)) + 1
			previous_heading[actor.name] = heading

	var checked := 0
	for actor in fauna.get_children():
		var steps := int(moving_steps.get(actor.name, 0))
		if steps < 10:
			continue
		checked += 1
		assert_true(
			float(turns.get(actor.name, 0)) <= float(steps) * 0.25,
			"%s changes heading every step, which reads as circling" % actor.name
		)
	assert_true(checked > 0, "at least one actor must actually travel")
	fauna.queue_free()


func test_concurrent_fauna_cap_is_enforced() -> void:
	var fauna := UrbanFauna.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(fauna)
	fauna.configure(&"lower_town_slice", MammalSpecies.CONTEXT_LOWER_TOWN, 32)
	fauna.sync(MammalSpecies.CONTEXT_LOWER_TOWN, 1.0, Vector3.ZERO, true)
	assert_true(fauna.active_fauna_count() <= UrbanFauna.MAX_CONCURRENT_FAUNA)
	fauna.queue_free()


func test_disabling_fauna_leaves_game_state_unchanged() -> void:
	var state := GameState.new()
	var before := state.save_payload()
	var fauna := UrbanFauna.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(fauna)
	fauna.configure(&"lower_town_slice", MammalSpecies.CONTEXT_LOWER_TOWN, 32)
	fauna.set_fauna_enabled(false)
	fauna.sync(MammalSpecies.CONTEXT_LOWER_TOWN, 1.0, Vector3.ZERO, false)
	assert_eq(fauna.active_fauna_count(), 0)
	assert_eq(state.save_payload(), before)
	fauna.queue_free()


func test_south_quarter_authors_horses_and_court_dog_under_cap() -> void:
	assert_eq(UrbanFauna.placement_count_for_map(&"south_quarter"), 3)
	assert_true(UrbanFauna.placement_count_for_map(&"south_quarter") <= UrbanFauna.MAX_CONCURRENT_FAUNA)
	var seen: Dictionary = {}
	for placement: Dictionary in UrbanFauna.MAP_PLACEMENTS[&"south_quarter"]:
		seen[placement.get("species", &"")] = true
	assert_true(seen.has(MammalSpecies.SPECIES_HORSE))
	assert_true(seen.has(MammalSpecies.SPECIES_DOG))


func test_south_quarter_stable_actors_stay_outside_south_watch_patrol() -> void:
	var definition: MapDefinition = SouthQuarterDefinition.create()
	var corridor := _south_watch_patrol_corridor_cells(definition, 1)
	for placement: Dictionary in UrbanFauna.MAP_PLACEMENTS[&"south_quarter"]:
		var cell: Vector2i = placement.get("cell", Vector2i.ZERO)
		assert_false(
			corridor.has(cell),
			"Urban fauna at %s must not spawn on the south_watch patrol spine" % cell
		)


func test_south_quarter_supports_urban_fauna_via_context() -> void:
	var definition: MapDefinition = SouthQuarterDefinition.create()
	assert_false(definition.suppresses_exterior_surroundings())
	assert_true(FaunaContext.supports_urban_fauna(definition.map_id))
	assert_eq(FaunaContext.context_for_map(definition.map_id), MammalSpecies.CONTEXT_LOWER_TOWN)


func test_interior_maps_suppress_urban_fauna_via_context() -> void:
	var smithy: MapDefinition = KalevSmithy.create()
	assert_true(smithy.suppresses_exterior_surroundings())
	assert_false(FaunaContext.supports_urban_fauna(smithy.map_id))

	var lower_town: MapDefinition = LowerTownSlice.create()
	assert_false(lower_town.suppresses_exterior_surroundings())
	assert_true(FaunaContext.supports_urban_fauna(lower_town.map_id))
	assert_eq(FaunaContext.context_for_map(lower_town.map_id), MammalSpecies.CONTEXT_LOWER_TOWN)


func _south_watch_patrol_corridor_cells(definition: MapDefinition, radius: int) -> Dictionary:
	var corridor: Dictionary = {}
	for patrol: Dictionary in definition.patrols:
		if patrol.get("id", &"") != &"south_watch":
			continue
		for point in patrol.get("points", []):
			var cell := Vector2i(point)
			for dx in range(-radius, radius + 1):
				for dy in range(-radius, radius + 1):
					corridor[cell + Vector2i(dx, dy)] = true
	return corridor


func test_town_cats_are_coat_variants_of_the_production_cat() -> void:
	var fauna := UrbanFauna.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(fauna)
	fauna.configure(&"lower_town_slice", MammalSpecies.CONTEXT_LOWER_TOWN, 32)
	var cats := 0
	var coats: Dictionary = {}
	for actor in fauna.get_children():
		if actor.get_meta(&"species", &"") != MammalSpecies.SPECIES_CAT:
			continue
		cats += 1
		var model := actor.get_node_or_null("Model") as Node3D
		assert_true(model != null, "town cats must instance the production cat rig")
		assert_true(model.has_meta(&"cat_coat"), "town cats must be dressed in a coat")
		coats[model.get_meta(&"cat_coat")] = true
		assert_true(model.find_children("*", "AnimationPlayer", true, false).size() > 0,
			"town cats must keep the rig's animation player")
	assert_true(cats >= 2, "Lower Town should keep more than one cat")
	assert_eq(coats.size(), cats, "each town cat should wear its own coat")
	fauna.queue_free()


func test_at_least_one_town_cat_walks_its_yard() -> void:
	var walking := 0
	for placement: Dictionary in UrbanFauna.MAP_PLACEMENTS[&"lower_town_slice"]:
		if placement.get("species", &"") != MammalSpecies.SPECIES_CAT:
			continue
		if placement.get("behavior", &"") == UrbanFauna.BEHAVIOR_WANDER:
			walking += 1
	assert_true(walking >= 1, "a town cat should use the walk cycle, not only rest poses")
