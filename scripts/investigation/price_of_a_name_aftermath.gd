class_name PriceOfANameAftermath
extends Node

## Patrol bark differences after the Coastal Gate detention install (P4-006).

const MODEL := preload("res://scripts/investigation/price_of_a_name_aftermath_model.gd")
const PATROL_BARK_SCRIPT := preload("res://scripts/phase/map_patrol_bark_presenter.gd")

var _scene_root: Node2D
var _player: Player
var _patrol_controller: MapPatrolController
var _install_consequence: Node
var _patrol_bark: Node


func setup(
	scene_root: Node2D,
	player: Player,
	patrol_controller: MapPatrolController,
	install_consequence: Node
) -> void:
	_scene_root = scene_root
	_player = player
	_patrol_controller = patrol_controller
	_install_consequence = install_consequence
	_spawn_patrol_bark(scene_root, player, patrol_controller)

	if _install_consequence != null:
		_install_consequence.encounter_resolver.resolved.connect(_on_encounter_resolved)

	if not SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.connect(_on_state_replaced)
	if SessionState.state != null and not SessionState.state.phase_changed.is_connected(_on_phase_changed):
		SessionState.state.phase_changed.connect(_on_phase_changed)
	_sync_aftermath()


func commit_install_for_test() -> bool:
	if _install_consequence != null:
		return _install_consequence.commit_install_for_test()
	return MODEL.commit_install(SessionState.state, SessionState.content_db)


func _exit_tree() -> void:
	if SessionState.state != null and SessionState.state.phase_changed.is_connected(_on_phase_changed):
		SessionState.state.phase_changed.disconnect(_on_phase_changed)
	if SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.disconnect(_on_state_replaced)


func _on_state_replaced(_previous: GameState, current: GameState, _reason: StringName) -> void:
	if current != null and not current.phase_changed.is_connected(_on_phase_changed):
		current.phase_changed.connect(_on_phase_changed)
	_sync_aftermath()


func _on_phase_changed(_previous: StringName, _next: StringName) -> void:
	_sync_aftermath()


func _on_encounter_resolved(
	_kind: StringName,
	_quest_id: StringName,
	_quest_state: StringName,
	_encounter_id: StringName
) -> void:
	_sync_aftermath()


func _spawn_patrol_bark(
	scene_root: Node2D,
	player: Player,
	patrol_controller: MapPatrolController
) -> void:
	_patrol_bark = PATROL_BARK_SCRIPT.new()
	_patrol_bark.name = "PriceOfANamePatrolBark"
	add_child(_patrol_bark)
	_patrol_bark.setup(
		scene_root,
		&"loc.lower_town_slice",
		MODEL.BARK_POOL,
		player,
		patrol_controller.get_body() if patrol_controller != null else null
	)
	_patrol_bark.set_enabled(false)


func _sync_aftermath() -> void:
	if _patrol_bark == null:
		return
	var visible := MODEL.is_aftermath_visible(SessionState.state)
	_patrol_bark.set_enabled(
		visible and _patrol_controller != null and _patrol_controller.is_enabled()
	)
