class_name WorldMapGraph
extends RefCounted

## Builds the player-facing district graph from DoorNavigator's active transition
## manifest plus authored map-definition transitions. Scene nodes always match the
## manifest exactly; edges only keep destinations that are also active.

const KalevSmithy := preload("res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd")
const StOlafsGuildHall := preload("res://scripts/map/definitions/prototypes/st_olafs_guild_hall_definition.gd")
const DistantLocationDefinitions := preload(
	"res://scripts/map/definitions/outdoor/distant_location_definitions.gd"
)

## WHY: temporary debug unlock so designers can jump to any active district without
## walking adjacency. Release builds keep authored-neighbor travel only.
static func allow_all_active_travel() -> bool:
	return OS.is_debug_build()


## Geographic-ish normalized positions so the overlay reads as Reval districts.
## Unknown active scenes fall back to a bottom row so nothing is silently dropped.
const LAYOUT_BY_SCENE: Dictionary = {
	&"reval_toompea": Vector2(0.16, 0.42),
	&"reval_north": Vector2(0.40, 0.16),
	&"reval_harbor": Vector2(0.70, 0.10),
	&"reval_harbor_north": Vector2(0.64, 0.10),
	&"reval_harbor_east": Vector2(0.50, 0.06),
	&"viru_gate_foreland": Vector2(0.86, 0.48),
	&"reval_monastery": Vector2(0.40, 0.30),
	&"reval_center": Vector2(0.40, 0.46),
	&"st_olafs_guild_hall": Vector2(0.22, 0.28),
	&"reval_east": Vector2(0.70, 0.50),
	&"forge": Vector2(0.88, 0.58),
	&"reval_south": Vector2(0.46, 0.78),
}


static func active_scene_ids() -> Array[StringName]:
	# WHY: distant Estonia placeholders stay on the global map tab only so the
	# Reval district graph does not absorb island/road destinations.
	var ids: Array[StringName] = []
	for scene_id in DoorNavigator.get_active_scene_ids():
		if GlobalMapCatalog.is_distant_scene(scene_id):
			continue
		ids.append(scene_id)
	return ids


static func create_definition(scene_id: StringName) -> MapDefinition:
	match scene_id:
		&"forge":
			return KalevSmithy.create()
		&"st_olafs_guild_hall":
			return StOlafsGuildHall.create()
		_:
			if GlobalMapCatalog.is_distant_scene(scene_id):
				return DistantLocationDefinitions.create(scene_id)
			return MapNeighborPreviewRegistry.create_definition(scene_id)


static func connections() -> Array[Dictionary]:
	var active: Dictionary = {}
	for scene_id in active_scene_ids():
		active[scene_id] = true

	var seen: Dictionary = {}
	var edges: Array[Dictionary] = []
	for scene_id in active.keys():
		var definition := create_definition(scene_id)
		if definition == null:
			continue
		for transition in definition.transitions:
			var destination := StringName(String(transition.get("destination_scene_id", "")))
			if destination.is_empty() or not active.has(destination):
				continue
			var key := _edge_key(scene_id, destination)
			if seen.has(key):
				continue
			seen[key] = true
			edges.append({
				"from": scene_id,
				"to": destination,
			})
	return edges


## Directed travel for P1-031a: spawn comes from the current scene's authored
## transition into the destination, never from undirected graph display edges.
## Debug builds may fall back to a destination default spawn for non-adjacent hops.
static func resolve_travel_spawn(from_scene_id: StringName, to_scene_id: StringName) -> StringName:
	if from_scene_id.is_empty() or to_scene_id.is_empty():
		return &""
	if from_scene_id == to_scene_id:
		return &""
	if not DoorNavigator.has_active_scene(to_scene_id):
		return &""
	# District fast-travel never jumps onto the global placeholder layer.
	if GlobalMapCatalog.is_distant_scene(to_scene_id):
		return &""
	var definition := create_definition(from_scene_id)
	if definition != null:
		for transition in definition.transitions:
			var destination := StringName(String(transition.get("destination_scene_id", "")))
			if destination != to_scene_id:
				continue
			var spawn := StringName(String(transition.get("destination_spawn_id", "")))
			if spawn.is_empty():
				continue
			if not DoorNavigator.has_spawn(to_scene_id, spawn):
				continue
			return spawn
	if allow_all_active_travel() and not GlobalMapCatalog.is_distant_scene(from_scene_id):
		return resolve_debug_fallback_spawn(to_scene_id)
	return &""


## Deterministic landing spawn when no authored edge exists (debug unlock only).
static func resolve_debug_fallback_spawn(to_scene_id: StringName) -> StringName:
	var spawns := DoorNavigator.get_scene_spawn_ids(to_scene_id)
	if spawns.is_empty():
		return &""
	return spawns[0]


static func plan_travel(from_scene_id: StringName, to_scene_id: StringName) -> Dictionary:
	var spawn := resolve_travel_spawn(from_scene_id, to_scene_id)
	if spawn.is_empty():
		return {}
	return {
		"scene_id": to_scene_id,
		"spawn_id": spawn,
	}


static func travelable_neighbors(from_scene_id: StringName) -> Array[StringName]:
	var neighbors: Array[StringName] = []
	if from_scene_id.is_empty():
		return neighbors
	for scene_id in active_scene_ids():
		if scene_id == from_scene_id:
			continue
		if resolve_travel_spawn(from_scene_id, scene_id).is_empty():
			continue
		neighbors.append(scene_id)
	return neighbors


static func layout_positions(scene_ids: Array[StringName]) -> Dictionary:
	var positions: Dictionary = {}
	var fallback_index := 0
	for scene_id in scene_ids:
		if LAYOUT_BY_SCENE.has(scene_id):
			positions[scene_id] = LAYOUT_BY_SCENE[scene_id]
			continue
		# WHY: keep every active manifest scene visible even when layout is not curated yet.
		var slot := float(fallback_index)
		positions[scene_id] = Vector2(0.12 + fmod(slot, 5.0) * 0.18, 0.90)
		fallback_index += 1
	return positions


static func resolve_current_scene_id(scene: Node) -> StringName:
	if scene == null:
		return &""
	var path := scene.scene_file_path
	if path.is_empty():
		return &""
	for scene_id in active_scene_ids():
		if DoorNavigator.get_scene_path(scene_id) == path:
			return scene_id
	return &""


static func _edge_key(a: StringName, b: StringName) -> String:
	var left := String(a)
	var right := String(b)
	if left < right:
		return "%s|%s" % [left, right]
	return "%s|%s" % [right, left]
