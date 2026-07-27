class_name RootAndEmberInstallConsequence
extends Node

## Peaceful brewery-neighbor hearth install for quest.root_and_ember (P4-007).

const ModelScript := preload("res://scripts/quest/root_and_ember_quest_model.gd")
const AftermathModelScript := preload(
	"res://scripts/investigation/root_and_ember_aftermath_model.gd"
)

const INTERACTABLE_ID := &"interact.root_and_ember.hearth_install"
const INSTALL_ANCHOR := &"brewery_door"

const INTERACTABLE_SCENE := preload("res://scenes/interaction/interactable.tscn")

var _scene_root: Node2D
var _definition: MapDefinition
var _install_interactable: Interactable
var _install_committed := false


func setup(scene_root: Node2D, definition: MapDefinition) -> void:
	_scene_root = scene_root
	_definition = definition
	_ensure_content()
	_build_install_interactable()
	if not SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.connect(_on_state_replaced)
	if SessionState.state != null \
			and not SessionState.state.phase_changed.is_connected(_on_phase_changed):
		SessionState.state.phase_changed.connect(_on_phase_changed)
	_sync_install()


func get_install_interactable() -> Interactable:
	return _install_interactable


func commit_install_for_test() -> bool:
	return _commit_hearth_install()


func _exit_tree() -> void:
	if SessionState.state != null \
			and SessionState.state.phase_changed.is_connected(_on_phase_changed):
		SessionState.state.phase_changed.disconnect(_on_phase_changed)
	if SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.disconnect(_on_state_replaced)


func _on_state_replaced(_previous: GameState, current: GameState, _reason: StringName) -> void:
	if current != null and not current.phase_changed.is_connected(_on_phase_changed):
		current.phase_changed.connect(_on_phase_changed)
	_sync_install()


func _on_phase_changed(_previous: StringName, _next: StringName) -> void:
	_sync_install()


func _sync_install() -> void:
	if SessionState.state == null:
		return
	_ensure_content()
	var should_offer := ModelScript.is_install_active(SessionState.state) and not _install_committed
	if _install_interactable != null:
		_install_interactable.enabled = should_offer


func _build_install_interactable() -> void:
	if _definition == null or _scene_root == null:
		return
	var position := MapVerification.anchor_position(_definition, INSTALL_ANCHOR)
	_install_interactable = INTERACTABLE_SCENE.instantiate() as Interactable
	_install_interactable.name = String(INTERACTABLE_ID)
	_install_interactable.interactable_id = INTERACTABLE_ID
	_install_interactable.interaction_kind = InteractionKinds.USE
	_install_interactable.prompt = "Install the hearth ward hardware"
	_install_interactable.global_position = position
	_install_interactable.enabled = false
	_install_interactable.set_interact_callback(Callable(self, "_on_install_pressed"))
	_scene_root.add_child(_install_interactable)


func _on_install_pressed(_actor: Node) -> void:
	if _commit_hearth_install() and _install_interactable != null:
		_install_interactable.enabled = false


func _commit_hearth_install() -> bool:
	if _install_committed or SessionState.state == null:
		return _install_committed
	_install_committed = AftermathModelScript.commit_install(
		SessionState.state,
		SessionState.content_db
	)
	return _install_committed


func _ensure_content() -> void:
	if not SessionState.content_db.is_loaded():
		SessionState.content_db.load_from_directories(ModelScript.CONTENT_DIRS)
