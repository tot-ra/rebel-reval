extends CanvasLayer

## Developer performance overlay (docs/SYSTEMS/PERFORMANCE_MONITOR.md). Autoload `PerfMonitor`.
##   F3          cycle off -> compact -> full
##   Alt+1..0    in "full": switch a render layer off/on to see what it costs
##   F4          in "full": measure what each layer costs (switches them off one by one)
##   Shift+F3    write a JSON snapshot to user://perf_snapshots/ (path is printed)
## The panel is built to be screenshotted: where the player stands, the quality row, frame
## time, CPU and GPU render time, the slowest GPU passes, the slowest CPU systems, memory
## and the scene counters that explain them.

const PerfProbeScript := preload("res://scripts/debug/perf_probe.gd")
const GraphicsPresetsScript := preload("res://scripts/settings/graphics_presets.gd")

const OFF := 0
const COMPACT := 1
const FULL := 2
const HISTORY := 240
const BUDGET_MS := 33.3
const REFRESH_SECONDS := 0.25
const MEASURE_SETTLE_FRAMES := 6
const MEASURE_FRAMES := 18
const SNAPSHOT_DIR := "user://perf_snapshots"
const MAX_PASSES := 9
const PANEL_WIDTH := 430.0
const FONT_SIZE := 12
const COLOR_OK := Color(0.55, 0.9, 0.55)
const COLOR_WARN := Color(1.0, 0.82, 0.3)
const COLOR_BAD := Color(1.0, 0.4, 0.35)

## Layers Alt+1..0 can switch off. Each finder returns the nodes to hide and pause.
const LAYERS: Array[Dictionary] = [
	{"id": "grass", "label": "grass"},
	{"id": "farmland", "label": "fields"},
	{"id": "trees", "label": "trees"},
	{"id": "buildings", "label": "buildings"},
	{"id": "water", "label": "sea/water"},
	{"id": "spray", "label": "shore spray"},
	{"id": "godrays", "label": "god rays"},
	{"id": "clouds", "label": "cloud shadow+fog"},
	{"id": "people", "label": "people+fauna"},
	{"id": "shadows", "label": "sun shadows"},
]

var mode := OFF
var _panel: PanelContainer
var _text: RichTextLabel
var _graph: Control
var _frames := PackedFloat32Array()
var _frame_cursor := 0
var _last_usec := 0
var _refresh := 0.0
var _scopes: Dictionary = {}
var _scope_peak: Dictionary = {}
var _layer_off: Dictionary = {}
var _measuring := false
## Layer id -> frame ms saved when it is off; filled by measure_layers().
var _layer_cost: Dictionary = {}
var _layer_baseline := 0.0
var _measure_status := ""
var _measure_running := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_frames.resize(HISTORY)
	_build_ui()
	_apply_mode()
	if "--perf-overlay" in OS.get_cmdline_user_args():
		mode = FULL
		_apply_mode()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F3:
		if key.shift_pressed:
			write_snapshot()
		else:
			mode = (mode + 1) % 3
			_apply_mode()
		get_viewport().set_input_as_handled()
	elif mode == FULL and key.keycode == KEY_F4:
		measure_layers()
		get_viewport().set_input_as_handled()
	elif mode == FULL and key.alt_pressed and key.keycode >= KEY_0 and key.keycode <= KEY_9:
		var index := key.keycode - KEY_1 if key.keycode != KEY_0 else 9
		if index >= 0 and index < LAYERS.size():
			toggle_layer(String(LAYERS[index]["id"]))
			get_viewport().set_input_as_handled()


func toggle_layer(id: String) -> void:
	_layer_off[id] = not bool(_layer_off.get(id, false))
	_apply_layers()


## Switches each layer off in turn and records how many milliseconds the frame loses or
## gains: the direct answer to "is it the grass, the sea or the sky". Takes a few seconds;
## the player should stand still. Results stay in the panel until the next run.
func measure_layers() -> void:
	if _measure_running:
		return
	_measure_running = true
	_layer_cost.clear()
	_restore_layers()
	_measure_status = "measuring layers, stand still ..."
	var before := await _median_frame_ms()
	var costs: Dictionary = {}
	for layer_def: Dictionary in LAYERS:
		var id := String(layer_def["id"])
		if _layer_nodes(id).is_empty() and id != "shadows":
			continue
		_measure_status = "measuring: %s off ..." % layer_def["label"]
		_layer_off[id] = true
		_apply_layers()
		costs[id] = await _median_frame_ms()
		_layer_off[id] = false
		_apply_layers()
	var after := await _median_frame_ms()
	_layer_baseline = (before + after) * 0.5
	for id: String in costs:
		_layer_cost[id] = maxf(_layer_baseline - float(costs[id]), 0.0)
	_measure_status = ""
	_measure_running = false


func _median_frame_ms() -> float:
	for _settle in MEASURE_SETTLE_FRAMES:
		await get_tree().process_frame
	var samples := PackedFloat32Array()
	var last := Time.get_ticks_usec()
	for _frame in MEASURE_FRAMES:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now - last) / 1000.0)
		last = now
	samples.sort()
	return samples[samples.size() / 2]


func _apply_mode() -> void:
	if _panel == null:
		return
	visible = mode != OFF
	_text.visible = true
	_graph.visible = mode == FULL
	PerfProbeScript.enabled = mode == FULL
	_set_measuring(mode != OFF)
	_panel.reset_size()
	if mode == OFF:
		_restore_layers()


func _set_measuring(on: bool) -> void:
	if on == _measuring:
		return
	_measuring = on
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), on)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if mode == OFF:
		_last_usec = now
		return
	if _last_usec != 0:
		_frames[_frame_cursor % HISTORY] = float(now - _last_usec) / 1000.0
		_frame_cursor += 1
	_last_usec = now
	_collect_scopes()
	_graph.queue_redraw()
	_refresh -= get_process_delta_time()
	if _refresh <= 0.0:
		_refresh = REFRESH_SECONDS
		_apply_layers()
		_text.text = _compose()


## Smooths the per-scope CPU times (frame by frame) so the list does not flicker.
func _collect_scopes() -> void:
	var frame := PerfProbeScript.take_frame()
	for scope: StringName in frame:
		var ms := float(frame[scope]) / 1000.0
		_scopes[scope] = lerpf(float(_scopes.get(scope, ms)), ms, 0.2)
		_scope_peak[scope] = maxf(ms, float(_scope_peak.get(scope, 0.0)) * 0.98)
	for scope: StringName in _scopes.keys():
		if not frame.has(scope):
			_scopes[scope] = float(_scopes[scope]) * 0.8


func _frame_stats() -> Dictionary:
	var count := mini(_frame_cursor, HISTORY)
	if count == 0:
		return {"avg": 0.0, "p95": 0.0, "worst": 0.0}
	var sorted := _frames.slice(0, count)
	sorted.sort()
	var total := 0.0
	for v: float in sorted:
		total += v
	return {
		"avg": total / count,
		"p95": sorted[mini(int(count * 0.95), count - 1)],
		"worst": sorted[count - 1],
	}


func _compose() -> String:
	var stats := _frame_stats()
	var avg: float = stats["avg"]
	var viewport_rid := get_viewport().get_viewport_rid()
	var cpu_ms := (
		RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid)
		+ RenderingServer.get_frame_setup_time_cpu()
	)
	var gpu_ms := RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
	var lines: PackedStringArray = []
	lines.append(
		(
			"[b]%3d FPS[/b]  frame %s avg  %s p95  %s worst"
			% [
				Engine.get_frames_per_second(),
				_ms(avg, true),
				_ms(stats["p95"], true),
				_ms(stats["worst"], true),
			]
		)
	)
	lines.append(
		(
			"render CPU %s   GPU %s   script %s   physics %s"
			% [
				_ms(cpu_ms),
				_ms(gpu_ms) if gpu_ms > 0.0 else "n/a",
				_ms(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0),
				_ms(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0),
			]
		)
	)
	lines.append(_bound_hint(avg, cpu_ms, gpu_ms))
	if mode == COMPACT:
		return "\n".join(lines)
	lines.append("")
	lines.append_array(_context_lines())
	lines.append("")
	lines.append_array(_pass_lines())
	lines.append_array(_scope_lines())
	lines.append("")
	lines.append_array(_memory_lines())
	lines.append("")
	lines.append_array(_layer_lines())
	lines.append("[color=#8899aa]F3 mode  Shift+F3 snapshot  Alt+1..0 layers[/color]")
	return "\n".join(lines)


## Says in words whether the frame is waiting for the CPU or the GPU. Probed systems plus
## render CPU is the CPU work we can see; when the frame is much longer than that, the CPU
## sits waiting, which on a frame this slow is nearly always the GPU.
func _bound_hint(avg: float, cpu_ms: float, gpu_ms: float) -> String:
	if avg <= 0.0:
		return ""
	var probed := 0.0
	for scope: StringName in _scopes:
		probed += float(_scopes[scope])
	var busy := cpu_ms + probed
	if gpu_ms > 0.0 and gpu_ms > busy * 1.2:
		return "[color=#ff6659]GPU bound[/color]: GPU %.1f ms, CPU work %.1f ms" % [gpu_ms, busy]
	if busy > avg * 0.75:
		return "[color=#ffd24d]CPU bound[/color]: %.1f of %.1f ms is CPU work" % [busy, avg]
	if busy < avg * 0.4 and avg > BUDGET_MS * 0.6:
		return "[color=#ff6659]waiting on the GPU[/color]: CPU work %.1f of %.1f ms (F4 finds the layer)" % [busy, avg]
	return "[color=#8cff8c]balanced[/color]: CPU work %.1f of %.1f ms" % [busy, avg]


func _context_lines() -> PackedStringArray:
	var out: PackedStringArray = []
	var window := get_window()
	var quality := "?"
	var settings := get_node_or_null("/root/UserSettings")
	if settings != null and settings.get("graphics") != null:
		quality = String(settings.graphics.quality)
	out.append(
		(
			"quality [b]%s[/b]  %s  scale %.2f  %dx%d"
			% [
				quality,
				RenderingServer.get_current_rendering_method(),
				window.scaling_3d_scale,
				window.size.x,
				window.size.y,
			]
		)
	)
	out.append(
		(
			"%s / %s"
			% [RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_driver_name()]
		)
	)
	var city := get_tree().get_first_node_in_group(&"seamless_city")
	if city == null or city.get("player") == null or city.get("world") == null:
		out.append("scene: %s" % (get_tree().current_scene.name if get_tree().current_scene else "-"))
		return out
	var world: Node = city.world
	var xz := CityPlan.to_world_xz(city.player.global_position)
	var depth: float = city.view.water_depth_at(xz) if city.view != null else 0.0
	out.append(
		(
			"at %.0f, %.0f   %s   water depth %.1f m"
			% [xz.x, xz.y, _nearest_place(city.plan, xz), depth]
		)
	)
	var sky: SkyWeather3D = world.sky_weather
	if sky != null:
		out.append("weather %s   time of day %.2f" % [sky.weather, float(city.view.cycle_progress)])
	return out


func _nearest_place(plan: CityPlan, xz: Vector2) -> String:
	var best := "open country"
	var best_d := 1e9
	for key: String in ["points_of_interest", "woods"]:
		for entry: Dictionary in plan.data.get(key, []):
			var at: Array = entry["at"]
			var d := xz.distance_to(Vector2(at[0], at[1]))
			if d < best_d:
				best_d = d
				best = "%s (%.0f m)" % [entry["id"], d]
	return best


func _pass_lines() -> PackedStringArray:
	var out: PackedStringArray = []
	var passes := _gpu_passes()
	if passes.is_empty():
		# Godot only records pass timestamps while its own visual profiler runs.
		return out
	out.append("[b]GPU passes[/b] (slowest first)")
	for i in mini(passes.size(), MAX_PASSES):
		out.append("  %s  %s" % [_ms(passes[i][1]), passes[i][0]])
	return out


## Per-pass GPU time from the rendering device's timestamps: a "> name" ... "< name" pair is
## one pass (own time = inclusive minus nested passes); a plain stamp is the time since the
## previous stamp.
func _gpu_passes() -> Array:
	var rd := RenderingServer.get_rendering_device()
	if rd == null:
		return []
	var count := rd.get_captured_timestamps_count()
	if count < 2:
		return []
	var stack: Array = []
	var own: Dictionary = {}
	var previous := rd.get_captured_timestamp_gpu_time(0)
	for i in range(1, count):
		var name := rd.get_captured_timestamp_name(i)
		var stamp := rd.get_captured_timestamp_gpu_time(i)
		var delta := float(stamp - previous) / 1.0e6
		previous = stamp
		if name.begins_with("<") and not stack.is_empty():
			var top: Array = stack.pop_back()
			var key: String = top[0]
			own[key] = float(own.get(key, 0.0)) + delta + float(top[1])
		elif name.begins_with(">"):
			if not stack.is_empty():
				stack[stack.size() - 1][1] += delta
			stack.append([name.trim_prefix("> ").trim_prefix(">"), 0.0])
		else:
			if not stack.is_empty():
				stack[stack.size() - 1][1] += delta
			else:
				own[name] = float(own.get(name, 0.0)) + delta
	var rows: Array = []
	for key: String in own:
		if float(own[key]) > 0.01:
			rows.append([key, float(own[key])])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	return rows


func _scope_lines() -> PackedStringArray:
	var out: PackedStringArray = ["", "[b]CPU systems[/b] (script time per frame, avg / peak)"]
	var rows: Array = []
	var total := 0.0
	for scope: StringName in _scopes:
		var ms: float = _scopes[scope]
		if ms > 0.0005:
			rows.append([String(scope), ms, float(_scope_peak.get(scope, ms))])
			total += ms
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	if rows.is_empty():
		out.append("  [color=#8899aa]no probed system ran yet[/color]")
	# Every probed system, slowest first; runtime_* scopes are parts of view_runtime.
	for row: Array in rows:
		var note := "  (inside view_runtime)" if String(row[0]).begins_with("runtime_") or String(row[0]).begins_with("ambient_") else ""
		out.append("  %s / %s  %s%s" % [_ms(row[1]), _ms(row[2]), row[0], note])
	out.append("  total %s (nested scopes counted twice)" % _ms(total))
	return out


func _memory_lines() -> PackedStringArray:
	var mb := 1.0 / (1024.0 * 1024.0)
	var out: PackedStringArray = ["[b]Memory[/b]"]
	out.append(
		(
			"  RAM %.0f MB   VRAM %.0f MB (textures %s, buffers %.0f)"
			% [
				Performance.get_monitor(Performance.MEMORY_STATIC) * mb,
				Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) * mb,
				_mb_or_na(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
				Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) * mb,
			]
		)
	)
	out.append(
		(
			"  draws %d   objects %d   tris %.2fM"
			% [
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1.0e6,
			]
		)
	)
	out.append(
		(
			"  nodes %d   orphans %d   resources %d   pipeline compiles %d"
			% [
				Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
				Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
				Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
				(
					Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)
					+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)
				),
			]
		)
	)
	return out


## Metal reports garbage (a wrapped counter) for the texture total on some drivers.
func _mb_or_na(bytes: float) -> String:
	return "%.0f" % (bytes / (1024.0 * 1024.0)) if bytes >= 0.0 and bytes < 6.0e10 else "n/a"


func _layer_lines() -> PackedStringArray:
	var out: PackedStringArray = ["[b]Layers[/b] (Alt+number toggles, F4 measures)"]
	var parts: PackedStringArray = []
	for i in LAYERS.size():
		var id := String(LAYERS[i]["id"])
		var is_off := bool(_layer_off.get(id, false))
		parts.append(
			"%s%d %s %s%s"
			% [
				"[color=#ff6659]" if is_off else "",
				(i + 1) % 10,
				LAYERS[i]["label"],
				"OFF" if is_off else "on",
				"[/color]" if is_off else "",
			]
		)
		if parts.size() == 3:
			out.append("  " + "   ".join(parts))
			parts.clear()
	if not parts.is_empty():
		out.append("  " + "   ".join(parts))
	out.append_array(_layer_cost_lines())
	return out


func _layer_cost_lines() -> PackedStringArray:
	var out: PackedStringArray = []
	if not _measure_status.is_empty():
		out.append("  [color=#ffd24d]%s[/color]" % _measure_status)
	if _layer_cost.is_empty():
		return out
	out.append("[b]Layer cost[/b] (frame ms saved when off; base %s)" % _ms(_layer_baseline))
	var rows: Array = []
	for id: String in _layer_cost:
		rows.append([id, float(_layer_cost[id])])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	for row: Array in rows:
		var share: float = float(row[1]) / maxf(_layer_baseline, 0.001) * 100.0
		out.append("  %s  %3.0f%%  %s" % [_ms(row[1]), share, _layer_label(row[0])])
	return out


func _layer_label(id: String) -> String:
	for layer_def: Dictionary in LAYERS:
		if layer_def["id"] == id:
			return String(layer_def["label"])
	return id


# -- layers --


## The city view the layers belong to: the playable city, or a benchmark's bare view.
func _city_view() -> Node:
	return get_tree().get_first_node_in_group(&"city_view")


func _layer_nodes(id: String) -> Array[Node]:
	var out: Array[Node] = []
	var view := _city_view()
	if view == null or view.get("world") == null:
		return out
	var world: Node = view.world
	match id:
		"grass":
			out.append(world.grass)
		"farmland":
			out.append(world.farmland)
		"trees":
			out.append(world.get_node_or_null("Vegetation"))
		"buildings":
			out.append(world.get_node_or_null("Buildings"))
		"water":
			out.append(world.get_node_or_null("Water"))
		"spray":
			out.append(world.spray)
		"godrays":
			out.append(view.get("_god_ray_pass"))
		"clouds":
			out.append(view.get("_cloud_shadow_pass"))
			out.append(view.get("_local_atmosphere"))
		"people":
			for node_name in ["CityNpcs", "CityFauna", "CityFish"]:
				out.append(get_tree().root.find_child(node_name, true, false))
	return out.filter(func(n: Node) -> bool: return n != null and is_instance_valid(n))


func _apply_layers() -> void:
	for layer_def: Dictionary in LAYERS:
		var id := String(layer_def["id"])
		var is_off := bool(_layer_off.get(id, false))
		if id == "shadows":
			var view := _city_view()
			if view != null and view.get("world") != null and view.world.sun != null:
				view.world.sun.shadow_enabled = not is_off
			continue
		for node: Node in _layer_nodes(id):
			if node is Node3D:
				(node as Node3D).visible = not is_off
			node.process_mode = Node.PROCESS_MODE_DISABLED if is_off else Node.PROCESS_MODE_INHERIT


func _restore_layers() -> void:
	if _layer_off.is_empty():
		return
	_layer_off.clear()
	_apply_layers()


# -- snapshot --


## One JSON file with everything the overlay shows plus what is too long for a screenshot:
## the biggest MultiMeshes and the node/light/particle counts, for pasting into a report.
func write_snapshot() -> String:
	var city := get_tree().get_first_node_in_group(&"seamless_city")
	var multimeshes: Array = []
	var classes: Dictionary = {}
	var lights := 0
	var particles := 0
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		classes[node.get_class()] = int(classes.get(node.get_class(), 0)) + 1
		if node is MultiMeshInstance3D and node.multimesh != null:
			var mm: MultiMesh = node.multimesh
			var shown := mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
			multimeshes.append({"node": str(node.get_path()), "instances": shown, "visible": node.is_visible_in_tree()})
		elif node is Light3D and node.is_visible_in_tree():
			lights += 1
		elif node is GPUParticles3D and node.emitting:
			particles += 1
	multimeshes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["instances"] > b["instances"])
	var class_rows: Array = []
	for key: String in classes:
		class_rows.append([key, classes[key]])
	class_rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	var passes: Array = []
	for row: Array in _gpu_passes():
		passes.append({"pass": row[0], "ms": snappedf(row[1], 0.01)})
	var scopes: Dictionary = {}
	for scope: StringName in _scopes:
		scopes[String(scope)] = snappedf(_scopes[scope], 0.01)
	var data := {
		"time": Time.get_datetime_string_from_system(),
		"frame": _frame_stats(),
		"fps": Engine.get_frames_per_second(),
		"gpu_passes": passes,
		"cpu_scopes_ms": scopes,
		"layers_off": _layer_off.keys().filter(func(k: String) -> bool: return _layer_off[k]),
		"lights_visible": lights,
		"particles_emitting": particles,
		"multimesh_top": multimeshes.slice(0, 20),
		"node_classes_top": class_rows.slice(0, 20),
		"adapter": RenderingServer.get_video_adapter_name(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"viewport": get_window().size,
		"render_scale": get_window().scaling_3d_scale,
		"panel": _text.get_parsed_text(),
		"city": city != null,
	}
	DirAccess.make_dir_recursive_absolute(SNAPSHOT_DIR)
	var path := "%s/perf_%s.json" % [SNAPSHOT_DIR, Time.get_datetime_string_from_system().replace(":", "-")]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "  ") + "\n")
		file.close()
		print("PerfMonitor snapshot: %s" % ProjectSettings.globalize_path(path))
	return path


# -- UI --


func _ms(value: float, colored: bool = false) -> String:
	var text := "%5.1f ms" % value
	if not colored:
		return text
	var color := COLOR_OK if value <= BUDGET_MS else (COLOR_WARN if value <= BUDGET_MS * 1.5 else COLOR_BAD)
	return "[color=#%s]%s[/color]" % [color.to_html(false), text]


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.position = Vector2(8, 8)
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.78)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(column)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.custom_minimum_size = Vector2(PANEL_WIDTH - 16, 0)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Menlo", "Consolas", "DejaVu Sans Mono", "monospace"])
	_text.add_theme_font_override("normal_font", mono)
	_text.add_theme_font_override("bold_font", mono)
	_text.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_text.add_theme_font_size_override("bold_font_size", FONT_SIZE)
	column.add_child(_text)
	_graph = Control.new()
	_graph.custom_minimum_size = Vector2(PANEL_WIDTH - 16, 56)
	_graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_graph.draw.connect(_draw_graph)
	column.add_child(_graph)


## Frame-time bars, newest on the right; the line marks the 30 FPS budget.
func _draw_graph() -> void:
	var size := _graph.size
	var top_ms := BUDGET_MS * 2.0
	var bar := size.x / HISTORY
	for i in HISTORY:
		var index := (_frame_cursor + i) % HISTORY
		var ms := _frames[index]
		if ms <= 0.0:
			continue
		var h := clampf(ms / top_ms, 0.0, 1.0) * size.y
		var color := COLOR_OK if ms <= BUDGET_MS else (COLOR_WARN if ms <= BUDGET_MS * 1.5 else COLOR_BAD)
		_graph.draw_rect(Rect2(i * bar, size.y - h, maxf(bar - 0.5, 1.0), h), color)
	var line_y := size.y - BUDGET_MS / top_ms * size.y
	_graph.draw_line(Vector2(0, line_y), Vector2(size.x, line_y), Color(1, 1, 1, 0.6), 1.0)
