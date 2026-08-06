class_name UrbanPopulationPlacement
extends RefCounted

## Deterministic Lower Town crowd placement for profile actor plans.
## WHY: profile resolution stays renderer-agnostic; this module owns the authored
## zone bounds and walkability/clearance checks shared by runtime and evidence capture.

const MapVerificationScript := preload("res://scripts/map/map_verification.gd")

const PROP_CLEARANCE := 42.0
const ACTOR_CLEARANCE := 24.0

const ZONE_BOUNDS: Dictionary = {
	&"street_frontage": Rect2(1856.0, 1664.0, 1056.0, 448.0),
	&"market_lane": Rect2(96.0, 1696.0, 1120.0, 256.0),
	&"work_yard": Rect2(2112.0, 2240.0, 704.0, 512.0),
	&"residential_yard": Rect2(480.0, 2400.0, 1600.0, 960.0),
	&"checkpoint": Rect2(3392.0, 1600.0, 320.0, 480.0),
	&"safe_interior": Rect2(3072.0, 1600.0, 480.0, 480.0),
}


static func build_placements(
	definition: MapDefinition,
	grid: MapTerrainGrid,
	profile: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if definition == null or grid == null or profile.is_empty():
		return result
	var used: Array[Vector2] = []
	var props: Array[Vector2] = []
	for prop: Dictionary in definition.props:
		props.append(prop["position"])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(profile.get("seed", 0)) ^ 0x524419
	var actor_plan: Variant = profile.get("actor_plan", [])
	if not actor_plan is Array:
		return result
	for actor: Variant in actor_plan:
		if not actor is Dictionary:
			continue
		var record: Dictionary = actor
		var zone_id: StringName = record.get("zone_id", &"")
		var zone: Rect2 = ZONE_BOUNDS.get(zone_id, Rect2())
		var position := _find_position(definition, grid, zone, props, used, rng)
		if position == Vector2.INF:
			return result
		used.append(position)
		result.append({
			"actor_index": int(record.get("actor_index", result.size())),
			"actor_id": record.get("actor_id", &""),
			"role": String(record.get("role", "")),
			"occupation": String(record.get("occupation", "")),
			"zone_id": String(zone_id),
			"position": position,
		})
	return result


static func _find_position(
	definition: MapDefinition,
	grid: MapTerrainGrid,
	zone: Rect2,
	props: Array[Vector2],
	used: Array[Vector2],
	rng: RandomNumberGenerator
) -> Vector2:
	if zone == Rect2():
		return Vector2.INF
	var min_cell := Vector2i(
		floori(zone.position.x / definition.cell_size),
		floori(zone.position.y / definition.cell_size)
	)
	var max_cell := Vector2i(
		ceili(zone.end.x / definition.cell_size) - 1,
		ceili(zone.end.y / definition.cell_size) - 1
	)
	for _attempt in 900:
		var cell := Vector2i(
			rng.randi_range(min_cell.x, max_cell.x),
			rng.randi_range(min_cell.y, max_cell.y)
		)
		if not MapVerificationScript.is_walkable_cell(definition, grid, cell):
			continue
		var candidate := Vector2(
			float(cell.x * definition.cell_size + definition.cell_size / 2) + rng.randf_range(-9.0, 9.0),
			float(cell.y * definition.cell_size + definition.cell_size / 2) + rng.randf_range(-9.0, 9.0)
		)
		if not zone.has_point(candidate) or not MapVerificationScript.is_walkable_point(definition, grid, candidate):
			continue
		var clear := true
		for prop_position: Vector2 in props:
			if candidate.distance_to(prop_position) < PROP_CLEARANCE:
				clear = false
				break
		if not clear:
			continue
		for used_position: Vector2 in used:
			if candidate.distance_to(used_position) < ACTOR_CLEARANCE:
				clear = false
				break
		if clear:
			return candidate
	return Vector2.INF
