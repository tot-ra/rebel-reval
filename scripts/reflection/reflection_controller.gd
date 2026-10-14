class_name ReflectionController
extends Node

const OVERLAY_SCENE := preload("res://scenes/ui/reflection_overlay.tscn")
const ModelScript := preload("res://scripts/reflection/reflection_model.gd")
const HUB_SCRIPT := preload("res://scripts/reflection/hingepuu_hub.gd")
const SpiritSightScript := preload("res://scripts/combat/spirit_sight.gd")
## The speaker id every guilt phantom dialogue uses; the arena shows the phantom's name.
const PHANTOM_SPEAKER_ID := &"char.guilt_phantom"

var _overlay: ReflectionOverlay
var _hub: HingepuuHub
var _evaluator := StateRuleEvaluator.new()
var _state: GameState
var _last_toggle_msec := 0
## SW-2: the content used for phantom duels; null falls back to SessionState.content_db.
var content_db: ContentDB
## Guilt the last phantom duel lifted (0 after a loss).
var last_phantom_absolution := 0
var _phantom_host: SpiritArenaHost
var _phantom_school: StringName = &""
var _sight_before_phantom := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = OVERLAY_SCENE.instantiate() as ReflectionOverlay
	_overlay.visible = false
	add_child(_overlay)
	_overlay.closed.connect(_on_overlay_closed)
	_overlay.conviction_chosen.connect(_on_conviction_chosen)
	_hub = HUB_SCRIPT.new() as HingepuuHub
	add_child(_hub)
	_hub.reflection_requested.connect(open)
	_hub.phantom_duel_requested.connect(face_phantom)
	_bind_state(SessionState.state)
	if not SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.connect(_on_state_replaced)


func _exit_tree() -> void:
	_unbind_state()
	if SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.disconnect(_on_state_replaced)


func _process(_delta: float) -> void:
	if _hub == null or _state == null:
		return
	if not Input.is_action_just_pressed("toggle_hingepuu") or _phantom_host != null:
		return
	var now := Time.get_ticks_msec()
	if now - _last_toggle_msec < 250:
		return
	_last_toggle_msec = now
	if _hub.is_active():
		_hub.leave(get_parent() as Node2D)
	else:
		enter_hingepuu()


func is_open() -> bool:
	return _overlay != null and _overlay.is_open()


func enter_hingepuu() -> bool:
	if _hub == null or _state == null:
		return false
	var actor := get_parent() as Node2D
	if actor == null:
		return false
	return _hub.enter(_state, actor)


func is_hingepuu_active() -> bool:
	return _hub != null and _hub.is_active()


func leave_hingepuu() -> bool:
	if _hub == null:
		return false
	return _hub.leave(get_parent() as Node2D)


func get_hingepuu() -> HingepuuHub:
	return _hub


## SW-2: open the spirit duel against a guilt phantom over the hub (2D arena, world frozen).
## The arena is created per duel so its tier scaling never leaks into another duel.
func face_phantom(phantom: Dictionary) -> bool:
	if _state == null or _phantom_host != null or phantom.is_empty():
		return false
	var db := content_db if content_db != null else SessionState.content_db
	if db == null:
		return false
	var host := SpiritArenaHost.new()
	host.speaker_names = {PHANTOM_SPEAKER_ID: String(phantom.get("name", ""))}
	GuiltPhantoms.configure_duel(host.duel, phantom)
	add_child(host)
	_phantom_host = host
	_phantom_school = StringName(phantom.get("school", &""))
	_sight_before_phantom = _state.spirit_sight
	host.closed.connect(_on_phantom_duel_closed)
	if _hub != null:
		_hub.set_duel_open(true)
	if host.open_scripted(db, _state, StringName(phantom.get("dialogue_id", &""))):
		return true
	host.closed.disconnect(_on_phantom_duel_closed)
	_release_phantom_host()
	return false


func phantom_duel_host() -> SpiritArenaHost:
	return _phantom_host


## A won duel lifts the phantom's guilt; a loss or an abandoned duel leaves it as it was.
func _on_phantom_duel_closed(outcome: Dictionary) -> void:
	if _state != null and _phantom_school != &"":
		last_phantom_absolution = GuiltPhantoms.apply_outcome(_state.guilt, _phantom_school, outcome)
	_release_phantom_host()


func _release_phantom_host() -> void:
	# The hub is a reflection, not the street: leave the sight the duel switched on.
	if _state != null and _phantom_host != null and not _sight_before_phantom and _state.spirit_sight:
		var sight: Node = get_tree().get_first_node_in_group(SpiritSightScript.SIGHT_GROUP) if is_inside_tree() else null
		if sight != null and sight.get(&"state") == _state:
			sight.call(&"leave_immediately")
		else:
			_state.spirit_sight = false
	if _phantom_host != null:
		_phantom_host.queue_free()
	_phantom_host = null
	_phantom_school = &""
	if _hub != null:
		_hub.set_duel_open(false)


func is_available() -> bool:
	return ModelScript.is_available(_state)

func open() -> void:
	if _overlay == null or _state == null or not is_available():
		return
	_close_other_overlays()
	_overlay.present(ModelScript.build_snapshot(_state))


func close() -> void:
	if _overlay != null and _overlay.is_open():
		_overlay.close()


func _on_state_replaced(_previous: GameState, current: GameState, _reason: StringName) -> void:
	_bind_state(current)
	if is_available():
		call_deferred("open")


func _bind_state(state: GameState) -> void:
	_unbind_state()
	_state = state
	if _state != null and not _state.phase_changed.is_connected(_on_phase_changed):
		_state.phase_changed.connect(_on_phase_changed)
	if is_available():
		call_deferred("open")


func _unbind_state() -> void:
	if _state != null and _state.phase_changed.is_connected(_on_phase_changed):
		_state.phase_changed.disconnect(_on_phase_changed)
	_state = null


func _on_phase_changed(_previous: StringName, _next: StringName) -> void:
	if is_available():
		call_deferred("open")


func _on_conviction_chosen(option_id: String) -> void:
	if _state == null:
		return
	if not ModelScript.apply_conviction(_state, option_id, _evaluator):
		push_warning("Reflection conviction failed: %s" % _evaluator.get_last_error())
		return
	close()
	var menu := get_parent().get_node_or_null("QuickAccessMenu") as QuickAccessMenu
	if menu != null:
		menu.refresh_action_availability()


func _on_overlay_closed() -> void:
	var menu := get_parent().get_node_or_null("QuickAccessMenu") as QuickAccessMenu
	if menu != null:
		menu.refresh_action_availability()


func _close_other_overlays() -> void:
	var inventory := get_parent().get_node_or_null("InventoryController") as InventoryController
	if inventory != null:
		inventory.close()
	var journal := get_parent().get_node_or_null("JournalController") as JournalController
	if journal != null:
		journal.close()
	var world_map := get_parent().get_node_or_null("WorldMapController") as WorldMapController
	if world_map != null:
		world_map.close()
