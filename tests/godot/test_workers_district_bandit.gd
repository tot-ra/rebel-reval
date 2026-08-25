extends "res://tests/godot/test_case.gd"

const BANDIT_RIG_SCENE := preload("res://assets/characters/variants/bandit.tscn")
const BANDIT_ACTOR_SCENE := preload("res://scenes/reval_east/workers_district_bandit.tscn")

func test_bandit_rig_keeps_shared_animation_contract_and_sword() -> void:
	var rig := BANDIT_RIG_SCENE.instantiate() as SharedCharacterRig
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(rig)
	assert_eq(rig.validation_errors(), [])
	assert_eq(rig.variant_id(), &"char.bandit")
	assert_true(rig.has_equipment())
	assert_true(rig.has_animation(&"sword_attack"))
	assert_true(rig.lod_visibility_configured())
	rig.queue_free()

func test_workers_district_bandit_is_a_damageable_enemy() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var player := Node2D.new()
	tree.root.add_child(player)
	var bandit := BANDIT_ACTOR_SCENE.instantiate() as WorkersDistrictBandit
	tree.root.add_child(bandit)
	bandit.configure_bandit(player)
	assert_eq(bandit.get_machine().archetype.id, EnemyArchetype.ID_BANDIT)
	assert_true(bandit.is_in_group(&"combat_damageable"))
	assert_true(bandit.is_in_group(&"map_view_actor"))
	assert_eq(bandit.take_damage(100.0), 30.0)
	assert_true(bandit.get_machine().is_dead())
	assert_eq(bandit.view_animation(), &"fall")
	bandit.queue_free()
	player.queue_free()


func test_bandit_chases_stops_to_attack_and_retreats_when_wounded() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var player := Node2D.new()
	player.global_position = Vector2(100.0, 0.0)
	tree.root.add_child(player)
	var bandit := BANDIT_ACTOR_SCENE.instantiate() as WorkersDistrictBandit
	bandit.global_position = Vector2.ZERO
	tree.root.add_child(bandit)
	bandit.configure_bandit(player)

	bandit.get_machine().state = EnemyCombatState.State.CHASE
	bandit._update_motion(0.1)
	assert_true(bandit.global_position.x > 0.0, "Bandit should move toward the player")
	assert_eq(bandit.view_animation(), &"run")

	bandit.get_machine().state = EnemyCombatState.State.TELEGRAPH
	var stopped_at := bandit.global_position
	bandit._update_motion(0.1)
	assert_eq(bandit.global_position, stopped_at, "Bandit must stop while telegraphing")
	assert_eq(bandit.view_animation(), &"guard")

	bandit.get_machine().state = EnemyCombatState.State.RETREAT
	bandit._update_motion(0.1)
	assert_true(bandit.global_position.x < stopped_at.x, "Wounded bandit should run away")
	assert_eq(bandit.view_animation(), &"run")
	bandit.queue_free()
	player.queue_free()
