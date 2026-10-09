extends SceneTree

## WR-4 CPU/GPU parity of the bed-aware shore surf (docs/SYSTEMS/CITY_SEA.md).
## Needs a renderer:
##   tools/godot_render.sh --script tools/water_sandbox/shore_parity.gd [-- --wind=0.55,0.95]
## Builds the water sandbox, evaluates shore_state() on the GPU (canvas shader that
## includes shore_swash.gdshaderinc) at probe points across the sand, shingle, reef
## and quay bays, and compares with CityWaterSurface on the CPU: the camera shore
## lift, the surging share and the validity. Times include both sides of the
## ocean_time wrap. Exit code 0 = parity within TOLERANCE, 1 = mismatch.

const Surface := preload("res://scripts/city/city_water_surface.gd")
const SHADER := preload("res://tools/water_sandbox/shore_parity.gdshader")
const CASES: Array[String] = ["sand", "shingle", "reef", "quay"]
const TIMES: Array[float] = [0.6, 3.3, 7.9, 1637.9]
## World units. GPU bilinear filtering uses 8-bit sub-texel weights; a crest face
## moves ~0.5 m per 0.1 s, so a few millimetres of disagreement are expected.
const TOLERANCE := 0.02
const RANGE := 16.0

var _winds: Array[float] = [0.55, 0.95]


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--wind="):
			_winds.clear()
			for w in arg.get_slice("=", 1).split(","):
				_winds.append(float(w))
	call_deferred("_run")


func _run() -> void:
	var sandbox: Node3D = load("res://tools/water_sandbox/water_sandbox.gd").create()
	root.add_child(sandbox)
	var shore: Dictionary = sandbox.world.sea_shore
	var water := MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER)
	var points := PackedVector2Array()
	for id in CASES:
		var cx: float = sandbox.bay_centres[id]
		for k in 48:
			# Offshore source line to the top of the run-up, along two shore lines.
			points.append(Vector2(cx + (k % 2) * 23.0 - 11.0, lerpf(-78.0, 8.0, float(k) / 47.0)))
	var image := Image.create_empty(points.size(), 1, false, Image.FORMAT_RGF)
	for i in points.size():
		image.set_pixel(i, 0, Color(points[i].x, points[i].y, 0.0))
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("probe_points", ImageTexture.create_from_image(image))
	material.set_shader_parameter("probe_count", points.size())
	var viewport := SubViewport.new()
	viewport.size = Vector2i(points.size(), 3)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var rect := ColorRect.new()
	rect.size = Vector2(viewport.size)
	rect.material = material
	viewport.add_child(rect)
	if float(water.get_shader_parameter("shore_bed_valid")) < 0.5:
		push_error("shore parity: the sandbox did not bind the bathymetry atlas")
		quit(1)
		return
	var worst := 0.0
	var worst_at := ""
	var rows := ["lift", "surging", "valid"]
	for wind in _winds:
		water.set_shader_parameter("shore_sea_state", wind)
		_copy_shore_uniforms(water, material)
		for time in TIMES:
			material.set_shader_parameter("probe_time", time)
			await process_frame
			await RenderingServer.frame_post_draw
			var out := viewport.get_texture().get_image()
			for i in points.size():
				var state := Surface.bed_state(shore, points[i], time, water)
				var cpu: Array[float] = [
					Surface.shore_lift(points[i], Surface.field_at(shore, points[i]), time, water, shore),
					float(state["surging"]),
					float(state["valid"]),
				]
				for row in 3:
					var gpu := _decode(out.get_pixel(i, row))
					var error := absf(gpu - cpu[row])
					if error > worst:
						worst = error
						worst_at = "%s wind %.2f t %.1f at %s: gpu %.4f cpu %.4f" % [
							rows[row], wind, time, points[i], gpu, cpu[row]
						]
	var ok := worst <= TOLERANCE
	print("shore parity: %d probes x %d winds x %d times, max error %.5f (%s)%s" % [
		points.size(), _winds.size(), TIMES.size(), worst, worst_at, "" if ok else " FAIL"
	])
	quit(0 if ok else 1)


## Every shore_* uniform the water material carries, so both sides read one state.
func _copy_shore_uniforms(from: ShaderMaterial, to: ShaderMaterial) -> void:
	for uniform: Dictionary in SHADER.get_shader_uniform_list():
		var uniform_name := StringName(uniform["name"])
		if not String(uniform_name).begins_with("shore_"):
			continue
		var value: Variant = from.get_shader_parameter(uniform_name)
		if value != null:
			to.set_shader_parameter(uniform_name, value)
	to.set_shader_parameter(
		"probe_geometry_scale", float(from.get_shader_parameter("shore_geometry_scale"))
	)


func _decode(c: Color) -> float:
	var v := float(c.r8) * 65536.0 + float(c.g8) * 256.0 + float(c.b8)
	return (v / 16777215.0 - 0.5) * RANGE
