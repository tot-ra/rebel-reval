class_name WorldHostStreamingDriver
extends Node

## WB-08b (R-1043): drives WorldHost seam streaming from the live host player.
## `WorldHost.launch_scene_location()` attaches one driver to a host whose layout
## has streamable seams (reval_outdoor). Every physics frame it feeds the player's global logic
## position to WorldHost.update_streaming(). It also owns the play-side glue the
## pure host policy leaves out:
## - streamed transition doors never run a DoorNavigator scene swap while
##   residency is active; the player walks through the seam instead;
## - package `SeamGate_*` walls (MapSceneBootstrap) open only while both sides of
##   their seam are resident, so nobody walks into unloaded space;
## - touching a streamed door whose neighbour is not resident (failed mount)
##   asks the host for the scene-swap fallback, which DoorNavigator answers with
##   the door's explicit transition;
## - a seam crossing updates the session location and spawn used by saves.
## - WB-08c (R-1044): it mirrors the owner and the player's global cell/sub-cell
##   into the session GameState every tick (WorldHostSeamSave), and on its first
##   tick resumes a loaded save's exact position after DoorNavigator placed the
##   player at the saved spawn.
## Flag off, no driver exists (only a launched host attaches one).

const NODE_NAME := "StreamingDriver"

## False in tests: the fallback resolves through DoorNavigator without swapping.
var execute_fallback := true
## The last DoorNavigator answer ({} until a fallback was requested).
var last_fallback: Dictionary = {}
## Main-thread microseconds of each tick() (the WB-08c streaming-work trace).
var tick_usec := PackedInt64Array()

var _host: WorldHost
var _resume_checked := false
## The GameState this driver mirrored into. A save loaded mid-play replaces the
## session state before this scene is freed; only this one may be released.
var _mirrored_state: GameState


## Attach to `host` when it can stream. Seeds `definition_provider` with the
## registry-compiled definition unless a caller already injected a loader.
## Returns null (nothing attached) for a solo layout or an inactive host.
static func attach(host: WorldHost) -> WorldHostStreamingDriver:
	if host == null or not host.is_additive_residency_active():
		return null
	if (host.world_layout.get("seams", []) as Array).is_empty():
		return null
	var existing := host.get_node_or_null(NODE_NAME) as WorldHostStreamingDriver
	if existing != null:
		return existing
	var driver := WorldHostStreamingDriver.new()
	driver.name = NODE_NAME
	driver._host = host
	if not host.location_loader.is_valid() and not host.definition_provider.is_valid():
		host.definition_provider = registry_definition
	# R-1054 rebinds owner-scoped consumers on a crossing, so the launch
	# location is no longer pinned above the residency cap.
	host.pinned_location_ids.clear()
	host.location_mounted.connect(driver._on_location_mounted)
	host.seam_activation_changed.connect(driver._on_seam_activation_changed)
	host.scene_swap_fallback_requested.connect(driver._on_scene_swap_fallback_requested)
	host.owning_location_changed.connect(driver._on_owning_location_changed)
	host.add_child(driver)
	for location_id in host.mounted_location_ids():
		driver._bind_location(location_id)
	for seam in host.world_layout.get("seams", []):
		driver._apply_gates(seam as Dictionary)
	return driver


## The definition the host mounts for `location_id`: compiled from its explicitly
## registered blueprint (MapBlueprintRegistry), the same source the manifest and
## the scene-owned path use. Null when the location is not registered.
static func registry_definition(location_id: StringName) -> MapDefinition:
	for entry in MapBlueprintRegistry.entries():
		if StringName(entry.get("id", &"")) != location_id:
			continue
		var blueprint := MapBlueprintRegistry.create_blueprint(entry)
		return MapBlueprintCompiler.compile(blueprint) if blueprint != null else null
	return null


func _physics_process(_delta: float) -> void:
	tick()


## One streaming step from the host player's position. Public so the headless
## harness, which cannot rely on frame order, can drive it deterministically.
func tick() -> Dictionary:
	var player := _host.player_owner as Node2D if _host != null else null
	if player == null:
		return {}
	var started := Time.get_ticks_usec()
	var state := _session_game_state()
	if not _resume_checked:
		_resume_checked = true
		var resume: Variant = WorldHostSeamSave.resume_position(_host, state)
		if resume is Vector2:
			player.global_position = resume
	var result := _host.update_streaming(player.global_position)
	if WorldHostSeamSave.capture(_host, state):
		_mirrored_state = state
	tick_usec.append(Time.get_ticks_usec() - started)
	return result


func _exit_tree() -> void:
	# Scene swap or unload: the next entry into this location uses its door spawn.
	if _host != null and _mirrored_state != null and _mirrored_state == _session_game_state():
		WorldHostSeamSave.release(_mirrored_state, _host.owning_location_id())


func _session_game_state() -> GameState:
	var state = _host.session_owner.get("state") if _host.session_owner != null else null
	return state as GameState if state is GameState else null


func _on_location_mounted(location_id: StringName) -> void:
	_bind_location(location_id)


## Disable the scene swap on every streamed door of a freshly mounted location
## and watch those doors for a touch while their neighbour is not resident.
func _bind_location(location_id: StringName) -> void:
	for door in _transition_doors(location_id):
		var transition_id := _transition_id(door)
		if not _host.is_transition_streamed(location_id, transition_id):
			continue
		door.set("transition_enabled", false)
		var on_entered := _on_streamed_door_entered.bind(location_id, transition_id)
		if not door.body_entered.is_connected(on_entered):
			door.body_entered.connect(on_entered)


func _on_seam_activation_changed(seam_id: String, _active: bool) -> void:
	for seam in _host.world_layout.get("seams", []):
		if String((seam as Dictionary).get("id", "")) == seam_id:
			_apply_gates(seam as Dictionary)
			return


## Open both gates of `seam` exactly while the seam is active (both resident).
func _apply_gates(seam: Dictionary) -> void:
	var open := _host.is_seam_active(String(seam.get("id", "")))
	for side in [["base_map_id", "base_transition_id"], ["neighbor_map_id", "neighbor_transition_id"]]:
		var location_id := StringName(seam.get(side[0], &""))
		var logic_root := _host.mounted_location_root(location_id, false)
		if logic_root == null:
			continue
		var transition_id := StringName(seam.get(side[1], &""))
		for body in logic_root.find_children("WorldBounds", "StaticBody2D", true, false):
			for shape in body.get_children():
				if shape.get_meta(MapSceneBootstrap.SEAM_GATE_META, &"") == transition_id:
					# Mounts happen in tick() (_physics_process), never in a physics
					# query flush, so the shape can be toggled directly.
					(shape as CollisionShape2D).disabled = open


func _on_streamed_door_entered(
	body: Node2D, location_id: StringName, transition_id: StringName
) -> void:
	if body != _host.player_owner or location_id != _host.owning_location_id():
		return
	var neighbor_id := _neighbor_through(location_id, transition_id)
	if neighbor_id.is_empty() or _host.mounted_location_ids().has(neighbor_id):
		return
	if _host.pending_location_ids().has(neighbor_id):
		# WB-08c: a healthy in-flight mount holds the player at the sealed gate.
		return
	# The gate is closed because the neighbour failed to mount: degrade to the
	# explicit transition instead of leaving the player at a sealed edge.
	_host.request_scene_swap_fallback(neighbor_id)


func _on_scene_swap_fallback_requested(_location_id: StringName, request: Dictionary) -> void:
	var from_id := StringName(request.get("from_location_id", &""))
	var logic_root := _host.mounted_location_root(from_id, false)
	last_fallback = DoorNavigator.answer_seam_fallback(logic_root, request, execute_fallback)


## Save identity follows the owner: the scene id of the new location plus the
## spawn of the door the player arrived through, so a save taken after a seam
## crossing reloads at that seam through today's scene path.
func _on_owning_location_changed(previous_id: StringName, location_id: StringName) -> void:
	var state := _session_game_state()
	WorldHostSeamSave.release(state, previous_id)
	if state != null:
		var entry := _host.location_entry(location_id)
		var player_state := (state as GameState).player
		player_state.location_id = StringName(entry.get("scene_id", location_id))
		var seam := _host.seam_between(previous_id, location_id)
		var arrival_id := StringName(
			seam.get(
				"neighbor_transition_id" if seam.get("neighbor_map_id", &"") == location_id
				else "base_transition_id",
				&""
			)
		)
		for door in _transition_doors(location_id):
			if _transition_id(door) == arrival_id and not String(door.get("spawn_id")).is_empty():
				player_state.spawn_id = StringName(door.get("spawn_id"))
				break
	_rebind_owner_consumers(location_id)


func _rebind_owner_consumers(location_id: StringName) -> void:
	var scene := _host.get_parent()
	if scene == null:
		return
	var runtime := scene.get_node_or_null("MapViewRuntime") as MapViewRuntime
	if runtime != null:
		runtime.bind_owning_location(location_id)
	# Do not add a method on the launch scene: reval_east.gd already fails
	# gdlint, and staging it blocks commit. The binder is a named child.
	var binder = scene.get_node_or_null("MapPhaseBinder")
	var bootstrap: Dictionary = _host.hosted_bootstrap(location_id)
	var definition := bootstrap.get("definition") as MapDefinition
	if binder != null and definition != null and binder.has_method("setup"):
		binder.call("setup", StringName("loc.%s" % String(location_id)), definition, runtime)
	_host.pinned_location_ids.clear()


func _neighbor_through(location_id: StringName, transition_id: StringName) -> StringName:
	for seam_value in _host.world_layout.get("seams", []):
		var seam: Dictionary = seam_value as Dictionary
		if (
			seam.get("base_map_id", &"") == location_id
			and StringName(seam.get("base_transition_id", &"")) == transition_id
		):
			return StringName(seam.get("neighbor_map_id", &""))
		if (
			seam.get("neighbor_map_id", &"") == location_id
			and StringName(seam.get("neighbor_transition_id", &"")) == transition_id
		):
			return StringName(seam.get("base_map_id", &""))
	return &""


## Doors of a mounted location, classified by stable handle like
## WorldHost.hosted_bootstrap() (no Door type: see the rrmap compile trap).
func _transition_doors(location_id: StringName) -> Array[Area2D]:
	var doors: Array[Area2D] = []
	var logic_root := _host.mounted_location_root(location_id, false)
	if logic_root == null:
		return doors
	for node in logic_root.find_children("*", "Area2D", true, false):
		if _transition_id(node).is_empty():
			continue
		doors.append(node as Area2D)
	return doors


static func _transition_id(node: Node) -> StringName:
	var handle: Variant = node.get_meta(&"stable_handle", {})
	if not handle is Dictionary:
		return &""
	var object_id := String((handle as Dictionary).get("object_id", ""))
	if not object_id.begins_with("transition:"):
		return &""
	return StringName(object_id.trim_prefix("transition:"))
