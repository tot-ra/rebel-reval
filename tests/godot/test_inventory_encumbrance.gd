extends RefCounted

const PLAYER_SCENE := preload("res://player.tscn")
const TEST_DELTA := 1.0

var _failures: Array[String] = []
var _session: Node


func test_encumbrance_reduces_run_speed() -> void:
	_bootstrap_session()
	SessionState.state.bag.try_add(&"item.forge_hammer")
	SessionState.state.bag.try_add(&"item.forge_hammer")

	var player := _create_player()
	Input.action_press("ui_right")
	player._physics_process(TEST_DELTA)
	Input.action_release("ui_right")

	var expected: float = player.run_speed * SessionState.state.bag.get_speed_multiplier()
	_assert_eq(player.velocity.x, expected, "Heavy bag must reduce run speed")
	player.free()
	_teardown_session()


func test_inventory_open_blocks_movement() -> void:
	_bootstrap_session()
	var player := _create_player()
	var controller := player.get_node("InventoryController") as InventoryController
	controller.toggle()
	Input.action_press("ui_right")
	player._physics_process(TEST_DELTA)
	Input.action_release("ui_right")
	_assert_eq(player.velocity, Vector2.ZERO, "Open bag must block movement")
	player.free()
	_teardown_session()


func _bootstrap_session() -> void:
	_session = SessionState
	SessionState.state = GameState.new()
	SessionState.content_db = ContentDB.new()
	SessionState.content_db.load_from_directories([
		"res://content/demo",
		"res://content/examples/valid",
	])
	SessionState.state.bag = InventoryBag.new()
	SessionState.state.bag.set_content_db(SessionState.content_db)


func _teardown_session() -> void:
	SessionState.state = GameState.new()
	SessionState.state.bag.set_content_db(SessionState.content_db)


func _create_player() -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(player)
	return player


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s - expected <%s> but got <%s>" % [message, str(expected), str(actual)])


func _get_failures() -> Array[String]:
	return _failures.duplicate()
