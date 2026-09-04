extends SceneTree

## Temporary probe: parse world_saaremaa.rrmap, compile it, and repeat the
## reachability contract from test_transition_spawn_clearance for this one map.

const PATH := "res://content/maps/world_saaremaa.rrmap"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var parsed := MapRrmapParser.parse_file(PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			print("DIAG %s" % diagnostic)
		print("PROBE FAILED: parse")
		quit(1)
		return
	var definition: MapDefinition = parsed.definition
	print(
		(
			"OK parse size=%s zones=%d buildings=%d props=%d anchors=%d transitions=%d"
			% [
				str(definition.size_cells),
				definition.zones.size(),
				definition.buildings.size(),
				definition.props.size(),
				definition.interaction_anchors.size(),
				definition.transitions.size(),
			]
		)
	)
	var errors := definition.validate()
	for message in errors:
		print("VALIDATE %s" % message)
	var grid := MapBuilder.build(definition)
	var failures := 0
	for transition in definition.transitions:
		var clear := MapVerification.spawn_clears_transition_trigger(transition)
		var arrival: Vector2 = (
			transition["rect"].get_center() + transition.get("spawn_offset", Vector2.ZERO)
		)
		var routed := MapVerification.route_exists(definition, grid, definition.player_spawn, arrival)
		print(
			(
				"TRANSITION %s clear=%s routed=%s arrival=%s"
				% [str(transition["id"]), str(clear), str(routed), str(arrival / 32.0)]
			)
		)
		if not clear or not routed:
			failures += 1
	print("PROBE %s errors=%d failures=%d" % ["DONE", errors.size(), failures])
	quit(1 if (failures > 0 or not errors.is_empty()) else 0)
