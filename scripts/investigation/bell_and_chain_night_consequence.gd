class_name BellAndChainNightConsequence
extends Node

## Curfew Viru Gate install encounter for quest.bell_and_chain (P4-002).

const ModelScript := preload("res://scripts/quest/bell_and_chain_quest_model.gd")
const AftermathModelScript := preload(
	"res://scripts/investigation/bell_and_chain_aftermath_model.gd"
)
const ENCOUNTER_ID := &"encounter.watch_checkpoint"
const INTERACTABLE_ID := &"interact.bell_and_chain.gate_install"
const CHECKPOINT_ANCHOR := &"checkpoint_east"
const SERGEANT_ANCHOR := &"mart_street"
const RECORD_HONEST := &"forged.bell_and_chain.honest_work"
const RECORD_SUBTLE := &"forged.bell_and_chain.subtle_defect"
const RECORD_SECRET := &"forged.bell_and_chain.secret_feature"
const ENEMY_SCRIPT := preload("res://scripts/combat/combat_room_enemy.gd")
const INTERACTABLE_SCENE := preload("res://scenes/interaction/interactable.tscn")

var watchman: CombatRoomEnemy
var sergeant: CombatRoomEnemy
var encounter_definition: EncounterOutcomeDefinition = EncounterOutcomeDefinition.new()
var encounter_resolver := EncounterOutcomeResolver.new()
var encounter_checkpoint := EncounterCheckpoint.new()

var _scene_root: Node2D
var _definition: MapDefinition
var _player: Player
var _actors: Node2D
var _checkpoint_interactable: Interactable
var _actions_layer: CanvasLayer
var _surrender_button: Button
var _escape_button: Button
var _bypass_button: Button
var _encounter_armed := false
var _encounter_resolved := false
var _install_committed := false

func setup(scene_root: Node2D, definition: MapDefinition, player: Player, actors: Node2D) -> void:
	_scene_root = scene_root
	_definition = definition
	_player = player
	_actors = actors
	_ensure_content()
	_build_checkpoint_interactable()
	_build_outcome_ui()
	if not SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.connect(_on_state_replaced)
	if (
		SessionState.state != null
		and not SessionState.state.phase_changed.is_connected(_on_phase_changed)
	):
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
	var ok := encounter_resolver.resolve(SessionState.state, encounter_definition, kind, enemies)
	if ok:
		_on_encounter_resolved()
	return ok


func arm_encounter_for_test() -> void:
	_encounter_resolved = false
	_encounter_armed = false
	_install_committed = false
	_sync_encounter()
	_begin_encounter()


func commit_install_for_test() -> bool:
	return _commit_gate_install()


func _exit_tree() -> void:
	if (
		SessionState.state != null
		and SessionState.state.phase_changed.is_connected(_on_phase_changed)
	):
		SessionState.state.phase_changed.disconnect(_on_phase_changed)
	if SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.disconnect(_on_state_replaced)


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
	var should_offer := (
		ModelScript.is_night_install_active(SessionState.state) and not _install_committed
	)
	if _checkpoint_interactable != null:
		_checkpoint_interactable.enabled = (
			should_offer and not _encounter_armed and not _encounter_resolved
		)
	if should_offer and not _encounter_armed and not _encounter_resolved:
		_teardown_combat_actors()
		_set_outcome_ui_visible(false)
	elif _encounter_armed and not _encounter_resolved:
		_refresh_outcome_buttons()
		_set_outcome_ui_visible(true)
	else:
		_teardown_encounter()


func _begin_encounter() -> void:
	if _encounter_armed or _encounter_resolved:
		return
	_spawn_combat_actors()
	encounter_checkpoint.arm(SessionState.state, encounter_definition.encounter_id)
	_encounter_armed = true
	if _checkpoint_interactable != null:
		_checkpoint_interactable.enabled = false
	_refresh_outcome_buttons()
	_set_outcome_ui_visible(true)


func _on_encounter_resolved() -> void:
	_encounter_resolved = true
	_encounter_armed = false
	encounter_checkpoint.clear()
	_set_outcome_ui_visible(false)
	_teardown_combat_actors()
	_commit_gate_install()


func _commit_gate_install() -> bool:
	if _install_committed or SessionState.state == null:
		return _install_committed
	_install_committed = AftermathModelScript.commit_install(
		SessionState.state, SessionState.content_db
	)
	return _install_committed


func _teardown_encounter() -> void:
	_encounter_armed = false
	encounter_checkpoint.clear()
	_set_outcome_ui_visible(false)
	_teardown_combat_actors()


func _spawn_combat_actors() -> void:
	if _actors == null or _definition == null:
		return
	_teardown_combat_actors()
	var watch_pos := MapVerification.anchor_position(_definition, CHECKPOINT_ANCHOR)
	var sarge_pos := MapVerification.anchor_position(_definition, SERGEANT_ANCHOR)
	watchman = _make_enemy(
		"BellAndChainWatchman", watch_pos, EnemyArchetype.watchman(), Color(0.62, 0.58, 0.34, 1.0)
	)
	sergeant = _make_enemy(
		"BellAndChainSergeant", sarge_pos, EnemyArchetype.sergeant(), Color(0.55, 0.28, 0.42, 1.0)
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
	_checkpoint_interactable.prompt = "Install the Viru Gate chain assembly"
	_checkpoint_interactable.global_position = position
	_checkpoint_interactable.enabled = false
	_checkpoint_interactable.set_interact_callback(Callable(self, "_on_checkpoint_pressed"))
	_scene_root.add_child(_checkpoint_interactable)


func _on_checkpoint_pressed(_actor: Node) -> void:
	_begin_encounter()


func _build_outcome_ui() -> void:
	_actions_layer = CanvasLayer.new()
	_actions_layer.name = "BellAndChainNightOutcomeActions"
	_actions_layer.layer = 43
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
	for button in [_surrender_button, _escape_button, _bypass_button]:
		_actions_layer.add_child(button)
	_set_outcome_ui_visible(false)


func _make_outcome_button(
	node_name: String, label: String, kind: StringName, pos: Vector2
) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
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


func _ensure_content() -> void:
	if not SessionState.content_db.is_loaded():
		SessionState.content_db.load_from_directories(ModelScript.CONTENT_DIRS)
	encounter_definition = EncounterOutcomeDefinition.from_content_db(
		SessionState.content_db, ENCOUNTER_ID
	)
