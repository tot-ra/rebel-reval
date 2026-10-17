extends Node

## Click-to-travel graph check (QA, perf/traversal ledger): plans every ordered pair of
## active manifest scenes through GlobalMapCatalog.plan_travel (the planner the district /
## world map click uses), then checks that
##   - every plan lands on a spawn DoorNavigator really has,
##   - every distant map is reachable from the city by chained plans,
##   - every distant map can chain back to the city.
## Failures print the exact (from, to) pair so each one is a repro.
## Run: godot --headless --path . res://tools/verify_travel_graph.tscn
##   [-- --out=build/qa/travel_graph.json]
## Exit code 1 on any failure. Needs a host scene so the DoorNavigator autoload resolves.

const CITY := &"reval_city"

var _out := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []
	var ids: Array[StringName] = DoorNavigator.get_active_scene_ids()
	var edges: Dictionary = {}
	var plans := 0
	# The map's own "return to Reval" node is the hub marker, not a manifest scene id.
	var targets: Array[StringName] = ids.duplicate()
	targets.append(GlobalMapCatalog.REVAL_HUB_ID)
	for from_id in ids:
		for to_id in targets:
			if from_id == to_id:
				continue
			var plan := GlobalMapCatalog.plan_travel(from_id, to_id)
			if plan.is_empty():
				continue
			plans += 1
			var dest := StringName(String(plan["scene_id"]))
			var spawn := StringName(String(plan["spawn_id"]))
			if not DoorNavigator.has_spawn(dest, spawn):
				failures.append(
					"plan %s -> %s lands on missing spawn %s/%s" % [from_id, to_id, dest, spawn]
				)
			if not edges.has(from_id):
				edges[from_id] = []
			edges[from_id].append(dest)
	var reach := _reach(edges, CITY)
	var unreachable: Array[String] = []
	var no_return: Array[String] = []
	for id in ids:
		if id == CITY:
			continue
		if not reach.has(id):
			unreachable.append(String(id))
			failures.append("%s is not reachable from the city by travel plans" % id)
		if not _reach(edges, id).has(CITY):
			no_return.append(String(id))
			failures.append("%s cannot travel back to the city by travel plans" % id)
	print(
		"travel graph: %d scenes, %d plans, %d reachable from city"
		% [ids.size(), plans, reach.size() - 1]
	)
	for f in failures:
		push_error(f)
	if _out != "":
		var path := ProjectSettings.globalize_path("res://" + _out.trim_prefix("res://"))
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			var report := {
				"scenes": ids.size(),
				"plans": plans,
				"unreachable": unreachable,
				"no_return": no_return,
				"failures": failures,
			}
			file.store_string(JSON.stringify(report, "  "))
	print("TRAVEL GRAPH: %s" % ("PASS" if failures.is_empty() else "FAIL (%d)" % failures.size()))
	get_tree().quit(0 if failures.is_empty() else 1)


func _reach(edges: Dictionary, start: StringName) -> Dictionary:
	var seen := {start: true}
	var queue: Array = [start]
	while not queue.is_empty():
		var current: StringName = queue.pop_back()
		for next in edges.get(current, []):
			if not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen
