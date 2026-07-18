extends "res://tests/godot/test_case.gd"


func test_player_and_npc_ignore_each_other_but_collide_with_world() -> void:
	var player := CharacterBody2D.new()
	CollisionLayers.apply_player(player)
	var npc := CharacterBody2D.new()
	CollisionLayers.apply_npc(npc)

	assert_eq(player.collision_mask & npc.collision_layer, 0, "player must not collide with npc bodies")
	assert_eq(npc.collision_mask & player.collision_layer, 0, "npc must not collide with the player body")
	assert_true((player.collision_mask & CollisionLayers.WORLD) != 0, "player must still collide with world geometry")
	assert_true((npc.collision_mask & CollisionLayers.WORLD) != 0, "npc must still collide with world geometry")
