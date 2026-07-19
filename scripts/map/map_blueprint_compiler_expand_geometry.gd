class_name MapBlueprintCompilerExpandGeometry
extends RefCounted

## Building and wall primitive expansion for MapBlueprintCompilerExpand.


static func expand_structure(
	object_id: StringName, data: Dictionary, style: Dictionary, inline: Dictionary,
	blueprint: MapBlueprint, path: String, expanded: Dictionary, global: Dictionary, errors: Array[String]
) -> void:
	var values := MapBlueprintCompilerExpand.resolved_values(object_id, data, style, inline, global, MapBlueprintCompiler.BUILDING_OVERRIDE_KEYS, path, errors)
	append_building(object_id, values, blueprint, path, expanded, errors)


static func expand_wall(
	object_id: StringName, data: Dictionary, style: Dictionary, inline: Dictionary,
	blueprint: MapBlueprint, path: String, expanded: Dictionary, global: Dictionary, errors: Array[String]
) -> void:
	var values := MapBlueprintCompilerExpand.resolved_values(object_id, data, style, inline, global, MapBlueprintCompiler.BUILDING_OVERRIDE_KEYS, path, errors)
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
		MapBlueprintCompilerExpand.register_id(object_id, path, expanded, errors)
	for index in segments.size():
		var segment_id := object_id if segments.size() == 1 else StringName("%s/segment.%03d" % [String(object_id), index])
		var segment_values := values.duplicate(true)
		segment_values["rect"] = segments[index]
		append_building(segment_id, segment_values, blueprint, "%s.segment[%d]" % [path, index], expanded, errors)


static func expand_row(
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
		MapBlueprintCompilerExpand.validate_override_keys(style, allowed, "%s.style" % path, errors)
		MapBlueprintCompilerExpand.validate_override_keys(slot_override, allowed, "%s.overrides_by_slot[%s]" % [path, String(slot_id)], errors)
		if global.has(object_id):
			MapBlueprintCompilerExpand.validate_override_keys(global[object_id], allowed, "override[%s]" % String(object_id), errors)
		if bool(values.get("enabled", true)):
			if object_type == MapBlueprint.OBJECT_BUILDING:
				append_building(object_id, values, blueprint, "%s.slot[%s]" % [path, String(slot_id)], expanded, errors)
			else:
				MapBlueprintCompilerExpand.append_prop(object_id, values, blueprint, "%s.slot[%s]" % [path, String(slot_id)], expanded, errors)
		else:
			MapBlueprintCompilerExpand.register_id(object_id, "%s.slot[%s]" % [path, String(slot_id)], expanded, errors)
			if global.has(object_id):
				errors.append("override targets disabled object: %s" % String(object_id))
	for key in per_slot.keys():
		if not known_slots.has(StringName(key)):
			errors.append("%s.overrides_by_slot has unknown slot: %s" % [path, String(key)])


static func append_building(
	object_id: StringName, values: Dictionary, blueprint: MapBlueprint,
	path: String, expanded: Dictionary, errors: Array[String]
) -> void:
	MapBlueprintCompilerExpand.register_id(object_id, path, expanded, errors)
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
