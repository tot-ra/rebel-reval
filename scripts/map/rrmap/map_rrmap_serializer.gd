class_name MapRrmapSerializer
extends RefCounted

## Deterministic rrmap v1 text emission. Kept separate from the parser so
## round-trip and canonical-print tests do not load the full tokenizer.


static func canonical_print(blueprint: MapBlueprint, format_version: int = 1) -> String:
	if blueprint == null:
		return ""
	var lines: Array[String] = ["rrmap %d" % format_version]
	lines.append("map %s %s %d %d %s scope=%s active=%s palette=%s seed=%d cell_size=%d" % [
		blueprint.map_id, blueprint.location, blueprint.size_cells.x, blueprint.size_cells.y,
		blueprint.base_terrain, blueprint.scope, str(blueprint.active).to_lower(), blueprint.palette,
		blueprint.seed, blueprint.cell_size,
	])
	var styles := blueprint.styles.duplicate(true)
	styles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["id"]) < String(b["id"]))
	for style in styles:
		var values: Dictionary = style["values"]
		var options = _canonical_options(values)
		if not StringName(style["parent"]).is_empty():
			options.push_front("parent=%s" % style["parent"])
		lines.append("style %s%s" % [style["id"], _option_suffix(options)])
	for path in blueprint.source_references:
		lines.append("source %s" % _quote(path))
	if not blueprint.surroundings_sides.is_empty():
		var tokens: Array[String] = []
		var sides := blueprint.surroundings_sides.keys()
		sides.sort_custom(func(a, b): return String(a) < String(b))
		for side in sides:
			tokens.append(String(side))
			tokens.append(String(blueprint.surroundings_sides[side]))
		lines.append("surroundings %s" % " ".join(tokens))
	if blueprint.has_authored_camera_bounds:
		lines.append("camera %s" % _rect_text(blueprint.authored_camera_bounds))
	for package in blueprint.prefab_packages:
		lines.append("package %s %d" % [package.package_id, package.version])
	for primitive in blueprint.primitives:
		lines.append(_print_primitive(primitive))
	for instance in blueprint.prefab_instances:
		lines.append(_print_prefab(instance))
	for object_override in blueprint.object_overrides:
		lines.append("override %s%s" % [object_override["id"], _option_suffix(_canonical_options(object_override["values"]))])
	return "\n".join(lines) + "\n"


static func _print_primitive(primitive: Dictionary) -> String:
	var kind: StringName = primitive["primitive"]
	var id = primitive["id"]
	var data: Dictionary = primitive["data"]
	var options: Dictionary = primitive["overrides"].duplicate(true)
	if not StringName(primitive["style"]).is_empty():
		options["style"] = primitive["style"]
	match kind:
		&"terrain_rect":
			return "terrain %s %s %s layer=%d order=%d%s" % [id, data["terrain"], _rect_text(data["rects"][0]), data["layer"], data["order"], _option_suffix(_canonical_options(options))]
		&"terrain_rects":
			return "terrain_rects %s %s %s layer=%d order=%d%s" % [id, data["terrain"], _rect_list_text(data["rects"]), data["layer"], data["order"], _option_suffix(_canonical_options(options))]
		&"terrain_stroke":
			return "stroke %s %s %s thickness=%d layer=%d order=%d%s" % [id, data["terrain"], _point_list_text(data["points"]), data["thickness"], data["layer"], data["order"], _option_suffix(_canonical_options(options))]
		&"structure_rect":
			return "building %s %s %s%s" % [id, data["kind"], _rect_text(data["rect"]), _option_suffix(_canonical_options(options))]
		&"wall_run":
			options["thickness"] = data["thickness"]
			options["kind"] = data["kind"]
			if not data["openings"].is_empty():
				options["openings"] = _rect_list_text(data["openings"])
			return "wall %s %d %d %d %d%s" % [id, data["start"].x, data["start"].y, data["end"].x, data["end"].y, _option_suffix(_canonical_options(options))]
		&"prop":
			if data.has("rect"):
				options["rect"] = "%d,%d" % [data["rect"].size.x, data["rect"].size.y]
				return "prop %s %s %d %d%s" % [id, data["kind"], data["rect"].position.x, data["rect"].position.y, _option_suffix(_canonical_options(options))]
			return "prop %s %s %d %d%s" % [id, data["kind"], data["cell"].x, data["cell"].y, _option_suffix(_canonical_options(options))]
		&"player_spawn":
			if data.has("rect"):
				return "spawn %s %d %d rect=%d,%d" % [id, data["rect"].position.x, data["rect"].position.y, data["rect"].size.x, data["rect"].size.y]
			return "spawn %s %d %d" % [id, data["cell"].x, data["cell"].y]
		&"transition":
			if not StringName(data["destination_scene_id"]).is_empty():
				options["to"] = data["destination_scene_id"]
			if not StringName(data["destination_spawn_id"]).is_empty():
				options["destination_spawn"] = data["destination_spawn_id"]
			if not StringName(data["spawn_id"]).is_empty():
				options["spawn"] = data["spawn_id"]
			return "transition %s %s%s" % [id, _rect_text(data["rect"]), _option_suffix(_canonical_options(options))]
		&"interaction_anchor":
			if not StringName(data["kind"]).is_empty():
				options["kind"] = data["kind"]
			if data.has("rect"):
				options["rect"] = "%d,%d" % [data["rect"].size.x, data["rect"].size.y]
				return "anchor %s %d %d%s" % [id, data["rect"].position.x, data["rect"].position.y, _option_suffix(_canonical_options(options))]
			return "anchor %s %d %d%s" % [id, data["cell"].x, data["cell"].y, _option_suffix(_canonical_options(options))]
		&"patrol_path":
			return "patrol %s %s" % [id, _point_list_text(data["points"])]
		&"excluded_rect":
			return "exclude %s %s" % [id, _rect_text(data["rect"])]
		&"fade_rect":
			return "fade %s %s" % [id, _rect_text(data["rect"])]
		&"direction_sign":
			return "sign %s %s %d %d %s%s" % [id, _quote(data["text"]), data["cell"].x, data["cell"].y, _direction_text(data["direction"]), _option_suffix(_canonical_options(options))]
		&"view_landmark":
			return "landmark %s %s %s%s" % [id, data["kind"], _rect_text(data["rect"]), _option_suffix(_canonical_options(options))]
	return "# unsupported primitive %s" % kind


static func _print_prefab(instance: Dictionary) -> String:
	var transform: MapTransform = instance["transform"]
	var options := [
		"rotation=%d" % transform.rotation_degrees,
		"mirror_x=%s" % str(transform.mirror_x).to_lower(),
		"mirror_y=%s" % str(transform.mirror_y).to_lower(),
	]
	var keys: Array = instance["parameters"].keys()
	keys.sort()
	for key in keys:
		options.append("param.%s=%s" % [key, _value_text(instance["parameters"][key])])
	return "prefab %s %s %d %d %s" % [instance["id"], instance["prefab_id"], instance["origin"].x, instance["origin"].y, " ".join(options)]


static func _canonical_options(values: Dictionary) -> Array[String]:
	var keys: Array = values.keys()
	keys.sort()
	var options: Array[String] = []
	for key in keys:
		options.append("%s=%s" % [key, _value_text(values[key])])
	return options


static func _value_text(value: Variant) -> String:
	if value is bool:
		return str(value).to_lower()
	if value is Color:
		return value.to_html(true)
	if value is Vector2i or value is Vector2:
		return "%s,%s" % [_number_text(value.x), _number_text(value.y)]
	if value is Rect2i:
		return "%d,%d,%d,%d" % [value.position.x, value.position.y, value.size.x, value.size.y]
	if value is float:
		return _number_text(value)
	return str(value)


static func _number_text(value: float) -> String:
	return str(int(value)) if value == floor(value) else str(value)


static func _option_suffix(options: Array[String]) -> String:
	return "" if options.is_empty() else " " + " ".join(options)


static func _rect_text(rect: Rect2i) -> String:
	return "%d %d %d %d" % [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


static func _rect_list_text(rects: Array) -> String:
	var values: Array[String] = []
	for rect in rects:
		values.append("%d,%d,%d,%d" % [rect.position.x, rect.position.y, rect.size.x, rect.size.y])
	return "|".join(values)


static func _point_list_text(points: Array) -> String:
	var values: Array[String] = []
	for point in points:
		values.append("%d,%d" % [point.x, point.y])
	return "|".join(values)


static func _direction_text(direction: Vector2i) -> String:
	if direction == Vector2i.UP:
		return "north"
	if direction == Vector2i.RIGHT:
		return "east"
	if direction == Vector2i.DOWN:
		return "south"
	if direction == Vector2i.LEFT:
		return "west"
	return "%d,%d" % [direction.x, direction.y]


static func _quote(value: String) -> String:
	return "\"%s\"" % value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n")
