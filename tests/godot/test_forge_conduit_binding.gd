extends "res://tests/godot/test_case.gd"

## P7-010 forge-conduit hook: Kalev's anvil work in the smithy binds the hammer
## conduit for the rest of the visit, and leaving the smithy clears it.

const FORGE_SCENE := preload("res://scenes/reval_east/forge/forge.tscn")


func test_kalev_anvil_work_binds_conduit_until_the_smithy_is_left() -> void:
	SessionState.state = GameState.new()
	SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS)
	var state := SessionState.state
	var tree := Engine.get_main_loop() as SceneTree
	var forge: Node2D = FORGE_SCENE.instantiate()
	tree.root.add_child(forge)
	var routine := forge.get_node("KalevDomesticRoutineController") as SmithyRoutineController
	assert_true(routine != null, "forge should own Kalev's domestic routine controller")
	assert_false(state.is_forge_conduit_bound())

	routine.activity_began.emit(&"char.mart", &"ap.forge.anvil")
	assert_false(state.is_forge_conduit_bound(), "Mart at the anvil must not bind Kalev's conduit")
	routine.activity_began.emit(&"char.kalev", &"ap.forge.bellows")
	assert_false(state.is_forge_conduit_bound(), "only anvil work binds the conduit")

	routine.activity_began.emit(&"char.kalev", &"ap.forge.anvil")
	assert_true(state.is_forge_conduit_bound())
	routine.activity_ended.emit(&"char.kalev", &"ap.forge.anvil", &"completed")
	assert_true(state.is_forge_conduit_bound(), "binding outlives the short anvil vignette")

	tree.root.remove_child(forge)
	assert_false(state.is_forge_conduit_bound(), "leaving the smithy clears the forge binding")
	forge.free()


func test_restored_smithy_binding_is_cleared_when_leaving() -> void:
	SessionState.state = GameState.new()
	SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS)
	var state := SessionState.state
	# Simulates loading a save that was made in the smithy after anvil work.
	state.set_forge_conduit_bound(true)
	var tree := Engine.get_main_loop() as SceneTree
	var forge: Node2D = FORGE_SCENE.instantiate()
	tree.root.add_child(forge)
	assert_true(state.is_forge_conduit_bound())

	tree.root.remove_child(forge)
	assert_false(state.is_forge_conduit_bound())
	forge.free()
