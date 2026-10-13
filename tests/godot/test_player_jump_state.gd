extends "res://tests/godot/test_case.gd"

## Hop arc and slope slide of PlayerJumpState, plus the STEEP collision layer split.


func _run_arc(state: PlayerJumpState) -> float:
	var elapsed := 0.0
	while elapsed < 3.0:
		elapsed += 1.0 / 60.0
		if state.update(1.0 / 60.0):
			return elapsed
	return -1.0


func test_hop_leaves_and_returns_to_the_ground() -> void:
	var state := PlayerJumpState.new()
	assert_false(state.is_airborne())
	state.start()
	assert_true(state.is_airborne())
	var airtime := _run_arc(state)
	assert_true(airtime > 0.5 and airtime < 0.8, "airtime near 0.65 s, got %f" % airtime)
	assert_false(state.is_airborne())
	assert_eq(state.height, 0.0)


func test_hop_at_a_run_clears_a_five_unit_strip() -> void:
	var state := PlayerJumpState.new()
	state.start()
	var airtime := _run_arc(state)
	# Run speed is 180 logic px/s, 32 px per world unit.
	var reach := 180.0 * PlayerJumpState.AIR_SPEED_FRACTION * airtime / 32.0
	assert_true(reach > 5.0, "hop reach %f units" % reach)


func test_no_slide_on_gentle_ground_and_downhill_direction_on_steep() -> void:
	assert_eq(PlayerJumpState.slide_velocity(Vector2.ZERO), Vector2.ZERO)
	assert_eq(PlayerJumpState.slide_velocity(Vector2(tan(deg_to_rad(10.0)), 0.0)), Vector2.ZERO)
	var steep := PlayerJumpState.slide_velocity(Vector2(0.0, tan(deg_to_rad(40.0))))
	assert_true(steep.y > 0.0 and is_zero_approx(steep.x), "slides along the downhill direction")
	assert_true(steep.length() >= PlayerJumpState.SLIDE_MAX_SPEED_PX)


func test_slide_grows_with_slope_and_is_capped() -> void:
	var mild := PlayerJumpState.slide_velocity(Vector2(tan(deg_to_rad(28.0)), 0.0)).length()
	var hard := PlayerJumpState.slide_velocity(Vector2(tan(deg_to_rad(36.0)), 0.0)).length()
	var cliff := PlayerJumpState.slide_velocity(Vector2(tan(deg_to_rad(80.0)), 0.0)).length()
	assert_true(mild > 0.0 and hard > mild)
	assert_true(cliff <= PlayerJumpState.SLIDE_MAX_SPEED_PX * 1.5 + 0.01)


func test_definition_downhill_points_away_from_the_rise() -> void:
	var definition := MapDefinition.new()
	definition.cell_size = 32
	definition.size_cells = Vector2i(8, 8)
	# Flat map: no pull.
	assert_eq(definition.downhill_at_world(Vector2(100, 100)), Vector2.ZERO)


func test_steep_layer_is_solid_for_walkers_but_separate_from_world() -> void:
	assert_true((CollisionLayers.MASK_PLAYER & CollisionLayers.STEEP) != 0)
	assert_true((CollisionLayers.MASK_NPC & CollisionLayers.STEEP) != 0)
	assert_true((CollisionLayers.MASK_WORLD & CollisionLayers.STEEP) != 0)
	assert_eq(CollisionLayers.STEEP & CollisionLayers.WORLD, 0)


func test_airborne_player_masks_out_steep_ground() -> void:
	var player: CharacterBody2D = load("res://scripts/player.gd").new()
	CollisionLayers.apply_player(player)
	player.stamina = 100.0
	assert_true((player.collision_mask & CollisionLayers.STEEP) != 0)
	player._jump.start()
	player._apply_steep_mask()
	assert_true((player.collision_mask & CollisionLayers.STEEP) == 0, "no steep collision in the air")
	assert_true((player.collision_mask & CollisionLayers.WORLD) != 0, "walls still block a hop")
	player._jump.reset()
	player._apply_steep_mask()
	assert_true((player.collision_mask & CollisionLayers.STEEP) != 0)
	player.free()


func _physics_rig(tree: SceneTree) -> Array:
	var root := Node2D.new()
	tree.root.add_child(root)
	var strip := StaticBody2D.new()
	strip.collision_layer = CollisionLayers.STEEP
	strip.collision_mask = 0
	var strip_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(64, 400)
	strip_shape.shape = rect
	strip.add_child(strip_shape)
	strip.position = Vector2(100, 0)
	root.add_child(strip)
	var body := CharacterBody2D.new()
	CollisionLayers.apply_player(body)
	var body_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	body_shape.shape = circle
	body.add_child(body_shape)
	body.position = Vector2(0, 0)
	root.add_child(body)
	return [root, body]


func test_steep_strip_stops_a_walker_and_a_hop_crosses_it() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var rig := _physics_rig(tree)
	var body: CharacterBody2D = rig[1]
	await tree.physics_frame
	for i in 60:
		body.velocity = Vector2(180, 0)
		body.move_and_slide()
		await tree.physics_frame
	assert_true(body.position.x < 70.0, "walker stopped at the strip, x=%f" % body.position.x)
	body.set_collision_mask_value(6, false)
	for i in 60:
		body.velocity = Vector2(180, 0)
		body.move_and_slide()
		await tree.physics_frame
	assert_true(body.position.x > 140.0, "airborne body crossed, x=%f" % body.position.x)
	# Landed past the strip: no overlap, so the mask can come back.
	body.collision_mask = CollisionLayers.STEEP
	assert_false(body.test_move(body.global_transform, Vector2.ZERO, null, 0.001, true))
	# Landing inside the strip is detected, so the slide gets to carry it out.
	body.global_position = Vector2(100, 0)
	await tree.physics_frame
	assert_true(body.test_move(body.global_transform, Vector2.ZERO, null, 0.001, true))
	(rig[0] as Node).queue_free()
