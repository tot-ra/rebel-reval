class_name MapBlueprintCompileResult
extends RefCounted

var definition: MapDefinition
var errors: Array[String] = []


func is_ok() -> bool:
	return definition != null and errors.is_empty()
