class_name StGeorgesNightClimax
extends Node

signal choice_committed(choice: StringName)

## Viru Gate act-boundary choice encounter for quest.st_georges_night (P4-008).

const ModelScript := preload("res://scripts/quest/st_georges_night_quest_model.gd")
const AftermathModelScript := preload(
	"res://scripts/investigation/st_georges_night_aftermath_model.gd"
)
const INTERACTABLE_ID := &"interact.st_georges_night.gate_choice"
const GATE_ANCHOR := &"checkpoint_east"
const INTERACTABLE_SCENE := preload("res://scenes/interaction/interactable.tscn")

var _scene_root: Node2D
var _definition: MapDefinition
var _gate_interactable: Interactable
var _actions_layer: CanvasLayer
var _seal_button: Button
var _break_button: Button
var _open_button: Button
var _choice_armed := false
var _choice_resolved := false

func setup(scene_root: Node2D, definition: MapDefinition) -> void:
	_scene_root = scene_root
	_definition = definition
	_ensure_content()
	_build_gate_interactable()
	_build_choice_ui()
	if not SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.connect(_on_state_replaced)
	if (
		SessionState.state != null
		and not SessionState.state.phase_changed.is_connected(_on_phase_changed)
	):
		SessionState.state.phase_changed.connect(_on_phase_changed)
	_sync_climax()


func get_gate_interactable() -> Interactable:
	return _gate_interactable


func arm_choice_for_test() -> void:
	_choice_resolved = false
	_choice_armed = false
	_arm_quest_approach()
	_sync_climax()
	_begin_choice()


func commit_choice_for_test(choice: StringName) -> bool:
	return _commit_choice(choice)


func _exit_tree() -> void:
	if (
		SessionState.state != null
		and SessionState.state.phase_changed.is_connected(_on_phase_changed)
	):
		SessionState.state.phase_changed.disconnect(_on_phase_changed)
	if SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.disconnect(_on_state_replaced)


func _on_state_replaced(_previous: GameState, current: GameState, _reason: StringName) -> void:
	if current != null and not current.phase_changed.is_connected(_on_phase_changed):
		current.phase_changed.connect(_on_phase_changed)
	_sync_climax()


func _on_phase_changed(_previous: StringName, _next: StringName) -> void:
	_sync_climax()


func _sync_climax() -> void:
	if SessionState.state == null:
		return
	_ensure_content()
	if ModelScript.is_climax_phase(SessionState.state):
		_arm_quest_approach()
	var should_offer := (
		ModelScript.is_gate_choice_active(SessionState.state) and not _choice_resolved
	)
	if _gate_interactable != null:
		_gate_interactable.enabled = should_offer and not _choice_armed
	if _choice_armed and not _choice_resolved:
		_refresh_choice_buttons()
		_set_choice_ui_visible(true)
	else:
		_set_choice_ui_visible(false)


func _arm_quest_approach() -> void:
	if SessionState.state == null:
		return
	var manager := QuestManager.new(SessionState.content_db, SessionState.state)
	var quest_state := SessionState.state.get_quest_state(ModelScript.QUEST_ID)
	if quest_state.is_empty():
		manager.start_quest(ModelScript.QUEST_ID)
	if SessionState.state.get_quest_state(ModelScript.QUEST_ID) == ModelScript.STATE_LATENT:
		manager.transition(ModelScript.QUEST_ID, ModelScript.TRANSITION_BEGIN_APPROACH)


func _begin_choice() -> void:
	if _choice_armed or _choice_resolved:
		return
	_choice_armed = true
	if _gate_interactable != null:
		_gate_interactable.enabled = false
	_refresh_choice_buttons()
	_set_choice_ui_visible(true)


func _commit_choice(choice: StringName) -> bool:
	if _choice_resolved or SessionState.state == null:
		return _choice_resolved
	var transition_id := ModelScript.transition_for_choice(choice)
	if transition_id.is_empty():
		return false
	match choice:
		&"seal":
			if not ModelScript.can_choose_seal(SessionState.state):
				return false
		&"break":
			if not ModelScript.can_choose_break(SessionState.state):
				return false
		&"open":
			if not ModelScript.can_choose_open(SessionState.state):
				return false
		_:
			return false
	var ok := AftermathModelScript.commit_climax_choice(
		SessionState.state, SessionState.content_db, transition_id
	)
	if not ok:
		return false
	_choice_resolved = true
	_choice_armed = false
	_set_choice_ui_visible(false)
	if _gate_interactable != null:
		_gate_interactable.enabled = false
	choice_committed.emit(choice)
	return true


func _build_gate_interactable() -> void:
	if _definition == null or _scene_root == null:
		return
	var position := MapVerification.anchor_position(_definition, GATE_ANCHOR)
	_gate_interactable = INTERACTABLE_SCENE.instantiate() as Interactable
	_gate_interactable.name = String(INTERACTABLE_ID)
	_gate_interactable.interactable_id = INTERACTABLE_ID
	_gate_interactable.interaction_kind = InteractionKinds.USE
	_gate_interactable.prompt = "Choose how Viru Gate resolves"
	_gate_interactable.global_position = position
	_gate_interactable.enabled = false
	_gate_interactable.set_interact_callback(Callable(self, "_on_gate_pressed"))
	_scene_root.add_child(_gate_interactable)


func _on_gate_pressed(_actor: Node) -> void:
	_begin_choice()


func _build_choice_ui() -> void:
	_actions_layer = CanvasLayer.new()
	_actions_layer.name = "StGeorgesNightChoiceActions"
	_actions_layer.layer = 44
	_scene_root.add_child(_actions_layer)

	_seal_button = _make_choice_button("SealButton", "Seal the gate", &"seal", Vector2(120, 640))
	_break_button = _make_choice_button(
		"BreakButton", "Break the gate", &"break", Vector2(260, 640)
	)
	_open_button = _make_choice_button("OpenButton", "Open the gate", &"open", Vector2(400, 640))
	for button in [_seal_button, _break_button, _open_button]:
		_actions_layer.add_child(button)
	_set_choice_ui_visible(false)


func _make_choice_button(
	node_name: String, label: String, choice: StringName, pos: Vector2
) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.position = pos
	button.custom_minimum_size = Vector2(130, 36)
	button.pressed.connect(func() -> void: _commit_choice(choice))
	return button


func _refresh_choice_buttons() -> void:
	if _seal_button != null:
		_seal_button.disabled = not ModelScript.can_choose_seal(SessionState.state)
	if _break_button != null:
		_break_button.disabled = not ModelScript.can_choose_break(SessionState.state)
	if _open_button != null:
		_open_button.disabled = not ModelScript.can_choose_open(SessionState.state)


func _set_choice_ui_visible(visible: bool) -> void:
	if _actions_layer != null:
		_actions_layer.visible = visible


func _ensure_content() -> void:
	if not SessionState.content_db.is_loaded():
		SessionState.content_db.load_from_directories(ModelScript.CONTENT_DIRS)
