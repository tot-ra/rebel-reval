extends SceneTree

## Session log for the ADR 0035 phase-2 pilot (R-1357, R-1358): boots a pilot
## location headless, walks the player, and records which catalog IDs the
## footstep and ambience layers actually triggered.
##
## Headless run (no window, no GPU needed):
##   godot --headless --path . --script tools/capture_sfx_session_log.gd -- \
##     --out=res://build/reports/sfx_session_log.json
##
## The log is evidence for the task verify lines and the input to the
## maintainer's listening review; it is not a test fixture.

const SCENES: Array[Dictionary] = [
	{"map": "kalev_smithy", "path": "res://scenes/reval_east/forge/forge.tscn"},
	{"map": "lower_town_slice", "path": "res://scenes/reval_east/reval_east.tscn"},
]
## Frames per leg of the square circuit.
const WALK_FRAMES := 90
const SETTLE_FRAMES := 12


func _init() -> void:
	var out := "res://build/reports/sfx_session_log.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	# Autoloads (SessionState, DoorNavigator) compile in only after frame one.
	await process_frame
	var entries: Array = []
	for scene: Dictionary in SCENES:
		entries.append(await _capture(scene))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out).get_base_dir())
	var payload := {"type": "sfx_session_log", "locations": entries}
	var file := FileAccess.open(out, FileAccess.WRITE)
	if file == null:
		push_error("cannot write %s" % out)
		quit(1)
		return
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	print("CAPTURED ", out)
	quit()


func _capture(scene: Dictionary) -> Dictionary:
	var location := (load(String(scene["path"])) as PackedScene).instantiate()
	root.add_child(location)
	await _frames(SETTLE_FRAMES)
	var runtime := location.get_node_or_null("MapViewRuntime") as MapViewRuntime
	var record := {
		"map": scene["map"],
		"scene": scene["path"],
		"footstep_ids": [],
		"footstep_count": 0,
		"ambience_layers": [],
	}
	if runtime == null:
		record["error"] = "MapViewRuntime not mounted"
		location.queue_free()
		await _frames(2)
		return record

	var triggered: Dictionary = {}
	var surfaces: Dictionary = {}
	# A square circuit instead of one straight line: walking into a wall or a
	# prop stops the body, and a stopped body stops planting feet, so a single
	# heading would log only the spawn cell's surface.
	for action: StringName in [&"ui_right", &"ui_down", &"ui_left", &"ui_up"]:
		Input.action_press(action)
		for frame in WALK_FRAMES:
			await process_frame
			var sound_id := runtime.last_footstep_sound_id()
			if not String(sound_id).is_empty():
				triggered[String(sound_id)] = int(triggered.get(String(sound_id), 0)) + 1
			var surface := runtime.last_footstep_surface()
			if not String(surface).is_empty():
				surfaces[String(surface)] = true
		Input.action_release(action)
	var walked_surfaces: Array = surfaces.keys()
	walked_surfaces.sort()
	record["surfaces_walked"] = walked_surfaces

	var ids: Array = triggered.keys()
	ids.sort()
	record["footstep_ids"] = ids
	record["footstep_count"] = runtime.footstep_played_count()
	var layers: Array = []
	for layer_id: StringName in runtime.ambience_active_layer_ids():
		layers.append(String(layer_id))
	record["ambience_layers"] = layers
	location.queue_free()
	await _frames(2)
	return record


func _frames(count: int) -> void:
	for i in count:
		await process_frame
