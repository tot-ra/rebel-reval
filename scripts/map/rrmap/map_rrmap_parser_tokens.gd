class_name MapRrmapParserTokens
extends RefCounted

## Tokenization and typed value coercion for MapRrmapParser. Split out so the
## statement dispatcher stays readable and tokenizer tests can load less code.

const STYLE_NAME_KEYS: Array[String] = [
	"door_side", "ridge_axis", "primitive", "style_variant", "destination_scene_id",
	"destination_spawn_id", "spawn_id", "view_landmark_id", "kind", "door_material", "passage_axis",
]
const STYLE_FLOAT_KEYS: Array[String] = ["wall_height", "wall_height_scale", "top_px", "movement_speed_multiplier"]
const STYLE_COLOR_KEYS: Array[String] = ["wall_color", "roof_color"]
const STYLE_VECTOR_KEYS: Array[String] = ["visual_offset_px", "spawn_offset_px"]
const STYLE_CARDINAL_VECTOR_KEYS: Array[String] = ["facing", "direction"]
const STYLE_RECT_KEYS: Array[String] = ["rect", "cell", "highlight_area"]
const STYLE_BOOL_KEYS: Array[String] = ["enabled", "tower"]

var _parser
func _init(parser) -> void:
	_parser = parser


func tokenize_line(line_text: String, line: int) -> Array[Dictionary]:
	var tokens: Array[Dictionary] = []
	var index := 0
	while index < line_text.length():
		while index < line_text.length() and line_text[index] in [" ", "\t", "\r"]:
			index += 1
		if index >= line_text.length() or line_text[index] == "#":
			break
		var column := index + 1
		var value := ""
		if line_text[index] == "\"":
			index += 1
			var closed := false
			while index < line_text.length():
				var ch := line_text[index]
				if ch == "\"":
					closed = true
					index += 1
					break
				if ch == "\\":
					index += 1
					if index >= line_text.length():
						break
					var escaped := line_text[index]
					if escaped == "n":
						value += "\n"
					elif escaped in ["\"", "\\", "#"]:
						value += escaped
					else:
						_parser._error(line, index, &"invalid_escape", "supported escapes are \\n, \\\", \\\\, and \\#")
						value += escaped
					index += 1
				else:
					value += ch
					index += 1
			if not closed:
				_parser._error(line, column, &"unterminated_string", "quoted string is not closed")
			if index < line_text.length() and line_text[index] not in [" ", "\t", "\r", "#"]:
				_parser._error(line, index + 1, &"missing_whitespace", "quoted strings must be separated by whitespace")
		else:
			while index < line_text.length() and line_text[index] not in [" ", "\t", "\r", "#"]:
				value += line_text[index]
				index += 1
		tokens.append({"text": value, "column": column})
	return tokens


func raw_options(tokens: Array[Dictionary], line: int, start: int) -> Variant:
	var values: Dictionary = {}
	for token in tokens.slice(start):
		var text: String = token["text"]
		var equals := text.find("=")
		if equals <= 0 or equals == text.length() - 1:
			_parser._error(line, token["column"], &"invalid_option", "expected key=value")
			continue
		var key := text.left(equals)
		if values.has(key):
			_parser._error(line, token["column"], &"duplicate_option", "option '%s' may appear only once" % key)
		else:
			values[key] = text.substr(equals + 1)
	return null if _parser._line_has_errors(line) else values


func options(tokens: Array[Dictionary], line: int, start: int, allowed: Array) -> Variant:
	var values = raw_options(tokens, line, start)
	if values == null:
		return null
	for key in values:
		if key not in allowed:
			_parser._error(
				line,
				option_column(tokens, key),
				&"unknown_option",
				"unknown option '%s'; allowed: %s" % [key, ", ".join(allowed)]
			)
	return null if _parser._line_has_errors(line) else values


func typed_options(tokens: Array[Dictionary], line: int, start: int, allow_parent: bool) -> Variant:
	var raw = raw_options(tokens, line, start)
	if raw == null:
		return null
	var values: Dictionary = {}
	for key in raw:
		if allow_parent and key == "parent":
			values[key] = StringName(raw[key])
			continue
		var parsed = typed_field(key, raw[key], line, option_column(tokens, key))
		if parsed != null:
			values[StringName(key)] = parsed
	return null if _parser._line_has_errors(line) else values


func style_and_overrides(tokens: Array[Dictionary], line: int, start: int) -> Variant:
	var raw = raw_options(tokens, line, start)
	if raw == null:
		return null
	return typed_style_raw(raw, tokens, line)


func typed_style_raw(raw: Dictionary, tokens: Array[Dictionary], line: int) -> Variant:
	var style := StringName(raw.get("style", ""))
	raw.erase("style")
	var overrides: Dictionary = {}
	for key in raw:
		var parsed = typed_field(key, raw[key], line, option_column(tokens, key))
		if parsed != null:
			overrides[StringName(key)] = parsed
	return null if _parser._line_has_errors(line) else {"style": style, "overrides": overrides}


func typed_field(key: String, text: String, line: int, column: int) -> Variant:
	if key in STYLE_NAME_KEYS:
		return StringName(text)
	if key in STYLE_FLOAT_KEYS:
		return float_value(text, line, column)
	if key in STYLE_COLOR_KEYS:
		return color_value(text, line, column)
	if key in STYLE_VECTOR_KEYS:
		return csv_number_vector(text, line, column)
	if key in STYLE_CARDINAL_VECTOR_KEYS:
		return cardinal_or_csv_vector(text, line, column)
	if key in STYLE_RECT_KEYS:
		var values := text.split(",", false)
		if key == "cell" and values.size() == 2:
			return csv_vector(text, line, column)
		return csv_rect(text, line, column)
	if key in STYLE_BOOL_KEYS:
		return bool_value(text, line, column)
	_parser._error(line, column, &"unknown_typed_field", "field '%s' is not in the rrmap v1 allowlist" % key)
	return null


func literal(text: String, line: int, column: int) -> Variant:
	if text in ["true", "false"]:
		return text == "true"
	if text.length() in [6, 8] and text.is_valid_hex_number():
		return color_value(text, line, column)
	if text.contains(","):
		return csv_vector(text, line, column)
	if text.is_valid_int():
		return int(text)
	if text.is_valid_float():
		return float(text)
	return StringName(text)


func vector_from_tokens(tokens: Array[Dictionary], line: int, start: int) -> Variant:
	if tokens.size() <= start + 1:
		_parser._error(line, tokens[0]["column"], &"missing_value", "expected two integer coordinates")
		return null
	var x = int_value(tokens[start]["text"], line, tokens[start]["column"])
	var y = int_value(tokens[start + 1]["text"], line, tokens[start + 1]["column"])
	return null if x == null or y == null else Vector2i(x, y)


func rect_from_tokens(tokens: Array[Dictionary], line: int, start: int) -> Variant:
	if tokens.size() <= start + 3:
		_parser._error(line, tokens[0]["column"], &"missing_value", "expected x y width height")
		return null
	var values: Array[int] = []
	for index in 4:
		var parsed = int_value(tokens[start + index]["text"], line, tokens[start + index]["column"])
		if parsed == null:
			return null
		values.append(parsed)
	return Rect2i(values[0], values[1], values[2], values[3])


func csv_vector(text: String, line: int, column: int) -> Variant:
	var parts := text.split(",", false)
	if parts.size() != 2:
		_parser._error(line, column, &"invalid_vector", "expected x,y")
		return null
	var x = int_value(parts[0], line, column)
	var y = int_value(parts[1], line, column + parts[0].length() + 1)
	return null if x == null or y == null else Vector2i(x, y)


func csv_number_vector(text: String, line: int, column: int) -> Variant:
	var parts := text.split(",", false)
	if parts.size() != 2:
		_parser._error(line, column, &"invalid_vector", "expected x,y")
		return null
	var x = float_value(parts[0], line, column)
	var y = float_value(parts[1], line, column + parts[0].length() + 1)
	return null if x == null or y == null else Vector2(x, y)


func cardinal_or_csv_vector(text: String, line: int, column: int) -> Variant:
	if text in ["north", "east", "south", "west"]:
		return cardinal(text, line, column)
	return csv_number_vector(text, line, column)


func csv_rect(text: String, line: int, column: int) -> Variant:
	var parts := text.split(",", false)
	if parts.size() != 4:
		_parser._error(line, column, &"invalid_rect", "expected x,y,width,height")
		return null
	var values: Array[int] = []
	for part in parts:
		var parsed = int_value(part, line, column)
		if parsed == null:
			return null
		values.append(parsed)
	return Rect2i(values[0], values[1], values[2], values[3])


func point_list(text: String, line: int, column: int) -> Variant:
	var points: Array[Vector2i] = []
	for item in text.split("|", false):
		var point = csv_vector(item, line, column)
		if point == null:
			return null
		points.append(point)
	return points


func rect_list(text: String, line: int, column: int) -> Variant:
	var rects: Array[Rect2i] = []
	for item in text.split("|", false):
		var rect = csv_rect(item, line, column)
		if rect == null:
			return null
		rects.append(rect)
	return rects


func int_value(text: String, line: int, column: int) -> Variant:
	if not text.is_valid_int():
		_parser._error(line, column, &"invalid_integer", "expected an integer, got '%s'" % text)
		return null
	return int(text)


func float_value(text: String, line: int, column: int) -> Variant:
	if not text.is_valid_float():
		_parser._error(line, column, &"invalid_number", "expected a number, got '%s'" % text)
		return null
	return float(text)


func bool_value(text: String, line: int, column: int) -> Variant:
	if text not in ["true", "false"]:
		_parser._error(line, column, &"invalid_boolean", "expected true or false, got '%s'" % text)
		return null
	return text == "true"


func color_value(text: String, line: int, column: int) -> Variant:
	if not text.is_valid_hex_number() or text.length() not in [6, 8]:
		_parser._error(line, column, &"invalid_color", "expected RRGGBB or RRGGBBAA")
		return null
	return Color.from_string("#" + text, Color.TRANSPARENT)


func cardinal(text: String, line: int, column: int) -> Variant:
	match text:
		"north":
			return Vector2i.UP
		"east":
			return Vector2i.RIGHT
		"south":
			return Vector2i.DOWN
		"west":
			return Vector2i.LEFT
	_parser._error(line, column, &"invalid_direction", "expected north, east, south, or west")
	return null


func int_option(options: Dictionary, key: String, fallback: int, tokens: Array[Dictionary], line: int) -> int:
	if not options.has(key):
		return fallback
	var value = int_value(options[key], line, option_column(tokens, key))
	return fallback if value == null else value


func take_int(raw: Dictionary, key: String, fallback: int, line: int, tokens: Array[Dictionary]) -> int:
	if not raw.has(key):
		return fallback
	var value = int_value(raw[key], line, option_column(tokens, key))
	raw.erase(key)
	return fallback if value == null else value


func take_bool(raw: Dictionary, key: String, fallback: bool, line: int, tokens: Array[Dictionary]) -> bool:
	if not raw.has(key):
		return fallback
	var value = bool_value(raw[key], line, option_column(tokens, key))
	raw.erase(key)
	return fallback if value == null else value


func arity(tokens: Array[Dictionary], line: int, minimum: int, usage: String) -> bool:
	if tokens.size() >= minimum:
		return true
	_parser._error(line, tokens[0]["column"], &"wrong_arity", "usage: %s" % usage)
	return false


func exact_arity(tokens: Array[Dictionary], line: int, count: int, usage: String) -> bool:
	if tokens.size() == count:
		return true
	_parser._error(line, tokens[0]["column"], &"wrong_arity", "usage: %s" % usage)
	return false


func option_column(tokens: Array[Dictionary], key: String) -> int:
	for token in tokens:
		if String(token["text"]).begins_with(key + "="):
			return token["column"]
	return tokens[0]["column"]
