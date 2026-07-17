class_name MapRrmapParser
extends RefCounted

## Strict line parser for rrmap v1. It recognizes only the commands and typed
## fields below, so source text can never invoke GDScript or load arbitrary code.

const FORMAT_VERSION := 1
const _URBAN_PACKAGE := preload("res://scripts/map/prefabs/urban_prefab_package.gd")

const _STYLE_NAME_KEYS: Array[String] = [
	"door_side", "ridge_axis", "primitive", "style_variant", "destination_scene_id",
	"destination_spawn_id", "spawn_id", "view_landmark_id", "kind", "door_material", "passage_axis",
]
const _STYLE_FLOAT_KEYS: Array[String] = ["wall_height", "wall_height_scale", "top_px"]
const _STYLE_COLOR_KEYS: Array[String] = ["wall_color", "roof_color"]
const _STYLE_VECTOR_KEYS: Array[String] = ["visual_offset_px", "spawn_offset_px"]
const _STYLE_CARDINAL_VECTOR_KEYS: Array[String] = ["facing", "direction"]
const _STYLE_RECT_KEYS: Array[String] = ["rect", "cell", "highlight_area"]
const _STYLE_BOOL_KEYS: Array[String] = ["enabled"]


static func parse(text: String, source_path: String = "<memory>") -> MapRrmapParseResult:
	var parser := MapRrmapParser.new()
	return parser._parse(text, source_path)


static func parse_file(path: String) -> MapRrmapParseResult:
	if not FileAccess.file_exists(path):
		var missing := MapRrmapParseResult.new()
		missing.diagnostics.append(MapRrmapDiagnostic.new(path, 1, 1, &"file_not_found", "file does not exist"))
		return missing
	return parse(FileAccess.get_file_as_string(path), path)


static func canonical_print(blueprint: MapBlueprint) -> String:
	if blueprint == null:
		return ""
	var lines: Array[String] = ["rrmap %d" % FORMAT_VERSION]
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
	if not blueprint.surroundings_town_sides.is_empty():
		var sides: Array[String] = []
		for side in blueprint.surroundings_town_sides:
			sides.append(String(side))
		lines.append("surroundings %s" % " ".join(sides))
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


var _path := "<memory>"
var _result: MapRrmapParseResult
var _blueprint: MapBlueprint
var _map_line := 1
var _packages: Dictionary = {}
var _source_locations: Dictionary = {}


func _parse(text: String, source_path: String) -> MapRrmapParseResult:
	_path = source_path
	_result = MapRrmapParseResult.new()
	var lines := text.split("\n", true)
	var saw_header := false
	for index in lines.size():
		var line_number := index + 1
		var tokens = _tokenize_line(lines[index], line_number)
		if tokens.is_empty():
			continue
		if not saw_header:
			saw_header = true
			_parse_header(tokens, line_number)
			continue
		_parse_statement(tokens, line_number)
	if not saw_header:
		_error(1, 1, &"missing_header", "expected 'rrmap 1' as the first non-comment line")
	if _blueprint == null and not _has_error(&"missing_map"):
		_error(1, 1, &"missing_map", "exactly one map statement is required")
	if not _result.diagnostics.is_empty() or _blueprint == null:
		return _result
	_result.blueprint = _blueprint
	var compiled := MapBlueprintCompiler.compile_with_diagnostics(_blueprint)
	for diagnostic in compiled.diagnostics:
		var location := _diagnostic_location(diagnostic.message)
		_result.diagnostics.append(MapRrmapDiagnostic.new(
			_path,
			location.x,
			location.y,
			diagnostic.code,
			diagnostic.message,
			diagnostic.severity
		))
	if not compiled.is_ok():
		return _result
	_result.definition = compiled.definition
	return _result


func _parse_header(tokens: Array[Dictionary], line: int) -> void:
	if tokens.size() != 2 or tokens[0]["text"] != "rrmap":
		_error(line, tokens[0]["column"], &"invalid_header", "expected exactly 'rrmap 1'")
		return
	var version_text: String = tokens[1]["text"]
	if not version_text.is_valid_int():
		_error(line, tokens[1]["column"], &"invalid_version", "format version must be an integer")
		return
	var version := int(version_text)
	if version == FORMAT_VERSION:
		return
	if version == 0:
		_error(line, tokens[1]["column"], &"version_migration_required", "rrmap 0 is obsolete; migrate the header to 'rrmap 1' and validate the file")
	else:
		_error(line, tokens[1]["column"], &"unsupported_version", "unsupported rrmap version %d; this build supports only version %d" % [version, FORMAT_VERSION])


func _parse_statement(tokens: Array[Dictionary], line: int) -> void:
	var command: String = tokens[0]["text"]
	if command != "map" and tokens.size() > 1:
		_source_locations[tokens[1]["text"]] = Vector2i(line, tokens[1]["column"])
	if command == "map":
		_parse_map(tokens, line)
		return
	if _blueprint == null:
		_error(line, tokens[0]["column"], &"map_required", "map must be declared before '%s'" % command)
		return
	match command:
		"source": _parse_source(tokens, line)
		"surroundings": _parse_surroundings(tokens, line)
		"camera": _parse_camera(tokens, line)
		"style": _parse_style(tokens, line)
		"terrain": _parse_terrain(tokens, line)
		"terrain_rects": _parse_terrain_rects(tokens, line)
		"stroke": _parse_stroke(tokens, line)
		"building": _parse_building(tokens, line)
		"wall": _parse_wall(tokens, line)
		"prop": _parse_prop(tokens, line)
		"spawn": _parse_spawn(tokens, line)
		"transition": _parse_transition(tokens, line)
		"anchor": _parse_anchor(tokens, line)
		"patrol": _parse_patrol(tokens, line)
		"exclude": _parse_simple_rect(tokens, line, &"exclude")
		"fade": _parse_simple_rect(tokens, line, &"fade")
		"sign": _parse_sign(tokens, line)
		"landmark": _parse_landmark(tokens, line)
		"package": _parse_package(tokens, line)
		"prefab": _parse_prefab(tokens, line)
		"override": _parse_override(tokens, line)
		_:
			_error(line, tokens[0]["column"], &"unknown_command", "unknown command '%s'" % command)


func _parse_map(tokens: Array[Dictionary], line: int) -> void:
	if _blueprint != null:
		_error(line, tokens[0]["column"], &"duplicate_map", "only one map statement is allowed")
		return
	if not _arity(tokens, line, 6, "map <id> <location> <width> <height> <base_terrain> [key=value ...]"):
		return
	var size = _vector_from_tokens(tokens, line, 3)
	if size == null:
		return
	var options = _options(tokens, line, 6, ["scope", "active", "palette", "seed", "cell_size"])
	if options == null:
		return
	_blueprint = MapBlueprint.new(
		StringName(tokens[1]["text"]), StringName(tokens[2]["text"]), size,
		StringName(tokens[5]["text"])
	)
	_map_line = line
	if options.has("scope"): _blueprint.scope = StringName(options["scope"])
	if options.has("active"):
		var active = _bool_value(options["active"], line, _option_column(tokens, "active"))
		if active != null: _blueprint.active = active
	if options.has("palette"): _blueprint.palette = StringName(options["palette"])
	if options.has("seed"):
		var seed = _int_value(options["seed"], line, _option_column(tokens, "seed"))
		if seed != null: _blueprint.seed = seed
	if options.has("cell_size"):
		var cell_size = _int_value(options["cell_size"], line, _option_column(tokens, "cell_size"))
		if cell_size != null: _blueprint.cell_size = cell_size


func _parse_source(tokens: Array[Dictionary], line: int) -> void:
	if _exact_arity(tokens, line, 2, "source <quoted_path>"):
		_blueprint.add_source_reference(tokens[1]["text"])


func _parse_surroundings(tokens: Array[Dictionary], line: int) -> void:
	if not _arity(tokens, line, 2, "surroundings <north|east|south|west> ..."):
		return
	var sides: Array[StringName] = []
	for token in tokens.slice(1):
		if token["text"] not in ["north", "east", "south", "west"]:
			_error(line, token["column"], &"invalid_side", "expected north, east, south, or west")
		else:
			sides.append(StringName(token["text"]))
	_blueprint.surroundings(sides)


func _parse_camera(tokens: Array[Dictionary], line: int) -> void:
	var rect = _rect_from_tokens(tokens, line, 1)
	if rect != null and _exact_arity(tokens, line, 5, "camera <x> <y> <width> <height>"):
		_blueprint.camera_bounds(rect)


func _parse_style(tokens: Array[Dictionary], line: int) -> void:
	if not _arity(tokens, line, 3, "style <id> [parent=<id>] <typed_key=value> ..."):
		return
	var parsed = _typed_options(tokens, line, 2, true)
	if parsed == null:
		return
	var parent: StringName = StringName(parsed["parent"] if parsed.has("parent") else "")
	parsed.erase("parent")
	_blueprint.style(StringName(tokens[1]["text"]), parsed, parent)


func _parse_terrain(tokens: Array[Dictionary], line: int) -> void:
	if not _arity(tokens, line, 7, "terrain <id> <terrain> <x> <y> <width> <height> [layer=N] [order=N] [style=id]"):
		return
	var rect = _rect_from_tokens(tokens, line, 3)
	var options = _options(tokens, line, 7, ["layer", "order", "style"])
	if rect == null or options == null: return
	_blueprint.terrain_rect(StringName(tokens[1]["text"]), StringName(tokens[2]["text"]), rect,
		_int_option(options, "layer", 0, tokens, line), _int_option(options, "order", 0, tokens, line),
		StringName(options.get("style", "")))


func _parse_terrain_rects(tokens: Array[Dictionary], line: int) -> void:
	if not _arity(tokens, line, 4, "terrain_rects <id> <terrain> <x,y,w,h|...> [layer=N] [order=N] [style=id]"):
		return
	var rects = _rect_list(tokens[3]["text"], line, tokens[3]["column"])
	var options = _options(tokens, line, 4, ["layer", "order", "style"])
	if rects == null or options == null: return
	_blueprint.terrain_rects(StringName(tokens[1]["text"]), StringName(tokens[2]["text"]), rects,
		_int_option(options, "layer", 0, tokens, line), _int_option(options, "order", 0, tokens, line),
		StringName(options.get("style", "")))


func _parse_stroke(tokens: Array[Dictionary], line: int) -> void:
	if not _arity(tokens, line, 4, "stroke <id> <terrain> <x,y|...> [thickness=N] [layer=N] [order=N] [style=id]"):
		return
	var points = _point_list(tokens[3]["text"], line, tokens[3]["column"])
	var options = _options(tokens, line, 4, ["thickness", "layer", "order", "style"])
	if points == null or options == null: return
	_blueprint.terrain_stroke(StringName(tokens[1]["text"]), StringName(tokens[2]["text"]), points,
		_int_option(options, "thickness", 1, tokens, line), _int_option(options, "layer", 0, tokens, line),
		_int_option(options, "order", 0, tokens, line), StringName(options.get("style", "")))


func _parse_building(tokens: Array[Dictionary], line: int) -> void:
	if not _arity(tokens, line, 7, "building <id> <kind> <x> <y> <width> <height> [style=id] [typed overrides]"):
		return
	var rect = _rect_from_tokens(tokens, line, 3)
	var split = _style_and_overrides(tokens, line, 7)
	if rect == null or split == null: return
	_blueprint.structure_rect(StringName(tokens[1]["text"]), StringName(tokens[2]["text"]), rect, split["style"], split["overrides"])


func _parse_wall(tokens: Array[Dictionary], line: int) -> void:
	if not _arity(tokens, line, 6, "wall <id> <x1> <y1> <x2> <y2> [thickness=N] [openings=x,y,w,h|...] [kind=wall] [style=id] [typed overrides]"):
		return
	var start = _vector_from_tokens(tokens, line, 2)
	var end = _vector_from_tokens(tokens, line, 4)
	var raw = _raw_options(tokens, line, 6)
	if start == null or end == null or raw == null: return
	var thickness = _take_int(raw, "thickness", 1, line, tokens)
	var openings: Array[Rect2i] = []
	if raw.has("openings"):
		var parsed = _rect_list(raw["openings"], line, _option_column(tokens, "openings"))
		raw.erase("openings")
		if parsed == null: return
		openings = parsed
	var kind := StringName(raw.get("kind", "wall")); raw.erase("kind")
	var split = _typed_style_raw(raw, tokens, line)
	if split == null: return
	_blueprint.wall_run(StringName(tokens[1]["text"]), start, end, thickness, openings, split["style"], split["overrides"], kind)


func _parse_prop(tokens: Array[Dictionary], line: int) -> void:
	if not _arity(tokens, line, 5, "prop <id> <kind> <x> <y> [rect=width,height] [style=id] [typed overrides]"):
		return
	var cell = _vector_from_tokens(tokens, line, 3)
	var raw = _raw_options(tokens, line, 5)
	if cell == null or raw == null: return
	var rect_size = null
	if raw.has("rect"):
		rect_size = _csv_vector(raw["rect"], line, _option_column(tokens, "rect")); raw.erase("rect")
	var split = _typed_style_raw(raw, tokens, line)
	if split == null: return
	if rect_size == null:
		_blueprint.prop(StringName(tokens[1]["text"]), StringName(tokens[2]["text"]), cell, split["style"], split["overrides"])
	else:
		_blueprint.prop_rect(StringName(tokens[1]["text"]), StringName(tokens[2]["text"]), Rect2i(cell, rect_size), split["style"], split["overrides"])


func _parse_spawn(tokens: Array[Dictionary], line: int) -> void:
	if not _arity(tokens, line, 4, "spawn <id> <x> <y> [rect=width,height]"): return
	var cell = _vector_from_tokens(tokens, line, 2)
	var options = _options(tokens, line, 4, ["rect"])
	if cell == null or options == null: return
	if options.has("rect"):
		var size = _csv_vector(options["rect"], line, _option_column(tokens, "rect"))
		if size != null: _blueprint.player_spawn_rect(StringName(tokens[1]["text"]), Rect2i(cell, size))
	else:
		_blueprint.player_spawn(StringName(tokens[1]["text"]), cell)


func _parse_transition(tokens: Array[Dictionary], line: int) -> void:
	if not _arity(tokens, line, 6, "transition <id> <x> <y> <width> <height> [to=id] [destination_spawn=id] [spawn=id] [style=id] [typed overrides]"): return
	var rect = _rect_from_tokens(tokens, line, 2)
	var raw = _raw_options(tokens, line, 6)
	if rect == null or raw == null: return
	var destination = StringName(raw.get("to", "")); raw.erase("to")
	var destination_spawn = StringName(raw.get("destination_spawn", "")); raw.erase("destination_spawn")
	var spawn_id = StringName(raw.get("spawn", "")); raw.erase("spawn")
	var split = _typed_style_raw(raw, tokens, line)
	if split == null: return
	_blueprint.transition(StringName(tokens[1]["text"]), rect, destination, destination_spawn, spawn_id, split["style"], split["overrides"])


func _parse_anchor(tokens: Array[Dictionary], line: int) -> void:
	if not _arity(tokens, line, 4, "anchor <id> <x> <y> [kind=id] [rect=width,height] [style=id] [typed overrides]"): return
	var cell = _vector_from_tokens(tokens, line, 2)
	var raw = _raw_options(tokens, line, 4)
	if cell == null or raw == null: return
	var kind := StringName(raw.get("kind", "")); raw.erase("kind")
	var rect_size = null
	if raw.has("rect"):
		rect_size = _csv_vector(raw["rect"], line, _option_column(tokens, "rect")); raw.erase("rect")
	var split = _typed_style_raw(raw, tokens, line)
	if split == null: return
	if rect_size == null:
		_blueprint.interaction_anchor(StringName(tokens[1]["text"]), cell, kind, split["style"], split["overrides"])
	else:
		_blueprint.interaction_anchor_rect(StringName(tokens[1]["text"]), Rect2i(cell, rect_size), kind, split["style"], split["overrides"])


func _parse_patrol(tokens: Array[Dictionary], line: int) -> void:
	if not _exact_arity(tokens, line, 3, "patrol <id> <x,y|...>"): return
	var points = _point_list(tokens[2]["text"], line, tokens[2]["column"])
	if points != null: _blueprint.patrol_path(StringName(tokens[1]["text"]), points)


func _parse_simple_rect(tokens: Array[Dictionary], line: int, kind: StringName) -> void:
	if not _exact_arity(tokens, line, 6, "%s <id> <x> <y> <width> <height>" % kind): return
	var rect = _rect_from_tokens(tokens, line, 2)
	if rect == null: return
	if kind == &"exclude": _blueprint.excluded_rect(StringName(tokens[1]["text"]), rect)
	else: _blueprint.fade_rect(StringName(tokens[1]["text"]), rect)


func _parse_sign(tokens: Array[Dictionary], line: int) -> void:
	if not _arity(tokens, line, 6, "sign <id> <quoted_text> <x> <y> <north|east|south|west> [style=id] [typed overrides]"): return
	var cell = _vector_from_tokens(tokens, line, 3)
	var direction = _cardinal(tokens[5]["text"], line, tokens[5]["column"])
	var split = _style_and_overrides(tokens, line, 6)
	if cell != null and direction != null and split != null:
		_blueprint.direction_sign(StringName(tokens[1]["text"]), tokens[2]["text"], cell, direction, split["style"], split["overrides"])


func _parse_landmark(tokens: Array[Dictionary], line: int) -> void:
	if not _arity(tokens, line, 7, "landmark <id> <kind> <x> <y> <width> <height> [style=id] [typed overrides]"): return
	var rect = _rect_from_tokens(tokens, line, 3)
	var split = _style_and_overrides(tokens, line, 7)
	if rect != null and split != null:
		_blueprint.view_landmark(StringName(tokens[1]["text"]), StringName(tokens[2]["text"]), rect, split["style"], split["overrides"])


func _parse_package(tokens: Array[Dictionary], line: int) -> void:
	if not _exact_arity(tokens, line, 3, "package urban 1"): return
	if tokens[1]["text"] != "urban" or tokens[2]["text"] != "1":
		_error(line, tokens[1]["column"], &"unknown_package", "only the reviewed package 'urban 1' is allowlisted in rrmap v1")
		return
	if _packages.has("urban"):
		_error(line, tokens[1]["column"], &"duplicate_package", "package 'urban' is already registered")
		return
	var package = _URBAN_PACKAGE.create()
	_packages["urban"] = package
	_blueprint.use_prefab_package(package)


func _parse_prefab(tokens: Array[Dictionary], line: int) -> void:
	if not _arity(tokens, line, 5, "prefab <instance_id> <qualified_prefab_id> <x> <y> [rotation=0|90|180|270] [mirror_x=bool] [mirror_y=bool] [param.<name>=typed]"): return
	var origin = _vector_from_tokens(tokens, line, 3)
	var raw = _raw_options(tokens, line, 5)
	if origin == null or raw == null: return
	var rotation = _take_int(raw, "rotation", 0, line, tokens)
	var mirror_x = _take_bool(raw, "mirror_x", false, line, tokens)
	var mirror_y = _take_bool(raw, "mirror_y", false, line, tokens)
	var parameters: Dictionary = {}
	for key in raw.keys():
		if not String(key).begins_with("param."):
			_error(line, _option_column(tokens, key), &"unknown_option", "prefab option '%s' is not supported; use param.<name>" % key)
			continue
		var parsed = _literal(raw[key], line, _option_column(tokens, key))
		if parsed != null: parameters[StringName(String(key).trim_prefix("param."))] = parsed
	if not _result.diagnostics.is_empty(): return
	_blueprint.prefab_instance(StringName(tokens[1]["text"]), StringName(tokens[2]["text"]), origin, MapTransform.new(rotation, mirror_x, mirror_y), parameters)


func _parse_override(tokens: Array[Dictionary], line: int) -> void:
	if not _arity(tokens, line, 3, "override <resolved_object_id> <typed_key=value> ..."): return
	var values = _typed_options(tokens, line, 2, false)
	if values != null: _blueprint.override_object(StringName(tokens[1]["text"]), values)


func _tokenize_line(line_text: String, line: int) -> Array[Dictionary]:
	var tokens: Array[Dictionary] = []
	var index := 0
	while index < line_text.length():
		while index < line_text.length() and line_text[index] in [" ", "\t", "\r"]: index += 1
		if index >= line_text.length() or line_text[index] == "#": break
		var column := index + 1
		var value := ""
		if line_text[index] == "\"":
			index += 1
			var closed := false
			while index < line_text.length():
				var ch := line_text[index]
				if ch == "\"":
					closed = true; index += 1; break
				if ch == "\\":
					index += 1
					if index >= line_text.length(): break
					var escaped := line_text[index]
					if escaped == "n": value += "\n"
					elif escaped in ["\"", "\\", "#"]: value += escaped
					else:
						_error(line, index, &"invalid_escape", "supported escapes are \\n, \\\", \\\\, and \\#")
						value += escaped
					index += 1
				else:
					value += ch; index += 1
			if not closed: _error(line, column, &"unterminated_string", "quoted string is not closed")
			if index < line_text.length() and line_text[index] not in [" ", "\t", "\r", "#"]:
				_error(line, index + 1, &"missing_whitespace", "quoted strings must be separated by whitespace")
		else:
			while index < line_text.length() and line_text[index] not in [" ", "\t", "\r", "#"]:
				value += line_text[index]; index += 1
		tokens.append({"text": value, "column": column})
	return tokens


func _raw_options(tokens: Array[Dictionary], line: int, start: int) -> Variant:
	var values: Dictionary = {}
	for token in tokens.slice(start):
		var text: String = token["text"]
		var equals := text.find("=")
		if equals <= 0 or equals == text.length() - 1:
			_error(line, token["column"], &"invalid_option", "expected key=value")
			continue
		var key := text.left(equals)
		if values.has(key):
			_error(line, token["column"], &"duplicate_option", "option '%s' may appear only once" % key)
		else:
			values[key] = text.substr(equals + 1)
	return null if _line_has_errors(line) else values


func _options(tokens: Array[Dictionary], line: int, start: int, allowed: Array[String]) -> Variant:
	var values = _raw_options(tokens, line, start)
	if values == null: return null
	for key in values:
		if key not in allowed: _error(line, _option_column(tokens, key), &"unknown_option", "unknown option '%s'; allowed: %s" % [key, ", ".join(allowed)])
	return null if _line_has_errors(line) else values


func _typed_options(tokens: Array[Dictionary], line: int, start: int, allow_parent: bool) -> Variant:
	var raw = _raw_options(tokens, line, start)
	if raw == null: return null
	var values: Dictionary = {}
	for key in raw:
		if allow_parent and key == "parent": values[key] = StringName(raw[key]); continue
		var parsed = _typed_field(key, raw[key], line, _option_column(tokens, key))
		if parsed != null: values[StringName(key)] = parsed
	return null if _line_has_errors(line) else values


func _style_and_overrides(tokens: Array[Dictionary], line: int, start: int) -> Variant:
	var raw = _raw_options(tokens, line, start)
	if raw == null: return null
	return _typed_style_raw(raw, tokens, line)


func _typed_style_raw(raw: Dictionary, tokens: Array[Dictionary], line: int) -> Variant:
	var style := StringName(raw.get("style", "")); raw.erase("style")
	var overrides: Dictionary = {}
	for key in raw:
		var parsed = _typed_field(key, raw[key], line, _option_column(tokens, key))
		if parsed != null: overrides[StringName(key)] = parsed
	return null if _line_has_errors(line) else {"style": style, "overrides": overrides}


func _typed_field(key: String, text: String, line: int, column: int) -> Variant:
	if key in _STYLE_NAME_KEYS: return StringName(text)
	if key in _STYLE_FLOAT_KEYS: return _float_value(text, line, column)
	if key in _STYLE_COLOR_KEYS: return _color_value(text, line, column)
	if key in _STYLE_VECTOR_KEYS: return _csv_number_vector(text, line, column)
	if key in _STYLE_CARDINAL_VECTOR_KEYS: return _cardinal_or_csv_vector(text, line, column)
	if key in _STYLE_RECT_KEYS:
		var values := text.split(",", false)
		if key == "cell" and values.size() == 2: return _csv_vector(text, line, column)
		return _csv_rect(text, line, column)
	if key in _STYLE_BOOL_KEYS: return _bool_value(text, line, column)
	_error(line, column, &"unknown_typed_field", "field '%s' is not in the rrmap v1 allowlist" % key)
	return null


func _literal(text: String, line: int, column: int) -> Variant:
	if text in ["true", "false"]: return text == "true"
	if text.length() in [6, 8] and text.is_valid_hex_number(): return _color_value(text, line, column)
	if text.contains(","): return _csv_vector(text, line, column)
	if text.is_valid_int(): return int(text)
	if text.is_valid_float(): return float(text)
	return StringName(text)


func _vector_from_tokens(tokens: Array[Dictionary], line: int, start: int) -> Variant:
	if tokens.size() <= start + 1:
		_error(line, tokens[0]["column"], &"missing_value", "expected two integer coordinates")
		return null
	var x = _int_value(tokens[start]["text"], line, tokens[start]["column"])
	var y = _int_value(tokens[start + 1]["text"], line, tokens[start + 1]["column"])
	return null if x == null or y == null else Vector2i(x, y)


func _rect_from_tokens(tokens: Array[Dictionary], line: int, start: int) -> Variant:
	if tokens.size() <= start + 3:
		_error(line, tokens[0]["column"], &"missing_value", "expected x y width height")
		return null
	var values: Array[int] = []
	for index in 4:
		var parsed = _int_value(tokens[start + index]["text"], line, tokens[start + index]["column"])
		if parsed == null: return null
		values.append(parsed)
	return Rect2i(values[0], values[1], values[2], values[3])


func _csv_vector(text: String, line: int, column: int) -> Variant:
	var parts := text.split(",", false)
	if parts.size() != 2:
		_error(line, column, &"invalid_vector", "expected x,y")
		return null
	var x = _int_value(parts[0], line, column)
	var y = _int_value(parts[1], line, column + parts[0].length() + 1)
	return null if x == null or y == null else Vector2i(x, y)


func _csv_number_vector(text: String, line: int, column: int) -> Variant:
	var parts := text.split(",", false)
	if parts.size() != 2:
		_error(line, column, &"invalid_vector", "expected x,y")
		return null
	var x = _float_value(parts[0], line, column)
	var y = _float_value(parts[1], line, column + parts[0].length() + 1)
	return null if x == null or y == null else Vector2(x, y)


func _cardinal_or_csv_vector(text: String, line: int, column: int) -> Variant:
	if text in ["north", "east", "south", "west"]:
		return _cardinal(text, line, column)
	return _csv_number_vector(text, line, column)


func _csv_rect(text: String, line: int, column: int) -> Variant:
	var parts := text.split(",", false)
	if parts.size() != 4:
		_error(line, column, &"invalid_rect", "expected x,y,width,height")
		return null
	var values: Array[int] = []
	for part in parts:
		var parsed = _int_value(part, line, column)
		if parsed == null: return null
		values.append(parsed)
	return Rect2i(values[0], values[1], values[2], values[3])


func _point_list(text: String, line: int, column: int) -> Variant:
	var points: Array[Vector2i] = []
	for item in text.split("|", false):
		var point = _csv_vector(item, line, column)
		if point == null: return null
		points.append(point)
	return points


func _rect_list(text: String, line: int, column: int) -> Variant:
	var rects: Array[Rect2i] = []
	for item in text.split("|", false):
		var rect = _csv_rect(item, line, column)
		if rect == null: return null
		rects.append(rect)
	return rects


func _int_value(text: String, line: int, column: int) -> Variant:
	if not text.is_valid_int():
		_error(line, column, &"invalid_integer", "expected an integer, got '%s'" % text)
		return null
	return int(text)


func _float_value(text: String, line: int, column: int) -> Variant:
	if not text.is_valid_float():
		_error(line, column, &"invalid_number", "expected a number, got '%s'" % text)
		return null
	return float(text)


func _bool_value(text: String, line: int, column: int) -> Variant:
	if text not in ["true", "false"]:
		_error(line, column, &"invalid_boolean", "expected true or false, got '%s'" % text)
		return null
	return text == "true"


func _color_value(text: String, line: int, column: int) -> Variant:
	# '#' starts a comment outside quoted strings, so colors use bare RRGGBB(A).
	if not text.is_valid_hex_number() or text.length() not in [6, 8]:
		_error(line, column, &"invalid_color", "expected RRGGBB or RRGGBBAA")
		return null
	return Color.from_string("#" + text, Color.TRANSPARENT)


func _cardinal(text: String, line: int, column: int) -> Variant:
	match text:
		"north": return Vector2i.UP
		"east": return Vector2i.RIGHT
		"south": return Vector2i.DOWN
		"west": return Vector2i.LEFT
	_error(line, column, &"invalid_direction", "expected north, east, south, or west")
	return null


func _int_option(options: Dictionary, key: String, fallback: int, tokens: Array[Dictionary], line: int) -> int:
	if not options.has(key): return fallback
	var value = _int_value(options[key], line, _option_column(tokens, key))
	return fallback if value == null else value


func _take_int(raw: Dictionary, key: String, fallback: int, line: int, tokens: Array[Dictionary]) -> int:
	if not raw.has(key): return fallback
	var value = _int_value(raw[key], line, _option_column(tokens, key)); raw.erase(key)
	return fallback if value == null else value


func _take_bool(raw: Dictionary, key: String, fallback: bool, line: int, tokens: Array[Dictionary]) -> bool:
	if not raw.has(key): return fallback
	var value = _bool_value(raw[key], line, _option_column(tokens, key)); raw.erase(key)
	return fallback if value == null else value


func _arity(tokens: Array[Dictionary], line: int, minimum: int, usage: String) -> bool:
	if tokens.size() >= minimum: return true
	_error(line, tokens[0]["column"], &"wrong_arity", "usage: %s" % usage)
	return false


func _exact_arity(tokens: Array[Dictionary], line: int, count: int, usage: String) -> bool:
	if tokens.size() == count: return true
	_error(line, tokens[0]["column"], &"wrong_arity", "usage: %s" % usage)
	return false


func _option_column(tokens: Array[Dictionary], key: String) -> int:
	for token in tokens:
		if String(token["text"]).begins_with(key + "="): return token["column"]
	return tokens[0]["column"]


func _error(line: int, column: int, code: StringName, message: String) -> void:
	_result.diagnostics.append(MapRrmapDiagnostic.new(_path, line, maxi(column, 1), code, message))


func _line_has_errors(line: int) -> bool:
	for diagnostic in _result.diagnostics:
		if diagnostic.line == line: return true
	return false


func _has_error(code: StringName) -> bool:
	for diagnostic in _result.diagnostics:
		if diagnostic.code == code: return true
	return false


func _diagnostic_location(message: String) -> Vector2i:
	# Compiler diagnostics name semantic IDs. Point them back to the declaring
	# token when possible, while metadata errors remain on the map statement.
	for id in _source_locations:
		if message.contains("'%s'" % id) or message.contains(" %s" % id):
			return _source_locations[id]
	return Vector2i(_map_line, 1)


static func _print_primitive(primitive: Dictionary) -> String:
	var kind: StringName = primitive["primitive"]
	var id = primitive["id"]
	var data: Dictionary = primitive["data"]
	var options: Dictionary = primitive["overrides"].duplicate(true)
	if not StringName(primitive["style"]).is_empty(): options["style"] = primitive["style"]
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
			options["thickness"] = data["thickness"]; options["kind"] = data["kind"]
			if not data["openings"].is_empty(): options["openings"] = _rect_list_text(data["openings"])
			return "wall %s %d %d %d %d%s" % [id, data["start"].x, data["start"].y, data["end"].x, data["end"].y, _option_suffix(_canonical_options(options))]
		&"prop":
			if data.has("rect"):
				options["rect"] = "%d,%d" % [data["rect"].size.x, data["rect"].size.y]
				return "prop %s %s %d %d%s" % [id, data["kind"], data["rect"].position.x, data["rect"].position.y, _option_suffix(_canonical_options(options))]
			return "prop %s %s %d %d%s" % [id, data["kind"], data["cell"].x, data["cell"].y, _option_suffix(_canonical_options(options))]
		&"player_spawn":
			if data.has("rect"): return "spawn %s %d %d rect=%d,%d" % [id, data["rect"].position.x, data["rect"].position.y, data["rect"].size.x, data["rect"].size.y]
			return "spawn %s %d %d" % [id, data["cell"].x, data["cell"].y]
		&"transition":
			if not StringName(data["destination_scene_id"]).is_empty(): options["to"] = data["destination_scene_id"]
			if not StringName(data["destination_spawn_id"]).is_empty(): options["destination_spawn"] = data["destination_spawn_id"]
			if not StringName(data["spawn_id"]).is_empty(): options["spawn"] = data["spawn_id"]
			return "transition %s %s%s" % [id, _rect_text(data["rect"]), _option_suffix(_canonical_options(options))]
		&"interaction_anchor":
			if not StringName(data["kind"]).is_empty(): options["kind"] = data["kind"]
			if data.has("rect"):
				options["rect"] = "%d,%d" % [data["rect"].size.x, data["rect"].size.y]
				return "anchor %s %d %d%s" % [id, data["rect"].position.x, data["rect"].position.y, _option_suffix(_canonical_options(options))]
			return "anchor %s %d %d%s" % [id, data["cell"].x, data["cell"].y, _option_suffix(_canonical_options(options))]
		&"patrol_path": return "patrol %s %s" % [id, _point_list_text(data["points"])]
		&"excluded_rect": return "exclude %s %s" % [id, _rect_text(data["rect"])]
		&"fade_rect": return "fade %s %s" % [id, _rect_text(data["rect"])]
		&"direction_sign": return "sign %s %s %d %d %s%s" % [id, _quote(data["text"]), data["cell"].x, data["cell"].y, _direction_text(data["direction"]), _option_suffix(_canonical_options(options))]
		&"view_landmark": return "landmark %s %s %s%s" % [id, data["kind"], _rect_text(data["rect"]), _option_suffix(_canonical_options(options))]
	return "# unsupported primitive %s" % kind


static func _print_prefab(instance: Dictionary) -> String:
	var transform: MapTransform = instance["transform"]
	var options := ["rotation=%d" % transform.rotation_degrees, "mirror_x=%s" % str(transform.mirror_x).to_lower(), "mirror_y=%s" % str(transform.mirror_y).to_lower()]
	var keys: Array = instance["parameters"].keys()
	keys.sort()
	for key in keys: options.append("param.%s=%s" % [key, _value_text(instance["parameters"][key])])
	return "prefab %s %s %d %d %s" % [instance["id"], instance["prefab_id"], instance["origin"].x, instance["origin"].y, " ".join(options)]


static func _canonical_options(values: Dictionary) -> Array[String]:
	var keys: Array = values.keys()
	keys.sort()
	var options: Array[String] = []
	for key in keys: options.append("%s=%s" % [key, _value_text(values[key])])
	return options


static func _value_text(value: Variant) -> String:
	if value is bool: return str(value).to_lower()
	if value is Color: return value.to_html(true)
	if value is Vector2i or value is Vector2: return "%s,%s" % [_number_text(value.x), _number_text(value.y)]
	if value is Rect2i: return "%d,%d,%d,%d" % [value.position.x, value.position.y, value.size.x, value.size.y]
	if value is float: return _number_text(value)
	return str(value)


static func _number_text(value: float) -> String:
	return str(int(value)) if value == floor(value) else str(value)


static func _option_suffix(options: Array[String]) -> String:
	return "" if options.is_empty() else " " + " ".join(options)


static func _rect_text(rect: Rect2i) -> String:
	return "%d %d %d %d" % [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


static func _rect_list_text(rects: Array) -> String:
	var values: Array[String] = []
	for rect in rects: values.append("%d,%d,%d,%d" % [rect.position.x, rect.position.y, rect.size.x, rect.size.y])
	return "|".join(values)


static func _point_list_text(points: Array) -> String:
	var values: Array[String] = []
	for point in points: values.append("%d,%d" % [point.x, point.y])
	return "|".join(values)


static func _direction_text(direction: Vector2i) -> String:
	if direction == Vector2i.UP: return "north"
	if direction == Vector2i.RIGHT: return "east"
	if direction == Vector2i.DOWN: return "south"
	if direction == Vector2i.LEFT: return "west"
	return "%d,%d" % [direction.x, direction.y]


static func _quote(value: String) -> String:
	return "\"%s\"" % value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n")
