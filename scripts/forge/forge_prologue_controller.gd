class_name ForgePrologueController
extends Node

## Orchestrates the Maker's Mark prologue: commission repair, Henning confrontation,
## missing-apprentice discovery, ledger branch, and bed rest gating until committed.

const QUEST_ID := &"quest.makers_mark"
const COMMISSION_ID := &"commission.watch_buckle_repair"
const DIALOGUE_HENNING := &"dialogue.makers_mark.henning_arrival"
const DIALOGUE_CHEST := &"dialogue.makers_mark.chest_discovery"
const DIALOGUE_LEDGER := &"dialogue.makers_mark.ledger_choice"
const DIALOGUE_WAKE_UP := &"dialogue.makers_mark.wake_up"
const BARK_WAKE_UP_ROOM := &"bark.prologue.wake_up_room"
const FLAG_WAKE_UP_MONOLOGUE_SEEN := &"flag.wake_up_monologue_seen"
const LOCATION_SMITHY := &"loc.kalev_smithy"
const CHEST_PROP_ID := &"chest"

const TRANSITION_DISCOVER := &"discover_incident"
const TRANSITION_PRESERVE := &"preserve_ledger"
const TRANSITION_ALTER := &"alter_ledger"
const TRANSITION_DESTROY := &"destroy_ledger"

const STATE_NOT_STARTED := &"not_started"
const STATE_INCIDENT_KNOWN := &"incident_known"
const STATE_LEDGER_COMMITTED := &"ledger_committed"

const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const UiPresenterScript := preload("res://scripts/dialogue/dialogue_ui_presenter.gd")
const UiScript := preload("res://scripts/dialogue/dialogue_ui.gd")
const BarkPresenterScript := preload("res://scripts/dialogue/dialogue_bark_presenter.gd")
const PhaseProfileModelScript := preload("res://scripts/phase/phase_profile_model.gd")
const InteractableScene := preload("res://scenes/interaction/interactable.tscn")

const HINTS: Array[String] = [
	"Move with WASD or arrow keys.",
	"Press E at the ledger to review Henning's buckle commission.",
	"Listen to Henning, then search the storage chest.",
	"Choose how Kalev handles the forge ledger.",
	"Rest at the bed to end the day shift.",
]

var _scene_root: Node2D
var _definition: MapDefinition
var _player: Player
var _commission_controller: ForgeCommissionController
var _rest_anchor: PhaseRestAnchor
var _dialogue_encounter: ForgeDialogueEncounter
var _henning: SmithyHenning
var _interaction_controller: InteractionController

var _quest_manager: QuestManager
var _runner: DialogueRunner
var _presenter: RefCounted
var _dialogue_ui: DialogueUI
var _bark_presenter: DialogueBarkPresenter
var _chest_interactable: Interactable
var _ledger_choice_interactable: Interactable
var _hint_label: Label
var _pending_quest_transition := &""
var _henning_arrival_started := false
var _wake_up_played := false


func setup(
	scene_root: Node2D,
	definition: MapDefinition,
	player: Player,
	_commission_anchor: ForgeCommissionAnchor,
	rest_anchor: PhaseRestAnchor,
	dialogue_encounter: ForgeDialogueEncounter,
	henning: SmithyHenning,
	interaction_controller: InteractionController
) -> void:
	# Parameters must keep distinct names from members; a gdlint unused-arg rename
	# that shadows fields and drops these assignments leaves _scene_root null and
	# crashes add_child in _build_dialogue_stack.
	_scene_root = scene_root
	_definition = definition
	_player = player
	_commission_controller = (
		player.get_node_or_null("ForgeCommissionController") as ForgeCommissionController
	)
	_rest_anchor = rest_anchor
	_dialogue_encounter = dialogue_encounter
	_henning = henning
	_interaction_controller = interaction_controller

	_quest_manager = QuestManager.new(SessionState.content_db, SessionState.state)
	_build_dialogue_stack()
	_build_bark_presenter()
	_build_hint_label()
	_spawn_chest_interactable()
	_spawn_ledger_choice_interactable()

	if not SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.connect(_on_state_replaced)
	if (
		_commission_controller != null
		and not _commission_controller.commission_finished.is_connected(_on_commission_finished)
	):
		_commission_controller.commission_finished.connect(_on_commission_finished)

	_bootstrap_quest()
	_sync_stage()
	# Trigger the opening wake-up monologue on first launch.
	_try_start_wake_up_monologue()


func get_dialogue_runner() -> DialogueRunner:
	return _runner


func get_dialogue_ui() -> DialogueUI:
	return _dialogue_ui


func get_chest_interactable() -> Interactable:
	return _chest_interactable


func get_ledger_choice_interactable() -> Interactable:
	return _ledger_choice_interactable


func _exit_tree() -> void:
	if SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.disconnect(_on_state_replaced)
	if (
		_commission_controller != null
		and _commission_controller.commission_finished.is_connected(_on_commission_finished)
	):
		_commission_controller.commission_finished.disconnect(_on_commission_finished)


func _on_state_replaced(_previous: GameState, current: GameState, _reason: StringName) -> void:
	_quest_manager = QuestManager.new(SessionState.content_db, current)
	_runner.configure(SessionState.content_db, current, _presenter)
	_henning_arrival_started = false
	_pending_quest_transition = &""
	_bootstrap_quest()
	_sync_stage()


func _on_commission_finished(commission_id: StringName) -> void:
	if commission_id != COMMISSION_ID or not _is_prologue_active():
		return
	_try_start_henning_arrival()


func _on_dialogue_finished(dialogue_id: StringName) -> void:
	_set_interaction_enabled(true)
	if _dialogue_ui.choice_selected.is_connected(_on_ledger_choice_picked):
		_dialogue_ui.choice_selected.disconnect(_on_ledger_choice_picked)
	if _henning != null:
		_henning.set_conversation_partner(null)
		if dialogue_id == DIALOGUE_HENNING:
			_henning.resume_after_dialogue()
	if dialogue_id == DIALOGUE_WAKE_UP:
		_play_wake_up_bark()
	if not _is_prologue_active():
		return
	match dialogue_id:
		DIALOGUE_HENNING:
			_quest_manager.transition(QUEST_ID, TRANSITION_DISCOVER)
		DIALOGUE_LEDGER:
			if not _pending_quest_transition.is_empty():
				_quest_manager.transition(QUEST_ID, _pending_quest_transition)
				_pending_quest_transition = &""
	_sync_stage()


func _bootstrap_quest() -> void:
	if not _is_prologue_active():
		return
	if SessionState.state.get_quest_state(QUEST_ID).is_empty():
		_quest_manager.start_quest(QUEST_ID)


func _is_prologue_active() -> bool:
	return (
		has_node("/root/SessionState")
		and SessionState.state != null
		and SessionState.state.get_phase() == GameState.PHASE_PROLOGUE_DAY
	)


func _commission_resolved() -> bool:
	return ForgeCommissionModel.is_commission_resolved(SessionState.state, COMMISSION_ID)


func _quest_state() -> StringName:
	return SessionState.state.get_quest_state(QUEST_ID)


func _try_start_wake_up_monologue() -> void:
	# Persist a successful opening trigger so leaving and re-entering the smithy
	# cannot recreate the controller and replay the new-game sequence.
	if (
		_wake_up_played
		or _runner.is_active()
		or SessionState.state.get_flag(FLAG_WAKE_UP_MONOLOGUE_SEEN)
	):
		return
	_wake_up_played = true
	_runner.configure(SessionState.content_db, SessionState.state, _presenter)
	if not _runner.start(DIALOGUE_WAKE_UP):
		push_warning("Forge prologue failed to start wake-up monologue")
		return
	SessionState.state.set_flag(FLAG_WAKE_UP_MONOLOGUE_SEEN, true)
	_set_interaction_enabled(false)


func _build_bark_presenter() -> void:
	_bark_presenter = BarkPresenterScript.new()
	_bark_presenter.name = "ForgePrologueBarkPresenter"
	_scene_root.add_child(_bark_presenter)


func _try_start_henning_arrival() -> void:
	if (
		_henning_arrival_started
		or _runner.is_active()
		or not _commission_resolved()
		or _quest_state() != STATE_NOT_STARTED
	):
		return
	_henning_arrival_started = true
	if _henning != null:
		_henning.begin_prologue_visit()
	_start_branching_dialogue(DIALOGUE_HENNING)


func _play_wake_up_bark() -> void:
	# The room's aside is deliberately independent from the blocking monologue:
	# it reads as an NPC comment, not as another turn in Kalev's conversation.
	if _bark_presenter == null or _henning == null or not _henning.visible:
		return
	_runner.play_bark(
		BARK_WAKE_UP_ROOM,
		_bark_presenter,
		_henning,
		_scene_root.get_node_or_null("MapViewRuntime"),
		GameState.PHASE_PROLOGUE_DAY,
		LOCATION_SMITHY
	)


func _start_branching_dialogue(dialogue_id: StringName) -> void:
	if _runner.is_active():
		return
	_runner.configure(SessionState.content_db, SessionState.state, _presenter)
	if (
		dialogue_id == DIALOGUE_LEDGER
		and not _dialogue_ui.choice_selected.is_connected(_on_ledger_choice_picked)
	):
		_dialogue_ui.choice_selected.connect(_on_ledger_choice_picked)
	if _henning != null and _player != null and dialogue_id == DIALOGUE_HENNING:
		_henning.set_conversation_partner(_player)
	if not _runner.start(dialogue_id):
		push_warning("Forge prologue failed to start dialogue %s" % dialogue_id)
		return
	_set_interaction_enabled(false)


func _on_ledger_choice_picked(choice_id: String) -> void:
	_pending_quest_transition = _transition_for_choice(choice_id)


func _build_dialogue_stack() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ForgePrologueDialogueLayer"
	layer.layer = 30
	_scene_root.add_child(layer)

	_dialogue_ui = UiScript.new()
	_dialogue_ui.name = "ForgePrologueDialogueUI"
	layer.add_child(_dialogue_ui)
	_dialogue_ui.apply_settings(UserSettings.dialogue)

	_runner = RunnerScript.new()
	_runner.name = "ForgePrologueDialogueRunner"
	layer.add_child(_runner)

	_presenter = UiPresenterScript.new()
	_presenter.configure(_dialogue_ui, _runner)
	_runner.configure(SessionState.content_db, SessionState.state, _presenter)
	_runner.finished.connect(_on_dialogue_finished)


func _build_hint_label() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ForgePrologueHintLayer"
	layer.layer = 20
	_scene_root.add_child(layer)

	_hint_label = Label.new()
	_hint_label.name = "TutorialHint"
	_hint_label.position = Vector2(24, 72)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(520, 0)
	_hint_label.add_theme_color_override("font_color", Color(0.92, 0.9, 0.82, 1.0))
	_hint_label.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.08, 1.0))
	_hint_label.add_theme_constant_override("outline_size", 4)
	layer.add_child(_hint_label)


func _spawn_chest_interactable() -> void:
	_chest_interactable = _spawn_use_interactable(
		"ChestDiscovery",
		&"interact.prologue.storage_chest",
		_prop_center(CHEST_PROP_ID),
		"Search the storage chest [E]",
		_on_chest_interact
	)


func _spawn_ledger_choice_interactable() -> void:
	_ledger_choice_interactable = _spawn_use_interactable(
		"LedgerChoice",
		&"interact.prologue.ledger_choice",
		MapVerification.anchor_position(_definition, &"ledger"),
		"Review the forge ledger [E]",
		_on_ledger_choice_interact
	)


func _spawn_use_interactable(
	node_name: String,
	interactable_id: StringName,
	position: Vector2,
	prompt: String,
	callback: Callable
) -> Interactable:
	var interactable: Interactable = InteractableScene.instantiate()
	interactable.name = node_name
	interactable.interactable_id = interactable_id
	interactable.interaction_kind = InteractionKinds.USE
	interactable.prompt = prompt
	interactable.global_position = position
	interactable.enabled = false
	interactable.set_interact_callback(callback)
	_scene_root.add_child(interactable)
	return interactable


func _on_chest_interact(_actor: Node) -> void:
	if _runner.is_active() or _quest_state() != STATE_INCIDENT_KNOWN:
		return
	_start_branching_dialogue(DIALOGUE_CHEST)


func _on_ledger_choice_interact(_actor: Node) -> void:
	if (
		_runner.is_active()
		or _quest_state() != STATE_INCIDENT_KNOWN
		or not SessionState.state.get_flag(&"flag.mart_missing")
	):
		return
	_pending_quest_transition = &""
	_start_branching_dialogue(DIALOGUE_LEDGER)


func _process(_delta: float) -> void:
	if _is_prologue_active():
		_sync_stage()


func _sync_stage() -> void:
	if not _is_prologue_active():
		_set_hint("")
		_set_interactable_enabled(_chest_interactable, false)
		_set_interactable_enabled(_ledger_choice_interactable, false)
		_restore_demo_henning_talk(true)
		return

	var quest_state := _quest_state()
	_restore_demo_henning_talk(quest_state == STATE_LEDGER_COMMITTED)

	if quest_state == STATE_LEDGER_COMMITTED:
		_set_hint(HINTS[4])
		_set_interactable_enabled(_chest_interactable, false)
		_set_interactable_enabled(_ledger_choice_interactable, false)
		_sync_rest_enabled(true)
		return

	_sync_rest_enabled(false)

	if quest_state == STATE_INCIDENT_KNOWN:
		var mart_missing := SessionState.state.get_flag(&"flag.mart_missing")
		_set_interactable_enabled(_chest_interactable, not mart_missing)
		_set_interactable_enabled(_ledger_choice_interactable, mart_missing)
		_set_hint(HINTS[3] if mart_missing else HINTS[2])
		return

	if _commission_resolved():
		_set_hint(HINTS[2])
		_try_start_henning_arrival()
	else:
		_set_hint(HINTS[1] if _player_moved() else HINTS[0])

	_set_interactable_enabled(_chest_interactable, false)
	_set_interactable_enabled(_ledger_choice_interactable, false)


func _sync_rest_enabled(allow_rest: bool) -> void:
	if _rest_anchor == null:
		return
	var interactable := _rest_anchor.get_interactable()
	if interactable == null:
		return
	var has_next_phase := not (
		PhaseProfileModelScript
		. next_phase_id(SessionState.state.get_phase(), SessionState.content_db)
		. is_empty()
	)
	interactable.enabled = allow_rest and has_next_phase


func _restore_demo_henning_talk(enabled: bool) -> void:
	if _dialogue_encounter == null:
		return
	var henning_talk := _dialogue_encounter.get_henning_interactable()
	if henning_talk != null:
		henning_talk.enabled = enabled


func _set_interactable_enabled(interactable: Interactable, enabled: bool) -> void:
	if interactable != null and interactable.enabled != enabled:
		interactable.enabled = enabled


func _set_hint(text: String) -> void:
	if _hint_label != null:
		_hint_label.text = text
		_hint_label.visible = not text.is_empty()


func _set_interaction_enabled(enabled: bool) -> void:
	if _interaction_controller == null:
		return
	_interaction_controller.set_process(enabled)
	_interaction_controller.set_process_unhandled_input(enabled)
	if _interaction_controller.prompt_label != null:
		_interaction_controller.prompt_label.visible = (
			enabled and _interaction_controller.get_focused_interactable() != null
		)


func _player_moved() -> bool:
	if _player == null:
		return false
	return _player.global_position.distance_to(_definition.player_spawn) > 24.0


func _prop_center(prop_id: StringName) -> Vector2:
	for prop in _definition.props:
		if prop.get("id", &"") == prop_id:
			var rect: Rect2 = prop.get("rect", Rect2())
			return rect.get_center()
	return Vector2.ZERO


func _transition_for_choice(choice_id: String) -> StringName:
	match choice_id:
		"preserve_ledger":
			return TRANSITION_PRESERVE
		"alter_ledger":
			return TRANSITION_ALTER
		"destroy_ledger":
			return TRANSITION_DESTROY
	return &""
