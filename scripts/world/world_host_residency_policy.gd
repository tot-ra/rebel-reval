class_name WorldHostResidencyPolicy
extends RefCounted

## WB-08 pure residency policy, split out of WorldHost (R-1044) so the host stays
## under the gdlint file cap. WorldHost.plan_residency() and
## WorldHost.seam_neighbor_distances() remain the public entry points.


## Returns {owner, desired, mount, evict, distances} where distances maps each seam
## neighbour of `owner_id` to the player's distance (cells) from the shared seam
## edge. Only layout seams (streamable by construction) are considered, so a
## travel or interior transition never streams. `resident_ids` includes pending
## (in-flight) mounts: they count against `cap` and get the eviction hysteresis.
static func plan(
	layout: Dictionary,
	owner_id: StringName,
	global_position: Vector2,
	resident_ids: Array,
	prefetch_cells: float,
	eviction_cells: float,
	cap: int
) -> Dictionary:
	var distances := seam_neighbor_distances(layout, owner_id, global_position)
	var candidates: Array[StringName] = []
	for neighbor_value in distances.keys():
		var neighbor_id := StringName(neighbor_value)
		var distance := float(distances[neighbor_id])
		# Hysteresis: an already resident neighbour survives until the wider band.
		var band := eviction_cells if resident_ids.has(neighbor_id) else prefetch_cells
		if distance <= band:
			candidates.append(neighbor_id)
	candidates.sort_custom(
		func(left: StringName, right: StringName) -> bool:
			var left_distance := float(distances[left])
			var right_distance := float(distances[right])
			if not is_equal_approx(left_distance, right_distance):
				return left_distance < right_distance
			return String(left) < String(right)
	)
	var desired: Array[StringName] = []
	if not owner_id.is_empty():
		desired.append(owner_id)
	for neighbor_id in candidates:
		if desired.size() >= maxi(cap, 1):
			break
		desired.append(neighbor_id)
	var mount: Array[StringName] = []
	for location_id in desired:
		if not resident_ids.has(location_id):
			mount.append(location_id)
	var evict: Array[StringName] = []
	for resident_value in resident_ids:
		var resident_id := StringName(resident_value)
		if not desired.has(resident_id):
			evict.append(resident_id)
	evict.sort_custom(
		func(left: StringName, right: StringName) -> bool: return String(left) < String(right)
	)
	return {
		"owner": owner_id,
		"desired": desired,
		"mount": mount,
		"evict": evict,
		"distances": distances,
	}


## Distance in cells from `global_position` to each seam edge `owner_id` shares
## with a neighbour (the closest edge when two locations share several seams).
static func seam_neighbor_distances(
	layout: Dictionary, owner_id: StringName, global_position: Vector2
) -> Dictionary:
	var bounds_by_id: Dictionary = {}
	var cell_size := 0
	for entry_value in layout.get("locations", []):
		var entry: Dictionary = entry_value as Dictionary
		bounds_by_id[StringName(entry.get("location_id", ""))] = entry.get("global_bounds", Rect2())
		cell_size = int(entry.get("cell_size", cell_size))
	var distances: Dictionary = {}
	if cell_size <= 0 or not bounds_by_id.has(owner_id):
		return distances
	for seam_value in layout.get("seams", []):
		var seam: Dictionary = seam_value as Dictionary
		var neighbor_id: StringName = &""
		if seam.get("base_map_id", &"") == owner_id:
			neighbor_id = StringName(seam.get("neighbor_map_id", &""))
		elif seam.get("neighbor_map_id", &"") == owner_id:
			neighbor_id = StringName(seam.get("base_map_id", &""))
		if neighbor_id.is_empty() or not bounds_by_id.has(neighbor_id):
			continue
		# The two rects touch along the seam; growing both by a pixel turns that
		# shared edge into a thin rect, whatever the side.
		var edge := (bounds_by_id[owner_id] as Rect2).grow(1.0).intersection(
			(bounds_by_id[neighbor_id] as Rect2).grow(1.0)
		)
		if edge.size == Vector2.ZERO:
			continue
		var closest := global_position.clamp(edge.position, edge.end)
		var distance := global_position.distance_to(closest) / float(cell_size)
		if not distances.has(neighbor_id) or distance < float(distances[neighbor_id]):
			distances[neighbor_id] = distance
	return distances
