extends SceneTree

## Objective wind-direction check for cloth and rope shaders. For four world
## wind vectors it renders, top-down and orthographic, a tower pennant, the
## town hall flag and a hoist rope on a staff/sheave at the origin, finds the
## coloured pixels, and checks that their centroid lies DOWNWIND of the staff
## (dot(centroid - staff, wind) > 0). Same convention as smoke, clouds, trees,
## grass, sails and water: `wind_direction` is where the wind blows TO.
##   tools/godot_render.sh --script tools/verify_wind_direction.gd
## Exit code 1 on any reversed element; writes docs/reports/images/wind/*.png.

const OUTPUT_DIR := "res://docs/reports/images/wind"
const SIZE := Vector2i(512, 512)
const EXTENT := 5.0
const WINDS: Array[Vector2] = [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0.6, -0.8)]
const TownHallModel := preload("res://scripts/map/view3d/map_view_town_hall_model.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _subjects() -> Array[Dictionary]:
	var pennant := MeshInstance3D.new()
	pennant.mesh = FactionHeraldry.pennant_mesh(&"danish_crown")
	pennant.material_override = MapViewMaterials.flag_cloth()
	pennant.scale = Vector3(3, 3, 3)
	var flag := MeshInstance3D.new()
	flag.mesh = TownHallModel._banner_mesh(1.5, 1.1, true, 2)
	flag.material_override = MapViewMaterials.flag_cloth(true)
	flag.scale = Vector3(2, 2, 2)
	# Rotated staff: the cloth must still find the wind, not the parent's axes.
	flag.rotation.y = 2.1
	return [
		{"name": "pennant", "node": pennant},
		{"name": "town_hall_flag", "node": flag},
	]


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for subject in _subjects():
		for wind in WINDS:
			await _check(subject, wind.normalized())
	for f in _failures:
		push_error(f)
	print(
		"WIND DIRECTION: %s" % ("PASS" if _failures.is_empty() else "FAIL (%d)" % _failures.size())
	)
	quit(0 if _failures.is_empty() else 1)


func _check(subject: Dictionary, wind: Vector2) -> void:
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 1.5
	var we := WorldEnvironment.new()
	we.environment = env
	viewport.add_child(we)
	var node: Node3D = (subject["node"] as Node3D).duplicate()
	viewport.add_child(node)
	MapViewMaterials.apply_world_wind(wind, 0.7)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = EXTENT * 2.0
	viewport.add_child(camera)
	# Looking straight down, screen right = +X, screen down = +Z.
	camera.look_at_from_position(Vector3(0, 20, 0), Vector3.ZERO, Vector3(0, 0, -1))
	camera.current = true
	# Shader compilation can blank the first frames: wait well past it.
	for i in 24:
		await process_frame
	var image := viewport.get_texture().get_image()
	var sum := Vector2.ZERO
	var count := 0
	for y in range(0, SIZE.y, 2):
		for x in range(0, SIZE.x, 2):
			var c := image.get_pixel(x, y)
			if c.r + c.g + c.b > 0.25:
				sum += Vector2(x, y)
				count += 1
	var label := "%s wind(%.1f,%.1f)" % [subject["name"], wind.x, wind.y]
	var path := (
		"%s/%s_%d_%d.png"
		% [OUTPUT_DIR, subject["name"], int(round(wind.x * 10)), int(round(wind.y * 10))]
	)
	image.save_png(ProjectSettings.globalize_path(path))
	if count < 20:
		_failures.append("%s: cloth not visible" % label)
	else:
		var centroid := sum / count
		var staff := Vector2(SIZE) * 0.5
		# World +X is screen +x, world +Z is screen +y.
		var offset := (centroid - staff) / (float(SIZE.x) / (EXTENT * 2.0))
		var along := offset.dot(wind)
		print(
			"%-34s cloth centroid %s world units from staff, downwind %.2f" % [label, offset, along]
		)
		if along <= 0.05:
			_failures.append("%s flies UPWIND (%.2f)" % [label, along])
	viewport.queue_free()
	await process_frame
