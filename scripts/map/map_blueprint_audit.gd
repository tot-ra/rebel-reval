class_name MapBlueprintAudit
extends RefCounted

## Repository-wide blueprint registry audit. Discovery is used only to prove the
## explicit registry is complete; registry order remains the deterministic source
## of factories and per-map semantic requirements.

const BLUEPRINT_ROOT := "res://scripts/map/definitions"
const RRMAP_ROOTS: Array[String] = ["res://content/maps"]


static func run() -> Array[MapBlueprintDiagnostic]:
	var diagnostics: Array[MapBlueprintDiagnostic] = []
	var entries := MapBlueprintRegistry.entries()
	var registered_sources: Dictionary = {}
	var registered_ids: Dictionary = {}

	if entries.is_empty():
		diagnostics.append(_diagnostic(&"MAP_REGISTRY_EMPTY", "no blueprints are registered"))
		return diagnostics

	for entry in entries:
		var expected_id := StringName(String(entry.get("id", "")))
		var source := String(entry.get("source", ""))
		if expected_id.is_empty() or source.is_empty():
			diagnostics.append(_diagnostic(&"MAP_REGISTRY_ENTRY_INVALID", "registry entries require id and source", expected_id, source))
			continue
		if registered_ids.has(String(expected_id)):
			diagnostics.append(_diagnostic(&"MAP_REGISTRY_ID_DUPLICATE", "map_id is already registered by %s" % registered_ids[String(expected_id)], expected_id, source))
		else:
			registered_ids[String(expected_id)] = source
		if registered_sources.has(source):
			diagnostics.append(_diagnostic(&"MAP_REGISTRY_SOURCE_DUPLICATE", "source is registered more than once", expected_id, source))
		else:
			registered_sources[source] = true

		var blueprint := MapBlueprintRegistry.create_blueprint(entry)
		if blueprint == null:
			diagnostics.append(_diagnostic(&"MAP_REGISTRY_FACTORY_INVALID", "factory must return MapBlueprint", expected_id, source))
			continue
		if blueprint.map_id != expected_id:
			diagnostics.append(_diagnostic(&"MAP_REGISTRY_ID_MISMATCH", "factory returned map_id '%s'" % blueprint.map_id, expected_id, source))
		var required_anchors: Array[StringName] = []
		required_anchors.assign(entry.get("required_anchors", []))
		var result := MapBlueprintCompiler.compile_with_diagnostics(blueprint, required_anchors)
		for diagnostic in result.diagnostics:
			diagnostic.path = source if diagnostic.path.is_empty() else diagnostic.path
			diagnostics.append(diagnostic)

	for source in discover_blueprint_sources():
		if not registered_sources.has(source):
			diagnostics.append(_diagnostic(
			&"MAP_REGISTRY_SOURCE_MISSING",
			"blueprint source is not present in MapBlueprintRegistry",
			&"",
			source
		))
	return diagnostics


static func discover_blueprint_sources() -> Array[String]:
	var sources: Array[String] = []
	_discover(BLUEPRINT_ROOT, "_blueprint.gd", sources)
	for root in RRMAP_ROOTS:
		_discover(root, ".rrmap", sources)
	sources.sort()
	return sources


static func _discover(root: String, suffix: String, output: Array[String]) -> void:
	var directory := DirAccess.open(root)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var path := root.path_join(entry)
			if directory.current_is_dir():
				_discover(path, suffix, output)
			elif entry.ends_with(suffix):
				output.append(path)
		entry = directory.get_next()
	directory.list_dir_end()


static func _diagnostic(
	code: StringName,
	message: String,
	map_id: StringName = &"",
	path: String = ""
) -> MapBlueprintDiagnostic:
	return MapBlueprintDiagnostic.new(
		code,
		MapBlueprintDiagnostic.SEVERITY_ERROR,
		message,
		map_id,
		path
	)
