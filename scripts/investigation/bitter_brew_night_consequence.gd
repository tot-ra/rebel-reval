class_name BitterBrewNightConsequence
extends Node

## P2-009: watch checkpoint night consequence on Lower Town during
## phase.investigation_night. Forged commission records gate non-combat routes;
## combat and surrender stay available for every outcome family.

const QUEST_ID := &"quest.bitter_brew"
const COMMISSION_ID := &"commission.bitter_brew"
const ENCOUNTER_ID := &"encounter.watch_checkpoint"
const INTERACTABLE_ID := &"interact.bitter_brew.checkpoint_encounter"
const CHECKPOINT_ANCHOR := &"checkpoint_west"
const SERGEANT_ANCHOR := &"checkpoint_east"

const RECORD_HONEST := &"forged.bitter_brew.honest_work"
const RECORD_SUBTLE := &"forged.bitter_brew.subtle_defect"
const RECORD_SECRET := &"forged.bitter_brew.secret_feature"

const STATE_ACTIVE := &"active"
const STATE_INVESTIGATION_READY := &"investigation_ready"

const ENEMY_SCRIPT := preload("res://scripts/combat/combat_room_enemy.gd")
const INTERACTABLE_SCENE := preload("res://scenes/interaction/interactable.tscn")

const TERMINAL_QUEST_STATES: Array[StringName] = [
	&"night_surrendered",
	&"night_escaped",
	&"night_bypassed",
	&"night_fought",
]

var _scene_root: Node2D
var _definition: MapDefinition
var _player: Player
var _actors: Node2D
var _interaction_controller: InteractionController

var watchman: CombatRoomEnemy
var sergeant: CombatRoomEnemy
var encounter_definition: EncounterOutcomeDefinition = EncounterOutcomeDefinition.new()
var encounter_resolver := EncounterOutcomeResolver.new()
var encounter_checkpoint := EncounterCheckpoint.new()

var _checkpoint_interactable: Interactable
var _actions_layer: CanvasLayer
var _surrender_button: Button
var _escape_button: Button
var _bypass_button: Button
var _retry_button: Button
var _encounter_armed := false
var _encounter_resolved := false
var _player_died_connected := false


func setup(
	scene_root: Node2D,
	definition: MapDefinition,
	player: Player,
	interaction_controller: InteractionController,
	actors: Node2D
) -> void:
	_scene_root = scene_root
	_definition = definition
	_player = player
	_interaction_controller = interaction_controller
	_actors = actors
	_ensure_content()
	_build_checkpoint_interactable()
	_build_outcome_ui()
	if not SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.connect(_on_state_replaced)
	if SessionState.state != null \
			and not SessionState.state.phase_changed.is_connected(_on_phase_changed):
		SessionState.state.phase_changed.connect(_on_phase_changed)
	_sync_encounter()


func get_checkpoint_interactable() -> Interactable:
	return _checkpoint_interactable


func is_outcome_available(kind: StringName) -> bool:
	if not _encounter_armed or _encounter_resolved:
		return false
	if kind == EncounterOutcome.KIND_SURRENDER or kind == EncounterOutcome.KIND_KILL:
		return true
	return _forged_allows_non_lethal(kind)


func resolve_encounter_outcome(kind: StringName) -> bool:
	if not is_outcome_available(kind) and kind != EncounterOutcome.KIND_KILL:
		return false
	if kind == EncounterOutcome.KIND_KILL and not _both_enemies_dead():
		return false
	var enemies: Array = []
	if watchman != null:
		enemies.append(watchman)
	if sergeant != null:
		enemies.append(sergeant)
	var ok := encounter_resolver.resolve(
		SessionState.state, encounter_definition, kind, enemies
	)
	if ok:
		_on_encounter_resolved()
	return ok


func arm_encounter_for_test() -> void:
	_encounter_resolved = false
	_encounter_armed = false
	_sync_encounter()
	_begin_encounter()


func advance_enemies_for_test(delta: float) -> void:
	_tick_enemies(delta)


func _exit_tree() -> void:
	if SessionState.state != null \
			and SessionState.state.phase_changed.is_connected(_on_phase_changed):
		SessionState.state.phase_changed.disconnect(_on_phase_changed)
	if SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.disconnect(_on_state_replaced)
	_disconnect_player_death()


func _process(delta: float) -> void:
	if not _encounter_armed or _encounter_resolved:
		return
	_tick_enemies(delta)
	if _both_enemies_dead():
		resolve_encounter_outcome(EncounterOutcome.KIND_KILL)


func _on_state_replaced(_previous: GameState, current: GameState, _reason: StringName) -> void:
	if current != null and not current.phase_changed.is_connected(_on_phase_changed):
		current.phase_changed.connect(_on_phase_changed)
	_sync_encounter()


func _on_phase_changed(_previous: StringName, _next: StringName) -> void:
	_sync_encounter()


func _sync_encounter() -> void:
	if SessionState.state == null:
		return
	_ensure_content()
	var should_offer := _should_offer_encounter()
	if _checkpoint_interactable != null:
		_checkpoint_interactable.enabled = should_offer and not _encounter_armed and not _encounter_resolved
	if should_offer and _encounter_resolved:
		_encounter_resolved = _is_quest_terminal()
	if should_offer and not _encounter_armed and not _encounter_resolved:
		_teardown_combat_actors()
		_set_outcome_ui_visible(false)
	elif _encounter_armed and not _encounter_resolved:
		_refresh_outcome_buttons()
		_set_outcome_ui_visible(true)
	else:
		_teardown_encounter()


func _should_offer_encounter() -> bool:
	if SessionState.state == null:
		return false
	if SessionState.state.get_phase() != GameState.PHASE_INVESTIGATION_NIGHT:
		return false
	if not ForgeCommissionModel.is_commission_resolved(SessionState.state, COMMISSION_ID):
		return false
	return not _is_quest_terminal()


func _is_quest_terminal() -> bool:
	var quest_state := SessionState.state.get_quest_state(QUEST_ID)
	return quest_state in TERMINAL_QUEST_STATES


func _begin_encounter() -> void:
	if _encounter_armed or _encounter_resolved:
		return
	_spawn_combat_actors()
	SessionState.state.set_quest_state(QUEST_ID, STATE_ACTIVE)
	encounter_checkpoint.arm(SessionState.state, encounter_definition.encounter_id)
	_encounter_armed = true
	_connect_player_death()
	if _checkpoint_interactable != null:
		_checkpoint_interactable.enabled = false
	_refresh_outcome_buttons()
	_set_outcome_ui_visible(true)


func _on_encounter_resolved() -> void:
	_encounter_resolved = true
	_encounter_armed = false
	encounter_checkpoint.clear()
	_set_retry_visible(false)
	_set_outcome_ui_visible(false)
	_teardown_combat_actors()
	_disconnect_player_death()


func _teardown_encounter() -> void:
	_encounter_armed = false
	_encounter_resolved = _is_quest_terminal()
	encounter_checkpoint.clear()
	_set_retry_visible(false)
	_set_outcome_ui_visible(false)
	_teardown_combat_actors()
	_disconnect_player_death()


func _spawn_combat_actors() -> void:
	if _actors == null or _definition == null:
		return
	_teardown_combat_actors()
	var watch_pos := MapVerification.anchor_position(_definition, CHECKPOINT_ANCHOR)
	var sarge_pos := MapVerification.anchor_position(_definition, SERGEANT_ANCHOR)
	watchman = _make_enemy(
		"BitterBrewWatchman", watch_pos, EnemyArchetype.watchman(), Color(0.62, 0.58, 0.34, 1.0)
	)
	sergeant = _make_enemy(
		"BitterBrewSergeant", sarge_pos, EnemyArchetype.sergeant(), Color(0.55, 0.28, 0.42, 1.0)
	)


func _make_enemy(
	node_name: String, pos: Vector2, profile: EnemyArchetype, tint: Color
) -> CombatRoomEnemy:
	var enemy: CombatRoomEnemy = ENEMY_SCRIPT.new()
	enemy.name = node_name
	enemy.position = pos
	enemy.configure(profile, tint)
	enemy.set_ai_target(_player)
	_actors.add_child(enemy)
	return enemy


func _teardown_combat_actors() -> void:
	for enemy in [watchman, sergeant]:
		if enemy != null and is_instance_valid(enemy):
			enemy.queue_free()
	watchman = null
	sergeant = null


func _tick_enemies(delta: float) -> void:
	if _player == null:
		return
	for enemy in [watchman, sergeant]:
		if enemy != null and is_instance_valid(enemy):
			enemy.tick_ai(delta, _player)


func _both_enemies_dead() -> bool:
	for enemy in [watchman, sergeant]:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not enemy.get_machine().is_dead():
			return false
	return watchman != null or sergeant != null


func _forged_allows_non_lethal(kind: StringName) -> bool:
	if SessionState.state == null:
		return false
	if kind == EncounterOutcome.KIND_BYPASS:
		return SessionState.state.has_forged_record(RECORD_SUBTLE)
	if kind == EncounterOutcome.KIND_ESCAPE:
		return SessionState.state.has_forged_record(RECORD_SECRET)
	return false


func _build_checkpoint_interactable() -> void:
	if _definition == null or _scene_root == null:
		return
	var position := MapVerification.anchor_position(_definition, CHECKPOINT_ANCHOR)
	_checkpoint_interactable = INTERACTABLE_SCENE.instantiate() as Interactable
	_checkpoint_interactable.name = String(INTERACTABLE_ID)
	_checkpoint_interactable.interactable_id = INTERACTABLE_ID
	_checkpoint_interactable.interaction_kind = InteractionKinds.USE
	_checkpoint_interactable.prompt = "Face the watch at the checkpoint"
	_checkpoint_interactable.global_position = position
	_checkpoint_interactable.enabled = false
	_checkpoint_interactable.set_interact_callback(Callable(self, "_on_checkpoint_pressed"))
	_scene_root.add_child(_checkpoint_interactable)


func _on_checkpoint_pressed(_actor: Node) -> void:
	_begin_encounter()


func _build_outcome_ui() -> void:
	_actions_layer = CanvasLayer.new()
	_actions_layer.name = "BitterBrewNightOutcomeActions"
	_actions_layer.layer = 42
	_scene_root.add_child(_actions_layer)

	_surrender_button = _make_outcome_button(
		"SurrenderButton", "Surrender", EncounterOutcome.KIND_SURRENDER, Vector2(170, 640)
	)
	_escape_button = _make_outcome_button(
		"EscapeButton", "Escape", EncounterOutcome.KIND_ESCAPE, Vector2(300, 640)
	)
	_bypass_button = _make_outcome_button(
		"BypassButton", "Bypass", EncounterOutcome.KIND_BYPASS, Vector2(430, 640)
	)
	_retry_button = Button.new()
	_retry_button.name = "RetryCheckpointButton"
	_retry_button.text = "Retry"
	_retry_button.tooltip_text = "Restore the armed checkpoint after failure"
	_retry_button.position = Vector2(560, 640)
	_retry_button.custom_minimum_size = Vector2(120, 36)
	_retry_button.visible = false
	_retry_button.pressed.connect(_on_retry_pressed)

	for button in [_surrender_button, _escape_button, _bypass_button, _retry_button]:
		_actions_layer.add_child(button)
	_set_outcome_ui_visible(false)


func _make_outcome_button(
	node_name: String, label: String, kind: StringName, pos: Vector2
) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.tooltip_text = (
		"Resolve the watch checkpoint via %s"
		% EncounterOutcome.display_name(kind)
	)
	button.position = pos
	button.custom_minimum_size = Vector2(120, 36)
	button.pressed.connect(func() -> void: resolve_encounter_outcome(kind))
	return button


func _refresh_outcome_buttons() -> void:
	if _surrender_button != null:
		_surrender_button.disabled = not is_outcome_available(EncounterOutcome.KIND_SURRENDER)
	if _escape_button != null:
		_escape_button.disabled = not is_outcome_available(EncounterOutcome.KIND_ESCAPE)
	if _bypass_button != null:
		_bypass_button.disabled = not is_outcome_available(EncounterOutcome.KIND_BYPASS)


func _set_outcome_ui_visible(visible: bool) -> void:
	if _actions_layer != null:
		_actions_layer.visible = visible


func _set_retry_visible(visible: bool) -> void:
	if _retry_button != null:
		_retry_button.visible = visible
		_retry_button.disabled = not visible


func _on_retry_pressed() -> void:
	if not encounter_checkpoint.is_armed:
		return
	if not encounter_checkpoint.restore(SessionState.state):
		return
	_encounter_resolved = false
	_spawn_combat_actors()
	_encounter_armed = true
	encounter_checkpoint.arm(SessionState.state, encounter_definition.encounter_id)
	_set_retry_visible(false)
	_refresh_outcome_buttons()
	_set_outcome_ui_visible(true)


func _connect_player_death() -> void:
	if _player == null or _player_died_connected:
		return
	if not _player.died.is_connected(_on_player_died):
		_player.died.connect(_on_player_died)
	_player_died_connected = true


func _disconnect_player_death() -> void:
	if _player == null or not _player_died_connected:
		return
	if _player.died.is_connected(_on_player_died):
		_player.died.disconnect(_on_player_died)
	_player_died_connected = false


func _on_player_died() -> void:
	if encounter_checkpoint.mark_failed():
		_set_retry_visible(true)


func _ensure_content() -> void:
	if not SessionState.content_db.is_loaded():
		SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS)
	encounter_definition = EncounterOutcomeDefinition.from_content_db(
		SessionState.content_db, ENCOUNTER_ID
	)
