extends "res://tests/godot/test_case.gd"

const ControllerScript := preload("res://scripts/world/smithy_routine_controller.gd")
const DefinitionScript := preload("res://scripts/world/smithy_routine_definition.gd")
const MartScript := preload("res://scenes/reval_east/forge/smithy_mart.gd")

const MART := &"char.mart"
const KALEV := &"char.kalev"
const CAT := &"char.forge_cat"


func _make_merged_controller() -> SmithyRoutineController:
	var controller := ControllerScript.new()
	controller.definition = MartScript._merge_routine_overlay(
		"res://content/routines/kalev_smithy.json",
		"res://content/routines/mart_smithy.json"
	)
	return controller


func _make_cat_controller() -> SmithyRoutineController:
	var controller := ControllerScript.new()
	controller.definition = MartScript._merge_routine_overlay(
		"res://content/routines/kalev_smithy.json",
		"res://content/routines/forge_cat.json"
	)
	return controller


func test_mart_hidden_while_mart_missing_flag_set() -> void:
	var mart := SmithyMart.new()
	_mount_actor(mart)
	mart.set_routine_context(GameState.PHASE_INVESTIGATION_MORNING, &"morning", true)
	assert_false(mart.visible)
	assert_false(mart.is_physics_processing())
	mart.free()


func test_mart_routine_starts_when_mart_returns() -> void:
	var mart := SmithyMart.new()
	_mount_actor(mart)
	mart.configure_navigation(RID(), Vector2(624, 240))
	mart.set_routine_context(GameState.PHASE_INVESTIGATION_MORNING, &"morning", false)
	assert_true(mart.visible)
	assert_true(mart.is_physics_processing())
	mart.free()


func test_mart_and_kalev_cannot_share_exclusive_station() -> void:
	var controller := _make_merged_controller()
	var context := {
		"phase_id": GameState.PHASE_INVESTIGATION_MORNING,
		"time_band": &"midday",
		"seed": 1343,
		"mart_missing": false,
	}
	assert_true(controller.begin_activity(KALEV, &"ap.eat.table", context))
	assert_false(controller.can_begin(MART, &"ap.eat.table", context))
	controller.free()


func test_anvil_bound_approaches_stand_beside_not_on_anvil() -> void:
	# WHY: 3D anvil GLB made cell-center approaches read as standing on the iron.
	var definition: MapDefinition = preload(
		"res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd"
	).create()
	var anvil_rect := Rect2()
	for prop in definition.props:
		if prop.get("id", &"") == &"forge_anvil":
			anvil_rect = prop.get("footprint", Rect2()) as Rect2
			break
	assert_false(anvil_rect == Rect2(), "forge_anvil footprint must exist")
	var controller := _make_merged_controller()
	for activity_id in [&"ap.forge.anvil", &"ap.visitor.inspect"]:
		var point := controller.get_activity_point(activity_id)
		assert_true(point != null, "%s missing" % String(activity_id))
		assert_false(
			anvil_rect.has_point(point.approach_position),
			"%s approach %s must stand beside the anvil, not on it"
			% [String(activity_id), str(point.approach_position)]
		)
	controller.free()


func test_mart_has_no_prologue_schedule() -> void:
	var controller := _make_merged_controller()
	assert_eq(controller.definition.schedule_for(MART, GameState.PHASE_PROLOGUE_DAY, &"morning").size(), 0)
	var mart := SmithyMart.new()
	_mount_actor(mart)
	mart.set_routine_context(GameState.PHASE_PROLOGUE_DAY, &"morning", false)
	assert_false(mart.visible)
	mart.free()
	controller.free()


func _mount_actor(actor: CharacterBody2D) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(actor)
