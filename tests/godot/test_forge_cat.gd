extends "res://tests/godot/test_case.gd"

const ControllerScript := preload("res://scripts/world/smithy_routine_controller.gd")
const MartScript := preload("res://scenes/reval_east/forge/smithy_mart.gd")

const CAT := &"char.forge_cat"
const FORBIDDEN_HUMAN_ACTIVITIES: Array[StringName] = [
	&"ap.eat.table",
	&"ap.prepare.board",
	&"ap.wash.basin",
	&"ap.forge.anvil",
	&"ap.forge.furnace",
	&"ap.hearth.tend",
]


func _make_cat_controller() -> SmithyRoutineController:
	var controller := ControllerScript.new()
	controller.definition = MartScript._merge_routine_overlay(
		"res://content/routines/kalev_smithy.json",
		"res://content/routines/forge_cat.json"
	)
	return controller


func test_cat_schedule_uses_only_cat_activity_points() -> void:
	var controller := _make_cat_controller()
	var context := {
		"phase_id": GameState.PHASE_PROLOGUE_DAY,
		"time_band": &"morning",
		"seed": 1343,
	}
	var seen: Array[StringName] = []
	for _i in 4:
		var next := controller.pick_next_activity(CAT, context)
		if next.is_empty():
			break
		assert_true(next.begins_with(&"ap.cat."), "Cat must stay on cat-only anchors: %s" % next)
		seen.append(next)
		assert_true(controller.begin_activity(CAT, next, context))
		controller.end_activity(CAT, ControllerScript.REASON_COMPLETED)
	assert_eq(
		seen,
		[&"ap.cat.sleep", &"ap.cat.groom", &"ap.cat.warmth", &"ap.cat.feed"]
	)
	controller.free()


func test_cat_cannot_claim_human_stations() -> void:
	var controller := _make_cat_controller()
	var context := {
		"phase_id": GameState.PHASE_PROLOGUE_DAY,
		"time_band": &"any",
	}
	for activity_id in FORBIDDEN_HUMAN_ACTIVITIES:
		if controller.get_activity_point(activity_id) == null:
			continue
		assert_false(
			controller.can_begin(CAT, activity_id, context),
			"Cat must not claim %s" % activity_id
		)
	controller.free()


func test_cat_animation_maps_to_contextual_states() -> void:
	var cat := ForgeCat.new()
	_mount_cat(cat)
	cat.set_routine_context(GameState.PHASE_PROLOGUE_DAY, &"any")
	cat._current_activity = &"ap.cat.sleep"
	cat._activity_mode = ForgeCat.ActivityMode.ACTING
	assert_eq(cat.view_animation(), &"sleep")
	cat._current_activity = &"ap.cat.groom"
	assert_eq(cat.view_animation(), &"lick")
	cat._current_activity = &"ap.cat.warmth"
	assert_eq(cat.view_animation(), &"sleep")
	cat.free()


func test_cat_warmth_uses_domestic_hearth_not_industrial_forge() -> void:
	var controller := _make_cat_controller()
	var warmth := controller.get_activity_point(&"ap.cat.warmth")
	var feed := controller.get_activity_point(&"ap.cat.feed")
	assert_true(warmth != null)
	assert_true(feed != null)
	assert_eq(warmth.prop_id, &"domestic_hearth")
	assert_eq(feed.prop_id, &"domestic_hearth")
	assert_ne(warmth.prop_id, &"forge_furnace")
	controller.free()


func _mount_cat(cat: ForgeCat) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(cat)
