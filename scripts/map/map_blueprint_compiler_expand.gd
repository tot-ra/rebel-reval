class_name MapBlueprintCompilerExpand
extends RefCounted

## Primitive expansion from authored MapBlueprint cells into compiler buckets.


static func expand_primitives(
	blueprint: MapBlueprint,
	styles: Dictionary,
	global_overrides: Dictionary,
	errors: Array[String],
	prefab_expansion: Dictionary = {"primitives": [], "instance_ids": {}}
) -> Dictionary:
	var expanded := {
		"terrain": [],
		"buildings": [],
		"props": [],
		"spawns": [],
		"transitions": [],
		"anchors": [],
		"patrols": [],
		"exclusions": [],
		"fades": [],
		"signs": [],
		"landmarks": [],
		"resolved_ids": {},
	}
	var source_ids: Dictionary = prefab_expansion.get("instance_ids", {}).duplicate()
	var all_primitives: Array = blueprint.primitives.duplicate()
	all_primitives.append_array(prefab_expansion.get("primitives", []))
	for index in all_primitives.size():
		var primitive: Dictionary = all_primitives[index]
		var path := "primitives[%d]" % index
		var primitive_kind: StringName = primitive.get("primitive", &"")
		var primitive_id: StringName = primitive.get("id", &"")
		var is_prefab_expanded := bool(primitive.get("prefab_expanded", false))
		MapBlueprintCompiler._validate_id(primitive_id, "%s.id" % path, is_prefab_expanded, errors)
		if source_ids.has(primitive_id):
			errors.append("%s duplicates source id: %s" % [path, String(primitive_id)])
		else:
			source_ids[primitive_id] = true
		var data: Variant = primitive.get("data")
		if not data is Dictionary:
			errors.append("%s.data must be Dictionary" % path)
			continue
		var style_id: StringName = primitive.get("style", &"")
		var style_values: Dictionary = {}
		if not style_id.is_empty():
			if not styles.has(style_id):
				errors.append("%s references unknown style: %s" % [path, String(style_id)])
			else:
				style_values = styles[style_id]
		var inline_overrides: Variant = primitive.get("overrides", {})
		if not inline_overrides is Dictionary:
			errors.append("%s.overrides must be Dictionary" % path)
			inline_overrides = {}

		match primitive_kind:
			&"terrain_rect", &"terrain_rects":
				_expand_terrain_rects(primitive_id, style_id, data, style_values, inline_overrides, blueprint, path, expanded, global_overrides, errors)
			&"terrain_stroke":
				_expand_terrain_stroke(primitive_id, style_id, data, style_values, inline_overrides, blueprint, path, expanded, global_overrides, errors)
			&"structure_rect":
				_expand_structure(primitive_id, data, style_values, inline_overrides, blueprint, path, expanded, global_overrides, errors)
			&"wall_run":
				_expand_wall(primitive_id, data, style_values, inline_overrides, blueprint, path, expanded, global_overrides, errors)
			&"placement_row":
				_expand_row(primitive_id, data, style_values, blueprint, path, expanded, global_overrides, errors)
			&"prop":
				_expand_prop(primitive_id, data, style_values, inline_overrides, blueprint, path, expanded, global_overrides, errors)
			&"player_spawn":
				_expand_point_record(&"spawn", primitive_id, data, style_values, inline_overrides, MapBlueprintCompiler.SPAWN_KEYS, blueprint, path, expanded["spawns"], expanded, global_overrides, errors)
			&"transition":
				_expand_rect_record(&"transition", primitive_id, data, style_values, inline_overrides, MapBlueprintCompiler.TRANSITION_KEYS, blueprint, path, expanded["transitions"], expanded, global_overrides, errors)
			&"interaction_anchor":
				_expand_point_record(&"anchor", primitive_id, data, style_values, inline_overrides, MapBlueprintCompiler.ANCHOR_KEYS, blueprint, path, expanded["anchors"], expanded, global_overrides, errors)
			&"patrol_path":
				_expand_patrol(primitive_id, data, style_values, inline_overrides, blueprint, path, expanded, global_overrides, errors)
			&"excluded_rect":
				_expand_rect_record(&"exclusion", primitive_id, data, style_values, inline_overrides, MapBlueprintCompiler.RECT_KEYS, blueprint, path, expanded["exclusions"], expanded, global_overrides, errors)
			&"fade_rect":
				_expand_rect_record(&"fade", primitive_id, data, style_values, inline_overrides, MapBlueprintCompiler.RECT_KEYS, blueprint, path, expanded["fades"], expanded, global_overrides, errors)
			&"direction_sign":
				_expand_sign(primitive_id, data, style_values, inline_overrides, blueprint, path, expanded, global_overrides, errors)
			&"view_landmark":
				_expand_rect_record(&"landmark", primitive_id, data, style_values, inline_overrides, MapBlueprintCompiler.LANDMARK_OVERRIDE_KEYS, blueprint, path, expanded["landmarks"], expanded, global_overrides, errors)
			_:
				errors.append("%s has unknown primitive kind: %s" % [path, String(primitive_kind)])
	return expanded


static func _expand_terrain_rects(
	object_id: StringName, style_id: StringName, data: Dictionary, style: Dictionary, inline: Dictionary,
	blueprint: MapBlueprint, path: String, expanded: Dictionary, global: Dictionary, errors: Array[String]
) -> void:
	var values := resolved_values(object_id, data, style, inline, global, MapBlueprintCompiler.TERRAIN_KEYS, path, errors)
	register_id(object_id, path, expanded, errors)
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


static func _expand_terrain_stroke(
	object_id: StringName, style_id: StringName, data: Dictionary, style: Dictionary, inline: Dictionary,
	blueprint: MapBlueprint, path: String, expanded: Dictionary, global: Dictionary, errors: Array[String]
) -> void:
	var values := resolved_values(object_id, data, style, inline, global, MapBlueprintCompiler.TERRAIN_KEYS, path, errors)
	register_id(object_id, path, expanded, errors)
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


static func _expand_structure(
	object_id: StringName, data: Dictionary, style: Dictionary, inline: Dictionary,
	blueprint: MapBlueprint, path: String, expanded: Dictionary, global: Dictionary, errors: Array[String]
) -> void:
	var values := resolved_values(object_id, data, style, inline, global, MapBlueprintCompiler.BUILDING_OVERRIDE_KEYS, path, errors)
	_append_building(object_id, values, blueprint, path, expanded, errors)


static func _expand_wall(
	object_id: StringName, data: Dictionary, style: Dictionary, inline: Dictionary,
	blueprint: MapBlueprint, path: String, expanded: Dictionary, global: Dictionary, errors: Array[String]
) -> void:
	var values := resolved_values(object_id, data, style, inline, global, MapBlueprintCompiler.BUILDING_OVERRIDE_KEYS, path, errors)
	var start: Variant = data.get("start")
	var finish: Variant = data.get("end")
	var thickness := int(data.get("thickness", 0))
	if not start is Vector2i or not finish is Vector2i:
		errors.append("%s endpoints must be Vector2i" % path)
		return
	if start == finish or (start.x != finish.x and start.y != finish.y):
		errors.append("%s must have distinct orthogonal endpoints" % path)
		return
	if thickness <= 0:
		errors.append("%s.thickness must be positive" % path)
		return
	var horizontal: bool = start.y == finish.y
	var run_rect := Rect2i(
		mini(start.x, finish.x) if horizontal else start.x,
		start.y if horizontal else mini(start.y, finish.y),
		absi(finish.x - start.x) + 1 if horizontal else thickness,
		thickness if horizontal else absi(finish.y - start.y) + 1
	)
	var openings: Variant = data.get("openings", [])
	if not openings is Array:
		errors.append("%s.openings must be Array[Rect2i]" % path)
		return
	var intervals: Array[Vector2i] = []
	for index in openings.size():
		var opening: Variant = openings[index]
		if not opening is Rect2i:
			errors.append("%s.openings[%d] must be Rect2i" % [path, index])
			continue
		if opening.size.x <= 0 or opening.size.y <= 0 or not run_rect.encloses(opening):
			errors.append("%s.openings[%d] must be positive and inside the wall run" % [path, index])
			continue
		if horizontal and (opening.position.y != run_rect.position.y or opening.size.y != thickness):
			errors.append("%s.openings[%d] must span the wall thickness" % [path, index])
			continue
		if not horizontal and (opening.position.x != run_rect.position.x or opening.size.x != thickness):
			errors.append("%s.openings[%d] must span the wall thickness" % [path, index])
			continue
		intervals.append(Vector2i(opening.position.x, opening.end.x) if horizontal else Vector2i(opening.position.y, opening.end.y))
	intervals.sort_custom(MapBlueprintCompiler._compare_vector2i)
	var cursor := run_rect.position.x if horizontal else run_rect.position.y
	var run_end := run_rect.end.x if horizontal else run_rect.end.y
	var segments: Array[Rect2i] = []
	for interval in intervals:
		if interval.x < cursor:
			errors.append("%s.openings overlap at cell %d" % [path, interval.x])
			continue
		if interval.x > cursor:
			segments.append(Rect2i(cursor, run_rect.position.y, interval.x - cursor, thickness) if horizontal else Rect2i(run_rect.position.x, cursor, thickness, interval.x - cursor))
		cursor = maxi(cursor, interval.y)
	if cursor < run_end:
		segments.append(Rect2i(cursor, run_rect.position.y, run_end - cursor, thickness) if horizontal else Rect2i(run_rect.position.x, cursor, thickness, run_end - cursor))
	if segments.is_empty():
		errors.append("%s openings remove the complete wall run" % path)
		return
	if segments.size() > 1:
		# The authored wall keeps its stable owner ID while deterministic child
		# suffixes identify the runtime fragments around openings.
		register_id(object_id, path, expanded, errors)
	for index in segments.size():
		var segment_id := object_id if segments.size() == 1 else StringName("%s/segment.%03d" % [String(object_id), index])
		var segment_values := values.duplicate(true)
		segment_values["rect"] = segments[index]
		_append_building(segment_id, segment_values, blueprint, "%s.segment[%d]" % [path, index], expanded, errors)


static func _expand_row(
	row_id: StringName, data: Dictionary, style: Dictionary, blueprint: MapBlueprint,
	path: String, expanded: Dictionary, global: Dictionary, errors: Array[String]
) -> void:
	var object_type: StringName = data.get("object_type", &"")
	if object_type not in [MapBlueprint.OBJECT_BUILDING, MapBlueprint.OBJECT_PROP]:
		errors.append("%s.object_type is unknown: %s" % [path, String(object_type)])
		return
	var origin: Variant = data.get("origin")
	var step: Variant = data.get("step")
	var slot_ids: Variant = data.get("slot_ids")
	if not origin is Vector2i or not step is Vector2i:
		errors.append("%s origin and step must be Vector2i" % path)
		return
	if step == Vector2i.ZERO:
		errors.append("%s.step must not be zero" % path)
	if not slot_ids is Array or slot_ids.is_empty():
		errors.append("%s.slot_ids must be a non-empty Array[StringName]" % path)
		return
	var per_slot: Variant = data.get("overrides_by_slot", {})
	if not per_slot is Dictionary:
		errors.append("%s.overrides_by_slot must be Dictionary" % path)
		per_slot = {}
	var known_slots: Dictionary = {}
	for index in slot_ids.size():
		var slot: Variant = slot_ids[index]
		if not slot is String and not slot is StringName:
			errors.append("%s.slot_ids[%d] must be StringName" % [path, index])
			continue
		var slot_id := StringName(slot)
		MapBlueprintCompiler._validate_id(slot_id, "%s.slot_ids[%d]" % [path, index], false, errors)
		if known_slots.has(slot_id):
			errors.append("%s has duplicate slot id: %s" % [path, String(slot_id)])
			continue
		known_slots[slot_id] = true
		var object_id := StringName("%s/%s" % [String(row_id), String(slot_id)])
		var values := {
			"kind": data.get("kind", &""),
			"cell": origin + step * index,
			"rect": Rect2i(origin + step * index, data.get("footprint_size", Vector2i.ONE)),
		}
		MapBlueprintCompiler._merge(values, style)
		var slot_override: Variant = per_slot.get(slot_id, per_slot.get(String(slot_id), {}))
		if not slot_override is Dictionary:
			errors.append("%s.overrides_by_slot[%s] must be Dictionary" % [path, String(slot_id)])
			slot_override = {}
		MapBlueprintCompiler._merge(values, slot_override)
		if global.has(object_id):
			MapBlueprintCompiler._merge(values, global[object_id])
		var allowed := MapBlueprintCompiler.BUILDING_OVERRIDE_KEYS if object_type == MapBlueprint.OBJECT_BUILDING else MapBlueprintCompiler.PROP_OVERRIDE_KEYS
		validate_override_keys(style, allowed, "%s.style" % path, errors)
		validate_override_keys(slot_override, allowed, "%s.overrides_by_slot[%s]" % [path, String(slot_id)], errors)
		if global.has(object_id):
			validate_override_keys(global[object_id], allowed, "override[%s]" % String(object_id), errors)
		if bool(values.get("enabled", true)):
			if object_type == MapBlueprint.OBJECT_BUILDING:
				_append_building(object_id, values, blueprint, "%s.slot[%s]" % [path, String(slot_id)], expanded, errors)
			else:
				_append_prop(object_id, values, blueprint, "%s.slot[%s]" % [path, String(slot_id)], expanded, errors)
		else:
			register_id(object_id, "%s.slot[%s]" % [path, String(slot_id)], expanded, errors)
			if global.has(object_id):
				errors.append("override targets disabled object: %s" % String(object_id))
	for key in per_slot.keys():
		if not known_slots.has(StringName(key)):
			errors.append("%s.overrides_by_slot has unknown slot: %s" % [path, String(key)])


static func _expand_prop(
	object_id: StringName, data: Dictionary, style: Dictionary, inline: Dictionary,
	blueprint: MapBlueprint, path: String, expanded: Dictionary, global: Dictionary, errors: Array[String]
) -> void:
	var values := resolved_values(object_id, data, style, inline, global, MapBlueprintCompiler.PROP_OVERRIDE_KEYS, path, errors)
	_append_prop(object_id, values, blueprint, path, expanded, errors)


static func _expand_point_record(
	record_kind: StringName, object_id: StringName, data: Dictionary, style: Dictionary, inline: Dictionary,
	allowed: Array[StringName], blueprint: MapBlueprint, path: String, destination: Array,
	expanded: Dictionary, global: Dictionary, errors: Array[String]
) -> void:
	var values := resolved_values(object_id, data, style, inline, global, allowed, path, errors)
	register_id(object_id, path, expanded, errors)
	if not bool(values.get("enabled", true)):
		return
	var cell: Variant = values.get("cell")
	var placement_rect: Variant = values.get("rect")
	if placement_rect is Rect2i:
		MapBlueprintCompiler._validate_rect(placement_rect, "%s.rect" % path, blueprint.size_cells, errors)
	elif cell is Vector2i:
		MapBlueprintCompiler._validate_cell(cell, "%s.cell" % path, blueprint.size_cells, errors)
	else:
		errors.append("%s requires cell or rect" % path)
		return
	values["id"] = object_id
	values["record_kind"] = record_kind
	destination.append(values)


static func _expand_rect_record(
	record_kind: StringName, object_id: StringName, data: Dictionary, style: Dictionary, inline: Dictionary,
	allowed: Array[StringName], blueprint: MapBlueprint, path: String, destination: Array,
	expanded: Dictionary, global: Dictionary, errors: Array[String]
) -> void:
	var values := resolved_values(object_id, data, style, inline, global, allowed, path, errors)
	register_id(object_id, path, expanded, errors)
	if not bool(values.get("enabled", true)):
		return
	var rect: Variant = values.get("rect")
	if not rect is Rect2i:
		errors.append("%s.rect must be Rect2i" % path)
		return
	MapBlueprintCompiler._validate_rect(rect, "%s.rect" % path, blueprint.size_cells, errors)
	if record_kind == &"landmark" and not MapDefinition.VIEW_LANDMARK_KINDS.has(values.get("kind", &"")):
		errors.append("%s kind is unknown: %s" % [path, str(values.get("kind", ""))])
	values["id"] = object_id
	values["record_kind"] = record_kind
	destination.append(values)


static func _expand_patrol(
	object_id: StringName, data: Dictionary, style: Dictionary, inline: Dictionary,
	blueprint: MapBlueprint, path: String, expanded: Dictionary, global: Dictionary, errors: Array[String]
) -> void:
	var values := resolved_values(object_id, data, style, inline, global, MapBlueprintCompiler.PATROL_KEYS, path, errors)
	register_id(object_id, path, expanded, errors)
	if not bool(values.get("enabled", true)):
		return
	var point_rects: Variant = values.get("point_rects")
	var points: Variant = values.get("points")
	if point_rects is Array and not point_rects.is_empty():
		var resolved_points: Array = []
		for index in point_rects.size():
			var rect: Variant = point_rects[index]
			if not rect is Rect2i:
				errors.append("%s.point_rects[%d] must be Rect2i" % [path, index])
				continue
			MapBlueprintCompiler._validate_rect(rect, "%s.point_rects[%d]" % [path, index], blueprint.size_cells, errors)
			resolved_points.append(rect)
		values["point_rects"] = resolved_points
	elif points is Array and not points.is_empty():
		for index in points.size():
			if not points[index] is Vector2i:
				errors.append("%s.points[%d] must be Vector2i" % [path, index])
			else:
				MapBlueprintCompiler._validate_cell(points[index], "%s.points[%d]" % [path, index], blueprint.size_cells, errors)
	else:
		errors.append("%s must define a non-empty points or point_rects array" % path)
		return
	values["id"] = object_id
	expanded["patrols"].append(values)


static func _expand_sign(
	object_id: StringName, data: Dictionary, style: Dictionary, inline: Dictionary,
	blueprint: MapBlueprint, path: String, expanded: Dictionary, global: Dictionary, errors: Array[String]
) -> void:
	var values := resolved_values(object_id, data, style, inline, global, MapBlueprintCompiler.SIGN_KEYS, path, errors)
	register_id(object_id, path, expanded, errors)
	if not bool(values.get("enabled", true)):
		return
	if String(values.get("text", "")).strip_edges().is_empty():
		errors.append("%s.text is required" % path)
	var cell: Variant = values.get("cell")
	var placement_rect: Variant = values.get("rect")
	var direction: Variant = values.get("direction")
	if placement_rect is Rect2i:
		MapBlueprintCompiler._validate_rect(placement_rect, "%s.rect" % path, blueprint.size_cells, errors)
	elif cell is Vector2i:
		MapBlueprintCompiler._validate_cell(cell, "%s.cell" % path, blueprint.size_cells, errors)
	else:
		errors.append("%s requires cell or rect" % path)
	if not direction is Vector2i or direction == Vector2i.ZERO:
		errors.append("%s.direction must be a non-zero Vector2i" % path)
	elif direction.x != 0 and direction.y != 0:
		errors.append("%s.direction must be orthogonal" % path)
	values["id"] = object_id
	expanded["signs"].append(values)


static func _append_building(
	object_id: StringName, values: Dictionary, blueprint: MapBlueprint,
	path: String, expanded: Dictionary, errors: Array[String]
) -> void:
	register_id(object_id, path, expanded, errors)
	if not bool(values.get("enabled", true)):
		return
	if not MapTypes.ALL_BUILDING_KINDS.has(values.get("kind", &"")):
		errors.append("%s building kind is unknown: %s" % [path, str(values.get("kind", ""))])
	var rect: Variant = values.get("rect")
	if not rect is Rect2i:
		errors.append("%s.rect must be Rect2i" % path)
		return
	MapBlueprintCompiler._validate_rect(rect, "%s.rect" % path, blueprint.size_cells, errors)
	values["id"] = object_id
	expanded["buildings"].append(values)


static func _append_prop(
	object_id: StringName, values: Dictionary, blueprint: MapBlueprint,
	path: String, expanded: Dictionary, errors: Array[String]
) -> void:
	register_id(object_id, path, expanded, errors)
	if not bool(values.get("enabled", true)):
		return
	if not MapTypes.ALL_PROP_KINDS.has(values.get("kind", &"")):
		errors.append("%s prop kind is unknown: %s" % [path, str(values.get("kind", ""))])
	var cell: Variant = values.get("cell")
	var placement_rect: Variant = values.get("rect")
	if placement_rect is Rect2i:
		MapBlueprintCompiler._validate_rect(placement_rect, "%s.rect" % path, blueprint.size_cells, errors)
	elif cell is Vector2i:
		MapBlueprintCompiler._validate_cell(cell, "%s.cell" % path, blueprint.size_cells, errors)
	else:
		errors.append("%s requires cell or rect" % path)
		return
	values["id"] = object_id
	expanded["props"].append(values)


static func resolved_values(
	object_id: StringName, data: Dictionary, style: Dictionary, inline: Dictionary,
	global: Dictionary, allowed: Array[StringName], path: String, errors: Array[String]
) -> Dictionary:
	validate_override_keys(style, allowed, "%s.style" % path, errors)
	validate_override_keys(inline, allowed, "%s.overrides" % path, errors)
	var values := data.duplicate(true)
	MapBlueprintCompiler._merge(values, style)
	MapBlueprintCompiler._merge(values, inline)
	if global.has(object_id):
		validate_override_keys(global[object_id], allowed, "override[%s]" % String(object_id), errors)
		MapBlueprintCompiler._merge(values, global[object_id])
	return values


static func validate_override_keys(values: Dictionary, allowed: Array[StringName], path: String, errors: Array[String]) -> void:
	for raw_key in values.keys():
		if not raw_key is String and not raw_key is StringName:
			errors.append("%s has non-string field: %s" % [path, str(raw_key)])
			continue
		var key := StringName(raw_key)
		if key == &"id":
			errors.append("%s.id cannot mutate stable identity" % path)
		elif not allowed.has(key) and not MapBlueprintCompiler.COMMON_STYLE_KEYS.has(key):
			errors.append("%s has unsupported field for this primitive: %s" % [path, String(key)])


static func register_id(object_id: StringName, path: String, expanded: Dictionary, errors: Array[String]) -> void:
	var resolved_ids: Dictionary = expanded["resolved_ids"]
	MapBlueprintCompiler._validate_id(object_id, "%s resolved id" % path, true, errors)
	if resolved_ids.has(object_id):
		errors.append("%s produces duplicate stable id: %s (first produced by %s)" % [path, String(object_id), resolved_ids[object_id]])
	else:
		resolved_ids[object_id] = path
