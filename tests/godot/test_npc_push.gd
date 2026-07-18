extends "res://tests/godot/test_case.gd"

const PUSHABLE_NPC_SCRIPT := preload("res://tests/godot/fixtures/pushable_test_npc.gd")
const TEST_DELTA := 1.0 / 60.0
const PHYSICS_STEPS := 90


func test_hostile_npc_is_not_pushable() -> void:
	var npc := CharacterBody2D.new()
	npc.add_to_group(NpcPush.HOSTILE_GROUP)
	assert_false(NpcPush.can_be_pushed(npc), "hostile actors must ignore player push")
	npc.free()


func test_pushable_npc_respects_world_collision() -> void:
	var root := _make_root()
	var wall := _spawn_wall(root, Vector2(196, 0), Vector2(16, 160))
	var npc := _spawn_pushable_npc(root, Vector2(160, 80))
	var start_x := npc.global_position.x

	for _step in PHYSICS_STEPS:
		NpcPush.queue_push(npc, Vector2.RIGHT, 8.0)
		npc._physics_process(TEST_DELTA)

	assert_true(npc.global_position.x > start_x, "npc should move away from the player push")
	assert_true(npc.global_position.x < wall.global_position.x - 8.0, "npc must not pass through a wall")
	_cleanup_node(root)


func test_player_clears_npc_blocking_a_narrow_route() -> void:
	var root := _make_root()
	_spawn_wall(root, Vector2(80, 0), Vector2(16, 200))
	_spawn_wall(root, Vector2(240, 0), Vector2(16, 200))
	var npc := _spawn_pushable_npc(root, Vector2(160, 80))
	var player := _spawn_logic_player(root, Vector2(120, 80))
	var npc_start := npc.global_position

	_simulate_logic_player_push(player, npc, Vector2.RIGHT, PHYSICS_STEPS)

	assert_true(npc.global_position.distance_to(npc_start) > 12.0, "npc should be displaced from the doorway")
	assert_true(player.global_position.x > npc_start.x - 8.0, "player should pass the former blocker")
	_cleanup_node(root)


func test_displaced_npc_resumes_idle_after_recovery() -> void:
	var root := _make_root()
	var npc := _spawn_pushable_npc(root, Vector2(120, 80))
	var start := npc.global_position

	NpcPush.queue_push(npc, Vector2.RIGHT, 48.0)
	for _step in range(4):
		npc._physics_process(TEST_DELTA)

	var pushed_x := npc.global_position.x
	assert_true(pushed_x > start.x + 8.0, "push should move the npc before recovery")

	for _step in range(24):
		npc._physics_process(TEST_DELTA)

	assert_true(npc.velocity.is_zero_approx(), "npc should return to idle after recovery")
	NpcPush.queue_push(npc, Vector2.RIGHT, 24.0)
	npc._physics_process(TEST_DELTA)
	assert_true(npc.global_position.x > pushed_x + 4.0, "npc must accept another push after recovery")
	_cleanup_node(root)


func _simulate_logic_player_push(
	player: CharacterBody2D,
	npc: CharacterBody2D,
	direction: Vector2,
	steps: int
) -> void:
	for _step in steps:
		var movement_velocity := direction.normalized() * 240.0
		player.velocity = movement_velocity
		player.move_and_slide()
		NpcPush.apply_player_contact_pushes(player, movement_velocity, TEST_DELTA)


func _spawn_logic_player(parent: Node, position: Vector2) -> CharacterBody2D:
	var player := CharacterBody2D.new()
	CollisionLayers.apply_player(player)
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 16.0
	capsule.height = 32.0
	shape.shape = capsule
	player.add_child(shape)
	parent.add_child(player)
	player.global_position = position
	return player


func _spawn_pushable_npc(parent: Node, position: Vector2) -> CharacterBody2D:
	var npc := CharacterBody2D.new()
	npc.name = "PushableNpc"
	npc.set_script(PUSHABLE_NPC_SCRIPT)
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 12.0
	capsule.height = 24.0
	shape.shape = capsule
	npc.add_child(shape)
	parent.add_child(npc)
	npc.global_position = position
	return npc


func _spawn_wall(parent: Node, position: Vector2, size: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = size * 0.5
	wall.add_child(shape)
	wall.global_position = position
	parent.add_child(wall)
	return wall


func _make_root() -> Node2D:
	var root := Node2D.new()
	_tree().root.add_child(root)
	return root


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _cleanup_node(node: Node) -> void:
	if is_instance_valid(node):
		node.free()
