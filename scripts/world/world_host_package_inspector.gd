class_name WorldHostPackageInspector
extends RefCounted

## Pure walks over a location package, split out of WorldHost (WB-08c, R-1044).
## Nothing here touches the scene tree or host state, so a staged mount can
## inspect its finished, still detached packages on a worker thread (Godot lets a
## worker read nodes that are outside the tree). WorldHost.mount_location() then
## checks the result against its registry instead of walking thousands of view
## nodes inside the mount frame. split_for_entry() is the one function that edits a
## package, and only while it is detached (WB-08e sliced tree entry).


## {violations, entries}: global-kind diagnostics and stable-handle entries
## {handle, key, node} for both packages (either may be null).
static func inspect(location_id: StringName, logic_package: Node, view_package: Node) -> Dictionary:
	var violations: Array[Dictionary] = []
	var entries: Array[Dictionary] = []
	for package: Node in [logic_package, view_package]:
		if package == null:
			continue
		violations.append_array(global_violations(location_id, package))
		entries.append_array(stable_handles(package, location_id))
	return {"violations": violations, "entries": entries}


static func diagnostic(
	code: String, location_id: StringName, node_path: String, detail: String
) -> Dictionary:
	return {
		"code": code,
		"location_id": String(location_id),
		"node_path": node_path,
		"detail": detail,
	}


## The global kind a node represents, or "" for ordinary location content. The
## rig group is checked because a rig scene's root class is not unique to players.
static func global_kind(node: Node) -> String:
	if node is Player:
		return "player"
	if node.is_in_group(&"player_view_rig"):
		return "player_rig"
	if node is Camera3D:
		return "camera"
	if node is WorldEnvironment:
		return "world_environment"
	if node is DirectionalLight3D:
		return "sun"
	if node is SkyWeather3D:
		return "sky_weather"
	if node is CanvasLayer:
		return "hud"
	if node is MapViewRuntime:
		return "runtime"
	return ""


## Diagnostics for every node in `package` that a location may not create. A
## location package is disposable; the listed kinds are host globals (ADR 0019 s.2).
static func global_violations(location_id: StringName, package: Node) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	if package != null:
		_collect_global_violations(location_id, package, package, diagnostics)
	return diagnostics


static func count_globals(node: Node, census: Dictionary) -> void:
	var kind := global_kind(node)
	if census.has(kind):
		census[kind] = int(census[kind]) + 1
		# A rig or HUD may nest cameras or layers of its own; count the owner only.
		return
	for child in node.get_children():
		count_globals(child, census)


## Entries {handle, key, node}. A `stable_handle` dictionary is location-scoped
## ({location_id, object_id}, the MapStableStateStore identity). A bare
## `stable_id` is a world-unique content id (for example `char.aita`), so it
## must exist at most once across every mounted location (ADR 0019 gate).
static func stable_handles(package: Node, location_id: StringName) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	_collect_stable_handles(package, location_id, entries)
	return entries


static func normalize_handle(raw_handle: Dictionary, location_id: StringName) -> Dictionary:
	return {
		"location_id": String(raw_handle.get("location_id", location_id)),
		"object_id": String(raw_handle.get("object_id", "")),
	}


static func handle_key(handle: Dictionary) -> String:
	return "%s/%s" % [String(handle.get("location_id", "")), String(handle.get("object_id", ""))]


static func world_key(handle: Dictionary) -> String:
	return "*/%s" % String(handle.get("object_id", ""))


## WB-08e (R-1069): a finished view enters the tree in slices so no frame pays for
## the whole district (~8 ms on market_civic_quarter). Runs on a worker while the
## view is still detached: every container whose subtree exceeds `max_nodes` gives
## up its children, which become later units. Returns [parent, child] pairs in
## pre-order; the first pair is [null, view] (null = the host's staging root).
## Adding the children back in this order rebuilds the same tree, node for node.
static func split_for_entry(view: Node, max_nodes: int) -> Array[Array]:
	var sizes := {}
	_count_subtree(view, sizes)
	var units: Array[Array] = [[null, view]]
	_split_subtree(view, sizes, maxi(max_nodes, 1), units)
	return units


## Only plain containers enter without their children: they run no script and no
## native child logic on enter or ready, so a later child cannot change what they
## did. MapView3D is the one scripted exception; it has no _ready or _enter_tree
## (its stages build everything before the view reaches the tree). Anything else
## (a scripted flock, a skeleton, a body) enters as one atomic unit.
static func may_split(node: Node) -> bool:
	if node is MapView3D:
		return true
	return node.get_script() == null and (node.get_class() == "Node3D" or node.get_class() == "Node")


## True when sliced teardown must null MultiMesh RIDs before free()
## (dummy-renderer ShaderMaterial instance-parameter ERRORs). Leaf
## MeshInstance3D nodes can free without that walk (R-1077).
static func needs_geometry_strip(node: Node) -> bool:
	if node is MultiMeshInstance3D:
		return true
	if node.get_child_count() == 0:
		return false
	for child in node.get_children():
		if needs_geometry_strip(child):
			return true
	return false


## WB-08e: the next node to remove when tearing `root` down in slices: the last
## leaf (or atomic subtree) of the last splittable path, so children always leave
## before their container and `root` itself goes last. Walks one path, not the tree.
static func next_removal(root: Node) -> Node:
	var node := root
	while node.get_child_count() > 0 and may_split(node):
		node = node.get_child(node.get_child_count() - 1)
	return node


static func _count_subtree(node: Node, sizes: Dictionary) -> int:
	var total := 1
	for child in node.get_children():
		total += _count_subtree(child, sizes)
	sizes[node.get_instance_id()] = total
	return total


static func _split_subtree(
	node: Node, sizes: Dictionary, max_nodes: int, units: Array[Array]
) -> void:
	if int(sizes[node.get_instance_id()]) <= max_nodes or not may_split(node):
		return
	var children := node.get_children()
	# Detach from the back: removing the last child shifts nothing.
	for index in range(children.size() - 1, -1, -1):
		node.remove_child(children[index])
	for child in children:
		units.append([node, child])
		_split_subtree(child, sizes, max_nodes, units)


static func _collect_global_violations(
	location_id: StringName, package: Node, node: Node, diagnostics: Array[Dictionary]
) -> void:
	var kind := global_kind(node)
	if not kind.is_empty():
		diagnostics.append(
			diagnostic(
				WorldHost.DIAG_PACKAGE_CREATES_GLOBAL,
				location_id,
				String(package.get_path_to(node)) if node != package else ".",
				kind
			)
		)
		# The whole subtree belongs to that global; one diagnostic is enough.
		return
	for child in node.get_children():
		_collect_global_violations(location_id, package, child, diagnostics)


static func _collect_stable_handles(
	node: Node, location_id: StringName, entries: Array[Dictionary]
) -> void:
	if node.has_meta(&"stable_handle"):
		var raw_handle: Variant = node.get_meta(&"stable_handle")
		if raw_handle is Dictionary:
			var handle := normalize_handle(raw_handle as Dictionary, location_id)
			entries.append({"handle": handle, "key": handle_key(handle), "node": node})
	elif node.has_meta(&"stable_id"):
		var handle := normalize_handle({"object_id": node.get_meta(&"stable_id")}, location_id)
		entries.append({"handle": handle, "key": world_key(handle), "node": node})
	for child in node.get_children():
		_collect_stable_handles(child, location_id, entries)
