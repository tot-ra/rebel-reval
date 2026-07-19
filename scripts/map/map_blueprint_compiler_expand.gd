class_name MapBlueprintCompilerExpand
extends RefCounted

## Primitive expansion from authored MapBlueprint cells into compiler buckets.

const ExpandTerrain := preload("res://scripts/map/map_blueprint_compiler_expand_terrain.gd")
const ExpandGeometry := preload("res://scripts/map/map_blueprint_compiler_expand_geometry.gd")

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
				ExpandTerrain.expand_terrain_rects(primitive_id, style_id, data, style_values, inline_overrides, blueprint, path, expanded, global_overrides, errors)
			&"terrain_stroke":
				ExpandTerrain.expand_terrain_stroke(primitive_id, style_id, data, style_values, inline_overrides, blueprint, path, expanded, global_overrides, errors)
			&"structure_rect":
				ExpandGeometry.expand_structure(primitive_id, data, style_values, inline_overrides, blueprint, path, expanded, global_overrides, errors)
			&"wall_run":
				ExpandGeometry.expand_wall(primitive_id, data, style_values, inline_overrides, blueprint, path, expanded, global_overrides, errors)
			&"placement_row":
				ExpandGeometry.expand_row(primitive_id, data, style_values, blueprint, path, expanded, global_overrides, errors)
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


static func _expand_prop(
	object_id: StringName, data: Dictionary, style: Dictionary, inline: Dictionary,
	blueprint: MapBlueprint, path: String, expanded: Dictionary, global: Dictionary, errors: Array[String]
) -> void:
	var values := resolved_values(object_id, data, style, inline, global, MapBlueprintCompiler.PROP_OVERRIDE_KEYS, path, errors)
	append_prop(object_id, values, blueprint, path, expanded, errors)


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


static func append_prop(
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
