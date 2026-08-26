class_name MapWorldLayout
extends RefCounted

## Runtime-neutral global layout contract for a contiguous group of maps.
## Authored map coordinates remain local; origins and seams are derived once from
## reciprocal physical transitions so load order cannot invent world placement.

const DEFAULT_WORLD_GROUP_ID := &"reval_outdoor"
const LOCATION_KIND_OUTDOOR := &"outdoor_streamed"
const LOCATION_KIND_TRAVEL := &"travel"
const EPSILON := 0.001
const OPPOSITE_SIDES := {
	&"north": &"south",
	&"south": &"north",
	&"east": &"west",
	&"west": &"east",
}


static func build(
	definitions: Array[MapDefinition],
	root_map_id: StringName = &"",
	world_group_id: StringName = DEFAULT_WORLD_GROUP_ID
) -> Dictionary:
	var layout := MapAlignmentMath.layout_connected_maps(definitions, root_map_id)
	var by_id := _definitions_by_id(definitions)
	var errors: Array[String] = []
	var locations: Array[Dictionary] = []
	var seen_map_ids: Dictionary = {}

	if by_id.is_empty():
		errors.append("world layout requires at least one map")
	if world_group_id.is_empty():
		errors.append("world_group_id is required")
	for definition in definitions:
		if definition == null:
			errors.append("world layout cannot contain a null map")
			continue
		var declared_map_id: StringName = definition.map_id
		if declared_map_id.is_empty():
			errors.append("world layout map_id is required")
		elif seen_map_ids.has(declared_map_id):
			errors.append("duplicate world layout map_id: %s" % String(declared_map_id))
		else:
			seen_map_ids[declared_map_id] = true

	for map_id_value in by_id.keys():
		var map_id := StringName(map_id_value)
		var definition: MapDefinition = by_id[map_id]
		if definition.cell_size != MapTypes.DEFAULT_CELL_SIZE:
			errors.append(
				"location %s has cell_size %d; contiguous groups require the default cell_size %d"
				% [String(map_id), definition.cell_size, MapTypes.DEFAULT_CELL_SIZE]
			)
		if not layout["offsets"].has(map_id):
			errors.append("location %s has no deterministic global origin" % String(map_id))
			continue
		var origin_px := Vector2(layout["offsets"][map_id])
		locations.append({
			"world_group_id": StringName(world_group_id),
			"location_id": map_id,
			"origin_cell": _pixel_to_cell(origin_px, definition.cell_size),
			"cell_size": definition.cell_size,
			"size_cells": definition.size_cells,
			"global_bounds": Rect2(origin_px, definition.world_size()),
			"map_fingerprint": definition.fingerprint,
		})

	locations.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left["location_id"]) < String(right["location_id"])
	)

	var seams: Array[Dictionary] = []
	for seam in layout["seams"]:
		var seam_result := _validate_seam(seam, by_id, layout["offsets"], world_group_id)
		errors.append_array(seam_result["errors"])
		if seam_result["record"].is_empty():
			continue
		seams.append(seam_result["record"])
	seams.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left["id"]) < String(right["id"])
	)

	errors.append_array(_validate_overlaps(locations, seams))
	errors.sort()
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"world_group_id": StringName(world_group_id),
		"locations": locations,
		"seams": seams,
		"unplaced": layout["unplaced"].duplicate(),
	}


static func location(result: Dictionary, map_id: StringName) -> Dictionary:
	for candidate in result.get("locations", []):
		if candidate.get("location_id", &"") == map_id:
			return (candidate as Dictionary).duplicate(true)
	return {}


static func global_cell(result: Dictionary, map_id: StringName, local_cell: Vector2i) -> Vector2i:
	var entry := location(result, map_id)
	if entry.is_empty():
		return local_cell
	return Vector2i(entry["origin_cell"]) + local_cell


static func location_at_global_cell(result: Dictionary, global_cell: Vector2i) -> StringName:
	for entry in result.get("locations", []):
		var origin_cell := Vector2i(entry["origin_cell"])
		var size_cells := Vector2i(entry["size_cells"])
		var local := global_cell - origin_cell
		if (
			local.x >= 0
			and local.y >= 0
			and local.x < size_cells.x
			and local.y < size_cells.y
		):
			return StringName(entry["location_id"])
	return &""


static func _definitions_by_id(definitions: Array[MapDefinition]) -> Dictionary:
	var by_id: Dictionary = {}
	for definition in definitions:
		if definition == null:
			continue
		var map_id: StringName = definition.map_id
		if by_id.has(map_id):
			# Keep the first deterministic input and surface the duplicate as an error
			# through the normal map-id validation below rather than overwriting it.
			continue
		by_id[map_id] = definition
	return by_id


static func _pixel_to_cell(position: Vector2, cell_size: int) -> Vector2i:
	return Vector2i(
		roundi(position.x / float(cell_size)),
		roundi(position.y / float(cell_size))
	)


static func _validate_seam(
	seam: Dictionary,
	by_id: Dictionary,
	offsets: Dictionary,
	world_group_id: StringName
) -> Dictionary:
	var errors: Array[String] = []
	var base_id: StringName = seam["base_map_id"]
	var neighbor_id: StringName = seam["neighbor_map_id"]
	var base: MapDefinition = by_id[base_id]
	var neighbor: MapDefinition = by_id[neighbor_id]
	var base_side: StringName = seam["base_side"]
	var neighbor_side: StringName = seam["neighbor_side"]
	var seam_id := "%s/%s|%s/%s" % [base_id, seam["base"]["id"], neighbor_id, seam["neighbor"]["id"]]

	if base_side.is_empty() or neighbor_side.is_empty():
		errors.append("seam %s has no boundary side" % seam_id)
	elif OPPOSITE_SIDES.get(base_side, &"") != neighbor_side:
		errors.append("seam %s must use opposite boundary sides" % seam_id)
	if base.cell_size != neighbor.cell_size:
		errors.append("seam %s has mismatched cell sizes" % seam_id)
	if not is_equal_approx(float(seam["base_span_cells"]), float(seam["neighbor_span_cells"])):
		errors.append("seam %s has mismatched transition spans" % seam_id)

	var expected_offset := Vector2(offsets[base_id]) + MapAlignmentMath.aligned_neighbor_offset(
		base, neighbor, seam["base"], seam["neighbor"]
	)
	var actual_offset := Vector2(offsets[neighbor_id])
	if not (
		is_equal_approx(actual_offset.x, expected_offset.x)
		and is_equal_approx(actual_offset.y, expected_offset.y)
	):
		errors.append("seam %s has a conflicting global origin" % seam_id)

	var record := {
		"id": seam_id,
		"world_group_id": world_group_id,
		"base_map_id": base_id,
		"neighbor_map_id": neighbor_id,
		"base_transition_id": seam["base"]["id"],
		"neighbor_transition_id": seam["neighbor"]["id"],
		"base_side": base_side,
		"neighbor_side": neighbor_side,
		"span_cells": float(seam["base_span_cells"]),
		"alignment": &"physical",
	}
	return {"errors": errors, "record": record}


static func _validate_overlaps(locations: Array[Dictionary], seams: Array[Dictionary]) -> Array[String]:
	var errors: Array[String] = []
	for first_index in locations.size():
		var first: Dictionary = locations[first_index]
		var first_bounds: Rect2 = first["global_bounds"]
		for second_index in range(first_index + 1, locations.size()):
			var second: Dictionary = locations[second_index]
			var second_bounds: Rect2 = second["global_bounds"]
			if not first_bounds.intersects(second_bounds, false):
				continue
			if _locations_share_seam(first["location_id"], second["location_id"], seams):
				# A physical seam may touch at one edge, but never overlap by area.
				var overlap := first_bounds.intersection(second_bounds)
				if overlap.size.x <= EPSILON or overlap.size.y <= EPSILON:
					continue
			errors.append(
				"locations %s and %s overlap in global bounds"
				% [first["location_id"], second["location_id"]]
			)
	return errors


static func _locations_share_seam(first_id: StringName, second_id: StringName, seams: Array[Dictionary]) -> bool:
	for seam in seams:
		if (
			(seam["base_map_id"] == first_id and seam["neighbor_map_id"] == second_id)
			or (seam["base_map_id"] == second_id and seam["neighbor_map_id"] == first_id)
		):
			return true
	return false
