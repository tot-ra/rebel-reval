extends SceneTree
## P0-142 HDR output probe (Godot 4.7 EDR on macOS). GPU run, root window, no SubViewport:
##   tools/godot_render.sh --rendering-method mobile --rendering-driver metal \
##     --script tools/probe_hdr_output.gd -- --json=res://build/hdr_spike/mobile/hdr_probe.json
##
## WHY: HDR output only reaches the screen through a Window, so SubViewport captures cannot
## show it. The probe requests HDR on the root window, renders emissive patches at known
## scene-linear values through the shipped MapViewLighting post-process (AgX), draws a UI
## white rectangle on a CanvasLayer, then reads the root framebuffer back as float. On an
## EDR display a patch whose read-back value exceeds the UI white sample is brighter than
## reference white. Variants repeat the read with Filmic and additive glow so the report
## shows which settings clamp to SDR.
## Optional --map=kalev_smithy also frames the real forge hearth at night (hearth_close).
## Optional --sun-map=smithy_courtyard frames the real sky sun disk on a clear midday
## (R-1537 sun follow-up: the visible disk must exceed UI white, not just the patches).
## --sun-progress=<0..1> picks the day-cycle point (default 0.5, midday; ~0.27 sunrise).
## --screen=<index> moves the window to that screen first (default: the screen with the
## largest HDR headroom, e.g. the built-in Liquid Retina XDR rather than an SDR monitor).

const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const Lighting := preload("res://scripts/map/view3d/map_view_lighting.gd")
const Registry := preload("res://scripts/map/map_audit_registry.gd")

## Scene-linear patch values: dim wall, SDR white, lamp, forge glow, fire core, sun disc.
const PATCHES: Array[Dictionary] = [
	{"id": "wall_0_5", "value": 0.5},
	{"id": "white_1", "value": 1.0},
	{"id": "lamp_2", "value": 2.0},
	{"id": "forge_4", "value": 4.0},
	{"id": "fire_8", "value": 8.0},
	{"id": "sun_16", "value": 16.0},
]
const VARIANTS: Array[Dictionary] = [
	{"id": "shipped_agx_softlight", "tonemap": Environment.TONE_MAPPER_AGX,
		"glow": Environment.GLOW_BLEND_MODE_SOFTLIGHT},
	{"id": "agx_additive_glow", "tonemap": Environment.TONE_MAPPER_AGX,
		"glow": Environment.GLOW_BLEND_MODE_ADDITIVE},
	{"id": "agx_no_glow", "tonemap": Environment.TONE_MAPPER_AGX, "glow": -1},
	{"id": "filmic_prologue", "tonemap": Environment.TONE_MAPPER_FILMIC,
		"glow": Environment.GLOW_BLEND_MODE_SOFTLIGHT},
]
const SIZE := Vector2i(1280, 720)
const PATCH_SPACING := 1.6
const UI_RECT := Rect2(40, 40, 120, 60)

var _env: Environment
var _camera: Camera3D
var _image_size := SIZE


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var json_path := "res://build/hdr_spike/hdr_probe.json"
	var map_id := ""
	var sun_map_id := ""
	var sun_progress := 0.5
	var screen := -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--json="):
			json_path = arg.trim_prefix("--json=")
		elif arg.begins_with("--map="):
			map_id = arg.trim_prefix("--map=")
		elif arg.begins_with("--sun-map="):
			sun_map_id = arg.trim_prefix("--sun-map=")
		elif arg.begins_with("--sun-progress="):
			sun_progress = float(arg.trim_prefix("--sun-progress="))
		elif arg.begins_with("--screen="):
			screen = int(arg.trim_prefix("--screen="))
	root.size = SIZE
	# Runtime equivalents of display/window/hdr/request_hdr_output and rendering/viewport/hdr_2d.
	root.use_hdr_2d = true
	root.hdr_output_requested = true
	for _frame in 30:
		await process_frame
	var window_id := root.get_window_id()
	var screens := []
	var best_screen := DisplayServer.window_get_current_screen(window_id)
	var best_headroom := 0.0
	for index in DisplayServer.get_screen_count():
		DisplayServer.window_set_current_screen(index, window_id)
		for _frame in 20:
			await process_frame
		var headroom := root.get_output_max_linear_value()
		screens.append({"index": index, "size": DisplayServer.screen_get_size(index),
			"max_linear": headroom,
			"max_nits": DisplayServer.window_get_hdr_output_current_max_luminance(window_id),
			"reference_nits": DisplayServer.window_get_hdr_output_current_reference_luminance(window_id)})
		if headroom > best_headroom:
			best_headroom = headroom
			best_screen = index
	DisplayServer.window_set_current_screen(best_screen if screen < 0 else screen, window_id)
	for _frame in 20:
		await process_frame
	var report := {
		"task_id": "P0-142",
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"hdr_output_supported": DisplayServer.window_is_hdr_output_supported(window_id),
		"hdr_output_requested": DisplayServer.window_is_hdr_output_requested(window_id),
		"hdr_output_enabled": DisplayServer.window_is_hdr_output_enabled(window_id),
		"reference_luminance_nits": DisplayServer.window_get_hdr_output_current_reference_luminance(window_id),
		"max_luminance_nits": DisplayServer.window_get_hdr_output_current_max_luminance(window_id),
		"output_max_linear_value": root.get_output_max_linear_value(),
		"screen": DisplayServer.window_get_current_screen(window_id),
		"screens": screens,
		"variants": [],
	}
	_build_patch_scene()
	for variant in VARIANTS:
		_apply_variant(variant)
		for _frame in 6:
			await process_frame
		var image := root.get_texture().get_image()
		# Retina: the framebuffer can be 2x the logical window size; rects scale with it.
		_image_size = image.get_size()
		var row := {"id": variant["id"], "format": image.get_format(), "image_size": _image_size,
			"ui_white": _sample(image, _scaled(UI_RECT))}
		var patches := {}
		for index in PATCHES.size():
			patches[PATCHES[index]["id"]] = _sample(image, _scaled(_patch_rect(index)))
		row["patches"] = patches
		row["max_patch_over_ui_white"] = _max_over(patches, row["ui_white"])
		(report["variants"] as Array).append(row)
		image.save_exr(ProjectSettings.globalize_path(json_path.get_base_dir() + "/hdr_probe_%s.exr" % variant["id"]))
		print("HDR probe %s: ui_white %.3f, patches %s" % [variant["id"], row["ui_white"], patches])
	if not map_id.is_empty():
		report["map_frame"] = await _probe_map(map_id)
	if not sun_map_id.is_empty():
		report["sun_frame"] = await _probe_sun(sun_map_id, sun_progress)
	var absolute := ProjectSettings.globalize_path(json_path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("HDR probe: enabled=%s max_linear=%.3f -> %s" % [
		report["hdr_output_enabled"], report["output_max_linear_value"], json_path])
	quit(0)


func _build_patch_scene() -> void:
	var world_environment := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.02, 0.02, 0.02)
	Lighting.configure_post_process(_env)
	Lighting.apply_post_grade(_env, 0.0)
	world_environment.environment = _env
	root.add_child(world_environment)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 6.0
	_camera.position = Vector3(0, 0, 10)
	root.add_child(_camera)
	_camera.make_current()
	var shader := Shader.new()
	# Unshaded so the patch writes exactly `value` into the scene-linear buffer.
	shader.code = "shader_type spatial; render_mode unshaded; uniform float value; void fragment() { ALBEDO = vec3(value); }"
	for index in PATCHES.size():
		var quad := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(1.2, 1.2)
		quad.mesh = mesh
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("value", float(PATCHES[index]["value"]))
		quad.material_override = material
		quad.position = Vector3(_patch_x(index), -0.8, 0)
		root.add_child(quad)
	var layer := CanvasLayer.new()
	var ui_white := ColorRect.new()
	ui_white.color = Color.WHITE
	ui_white.position = UI_RECT.position
	ui_white.size = UI_RECT.size
	layer.add_child(ui_white)
	var label := Label.new()
	label.text = "UI reference white"
	label.position = UI_RECT.position + Vector2(0, UI_RECT.size.y + 6)
	layer.add_child(label)
	root.add_child(layer)


func _apply_variant(variant: Dictionary) -> void:
	_env.tonemap_mode = variant["tonemap"]
	_env.glow_enabled = int(variant["glow"]) >= 0
	if _env.glow_enabled:
		_env.glow_blend_mode = variant["glow"]


## Logical (SIZE) rect -> read-back image pixels.
func _scaled(rect: Rect2) -> Rect2:
	# Stretch mode "viewport" renders at the 1920x1080 content size, not the window size.
	var factor := Vector2(_image_size) / root.get_visible_rect().size
	return Rect2(rect.position * factor, rect.size * factor)


func _patch_x(index: int) -> float:
	return (float(index) - float(PATCHES.size() - 1) * 0.5) * PATCH_SPACING


## Screen rect of a patch centre (inner 40%, away from glow halo edges).
func _patch_rect(index: int) -> Rect2:
	var logical := root.get_visible_rect().size
	var pixels_per_unit := logical.y / _camera.size
	var centre := logical * 0.5 + Vector2(_patch_x(index), 0.8) * pixels_per_unit
	var half := 0.2 * 1.2 * pixels_per_unit
	return Rect2(centre - Vector2(half, half), Vector2(half, half) * 2.0)


## Mean of the max RGB channel over a rect. Float formats keep values above 1.0.
func _sample(image: Image, rect: Rect2) -> float:
	var total := 0.0
	var count := 0
	for y in range(int(rect.position.y), int(rect.end.y), 4):
		for x in range(int(rect.position.x), int(rect.end.x), 4):
			var c := image.get_pixel(x, y)
			total += maxf(c.r, maxf(c.g, c.b))
			count += 1
	return total / maxf(count, 1)


func _max_over(patches: Dictionary, ui_white: float) -> float:
	var best := 0.0
	for value in patches.values():
		best = maxf(best, float(value))
	return best / maxf(ui_white, 0.0001)


## Real forge hearth at night, root window, same HDR request. Reports how much of the
## frame exceeds UI white and the peak value.
func _probe_map(map_id: String) -> Dictionary:
	for child in root.get_children():
		if child is Node3D or child is WorldEnvironment:
			child.queue_free()
	await process_frame
	var definition: MapDefinition = Registry.by_id()[map_id]
	var view := MapView3D.create(definition, MapBuilder.build(definition), MapView3D.TIME_NIGHT)
	root.add_child(view)
	await view.assemble_async(200.0)
	view.set_close_camera_mode(true)
	var camera := Camera3D.new()
	camera.fov = 70.0
	camera.near = 0.05
	root.add_child(camera)
	camera.make_current()
	camera.position = Vector3(21.2, 1.7, 5.4)
	camera.look_at(Vector3(20.3, 1.2, 1.8), Vector3.UP)
	for _frame in 20:
		await process_frame
	var image := root.get_texture().get_image()
	var peak := 0.0
	var over := 0
	var count := 0
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			var c := image.get_pixel(x, y)
			var v := maxf(c.r, maxf(c.g, c.b))
			peak = maxf(peak, v)
			if v > 1.001:
				over += 1
			count += 1
	var png := ProjectSettings.globalize_path("res://build/hdr_spike/%s_hdr_%s.png" % [
		RenderingServer.get_current_rendering_method(), map_id])
	image.convert(Image.FORMAT_RGBA8)
	image.save_png(png)
	return {"map_id": map_id, "shot": "hearth_close_night", "peak": peak,
		"output_max_linear_value": root.get_output_max_linear_value(),
		"fraction_over_ui_white": float(over) / maxf(count, 1), "ui_white": _sample(
			root.get_texture().get_image(), _scaled(UI_RECT))}

## Real sky sun disk: clear weather near midday, camera aimed at the sun. Reports the peak
## and the UI white sample so peak / ui_white is the disk brightness in UI-white units.
func _probe_sun(map_id: String, progress: float) -> Dictionary:
	for child in root.get_children():
		if child is Node3D or child is WorldEnvironment:
			child.queue_free()
	await process_frame
	var definition: MapDefinition = Registry.by_id()[map_id]
	var view := MapView3D.create(definition, MapBuilder.build(definition), MapView3D.TIME_DAY)
	root.add_child(view)
	await view.assemble_async(200.0)
	view.set_weather_time_scale(0.0)
	for node in view.find_children("*", "", true, false):
		if node is SkyWeather3D:
			var sky := node as SkyWeather3D
			sky.set_weather(SkyWeather3D.WEATHER_CLOUDLESS)
			# Finish the weather blend now; time_scale 0 above freezes it otherwise.
			sky.advance(SkyWeather3D.TRANSITION_SECONDS + 1.0)
	view.apply_cycle_progress(progress)
	var sun: DirectionalLight3D = view.find_children("*", "DirectionalLight3D", true, false)[0]
	var camera := Camera3D.new()
	camera.fov = 60.0
	root.add_child(camera)
	camera.make_current()
	camera.position = Vector3(0, 2.0, 0)
	# A DirectionalLight3D shines along its -Z, so the sun sits along +Z.
	camera.look_at(camera.position + sun.global_transform.basis.z, Vector3.UP)
	for _frame in 30:
		await process_frame
	var image := root.get_texture().get_image()
	var peak := 0.0
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			var c := image.get_pixel(x, y)
			peak = maxf(peak, maxf(c.r, maxf(c.g, c.b)))
	var ui_white := _sample(image, _scaled(UI_RECT))
	var exr := ProjectSettings.globalize_path("res://build/hdr_spike/%s_sun_%s.exr" % [
		RenderingServer.get_current_rendering_method(), map_id])
	image.save_exr(exr)
	_heat_map(image, ui_white).save_png(exr.trim_suffix(".exr") + "_heat.png")
	image.convert(Image.FORMAT_RGBA8)
	image.save_png(exr.trim_suffix(".exr") + ".png")
	print("HDR probe sun %s: peak %.3f ui_white %.3f (%.2fx)" % [
		map_id, peak, ui_white, peak / maxf(ui_white, 0.0001)])
	return {"map_id": map_id, "shot": "sun_clear_noon", "peak": peak, "ui_white": ui_white,
		"peak_over_ui_white": peak / maxf(ui_white, 0.0001),
		"output_max_linear_value": root.get_output_max_linear_value(),
		"sun_direction": sun.global_transform.basis.z}


## False colour for screenshots, since a PNG cannot show EDR: grey up to UI white, then
## yellow (1-2x), orange (2-4x) and red (4x and above UI white).
func _heat_map(image: Image, ui_white: float) -> Image:
	var heat := Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGB8)
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			var v := maxf(c.r, maxf(c.g, c.b)) / maxf(ui_white, 0.0001)
			var out := Color(1, 0.1, 0.1) if v >= 4.0 else Color(1, 0.55, 0.1) if v >= 2.0 \
				else Color(1, 0.95, 0.2) if v > 1.0 else Color(v, v, v) * 0.6
			heat.set_pixel(x, y, out)
	return heat
