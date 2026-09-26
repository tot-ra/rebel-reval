extends "res://tests/godot/test_case.gd"

const BirdContext := preload("res://scripts/map/view3d/map_view_bird_context.gd")
const BirdFlight := preload("res://scripts/map/view3d/map_view_bird_flight.gd")
const BirdSpecies := preload("res://scripts/map/view3d/map_view_bird_species.gd")
const CrowdRenderer := preload("res://scripts/map/view3d/map_view_crowd_renderer.gd")
const KalevSmithy := preload("res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd")
const LowerTownSlice := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const HarborNorth := preload(
	"res://scripts/map/definitions/outdoor/reval_harbor_north_definition.gd"
)
const Foreland := preload("res://scripts/map/definitions/outdoor/viru_gate_foreland_definition.gd")


func test_foreland_context_surfaces_distinct_gliding_species() -> void:
	var species := BirdFlight.distinct_species_for_context(
		&"viru_gate_foreland",
		BirdContext.context_for_map(&"viru_gate_foreland"),
		0.35,
		48
	)
	assert_true(
		species.size() >= 3,
		"Viru Gate foreland day cycle should surface at least three gliding species"
	)


func test_lower_town_context_surfaces_distinct_gliding_species() -> void:
	var species := BirdFlight.distinct_species_for_context(
		&"lower_town_slice",
		BirdContext.context_for_map(&"lower_town_slice"),
		0.35,
		48
	)
	assert_true(
		species.size() >= 3, "Lower Town day cycle should surface at least three gliding species"
	)


func test_harbor_context_surfaces_distinct_gliding_species() -> void:
	var species := BirdFlight.distinct_species_for_context(
		&"reval_harbor_north",
		BirdContext.context_for_map(&"reval_harbor_north"),
		0.35,
		48
	)
	assert_true(species.size() >= 3, "Harbour day cycle should surface at least three gliding species")


func test_flight_path_uses_wind_carved_curve() -> void:
	var flight := BirdFlight.new()
	var bird := Node3D.new()
	bird.set_meta(&"start", Vector3(5.0, 10.0, 12.0))
	bird.set_meta(&"end", Vector3(55.0, 10.2, 20.0))
	bird.set_meta(&"sway_phase", 0.8)
	bird.set_meta(&"sway_amplitude", 0.5)
	bird.set_meta(&"sway_frequency", 1.1)
	var midpoint: Vector3 = flight._flight_position(bird, 0.5)
	var straight_midpoint: Vector3 = bird.get_meta(&"start").lerp(bird.get_meta(&"end"), 0.5)
	assert_true(
		midpoint.distance_to(straight_midpoint) > 0.03,
		"flight should arc through the wind instead of following a ruler-straight line"
	)
	assert_true(flight._flight_position(bird, 0.0).is_equal_approx(bird.get_meta(&"start")))
	assert_true(flight._flight_position(bird, 1.0).is_equal_approx(bird.get_meta(&"end")))
	bird.free()
	flight.free()


func test_active_bird_skips_orientation_when_look_ahead_matches_position() -> void:
	var flight := BirdFlight.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(flight)
	var bird := flight.get_node("FlightBird0") as Node3D
	bird.visible = true
	bird.set_meta(&"start", Vector3(8.0, 10.0, 8.0))
	bird.set_meta(&"end", Vector3(48.0, 10.0, 8.0))
	bird.set_meta(&"speed", 9.9999)
	bird.set_meta(&"path_length", 10.0)
	bird.set_meta(&"traveled", 0.0)
	flight._advance_active_birds(1.0)
	assert_true(bird.visible, "a bird near the end of its path should remain active")
	assert_true(bird.position.x > 47.9)
	flight.queue_free()


func test_species_selection_is_deterministic_for_seed_and_tick() -> void:
	var first := BirdFlight.pick_species(&"lower_town_slice", BirdSpecies.CONTEXT_LOWER_TOWN, 0.35, 7)
	var second := BirdFlight.pick_species(&"lower_town_slice", BirdSpecies.CONTEXT_LOWER_TOWN, 0.35, 7)
	assert_false(first.is_empty())
	assert_eq(first, second)


func test_concurrent_bird_cap_is_enforced() -> void:
	var flight := BirdFlight.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(flight)
	flight.configure(&"lower_town_slice", BirdSpecies.CONTEXT_LOWER_TOWN, Vector2i(64, 36))
	for _attempt in 12:
		flight.sync(BirdSpecies.CONTEXT_LOWER_TOWN, 0.35, 10.0)
	assert_true(flight.active_bird_count() <= 4)
	flight.queue_free()


func test_active_birds_fly_above_the_ground() -> void:
	var flight := BirdFlight.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(flight)
	flight.configure(&"lower_town_slice", BirdSpecies.CONTEXT_LOWER_TOWN, Vector2i(64, 36))
	# The first sync deterministically spawns a bird; inspect it before the short
	# test map lets that bird cross the opposite edge and despawn.
	flight.sync(BirdSpecies.CONTEXT_LOWER_TOWN, 0.35, 0.1)
	var checked := 0
	for bird in flight.flight_birds():
		if not bird.visible:
			continue
		checked += 1
		assert_true(
			bird.position.y >= BirdFlight.FLIGHT_HEIGHT_MIN * 0.9,
			"%s must fly instead of circling on the ground" % bird.name
		)
	assert_true(checked > 0, "at least one ambient bird must be in flight")
	flight.queue_free()


func test_disabling_bird_flight_leaves_game_state_unchanged() -> void:
	var state := GameState.new()
	var before := state.save_payload()
	var flight := BirdFlight.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(flight)
	flight.configure(&"lower_town_slice", BirdSpecies.CONTEXT_LOWER_TOWN, Vector2i(64, 36))
	flight.set_flight_enabled(false)
	flight.sync(BirdSpecies.CONTEXT_LOWER_TOWN, 0.35, 1.0, false)
	assert_eq(flight.active_bird_count(), 0)
	assert_eq(state.save_payload(), before)
	flight.queue_free()


func test_interior_maps_suppress_bird_flight_via_runtime() -> void:
	var smithy: MapDefinition = KalevSmithy.create()
	assert_true(smithy.suppresses_exterior_surroundings())

	var lower_town: MapDefinition = LowerTownSlice.create()
	assert_false(lower_town.suppresses_exterior_surroundings())
	assert_eq(BirdContext.context_for_map(lower_town.map_id), BirdSpecies.CONTEXT_LOWER_TOWN)

	var harbor: MapDefinition = HarborNorth.create()
	assert_eq(BirdContext.context_for_map(harbor.map_id), BirdSpecies.CONTEXT_HARBOR)

	var foreland: MapDefinition = Foreland.create()
	assert_eq(BirdContext.context_for_map(foreland.map_id), BirdSpecies.CONTEXT_FORELAND)


func test_flocks_render_followers_through_instanced_path_with_lod() -> void:
	var flight := _harbour_flight_with_flock()
	var leader := _first_flock_leader(flight)
	assert_true(leader != null, "the harbour day cycle must spawn a flocking leader")
	if leader == null:
		flight.queue_free()
		return
	var species: StringName = leader.get_meta(&"species")
	var renderer := flight.flock_renderer_for(species)
	assert_true(renderer is MapViewCrowdRenderer, "followers must use the P0-152 crowd path")
	var followers := (leader.get_meta(&"flock_offsets") as Array).size()
	assert_true(
		followers >= BirdFlight.FLOCK_FOLLOWERS_MIN
		or followers == BirdFlight.MAX_FLOCK_FOLLOWERS
	)
	assert_eq(renderer.drawn_count(), followers, "every follower is one MultiMesh instance")
	assert_false(renderer.part_instances().is_empty())
	for part: MultiMeshInstance3D in renderer.part_instances():
		assert_eq(part.multimesh.visible_instance_count, followers)
		assert_eq(part.visibility_range_end, BirdFlight.FLOCK_VISIBILITY_RANGE)
		assert_eq(part.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var leader_geometry := leader.find_children("*", "GeometryInstance3D", true, false)
	assert_false(leader_geometry.is_empty())
	for geometry: GeometryInstance3D in leader_geometry:
		assert_eq(
			geometry.visibility_range_end,
			BirdFlight.BIRD_DETAIL_RANGE,
			"%s must cull by LOD range" % geometry.name
		)
	# Followers trail the leader in formation (+Z is behind after look_at).
	var local_leader := leader.transform.orthonormalized().affine_inverse()
	for position: Vector3 in renderer._actor_positions.values():
		var local := local_leader * position
		assert_true(local.z > 0.0, "followers must trail the leader")
		assert_true(local.length() < 16.0, "followers must stay close to the leader")
	flight.queue_free()


func test_flock_followers_respect_concurrent_cap() -> void:
	assert_true(BirdFlight.flock_offsets(&"reval_harbor_north", 3, 0).is_empty())
	assert_true(BirdFlight.flock_offsets(&"reval_harbor_north", 3, 2).size() <= 2)
	assert_eq(
		BirdFlight.flock_offsets(&"reval_harbor_north", 5, 24),
		BirdFlight.flock_offsets(&"reval_harbor_north", 5, 24),
		"flock formation must be deterministic for seed and tick"
	)
	var flight := BirdFlight.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(flight)
	flight.configure(&"reval_harbor_north", BirdSpecies.CONTEXT_HARBOR, Vector2i(160, 120))
	for _attempt in 40:
		flight.sync(BirdSpecies.CONTEXT_HARBOR, 0.35, 3.0)
		assert_true(flight.active_bird_count() <= BirdFlight.MAX_CONCURRENT_BIRDS)
		assert_true(flight.active_flock_follower_count() <= BirdFlight.MAX_FLOCK_FOLLOWERS)
		var drawn := 0
		for child in flight.get_children():
			if child is MapViewCrowdRenderer:
				drawn += (child as MapViewCrowdRenderer).drawn_count()
		assert_eq(drawn, flight.active_flock_follower_count())
	flight.queue_free()


func test_disabling_flight_clears_instanced_followers() -> void:
	var state := GameState.new()
	var before := state.save_payload()
	var flight := _harbour_flight_with_flock()
	assert_true(flight.active_flock_follower_count() > 0)
	flight.set_flight_enabled(false)
	assert_eq(flight.active_flock_follower_count(), 0)
	for child in flight.get_children():
		if child is MapViewCrowdRenderer:
			assert_eq((child as MapViewCrowdRenderer).drawn_count(), 0)
	assert_eq(state.save_payload(), before)
	flight.queue_free()


func _harbour_flight_with_flock() -> MapViewBirdFlight:
	var flight := BirdFlight.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(flight)
	flight.configure(&"reval_harbor_north", BirdSpecies.CONTEXT_HARBOR, Vector2i(160, 120))
	# Spawns are deterministic; small steps keep leaders mid-path while the
	# spawn timer walks the harbour species roll until a gregarious one lands.
	for _step in 400:
		flight.sync(BirdSpecies.CONTEXT_HARBOR, 0.35, 0.25)
		if _first_flock_leader(flight) != null:
			break
	return flight


func _first_flock_leader(flight: MapViewBirdFlight) -> Node3D:
	for bird in flight.flight_birds():
		if bird.visible and bird.has_meta(&"flock_offsets"):
			return bird
	return null
