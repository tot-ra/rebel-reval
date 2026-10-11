extends "res://tests/godot/test_case.gd"

const PresetsScript := preload("res://scripts/debug/debug_state_presets.gd")
const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const PresenterScript := preload("res://scripts/dialogue/dialogue_presenter.gd")

const FOLLOWUP_ID := &"dialogue.test_runner.followup"
const FLAG_TRUSTED := &"flag.test_runner_trusted"
const FLAG_INCIDENT := &"flag.prologue_maker_mark_incident"
const FLAG_PRESERVED := &"flag.forge_ledger_preserved"
const FLAG_ALTERED := &"flag.forge_ledger_altered"
const FLAG_MART_MISSING := &"flag.mart_missing"
const QUEST_MAKERS_MARK := &"quest.makers_mark"


func test_manifest_loads_every_declared_preset() -> void:
	var presets = PresetsScript.new()
	assert_true(presets.load_manifest())
	assert_true(presets.get_preset_ids().size() >= 12)


func test_every_slice_phase_preset_sets_target_phase() -> void:
	var presets = PresetsScript.new()
	assert_true(presets.load_manifest())

	for phase in GameState.SLICE_PHASES:
		var preset_id := "debug.phase.%s" % String(phase).trim_prefix("phase.")
		var result: Dictionary = presets.apply_preset(preset_id)
		assert_true(result["ok"], "phase preset %s failed: %s" % [preset_id, result.get("error", "")])
		var state: GameState = result["state"]
		assert_eq(state.get_phase(), phase, "preset %s must set %s" % [preset_id, phase])


func test_reset_presets_match_released_fixtures() -> void:
	var presets = PresetsScript.new()
	assert_true(presets.load_manifest())

	var fresh := presets.apply_preset("debug.reset.demo_fresh")
	assert_true(fresh["ok"])
	var fresh_state: GameState = fresh["state"]
	assert_true(fresh_state.is_world_item_placed(&"loc.kalev_smithy", &"world.spearhead_anvil"))
	assert_false(fresh_state.has_item(&"item.seized_spearhead"))

	var pickup := presets.apply_preset("debug.reset.demo_post_pickup")
	assert_true(pickup["ok"])
	var pickup_state: GameState = pickup["state"]
	assert_true(pickup_state.get_flag(&"flag.demo_mart_spoken"))
	assert_true(pickup_state.has_item(&"item.seized_spearhead"))
	assert_false(pickup_state.is_world_item_placed(&"loc.kalev_smithy", &"world.spearhead_anvil"))


func test_makers_mark_branch_presets_set_expected_flags() -> void:
	var presets = PresetsScript.new()
	assert_true(presets.load_manifest())

	var incident := presets.apply_preset("debug.branch.makers_mark_incident")["state"] as GameState
	assert_eq(incident.get_quest_state(QUEST_MAKERS_MARK), &"incident_known")
	assert_true(incident.get_flag(FLAG_INCIDENT))
	assert_false(incident.get_flag(FLAG_PRESERVED))
	assert_false(incident.get_flag(FLAG_ALTERED))

	var preserved := presets.apply_preset("debug.branch.makers_mark_preserved")["state"] as GameState
	assert_eq(preserved.get_quest_state(QUEST_MAKERS_MARK), &"ledger_committed")
	assert_true(preserved.get_flag(FLAG_PRESERVED))
	assert_false(preserved.get_flag(FLAG_ALTERED))

	var altered := presets.apply_preset("debug.branch.makers_mark_altered")["state"] as GameState
	assert_true(altered.get_flag(FLAG_ALTERED))
	assert_false(altered.get_flag(FLAG_PRESERVED))

	var destroyed := presets.apply_preset("debug.branch.makers_mark_destroyed")["state"] as GameState
	assert_true(destroyed.get_flag(FLAG_MART_MISSING))
	assert_eq(destroyed.get_pressure(GameState.PRESSURE_SUSPICION), 1)


func test_dialogue_branch_presets_unlock_followup_without_replay() -> void:
	var presets = PresetsScript.new()
	var db := ContentDB.new()
	assert_true(db.load_from_directories([
		"res://content/examples/valid",
		"res://content/examples/support",
	]))

	var trusted := presets.apply_preset("debug.branch.dialogue_trusted")["state"] as GameState
	var runner = RunnerScript.new()
	runner.configure(db, trusted, PresenterScript.new())
	assert_true(runner.start(FOLLOWUP_ID))

	var doubted := presets.apply_preset("debug.branch.dialogue_doubted")["state"] as GameState
	runner = RunnerScript.new()
	runner.configure(db, doubted, PresenterScript.new())
	assert_false(runner.start(FOLLOWUP_ID))


func test_session_state_apply_debug_preset_replaces_live_state() -> void:
	var root := _make_root()
	var session_script := load("res://scripts/session/session_state.gd") as Script
	var session: Node = session_script.new()
	root.add_child(session)

	var original_phase: StringName = session.state.get_phase()
	session.state.set_flag(&"flag.debug_probe", true)

	assert_true(session.apply_debug_preset("debug.phase.investigation_night"))
	assert_eq(session.state.get_phase(), GameState.PHASE_INVESTIGATION_NIGHT)
	assert_false(session.state.get_flag(&"flag.debug_probe"))

	session.apply_debug_preset("debug.reset.demo_fresh")
	assert_eq(session.state.get_phase(), original_phase)
	_cleanup_node(root)


func _make_root() -> Node:
	var root := Node.new()
	(_tree().root as Node).add_child(root)
	return root


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _cleanup_node(node: Node) -> void:
	if is_instance_valid(node):
		node.free()
