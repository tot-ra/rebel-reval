extends "res://tests/godot/test_case.gd"

const FORGE_SCENE := preload("res://scenes/reval_east/forge/forge.tscn")
const LOWER_TOWN_SCENE := preload("res://scenes/reval_east/reval_east.tscn")
const PhaseRestAnchorScript := preload("res://scripts/phase/phase_rest_anchor.gd")
const EvaluatorScript := preload("res://scripts/state/state_rule_evaluator.gd")

const LOC_SMITHY := &"loc.kalev_smithy"
const OBJ_SPEAR := &"world.spearhead_anvil"
const ITEM_HAMMER := &"item.forge_hammer"


func test_bed_rest_interactable_advances_slice_phase() -> void:
	_prepare_prologue_forge_state()
	var tree := Engine.get_main_loop() as SceneTree
	var forge: Node2D = FORGE_SCENE.instantiate()
	tree.root.add_child(forge)

	var rest := _find_rest_interactable(forge)
	assert_true(rest != null, "forge bed alcove must expose a rest interactable")
	assert_true(rest.is_enabled())

	var player := forge.get_node("Actors/Player") as Player
	player.global_position = rest.global_position
	rest.register_actor_in_range(player)
	assert_true(rest.interact(player))
	assert_eq(SessionState.state.get_phase(), GameState.PHASE_INVESTIGATION_MORNING)
	assert_true(rest.is_enabled(), "mid-slice phases must keep the rest interactable available")
	forge.queue_free()


func test_debug_investigation_morning_preset_updates_forge_without_reload() -> void:
	_prepare_prologue_forge_state()
	var tree := Engine.get_main_loop() as SceneTree
	var forge: Node2D = FORGE_SCENE.instantiate()
	tree.root.add_child(forge)

	assert_true(_find_pickup_interactable(forge) != null, "prologue forge should show the anvil spearhead")
	assert_true(SessionState.apply_debug_preset("debug.phase.investigation_morning"))
	assert_eq(SessionState.state.get_phase(), GameState.PHASE_INVESTIGATION_MORNING)
	assert_false(_is_spearhead_pickup_available(forge), "phase jump must hide the anvil spearhead without reload")
	forge.queue_free()


func test_debug_investigation_morning_preset_updates_lower_town_patrol() -> void:
	_prepare_prologue_forge_state()
	var tree := Engine.get_main_loop() as SceneTree
	var town: Node2D = LOWER_TOWN_SCENE.instantiate()
	tree.root.add_child(town)

	var patrol := town.get_node_or_null("ViruWatchPatrol")
	assert_true(patrol != null)
	assert_false(patrol.is_enabled(), "prologue patrol should start disabled")

	assert_true(SessionState.apply_debug_preset("debug.phase.investigation_morning"))
	assert_true(patrol.is_enabled(), "investigation morning must enable the watch patrol without reload")
	town.queue_free()


func test_set_phase_effect_applies_authored_profile_without_reload() -> void:
	_prepare_prologue_forge_state()
	var tree := Engine.get_main_loop() as SceneTree
	var forge: Node2D = FORGE_SCENE.instantiate()
	tree.root.add_child(forge)

	var evaluator = EvaluatorScript.new()
	assert_true(
		evaluator.apply_effect(
			{
				"op": "set_phase",
				"key": "phase.investigation_morning",
				"value": "active",
			},
			SessionState.state
		)
	)
	assert_eq(SessionState.state.get_phase(), GameState.PHASE_INVESTIGATION_MORNING)
	assert_false(_is_spearhead_pickup_available(forge), "set_phase effect must refresh forge props in scene")
	forge.queue_free()


func test_phase_rest_anchor_disables_when_no_next_phase() -> void:
	var definition := MapDefinition.new()
	definition.interaction_anchors.append({
		"id": &"bed_alcove",
		"position": Vector2(40, 80),
	})
	var root := Node2D.new()
	(_tree().root as Node).add_child(root)

	var player := Player.new()
	root.add_child(player)

	var anchor = PhaseRestAnchorScript.new()
	root.add_child(anchor)
	anchor.setup(root, definition, player)

	var interactable := anchor.get_interactable()
	assert_true(interactable != null)
	assert_true(interactable.is_enabled())

	SessionState.state.set_phase(GameState.PHASE_REFLECTION_MORNING)
	assert_false(interactable.is_enabled())
	_cleanup_node(root)


func _prepare_prologue_forge_state() -> void:
	SessionState.state = GameState.new()
	SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS)
	SessionState.state.bag.set_content_db(SessionState.content_db)
	SessionState.state.bag.try_add(ITEM_HAMMER)
	SessionState.state.equip_from_bag(&"right_hand", ITEM_HAMMER)
	SessionState.state.set_phase(GameState.PHASE_PROLOGUE_DAY)
	if _tree().root.get_node_or_null("PhaseDirector") != null:
		PhaseDirector.rebind_session_state()


func _find_pickup_interactable(forge: Node) -> Interactable:
	for node in forge.find_children("*", "Area2D", true, false):
		var interactable := node as Interactable
		if interactable != null and interactable.get_interaction_kind() == InteractionKinds.PICKUP:
			return interactable
	return null


func _is_spearhead_pickup_available(forge: Node) -> bool:
	var interactable := _find_pickup_interactable(forge)
	if interactable == null:
		return false
	return interactable.is_enabled() and interactable.visible


func _find_rest_interactable(forge: Node) -> Interactable:
	for node in forge.find_children("*", "Area2D", true, false):
		var interactable := node as Interactable
		if interactable != null and interactable.get_interactable_id() == &"interact.rest.bed_alcove":
			return interactable
	return null


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _cleanup_node(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
