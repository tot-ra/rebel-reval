class_name MapPhaseBinder
extends Node

const PhaseProfileModelScript := preload("res://scripts/phase/phase_profile_model.gd")
const MapPatrolControllerScript := preload("res://scripts/phase/map_patrol_controller.gd")

## Applies per-location phase rules to NPCs, props, patrols, and the 3D view runtime.

var location_id: StringName = &""

var _definition: MapDefinition
var _view_runtime: MapViewRuntime
var _npcs: Dictionary = {}
var _props: Dictionary = {}
var _patrols: Dictionary = {}


func setup(
	map_location_id: StringName,
	definition: MapDefinition,
	view_runtime: MapViewRuntime,
	listen_to_director: bool = true
) -> void:
	location_id = map_location_id
	_definition = definition
	_view_runtime = view_runtime
	if listen_to_director:
		if not PhaseDirector.profile_applied.is_connected(_on_profile_applied):
			PhaseDirector.profile_applied.connect(_on_profile_applied)
		PhaseDirector.sync_current_phase()


func register_npc(npc_id: StringName, actor: Node2D, default_anchor_id: StringName = &"") -> void:
	_npcs[npc_id] = {
		"actor": actor,
		"default_anchor_id": default_anchor_id,
	}


func register_prop(object_id: StringName, handler: Callable) -> void:
	_props[object_id] = handler


func register_patrol(patrol_id: StringName, controller: Node) -> void:
	_patrols[patrol_id] = controller


func get_patrol_controller(patrol_id: StringName) -> Node:
	return _patrols.get(patrol_id, null) as Node


func _exit_tree() -> void:
	if PhaseDirector.profile_applied.is_connected(_on_profile_applied):
		PhaseDirector.profile_applied.disconnect(_on_profile_applied)


func apply_authored_profile(profile: Dictionary) -> void:
	_apply_profile(profile)


func _on_profile_applied(profile: Dictionary, _phase_id: StringName) -> void:
	_apply_profile(profile)


func _apply_profile(profile: Dictionary) -> void:
	var rules := PhaseProfileModelScript.location_rules(profile, location_id)
	_apply_presentation(profile)
	_apply_npc_rules(rules.get("npcs", []) as Array)
	_apply_prop_rules(rules.get("props", []) as Array)
	_apply_patrol_rules(rules.get("patrols", []) as Array)


func _apply_presentation(profile: Dictionary) -> void:
	if _view_runtime == null:
		return
	var presentation := PhaseProfileModelScript.presentation(profile)
	if presentation.is_empty():
		return
	# Day profiles keep the shared clock running; night profiles freeze so a
	# 60s in-game day cannot dawn mid-investigation. Default true so outdoor
	# exploration keeps a moving sun when content omits the flag.
	var cycle_enabled := bool(presentation.get("cycle_enabled", true))
	_view_runtime.cycle_enabled = cycle_enabled
	var music_director := get_node_or_null("/root/MusicDirector")
	if (
		cycle_enabled
		and music_director != null
		and music_director.has_method(&"is_cycle_active")
		and bool(music_director.call(&"is_cycle_active"))
	):
		# Continue the live global clock instead of rewinding to the authored
		# phase start every time this map's binder re-applies.
		_view_runtime.cycle_progress = float(music_director.call(&"get_cycle_progress"))
	else:
		_view_runtime.cycle_progress = float(
			presentation.get("cycle_progress", _view_runtime.cycle_progress)
		)
	if _view_runtime.view != null:
		_view_runtime.view.apply_cycle_progress(_view_runtime.cycle_progress)
	if music_director != null and music_director.has_method(&"set_cycle_progress"):
		music_director.call(&"set_cycle_progress", _view_runtime.cycle_progress)


func _apply_npc_rules(entries: Array) -> void:
	for value in entries:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var rule := value as Dictionary
		var npc_id := StringName(String(rule.get("npc_id", "")))
		if not _npcs.has(npc_id):
			continue
		var record: Dictionary = _npcs[npc_id]
		var actor: Node2D = record.get("actor")
		if actor == null or not is_instance_valid(actor):
			continue
		var visible := bool(rule.get("visible", true))
		actor.visible = visible
		if actor.has_method("set_phase_visibility"):
			actor.call("set_phase_visibility", visible)
		if not visible:
			continue
		var anchor_id := StringName(String(rule.get("anchor_id", record.get("default_anchor_id", ""))))
		if anchor_id.is_empty() or _definition == null:
			continue
		if MapVerification.has_anchor(_definition, anchor_id):
			actor.global_position = MapVerification.anchor_position(_definition, anchor_id)


func _apply_prop_rules(entries: Array) -> void:
	for value in entries:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var rule := value as Dictionary
		var object_id := StringName(String(rule.get("object_id", "")))
		if not _props.has(object_id):
			continue
		var handler: Callable = _props[object_id]
		if handler.is_valid():
			handler.call(bool(rule.get("visible", true)))


func _apply_patrol_rules(entries: Array) -> void:
	for value in entries:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var rule := value as Dictionary
		var patrol_id := StringName(String(rule.get("patrol_id", "")))
		if not _patrols.has(patrol_id):
			continue
		var controller: Node = _patrols[patrol_id]
		if controller != null and controller.has_method("set_enabled"):
			controller.call("set_enabled", bool(rule.get("enabled", false)))
