extends "res://tests/godot/test_case.gd"

const CONTENT_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]
const ILLUSIONARY_DOUBLE := &"spell.pagan.illusionary_double"
const GRANT_ILLUSIONARY_DOUBLE := &"magic.grant.starter_illusionary_double"
const MIND_DECEPTION: Array[StringName] = [&"element.mind", &"element.deception"]
const CAST_EXECUTOR := preload("res://scripts/magic/magic_cast_executor_2d.gd")
const ENEMY_SCRIPT := preload("res://scripts/combat/combat_room_enemy.gd")


func test_mind_plus_deception_resolves_to_authored_summon() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))
	var state := GameState.new()
	state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 3)
	assert_true(MagicResolver.apply_grant_operation(state, db, GRANT_ILLUSIONARY_DOUBLE))

	var result := MagicResolver.cast(state, db, &"", MIND_DECEPTION)
	assert_true(result["ok"])
	assert_eq(result["target_id"], ILLUSIONARY_DOUBLE)
	assert_eq(state.get_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER), 0)
	var delivery: Dictionary = result["effect"]["delivery"]
	assert_eq(delivery["kind"], "summon")
	assert_eq(delivery["summon_kind"], "illusionary_double")
	assert_eq(delivery["lifetime_sec"], 6.0)
	assert_eq(delivery["health"], 10.0)


func test_double_redirects_nearby_enemy_and_restores_target_after_lifetime() -> void:
	var fixture := _make_combat_fixture()
	var host := fixture["host"] as Node2D
	var player := fixture["player"] as Node2D
	var near_enemy := fixture["near_enemy"] as CombatRoomEnemy
	var far_enemy := fixture["far_enemy"] as CombatRoomEnemy
	var result := _cast_result()
	var double := CAST_EXECUTOR.execute(result, player, Vector2.RIGHT, host) as Node2D

	assert_true(double != null)
	assert_eq(double.global_position, Vector2(36.0, 0.0))
	assert_eq(near_enemy.get_ai_target(), double, "nearby AI should attack the decoy")
	assert_eq(far_enemy.get_ai_target(), player, "AI outside aggro radius should keep its target")
	double.advance(6.0)
	assert_eq(near_enemy.get_ai_target(), player, "expiry should restore the prior target")
	assert_true(double.is_queued_for_deletion(), "expired double should clean itself up")
	host.free()


func test_damage_destroys_double_and_newer_enemy_decision_wins_cleanup() -> void:
	var fixture := _make_combat_fixture()
	var host := fixture["host"] as Node2D
	var player := fixture["player"] as Node2D
	var near_enemy := fixture["near_enemy"] as CombatRoomEnemy
	var fallback_target := Node2D.new()
	host.add_child(fallback_target)
	var double := CAST_EXECUTOR.execute(_cast_result(), player, Vector2.RIGHT, host) as Node2D

	assert_eq(near_enemy.get_ai_target(), double)
	near_enemy.set_ai_target(fallback_target)
	assert_eq(double.take_damage(10.0), 10.0)
	assert_eq(near_enemy.get_ai_target(), fallback_target)
	assert_true(double.is_queued_for_deletion())
	host.free()


func test_double_has_authored_collision_and_rejects_unknown_summon_kind() -> void:
	var fixture := _make_combat_fixture()
	var host := fixture["host"] as Node2D
	var player := fixture["player"] as Node2D
	var result := _cast_result()
	var double := CAST_EXECUTOR.execute(result, player, Vector2.RIGHT, host) as Area2D

	assert_true(double != null)
	assert_eq(double.collision_layer, CollisionLayers.PLAYER)
	assert_eq(double.collision_mask, CollisionLayers.MASK_PLAYER)
	var collision := double.get_node_or_null("CollisionShape2D") as CollisionShape2D
	assert_true(collision != null)
	var circle := collision.shape as CircleShape2D
	assert_true(circle != null)
	assert_eq(circle.radius, 18.0)

	var invalid := _cast_result()
	invalid["effect"]["delivery"]["summon_kind"] = "unreviewed_summon"
	assert_eq(CAST_EXECUTOR.execute(invalid, player, Vector2.RIGHT, host), null)
	host.free()


func _cast_result() -> Dictionary:
	return {
		"ok": true,
		"target_id": ILLUSIONARY_DOUBLE,
		"effect": {
			"delivery": {
				"kind": "summon",
				"summon_kind": "illusionary_double",
				"lifetime_sec": 6.0,
				"health": 10.0,
				"collision_radius": 18.0,
				"aggro_radius": 240.0,
				"spawn_offset": 36.0,
			}
		}
	}


func _make_combat_fixture() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var host := Node2D.new()
	tree.root.add_child(host)
	var player := Node2D.new()
	player.name = "PlayerTarget"
	host.add_child(player)
	var near_enemy := ENEMY_SCRIPT.new() as CombatRoomEnemy
	host.add_child(near_enemy)
	near_enemy.global_position = Vector2(120.0, 0.0)
	near_enemy.set_ai_target(player)
	var far_enemy := ENEMY_SCRIPT.new() as CombatRoomEnemy
	host.add_child(far_enemy)
	far_enemy.global_position = Vector2(400.0, 0.0)
	far_enemy.set_ai_target(player)
	return {
		"host": host,
		"player": player,
		"near_enemy": near_enemy,
		"far_enemy": far_enemy,
	}
