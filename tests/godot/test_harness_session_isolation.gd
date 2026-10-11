extends "res://tests/godot/test_case.gd"

const EXAMPLE_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]


func test_isolate_restores_demo_content_after_a_narrower_corpus() -> void:
	var poisoned := ContentDB.new()
	assert_true(poisoned.load_from_directories(EXAMPLE_DIRS))
	SessionState.content_db = poisoned
	SessionState.state = GameState.new()
	SessionState.state.bag.set_content_db(poisoned)
	assert_false(
		demo_content_ready(),
		"example corpus must omit at least one combat/quest sentinel"
	)

	assert_true(restore_demo_session())
	assert_true(demo_content_ready())
	assert_true(SessionState.content_db.has_record(SENTINEL_ENCOUNTER))
	assert_true(SessionState.content_db.has_record(SENTINEL_MECHANISM))
	assert_eq(SessionState.state.equipped_item(&"right_hand"), ITEM_FORGE_HAMMER)


func test_isolate_frees_leaked_root_hosts_and_releases_held_actions() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null)
	var leaked := Node2D.new()
	leaked.name = "IsolationLeakHost"
	tree.root.add_child(leaked)
	Input.action_press(PlayerActionKind.ACTION_ATTACK)
	assert_true(Input.is_action_pressed(PlayerActionKind.ACTION_ATTACK))

	isolate_session_globals()

	assert_false(is_instance_valid(leaked), "leaked root hosts must be freed")
	assert_false(Input.is_action_pressed(PlayerActionKind.ACTION_ATTACK))
	assert_true(SessionState.content_db.has_record(SENTINEL_ENCOUNTER))
