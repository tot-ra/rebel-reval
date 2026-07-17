class_name MapBlueprintDiagnostic
extends RefCounted

## Stable, machine-readable diagnostic emitted by blueprint compilation and
## post-compile semantic validation. Codes are API: tooling may branch on them.

const SEVERITY_ERROR := &"error"
const SEVERITY_WARNING := &"warning"

var code: StringName
var severity: StringName
var message: String
var map_id: StringName
var path: String
var subject: StringName
var details: Dictionary


func _init(
	code_value: StringName,
	severity_value: StringName,
	message_value: String,
	map_id_value: StringName = &"",
	path_value: String = "",
	subject_value: StringName = &"",
	details_value: Dictionary = {}
) -> void:
	code = code_value
	severity = severity_value
	message = message_value
	map_id = map_id_value
	path = path_value
	subject = subject_value
	details = details_value.duplicate(true)


func is_error() -> bool:
	return severity == SEVERITY_ERROR


func format() -> String:
	var context: Array[String] = []
	if not map_id.is_empty():
		context.append("map=%s" % String(map_id))
	if not path.is_empty():
		context.append("path=%s" % path)
	if not subject.is_empty():
		context.append("subject=%s" % String(subject))
	var suffix := " (%s)" % ", ".join(context) if not context.is_empty() else ""
	return "%s[%s]%s: %s" % [String(severity).to_upper(), String(code), suffix, message]


func to_dict() -> Dictionary:
	return {
		"code": String(code),
		"severity": String(severity),
		"message": message,
		"map_id": String(map_id),
		"path": path,
		"subject": String(subject),
		"details": details.duplicate(true),
	}


static func from_compiler_error(message_value: String, map_id_value: StringName = &"") -> MapBlueprintDiagnostic:
	var code_value := _classify_compiler_error(message_value)
	return MapBlueprintDiagnostic.new(
		code_value,
		SEVERITY_ERROR,
		message_value,
		map_id_value,
		_extract_path(message_value),
		_extract_subject(message_value)
	)


static func _classify_compiler_error(message_value: String) -> StringName:
	var text := message_value.to_lower()
	if "duplicate" in text and (" id" in text or "stable id" in text or "source id" in text):
		return &"MAP_ID_DUPLICATE"
	if "invalid stable id" in text or "reserved namespace separator" in text or (".id" in text and "is required" in text):
		return &"MAP_ID_UNSTABLE"
	if "unknown style" in text or "unknown parent style" in text:
		return &"MAP_STYLE_UNKNOWN"
	if "terrain is unknown" in text or "base_terrain is unknown" in text or "unknown base_terrain" in text:
		return &"MAP_TERRAIN_UNKNOWN"
	if "kind is unknown" in text or "unknown building kind" in text or "unknown prop kind" in text:
		return &"MAP_KIND_UNKNOWN"
	if "outside map bounds" in text or "outside world bounds" in text:
		return &"MAP_GEOMETRY_OUT_OF_BOUNDS"
	if "positive size" in text or "size_cells must be positive" in text or "cell_size must be positive" in text or "thickness must be positive" in text:
		return &"MAP_SIZE_INVALID"
	if "recursive prefab" in text or "maximum prefab nesting depth" in text:
		return &"MAP_PREFAB_RECURSION"
	if "override targets unknown" in text or "targets unknown prefab object" in text:
		return &"MAP_OVERRIDE_TARGET_MISSING"
	if message_value.begins_with("compiled MapDefinition:"):
		return &"MAP_RUNTIME_CONTRACT"
	return &"MAP_COMPILE_ERROR"


static func _extract_path(message_value: String) -> String:
	var first_token := message_value.get_slice(" ", 0).trim_suffix(":")
	if "[" in first_token or "." in first_token:
		return first_token
	return ""


static func _extract_subject(message_value: String) -> StringName:
	for marker in ["stable id: ", "source id: ", "unknown object: ", "unknown prefab object: "]:
		var offset := message_value.find(marker)
		if offset >= 0:
			var value := message_value.substr(offset + marker.length()).get_slice(" ", 0).trim_suffix(",")
			return StringName(value)
	return &""
