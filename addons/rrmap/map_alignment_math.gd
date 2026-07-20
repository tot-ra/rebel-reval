@tool
class_name MapAlignmentMath
extends RefCounted

## Pure alignment helpers shared by the editor workspace and headless tests.
## Offsets are expressed in world pixels because compiled MapDefinition geometry
## uses pixels even though authors edit integer cells in .rrmap sources.

const SIDES: Array[StringName] = [&"north", &"south", &"east", &"west"]


static func find_transition_pairs(base: MapDefinition, neighbor: MapDefinition) -> Array[Dictionary]:
	var pairs: Array[Dictionary] = []
	if base == null or neighbor == null:
		return pairs
	for base_transition in base.transitions:
		for neighbor_transition in neighbor.transitions:
			# Long-distance roads remain reciprocal gameplay transitions but must not
			# pull non-touching maps together in the physical district layout.
			if base_transition.get("alignment", &"edge") == &"travel" \
			or neighbor_transition.get("alignment", &"edge") == &"travel":
				continue
			var base_spawn := StringName(base_transition.get("spawn_id", &""))
			var base_destination := StringName(base_transition.get("destination_spawn_id", &""))
			var neighbor_spawn := StringName(neighbor_transition.get("spawn_id", &""))
			var neighbor_destination := StringName(neighbor_transition.get("destination_spawn_id", &""))
			if base_spawn.is_empty() or base_destination.is_empty():
				continue
			if base_destination != neighbor_spawn or base_spawn != neighbor_destination:
				continue
			pairs.append({
				"base": base_transition,
				"neighbor": neighbor_transition,
				"base_side": transition_side(base, base_transition),
				"neighbor_side": transition_side(neighbor, neighbor_transition),
			})
	pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["base"]["id"]) < String(b["base"]["id"])
	)
	return pairs


static func layout_connected_maps(
	definitions: Array[MapDefinition],
	root_map_id: StringName = &""
) -> Dictionary:
	var by_id: Dictionary = {}
	for definition in definitions:
		if definition != null:
			by_id[definition.map_id] = definition
	if by_id.is_empty():
		return {"offsets": {}, "seams": [], "unplaced": []}

	var root_id := root_map_id if by_id.has(root_map_id) else StringName(by_id.keys()[0])
	var offsets: Dictionary = {root_id: Vector2.ZERO}
	var seams: Array[Dictionary] = []
	var seam_keys: Dictionary = {}
	var queue: Array[StringName] = [root_id]
	while not queue.is_empty():
		var base_id := queue.pop_front()
		var base: MapDefinition = by_id[base_id]
		for neighbor_id_value in by_id.keys():
			var neighbor_id := StringName(neighbor_id_value)
			if neighbor_id == base_id:
				continue
			var neighbor: MapDefinition = by_id[neighbor_id]
			for pair in find_transition_pairs(base, neighbor):
				var seam_key := _seam_key(base_id, pair["base"]["id"], neighbor_id, pair["neighbor"]["id"])
				if not seam_keys.has(seam_key):
					seam_keys[seam_key] = true
					seams.append({
						"base_map_id": base_id,
						"neighbor_map_id": neighbor_id,
						"base": pair["base"],
						"neighbor": pair["neighbor"],
						"base_side": pair["base_side"],
						"neighbor_side": pair["neighbor_side"],
						"base_span_cells": seam_span_cells(base, pair["base"], pair["base_side"]),
						"neighbor_span_cells": seam_span_cells(neighbor, pair["neighbor"], pair["neighbor_side"]),
					})
				if offsets.has(neighbor_id):
					continue
				offsets[neighbor_id] = Vector2(offsets[base_id]) + aligned_neighbor_offset(
					base, neighbor, pair["base"], pair["neighbor"]
				)
				queue.append(neighbor_id)

	var unplaced: Array[StringName] = []
	for map_id_value in by_id.keys():
		var map_id := StringName(map_id_value)
		if not offsets.has(map_id):
			unplaced.append(map_id)
	unplaced.sort()
	return {"offsets": offsets, "seams": seams, "unplaced": unplaced}


static func layout_all_maps(
	definitions: Array[MapDefinition],
	root_map_id: StringName = &""
) -> Dictionary:
	var result := layout_connected_maps(definitions, root_map_id)
	var offsets: Dictionary = result["offsets"]
	var unplaced: Array = result["unplaced"]
	if unplaced.is_empty():
		return result

	# Disconnected interiors/prototypes remain visible in a separate shelf below
	# the connected city graph rather than silently disappearing from Load all.
	var bounds := _layout_bounds(definitions, offsets)
	var shelf_x := bounds.position.x
	var shelf_y := bounds.end.y + 8.0 * float(MapTypes.DEFAULT_CELL_SIZE)
	for map_id in unplaced:
		var definition := _definition_by_id(definitions, map_id)
		if definition == null:
			continue
		offsets[map_id] = Vector2(shelf_x, shelf_y)
		shelf_x += definition.world_size().x + 8.0 * float(definition.cell_size)
	result["offsets"] = offsets
	return result


static func _seam_key(
	first_map_id: StringName,
	first_transition_id: StringName,
	second_map_id: StringName,
	second_transition_id: StringName
) -> String:
	var first := "%s/%s" % [first_map_id, first_transition_id]
	var second := "%s/%s" % [second_map_id, second_transition_id]
	return "%s|%s" % [first, second] if first < second else "%s|%s" % [second, first]


static func _layout_bounds(definitions: Array[MapDefinition], offsets: Dictionary) -> Rect2:
	var result := Rect2()
	var has_bounds := false
	for definition in definitions:
		if definition == null or not offsets.has(definition.map_id):
			continue
		var bounds := Rect2(Vector2(offsets[definition.map_id]), definition.world_size())
		result = result.merge(bounds) if has_bounds else bounds
		has_bounds = true
	return result


static func _definition_by_id(
	definitions: Array[MapDefinition],
	map_id: StringName
) -> MapDefinition:
	for definition in definitions:
		if definition != null and definition.map_id == map_id:
			return definition
	return null


static func transition_side(definition: MapDefinition, transition: Dictionary) -> StringName:
	if definition == null or not transition.get("rect") is Rect2:
		return &""
	var rect: Rect2 = transition["rect"]
	var world_size := definition.world_size()
	var distances := {
		&"north": absf(rect.position.y),
		&"south": absf(world_size.y - rect.end.y),
		&"west": absf(rect.position.x),
		&"east": absf(world_size.x - rect.end.x),
	}
	var result: StringName = &"north"
	var best := INF
	for side in SIDES:
		var distance := float(distances[side])
		if distance < best:
			best = distance
			result = side
	return result


static func aligned_neighbor_offset(
	base: MapDefinition,
	neighbor: MapDefinition,
	base_transition: Dictionary,
	neighbor_transition: Dictionary
) -> Vector2:
	if base == null or neighbor == null:
		return Vector2.ZERO
	var base_rect: Rect2 = base_transition.get("rect", Rect2())
	var neighbor_rect: Rect2 = neighbor_transition.get("rect", Rect2())
	var base_side := transition_side(base, base_transition)
	var neighbor_side := transition_side(neighbor, neighbor_transition)
	var base_center := base_rect.get_center()
	var neighbor_center := neighbor_rect.get_center()

	# Opposite boundary edges touch while transition centers remain aligned on the
	# seam's other axis. This exposes mismatched streets and wall openings instead
	# of hiding them by overlapping both transition rectangles.
	match base_side:
		&"north":
			if neighbor_side == &"south":
				return Vector2(base_center.x - neighbor_center.x, -neighbor.world_size().y)
		&"south":
			if neighbor_side == &"north":
				return Vector2(base_center.x - neighbor_center.x, base.world_size().y)
		&"west":
			if neighbor_side == &"east":
				return Vector2(-neighbor.world_size().x, base_center.y - neighbor_center.y)
		&"east":
			if neighbor_side == &"west":
				return Vector2(base.world_size().x, base_center.y - neighbor_center.y)

	# Invalid or unusual same-side links remain inspectable by aligning centers.
	return base_center - neighbor_center


static func seam_span_cells(
	definition: MapDefinition,
	transition: Dictionary,
	side: StringName
) -> float:
	if definition == null or definition.cell_size <= 0:
		return 0.0
	var rect: Rect2 = transition.get("rect", Rect2())
	var span_px := rect.size.x if side in [&"north", &"south"] else rect.size.y
	return span_px / float(definition.cell_size)


static func offset_in_neighbor_cells(neighbor: MapDefinition, offset_px: Vector2) -> Vector2:
	if neighbor == null or neighbor.cell_size <= 0:
		return Vector2.ZERO
	return offset_px / float(neighbor.cell_size)
