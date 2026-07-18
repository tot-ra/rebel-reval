class_name MapRrmapParser
extends RefCounted

## Strict line parser for rrmap v1. It recognizes only the commands and typed
## fields below, so source text can never invoke GDScript or load arbitrary code.

const FORMAT_VERSION := 1

const _TokensScript := preload("res://scripts/map/rrmap/map_rrmap_parser_tokens.gd")
const _StatementsScript := preload("res://scripts/map/rrmap/map_rrmap_parser_statements.gd")

var _path := "<memory>"
var _result: MapRrmapParseResult
var _blueprint: MapBlueprint
var _map_line := 1
var _packages: Dictionary = {}
var _source_locations: Dictionary = {}

var _tokens
var _statements


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
	return MapRrmapSerializer.canonical_print(blueprint, FORMAT_VERSION)


func _parse(text: String, source_path: String) -> MapRrmapParseResult:
	_path = source_path
	_result = MapRrmapParseResult.new()
	_tokens = _TokensScript.new(self)
	_statements = _StatementsScript.new(self, _tokens)
	var lines := text.split("\n", true)
	var saw_header := false
	for index in lines.size():
		var line_number := index + 1
		var tokens = _tokens.tokenize_line(lines[index], line_number)
		if tokens.is_empty():
			continue
		if not saw_header:
			saw_header = true
			_statements.parse_header(tokens, line_number)
			continue
		_statements.parse_statement(tokens, line_number)
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


func _error(line: int, column: int, code: StringName, message: String) -> void:
	_result.diagnostics.append(MapRrmapDiagnostic.new(_path, line, maxi(column, 1), code, message))


func _line_has_errors(line: int) -> bool:
	for diagnostic in _result.diagnostics:
		if diagnostic.line == line:
			return true
	return false


func _has_error(code: StringName) -> bool:
	for diagnostic in _result.diagnostics:
		if diagnostic.code == code:
			return true
	return false


func _diagnostic_location(message: String) -> Vector2i:
	# Compiler diagnostics name semantic IDs. Point them back to the declaring
	# token when possible, while metadata errors remain on the map statement.
	for id in _source_locations:
		if message.contains("'%s'" % id) or message.contains(" %s" % id):
			return _source_locations[id]
	return Vector2i(_map_line, 1)
