class_name MapRrmapParseResult
extends RefCounted

var blueprint: MapBlueprint
var definition: MapDefinition
var diagnostics: Array[MapRrmapDiagnostic] = []


func is_ok() -> bool:
	return blueprint != null and definition != null and diagnostics.is_empty()


func formatted_diagnostics() -> Array[String]:
	var formatted: Array[String] = []
	for diagnostic in diagnostics:
		formatted.append(diagnostic.format())
	return formatted
