class_name WorldMapGraph
extends RefCounted

## Builds the player-facing district graph from DoorNavigator's active transition
## manifest plus authored map-definition transitions. Scene nodes always match the
## manifest exactly; edges only keep destinations that are also active.

const KalevSmithy := preload("res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd")
const DistantLocationDefinitions := preload(
	"res://scripts/map/definitions/outdoor/distant_location_definitions.gd"
)

## Geographic-ish normalized positions so the overlay reads as Reval districts.
## Unknown active scenes fall back to a bottom row so nothing is silently dropped.
const LAYOUT_BY_SCENE: Dictionary = {
	&"reval_city": Vector2(0.62, 0.30),
}

## Key places of the seamless city (ADR 0031) shown as fast-travel nodes in place
## of the single `reval_city` node. `id` is the node id (no dots: it becomes a
## Godot node name), `spawn` a spawn registered for `reval_city`, `pos` a
## schematic position (north up, Toompea west, Viru east), not surveyed.
const CITY_PLACES: Array[Dictionary] = [
	{"id": &"city_fish_landing", "spawn": &"poi.fish_landing", "pos": Vector2(0.62, 0.07)},
	{"id": &"city_coastal_gate", "spawn": &"gate.coastal", "pos": Vector2(0.62, 0.20)},
	{"id": &"city_kalarand", "spawn": &"suburb.kalarand", "pos": Vector2(0.20, 0.10)},
	{"id": &"city_st_olaf", "spawn": &"landmark.st_olaf", "pos": Vector2(0.38, 0.27)},
	{"id": &"city_pikk_granary", "spawn": &"poi.granary.pikk", "pos": Vector2(0.58, 0.34)},
	{"id": &"city_viru_gate", "spawn": &"gate.viru", "pos": Vector2(0.80, 0.42)},
	{"id": &"city_viru_outside", "spawn": &"gate.viru.outside", "pos": Vector2(0.88, 0.57)},
	{"id": &"city_forum", "spawn": &"poi.forum", "pos": Vector2(0.48, 0.47)},
	{"id": &"city_kalev_smithy", "spawn": &"kalev_smithy", "pos": Vector2(0.66, 0.60)},
	{"id": &"city_bishop_garden", "spawn": &"poi.well.bishop_garden", "pos": Vector2(0.16, 0.50)},
	{"id": &"city_st_nicholas", "spawn": &"landmark.st_nicholas", "pos": Vector2(0.32, 0.64)},
	{"id": &"city_castle_barracks", "spawn": &"poi.barracks.castle", "pos": Vector2(0.14, 0.68)},
	{"id": &"city_toompea_road", "spawn": &"road.toompea_west", "pos": Vector2(0.14, 0.86)},
	{"id": &"city_karja_outside", "spawn": &"gate.karja.outside", "pos": Vector2(0.58, 0.82)},
	{"id": &"city_harju_outside", "spawn": &"gate.harju.outside", "pos": Vector2(0.38, 0.90)},
]


## WHY: temporary debug unlock so designers can jump to any active district without
## walking adjacency. Release builds keep authored-neighbor travel only.
static func allow_all_active_travel() -> bool:
	return OS.is_debug_build()


static func is_city_place(node_id: StringName) -> bool:
	return not city_place(node_id).is_empty()


static func city_place(node_id: StringName) -> Dictionary:
	for place in CITY_PLACES:
		if place["id"] == node_id:
			return place
	return {}


## WHY: debug builds list every place so designers can jump anywhere. Exploration
## gating (a place appears once the player has found it) plugs in here later.
static func city_place_discovered(_place: Dictionary) -> bool:
	return true


static func active_scene_ids() -> Array[StringName]:
	# WHY: distant Estonia placeholders stay on the global map tab only so the
	# Reval district graph does not absorb island/road destinations.
	var ids: Array[StringName] = []
	for scene_id in DoorNavigator.get_active_scene_ids():
		if GlobalMapCatalog.is_distant_scene(scene_id):
			continue
		# The 2D smithy is retired from travel: CityTravel redirects it into the city.
		if CityTravel.REDIRECTS.has(scene_id):
			continue
		# The city is shown as its key places instead of one node.
		if scene_id == CityTravel.CITY_SCENE_ID:
			for place in CITY_PLACES:
				if (
					city_place_discovered(place)
					and DoorNavigator.has_spawn(scene_id, place["spawn"])
				):
					ids.append(place["id"])
			continue
		ids.append(scene_id)
	return ids


static func create_definition(scene_id: StringName) -> MapDefinition:
	match scene_id:
		&"forge":
			return KalevSmithy.create()
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
		if is_city_place(scene_id):
			continue
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
			(
				edges
				. append(
					{
						"from": scene_id,
						"to": destination,
					}
				)
			)
	return edges


## Directed travel for P1-031a: spawn comes from the current scene's authored
## transition into the destination, never from undirected graph display edges.
## Debug builds may fall back to a destination default spawn for non-adjacent hops.
static func resolve_travel_spawn(from_scene_id: StringName, to_scene_id: StringName) -> StringName:
	if from_scene_id.is_empty() or to_scene_id.is_empty():
		return &""
	if from_scene_id == to_scene_id:
		return &""
	var place := city_place(to_scene_id)
	if not place.is_empty():
		var registered := DoorNavigator.has_spawn(CityTravel.CITY_SCENE_ID, place["spawn"])
		return place["spawn"] if registered else &""
	if not DoorNavigator.has_active_scene(to_scene_id):
		return &""
	# District fast-travel never jumps onto the global placeholder layer.
	if GlobalMapCatalog.is_distant_scene(to_scene_id):
		return &""
	# ADR 0031: from the seamless city every Reval district is a fast-travel
	# point inside the same scene (DoorNavigator redirects it to a city spawn).
	if from_scene_id == CityTravel.CITY_SCENE_ID:
		var routed: Array = CityTravel.redirect(to_scene_id, &"")
		if routed[0] == CityTravel.CITY_SCENE_ID:
			var spawns := DoorNavigator.get_scene_spawn_ids(to_scene_id)
			return spawns[0] if not spawns.is_empty() else &""
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
	var place := city_place(to_scene_id)
	return {
		"scene_id": CityTravel.CITY_SCENE_ID if not place.is_empty() else to_scene_id,
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
		var place := city_place(scene_id)
		if not place.is_empty():
			positions[scene_id] = place["pos"]
			continue
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
	# WHY: search every active scene, distant ones included. active_scene_ids()
	# hides them from the district graph, so using it here left the id empty in
	# a world_* location and the map could not plan the trip back to Reval.
	for scene_id in DoorNavigator.get_active_scene_ids():
		if DoorNavigator.get_scene_path(scene_id) == path:
			return scene_id
	return &""


static func _edge_key(a: StringName, b: StringName) -> String:
	var left := String(a)
	var right := String(b)
	if left < right:
		return "%s|%s" % [left, right]
	return "%s|%s" % [right, left]
