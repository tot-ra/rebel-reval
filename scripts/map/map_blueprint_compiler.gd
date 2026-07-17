class_name MapBlueprintCompiler
extends RefCounted

## Pure, deterministic expansion from cell-space MapBlueprint semantics to the
## existing MapDefinition runtime contract.

const COMPILER_VERSION := 2
const ID_PATTERN := "^[a-z0-9_.-]+$"

const COMMON_STYLE_KEYS: Array[StringName] = [&"enabled"]
const TERRAIN_KEYS: Array[StringName] = [&"terrain"]
const BUILDING_OVERRIDE_KEYS: Array[StringName] = [
	&"rect", &"wall_height", &"wall_height_scale", &"wall_color", &"roof_color",
	&"door_side", &"ridge_axis", &"primitive",
]
const PROP_OVERRIDE_KEYS: Array[StringName] = [
	&"cell", &"rect", &"facing", &"style_variant", &"visual_offset_px", &"primitive",
]
const SPAWN_KEYS: Array[StringName] = [&"cell", &"rect"]
const TRANSITION_KEYS: Array[StringName] = [
	&"rect", &"destination_scene_id", &"destination_spawn_id", &"spawn_id",
	&"spawn_offset_px", &"highlight_area", &"view_landmark_id",
]
const ANCHOR_KEYS: Array[StringName] = [&"cell", &"rect", &"kind"]
const PATROL_KEYS: Array[StringName] = [&"points", &"point_rects"]
const RECT_KEYS: Array[StringName] = [&"rect"]
const SIGN_KEYS: Array[StringName] = [&"text", &"cell", &"rect", &"direction"]
const LANDMARK_OVERRIDE_KEYS: Array[StringName] = [
	&"rect", &"wall_color", &"top_px", &"door_material", &"passage_axis",
]
const ALL_STYLE_KEYS: Array[StringName] = [
	&"enabled", &"terrain", &"rect", &"wall_height", &"wall_height_scale", &"wall_color",
	&"roof_color", &"door_side", &"ridge_axis", &"primitive", &"cell", &"facing",
	&"style_variant", &"visual_offset_px", &"destination_scene_id", &"destination_spawn_id",
	&"spawn_id", &"spawn_offset_px", &"highlight_area", &"view_landmark_id", &"kind",
	&"points", &"point_rects", &"text", &"direction", &"top_px", &"door_material", &"passage_axis",
]


static func compile(blueprint: MapBlueprint) -> MapDefinition:
	return compile_with_diagnostics(blueprint).definition


static func compile_with_diagnostics(blueprint: MapBlueprint) -> MapBlueprintCompileResult:
	var result := MapBlueprintCompileResult.new()
	if blueprint == null:
		result.errors.append("blueprint is required")
		return result

	_validate_metadata(blueprint, result.errors)
	_validate_deterministic_value(blueprint.styles, "styles", result.errors)
	_validate_deterministic_value(blueprint.primitives, "primitives", result.errors)
	_validate_deterministic_value(blueprint.object_overrides, "object_overrides", result.errors)
	var prefab_expansion := MapPrefabExpander.expand(blueprint, result.errors)
	_validate_deterministic_value(prefab_expansion["primitives"], "expanded_prefabs", result.errors)
	var resolved_styles := _resolve_styles(blueprint, result.errors)
	var global_overrides := _index_global_overrides(blueprint, result.errors)
	var expanded := _expand_primitives(blueprint, resolved_styles, global_overrides, result.errors, prefab_expansion)
	_validate_unused_overrides(global_overrides, expanded["resolved_ids"], result.errors)
	var spawn_count: int = expanded["spawns"].size()
	if spawn_count != 1:
		result.errors.append("blueprint must define exactly one enabled player_spawn; found %d" % spawn_count)
	if not result.errors.is_empty():
		return result

	var definition := _build_definition(blueprint, expanded)
	var runtime_errors := definition.validate()
	for error in runtime_errors:
		result.errors.append("compiled MapDefinition: %s" % error)
	if not result.errors.is_empty():
		return result

	result.definition = definition
	return result


static func _validate_metadata(blueprint: MapBlueprint, errors: Array[String]) -> void:
	_validate_id(blueprint.map_id, "map.map_id", false, errors)
	if blueprint.location.is_empty():
		errors.append("map.location is required")
	if blueprint.scope not in [&"prototype", &"production", &"archive"]:
		errors.append("map.scope must be prototype, production, or archive")
	if blueprint.active and blueprint.scope in [&"prototype", &"archive"]:
		errors.append("map.active=true is rejected for prototype or archive scope")
	if blueprint.palette.is_empty():
		errors.append("map.palette is required")
	if blueprint.size_cells.x <= 0 or blueprint.size_cells.y <= 0:
		errors.append("map.size_cells must be positive")
	if blueprint.cell_size <= 0:
		errors.append("map.cell_size must be positive")
	if not MapTypes.ALL_TERRAINS.has(blueprint.base_terrain):
		errors.append("map.base_terrain is unknown: %s" % String(blueprint.base_terrain))

	var source_paths: Dictionary = {}
	for index in blueprint.source_references.size():
		var path := blueprint.source_references[index]
		var prefix := "source_references[%d]" % index
		if path.strip_edges().is_empty():
			errors.append("%s must not be empty" % prefix)
		elif path.is_absolute_path() or path.contains(".."):
			errors.append("%s must be a project-relative path: %s" % [prefix, path])
		elif not FileAccess.file_exists("res://" + path):
			errors.append("%s does not exist: %s" % [prefix, path])
		if source_paths.has(path):
			errors.append("duplicate source reference: %s" % path)
		source_paths[path] = true

	var sides: Dictionary = {}
	for side in blueprint.surroundings_town_sides:
		if not MapDefinition.WORLD_SIDES.has(side):
			errors.append("surroundings has unknown side: %s" % String(side))
		elif sides.has(side):
			errors.append("surroundings has duplicate side: %s" % String(side))
		sides[side] = true
	if blueprint.has_authored_camera_bounds:
		_validate_rect(blueprint.authored_camera_bounds, "camera_bounds", blueprint.size_cells, errors)


static func _resolve_styles(blueprint: MapBlueprint, errors: Array[String]) -> Dictionary:
	var declarations: Dictionary = {}
	for index in blueprint.styles.size():
		var declaration: Dictionary = blueprint.styles[index]
		var path := "styles[%d]" % index
		var style_id: StringName = declaration.get("id", &"")
		_validate_id(style_id, "%s.id" % path, false, errors)
		if declarations.has(style_id):
			errors.append("%s duplicates style id: %s" % [path, String(style_id)])
		else:
			declarations[style_id] = declaration
		var values: Variant = declaration.get("values")
		if not values is Dictionary:
			errors.append("%s.values must be Dictionary" % path)
		else:
			for key in values.keys():
				if not key is String and not key is StringName:
					errors.append("%s.values has non-string key: %s" % [path, str(key)])
				elif StringName(key) == &"id":
					errors.append("%s.values.id cannot mutate stable identity" % path)
				elif not ALL_STYLE_KEYS.has(StringName(key)):
					errors.append("%s.values has unknown style field: %s" % [path, String(key)])

	var resolved: Dictionary = {}
	var visiting: Dictionary = {}
	var style_ids := declarations.keys()
	style_ids.sort_custom(_compare_string_values)
	for style_id in style_ids:
		_resolve_style(style_id, declarations, resolved, visiting, errors, [])
	return resolved


static func _resolve_style(
	style_id: StringName,
	declarations: Dictionary,
	resolved: Dictionary,
	visiting: Dictionary,
	errors: Array[String],
	chain: Array[String]
) -> Dictionary:
	if resolved.has(style_id):
		return resolved[style_id]
	if visiting.has(style_id):
		chain.append(String(style_id))
		errors.append("recursive style inheritance: %s" % " -> ".join(chain))
		return {}
	if not declarations.has(style_id):
		errors.append("unknown parent style: %s" % String(style_id))
		return {}

	visiting[style_id] = true
	var declaration: Dictionary = declarations[style_id]
	var values: Dictionary = {}
	var parent: StringName = declaration.get("parent", &"")
	var next_chain := chain.duplicate()
	next_chain.append(String(style_id))
	if not parent.is_empty():
		values = _resolve_style(parent, declarations, resolved, visiting, errors, next_chain).duplicate(true)
	var own_values: Variant = declaration.get("values", {})
	if own_values is Dictionary:
		_merge(values, own_values)
	visiting.erase(style_id)
	resolved[style_id] = values
	return values


static func _index_global_overrides(blueprint: MapBlueprint, errors: Array[String]) -> Dictionary:
	var indexed: Dictionary = {}
	for index in blueprint.object_overrides.size():
		var entry: Dictionary = blueprint.object_overrides[index]
		var path := "object_overrides[%d]" % index
		var target: StringName = entry.get("id", &"")
		_validate_id(target, "%s.id" % path, true, errors)
		if indexed.has(target):
			errors.append("%s conflicts with another override for: %s" % [path, String(target)])
			continue
		var values: Variant = entry.get("values")
		if not values is Dictionary:
			errors.append("%s.values must be Dictionary" % path)
			continue
		indexed[target] = values
	return indexed


static func _expand_primitives(
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
		_validate_id(primitive_id, "%s.id" % path, is_prefab_expanded, errors)
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
				_expand_terrain_rects(primitive_id, data, style_values, inline_overrides, blueprint, path, expanded, global_overrides, errors)
			&"terrain_stroke":
				_expand_terrain_stroke(primitive_id, data, style_values, inline_overrides, blueprint, path, expanded, global_overrides, errors)
			&"structure_rect":
				_expand_structure(primitive_id, data, style_values, inline_overrides, blueprint, path, expanded, global_overrides, errors)
			&"wall_run":
				_expand_wall(primitive_id, data, style_values, inline_overrides, blueprint, path, expanded, global_overrides, errors)
			&"placement_row":
				_expand_row(primitive_id, data, style_values, blueprint, path, expanded, global_overrides, errors)
			&"prop":
				_expand_prop(primitive_id, data, style_values, inline_overrides, blueprint, path, expanded, global_overrides, errors)
			&"player_spawn":
				_expand_point_record(&"spawn", primitive_id, data, style_values, inline_overrides, SPAWN_KEYS, blueprint, path, expanded["spawns"], expanded, global_overrides, errors)
			&"transition":
				_expand_rect_record(&"transition", primitive_id, data, style_values, inline_overrides, TRANSITION_KEYS, blueprint, path, expanded["transitions"], expanded, global_overrides, errors)
			&"interaction_anchor":
				_expand_point_record(&"anchor", primitive_id, data, style_values, inline_overrides, ANCHOR_KEYS, blueprint, path, expanded["anchors"], expanded, global_overrides, errors)
			&"patrol_path":
				_expand_patrol(primitive_id, data, style_values, inline_overrides, blueprint, path, expanded, global_overrides, errors)
			&"excluded_rect":
				_expand_rect_record(&"exclusion", primitive_id, data, style_values, inline_overrides, RECT_KEYS, blueprint, path, expanded["exclusions"], expanded, global_overrides, errors)
			&"fade_rect":
				_expand_rect_record(&"fade", primitive_id, data, style_values, inline_overrides, RECT_KEYS, blueprint, path, expanded["fades"], expanded, global_overrides, errors)
			&"direction_sign":
				_expand_sign(primitive_id, data, style_values, inline_overrides, blueprint, path, expanded, global_overrides, errors)
			&"view_landmark":
				_expand_rect_record(&"landmark", primitive_id, data, style_values, inline_overrides, LANDMARK_OVERRIDE_KEYS, blueprint, path, expanded["landmarks"], expanded, global_overrides, errors)
			_:
				errors.append("%s has unknown primitive kind: %s" % [path, String(primitive_kind)])
	return expanded


static func _expand_terrain_rects(
	object_id: StringName, data: Dictionary, style: Dictionary, inline: Dictionary,
	blueprint: MapBlueprint, path: String, expanded: Dictionary, global: Dictionary, errors: Array[String]
) -> void:
	var values := _resolved_values(object_id, data, style, inline, global, TERRAIN_KEYS, path, errors)
	_register_id(object_id, path, expanded, errors)
	if not MapTypes.ALL_TERRAINS.has(values.get("terrain", &"")):
		errors.append("%s terrain is unknown: %s" % [path, str(values.get("terrain", ""))])
	var rects: Variant = data.get("rects")
	if not rects is Array or rects.is_empty():
		errors.append("%s.rects must be a non-empty Array[Rect2i]" % path)
		return
	var sorted_rects: Array = rects.duplicate()
	sorted_rects.sort_custom(_compare_rects)
	for fragment_index in sorted_rects.size():
		var rect: Variant = sorted_rects[fragment_index]
		if not rect is Rect2i:
			errors.append("%s.rects[%d] must be Rect2i" % [path, fragment_index])
			continue
		if values.has("rect") and sorted_rects.size() == 1:
			rect = values["rect"]
		_validate_rect(rect, "%s.rects[%d]" % [path, fragment_index], blueprint.size_cells, errors)
		expanded["terrain"].append({
			"source_id": object_id,
			"terrain": values.get("terrain", &""),
			"rect": rect,
			"layer": int(data.get("layer", 0)),
			"order": int(data.get("order", 0)),
			"fragment": fragment_index,
		})


static func _expand_terrain_stroke(
	object_id: StringName, data: Dictionary, style: Dictionary, inline: Dictionary,
	blueprint: MapBlueprint, path: String, expanded: Dictionary, global: Dictionary, errors: Array[String]
) -> void:
	var values := _resolved_values(object_id, data, style, inline, global, TERRAIN_KEYS, path, errors)
	_register_id(object_id, path, expanded, errors)
	if not MapTypes.ALL_TERRAINS.has(values.get("terrain", &"")):
		errors.append("%s terrain is unknown: %s" % [path, str(values.get("terrain", ""))])
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
		_validate_rect(rect, "%s.segment[%d]" % [path, index], blueprint.size_cells, errors)
		expanded["terrain"].append({
			"source_id": object_id,
			"terrain": values.get("terrain", &""),
			"rect": rect,
			"layer": int(data.get("layer", 0)),
			"order": int(data.get("order", 0)),
			"fragment": index,
		})


static func _expand_structure(
	object_id: StringName, data: Dictionary, style: Dictionary, inline: Dictionary,
	blueprint: MapBlueprint, path: String, expanded: Dictionary, global: Dictionary, errors: Array[String]
) -> void:
	var values := _resolved_values(object_id, data, style, inline, global, BUILDING_OVERRIDE_KEYS, path, errors)
	_append_building(object_id, values, blueprint, path, expanded, errors)


static func _expand_wall(
	object_id: StringName, data: Dictionary, style: Dictionary, inline: Dictionary,
	blueprint: MapBlueprint, path: String, expanded: Dictionary, global: Dictionary, errors: Array[String]
) -> void:
	var values := _resolved_values(object_id, data, style, inline, global, BUILDING_OVERRIDE_KEYS, path, errors)
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
	intervals.sort_custom(_compare_vector2i)
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
		_register_id(object_id, path, expanded, errors)
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
		_validate_id(slot_id, "%s.slot_ids[%d]" % [path, index], false, errors)
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
		_merge(values, style)
		var slot_override: Variant = per_slot.get(slot_id, per_slot.get(String(slot_id), {}))
		if not slot_override is Dictionary:
			errors.append("%s.overrides_by_slot[%s] must be Dictionary" % [path, String(slot_id)])
			slot_override = {}
		_merge(values, slot_override)
		if global.has(object_id):
			_merge(values, global[object_id])
		var allowed := BUILDING_OVERRIDE_KEYS if object_type == MapBlueprint.OBJECT_BUILDING else PROP_OVERRIDE_KEYS
		_validate_override_keys(style, allowed, "%s.style" % path, errors)
		_validate_override_keys(slot_override, allowed, "%s.overrides_by_slot[%s]" % [path, String(slot_id)], errors)
		if global.has(object_id):
			_validate_override_keys(global[object_id], allowed, "override[%s]" % String(object_id), errors)
		if bool(values.get("enabled", true)):
			if object_type == MapBlueprint.OBJECT_BUILDING:
				_append_building(object_id, values, blueprint, "%s.slot[%s]" % [path, String(slot_id)], expanded, errors)
			else:
				_append_prop(object_id, values, blueprint, "%s.slot[%s]" % [path, String(slot_id)], expanded, errors)
		else:
			_register_id(object_id, "%s.slot[%s]" % [path, String(slot_id)], expanded, errors)
			if global.has(object_id):
				errors.append("override targets disabled object: %s" % String(object_id))
	for key in per_slot.keys():
		if not known_slots.has(StringName(key)):
			errors.append("%s.overrides_by_slot has unknown slot: %s" % [path, String(key)])


static func _expand_prop(
	object_id: StringName, data: Dictionary, style: Dictionary, inline: Dictionary,
	blueprint: MapBlueprint, path: String, expanded: Dictionary, global: Dictionary, errors: Array[String]
) -> void:
	var values := _resolved_values(object_id, data, style, inline, global, PROP_OVERRIDE_KEYS, path, errors)
	_append_prop(object_id, values, blueprint, path, expanded, errors)


static func _expand_point_record(
	record_kind: StringName, object_id: StringName, data: Dictionary, style: Dictionary, inline: Dictionary,
	allowed: Array[StringName], blueprint: MapBlueprint, path: String, destination: Array,
	expanded: Dictionary, global: Dictionary, errors: Array[String]
) -> void:
	var values := _resolved_values(object_id, data, style, inline, global, allowed, path, errors)
	_register_id(object_id, path, expanded, errors)
	if not bool(values.get("enabled", true)):
		return
	var cell: Variant = values.get("cell")
	var placement_rect: Variant = values.get("rect")
	if placement_rect is Rect2i:
		_validate_rect(placement_rect, "%s.rect" % path, blueprint.size_cells, errors)
	elif cell is Vector2i:
		_validate_cell(cell, "%s.cell" % path, blueprint.size_cells, errors)
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
	var values := _resolved_values(object_id, data, style, inline, global, allowed, path, errors)
	_register_id(object_id, path, expanded, errors)
	if not bool(values.get("enabled", true)):
		return
	var rect: Variant = values.get("rect")
	if not rect is Rect2i:
		errors.append("%s.rect must be Rect2i" % path)
		return
	_validate_rect(rect, "%s.rect" % path, blueprint.size_cells, errors)
	if record_kind == &"landmark" and not MapDefinition.VIEW_LANDMARK_KINDS.has(values.get("kind", &"")):
		errors.append("%s kind is unknown: %s" % [path, str(values.get("kind", ""))])
	values["id"] = object_id
	values["record_kind"] = record_kind
	destination.append(values)


static func _expand_patrol(
	object_id: StringName, data: Dictionary, style: Dictionary, inline: Dictionary,
	blueprint: MapBlueprint, path: String, expanded: Dictionary, global: Dictionary, errors: Array[String]
) -> void:
	var values := _resolved_values(object_id, data, style, inline, global, PATROL_KEYS, path, errors)
	_register_id(object_id, path, expanded, errors)
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
			_validate_rect(rect, "%s.point_rects[%d]" % [path, index], blueprint.size_cells, errors)
			resolved_points.append(rect)
		values["point_rects"] = resolved_points
	elif points is Array and not points.is_empty():
		for index in points.size():
			if not points[index] is Vector2i:
				errors.append("%s.points[%d] must be Vector2i" % [path, index])
			else:
				_validate_cell(points[index], "%s.points[%d]" % [path, index], blueprint.size_cells, errors)
	else:
		errors.append("%s must define a non-empty points or point_rects array" % path)
		return
	values["id"] = object_id
	expanded["patrols"].append(values)


static func _expand_sign(
	object_id: StringName, data: Dictionary, style: Dictionary, inline: Dictionary,
	blueprint: MapBlueprint, path: String, expanded: Dictionary, global: Dictionary, errors: Array[String]
) -> void:
	var values := _resolved_values(object_id, data, style, inline, global, SIGN_KEYS, path, errors)
	_register_id(object_id, path, expanded, errors)
	if not bool(values.get("enabled", true)):
		return
	if String(values.get("text", "")).strip_edges().is_empty():
		errors.append("%s.text is required" % path)
	var cell: Variant = values.get("cell")
	var placement_rect: Variant = values.get("rect")
	var direction: Variant = values.get("direction")
	if placement_rect is Rect2i:
		_validate_rect(placement_rect, "%s.rect" % path, blueprint.size_cells, errors)
	elif cell is Vector2i:
		_validate_cell(cell, "%s.cell" % path, blueprint.size_cells, errors)
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
	_register_id(object_id, path, expanded, errors)
	if not bool(values.get("enabled", true)):
		return
	if not MapTypes.ALL_BUILDING_KINDS.has(values.get("kind", &"")):
		errors.append("%s building kind is unknown: %s" % [path, str(values.get("kind", ""))])
	var rect: Variant = values.get("rect")
	if not rect is Rect2i:
		errors.append("%s.rect must be Rect2i" % path)
		return
	_validate_rect(rect, "%s.rect" % path, blueprint.size_cells, errors)
	values["id"] = object_id
	expanded["buildings"].append(values)


static func _append_prop(
	object_id: StringName, values: Dictionary, blueprint: MapBlueprint,
	path: String, expanded: Dictionary, errors: Array[String]
) -> void:
	_register_id(object_id, path, expanded, errors)
	if not bool(values.get("enabled", true)):
		return
	if not MapTypes.ALL_PROP_KINDS.has(values.get("kind", &"")):
		errors.append("%s prop kind is unknown: %s" % [path, str(values.get("kind", ""))])
	var cell: Variant = values.get("cell")
	var placement_rect: Variant = values.get("rect")
	if placement_rect is Rect2i:
		_validate_rect(placement_rect, "%s.rect" % path, blueprint.size_cells, errors)
	elif cell is Vector2i:
		_validate_cell(cell, "%s.cell" % path, blueprint.size_cells, errors)
	else:
		errors.append("%s requires cell or rect" % path)
		return
	values["id"] = object_id
	expanded["props"].append(values)


static func _resolved_values(
	object_id: StringName, data: Dictionary, style: Dictionary, inline: Dictionary,
	global: Dictionary, allowed: Array[StringName], path: String, errors: Array[String]
) -> Dictionary:
	_validate_override_keys(style, allowed, "%s.style" % path, errors)
	_validate_override_keys(inline, allowed, "%s.overrides" % path, errors)
	var values := data.duplicate(true)
	_merge(values, style)
	_merge(values, inline)
	if global.has(object_id):
		_validate_override_keys(global[object_id], allowed, "override[%s]" % String(object_id), errors)
		_merge(values, global[object_id])
	return values


static func _validate_override_keys(values: Dictionary, allowed: Array[StringName], path: String, errors: Array[String]) -> void:
	for raw_key in values.keys():
		if not raw_key is String and not raw_key is StringName:
			errors.append("%s has non-string field: %s" % [path, str(raw_key)])
			continue
		var key := StringName(raw_key)
		if key == &"id":
			errors.append("%s.id cannot mutate stable identity" % path)
		elif not allowed.has(key) and not COMMON_STYLE_KEYS.has(key):
			errors.append("%s has unsupported field for this primitive: %s" % [path, String(key)])


static func _register_id(object_id: StringName, path: String, expanded: Dictionary, errors: Array[String]) -> void:
	var resolved_ids: Dictionary = expanded["resolved_ids"]
	_validate_id(object_id, "%s resolved id" % path, true, errors)
	if resolved_ids.has(object_id):
		errors.append("%s produces duplicate stable id: %s (first produced by %s)" % [path, String(object_id), resolved_ids[object_id]])
	else:
		resolved_ids[object_id] = path


static func _validate_unused_overrides(global: Dictionary, resolved_ids: Dictionary, errors: Array[String]) -> void:
	var targets := global.keys()
	targets.sort_custom(_compare_string_values)
	for target in targets:
		if not resolved_ids.has(target):
			errors.append("override targets unknown object: %s" % String(target))


static func _build_definition(blueprint: MapBlueprint, expanded: Dictionary) -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = blueprint.map_id
	definition.location = blueprint.location
	definition.scope = blueprint.scope
	definition.active = blueprint.active
	definition.seed = blueprint.seed
	definition.palette = blueprint.palette
	definition.size_cells = blueprint.size_cells
	definition.base_terrain = blueprint.base_terrain
	definition.cell_size = blueprint.cell_size

	var terrain: Array = expanded["terrain"]
	terrain.sort_custom(_compare_terrain)
	for entry in terrain:
		definition.zones.append({"terrain": entry["terrain"], "rect": entry["rect"]})

	var buildings: Array = expanded["buildings"]
	buildings.sort_custom(_compare_id_records)
	for values in buildings:
		definition.buildings.append(_compile_building(values, definition))
	var props: Array = expanded["props"]
	props.sort_custom(_compare_id_records)
	for values in props:
		definition.props.append(_compile_prop(values, definition))

	var spawns: Array = expanded["spawns"]
	spawns.sort_custom(_compare_id_records)
	if spawns.size() == 1:
		definition.player_spawn = _placement_position(spawns[0], definition.cell_size)
		definition.set_meta("player_spawn_id", spawns[0]["id"])
	elif spawns.is_empty():
		# MapDefinition treats Vector2.ZERO as missing, so source validation keeps
		# this error tied to the authored primitive rather than a runtime index.
		definition.player_spawn = Vector2.ZERO
	else:
		definition.player_spawn = _placement_position(spawns[0], definition.cell_size)

	var transitions: Array = expanded["transitions"]
	transitions.sort_custom(_compare_id_records)
	for values in transitions:
		definition.transitions.append(_compile_transition(values, definition))
	var anchors: Array = expanded["anchors"]
	anchors.sort_custom(_compare_id_records)
	for values in anchors:
		definition.interaction_anchors.append(_compile_anchor(values, definition))
	var patrols: Array = expanded["patrols"]
	patrols.sort_custom(_compare_id_records)
	for values in patrols:
		var points: Array[Vector2] = []
		var point_rects: Variant = values.get("point_rects")
		if point_rects is Array and not point_rects.is_empty():
			for rect in point_rects:
				points.append(_rect_center(rect, definition.cell_size))
		else:
			for cell in values["points"]:
				points.append(_cell_center(cell, definition.cell_size))
		definition.patrols.append({"id": values["id"], "points": points})

	var signs: Array = expanded["signs"]
	signs.sort_custom(_compare_id_records)
	for values in signs:
		definition.direction_signs.append(_compile_sign(values, definition))
	var landmarks: Array = expanded["landmarks"]
	landmarks.sort_custom(_compare_id_records)
	for values in landmarks:
		definition.view_landmarks.append(_compile_landmark(values, definition))

	var exclusions: Array = expanded["exclusions"]
	exclusions.sort_custom(_compare_id_records)
	for values in exclusions:
		definition.excluded_areas.append(values["rect"])
	var fades: Array = expanded["fades"]
	fades.sort_custom(_compare_id_records)
	for values in fades:
		definition.fade_volumes.append({"id": values["id"], "rect": definition.cell_rect_to_world_rect(values["rect"])})

	definition.source_references = blueprint.source_references.duplicate()
	definition.source_references.sort()
	definition.surroundings_town_sides = blueprint.surroundings_town_sides.duplicate()
	definition.surroundings_town_sides.sort_custom(_compare_string_values)
	var camera_cells := blueprint.authored_camera_bounds if blueprint.has_authored_camera_bounds else Rect2i(Vector2i.ZERO, blueprint.size_cells)
	definition.camera_bounds = definition.cell_rect_to_world_rect(camera_cells)
	definition.fingerprint = _fingerprint(definition)
	return definition


static func _compile_building(values: Dictionary, definition: MapDefinition) -> Dictionary:
	var output := {"id": values["id"], "kind": values["kind"], "footprint": definition.cell_rect_to_world_rect(values["rect"])}
	_copy_fields(values, output, [&"wall_height", &"wall_height_scale", &"wall_color", &"roof_color", &"door_side", &"ridge_axis", &"primitive"])
	return output


static func _compile_prop(values: Dictionary, definition: MapDefinition) -> Dictionary:
	var output := {
		"id": values["id"],
		"kind": values["kind"],
		"position": _placement_position(values, definition.cell_size),
	}
	_copy_fields(values, output, [&"facing", &"style_variant", &"visual_offset_px", &"primitive"])
	return output


static func _compile_transition(values: Dictionary, definition: MapDefinition) -> Dictionary:
	var output := {"id": values["id"], "rect": definition.cell_rect_to_world_rect(values["rect"])}
	_copy_non_empty_names(values, output, [&"destination_scene_id", &"destination_spawn_id", &"spawn_id", &"view_landmark_id"])
	if values.has("spawn_offset_px"):
		output["spawn_offset"] = values["spawn_offset_px"]
	if bool(values.get("highlight_area", false)):
		output["highlight_area"] = true
	return output


static func _compile_anchor(values: Dictionary, definition: MapDefinition) -> Dictionary:
	var output := {"id": values["id"], "position": _placement_position(values, definition.cell_size)}
	if not String(values.get("kind", "")).is_empty():
		output["kind"] = values["kind"]
	return output


static func _compile_sign(values: Dictionary, definition: MapDefinition) -> Dictionary:
	var direction := Vector2(values["direction"]).normalized()
	return {
		"id": values["id"],
		"text": values["text"],
		"position": _placement_position(values, definition.cell_size),
		"direction": direction,
	}


static func _compile_landmark(values: Dictionary, definition: MapDefinition) -> Dictionary:
	var output := {"id": values["id"], "kind": values["kind"], "rect": definition.cell_rect_to_world_rect(values["rect"])}
	_copy_fields(values, output, [&"wall_color", &"top_px", &"door_material", &"passage_axis"])
	return output


static func _copy_fields(source: Dictionary, destination: Dictionary, keys: Array[StringName]) -> void:
	for key in keys:
		if source.has(key):
			destination[key] = source[key]


static func _copy_non_empty_names(source: Dictionary, destination: Dictionary, keys: Array[StringName]) -> void:
	for key in keys:
		if source.has(key) and not String(source[key]).is_empty():
			destination[key] = source[key]


static func _fingerprint(definition: MapDefinition) -> String:
	var payload := {
		"compiler_version": COMPILER_VERSION,
		"map_id": definition.map_id,
		"location": definition.location,
		"scope": definition.scope,
		"active": definition.active,
		"seed": definition.seed,
		"palette": definition.palette,
		"size_cells": definition.size_cells,
		"cell_size": definition.cell_size,
		"base_terrain": definition.base_terrain,
		"zones": definition.zones,
		"buildings": definition.buildings,
		"props": definition.props,
		"player_spawn": definition.player_spawn,
		"player_spawn_id": definition.get_meta("player_spawn_id", &""),
		"transitions": definition.transitions,
		"direction_signs": definition.direction_signs,
		"excluded_areas": definition.excluded_areas,
		"patrols": definition.patrols,
		"interaction_anchors": definition.interaction_anchors,
		"camera_bounds": definition.camera_bounds,
		"fade_volumes": definition.fade_volumes,
		"source_references": definition.source_references,
		"view_landmarks": definition.view_landmarks,
		"surroundings_town_sides": definition.surroundings_town_sides,
	}
	return MapParitySnapshot.serialize_value(payload).sha256_text()


static func _validate_id(value: StringName, path: String, allow_namespace: bool, errors: Array[String]) -> void:
	var text := String(value)
	if text.is_empty():
		errors.append("%s is required" % path)
		return
	var segments := text.split("/")
	if not allow_namespace and segments.size() != 1:
		errors.append("%s cannot contain reserved namespace separator '/': %s" % [path, text])
		return
	for segment in segments:
		if segment.is_empty() or not _matches_id_pattern(segment):
			errors.append("%s has invalid stable id '%s'; use lowercase ASCII letters, digits, _, . or -" % [path, text])
			return


static func _matches_id_pattern(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile(ID_PATTERN)
	return regex.search(value) != null


static func _validate_rect(rect: Rect2i, path: String, bounds: Vector2i, errors: Array[String]) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		errors.append("%s must have positive size" % path)
	elif rect.position.x < 0 or rect.position.y < 0 or rect.end.x > bounds.x or rect.end.y > bounds.y:
		errors.append("%s is outside map bounds %s: %s" % [path, bounds, rect])


static func _validate_cell(cell: Vector2i, path: String, bounds: Vector2i, errors: Array[String]) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= bounds.x or cell.y >= bounds.y:
		errors.append("%s is outside map bounds %s: %s" % [path, bounds, cell])


static func _validate_deterministic_value(value: Variant, path: String, errors: Array[String]) -> void:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME, TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_RECT2, TYPE_RECT2I, TYPE_COLOR:
			return
		TYPE_FLOAT:
			if is_nan(value) or is_inf(value):
				errors.append("%s contains non-deterministic non-finite float" % path)
		TYPE_ARRAY:
			for index in value.size():
				_validate_deterministic_value(value[index], "%s[%d]" % [path, index], errors)
		TYPE_DICTIONARY:
			for key in value.keys():
				if not key is String and not key is StringName:
					errors.append("%s contains non-string dictionary key: %s" % [path, str(key)])
				_validate_deterministic_value(value[key], "%s.%s" % [path, String(key)], errors)
		_:
			errors.append("%s contains unsupported non-deterministic value type %d" % [path, typeof(value)])


static func _merge(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		target[StringName(key) if key is String else key] = source[key]


static func _cell_center(cell: Vector2i, cell_size: int) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * float(cell_size)


static func _rect_center(cell_rect: Rect2i, cell_size: int) -> Vector2:
	var world_rect := Rect2(
		Vector2(cell_rect.position) * float(cell_size),
		Vector2(cell_rect.size) * float(cell_size)
	)
	return world_rect.position + world_rect.size * 0.5


static func _placement_position(values: Dictionary, cell_size: int) -> Vector2:
	var placement_rect: Variant = values.get("rect")
	if placement_rect is Rect2i:
		return _rect_center(placement_rect, cell_size)
	return _cell_center(values["cell"], cell_size)


static func _compare_string_values(left: Variant, right: Variant) -> bool:
	return String(left) < String(right)


static func _compare_id_records(left: Dictionary, right: Dictionary) -> bool:
	return String(left.get("id", "")) < String(right.get("id", ""))


static func _compare_rects(left: Variant, right: Variant) -> bool:
	if not left is Rect2i or not right is Rect2i:
		return str(left) < str(right)
	var left_rect: Rect2i = left
	var right_rect: Rect2i = right
	return [left_rect.position.y, left_rect.position.x, left_rect.size.y, left_rect.size.x] < [right_rect.position.y, right_rect.position.x, right_rect.size.y, right_rect.size.x]


static func _compare_vector2i(left: Vector2i, right: Vector2i) -> bool:
	return left.x < right.x or (left.x == right.x and left.y < right.y)


static func _compare_terrain(left: Dictionary, right: Dictionary) -> bool:
	var left_key := [int(left["layer"]), int(left["order"]), String(left["source_id"]), int(left["fragment"])]
	var right_key := [int(right["layer"]), int(right["order"]), String(right["source_id"]), int(right["fragment"])]
	return left_key < right_key
