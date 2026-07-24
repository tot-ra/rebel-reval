extends SceneTree

## Headless composition audit for every enforced map in map_composition_thresholds.json.

const MapCompositionAudit := preload("res://scripts/map/map_composition_audit.gd")
const THRESHOLDS_PATH := "res://docs/data/map_composition_thresholds.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var thresholds_doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(THRESHOLDS_PATH))
	if thresholds_doc == null or not thresholds_doc is Dictionary:
		push_error("ERROR[MAP_COMPOSITION_THRESHOLDS_INVALID]: could not parse %s" % THRESHOLDS_PATH)
		quit(1)
		return

	var map_thresholds: Dictionary = thresholds_doc.get("maps", {})
	var error_count := 0
	var audited := 0
	for entry in MapBlueprintRegistry.entries():
		var map_id := String(entry.get("id", ""))
		if not map_thresholds.has(map_id):
			push_error(
				"ERROR[MAP_COMPOSITION_THRESHOLDS_MISSING] (map=%s): no threshold card" % map_id
			)
			error_count += 1
			continue
		var card: Dictionary = map_thresholds[map_id]
		if card.get("enforce", true) == false:
			print("SKIP %s (enforce=false)" % map_id)
			continue
		var blueprint := MapBlueprintRegistry.create_blueprint(entry)
		if blueprint == null:
			push_error("ERROR[MAP_COMPOSITION_FACTORY_INVALID] (map=%s)" % map_id)
			error_count += 1
			continue
		var required_anchors: Array[StringName] = []
		required_anchors.assign(entry.get("required_anchors", []))
		var result := MapBlueprintCompiler.compile_with_diagnostics(
			blueprint,
			required_anchors
		)
		if not result.diagnostics.is_empty():
			var blocked := false
			for diagnostic in result.diagnostics:
				if diagnostic.is_error():
					push_error(diagnostic.format())
					error_count += 1
					blocked = true
			if blocked:
				continue
		var definition := result.definition
		var grid := MapBuilder.build(definition)
		var violations := MapCompositionAudit.audit(definition, grid, card)
		audited += 1
		print("AUDIT %s" % map_id)
		if violations.is_empty():
			print("  pass")
			continue
		for violation in violations:
			push_error(MapCompositionAudit.format_violation(violation))
			error_count += 1

	print("Composition audit: %d enforced map(s), %d error(s)." % [audited, error_count])
	quit(1 if error_count > 0 else 0)
