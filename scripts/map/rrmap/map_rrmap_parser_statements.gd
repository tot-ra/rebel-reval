class_name MapRrmapParserStatements
extends RefCounted

## rrmap v1 statement dispatch. Split from MapRrmapParser so tokenizer/value code
## can evolve independently.

const _URBAN_PACKAGE := preload("res://scripts/map/prefabs/urban_prefab_package.gd")

var _parser
var _tokens


func _init(parser, tokens) -> void:
	_parser = parser
	_tokens = tokens


func parse_header(tokens: Array[Dictionary], line: int) -> void:
	if tokens.size() != 2 or tokens[0]["text"] != "rrmap":
		_parser._error(line, tokens[0]["column"], &"invalid_header", "expected exactly 'rrmap 1'")
		return
	var version_text: String = tokens[1]["text"]
	if not version_text.is_valid_int():
		_parser._error(line, tokens[1]["column"], &"invalid_version", "format version must be an integer")
		return
	var version := int(version_text)
	if version == 1:
		return
	if version == 0:
		_parser._error(
			line,
			tokens[1]["column"],
			&"version_migration_required",
			"rrmap 0 is obsolete; migrate the header to 'rrmap 1' and validate the file"
		)
	else:
		_parser._error(
			line,
			tokens[1]["column"],
			&"unsupported_version",
			"unsupported rrmap version %d; this build supports only version %d" % [version, 1]
		)


func parse_statement(tokens: Array[Dictionary], line: int) -> void:
	var command: String = tokens[0]["text"]
	if command != "map" and tokens.size() > 1:
		_parser._source_locations[tokens[1]["text"]] = Vector2i(line, tokens[1]["column"])
	if command == "map":
		_parse_map(tokens, line)
		return
	if _parser._blueprint == null:
		_parser._error(line, tokens[0]["column"], &"map_required", "map must be declared before '%s'" % command)
		return
	match command:
		"source":
			_parse_source(tokens, line)
		"surroundings":
			_parse_surroundings(tokens, line)
		"camera":
			_parse_camera(tokens, line)
		"style":
			_parse_style(tokens, line)
		"terrain":
			_parse_terrain(tokens, line)
		"terrain_rects":
			_parse_terrain_rects(tokens, line)
		"stroke":
			_parse_stroke(tokens, line)
		"building":
			_parse_building(tokens, line)
		"wall":
			_parse_wall(tokens, line)
		"prop":
			_parse_prop(tokens, line)
		"spawn":
			_parse_spawn(tokens, line)
		"transition":
			_parse_transition(tokens, line)
		"anchor":
			_parse_anchor(tokens, line)
		"patrol":
			_parse_patrol(tokens, line)
		"exclude":
			_parse_simple_rect(tokens, line, &"exclude")
		"fade":
			_parse_simple_rect(tokens, line, &"fade")
		"sign":
			_parse_sign(tokens, line)
		"landmark":
			_parse_landmark(tokens, line)
		"package":
			_parse_package(tokens, line)
		"prefab":
			_parse_prefab(tokens, line)
		"override":
			_parse_override(tokens, line)
		_:
			_parser._error(line, tokens[0]["column"], &"unknown_command", "unknown command '%s'" % command)


func _parse_map(tokens: Array[Dictionary], line: int) -> void:
	if _parser._blueprint != null:
		_parser._error(line, tokens[0]["column"], &"duplicate_map", "only one map statement is allowed")
		return
	if not _tokens.arity(tokens, line, 6, "map <id> <location> <width> <height> <base_terrain> [key=value ...]"):
		return
	var size = _tokens.vector_from_tokens(tokens, line, 3)
	if size == null:
		return
	var options = _tokens.options(tokens, line, 6, ["scope", "active", "palette", "seed", "cell_size", "elevation"])
	if options == null:
		return
	_parser._blueprint = MapBlueprint.new(
		StringName(tokens[1]["text"]), StringName(tokens[2]["text"]), size, StringName(tokens[5]["text"])
	)
	_parser._map_line = line
	if options.has("scope"):
		_parser._blueprint.scope = StringName(options["scope"])
	if options.has("active"):
		var active = _tokens.bool_value(options["active"], line, _tokens.option_column(tokens, "active"))
		if active != null:
			_parser._blueprint.active = active
	if options.has("palette"):
		_parser._blueprint.palette = StringName(options["palette"])
	if options.has("seed"):
		var seed = _tokens.int_value(options["seed"], line, _tokens.option_column(tokens, "seed"))
		if seed != null:
			_parser._blueprint.seed = seed
	if options.has("cell_size"):
		var cell_size = _tokens.int_value(options["cell_size"], line, _tokens.option_column(tokens, "cell_size"))
		if cell_size != null:
			_parser._blueprint.cell_size = cell_size
	if options.has("elevation"):
		var elevation = _tokens.float_value(options["elevation"], line, _tokens.option_column(tokens, "elevation"))
		if elevation != null:
			_parser._blueprint.ground_elevation = elevation


func _parse_source(tokens: Array[Dictionary], line: int) -> void:
	if _tokens.exact_arity(tokens, line, 2, "source <quoted_path>"):
		_parser._blueprint.add_source_reference(tokens[1]["text"])


func _parse_surroundings(tokens: Array[Dictionary], line: int) -> void:
	if tokens.size() < 2:
		_parser._error(line, tokens[0]["column"], &"invalid_surroundings", "expected surroundings <side> [<kind>] ...")
		return
	var sides: Dictionary = {}
	var index := 1
	while index < tokens.size():
		var side_text: String = tokens[index]["text"]
		if side_text not in ["north", "east", "south", "west"]:
			_parser._error(line, tokens[index]["column"], &"invalid_side", "expected north, east, south, or west")
			return
		var side := StringName(side_text)
		if sides.has(side):
			_parser._error(line, tokens[index]["column"], &"duplicate_side", "duplicate surroundings side: %s" % side_text)
			return
		index += 1
		var kind := &"town"
		if index < tokens.size() and tokens[index]["text"] in ["town", "water", "woodland"]:
			kind = StringName(tokens[index]["text"])
			index += 1
		sides[side] = kind
	_parser._blueprint.surroundings_sides = sides
	var town_sides: Array[StringName] = []
	for side in sides.keys():
		if sides[side] == &"town":
			town_sides.append(side)
	town_sides.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	_parser._blueprint.surroundings_town_sides = town_sides


func _parse_camera(tokens: Array[Dictionary], line: int) -> void:
	var rect = _tokens.rect_from_tokens(tokens, line, 1)
	if rect != null and _tokens.exact_arity(tokens, line, 5, "camera <x> <y> <width> <height>"):
		_parser._blueprint.camera_bounds(rect)


func _parse_style(tokens: Array[Dictionary], line: int) -> void:
	if not _tokens.arity(tokens, line, 2, "style <id> [parent=<id>] [typed_key=value] ..."):
		return
	var parsed: Dictionary = {}
	if tokens.size() >= 3:
		var options = _tokens.typed_options(tokens, line, 2, true)
		if options == null:
			return
		parsed = options
	var parent: StringName = StringName(parsed["parent"] if parsed.has("parent") else "")
	parsed.erase("parent")
	_parser._blueprint.style(StringName(tokens[1]["text"]), parsed, parent)


func _parse_terrain(tokens: Array[Dictionary], line: int) -> void:
	if not _tokens.arity(
		tokens,
		line,
		7,
		"terrain <id> <terrain> <x> <y> <width> <height> [layer=N] [order=N] [style=id]"
	):
		return
	var rect = _tokens.rect_from_tokens(tokens, line, 3)
	var options = _tokens.options(tokens, line, 7, ["layer", "order", "style"])
	if rect == null or options == null:
		return
	_parser._blueprint.terrain_rect(
		StringName(tokens[1]["text"]),
		StringName(tokens[2]["text"]),
		rect,
		_tokens.int_option(options, "layer", 0, tokens, line),
		_tokens.int_option(options, "order", 0, tokens, line),
		StringName(options.get("style", ""))
	)


func _parse_terrain_rects(tokens: Array[Dictionary], line: int) -> void:
	if not _tokens.arity(
		tokens,
		line,
		4,
		"terrain_rects <id> <terrain> <x,y,w,h|...> [layer=N] [order=N] [style=id]"
	):
		return
	var rects = _tokens.rect_list(tokens[3]["text"], line, tokens[3]["column"])
	var options = _tokens.options(tokens, line, 4, ["layer", "order", "style"])
	if rects == null or options == null:
		return
	_parser._blueprint.terrain_rects(
		StringName(tokens[1]["text"]),
		StringName(tokens[2]["text"]),
		rects,
		_tokens.int_option(options, "layer", 0, tokens, line),
		_tokens.int_option(options, "order", 0, tokens, line),
		StringName(options.get("style", ""))
	)


func _parse_stroke(tokens: Array[Dictionary], line: int) -> void:
	if not _tokens.arity(
		tokens,
		line,
		4,
		"stroke <id> <terrain> <x,y|...> [thickness=N] [layer=N] [order=N] [style=id]"
	):
		return
	var points = _tokens.point_list(tokens[3]["text"], line, tokens[3]["column"])
	var options = _tokens.options(tokens, line, 4, ["thickness", "layer", "order", "style"])
	if points == null or options == null:
		return
	_parser._blueprint.terrain_stroke(
		StringName(tokens[1]["text"]),
		StringName(tokens[2]["text"]),
		points,
		_tokens.int_option(options, "thickness", 1, tokens, line),
		_tokens.int_option(options, "layer", 0, tokens, line),
		_tokens.int_option(options, "order", 0, tokens, line),
		StringName(options.get("style", ""))
	)


func _parse_building(tokens: Array[Dictionary], line: int) -> void:
	if not _tokens.arity(
		tokens,
		line,
		7,
		"building <id> <kind> <x> <y> <width> <height> [style=id] [transition_visual=door|ground|none] [typed overrides]"
	):
		return
	var rect = _tokens.rect_from_tokens(tokens, line, 3)
	var split = _tokens.style_and_overrides(tokens, line, 7)
	if rect == null or split == null:
		return
	_parser._blueprint.structure_rect(
		StringName(tokens[1]["text"]),
		StringName(tokens[2]["text"]),
		rect,
		split["style"],
		split["overrides"]
	)


func _parse_wall(tokens: Array[Dictionary], line: int) -> void:
	if not _tokens.arity(
		tokens,
		line,
		6,
		"wall <id> <x1> <y1> <x2> <y2> [thickness=N] [openings=x,y,w,h|...] [kind=wall] [style=id] [typed overrides]"
	):
		return
	var start = _tokens.vector_from_tokens(tokens, line, 2)
	var end = _tokens.vector_from_tokens(tokens, line, 4)
	var raw = _tokens.raw_options(tokens, line, 6)
	if start == null or end == null or raw == null:
		return
	var thickness = _tokens.take_int(raw, "thickness", 1, line, tokens)
	var openings: Array[Rect2i] = []
	if raw.has("openings"):
		var parsed = _tokens.rect_list(raw["openings"], line, _tokens.option_column(tokens, "openings"))
		raw.erase("openings")
		if parsed == null:
			return
		openings = parsed
	var kind := StringName(raw.get("kind", "wall"))
	raw.erase("kind")
	var split = _tokens.typed_style_raw(raw, tokens, line)
	if split == null:
		return
	_parser._blueprint.wall_run(
		StringName(tokens[1]["text"]),
		start,
		end,
		thickness,
		openings,
		split["style"],
		split["overrides"],
		kind
	)


func _parse_prop(tokens: Array[Dictionary], line: int) -> void:
	if not _tokens.arity(
		tokens,
		line,
		5,
		"prop <id> <kind> <x> <y> [rect=width,height] [style=id] [typed overrides]"
	):
		return
	var cell = _tokens.vector_from_tokens(tokens, line, 3)
	var raw = _tokens.raw_options(tokens, line, 5)
	if cell == null or raw == null:
		return
	var rect_size = null
	if raw.has("rect"):
		rect_size = _tokens.csv_vector(raw["rect"], line, _tokens.option_column(tokens, "rect"))
		raw.erase("rect")
	var split = _tokens.typed_style_raw(raw, tokens, line)
	if split == null:
		return
	if rect_size == null:
		_parser._blueprint.prop(
			StringName(tokens[1]["text"]),
			StringName(tokens[2]["text"]),
			cell,
			split["style"],
			split["overrides"]
		)
	else:
		_parser._blueprint.prop_rect(
			StringName(tokens[1]["text"]),
			StringName(tokens[2]["text"]),
			Rect2i(cell, rect_size),
			split["style"],
			split["overrides"]
		)


func _parse_spawn(tokens: Array[Dictionary], line: int) -> void:
	if not _tokens.arity(tokens, line, 4, "spawn <id> <x> <y> [rect=width,height]"):
		return
	var cell = _tokens.vector_from_tokens(tokens, line, 2)
	var options = _tokens.options(tokens, line, 4, ["rect"])
	if cell == null or options == null:
		return
	if options.has("rect"):
		var size = _tokens.csv_vector(options["rect"], line, _tokens.option_column(tokens, "rect"))
		if size != null:
			_parser._blueprint.player_spawn_rect(StringName(tokens[1]["text"]), Rect2i(cell, size))
	else:
		_parser._blueprint.player_spawn(StringName(tokens[1]["text"]), cell)


func _parse_transition(tokens: Array[Dictionary], line: int) -> void:
	if not _tokens.arity(
		tokens,
		line,
		6,
		"transition <id> <x> <y> <width> <height> [to=id] [destination_spawn=id] [spawn=id] [style=id] [typed overrides]"
	):
		return
	var rect = _tokens.rect_from_tokens(tokens, line, 2)
	var raw = _tokens.raw_options(tokens, line, 6)
	if rect == null or raw == null:
		return
	var destination = StringName(raw.get("to", ""))
	raw.erase("to")
	var destination_spawn = StringName(raw.get("destination_spawn", ""))
	raw.erase("destination_spawn")
	var spawn_id = StringName(raw.get("spawn", ""))
	raw.erase("spawn")
	var split = _tokens.typed_style_raw(raw, tokens, line)
	if split == null:
		return
	_parser._blueprint.transition(
		StringName(tokens[1]["text"]),
		rect,
		destination,
		destination_spawn,
		spawn_id,
		split["style"],
		split["overrides"]
	)


func _parse_anchor(tokens: Array[Dictionary], line: int) -> void:
	if not _tokens.arity(
		tokens,
		line,
		4,
		"anchor <id> <x> <y> [kind=id] [rect=width,height] [style=id] [typed overrides]"
	):
		return
	var cell = _tokens.vector_from_tokens(tokens, line, 2)
	var raw = _tokens.raw_options(tokens, line, 4)
	if cell == null or raw == null:
		return
	var kind := StringName(raw.get("kind", ""))
	raw.erase("kind")
	var rect_size = null
	if raw.has("rect"):
		rect_size = _tokens.csv_vector(raw["rect"], line, _tokens.option_column(tokens, "rect"))
		raw.erase("rect")
	var split = _tokens.typed_style_raw(raw, tokens, line)
	if split == null:
		return
	if rect_size == null:
		_parser._blueprint.interaction_anchor(
			StringName(tokens[1]["text"]),
			cell,
			kind,
			split["style"],
			split["overrides"]
		)
	else:
		_parser._blueprint.interaction_anchor_rect(
			StringName(tokens[1]["text"]),
			Rect2i(cell, rect_size),
			kind,
			split["style"],
			split["overrides"]
		)


func _parse_patrol(tokens: Array[Dictionary], line: int) -> void:
	if not _tokens.exact_arity(tokens, line, 3, "patrol <id> <x,y|...>"):
		return
	var points = _tokens.point_list(tokens[2]["text"], line, tokens[2]["column"])
	if points != null:
		_parser._blueprint.patrol_path(StringName(tokens[1]["text"]), points)


func _parse_simple_rect(tokens: Array[Dictionary], line: int, kind: StringName) -> void:
	if not _tokens.exact_arity(tokens, line, 6, "%s <id> <x> <y> <width> <height>" % kind):
		return
	var rect = _tokens.rect_from_tokens(tokens, line, 2)
	if rect == null:
		return
	if kind == &"exclude":
		_parser._blueprint.excluded_rect(StringName(tokens[1]["text"]), rect)
	else:
		_parser._blueprint.fade_rect(StringName(tokens[1]["text"]), rect)


func _parse_sign(tokens: Array[Dictionary], line: int) -> void:
	if not _tokens.arity(
		tokens,
		line,
		6,
		"sign <id> <quoted_text> <x> <y> <north|east|south|west> [style=id] [typed overrides]"
	):
		return
	var cell = _tokens.vector_from_tokens(tokens, line, 3)
	var direction = _tokens.cardinal(tokens[5]["text"], line, tokens[5]["column"])
	var split = _tokens.style_and_overrides(tokens, line, 6)
	if cell != null and direction != null and split != null:
		_parser._blueprint.direction_sign(
			StringName(tokens[1]["text"]),
			tokens[2]["text"],
			cell,
			direction,
			split["style"],
			split["overrides"]
		)


func _parse_landmark(tokens: Array[Dictionary], line: int) -> void:
	if not _tokens.arity(
		tokens,
		line,
		7,
		"landmark <id> <kind> <x> <y> <width> <height> [style=id] [typed overrides]"
	):
		return
	var rect = _tokens.rect_from_tokens(tokens, line, 3)
	var split = _tokens.style_and_overrides(tokens, line, 7)
	if rect != null and split != null:
		_parser._blueprint.view_landmark(
			StringName(tokens[1]["text"]),
			StringName(tokens[2]["text"]),
			rect,
			split["style"],
			split["overrides"]
		)


func _parse_package(tokens: Array[Dictionary], line: int) -> void:
	if not _tokens.exact_arity(tokens, line, 3, "package urban 1"):
		return
	if tokens[1]["text"] != "urban" or tokens[2]["text"] != "1":
		_parser._error(
			line,
			tokens[1]["column"],
			&"unknown_package",
			"only the reviewed package 'urban 1' is allowlisted in rrmap v1"
		)
		return
	if _parser._packages.has("urban"):
		_parser._error(line, tokens[1]["column"], &"duplicate_package", "package 'urban' is already registered")
		return
	var package = _URBAN_PACKAGE.create()
	_parser._packages["urban"] = package
	_parser._blueprint.use_prefab_package(package)


func _parse_prefab(tokens: Array[Dictionary], line: int) -> void:
	if not _tokens.arity(
		tokens,
		line,
		5,
		"prefab <instance_id> <qualified_prefab_id> <x> <y> [rotation=0|90|180|270] [mirror_x=bool] [mirror_y=bool] [param.<name>=typed]"
	):
		return
	var origin = _tokens.vector_from_tokens(tokens, line, 3)
	var raw = _tokens.raw_options(tokens, line, 5)
	if origin == null or raw == null:
		return
	var rotation = _tokens.take_int(raw, "rotation", 0, line, tokens)
	var mirror_x = _tokens.take_bool(raw, "mirror_x", false, line, tokens)
	var mirror_y = _tokens.take_bool(raw, "mirror_y", false, line, tokens)
	var parameters: Dictionary = {}
	for key in raw.keys():
		if not String(key).begins_with("param."):
			_parser._error(
				line,
				_tokens.option_column(tokens, key),
				&"unknown_option",
				"prefab option '%s' is not supported; use param.<name>" % key
			)
			continue
		var parsed = _tokens.literal(raw[key], line, _tokens.option_column(tokens, key))
		if parsed != null:
			parameters[StringName(String(key).trim_prefix("param."))] = parsed
	if not _parser._result.diagnostics.is_empty():
		return
	_parser._blueprint.prefab_instance(
		StringName(tokens[1]["text"]),
		StringName(tokens[2]["text"]),
		origin,
		MapTransform.new(rotation, mirror_x, mirror_y),
		parameters
	)


func _parse_override(tokens: Array[Dictionary], line: int) -> void:
	if not _tokens.arity(tokens, line, 3, "override <resolved_object_id> <typed_key=value> ..."):
		return
	var values = _tokens.typed_options(tokens, line, 2, false)
	if values != null:
		_parser._blueprint.override_object(StringName(tokens[1]["text"]), values)
