extends "res://tests/godot/test_case.gd"

const CONTENT_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]
const ModelScript := preload("res://scripts/magic/spellforge_model.gd")
const HudScript := preload("res://scripts/magic/spellforge_hud.gd")
const ControllerScript := preload("res://scripts/magic/spellforge_controller.gd")
const BindingSettings := preload("res://scripts/settings/input_binding_settings.gd")
const FIREBALL := &"spell.pagan.fireball"
const GRANT_FIREBALL := &"magic.grant.starter_fireball"
const FIRE_AIR: Array[StringName] = [&"element.fire", &"element.air"]


func _make_db() -> ContentDB:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))
	return db


func test_model_limits_selection_to_learned_elements_and_three_slots() -> void:
	var state := GameState.new()
	var db := _make_db()
	assert_true(MagicResolver.apply_grant_operation(state, db, GRANT_FIREBALL))
	var model := ModelScript.new() as SpellforgeModel
	model.configure(state, db)

	assert_eq(model.learned_elements(), [&"element.air", &"element.fire"])
	assert_false(model.select_element(&"element.earth"))
	assert_true(model.feedback_text().contains("not learned"))
	assert_true(model.select_element(&"element.fire"))
	assert_true(model.select_element(&"element.air"))
	assert_true(model.select_element(&"element.fire"))
	assert_false(model.select_element(&"element.air"))
	assert_eq(model.selected_sequence().size(), 3)
	assert_true(model.feedback_text().contains("at most three"))


func test_unknown_locked_and_resource_failures_have_player_feedback() -> void:
	var state := GameState.new()
	var db := _make_db()
	var model := ModelScript.new() as SpellforgeModel
	model.configure(state, db)
	assert_false(model.select_element(&"element.fire"), "locked elements cannot enter the sequence")
	assert_eq(
		SpellforgeModel.failure_text(MagicResolver.FAILURE_LOCKED),
		"That recipe has not been learned."
	)
	assert_eq(
		SpellforgeModel.failure_text(MagicResolver.FAILURE_INSUFFICIENT_WILLPOWER),
		"Not enough willpower."
	)
	assert_eq(
		SpellforgeModel.failure_text(MagicResolver.FAILURE_UNKNOWN_SEQUENCE),
		"No authored spell matches that sequence."
	)


func test_cookbook_reveals_authored_sequences_and_lock_state() -> void:
	var state := GameState.new()
	var db := _make_db()
	assert_true(MagicResolver.apply_grant_operation(state, db, GRANT_FIREBALL))
	var model := ModelScript.new() as SpellforgeModel
	model.configure(state, db)
	var fireball := _cookbook_row(model.cookbook_rows(), FIREBALL)
	var spark := _cookbook_row(model.cookbook_rows(), &"spell.pagan.spark")

	assert_eq(fireball["sequence_text"], "Fire + Air")
	assert_true(fireball["learned"])
	assert_false(spark["learned"])
	assert_true(String(fireball["summary"]).contains("projectile"))


func test_fireball_cast_executes_projectile_and_spends_willpower() -> void:
	var state := GameState.new()
	var db := _make_db()
	state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 2)
	assert_true(MagicResolver.apply_grant_operation(state, db, GRANT_FIREBALL))
	var model := ModelScript.new() as SpellforgeModel
	model.configure(state, db)
	for element_id in FIRE_AIR:
		assert_true(model.select_element(element_id))

	var tree := Engine.get_main_loop() as SceneTree
	var host := Node2D.new()
	tree.root.add_child(host)
	var caster := Node2D.new()
	host.add_child(caster)
	var result := model.cast(caster, Vector2.RIGHT, host)

	assert_true(result["ok"])
	assert_eq(result["target_id"], FIREBALL)
	assert_eq(state.get_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER), 0)
	assert_true(host.get_child_count() >= 2, "casting must add the projectile delivery")
	assert_eq(model.selected_sequence(), [])
	assert_eq(model.feedback_text(), "Fireball cast.")
	host.free()


func test_hud_uses_text_controls_and_exposes_cookbook_without_legacy_sprites() -> void:
	var state := GameState.new()
	var db := _make_db()
	assert_true(MagicResolver.apply_grant_operation(state, db, GRANT_FIREBALL))
	var model := ModelScript.new() as SpellforgeModel
	model.configure(state, db)
	var hud := HudScript.new() as SpellforgeHud
	hud.configure(model)
	(Engine.get_main_loop() as SceneTree).root.add_child(hud)
	hud.open()

	assert_true(hud.find_child("FireElement", true, false) is Button)
	assert_true(hud.find_child("FireballRecipe", true, false) is Label)
	assert_true(hud.find_child("CastButton", true, false) is Button)
	var hud_source := FileAccess.get_file_as_string("res://scripts/magic/spellforge_hud.gd")
	assert_false(hud_source.contains("spell-hud.png"))
	assert_false(hud_source.contains("archive/2d_sprites_inspiration"))
	hud.free()


func test_quick_hud_stays_visible_when_cookbook_is_closed() -> void:
	var state := GameState.new()
	var db := _make_db()
	assert_true(MagicResolver.apply_grant_operation(state, db, GRANT_FIREBALL))
	var model := ModelScript.new() as SpellforgeModel
	model.configure(state, db)
	var hud := HudScript.new() as SpellforgeHud
	hud.configure(model)
	(Engine.get_main_loop() as SceneTree).root.add_child(hud)

	assert_true(hud.visible)
	assert_false(hud.is_open(), "cookbook starts closed without hiding quick casting")
	assert_true(hud.find_child("QuickSpellHud", true, false) is Control)
	assert_true(hud.find_child("QuickSequenceLabel", true, false) is Label)
	assert_eq((hud.find_child("QuickFireElement", true, false) as Label).text, "[4] Fire")
	hud.free()


func test_catalog_shortcuts_make_four_plus_one_fireball_sequence() -> void:
	var state := GameState.new()
	var db := _make_db()
	assert_true(MagicResolver.apply_grant_operation(state, db, GRANT_FIREBALL))
	var model := ModelScript.new() as SpellforgeModel
	model.configure(state, db)
	var controller := ControllerScript.new() as SpellforgeController
	var hud := HudScript.new() as SpellforgeHud
	hud.configure(model)
	(Engine.get_main_loop() as SceneTree).root.add_child(hud)
	controller.set("_model", model)
	controller.set("_hud", hud)

	controller.call("_select_catalog_index", 3)
	controller.call("_select_catalog_index", 0)

	assert_eq(model.selected_sequence(), FIRE_AIR)
	hud.free()
	controller.free()


func test_spellforge_actions_are_remappable_for_keyboard_and_gamepad() -> void:
	var bindings = BindingSettings.default_settings()
	for action: StringName in [
		&"toggle_spellforge",
		&"spellforge_element_1",
		&"spellforge_element_2",
		&"spellforge_element_3",
		&"spellforge_element_4",
		&"spellforge_element_5",
		&"spellforge_remove",
		&"spellforge_cast",
	]:
		assert_true(BindingSettings.has_action(action))
		assert_false(
			bindings.events_for(action, BindingSettings.DEVICE_KEYBOARD_MOUSE).is_empty()
		)
		assert_false(bindings.events_for(action, BindingSettings.DEVICE_GAMEPAD).is_empty())
	var cast_events = bindings.events_for(
		&"spellforge_cast", BindingSettings.DEVICE_KEYBOARD_MOUSE
	)
	var has_left_click := false
	for event: InputEvent in cast_events:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			has_left_click = true
	assert_true(has_left_click, "quick cast must include the left mouse button")


func _cookbook_row(rows: Array[Dictionary], target_id: StringName) -> Dictionary:
	for row in rows:
		if row["id"] == target_id:
			return row
	return {}
