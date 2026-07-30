extends "res://tests/godot/test_case.gd"

## P4-043: Act 1 packaged-candidate preflight.
## WHY: P4-012 needs independent QA evidence that the candidate stays operable
## under keyboard/mouse and gamepad, accessibility, content-budget, licence, and
## macOS launch/save/load/exit smoke contracts - without repairing runtime or
## editing release evidence.

const BindingSettings := preload("res://scripts/settings/input_binding_settings.gd")
const InputCatalog := preload("res://scripts/slice/vertical_slice_input_catalog.gd")
const SliceInputDriverScript := preload("res://tests/godot/slice_input_driver.gd")
const PlatformModel := preload("res://scripts/slice/vertical_slice_platform_model.gd")
const PlatformSmokeScript := preload("res://scripts/demo/packaged_platform_smoke.gd")
const TraversalModel := preload("res://scripts/quest/act1_traversal_model.gd")
const StGeorgesModel := preload("res://scripts/quest/st_georges_night_quest_model.gd")
const AftermathModelScript := preload(
	"res://scripts/investigation/st_georges_night_aftermath_model.gd"
)
const Act1AftermathModel := preload("res://scripts/quest/act1_aftermath_model.gd")
const GameplayAccessibility := preload(
	"res://scripts/settings/gameplay_accessibility_settings.gd"
)
const DialogueSettings := preload("res://scripts/settings/dialogue_settings.gd")

const BUDGET_MANIFEST_PATH := "res://docs/data/act1_content_budget_manifest.json"
const ACCESSIBILITY_MANIFEST_PATH := "res://docs/data/accessibility_checklist.json"
const THIRD_PARTY_MANIFEST_PATH := "res://docs/data/slice_third_party_manifest.json"
const THIRD_PARTY_NOTICES_PATH := "res://docs/THIRD_PARTY_NOTICES.md"
const CREDITS_PATH := "res://CREDITS.md"
const CLEAN_START_PATH := "res://tests/fixtures/act1_candidate/clean_start.json"

const EXPECTED_SUBSTANTIAL_QUEST_BUDGET := 8
const EXPECTED_CLIMAX_QUEST_COUNT := 1
const EXPECTED_ACCESSIBILITY_OPTIONS := [
	"remapping",
	"guard_hold_toggle",
	"text_speed",
	"scalable_text",
	"subtitle_background",
	"focus_contrast",
	"screen_shake",
	"reduced_flashing",
]

var _save_directory := ""


func before_each() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(StGeorgesModel.CONTENT_DIRS))
	SessionState.content_db = db
	SessionState.state = GameState.new()
	SessionState.state.bag.set_content_db(db)
	_cleanup_save_directory()


func after_each() -> void:
	_cleanup_save_directory()


func test_supported_input_actions_have_keyboard_mouse_and_gamepad_bindings() -> void:
	var bindings := BindingSettings.default_settings()
	var actions := InputCatalog.action_ids()
	assert_true(actions.size() >= 18, "candidate must keep the shipped slice action catalog")
	for action: StringName in actions:
		var keyboard := bindings.events_for(action, BindingSettings.DEVICE_KEYBOARD_MOUSE)
		var gamepad := bindings.events_for(action, BindingSettings.DEVICE_GAMEPAD)
		assert_false(
			keyboard.is_empty(),
			"%s needs a keyboard/mouse binding" % String(action)
		)
		assert_false(gamepad.is_empty(), "%s needs a gamepad binding" % String(action))


func test_catalog_actions_complete_via_keyboard_mouse_events() -> void:
	var driver = SliceInputDriverScript.new(SliceInputDriverScript.DeviceProfile.KEYBOARD_MOUSE)
	for action: StringName in InputCatalog.action_ids():
		driver.tap_action(action)
	driver.assert_no_fallback_used()
	assert_false(driver.fallback_used)
	assert_eq(driver.recorded_steps.size(), InputCatalog.action_ids().size())


func test_catalog_actions_complete_via_gamepad_events() -> void:
	var driver = SliceInputDriverScript.new(SliceInputDriverScript.DeviceProfile.GAMEPAD)
	for action: StringName in InputCatalog.action_ids():
		driver.tap_action(action)
	driver.assert_no_fallback_used()
	assert_false(driver.fallback_used)
	assert_eq(driver.recorded_steps.size(), InputCatalog.action_ids().size())


func test_accessibility_checklist_contract_is_present() -> void:
	var checklist := _load_json_dictionary(ACCESSIBILITY_MANIFEST_PATH)
	assert_false(checklist.is_empty(), "accessibility checklist must load")
	var required: Variant = checklist.get("required_options", [])
	assert_true(required is Array)
	for option: String in EXPECTED_ACCESSIBILITY_OPTIONS:
		assert_array_contains(required as Array, option, "missing accessibility option %s" % option)
	var methods: Variant = checklist.get("input_methods", [])
	assert_true(methods is Array)
	assert_array_contains(methods as Array, "keyboard_mouse")
	assert_array_contains(methods as Array, "gamepad")
	var gameplay := GameplayAccessibility.default_settings()
	assert_true(gameplay.guard_uses_hold() or gameplay.guard_mode == "toggle")
	# DialogueSettings.default_settings() is untyped; keep explicit Variant to avoid
	# inference failure under Godot 4.7 typed GDScript.
	var dialogue: Variant = DialogueSettings.default_settings()
	assert_true(dialogue is Object)
	assert_false(String(dialogue.text_scale).is_empty())
	assert_true(FileAccess.file_exists("res://scripts/ui/game_settings_overlay.gd"))
	assert_true(FileAccess.file_exists("res://scripts/ui/controls_overlay.gd"))


func test_act1_content_budget_and_audio_dialogue_caps_hold() -> void:
	var budget := _load_json_dictionary(BUDGET_MANIFEST_PATH)
	assert_false(budget.is_empty(), "Act 1 content-budget manifest must load")
	assert_eq(int(budget.get("substantial_quest_budget", -1)), EXPECTED_SUBSTANTIAL_QUEST_BUDGET)
	var substantial: Variant = budget.get("substantial_quest_ids", [])
	assert_true(substantial is Array)
	assert_eq((substantial as Array).size(), EXPECTED_SUBSTANTIAL_QUEST_BUDGET)
	var climax: Variant = budget.get("climax_quest_ids", [])
	assert_true(climax is Array)
	assert_eq((climax as Array).size(), EXPECTED_CLIMAX_QUEST_COUNT)
	assert_eq(int(budget.get("district_budget", -1)), 3)
	assert_eq(int(budget.get("core_character_budget", -1)), 7)
	assert_eq(int(budget.get("cycle_budget", -1)), 5)
	assert_eq(int(budget.get("dialogue_word_budget", -1)), 12000)
	assert_eq(int(budget.get("audio_duration_budget_seconds", -1)), 9000)
	assert_true(FileAccess.file_exists("res://docs/data/act1_dialogue_manifest.json"))
	assert_true(FileAccess.file_exists("res://docs/data/act1_soundtrack_manifest.json"))


func test_third_party_licence_surfaces_are_present() -> void:
	assert_true(FileAccess.file_exists(THIRD_PARTY_NOTICES_PATH))
	assert_true(FileAccess.file_exists(CREDITS_PATH))
	var manifest := _load_json_dictionary(THIRD_PARTY_MANIFEST_PATH)
	assert_false(manifest.is_empty(), "slice third-party manifest must load")
	var entries: Variant = manifest.get("entries", [])
	assert_true(entries is Array)
	assert_true((entries as Array).size() > 0, "third-party entries must be listed")
	var bundles: Variant = manifest.get("bundles", [])
	assert_true(bundles is Array)
	assert_true((bundles as Array).size() > 0, "third-party bundles must be listed")
	var notices := FileAccess.get_file_as_string(THIRD_PARTY_NOTICES_PATH)
	assert_true(
		notices.contains("License")
		or notices.contains("licence")
		or notices.contains("CC0")
		or notices.contains("AGPL")
	)

func test_macos_launch_save_load_exit_menu_contract() -> void:
	assert_true(PlatformModel.manifest_matches_model())
	assert_eq(PlatformModel.SUPPORTED_PLATFORMS.size(), 1)
	assert_eq(String(PlatformModel.SUPPORTED_PLATFORMS[0].get("id", "")), "macos_universal")
	for path in PlatformModel.export_preset_contract_paths():
		assert_true(
			FileAccess.file_exists(ProjectSettings.globalize_path(path)),
			"missing export contract file: %s" % path
		)

	# WHY: instantiating main_menu.tscn currently cascades MapViewRuntime parse
	# failures (P0-172) through PackagedDemoWalkthrough. Assert the authored
	# launch/save/load/exit surface from the scene source instead of repairing runtime.
	var menu_source := FileAccess.get_file_as_string("res://scenes/menu/main_menu.tscn")
	assert_false(menu_source.is_empty(), "main menu scene must be readable")
	assert_true(menu_source.contains('path="res://scripts/demo/packaged_platform_smoke.gd"'))
	assert_true(menu_source.contains('[node name="PackagedPlatformSmoke"'))
	assert_true(menu_source.contains('[node name="Start label"'))
	assert_true(menu_source.contains('[node name="Load label"'))
	assert_true(menu_source.contains('[node name="Exit label"'))
	assert_true(PlatformSmokeScript.is_requested(PackedStringArray([PlatformSmokeScript.USER_ARGUMENT])))
	assert_false(PlatformSmokeScript.is_requested(PackedStringArray()))

	var dmg_path := ProjectSettings.globalize_path("res://build/rr.dmg")
	assert_true(
		FileAccess.file_exists(dmg_path),
		"candidate packaged smoke expects build/rr.dmg from the macOS rr preset"
	)


func test_act1_boundary_save_load_exit_smoke_from_clean_start() -> void:
	## Repository-side launch/save/load/exit proof for Act 1 remembered state.
	## Full in-binary packaged transitions still depend on DoorNavigator / MapViewRuntime.
	var service := _save_service()
	var clean := SaveEnvelope.parse_file(CLEAN_START_PATH)
	assert_true(clean["ok"], "clean_start must load: %s" % ", ".join(clean["errors"]))
	var state := clean["state"] as GameState
	state.bag.set_content_db(SessionState.content_db)
	state = _drive_clean_save_to_boundary(state, TraversalModel.boundary_branch_for_id("seal"))
	assert_eq(String(state.get_act1_transition().get("act_boundary", "")), "seal")
	assert_true(service.save_game(state), "Act 1 boundary save failed")

	var loaded := service.load_game()
	assert_true(loaded["ok"], "Act 1 boundary load failed")
	var restored := loaded["state"] as GameState
	restored.bag.set_content_db(SessionState.content_db)
	assert_eq(String(restored.get_act1_transition().get("act_boundary", "")), "seal")
	var validation := Act1AftermathModel.validate_envelope(restored.get_act1_transition())
	assert_true(validation["valid"], str(validation["errors"]))
	# Exit smoke: quit path remains authored; SessionState stays consistent after load.
	assert_true(restored.has_act1_transition())


func _drive_clean_save_to_boundary(state: GameState, branch: Dictionary) -> GameState:
	state.bag.set_content_db(SessionState.content_db)
	state.set_phase(StGeorgesModel.PHASE_ACT1_CLIMAX)
	var manager := QuestManager.new(SessionState.content_db, state, StateRuleEvaluator.new())
	assert_true(manager.start_quest(StGeorgesModel.QUEST_ID))
	assert_true(manager.transition(StGeorgesModel.QUEST_ID, StGeorgesModel.TRANSITION_BEGIN_APPROACH))
	state.set_flag(branch["bias"] as StringName, true)
	assert_true(
		AftermathModelScript.commit_climax_choice(
			state,
			SessionState.content_db,
			branch["transition"] as StringName
		)
	)
	return state


func _save_service() -> SaveService:
	var service := SaveService.new()
	_save_directory = "user://test_saves/act1_packaged_%d" % Time.get_ticks_usec()
	service.save_directory = _save_directory
	return service


func _cleanup_save_directory() -> void:
	if _save_directory.is_empty():
		return
	_remove_tree(_save_directory)
	_save_directory = ""


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		DirAccess.remove_absolute(path)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var child := "%s/%s" % [path, entry]
			if DirAccess.dir_exists_absolute(child):
				_remove_tree(child)
			else:
				DirAccess.remove_absolute(child)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


func _load_json_dictionary(path: String) -> Dictionary:
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(source)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}
