extends SceneTree

## R-1321 (VEGR-2) evidence: one gust front crossing a meadow, then the tree
## line, then a pennant, all driven by the shared WindField globals.
##
## Run: tools/godot_render.sh --script tools/capture_wind_front.gd
## Raw frames (wind_front_00..05, about 0.45 s apart, plus calm and storm) go to
## FRAMES_DIR. The committed plates under OUTPUT are built from them:
## - r1321_wind_front_sheet.png: each frame beside its front map, the frame's
##   luminance minus the mean of all gust frames, blurred to front scale (the
##   steady lean cancels, per-tuft flutter averages out). Warm = blades laid
##   over by a gust crest; the warm band should move left to right.
## - r1321_wind_calm_storm.png: the same meadow at strength 0.04 and 0.92.
## The CPU mirror's gust profile is printed per frame for comparison. Shader
## TIME cannot be pinned, so frames are real-time intervals; the tool fails if
## two frames are identical (a minimized window that stopped redrawing).

const OUTPUT := "res://docs/reports/images/vegetation/"
const FRAMES_DIR := "res://build/wind_front/"
const WIND := Vector2(1.0, 0.0)
const FRAME_SECONDS := 0.45
const FRAMES := 6

var viewport: SubViewport
var _frames: Array[Image] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600, 700)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	_add_environment(stage)
	_add_meadow(stage)
	_add_tree_line(stage)
	_add_pennant(stage)
	var camera := Camera3D.new()
	camera.fov = 58.0
	stage.add_child(camera)
	# Side-on and a little above: the wind runs left to right across the frame,
	# meadow first, then the birches, then the pennant.
	camera.position = Vector3(9.0, 3.2, 13.5)
	camera.look_at(Vector3(9.0, 1.4, -2.0))
	camera.current = true

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FRAMES_DIR))
	MapViewMaterials.apply_world_wind(WIND, 0.6)
	await _settle()
	for frame in FRAMES:
		var started := WindField.clock()
		_frames.append(_save("wind_front_%02d" % frame))
		_print_profile(frame, started)
		await create_timer(FRAME_SECONDS).timeout
		await RenderingServer.frame_post_draw
	MapViewMaterials.apply_world_wind(WIND, 0.04)
	await _settle()
	var calm := _save("wind_front_calm")
	MapViewMaterials.apply_world_wind(WIND, 0.92)
	await _settle()
	var storm := _save("wind_front_storm")
	MapViewMaterials.apply_world_wind(WindField.DEFAULT_DIRECTION, WindField.DEFAULT_STRENGTH)
	for i in range(1, _frames.size()):
		if _frames[i].get_data() == _frames[i - 1].get_data():
			push_error("Wind front frames %d and %d are identical; re-run" % [i - 1, i])
			quit(1)
			return
	_write_plate(_front_sheet(), "r1321_wind_front_sheet")
	_write_plate(_stack([calm, storm]), "r1321_wind_calm_storm")
	viewport.queue_free()
	await process_frame
	quit()


func _settle() -> void:
	for _frame in 10:
		await process_frame
	await RenderingServer.frame_post_draw


func _add_environment(stage: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("8e9ba3")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b4c5cf")
	env.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34.0, -150.0, 0.0)
	sun.light_color = Color("fff0d4")
	sun.light_energy = 1.25
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(90.0, 50.0)
	ground.mesh = plane
	var earth := StandardMaterial3D.new()
	earth.albedo_color = Color("4a4f30")
	earth.roughness = 1.0
	ground.material_override = earth
	ground.position = Vector3(4.0, -0.02, 0.0)
	stage.add_child(ground)


## A 34 m strip of tufts along the wind (x from -12 to 22).
func _add_meadow(stage: Node3D) -> void:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in 14000:
		var x := MapViewMeshBuilderMath.hash01(i, 3, 991) * 34.0 - 12.0
		var z := MapViewMeshBuilderMath.hash01(i, 7, 997) * 12.0 - 6.0
		var scale := 0.55 + MapViewMeshBuilderMath.hash01(i, 11, 1009) * 0.6
		transforms.append(
			Transform3D(Basis(Vector3.UP, float(i)).scaled(Vector3.ONE * scale), Vector3(x, 0.0, z))
		)
		colors.append(
			Color(0.82, 0.98, 0.72).lerp(
				Color(1.08, 1.0, 0.86), MapViewMeshBuilderMath.hash01(i, 13, 1013)
			)
		)
	var grass := MapViewMeshBuilderPrimitives.multi_mesh(
		"Meadow",
		MapViewFoliageMeshes.grass_tuft_mesh(),
		transforms,
		colors,
		MapViewMaterials.grass_blades(),
		Vector3.ZERO
	)
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(grass)


## Birches downwind of the meadow: the same front reaches them later.
func _add_tree_line(stage: Node3D) -> void:
	for i in 4:
		var location := Vector3(24.0 + (i % 2) * 2.0, 0.0, -5.0 + i * 2.5)
		for part in [
			[MapViewTreeMeshes.wood_mesh(&"birch"), MapViewMaterials.bark(MapViewTreeSpecies.bark_kind_for(&"birch"))],  # gdlint: ignore=max-line-length
			[MapViewTreeMeshes.canopy_mesh(&"birch"), MapViewMaterials.canopy_for_species(&"birch")],
		]:
			var instance := MeshInstance3D.new()
			instance.mesh = part[0]
			instance.material_override = part[1]
			instance.position = location
			stage.add_child(instance)


func _add_pennant(stage: Node3D) -> void:
	var base := Vector3(29.5, 0.0, 2.0)
	var staff := MeshInstance3D.new()
	var staff_mesh := CylinderMesh.new()
	staff_mesh.top_radius = 0.04
	staff_mesh.bottom_radius = 0.05
	staff_mesh.height = 3.4
	staff.mesh = staff_mesh
	staff.position = base + Vector3(0.0, 1.7, 0.0)
	stage.add_child(staff)
	var flag := MeshInstance3D.new()
	flag.mesh = FactionHeraldry.pennant_mesh(FactionHeraldry.DANISH_CROWN)
	flag.material_override = MapViewMaterials.flag_cloth()
	flag.scale = Vector3.ONE * 2.0
	flag.position = base + Vector3(0.0, 3.3, 0.0)
	stage.add_child(flag)


func _print_profile(frame: int, time: float) -> void:
	var line := PackedStringArray()
	for x in range(-12, 32, 4):
		line.append("%d:%.2f" % [x, WindField.gust(Vector2(x, 0.0), time)])
	print("Wind front frame %02d t=%.2f  %s" % [frame, time, " ".join(line)])


func _save(name: String) -> Image:
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	var path := ProjectSettings.globalize_path(FRAMES_DIR).path_join(name + ".png")
	if image.save_png(path) != OK:
		push_error("Wind front capture failed: %s" % path)
		quit(1)
	print("Wind front capture: ", path)
	return image


func _write_plate(image: Image, name: String) -> void:
	var path := ProjectSettings.globalize_path(OUTPUT).path_join(name + ".png")
	if image.save_png(path) != OK:
		push_error("Wind front plate failed: %s" % path)
		quit(1)
	print("Wind front plate: ", path)


## Lower 70 percent of a frame (the sky carries no wind), at half size.
func _ground(image: Image) -> Image:
	var top := int(image.get_height() * 0.3)
	var ground := image.get_region(Rect2i(0, top, image.get_width(), image.get_height() - top))
	ground.resize(ground.get_width() / 2, ground.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	return ground


func _stack(images: Array[Image]) -> Image:
	var parts: Array[Image] = []
	for image in images:
		parts.append(_ground(image))
	var w := parts[0].get_width()
	var h := parts[0].get_height()
	var sheet := Image.create(w, h * parts.size(), false, Image.FORMAT_RGB8)
	for i in parts.size():
		sheet.blit_rect(parts[i], Rect2i(0, 0, w, h), Vector2i(0, h * i))
	return sheet


func _front_sheet() -> Image:
	var parts: Array[Image] = []
	for frame in _frames:
		parts.append(_ground(frame))
	var w := parts[0].get_width()
	var h := parts[0].get_height()
	var luminance: Array[PackedFloat32Array] = []
	var mean := PackedFloat32Array()
	mean.resize(w * h)
	for part in parts:
		var values := PackedFloat32Array()
		values.resize(w * h)
		for y in h:
			for x in w:
				var value := part.get_pixel(x, y).get_luminance()
				values[y * w + x] = value
				mean[y * w + x] += value / parts.size()
		luminance.append(values)
	var sheet := Image.create(w * 2, h * parts.size(), false, Image.FORMAT_RGB8)
	for i in parts.size():
		var deviation := Image.create(w, h, false, Image.FORMAT_RF)
		for y in h:
			for x in w:
				deviation.set_pixel(x, y, Color(luminance[i][y * w + x] - mean[y * w + x], 0, 0))
		# Down and up again is a cheap front-scale blur that drops per-tuft flutter.
		# Lanczos averages the footprint; bilinear would alias the flutter.
		deviation.resize(w / 20, h / 20, Image.INTERPOLATE_LANCZOS)
		deviation.resize(w, h, Image.INTERPOLATE_CUBIC)
		var heat := Image.create(w, h, false, Image.FORMAT_RGB8)
		for y in h:
			for x in w:
				var v := clampf(deviation.get_pixel(x, y).r * 45.0, -1.0, 1.0)
				heat.set_pixel(
					x, y, Color.BLACK.lerp(Color("ffd040") if v > 0.0 else Color("1030a0"), absf(v))
				)
		sheet.blit_rect(parts[i], Rect2i(0, 0, w, h), Vector2i(0, h * i))
		sheet.blit_rect(heat, Rect2i(0, 0, w, h), Vector2i(w, h * i))
	# Keeps the plate under the 1.5 MiB evidence cap (ASSET_STORAGE_POLICY.md).
	sheet.resize(sheet.get_width() * 3 / 4, sheet.get_height() * 3 / 4, Image.INTERPOLATE_LANCZOS)
	return sheet
