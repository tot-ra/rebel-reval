class_name MapBuildingEntrance
extends RefCounted

## Resolves a functional transition onto a building facade without changing the
## transition trigger used by 2D navigation. WHY: approach areas need room for
## the player, while the visible door must stay physically attached to the wall.

const MAX_APPROACH_DISTANCE_CELLS := 4.0
const CARDINAL_SIDES: Array[StringName] = [&"north", &"south", &"east", &"west"]


static func find_building(definition, transition: Dictionary) -> Dictionary:
	if definition == null:
		return {}
	var building_id := StringName(String(transition.get("building_id", "")))
	if building_id.is_empty():
		return {}
	for building in definition.buildings:
		if building.get("id", &"") == building_id:
			return building
	return {}


static func attachment_side(building: Dictionary, transition: Dictionary) -> StringName:
	if building.is_empty() or not building.get("footprint") is Rect2:
		return &""
	var footprint: Rect2 = building["footprint"]
	var rect: Rect2 = transition.get("rect", Rect2())
	var center := rect.get_center()

	# Prefer the side the approach trigger sits beyond. This remains stable for
	# roomy yard triggers whose center may be closer to a neighboring corner.
	if rect.position.y >= footprint.end.y:
		return &"south"
	if rect.end.y <= footprint.position.y:
		return &"north"
	if rect.position.x >= footprint.end.x:
		return &"east"
	if rect.end.x <= footprint.position.x:
		return &"west"

	var authored_side := StringName(String(building.get("door_side", "")))
	if CARDINAL_SIDES.has(authored_side):
		return authored_side

	var distances := {
		&"north": absf(center.y - footprint.position.y),
		&"south": absf(center.y - footprint.end.y),
		&"west": absf(center.x - footprint.position.x),
		&"east": absf(center.x - footprint.end.x),
	}
	var side: StringName = &"north"
	for candidate in CARDINAL_SIDES:
		if float(distances[candidate]) < float(distances[side]):
			side = candidate
	return side


static func facade_position(building: Dictionary, transition: Dictionary) -> Vector2:
	if building.is_empty() or not building.get("footprint") is Rect2:
		return Vector2.ZERO
	var footprint: Rect2 = building["footprint"]
	var center: Vector2 = transition.get("rect", Rect2()).get_center()
	match attachment_side(building, transition):
		&"north":
			return Vector2(clampf(center.x, footprint.position.x, footprint.end.x), footprint.position.y)
		&"south":
			return Vector2(clampf(center.x, footprint.position.x, footprint.end.x), footprint.end.y)
		&"east":
			return Vector2(footprint.end.x, clampf(center.y, footprint.position.y, footprint.end.y))
		&"west":
			return Vector2(footprint.position.x, clampf(center.y, footprint.position.y, footprint.end.y))
	return footprint.get_center()


static func facade_along_world(
	building: Dictionary,
	transition: Dictionary,
	cell_size: int
) -> float:
	var footprint: Rect2 = building.get("footprint", Rect2())
	var position := facade_position(building, transition)
	var center := footprint.get_center()
	var scale := MapViewBridge.world_scale(cell_size)
	var side := attachment_side(building, transition)
	return (position.x - center.x) * scale if side in [&"north", &"south"] else (position.y - center.y) * scale


static func approach_aligns_with_facade(
	building: Dictionary,
	transition: Dictionary,
	cell_size: int
) -> bool:
	if building.is_empty() or not building.get("footprint") is Rect2:
		return false
	var footprint: Rect2 = building["footprint"]
	var rect: Rect2 = transition.get("rect", Rect2())
	var side := attachment_side(building, transition)
	var overlaps_facade := false
	var gap := INF
	match side:
		&"north":
			overlaps_facade = rect.end.x > footprint.position.x and rect.position.x < footprint.end.x
			gap = maxf(0.0, footprint.position.y - rect.end.y)
		&"south":
			overlaps_facade = rect.end.x > footprint.position.x and rect.position.x < footprint.end.x
			gap = maxf(0.0, rect.position.y - footprint.end.y)
		&"east":
			overlaps_facade = rect.end.y > footprint.position.y and rect.position.y < footprint.end.y
			gap = maxf(0.0, rect.position.x - footprint.end.x)
		&"west":
			overlaps_facade = rect.end.y > footprint.position.y and rect.position.y < footprint.end.y
			gap = maxf(0.0, footprint.position.x - rect.end.x)
	return overlaps_facade and gap <= float(cell_size) * MAX_APPROACH_DISTANCE_CELLS
