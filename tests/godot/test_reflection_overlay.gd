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
	overlay.free()


func test_overlay_extended_reflection_sections_follow_snapshot_contract() -> void:
	var overlay := OverlayScene.instantiate() as ReflectionOverlay
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	overlay.present(
		{
			"natural_enabled": false,
			"natural_aspects": [{"display": "Nature", "rank": 5, "effective_rank": 5}],
			"natural_unspent_points": 2,
			"psyche_states": [],
			"hingepuu_loci": [],
		}
	)
	assert_false(overlay._natural_label.visible)
	assert_false(overlay._psyche_label.visible)
	assert_false(overlay._loci_label.visible)

	overlay.present(
		{
			"natural_enabled": true,
			"natural_unspent_points": 2,
			"natural_aspects": [
				{"display": "Nature", "rank": 5, "effective_rank": 7},
			],
			"psyche_states": [
				{"id": "psyche.state.ruthless", "intensity": 2, "source_beat": "beat.test"},
			],
			"hingepuu_loci": [{"id": "hingepuu.locus.nature", "kind": "aspect"}],
		}
	)
	assert_true(overlay._natural_label.visible)
	assert_true(overlay._natural_label.text.contains("2 point(s) unspent"))
	assert_true(overlay._natural_label.text.contains("Nature: 5 (effective 7)"))
	assert_true(overlay._psyche_label.visible)
	assert_true(overlay._psyche_label.text.contains("psyche.state.ruthless (intensity 2)"))
	assert_true(overlay._loci_label.visible)
	assert_true(overlay._loci_label.text.contains("Nature"))
	assert_false(
		overlay._loci_label.text.contains("hingepuu.locus."), "loci must not show raw IDs"
	)
	overlay.free()


func test_slice_snapshot_renders_visual_sections_not_prose() -> void:
	# R-1892: gauges + chips + icon cards; prose stays only as the plain summary.
	var state := GameState.new()
	state.set_phase(GameState.PHASE_REFLECTION_MORNING)
	state.adjust_pressure(GameState.PRESSURE_SUSPICION, 1)
	state.set_relationship(&"rel.henning_trust", -1)
	var snapshot := ModelScript.build_snapshot(state)
	var overlay := OverlayScene.instantiate() as ReflectionOverlay
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	overlay.present(snapshot)

	assert_eq(overlay._gauges_box.get_child_count(), 4, "suspicion, solidarity, scarcity, Henning")
	assert_false(overlay._plain_summary_label.visible, "prose must not repeat the gauges")
	assert_true(overlay._gauges_box.tooltip_text.contains("Suspicion 1"))
	assert_false(overlay._marks_box.visible, "bare tree shows no placeholder chip")
	assert_eq(overlay.get_mark_labels().size(), 0)
	assert_false(overlay._loci_label.visible, "slice reflection hides Hingepuu loci")
	assert_eq(overlay._options_box.get_child_count(), 3)
	for option: Dictionary in snapshot["options"]:
		assert_true(ResourceLoader.exists(String(option["icon"])), "conviction icon must exist")
		assert_false(String(option["effect_label"]).is_empty())
	overlay.free()


func test_soul_tree_backdrop_sits_behind_content_without_sizing_panel() -> void:
	# R-1896: painted Hingepuu behind the layout; must not grab clicks or grow the panel.
	var overlay := OverlayScene.instantiate() as ReflectionOverlay
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	overlay.present(ModelScript.build_snapshot(SessionState.state))
	var backdrop := overlay.get_backdrop()
	assert_true(backdrop != null, "backdrop texture must load")
	assert_true(backdrop.texture != null)
	assert_eq(backdrop.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(backdrop.expand_mode, TextureRect.EXPAND_IGNORE_SIZE)
	assert_eq(backdrop.get_parent().get_index(), 0, "backdrop is drawn before the layout")
	overlay.free()


func test_closed_overlay_does_not_join_modal_input_group() -> void:
	# WHY: permanent modal_input_overlay membership blocked all player locomotion.
	var overlay := OverlayScene.instantiate() as ReflectionOverlay
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	assert_false(overlay.visible)
	assert_false(
		overlay.is_in_group(&"modal_input_overlay"),
		"closed reflection overlay must not block Player movement via modal group"
	)
	overlay.present(ModelScript.build_snapshot(SessionState.state))
	assert_true(overlay.is_in_group(&"modal_input_overlay"))
	overlay.close()
	assert_false(overlay.is_in_group(&"modal_input_overlay"))
	overlay.free()


func test_player_movement_unblocked_while_reflection_closed() -> void:
	const PLAYER_SCENE := preload("res://player.tscn")
	SessionState.state.set_phase(GameState.PHASE_PROLOGUE_DAY)
	SessionState.state.set_flag(ModelScript.FLAG_COMPLETED, false)
	var player := PLAYER_SCENE.instantiate() as Player
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(player)
	assert_false(
		player.is_movement_input_blocked(),
		"ReflectionController host must not block locomotion while overlay is closed"
	)
	player.free()


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
