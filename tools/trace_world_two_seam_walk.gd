extends Node

## WB-08c (R-1044) headless trace of a two-seam walk with staged seam mounts:
## Lower Town -> market_civic_quarter -> south_quarter over real physics frames.
## Run as a main scene so autoloads resolve:
##   godot --headless --path . res://tools/trace_world_two_seam_walk.tscn
## Both streaming flags are forced on for this process only. The player runs at
## 240 px/s (4 px per 60 Hz physics frame). A physical seam gate holds a player in
## front of an in-flight neighbour, so the walk pauses while the host reports
## `waiting`. The driver tick (all main-thread streaming work: planning, worker
## hand-off, staged view units, package mounts) is timed every frame.
## `-- --px-per-frame=2` walks instead of running, so prefetch finishes before each
## seam and the trace also shows ordinary (not early) mounts.
## `-- --stability` exits 0 when both crossings happen without a scene swap.
## Budget overruns stay in the report; they belong to R-1006 / R-1069 / R-1071,
## not the R-1076 SIGSEGV leftover.
## Writes build/world_two_seam_trace.json (or `--out=res://build/<name>.json`) and
## exits 0 only when every tick stays within the budget and both crossings
## happened without a scene swap, unless `--stability` is set.

const LOWER_TOWN_SCENE_PATH := "res://scenes/reval_east/reval_east.tscn"
const REPORT_PATH := "res://build/world_two_seam_trace.json"
const ROUTE: Array[StringName] = [&"lower_town_slice", &"market_civic_quarter", &"south_quarter"]
const RUN_PX_PER_FRAME := 4.0
const BUDGET_MSEC := 4.0
const MAX_FRAMES := 12000

var _frames: Array[Dictionary] = []
var _px_per_frame := RUN_PX_PER_FRAME
var _report_path := REPORT_PATH
var _stability := false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--px-per-frame="):
			_px_per_frame = maxf(float(arg.get_slice("=", 1)), 0.5)
		elif arg.begins_with("--out="):
			_report_path = arg.get_slice("=", 1)
		elif arg == "--stability":
			# Crash-only leftover: completed walk, no scene swap, ignore 4 ms ticks.
			_stability = true
	ProjectSettings.set_setting(WorldHost.ADDITIVE_RESIDENCY_SETTING, true)
	ProjectSettings.set_setting(WorldHostMountQueue.Assembly.ENABLED_SETTING, true)
	DoorNavigator.clear_pending_spawn()
	var level := (load(LOWER_TOWN_SCENE_PATH) as PackedScene).instantiate()
	get_tree().root.add_child(level)
	var host := level.get_node_or_null(WorldHost.HOST_NODE_NAME) as WorldHost
	var driver := host.get_node_or_null(WorldHostStreamingDriver.NODE_NAME) if host != null else null
	if driver == null:
		push_error("trace: no hosted launch with a streaming driver")
		get_tree().quit(2)
		return
	# The tool owns the frame order: move, then tick, exactly once per frame.
	driver.set_physics_process(false)
	var player := host.player_owner as Node2D
	# Position-driven walk: the body must not depenetrate or slide on its own.
	player.set_physics_process(false)
	var waypoints := _waypoints(host)
	var unit_peaks := {}
	host.location_mounted.connect(
		func(location_id: StringName) -> void:
			var view := host.hosted_view(location_id)
			if view != null:
				unit_peaks[String(location_id)] = _top_units(view.assembly_unit_timings())
	)
	player.global_position = waypoints[0]
	var owners: Array[String] = []
	var waiting_frames := 0
	var target_index := 1
	var last_usec := Time.get_ticks_usec()
	while target_index < waypoints.size() and _frames.size() < MAX_FRAMES:
		await get_tree().physics_frame
		var now := Time.get_ticks_usec()
		var target: Vector2 = waypoints[target_index]
		var previous := player.global_position
		player.global_position = previous.move_toward(target, _px_per_frame)
		var result: Dictionary = driver.tick()
		if result.get("waiting", &"") != &"":
			# A sealed seam gate stops the body at the edge.
			player.global_position = previous
			waiting_frames += 1
		if player.global_position.distance_to(target) < 0.5:
			target_index += 1
		var owner := String(host.owning_location_id())
		if owners.is_empty() or owners[-1] != owner:
			owners.append(owner)
		_frames.append({
			"frame_ms": float(now - last_usec) / 1000.0,
			"tick_ms": float(driver.tick_usec[-1]) / 1000.0,
			# WB-08e breakdown: staged-mount step (mounts, entry and teardown slices)
			# and eviction; the rest of the tick is planning and owner handover.
			"queue_ms": float(result.get("queue_usec", 0)) / 1000.0,
			"evict_ms": float(result.get("evict_usec", 0)) / 1000.0,
			"slice_ms": float(host.mount_queue.tick_slice_usec) / 1000.0,
			"owner": owner,
			"waiting": String(result.get("waiting", &"")),
			"mounted": _strings(result.get("mounted", [])),
			"evicted": _strings(result.get("evicted", [])),
			"pending": _strings(host.pending_location_ids()),
			"evicting": host.mount_queue.evicting_count(),
		})
		last_usec = now
	var report := _report(host, owners, waiting_frames)
	report["heaviest_view_units"] = unit_peaks
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var file := FileAccess.open(_report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify(report["summary"], "  "))
	host.unmount_all()
	level.queue_free()
	await get_tree().physics_frame
	get_tree().quit(0 if report["summary"]["ok"] else 1)


## Owner centre -> each seam's door aperture (both sides) -> next owner. The
## apertures come from the compiled definitions, so the walk never scrapes the
## boundary walls beside a seam (they would push the body back).
func _waypoints(host: WorldHost) -> Array[Vector2]:
	var layout := host.world_layout
	var bounds := {}
	for entry in layout.get("locations", []):
		bounds[StringName(entry["location_id"])] = entry["global_bounds"]
	var points: Array[Vector2] = [(bounds[ROUTE[0]] as Rect2).get_center()]
	for index in range(1, ROUTE.size()):
		var from_id := ROUTE[index - 1]
		var to_id := ROUTE[index]
		var seam := host.seam_between(from_id, to_id)
		var from_door := _door_center(host, from_id, _transition_of(seam, from_id))
		var to_door := _door_center(host, to_id, _transition_of(seam, to_id))
		points.append(from_door + (from_door - to_door).normalized() * 64.0)
		points.append(to_door + (to_door - from_door).normalized() * 64.0)
		var to_center := (bounds[to_id] as Rect2).get_center()
		# Walk halfway into a district that is not the last, so its far seam is next.
		points.append(to_door.lerp(to_center, 0.5 if index < ROUTE.size() - 1 else 1.0))
	return points


static func _transition_of(seam: Dictionary, location_id: StringName) -> StringName:
	if seam.get("base_map_id", &"") == location_id:
		return StringName(seam.get("base_transition_id", &""))
	return StringName(seam.get("neighbor_transition_id", &""))


static func _door_center(
	host: WorldHost, location_id: StringName, transition_id: StringName
) -> Vector2:
	var definition := WorldHostStreamingDriver.registry_definition(location_id)
	for transition in definition.transitions:
		if StringName(transition.get("id", &"")) == transition_id:
			var rect: Rect2 = transition["rect"]
			return host.global_logic_position(location_id, rect.get_center())
	return host.location_origin_logic_position(location_id)


func _report(host: WorldHost, owners: Array[String], waiting_frames: int) -> Dictionary:
	var ticks: Array[float] = []
	var over: Array[Dictionary] = []
	for index in _frames.size():
		var tick_ms: float = _frames[index]["tick_ms"]
		ticks.append(tick_ms)
		if tick_ms > BUDGET_MSEC:
			var frame := _frames[index].duplicate()
			frame["frame"] = index
			over.append(frame)
	var sorted_ticks := ticks.duplicate()
	sorted_ticks.sort()
	var visited_all := owners == (ROUTE.map(func(id: StringName) -> String: return String(id)))
	var summary := {
		"frames": _frames.size(),
		"owners": owners,
		"tick_ms_p50": _percentile(sorted_ticks, 0.5),
		"tick_ms_p95": _percentile(sorted_ticks, 0.95),
		"tick_ms_max": sorted_ticks[-1] if not sorted_ticks.is_empty() else 0.0,
		"ticks_over_budget": over.size(),
		"budget_ms": BUDGET_MSEC,
		"px_per_frame": _px_per_frame,
		"waiting_frames": waiting_frames,
		"readiness_misses": host.mount_queue.misses(),
		"scene_swaps": 0 if DoorNavigator.pending_spawn_scene_id.is_empty() else 1,
		"queue_ms_max": _max_of("queue_ms"),
		"evict_ms_max": _max_of("evict_ms"),
		"slice_ms_max": float(host.mount_queue.max_slice_usec) / 1000.0,
		"slice_max_label": host.mount_queue.max_slice_label,
		"evict_slice_ms_max": float(host.mount_queue.max_evict_slice_usec) / 1000.0,
		"tick_slice_ms_max": _max_of("slice_ms"),
		"teardown_tick_ms_max": _teardown_tick_ms_max(),
		"stability": _stability,
	}
	var walk_ok: bool = visited_all and int(summary["scene_swaps"]) == 0
	summary["ok"] = walk_ok if _stability else (walk_ok and over.is_empty())
	return {"task": "R-1069", "summary": summary, "over_budget": over, "frames": _frames}


func _max_of(key: String) -> float:
	var peak := 0.0
	for frame in _frames:
		peak = maxf(peak, float(frame.get(key, 0.0)))
	return peak


func _teardown_tick_ms_max() -> float:
	var peak := 0.0
	for frame in _frames:
		if int(frame.get("evicting", 0)) <= 0 and (frame.get("evicted", []) as Array).is_empty():
			continue
		peak = maxf(peak, float(frame.get("tick_ms", 0.0)))
	return peak


static func _top_units(units: Array[Dictionary]) -> Array[Dictionary]:
	var sorted_units := units.duplicate()
	sorted_units.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["usec"] > b["usec"])
	var top: Array[Dictionary] = []
	for unit in sorted_units.slice(0, 12):
		top.append({"stage": String(unit["stage"]), "label": unit["label"], "ms": unit["usec"] / 1000.0})
	return top


static func _percentile(sorted_values: Array, fraction: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	return float(sorted_values[mini(int(fraction * sorted_values.size()), sorted_values.size() - 1)])


static func _strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result
