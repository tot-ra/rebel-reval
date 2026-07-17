class_name MapRrmapDiagnostic
extends RefCounted

## One source-oriented parser or compiler diagnostic.

var source_path: String
var line: int
var column: int
var code: StringName
var message: String
var severity: StringName


func _init(
	path_value: String,
	line_value: int,
	column_value: int,
	code_value: StringName,
	message_value: String,
	severity_value: StringName = &"error"
) -> void:
	source_path = path_value
	line = line_value
	column = column_value
	code = code_value
	message = message_value
	severity = severity_value


func format() -> String:
	return "%s:%d:%d: %s[%s]: %s" % [source_path, line, column, String(severity), String(code), message]
