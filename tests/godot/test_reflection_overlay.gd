extends "res://tests/godot/test_case.gd"

const ModelScript := preload("res://scripts/reflection/reflection_model.gd")
const OverlayScene := preload("res://scenes/ui/reflection_overlay.tscn")
const COMMISSION := &"commission.watch_buckle_repair"


func before_each() -> void:
	SessionState.state.set_flag(ModelScript.FLAG_COMPLETED, false)
	SessionState.state.set_flag(ModelScript.FLAG_DUTY, false)
	SessionState.state.set_flag(ModelScript.FLAG_FURY, false)
	SessionState.state.set_flag(ModelScript.FLAG_MERCY, false)
	SessionState.state.set_phase(GameState.PHASE_REFLECTION_MORNING)


func test_available_only_during_uncompleted_reflection_morning() -> void:
	assert_true(ModelScript.is_available(SessionState.state))
	SessionState.state.set_flag(ModelScript.FLAG_COMPLETED, true)
	assert_false(ModelScript.is_available(SessionState.state))
	SessionState.state.set_flag(ModelScript.FLAG_COMPLETED, false)
	SessionState.state.set_phase(GameState.PHASE_INVESTIGATION_MORNING)
	assert_false(ModelScript.is_available(SessionState.state))


func test_snapshot_marks_change_with_prior_forged_record() -> void:
	var honest_state := GameState.new()
	honest_state.set_phase(GameState.PHASE_REFLECTION_MORNING)
	honest_state.add_forged_record(
		ForgedRecord.new(
			&"record.honest",
			COMMISSION,
			&"item.watch_buckle",
			&"honest_work"
		)
	)
	var defect_state := GameState.new()
	defect_state.set_phase(GameState.PHASE_REFLECTION_MORNING)
	defect_state.add_forged_record(
		ForgedRecord.new(
			&"record.defect",
			COMMISSION,
			&"item.watch_buckle",
			&"subtle_defect"
		)
	)

	var honest_snapshot := ModelScript.build_snapshot(honest_state)
	var defect_snapshot := ModelScript.build_snapshot(defect_state)
	assert_ne(honest_snapshot["marks"], defect_snapshot["marks"])
	assert_true(
		String(honest_snapshot["plain_summary"]).contains("Honest hand"),
		"plain summary must name the honest-work mark"
	)
	assert_true(
		String(defect_snapshot["plain_summary"]).contains("Hidden flaw"),
		"plain summary must name the defect mark"
	)


func test_overlay_plain_summary_matches_snapshot_marks() -> void:
	var state := GameState.new()
	state.set_phase(GameState.PHASE_REFLECTION_MORNING)
	state.adjust_pressure(GameState.PRESSURE_SUSPICION, 2)
	state.add_forged_record(
		ForgedRecord.new(
			&"record.secret",
			COMMISSION,
			&"item.watch_buckle",
			&"secret_feature"
		)
	)
	var snapshot := ModelScript.build_snapshot(state)
	var overlay := OverlayScene.instantiate() as ReflectionOverlay
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	overlay.present(snapshot)

	var plain := overlay.get_plain_summary_text()
	assert_true(plain.contains("Secret catch"), "plain summary must describe visible marks")
	for mark: Dictionary in snapshot["marks"]:
		assert_true(plain.contains(String(mark.get("label", ""))))
	for label in overlay.get_mark_labels():
		assert_true(plain.contains(label), "plain summary must include every visual mark label")
	overlay.queue_free()


func test_duty_applies_one_allowlisted_relationship_effect() -> void:
	var state := GameState.new()
	state.set_phase(GameState.PHASE_REFLECTION_MORNING)
	var evaluator := StateRuleEvaluator.new()
	assert_eq(state.get_relationship(&"rel.henning_trust"), 0)
	assert_true(ModelScript.apply_conviction(state, "duty", evaluator))
	assert_eq(state.get_relationship(&"rel.henning_trust"), 1)
	assert_true(state.get_flag(ModelScript.FLAG_DUTY))
	assert_true(state.get_flag(ModelScript.FLAG_COMPLETED))


func test_mercy_applies_one_allowlisted_pressure_effect() -> void:
	var state := GameState.new()
	state.set_phase(GameState.PHASE_REFLECTION_MORNING)
	state.adjust_pressure(GameState.PRESSURE_SUSPICION, 2)
	var evaluator := StateRuleEvaluator.new()
	assert_true(ModelScript.apply_conviction(state, "mercy", evaluator))
	assert_eq(state.get_pressure(GameState.PRESSURE_SUSPICION), 1)
	assert_true(state.get_flag(ModelScript.FLAG_MERCY))
