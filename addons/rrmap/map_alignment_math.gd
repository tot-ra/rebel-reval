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
