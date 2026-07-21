extends Node

## Runs as a child of the real Lower Town scene, so normal project autoloads and
## the complete production _ready chain are present during baseline capture.

const DEFAULT_OUTPUT := "user://lower_town_scene_baseline.json"
const MIB := 1024.0 * 1024.0

var _started_usec := Time.get_ticks_usec()
var _memory_before := 0


func _enter_tree() -> void:
	_memory_before = int(Performance.get_monitor(Performance.MEMORY_STATIC))


func _ready() -> void:
	call_deferred("_record")


func _record() -> void:
	await get_tree().process_frame
	var startup_ms := float(Time.get_ticks_usec() - _started_usec) / 1000.0
	var frame_count := 120
	for argument in OS.get_cmdline_user_args():
		if argument == "--quick":
			frame_count = 20
	var frame_times: Array[float] = []
	var previous := Time.get_ticks_usec()
	for ignored in frame_count:
		await get_tree().process_frame
		var current := Time.get_ticks_usec()
		frame_times.append(float(current - previous) / 1000.0)
		previous = current

	var scene_root := get_parent().get_node("LowerTown")
	var actors_root := scene_root.get_node_or_null("Actors")
	var memory_after := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var report := {
		"scene_startup_ms": startup_ms,
		"pipeline_cpu_ms": startup_ms,
		"node_count": _count_nodes(scene_root),
		"collision_count": _count_collisions(scene_root),
		# The production Actors branch is authoritative for simulation workload;
		# counting named nodes would silently miss future actor archetypes.
		"actor_count": _count_actors(actors_root),
		"memory_static_bytes": memory_after,
		"memory_delta_mib": maxf(0.0, float(memory_after - _memory_before) / MIB),
		"frame_time_ms": _distribution(frame_times),
	}
	var output_path := DEFAULT_OUTPUT
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write Lower Town scene baseline: %s" % output_path)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	get_tree().quit(0)


func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count


func _count_collisions(node: Node) -> int:
	var count := 1 if node is CollisionShape2D or node is CollisionPolygon2D else 0
	for child in node.get_children():
		count += _count_collisions(child)
	return count


func _count_actors(actors_root: Node) -> int:
	if actors_root == null:
		return 0
	var count := 1 if actors_root is CharacterBody2D or actors_root is CharacterBody3D else 0
	for child in actors_root.get_children():
		count += _count_actors(child)
	return count


func _distribution(input_values: Array[float]) -> Dictionary:
	if input_values.is_empty():
		return {"samples": 0, "median": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0}
	var values := input_values.duplicate()
	values.sort()
	return {
		"samples": values.size(),
		"median": values[values.size() / 2],
		"p95": _percentile(values, 0.95),
		"p99": _percentile(values, 0.99),
		"max": values[-1],
	}


func _percentile(sorted_values: Array[float], fraction: float) -> float:
	return sorted_values[clampi(ceili(float(sorted_values.size()) * fraction) - 1, 0, sorted_values.size() - 1)]
