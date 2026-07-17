class_name RrmapResourceFormatLoader
extends ResourceFormatLoader

## Editor loader for declarative .rrmap sources. Loading parses into MapBlueprint
## and compiles through MapBlueprintCompiler before exposing a Resource wrapper.


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["rrmap"])


func _handles_type(type: StringName) -> bool:
	return type == &"RrmapResource" or type == &"Resource"


func _get_resource_type(path: String) -> String:
	return "RrmapResource" if path.get_extension().to_lower() == "rrmap" else ""


func _load(
	path: String,
	_original_path: String,
	_use_sub_threads: bool,
	_cache_mode: int
) -> Variant:
	var parsed := MapRrmapParser.parse_file(path)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return ERR_PARSE_ERROR
	var resource := RrmapResource.new()
	resource.source_path = path
	resource.source_text = FileAccess.get_file_as_string(path)
	resource.blueprint = parsed.blueprint
	resource.definition = parsed.definition
	resource.diagnostics = parsed.diagnostics
	return resource
