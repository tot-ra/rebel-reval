class_name WorldHost
extends Node

## Phase 2 additive-residency prototype for one contiguous outdoor world group.
## The host owns location-package roots and references the already-existing global
## owners. It deliberately does not create players/cameras or perform scene swaps.

signal location_mounted(location_id: StringName)
signal location_unmounted(location_id: StringName)
signal seam_activation_changed(seam_id: String, active: bool)

const ADDITIVE_RESIDENCY_SETTING := "world_host/additive_residency_enabled"
const SCENE_SWAP_FALLBACK_SETTING := "world_host/scene_swap_fallback_enabled"
const LOGIC_LOCATIONS_NAME := "LogicLocations"
const VIEW_LOCATIONS_NAME := "ViewLocations"

var additive_residency_enabled: bool
var scene_swap_fallback_enabled: bool
var player_owner: Node
var camera_owner: Camera3D
var session_owner: Node
var world_layout: Dictionary = {}

var _logic_locations: Node
var _view_locations: Node3D
var _locations_by_id: Dictionary = {}
var _mounted_locations: Dictionary = {}
var _stable_handle_owners: Dictionary = {}
var _duplicate_stable_handles: Array[Dictionary] = []
var _last_global_logic_position := Vector2.ZERO
var _last_location_id: StringName = &""
var _configured := false


func _init() -> void:
	# Project settings provide the shipping default. Tests and a future launch
	# adapter may explicitly opt into the prototype without changing that default.
	additive_residency_enabled = bool(
		ProjectSettings.get_setting(ADDITIVE_RESIDENCY_SETTING, false)
	)
	scene_swap_fallback_enabled = bool(
		ProjectSettings.get_setting(SCENE_SWAP_FALLBACK_SETTING, false)
	)


## Bind global owners and a pre-built MapWorldLayout. No package is mounted when
## the additive feature is disabled, so existing scene entry points remain inert.
func configure(layout: Dictionary, player: Node, camera: Camera3D, session: Node) -> bool:
	if not bool(layout.get("valid", false)):
		return false
	if player == null or camera == null or session == null:
		return false
	if (
		_configured
		and (player_owner != player or camera_owner != camera or session_owner != session)
	):
		return false

	world_layout = layout.duplicate(true)
	player_owner = player
	camera_owner = camera
	session_owner = session
	_locations_by_id.clear()
	for entry_value in world_layout.get("locations", []):
		var entry: Dictionary = entry_value as Dictionary
		var location_id := StringName(entry.get("location_id", ""))
		if location_id.is_empty():
			continue
		_locations_by_id[location_id] = entry.duplicate(true)
	_configured = true
	_ensure_mount_roots()
	return true


func is_configured() -> bool:
	return _configured


func is_additive_residency_active() -> bool:
	return _configured and additive_residency_enabled


func set_additive_residency_enabled(enabled: bool) -> void:
	additive_residency_enabled = enabled


func is_scene_swap_fallback_enabled() -> bool:
	# This prototype never invokes a fallback. Exposing the flag makes the default
	# explicit and prevents a later adapter from silently opting into scene swaps.
	return scene_swap_fallback_enabled


func mounted_location_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for location_id_value in _mounted_locations.keys():
		ids.append(StringName(location_id_value))
	ids.sort()
	return ids


func mounted_location_root(location_id: StringName, view_layer: bool = true) -> Node:
	var mounted: Dictionary = _mounted_locations.get(location_id, {}) as Dictionary
	return mounted.get("view_root" if view_layer else "logic_root") as Node


func location_entry(location_id: StringName) -> Dictionary:
	return (_locations_by_id.get(location_id, {}) as Dictionary).duplicate(true)


func location_origin_world_position(location_id: StringName) -> Vector3:
	var entry := location_entry(location_id)
	if entry.is_empty():
		return Vector3.ZERO
	var origin := Vector2i(entry.get("origin_cell", Vector2i.ZERO))
	# MapViewBridge uses one world unit per authored cell. The package root is
	# therefore offset in global cells, not in authored pixel coordinates.
	return Vector3(float(origin.x), 0.0, float(origin.y))


func location_origin_logic_position(location_id: StringName) -> Vector2:
	var entry := location_entry(location_id)
	if entry.is_empty():
		return Vector2.ZERO
	var origin := Vector2i(entry.get("origin_cell", Vector2i.ZERO))
	var cell_size := int(entry.get("cell_size", 0))
	return Vector2(origin) * float(cell_size)


func global_logic_position(location_id: StringName, local_position: Vector2) -> Vector2:
	return location_origin_logic_position(location_id) + local_position


## Mount a disposable package under both location layers. Packages may be null for
## a data-only proof, but any stable handle present in a package must be unique in
## the entire mounted host.
func mount_location(
	location_id: StringName, logic_package: Node = null, view_package: Node = null
) -> bool:
	if not is_additive_residency_active() or not _locations_by_id.has(location_id):
		return false
	if _mounted_locations.has(location_id):
		return false
	if not _packages_have_unique_handles(location_id, logic_package, view_package):
		return false

	_ensure_mount_roots()
	var entry := location_entry(location_id)
	var logic_root := Node2D.new()
	logic_root.name = String(location_id)
	logic_root.position = location_origin_logic_position(location_id)
	# The two package layers share a location ID while retaining their own
	# coordinate systems: logic uses authored pixels, view uses global cells.
	_logic_locations.add_child(logic_root)
	if logic_package != null:
		logic_root.add_child(logic_package)

	var view_root := Node3D.new()
	view_root.name = String(location_id)
	view_root.position = location_origin_world_position(location_id)
	_view_locations.add_child(view_root)
	if view_package != null:
		view_root.add_child(view_package)

	_mounted_locations[location_id] = {
		"location_id": location_id,
		"origin_cell": Vector2i(entry.get("origin_cell", Vector2i.ZERO)),
		"logic_root": logic_root,
		"view_root": view_root,
	}
	_register_package_handles(location_id, logic_package)
	_register_package_handles(location_id, view_package)
	location_mounted.emit(location_id)
	_refresh_seam_activation()
	return true


func unmount_location(location_id: StringName) -> bool:
	if not _mounted_locations.has(location_id):
		return false
	var mounted: Dictionary = _mounted_locations[location_id] as Dictionary
	var logic_root := mounted.get("logic_root") as Node
	var view_root := mounted.get("view_root") as Node
	if logic_root != null:
		logic_root.queue_free()
	if view_root != null:
		view_root.queue_free()
	_mounted_locations.erase(location_id)
	_rebuild_stable_handle_registry()
	location_unmounted.emit(location_id)
	_refresh_seam_activation()
	return true


func unmount_all() -> void:
	for location_id in mounted_location_ids():
		unmount_location(location_id)


func active_seams() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for seam_value in world_layout.get("seams", []):
		var seam: Dictionary = seam_value as Dictionary
		if _seam_is_active(seam):
			result.append(seam.duplicate(true))
	result.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return String(left.get("id", "")) < String(right.get("id", ""))
	)
	return result


func is_seam_active(seam_id: String) -> bool:
	for seam_value in world_layout.get("seams", []):
		var seam: Dictionary = seam_value as Dictionary
		if String(seam.get("id", "")) == seam_id:
			return _seam_is_active(seam)
	return false


func is_seam_active_between(first_id: StringName, second_id: StringName) -> bool:
	for seam_value in active_seams():
		var seam: Dictionary = seam_value as Dictionary
		if (
			(
				seam.get("base_map_id", &"") == first_id
				and seam.get("neighbor_map_id", &"") == second_id
			)
			or (
				seam.get("base_map_id", &"") == second_id
				and seam.get("neighbor_map_id", &"") == first_id
			)
		):
			return true
	return false


func duplicate_stable_handles() -> Array[Dictionary]:
	return _duplicate_stable_handles.duplicate(true)


func stable_handle_owner(handle: Dictionary) -> Node:
	return _stable_handle_owners.get(_handle_key(handle)) as Node


func stable_handle_count() -> int:
	return _stable_handle_owners.size()


## Observe the canonical logic position without writing to the player. This lets a
## seam probe cross the boundary while the one player owner retains its identity.
func observe_global_logic_position(global_position: Vector2) -> StringName:
	_last_global_logic_position = global_position
	var cell_size := _layout_cell_size()
	if cell_size <= 0:
		_last_location_id = &""
		return _last_location_id
	var global_cell := Vector2i(
		floori(global_position.x / float(cell_size)), floori(global_position.y / float(cell_size))
	)
	_last_location_id = MapWorldLayout.location_at_global_cell(world_layout, global_cell)
	return _last_location_id


func observed_global_logic_position() -> Vector2:
	return _last_global_logic_position


func observed_location_id() -> StringName:
	return _last_location_id


func owner_snapshot() -> Dictionary:
	return {
		"player": player_owner,
		"camera": camera_owner,
		"session": session_owner,
	}


func _ensure_mount_roots() -> void:
	if _logic_locations == null:
		_logic_locations = Node.new()
		_logic_locations.name = LOGIC_LOCATIONS_NAME
		add_child(_logic_locations)
	if _view_locations == null:
		_view_locations = Node3D.new()
		_view_locations.name = VIEW_LOCATIONS_NAME
		add_child(_view_locations)


func _layout_cell_size() -> int:
	for entry_value in world_layout.get("locations", []):
		var entry: Dictionary = entry_value as Dictionary
		return int(entry.get("cell_size", 0))
	return 0


func _seam_is_active(seam: Dictionary) -> bool:
	return (
		_mounted_locations.has(seam.get("base_map_id", &""))
		and _mounted_locations.has(seam.get("neighbor_map_id", &""))
	)


func _refresh_seam_activation() -> void:
	for seam_value in world_layout.get("seams", []):
		var seam: Dictionary = seam_value as Dictionary
		var seam_id := String(seam.get("id", ""))
		var active := _seam_is_active(seam)
		if not seam_id.is_empty():
			seam_activation_changed.emit(seam_id, active)


func _packages_have_unique_handles(
	location_id: StringName, logic_package: Node, view_package: Node
) -> bool:
	var candidate_keys: Dictionary = {}
	var packages: Array[Node] = []
	if logic_package != null:
		packages.append(logic_package)
	if view_package != null:
		packages.append(view_package)
	for package in packages:
		for handle in _stable_handles_in(package, location_id):
			var object_id := String(handle.get("object_id", ""))
			if object_id.is_empty():
				return false
			var key := _handle_key(handle)
			if candidate_keys.has(key) or _stable_handle_owners.has(key):
				_duplicate_stable_handles.append(handle.duplicate(true))
				return false
			candidate_keys[key] = true
	return true


func _register_package_handles(location_id: StringName, package: Node) -> void:
	if package == null:
		return
	for handle in _stable_handles_in(package, location_id):
		_stable_handle_owners[_handle_key(handle)] = _node_for_handle(package, handle)


func _rebuild_stable_handle_registry() -> void:
	_stable_handle_owners.clear()
	_duplicate_stable_handles.clear()
	for location_id in mounted_location_ids():
		var mounted: Dictionary = _mounted_locations[location_id] as Dictionary
		_register_package_handles(location_id, mounted.get("logic_root") as Node)
		_register_package_handles(location_id, mounted.get("view_root") as Node)


func _stable_handles_in(package: Node, location_id: StringName) -> Array[Dictionary]:
	var handles: Array[Dictionary] = []
	_collect_stable_handles(package, location_id, handles)
	return handles


func _collect_stable_handles(
	node: Node, location_id: StringName, handles: Array[Dictionary]
) -> void:
	if node.has_meta(&"stable_handle"):
		var raw_handle: Variant = node.get_meta(&"stable_handle")
		if raw_handle is Dictionary:
			handles.append(_normalize_handle(raw_handle as Dictionary, location_id))
	elif node.has_meta(&"stable_id"):
		handles.append(_normalize_handle({"object_id": node.get_meta(&"stable_id")}, location_id))
	for child in node.get_children():
		_collect_stable_handles(child, location_id, handles)


func _normalize_handle(raw_handle: Dictionary, location_id: StringName) -> Dictionary:
	return {
		"location_id": String(raw_handle.get("location_id", location_id)),
		"object_id": String(raw_handle.get("object_id", "")),
	}


func _handle_key(handle: Dictionary) -> String:
	return "%s/%s" % [String(handle.get("location_id", "")), String(handle.get("object_id", ""))]


func _node_for_handle(package: Node, handle: Dictionary) -> Node:
	var target_key := _handle_key(handle)
	return _find_node_for_handle(package, target_key)


func _find_node_for_handle(node: Node, target_key: String) -> Node:
	var location_hint := StringName(target_key.get_slice("/", 0))
	for meta_name in [&"stable_handle", &"stable_id"]:
		if not node.has_meta(meta_name):
			continue
		var raw: Variant = node.get_meta(meta_name)
		var normalized := (
			_normalize_handle(raw as Dictionary, location_hint)
			if raw is Dictionary
			else _normalize_handle({"object_id": raw}, location_hint)
		)
		if _handle_key(normalized) == target_key:
			return node
	for child in node.get_children():
		var found := _find_node_for_handle(child, target_key)
		if found != null:
			return found
	return null
