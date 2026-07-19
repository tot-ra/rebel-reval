class_name MapBlueprintCompiler
extends RefCounted

## Pure, deterministic expansion from cell-space MapBlueprint semantics to the
## existing MapDefinition runtime contract.
##
## Primitive expansion and MapDefinition assembly live in focused modules;
## this class keeps validation helpers and the public compile entry points.


const COMPILER_VERSION := 3
const ID_PATTERN := "^[a-z0-9_.-]+$"

const COMMON_STYLE_KEYS: Array[StringName] = [&"enabled"]
const TERRAIN_KEYS: Array[StringName] = [&"terrain", &"style_variant", &"movement_speed_multiplier"]
const BUILDING_OVERRIDE_KEYS: Array[StringName] = [
	&"rect", &"wall_height", &"wall_height_scale", &"wall_color", &"roof_color",
	&"door_side", &"ridge_axis", &"primitive", &"tower", &"wall_material", &"roof_material",
]
const PROP_OVERRIDE_KEYS: Array[StringName] = [
	&"cell", &"rect", &"facing", &"style_variant", &"visual_offset_px", &"primitive",
	&"movement_speed_multiplier",
]
const SPAWN_KEYS: Array[StringName] = [&"cell", &"rect"]
const TRANSITION_KEYS: Array[StringName] = [
	&"rect", &"destination_scene_id", &"destination_spawn_id", &"spawn_id",
		&"spawn_offset_px", &"highlight_area", &"transition_visual", &"view_landmark_id",
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
	&"spawn_id", &"spawn_offset_px", &"highlight_area", &"transition_visual", &"view_landmark_id", &"kind",
	&"points", &"point_rects", &"text", &"direction", &"top_px", &"door_material", &"passage_axis",
	&"movement_speed_multiplier", &"tower", &"wall_material", &"roof_material",
]


static func compile(blueprint: MapBlueprint) -> MapDefinition:
	var result := compile_with_diagnostics(blueprint)
	return result.definition if result.is_ok() else null


static func compile_with_diagnostics(
	blueprint: MapBlueprint,
	required_anchor_ids: Array[StringName] = [],
	transition_registry: Dictionary = {}
) -> MapBlueprintCompileResult:
	var result := MapBlueprintCompileResult.new()
	if blueprint == null:
		result.errors.append("blueprint is required")
		result.import_legacy_errors()
		return result

	_validate_metadata(blueprint, result.errors)
	_validate_deterministic_value(blueprint.styles, "styles", result.errors)
	_validate_deterministic_value(blueprint.primitives, "primitives", result.errors)
	_validate_deterministic_value(blueprint.object_overrides, "object_overrides", result.errors)
	var prefab_expansion := MapPrefabExpander.expand(blueprint, result.errors)
	_validate_deterministic_value(prefab_expansion["primitives"], "expanded_prefabs", result.errors)
	var resolved_styles := _resolve_styles(blueprint, result.errors)
	var global_overrides := _index_global_overrides(blueprint, result.errors)
	var expanded := MapBlueprintCompilerExpand.expand_primitives(blueprint, resolved_styles, global_overrides, result.errors, prefab_expansion)
	_validate_unused_overrides(global_overrides, expanded["resolved_ids"], result.errors)
	var spawn_count: int = expanded["spawns"].size()
	if spawn_count != 1:
		result.errors.append("blueprint must define exactly one enabled player_spawn; found %d" % spawn_count)
	if not result.errors.is_empty():
		result.import_legacy_errors(blueprint.map_id)
		return result

	var definition := MapBlueprintCompilerBuild.build_definition(blueprint, expanded)
	var runtime_errors := definition.validate()
	for error in runtime_errors:
		result.errors.append("compiled MapDefinition: %s" % error)
	if not result.errors.is_empty():
		result.import_legacy_errors(blueprint.map_id)
		return result

	result.definition = definition
	for diagnostic in MapBlueprintSemanticValidator.validate(definition, required_anchor_ids, transition_registry):
		result.add_diagnostic(diagnostic)
	result.import_legacy_errors(blueprint.map_id)
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
	for side in blueprint.surroundings_sides.keys():
		var kind: StringName = blueprint.surroundings_sides[side]
		if not MapDefinition.WORLD_SIDES.has(side):
			errors.append("surroundings has unknown side: %s" % String(side))
		elif sides.has(side):
			errors.append("surroundings has duplicate side: %s" % String(side))
		elif not MapDefinition.SURROUNDINGS_KINDS.has(kind):
			errors.append("surroundings has unknown kind for %s: %s" % [String(side), String(kind)])
		else:
			sides[side] = true
	for side in blueprint.surroundings_town_sides:
		if not MapDefinition.WORLD_SIDES.has(side):
			errors.append("surroundings has unknown side: %s" % String(side))
		elif sides.has(side) and blueprint.surroundings_sides.get(side) != &"town":
			errors.append("surroundings town side conflicts with kind on %s" % String(side))
		elif not sides.has(side):
			errors.append("surroundings town side missing kind entry: %s" % String(side))
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


static func _validate_unused_overrides(global: Dictionary, resolved_ids: Dictionary, errors: Array[String]) -> void:
	var targets := global.keys()
	targets.sort_custom(_compare_string_values)
	for target in targets:
		if not resolved_ids.has(target):
			errors.append("override targets unknown object: %s" % String(target))


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
