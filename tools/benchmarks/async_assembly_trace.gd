extends SceneTree

## WB-07 (R-979) location-assembly trace. For each map it records:
## - the synchronous MapView3D build (the "before": one frame pays everything),
## - the staged build driven by assemble_async() over real process frames (the
##   "after"), with per-frame main-thread cost and every unit over the budget,
## - per-stage totals for both paths (MapViewAssembly STAGES keys),
## - navigation: synchronous bake time vs the main-thread cost of a threaded bake.
##
## Usage:
##   godot --headless --path . --script tools/benchmarks/async_assembly_trace.gd \
##     -- --output=build/benchmarks/async_assembly.json [--budget-ms=4.0] [--quick]
## Headless uses the dummy renderer: the numbers are CPU scene-construction cost,
## not GPU upload. Run through tools/godot_render.sh for a GPU-backed trace.

const DEFAULT_OUTPUT := "res://build/benchmarks/async_assembly.json"
const MAP_SCRIPTS := {
	&"lower_town_slice": "res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd",
	&"kalev_smithy": "res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd",
	&"reval_harbor_east": "res://scripts/map/definitions/outdoor/reval_harbor_east_definition.gd",
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var default_budget := str(MapView3D.Assembly.frame_budget_msec())
	var budget_ms := float(_argument_value("--budget-ms=", default_budget))
	var quick := _has_flag("--quick")
	var maps: Array[Dictionary] = []
	for map_id: StringName in MAP_SCRIPTS:
		if quick and map_id != &"lower_town_slice":
			continue
		maps.append(await _trace_map(map_id, budget_ms))
	var report := {
		"schema": "rr.async_assembly_trace.v1",
		"renderer": RenderingServer.get_current_rendering_method(),
		"display_server": DisplayServer.get_name(),
		"godot": Engine.get_version_info()["string"],
		"host":
		{
			"os": OS.get_name(),
			"cpu": OS.get_processor_name(),
			"arch": Engine.get_architecture_name(),
		},
		"budget_ms": budget_ms,
		"maps": maps,
	}
	var output_path := _argument_value("--output=", DEFAULT_OUTPUT)
	var output_dir := ProjectSettings.globalize_path(output_path).get_base_dir()
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write async assembly trace: %s" % output_path)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	for entry in maps:
		print(
			(
				"ASSEMBLY %s sync=%.1f ms staged: frames=%d max_frame=%.2f ms"
				+ " over_budget_units=%d nav sync=%.1f ms threaded_main=%.2f ms"
			)
			% [
				entry["map_id"],
				entry["synchronous"]["total_ms"],
				entry["staged"]["frames"],
				entry["staged"]["max_frame_ms"],
				entry["staged"]["units_over_budget"].size(),
				entry["navigation"]["synchronous_ms"],
				entry["navigation"]["threaded_main_thread_ms"],
			]
		)
	print("ASSEMBLY report: %s" % output_path)
	quit(0)


func _trace_map(map_id: StringName, budget_ms: float) -> Dictionary:
	var definition: MapDefinition = load(String(MAP_SCRIPTS[map_id])).create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	# Warm shared static caches (materials, prefab templates, height field) so the
	# before/after comparison measures the same work on both paths.
	_free_view(MapView3D.create(definition, grid))
	await process_frame

	var started := Time.get_ticks_usec()
	var synchronous := MapView3D.create(definition, grid)
	var sync_total := Time.get_ticks_usec() - started
	root.add_child(synchronous)
	var sync_stages := _stage_ms(synchronous.assembly_stage_timings_usec())
	root.remove_child(synchronous)
	_free_view(synchronous)
	await process_frame

	# Assembled detached and mounted on completion, the WB-07 usage contract: no
	# half-built location is ever visible and nothing simulates before mount.
	var staged := MapView3D.create_staged(definition, grid)
	var wall_started := Time.get_ticks_usec()
	var completed: bool = await staged.assemble_async(budget_ms)
	var wall_usec := Time.get_ticks_usec() - wall_started
	var frames := staged.assembly_frame_timings_usec()
	var max_frame := 0
	var frames_over := 0
	for frame_usec in frames:
		max_frame = maxi(max_frame, frame_usec)
		if frame_usec > int(budget_ms * 1000.0):
			frames_over += 1
	var over_budget: Array[Dictionary] = []
	for unit in staged.assembly_unit_timings():
		if int(unit["usec"]) > int(budget_ms * 1000.0):
			over_budget.append(
				{"stage": String(unit["stage"]), "label": unit["label"], "ms": _ms(unit["usec"])}
			)
	var frame_ms: Array[float] = []
	for frame_usec in frames:
		frame_ms.append(_ms(frame_usec))
	var mount_started := Time.get_ticks_usec()
	root.add_child(staged)
	var mount_usec := Time.get_ticks_usec() - mount_started
	var staged_stages := _stage_ms(staged.assembly_stage_timings_usec())
	var unit_count := staged.assembly_unit_timings().size()
	root.remove_child(staged)
	_free_view(staged)
	await process_frame

	var nav_started := Time.get_ticks_usec()
	var region := MapNavBuilder.create_navigation_region(definition, grid)
	var nav_sync := Time.get_ticks_usec() - nav_started
	region.free()
	nav_started = Time.get_ticks_usec()
	var job := MapNavBuilder.start_bake(definition, grid)
	var nav_main := Time.get_ticks_usec() - nav_started
	var nav_frames := 0
	while not job.is_done():
		nav_frames += 1
		await process_frame
	job.wait()

	return {
		"map_id": String(map_id),
		"synchronous": {"total_ms": _ms(sync_total), "stages_ms": sync_stages},
		"staged": {
			"completed": completed,
			"frames": frames.size(),
			"wall_ms": _ms(wall_usec),
			"max_frame_ms": _ms(max_frame),
			"mount_add_child_ms": _ms(mount_usec),
			"frames_over_budget": frames_over,
			"frame_ms": frame_ms,
			"stages_ms": staged_stages,
			"units": unit_count,
			"units_over_budget": over_budget,
		},
		"navigation": {
			"synchronous_ms": _ms(nav_sync),
			"threaded_main_thread_ms": _ms(nav_main),
			"threaded_frames_until_ready": nav_frames,
		},
	}


static func _stage_ms(timings: Dictionary) -> Dictionary:
	var result := {}
	for stage in timings:
		result[String(stage)] = _ms(timings[stage])
	return result


static func _ms(usec: int) -> float:
	return snappedf(float(usec) / 1000.0, 0.001)


static func _free_view(view: MapView3D) -> void:
	MapView3D._strip_geometry_materials(view)
	view.free()


func _argument_value(prefix: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return fallback


func _has_flag(flag: String) -> bool:
	return OS.get_cmdline_user_args().has(flag)
