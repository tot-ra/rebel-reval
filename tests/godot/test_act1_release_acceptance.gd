extends "res://tests/godot/test_case.gd"

## P4-044: Act 1 release acceptance over the exact P4-013 package.
## WHY: QA must bind install/start/save/load/exit, traversal, licences,
## accessibility, and supported-input evidence to the frozen package SHA without
## editing package inputs, runtime, or the P4-012 gate report.

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

const RELEASE_MANIFEST_PATH := "res://docs/data/act1_release_manifest.json"
const PACKAGE_FINGERPRINT_PATH := "res://build/act1/package_fingerprint.json"
const PACKAGE_SHA_SIDECAR_PATH := "res://build/act1/PACKAGE_SHA256.txt"
const PACKAGE_DMG_PATH := "res://build/act1/rr.dmg"
const ACCEPTANCE_REPORT_PATH := "res://docs/reports/p4_044_act1_release_acceptance.md"
const BUDGET_MANIFEST_PATH := "res://docs/data/act1_content_budget_manifest.json"
const ACCESSIBILITY_MANIFEST_PATH := "res://docs/data/accessibility_checklist.json"
const THIRD_PARTY_MANIFEST_PATH := "res://docs/data/slice_third_party_manifest.json"
const THIRD_PARTY_NOTICES_PATH := "res://docs/THIRD_PARTY_NOTICES.md"
const CREDITS_PATH := "res://CREDITS.md"
const CLEAN_START_PATH := "res://tests/fixtures/act1_candidate/clean_start.json"

const EXPECTED_PACKAGE_SHA := "ea3cf41493394ab6bd01e17de38011b05bf3ee199fd4710a08a4eb3dc1eafbdc"
const EXPECTED_PACKAGE_BYTES := 1143742554
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


func test_release_manifest_binds_exact_p4_013_package() -> void:
	var manifest := _load_json_dictionary(RELEASE_MANIFEST_PATH)
	assert_false(manifest.is_empty(), "act1_release_manifest.json must load")
	assert_eq(String(manifest.get("task_id", "")), "P4-044")
	assert_eq(String(manifest.get("package_task_id", "")), "P4-013")
	assert_eq(String(manifest.get("release_tag", "")), "v0.2.0-act1")
	assert_eq(String(manifest.get("export_preset", "")), "act1")
	assert_eq(String(manifest.get("package_path", "")), "build/act1/rr.dmg")
	assert_eq(String(manifest.get("package_sha256", "")), EXPECTED_PACKAGE_SHA)
	assert_eq(int(manifest.get("package_bytes", -1)), EXPECTED_PACKAGE_BYTES)
	assert_eq(int(manifest.get("save_envelope_version", -1)), 1)
	assert_eq(int(manifest.get("game_state_version", -1)), 2)
	assert_eq(int(manifest.get("map_world_state_version", -1)), 2)
	assert_eq(int(manifest.get("content_schema_version", -1)), 1)

	var fingerprint := _load_json_dictionary(PACKAGE_FINGERPRINT_PATH)
	assert_false(fingerprint.is_empty(), "P4-013 package_fingerprint.json must load")
	assert_eq(String(fingerprint.get("task_id", "")), "P4-013")
	assert_eq(String(fingerprint.get("package_sha256", "")), EXPECTED_PACKAGE_SHA)
	assert_eq(int(fingerprint.get("package_bytes", -1)), EXPECTED_PACKAGE_BYTES)

	var sidecar_path := ProjectSettings.globalize_path(PACKAGE_SHA_SIDECAR_PATH)
	assert_true(FileAccess.file_exists(sidecar_path), "PACKAGE_SHA256.txt must exist")
	var sidecar := FileAccess.get_file_as_string(PACKAGE_SHA_SIDECAR_PATH).strip_edges()
	assert_true(sidecar.begins_with(EXPECTED_PACKAGE_SHA), "SHA sidecar must bind P4-013")

	var dmg_path := ProjectSettings.globalize_path(PACKAGE_DMG_PATH)
	assert_true(FileAccess.file_exists(dmg_path), "Act 1 DMG must exist for release bind")
	assert_true(
		FileAccess.file_exists(ProjectSettings.globalize_path(ACCEPTANCE_REPORT_PATH)),
		"P4-044 acceptance report must exist"
	)


func test_supported_input_actions_have_keyboard_mouse_and_gamepad_bindings() -> void:
	var bindings := BindingSettings.default_settings()
	var actions := InputCatalog.action_ids()
	assert_true(actions.size() >= 18, "release must keep the shipped slice action catalog")
	for action: StringName in actions:
		var keyboard := bindings.events_for(action, BindingSettings.DEVICE_KEYBOARD_MOUSE)
		var gamepad := bindings.events_for(action, BindingSettings.DEVICE_GAMEPAD)
		assert_false(
			keyboard.is_empty(),
			"%s needs a keyboard/mouse binding" % String(action)
		)
		assert_false(gamepad.is_empty(), "%s needs a gamepad binding" % String(action))


func test_catalog_actions_complete_via_keyboard_mouse_and_gamepad() -> void:
	for profile in [
		SliceInputDriverScript.DeviceProfile.KEYBOARD_MOUSE,
		SliceInputDriverScript.DeviceProfile.GAMEPAD,
	]:
		var driver = SliceInputDriverScript.new(profile)
		for action: StringName in InputCatalog.action_ids():
			driver.tap_action(action)
		driver.assert_no_fallback_used()
		assert_false(driver.fallback_used)
		assert_eq(driver.recorded_steps.size(), InputCatalog.action_ids().size())


func test_accessibility_and_licence_surfaces_hold() -> void:
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
	var dialogue: Variant = DialogueSettings.default_settings()
	assert_true(dialogue is Object)
	assert_false(String(dialogue.text_scale).is_empty())

	assert_true(FileAccess.file_exists(THIRD_PARTY_NOTICES_PATH))
	assert_true(FileAccess.file_exists(CREDITS_PATH))
	var third_party := _load_json_dictionary(THIRD_PARTY_MANIFEST_PATH)
	assert_false(third_party.is_empty(), "slice third-party manifest must load")
	assert_true((third_party.get("entries", []) as Array).size() > 0)
	assert_true((third_party.get("bundles", []) as Array).size() > 0)


func test_act1_traversal_boundaries_remain_reachable() -> void:
	assert_eq(TraversalModel.INTENDED_BOUNDARY_ENDINGS.size(), 3)
	for boundary in TraversalModel.INTENDED_BOUNDARY_ENDINGS:
		var branch := TraversalModel.boundary_branch_for_id(boundary)
		assert_false(branch.is_empty(), "missing intended boundary %s" % boundary)
	var budget := _load_json_dictionary(BUDGET_MANIFEST_PATH)
	assert_eq(int(budget.get("substantial_quest_budget", -1)), 8)
	assert_eq((budget.get("climax_quest_ids", []) as Array).size(), 1)


func test_macos_act1_package_menu_and_smoke_contract() -> void:
	assert_true(PlatformModel.manifest_matches_model())
	assert_eq(String(PlatformModel.SUPPORTED_PLATFORMS[0].get("id", "")), "macos_universal")
	var menu_source := FileAccess.get_file_as_string("res://scenes/menu/main_menu.tscn")
	assert_false(menu_source.is_empty(), "main menu scene must be readable")
	assert_true(menu_source.contains('path="res://scripts/demo/packaged_platform_smoke.gd"'))
	assert_true(menu_source.contains('[node name="PackagedPlatformSmoke"'))
	assert_true(menu_source.contains('[node name="Start label"'))
	assert_true(menu_source.contains('[node name="Load label"'))
	assert_true(menu_source.contains('[node name="Exit label"'))
	assert_true(PlatformSmokeScript.is_requested(PackedStringArray([PlatformSmokeScript.USER_ARGUMENT])))
	assert_false(PlatformSmokeScript.is_requested(PackedStringArray()))
	assert_true(
		FileAccess.file_exists(ProjectSettings.globalize_path(PACKAGE_DMG_PATH)),
		"release smoke expects build/act1/rr.dmg from the act1 preset"
	)


func test_act1_boundary_save_load_exit_from_clean_start() -> void:
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
	_save_directory = "user://test_saves/act1_release_%d" % Time.get_ticks_usec()
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
