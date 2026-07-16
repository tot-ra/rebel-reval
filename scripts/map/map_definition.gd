class_name MapDefinition
extends RefCounted

## Declarative map data used by MapBuilder. Zones are applied in array order.

var map_id: StringName = &""
var seed: int = MapTypes.DEFAULT_SEED
var cell_size: int = MapTypes.DEFAULT_CELL_SIZE
var size_cells: Vector2i = Vector2i.ZERO
var base_terrain: StringName = MapTypes.TERRAIN_GRASS
var zones: Array[Dictionary] = []
var buildings: Array[Dictionary] = []
var props: Array[Dictionary] = []
var player_spawn: Vector2 = Vector2.ZERO


func cell_rect_to_world_rect(cell_rect: Rect2i) -> Rect2:
	var pixel_size := Vector2(float(cell_size), float(cell_size))
	return Rect2(Vector2(cell_rect.position) * pixel_size, Vector2(cell_rect.size) * pixel_size)


func cell_rect_center(cell_rect: Rect2i) -> Vector2:
	var world_rect := cell_rect_to_world_rect(cell_rect)
	return world_rect.position + world_rect.size * 0.5


func validate() -> Array[String]:
	var errors: Array[String] = []

	if map_id.is_empty():
		errors.append("map_id is required")
	if cell_size <= 0:
		errors.append("cell_size must be positive")
	if size_cells.x <= 0 or size_cells.y <= 0:
		errors.append("size_cells must be positive")

	if not MapTypes.ALL_TERRAINS.has(base_terrain):
		errors.append("unknown base_terrain: %s" % String(base_terrain))

	for index in zones.size():
		errors.append_array(_validate_zone(zones[index], index))

	var seen_ids: Dictionary = {}
	for index in buildings.size():
		errors.append_array(_validate_building(buildings[index], index, seen_ids))

	for index in props.size():
		errors.append_array(_validate_prop(props[index], index, seen_ids))

	if player_spawn == Vector2.ZERO:
		errors.append("player_spawn must be set")
	elif not _point_inside_world_pixels(player_spawn):
		errors.append("player_spawn is outside world bounds")

	return errors


func world_size() -> Vector2:
	return Vector2(float(size_cells.x * cell_size), float(size_cells.y * cell_size))


func _validate_zone(zone: Dictionary, index: int) -> Array[String]:
	var errors: Array[String] = []
	var prefix := "zones[%d]" % index

	if not zone.has("rect") or not zone["rect"] is Rect2i:
		errors.append("%s.rect must be Rect2i" % prefix)
		return errors

	var terrain: Variant = zone.get("terrain", &"")
	if not MapTypes.ALL_TERRAINS.has(terrain):
		errors.append("%s.terrain is unknown: %s" % [prefix, str(terrain)])

	var rect: Rect2i = zone["rect"]
	if rect.size.x <= 0 or rect.size.y <= 0:
		errors.append("%s.rect must have positive size" % prefix)
	elif not _rect_inside_bounds(rect):
		errors.append("%s.rect is outside world bounds" % prefix)

	return errors


func _validate_building(building: Dictionary, index: int, seen_ids: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var prefix := "buildings[%d]" % index

	if not building.has("id") or String(building["id"]).is_empty():
		errors.append("%s.id is required" % prefix)
	else:
		var building_id: StringName = building["id"]
		if seen_ids.has(building_id):
			errors.append("duplicate stable id: %s" % String(building_id))
		seen_ids[building_id] = true

	var kind: Variant = building.get("kind", MapTypes.BUILDING_KIND_HOUSE)
	if not MapTypes.ALL_BUILDING_KINDS.has(kind):
		errors.append("%s.kind is unknown: %s" % [prefix, str(kind)])

	if not building.has("footprint") or not building["footprint"] is Rect2:
		errors.append("%s.footprint must be Rect2" % prefix)
		return errors

	var footprint: Rect2 = building["footprint"]
	if footprint.size.x <= 0.0 or footprint.size.y <= 0.0:
		errors.append("%s.footprint must have positive size" % prefix)
	if not _rect_inside_world_pixels(footprint):
		errors.append("%s.footprint is outside world bounds" % prefix)

	return errors


func _validate_prop(prop: Dictionary, index: int, seen_ids: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var prefix := "props[%d]" % index

	if not prop.has("id") or String(prop["id"]).is_empty():
		errors.append("%s.id is required" % prefix)
	else:
		var prop_id: StringName = prop["id"]
		if seen_ids.has(prop_id):
			errors.append("duplicate stable id: %s" % String(prop_id))
		seen_ids[prop_id] = true

	if not prop.has("kind") or String(prop["kind"]).is_empty():
		errors.append("%s.kind is required" % prefix)
	elif not MapTypes.ALL_PROP_KINDS.has(prop["kind"]):
		errors.append("%s.kind is unknown: %s" % [prefix, str(prop["kind"])])

	if not prop.has("position") or not prop["position"] is Vector2:
		errors.append("%s.position must be Vector2" % prefix)
	elif not _point_inside_world_pixels(prop["position"]):
		errors.append("%s.position is outside world bounds" % prefix)

	return errors


func _rect_inside_bounds(rect: Rect2i) -> bool:
	return rect.position.x >= 0 \
		and rect.position.y >= 0 \
		and rect.end.x <= size_cells.x \
		and rect.end.y <= size_cells.y


func _rect_inside_world_pixels(rect: Rect2) -> bool:
	var world := world_size()
	return rect.position.x >= 0.0 \
		and rect.position.y >= 0.0 \
		and rect.end.x <= world.x \
		and rect.end.y <= world.y


func _point_inside_world_pixels(point: Vector2) -> bool:
	var world := world_size()
	return point.x >= 0.0 \
		and point.y >= 0.0 \
		and point.x <= world.x \
		and point.y <= world.y
