extends SceneTree

## Headless composition audit for every registry map in map_composition_thresholds.json.
##
## Two passes per map:
## - P1-036 historical bands, enforced only for cards with enforce != false.
## - WB-10 (R-982) dressing-and-ground density contract, measured for every map
##   against its `map_class`. It fails only for scope=production maps that hold
##   no grace entry; everything else is reported so inactive districts show
##   their gap without blocking CI. One `DENSITY_JSON {...}` line per map feeds
##   tools/verify_map_composition.py (baseline table and visual-gate rows).

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
	var density_contract: Dictionary = thresholds_doc.get("density_contract", {})
	var density_classes: Dictionary = density_contract.get("classes", {})
	var density_grace: Dictionary = density_contract.get("production_grace", {})
	var error_count := 0
	var audited := 0
	var density_errors := 0
	for entry in MapBlueprintRegistry.entries():
		var map_id := String(entry.get("id", ""))
		if not map_thresholds.has(map_id):
			push_error(
				"ERROR[MAP_COMPOSITION_THRESHOLDS_MISSING] (map=%s): no threshold card" % map_id
			)
			error_count += 1
			continue
		var card: Dictionary = map_thresholds[map_id]
		var enforce_bands: bool = card.get("enforce", true) != false
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
		var blocked := false
		for diagnostic in result.diagnostics:
			if diagnostic.is_error():
				blocked = true
				# Compile errors on report-only maps must not fail the band audit
				# they were never enrolled in; the blueprint validator owns them.
				if enforce_bands:
					push_error(diagnostic.format())
					error_count += 1
		if blocked:
			print("DENSITY_JSON %s" % JSON.stringify({"map_id": map_id, "status": "compile_error"}))
			continue
		var definition := result.definition
		var grid := MapBuilder.build(definition)
		var authoring_contract := _load_authoring_contract(map_id)

		if enforce_bands:
			var violations := MapCompositionAudit.audit(definition, grid, card, authoring_contract)
			audited += 1
			print("AUDIT %s" % map_id)
			print(
				"  sources=%s expected=%s"
				% [", ".join(card.get("source_refs", [])), JSON.stringify(card)]
			)
			if violations.is_empty():
				print("  pass")
			for violation in violations:
				push_error(MapCompositionAudit.format_violation(violation))
				error_count += 1
		else:
			print("SKIP %s (enforce=false)" % map_id)

		var map_class := String(card.get("map_class", ""))
		if not density_classes.has(map_class):
			push_error(
				"ERROR[MAP_COMPOSITION_CLASS_MISSING] (map=%s): unknown map_class `%s`"
				% [map_id, map_class]
			)
			error_count += 1
			continue
		var metrics := MapCompositionAudit.measure(definition, grid, authoring_contract)
		var dressing: Dictionary = metrics["dressing"]
		var density_violations := MapCompositionAudit.audit_density(
			map_id, dressing, density_classes[map_class], card.get("source_refs", [])
		)
		var scope := String(metrics.get("scope", ""))
		var mode := "report"
		if scope == "production":
			mode = "grace" if density_grace.has(map_id) else "enforced"
		var failing: Array[String] = []
		for violation in density_violations:
			failing.append(String(violation["metric"]))
			if mode == "enforced":
				push_error(MapCompositionAudit.format_violation(violation))
				density_errors += 1
		print(
			"DENSITY_JSON %s"
			% JSON.stringify({
				"map_id": map_id,
				"map_class": map_class,
				"scope": scope,
				"mode": mode,
				"status": "pass" if density_violations.is_empty() else "fail",
				"failing_metrics": failing,
				"violations": density_violations.map(
					func(v): return {
						"code": String(v["code"]),
						"metric": v["metric"],
						"measured": v["measured"],
						"expected": v["expected"],
					}
				),
				"metrics": dressing,
			}, "", true)
		)

	print(
		"Composition audit: %d enforced map(s), %d error(s), %d density error(s)."
		% [audited, error_count, density_errors]
	)
	quit(1 if error_count + density_errors > 0 else 0)


func _load_authoring_contract(map_id: String) -> Dictionary:
	var path := "res://docs/data/%s_authoring_contract.json" % map_id
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	push_error(
		"ERROR[MAP_COMPOSITION_AUTHORING_CONTRACT_INVALID] (map=%s): could not parse %s"
		% [map_id, path]
	)
	return {}
