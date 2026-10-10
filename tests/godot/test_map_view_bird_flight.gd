extends "res://tests/godot/test_case.gd"

## R-1628: birds cruise at constant speed, fly in from and on out to the
## distance, and stand in a flipbook instance that dissolves on those legs.

const BirdFlight := preload("res://scripts/map/view3d/map_view_bird_flight.gd")
const BirdSpecies := preload("res://scripts/map/view3d/map_view_bird_species.gd")

const STEP := 0.1
const CYCLE_NOON := 0.5


func test_fade_ramps_in_and_out_over_the_far_legs() -> void:
	var length := 300.0
	assert_almost_eq(BirdFlight.fade_at(0.0, length), 0.0, 0.0001)
	assert_almost_eq(BirdFlight.fade_at(BirdFlight.FADE_DEPTH * 0.5, length), 0.5, 0.0001)
	assert_almost_eq(BirdFlight.fade_at(length * 0.5, length), 1.0, 0.0001)
	assert_almost_eq(BirdFlight.fade_at(length - BirdFlight.FADE_DEPTH * 0.5, length), 0.5, 0.0001)
	assert_almost_eq(BirdFlight.fade_at(length, length), 0.0, 0.0001)


func test_birds_never_brake_and_fly_past_the_window() -> void:
	var flight := _flight()
	var bird := _first_active(flight)
	assert_true(bird != null, "a bird must spawn")
	if bird == null:
		flight.free()
		return
	var start: Vector3 = bird.get_meta(&"start")
	var end: Vector3 = bird.get_meta(&"end")
	var heading := (end - start).normalized()
	var path_length := float(bird.get_meta(&"path_length"))
	var speed := float(bird.get_meta(&"speed"))
	assert_true(
		path_length >= BirdFlight.FADE_DEPTH * 2.0 + BirdFlight.EDGE_MARGIN,
		"the path must reach FADE_DEPTH beyond the window on both sides"
	)
	var last_forward := heading.dot(bird.position - start)
	var slowest := INF
	while bird.visible and float(bird.get_meta(&"traveled")) + speed * STEP < path_length:
		flight.sync(BirdSpecies.CONTEXT_LOWER_TOWN, CYCLE_NOON, STEP)
		var forward := heading.dot(bird.position - start)
		slowest = minf(slowest, (forward - last_forward) / STEP)
		last_forward = forward
	# Sway and heave bend the line slightly; a braking bird would drop to ~0.
	assert_true(slowest > speed * 0.75, "bird slowed to %.2f of %.2f m/s" % [slowest, speed])
	flight.free()


func test_far_legs_draw_the_leader_as_a_fading_flipbook() -> void:
	var flight := _flight()
	var bird := _first_active(flight)
	if bird == null or flight.flock_renderers_for(bird.get_meta(&"species")).is_empty():
		flight.free()
		skip("no catalogue flipbook species spawned in lower_town")
		return
	var species: StringName = bird.get_meta(&"species")
	assert_true(BirdFlight.is_simplified(bird), "a bird entering from afar starts as a flipbook")
	assert_true(_rigged_geometry_hidden(bird), "the simplified rig must not draw")
	var drawn := _flipbook_alphas(flight, species)
	assert_false(drawn.is_empty(), "the simplified leader must be drawn by its flipbook")
	for alpha: float in drawn:
		assert_true(alpha < 1.0, "the approaching leg must fade in, got alpha %.2f" % alpha)
	var path_length := float(bird.get_meta(&"path_length"))
	while bird.visible and float(bird.get_meta(&"traveled")) < path_length * 0.5:
		flight.sync(BirdSpecies.CONTEXT_LOWER_TOWN, CYCLE_NOON, STEP)
	assert_false(BirdFlight.is_simplified(bird), "inside the window the rigged leader flies")
	assert_false(_rigged_geometry_hidden(bird))
	flight.free()


func test_flipbook_materials_dither_by_instance_alpha() -> void:
	var flight := _flight()
	var checked := 0
	for bird: Node3D in flight.flight_birds():
		if not bird.visible:
			continue
		for renderer: MapViewCrowdRenderer in flight.flock_renderers_for(bird.get_meta(&"species")):
			for node: MultiMeshInstance3D in renderer.part_instances():
				var mesh := node.multimesh.mesh
				for surface in mesh.get_surface_count():
					var material := mesh.surface_get_material(surface)
					if material is ShaderMaterial:
						var code := (material as ShaderMaterial).shader.code
						assert_true(code.contains("ALPHA = COLOR.a;"), "plumage fades by COLOR.a")
						assert_true(code.contains("ALPHA_HASH_SCALE"), "fade must dither")
						checked += 1
					elif material is BaseMaterial3D:
						var base := material as BaseMaterial3D
						assert_true(base.vertex_color_use_as_albedo, "fade rides on COLOR.a")
						assert_ne(base.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED)
						checked += 1
	if checked == 0:
		skip("no catalogue flipbook species spawned in lower_town")
	flight.free()


func _flight() -> BirdFlight:
	var flight := BirdFlight.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(flight)
	flight.configure(&"test_bird_flight", BirdSpecies.CONTEXT_LOWER_TOWN, Vector2i(160, 160))
	flight.sync(BirdSpecies.CONTEXT_LOWER_TOWN, CYCLE_NOON, STEP)
	return flight


func _first_active(flight: BirdFlight) -> Node3D:
	for bird: Node3D in flight.flight_birds():
		if bird.visible:
			return bird
	return null


func _rigged_geometry_hidden(bird: Node3D) -> bool:
	for child: Node in bird.get_children():
		if child is Node3D and (child as Node3D).visible:
			return false
	return true


func _flipbook_alphas(flight: BirdFlight, species: StringName) -> Array[float]:
	var alphas: Array[float] = []
	# Headless MultiMeshes do not keep instance data; read what was uploaded.
	for renderer: MapViewCrowdRenderer in flight.flock_renderers_for(species):
		for actor_id: int in renderer._actor_positions:
			alphas.append(float(renderer._actor_alphas.get(actor_id, 1.0)))
	return alphas
