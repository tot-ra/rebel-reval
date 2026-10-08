extends "res://tests/godot/test_case.gd"


func test_player_and_npc_collide_with_world_and_each_other() -> void:
	var player := CharacterBody2D.new()
	CollisionLayers.apply_player(player)
	var npc := CharacterBody2D.new()
	CollisionLayers.apply_npc(npc)

	assert_true(
		(player.collision_mask & npc.collision_layer) != 0,
		"player must collide with npc bodies for gentle push"
	)
	assert_true(
		(npc.collision_mask & player.collision_layer) != 0,
		"npc must detect the player to avoid shoving during navigation"
	)
	assert_true(
		(player.collision_mask & CollisionLayers.WORLD) != 0,
		"player must still collide with world geometry"
	)
	assert_true(
		(npc.collision_mask & CollisionLayers.WORLD) != 0,
		"npc must still collide with world geometry"
	)


func test_crowd_is_passable_for_player_but_detectable() -> void:
	var player := CharacterBody2D.new()
	CollisionLayers.apply_player(player)
	var crowd := CharacterBody2D.new()
	CollisionLayers.apply_crowd(crowd)
	assert_true(
		(player.collision_mask & crowd.collision_layer) == 0,
		"player must walk through the ambient crowd"
	)
	assert_true(
		(CollisionLayers.MASK_ACTORS & crowd.collision_layer) != 0,
		"interaction sensors still see the crowd"
	)


func test_crowd_yield_opens_a_gap_and_returns() -> void:
	var home := Vector2(100, 100)
	var offset := Vector2.ZERO
	for i in 60:
		offset = CrowdYield.step_offset(offset, home, Vector2(100, 112), Vector2(0, -220), 0.016)
	assert_true(
		(home + offset).distance_to(Vector2(100, 112)) > 20.0,
		"actor must clear the player's path"
	)
	for i in 120:
		offset = CrowdYield.step_offset(offset, home, Vector2(400, 400), Vector2.ZERO, 0.016)
	assert_true(offset.is_zero_approx(), "actor returns to the scheduled spot")
