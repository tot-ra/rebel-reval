class_name MapRrmapParseResult
extends RefCounted

var blueprint: MapBlueprint
var definition: MapDefinition
var diagnostics: Array[MapRrmapDiagnostic] = []


func is_ok() -> bool:
	if blueprint == null or definition == null:
		return false
	for diagnostic in diagnostics:
		if diagnostic.severity == &"error":
			return false
	return true


func formatted_diagnostics() -> Array[String]:
	var formatted: Array[String] = []
	for diagnostic in diagnostics:
		formatted.append(diagnostic.format())
	return formatted
