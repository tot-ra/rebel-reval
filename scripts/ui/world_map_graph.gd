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
## schematic position (north up, Toompea west, Viru east), not surveyed. The
## marker on the painted Reval map is derived from the spawn's world position
## (`city_place_map_position`), so it never drifts from where travel lands.
const CITY_PLACES: Array[Dictionary] = [
	{
		"id": &"city_fish_landing",
		"spawn": &"poi.fish_landing",
		"pos": Vector2(0.62, 0.07),
	},
	{
		"id": &"city_coastal_gate",
		"spawn": &"gate.coastal",
		"pos": Vector2(0.62, 0.20),
	},
	{
		"id": &"city_kalarand",
		"spawn": &"suburb.kalarand",
		"pos": Vector2(0.20, 0.10),
	},
	{
		"id": &"city_st_olaf",
		"spawn": &"landmark.st_olaf",
		"pos": Vector2(0.38, 0.27),
	},
	{
		"id": &"city_pikk_granary",
		"spawn": &"poi.granary.pikk",
		"pos": Vector2(0.58, 0.34),
	},
	{
		"id": &"city_viru_gate",
		"spawn": &"gate.viru",
		"pos": Vector2(0.80, 0.42),
	},
	{
		"id": &"city_viru_outside",
		"spawn": &"gate.viru.outside",
		"pos": Vector2(0.88, 0.57),
	},
	{
		"id": &"city_forum",
		"spawn": &"poi.forum",
		"pos": Vector2(0.48, 0.47),
	},
	{
		"id": &"city_kalev_smithy",
		"spawn": &"kalev_smithy",
		"pos": Vector2(0.66, 0.60),
	},
	{
		"id": &"city_bishop_garden",
		"spawn": &"poi.well.bishop_garden",
		"pos": Vector2(0.16, 0.50),
	},
	{
		"id": &"city_st_nicholas",
		"spawn": &"landmark.st_nicholas",
		"pos": Vector2(0.32, 0.64),
	},
	{
		"id": &"city_castle_barracks",
		"spawn": &"poi.barracks.castle",
		"pos": Vector2(0.14, 0.68),
	},
	{
		"id": &"city_toompea_road",
		"spawn": &"road.toompea_west",
		"pos": Vector2(0.14, 0.86),
	},
	{
		"id": &"city_karja_outside",
		"spawn": &"gate.karja.outside",
		"pos": Vector2(0.58, 0.82),
	},
	{
		"id": &"city_harju_outside",
		"spawn": &"gate.harju.outside",
		"pos": Vector2(0.38, 0.90),
	},
]


## The painted Reval basemap (`assets/UI/reval_city_map.jpg`) is the city
## minimap (`content/world/reval_city/minimap.png`, square over plan bounds)
## cropped to rows 0.06..0.86, widened to 16:9 with painted countryside strips
## of 333 px on each side of the 1580 px minimap (2246 px canvas), then
## repainted image-to-image (see assets/SOURCES.csv). These numbers map plan
## UV onto the basemap; change them together with the image.
const CITY_MAP_CROP_TOP := 0.06
const CITY_MAP_CROP_HEIGHT := 0.80
const CITY_MAP_SIDE_PAD := 333.0 / 2246.0
const CITY_MAP_WIDTH := 1580.0 / 2246.0
## Basemap pixel size and the closest two markers may sit: gates and their
## `.outside` spawns are a few metres apart and would cover each other.
const CITY_MAP_PIXELS := Vector2(1820, 1024)
const CITY_MAP_MIN_GAP_PX := 34.0

static var _city_map_positions: Dictionary = {}


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


## Normalized point of a place on the painted Reval basemap: its spawn's world
## position through the minimap crop, nudged apart from close neighbours.
static func city_place_map_position(node_id: StringName) -> Vector2:
	if _city_map_positions.is_empty():
		_city_map_positions = _build_city_map_positions()
	return _city_map_positions.get(node_id, Vector2(0.5, 0.5))


static func _build_city_map_positions() -> Dictionary:
	var plan := CityPlan.load_default()
	var ids: Array[StringName] = []
	var points: Array[Vector2] = []
	for place in CITY_PLACES:
		var at := CityTravel.spawn_position(plan, String(place["spawn"]))
		var uv := (at - plan.bounds.position) / plan.bounds.size
		var normalized := Vector2(
			CITY_MAP_SIDE_PAD + uv.x * CITY_MAP_WIDTH,
			(uv.y - CITY_MAP_CROP_TOP) / CITY_MAP_CROP_HEIGHT
		)
		ids.append(place["id"])
		points.append(normalized * CITY_MAP_PIXELS)
	# Push overlapping pairs apart symmetrically; a few passes settle the small
	# clusters (gate + outside). Deterministic: same order, same result.
	for _pass in 8:
		for i in points.size():
			for j in range(i + 1, points.size()):
				var delta := points[j] - points[i]
				var distance := delta.length()
				if distance >= CITY_MAP_MIN_GAP_PX:
					continue
				var push := delta.normalized() if distance > 0.01 else Vector2.RIGHT
				var shift := push * (CITY_MAP_MIN_GAP_PX - distance) * 0.5
				points[i] -= shift
				points[j] += shift
	var positions := {}
	for i in ids.size():
		positions[ids[i]] = points[i] / CITY_MAP_PIXELS
	return positions


## The place closest to a spot in the city (world XZ), by spawn position: the
## "you are here" marker of the Reval map and the start of the traveler's walk.
## Empty when the player's position is unknown.
static func nearest_city_place(world_xz: Vector2) -> StringName:
	if not world_xz.is_finite():
		return &""
	var plan := CityPlan.load_default()
	var best := &""
	var best_distance := INF
	for place in CITY_PLACES:
		if not city_place_discovered(place):
			continue
		var at := CityTravel.spawn_position(plan, String(place["spawn"]))
		var distance := at.distance_squared_to(world_xz)
		if distance < best_distance:
			best_distance = distance
			best = place["id"]
	return best


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
