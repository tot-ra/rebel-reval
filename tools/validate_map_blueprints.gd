extends SceneTree

## Headless semantic validation for every explicitly registered MapBlueprint.
## Exit code is non-zero only for error diagnostics; warnings remain CI-visible.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var entries := MapBlueprintRegistry.entries()
	var error_count := 0
	var warning_count := 0
	var seen_map_ids: Dictionary = {}
	if entries.is_empty():
		push_error("ERROR[MAP_REGISTRY_EMPTY]: no blueprints are registered")
		quit(1)
		return

	for entry in entries:
		var expected_id: StringName = entry.get("id", &"")
		var source := String(entry.get("source", "<unknown>"))
		var blueprint := MapBlueprintRegistry.create_blueprint(entry)
		if blueprint == null:
			error_count += 1
			push_error("ERROR[MAP_REGISTRY_FACTORY_INVALID] (map=%s, source=%s): factory must return MapBlueprint" % [expected_id, source])
			continue
		if blueprint.map_id != expected_id:
			error_count += 1
			push_error("ERROR[MAP_REGISTRY_ID_MISMATCH] (map=%s, source=%s): factory returned map_id '%s'" % [expected_id, source, blueprint.map_id])
		if seen_map_ids.has(blueprint.map_id):
			error_count += 1
			push_error("ERROR[MAP_REGISTRY_ID_DUPLICATE] (map=%s, source=%s): map_id is already registered by %s" % [blueprint.map_id, source, seen_map_ids[blueprint.map_id]])
		else:
			seen_map_ids[blueprint.map_id] = source

		var required_anchors: Array[StringName] = []
		required_anchors.assign(entry.get("required_anchors", []))
		var result := MapBlueprintCompiler.compile_with_diagnostics(blueprint, required_anchors)
		print("VALIDATE %s (%s)" % [blueprint.map_id, source])
		for diagnostic in result.diagnostics:
			print(diagnostic.format())
			if diagnostic.is_error():
				error_count += 1
			else:
				warning_count += 1

	print("Blueprint validation: %d registered, %d error(s), %d warning(s)." % [entries.size(), error_count, warning_count])
	quit(1 if error_count > 0 else 0)
