class_name MapBlueprintCompilerExpandTerrain
extends RefCounted

## Terrain primitive expansion for MapBlueprintCompilerExpand.


static func expand_terrain_rects(
	object_id: StringName, style_id: StringName, data: Dictionary, style: Dictionary, inline: Dictionary,
	blueprint: MapBlueprint, path: String, expanded: Dictionary, global: Dictionary, errors: Array[String]
) -> void:
	var values := MapBlueprintCompilerExpand.resolved_values(object_id, data, style, inline, global, MapBlueprintCompiler.TERRAIN_KEYS, path, errors)
	MapBlueprintCompilerExpand.register_id(object_id, path, expanded, errors)
	if not MapTypes.ALL_TERRAINS.has(values.get("terrain", &"")):
		errors.append("%s terrain is unknown: %s" % [path, str(values.get("terrain", ""))])
	var style_variant := TerrainVegetation.resolved_variant(style_id, values)
	if not TerrainVegetation.is_known_variant(style_variant):
		errors.append("%s style_variant is unknown: %s" % [path, String(style_variant)])
	var rects: Variant = data.get("rects")
	if not rects is Array or rects.is_empty():
		errors.append("%s.rects must be a non-empty Array[Rect2i]" % path)
		return
	var sorted_rects: Array = rects.duplicate()
	sorted_rects.sort_custom(MapBlueprintCompiler._compare_rects)
	for fragment_index in sorted_rects.size():
		var rect: Variant = sorted_rects[fragment_index]
		if not rect is Rect2i:
			errors.append("%s.rects[%d] must be Rect2i" % [path, fragment_index])
			continue
		if values.has("rect") and sorted_rects.size() == 1:
			rect = values["rect"]
		MapBlueprintCompiler._validate_rect(rect, "%s.rects[%d]" % [path, fragment_index], blueprint.size_cells, errors)
		var entry := {
			"source_id": object_id,
			"terrain": values.get("terrain", &""),
			"rect": rect,
			"layer": int(data.get("layer", 0)),
			"order": int(data.get("order", 0)),
			"fragment": fragment_index,
		}
		if not style_variant.is_empty():
			entry["style_variant"] = style_variant
		if values.has("movement_speed_multiplier"):
			entry["movement_speed_multiplier"] = float(values["movement_speed_multiplier"])
		expanded["terrain"].append(entry)


static func expand_terrain_stroke(
	object_id: StringName, style_id: StringName, data: Dictionary, style: Dictionary, inline: Dictionary,
	blueprint: MapBlueprint, path: String, expanded: Dictionary, global: Dictionary, errors: Array[String]
) -> void:
	var values := MapBlueprintCompilerExpand.resolved_values(object_id, data, style, inline, global, MapBlueprintCompiler.TERRAIN_KEYS, path, errors)
	MapBlueprintCompilerExpand.register_id(object_id, path, expanded, errors)
	if not MapTypes.ALL_TERRAINS.has(values.get("terrain", &"")):
		errors.append("%s terrain is unknown: %s" % [path, str(values.get("terrain", ""))])
	var style_variant := TerrainVegetation.resolved_variant(style_id, values)
	if not TerrainVegetation.is_known_variant(style_variant):
		errors.append("%s style_variant is unknown: %s" % [path, String(style_variant)])
	var points: Variant = data.get("points")
	var thickness := int(data.get("thickness", 0))
	if not points is Array or points.size() < 2:
		errors.append("%s.points must contain at least two Vector2i points" % path)
		return
	if thickness <= 0:
		errors.append("%s.thickness must be positive" % path)
		return
	for point_index in points.size():
		if not points[point_index] is Vector2i:
			errors.append("%s.points[%d] must be Vector2i" % [path, point_index])
			return
	for index in points.size() - 1:
		var start: Vector2i = points[index]
		var finish: Vector2i = points[index + 1]
		if start == finish or (start.x != finish.x and start.y != finish.y):
			errors.append("%s segment %d must be non-zero and orthogonal: %s -> %s" % [path, index, start, finish])
			continue
		var rect: Rect2i
		if start.y == finish.y:
			rect = Rect2i(mini(start.x, finish.x), start.y, absi(finish.x - start.x) + 1, thickness)
		else:
			rect = Rect2i(start.x, mini(start.y, finish.y), thickness, absi(finish.y - start.y) + 1)
		MapBlueprintCompiler._validate_rect(rect, "%s.segment[%d]" % [path, index], blueprint.size_cells, errors)
		var entry := {
			"source_id": object_id,
			"terrain": values.get("terrain", &""),
			"rect": rect,
			"layer": int(data.get("layer", 0)),
			"order": int(data.get("order", 0)),
			"fragment": index,
		}
		if not style_variant.is_empty():
			entry["style_variant"] = style_variant
		if values.has("movement_speed_multiplier"):
			entry["movement_speed_multiplier"] = float(values["movement_speed_multiplier"])
		expanded["terrain"].append(entry)
