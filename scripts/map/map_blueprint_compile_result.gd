class_name MapBlueprintCompileResult
extends RefCounted

var definition: MapDefinition
## Compatibility view for existing callers. New tooling should consume diagnostics.
var errors: Array[String] = []
var diagnostics: Array[MapBlueprintDiagnostic] = []


func is_ok() -> bool:
	return definition != null and not has_errors()


func has_errors() -> bool:
	if not errors.is_empty():
		return true
	for diagnostic in diagnostics:
		if diagnostic.is_error():
			return true
	return false


func warnings() -> Array[MapBlueprintDiagnostic]:
	var result: Array[MapBlueprintDiagnostic] = []
	for diagnostic in diagnostics:
		if diagnostic.severity == MapBlueprintDiagnostic.SEVERITY_WARNING:
			result.append(diagnostic)
	return result


func add_diagnostic(diagnostic: MapBlueprintDiagnostic) -> void:
	diagnostics.append(diagnostic)
	if diagnostic.is_error():
		errors.append(diagnostic.message)


func import_legacy_errors(map_id: StringName = &"") -> void:
	var existing_messages: Dictionary = {}
	for diagnostic in diagnostics:
		existing_messages[diagnostic.message] = true
	for message in errors:
		if not existing_messages.has(message):
			diagnostics.append(MapBlueprintDiagnostic.from_compiler_error(message, map_id))
	_sort_diagnostics()


func formatted_diagnostics() -> Array[String]:
	var formatted: Array[String] = []
	for diagnostic in diagnostics:
		formatted.append(diagnostic.format())
	return formatted


func _sort_diagnostics() -> void:
	diagnostics.sort_custom(func(left: MapBlueprintDiagnostic, right: MapBlueprintDiagnostic) -> bool:
		return [String(left.severity), String(left.code), left.path, String(left.subject), left.message] < \
			[String(right.severity), String(right.code), right.path, String(right.subject), right.message]
	)
