extends "res://tests/godot/test_case.gd"


func test_player_and_npc_collide_with_world_and_each_other() -> void:
	var player := CharacterBody2D.new()
	CollisionLayers.apply_player(player)
	var npc := CharacterBody2D.new()
	CollisionLayers.apply_npc(npc)

	assert_true((player.collision_mask & npc.collision_layer) != 0, "player must collide with npc bodies for gentle push")
	assert_true((npc.collision_mask & player.collision_layer) != 0, "npc must detect the player to avoid shoving during navigation")
	assert_true((player.collision_mask & CollisionLayers.WORLD) != 0, "player must still collide with world geometry")
	assert_true((npc.collision_mask & CollisionLayers.WORLD) != 0, "npc must still collide with world geometry")
