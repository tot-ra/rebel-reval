extends SceneTree

const BlueprintAudit := preload("res://scripts/map/map_blueprint_audit.gd")

## Headless audit for every production blueprint source. The explicit registry
## supplies factories and semantic requirements; discovery proves no source was
## accidentally omitted from CI coverage.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var diagnostics := BlueprintAudit.run()
	var error_count := 0
	var warning_count := 0
	for diagnostic in diagnostics:
		print(diagnostic.format())
		if diagnostic.is_error():
			error_count += 1
		else:
			warning_count += 1
	print("Blueprint audit: %d registered, %d discovered, %d error(s), %d warning(s)." % [
		MapBlueprintRegistry.entries().size(),
		BlueprintAudit.discover_blueprint_sources().size(),
		error_count,
		warning_count,
	])
	quit(1 if error_count > 0 else 0)
