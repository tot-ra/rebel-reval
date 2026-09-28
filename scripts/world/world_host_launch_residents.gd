class_name WorldHostLaunchResidents
extends RefCounted

## WB-08d follow-up (R-1059): scene-scoped residents of the launch location
## follow that location's residency instead of outliving its package.
##
## A launch adapter such as `reval_east` builds its quest controllers, phase
## binder, patrols, NPCs and interactables as children of the scene itself, in
## the launch location's logic space (ADR 0019 phase 6 keeps them there). Once a
## seam crossing unpins the launch location, a far-band eviction frees its
## package while those nodes stay live: patrols walk over unloaded ground,
## interactables keep monitoring, and NPC rigs stand frozen in empty space.
##
## `suspend()` runs when the launch location unmounts and `resume()` when it
## mounts again (the driver listens to the host signals). Suspension disables
## processing (physics bodies and areas leave the physics space with it), hides
## the `Actors` layer and the 3D rigs mirrored from it, and restores exactly the
## previous process modes and visibility on resume. Quest state is untouched:
## GameState signals still reach suspended controllers, so a phase change while
## the player is elsewhere is already applied when Lower Town comes back.
##
## Kept out (never suspended):
## - the WorldHost and MapViewRuntime (host/owner scoped);
## - CanvasLayer UI and flat Node2D/Node3D scaffolding (MapRoot, Camera2D);
## - any child holding an `InteractionController`: it is the player's
##   interaction input for every mounted location, not a Lower Town resident.

const ACTORS_NODE := &"Actors"
## Set on every node this helper suspended; tests and tools read it.
const SUSPENDED_META := &"world_host_launch_suspended"

var location_id: StringName = &""

var _scene: Node
var _host: WorldHost
var _suspended := false
## Node -> process_mode it had before suspension.
var _process_modes: Dictionary = {}
## Actors layer visibility before suspension.
var _actors_visible := true
## 3D rig -> visible before suspension.
var _rig_visibility: Dictionary = {}


func _init(scene: Node, host: WorldHost, launch_location_id: StringName) -> void:
	_scene = scene
	_host = host
	location_id = launch_location_id


func is_suspended() -> bool:
	return _suspended


## Scene children that belong to the launch location. Resolved on every call:
## the adapter builds its controllers after the host (and this helper) exist.
func residents() -> Array[Node]:
	var found: Array[Node] = []
	if _scene == null or not is_instance_valid(_scene):
		return found
	for child in _scene.get_children():
		if _is_resident(child):
			found.append(child)
	return found


func suspend() -> void:
	if _suspended:
		return
	_suspended = true
	_process_modes.clear()
	_rig_visibility.clear()
	for node in residents():
		_process_modes[node] = node.process_mode
		node.process_mode = Node.PROCESS_MODE_DISABLED
		node.set_meta(SUSPENDED_META, true)
	var actors := _actors()
	if actors != null:
		_actors_visible = actors.visible
		actors.visible = false
		var runtime := _runtime()
		if runtime != null:
			for actor in actors.find_children("*", "Node2D", true, false):
				var rig := runtime.get_actor_rig(actor as Node2D)
				if rig != null and not _rig_visibility.has(rig):
					_rig_visibility[rig] = rig.visible
					rig.visible = false


func resume() -> void:
	if not _suspended:
		return
	_suspended = false
	for node in _process_modes.keys():
		if not is_instance_valid(node):
			continue
		(node as Node).process_mode = _process_modes[node]
		(node as Node).remove_meta(SUSPENDED_META)
	_process_modes.clear()
	var actors := _actors()
	if actors != null:
		actors.visible = _actors_visible
	for rig in _rig_visibility.keys():
		if is_instance_valid(rig):
			(rig as Node3D).visible = bool(_rig_visibility[rig])
	_rig_visibility.clear()


## R-1085: `MapViewRuntimeActors.sync_view_actors` can spawn a rig after
## suspend() ran. Hide those late rigs for the rest of the eviction; resume()
## restores them as visible so quest NPCs spawned while away are there on return.
func hide_late_actor_rigs() -> void:
	if not _suspended:
		return
	var actors := _actors()
	var runtime := _runtime()
	if actors == null or runtime == null:
		return
	for found in actors.find_children("*", "Node2D", true, false):
		var actor := found as Node2D
		var rig := runtime.get_actor_rig(actor)
		if rig == null or not is_instance_valid(rig):
			continue
		if not _rig_visibility.has(rig):
			_rig_visibility[rig] = true
		rig.visible = false


func _is_resident(node: Node) -> bool:
	if node == _host or node is CanvasLayer or node is Node3D:
		return false
	if node.name == ACTORS_NODE:
		return true
	# Flat scaffolding (MapRoot, Camera2D, editor preview) is not gameplay.
	if node is CanvasItem and not node is CollisionObject2D:
		return false
	return not _holds_interaction_controller(node)


static func _holds_interaction_controller(node: Node) -> bool:
	if node is InteractionController:
		return true
	for child in node.get_children():
		if _holds_interaction_controller(child):
			return true
	return false


func _actors() -> Node2D:
	if _scene == null or not is_instance_valid(_scene):
		return null
	return _scene.get_node_or_null(NodePath(String(ACTORS_NODE))) as Node2D


func _runtime() -> MapViewRuntime:
	if _scene == null or not is_instance_valid(_scene):
		return null
	return _scene.get_node_or_null("MapViewRuntime") as MapViewRuntime
