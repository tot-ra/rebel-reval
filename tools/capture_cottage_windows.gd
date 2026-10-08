extends SceneTree

## Window material/geometry review, interior plate and actual plan-building
## samples. Run only through tools/godot_render.sh (no visible Godot window).

const Openings := preload("res://scripts/city/city_window_openings.gd")
const OUTPUT := "res://build/windows/"

var viewport: SubViewport
var camera: Camera3D
var stage: Node3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	viewport = SubViewport.new()
	viewport.size = Vector2i(2000, 850)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.48, 0.58, 0.65)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.83, 0.88)
	env.ambient_light_energy = 0.65
	var we := WorldEnvironment.new()
	we.environment = env
	viewport.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	viewport.add_child(sun)
	camera = Camera3D.new()
	viewport.add_child(camera)
	camera.current = true
	stage = Node3D.new()
	viewport.add_child(stage)
	_variants()
	camera.look_at_from_position(Vector3(8.4, 2.1, 9), Vector3(8.4, 1.55, 0))
	camera.fov = 90
	await _save("cottage_windows.png")
	# Inward view through the identical apertures and glazing, with a coloured
	# exterior object to make transparency differences unambiguous.
	camera.look_at_from_position(Vector3(8.4, 1.8, -9), Vector3(8.4, 1.5, 0))
	await _save("interior_windows.png")
	stage.queue_free()
	await process_frame
	stage = Node3D.new()
	viewport.add_child(stage)
	_plan_samples()
	camera.look_at_from_position(Vector3(20, 12, 29), Vector3(17, 2, 0))
	camera.fov = 70
	await _save("plan_houses.png")
	quit(0)


func _mesh(shell: CityBuildingBuilder.Shell, offset := Vector3.ZERO) -> void:
	var inst := MeshInstance3D.new()
	inst.mesh = shell.to_mesh(CityBuildingBuilder.material_for_key)
	inst.position = offset
	stage.add_child(inst)


func _label(text: String, at: Vector3, reverse := false) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.pixel_size = 0.003
	label.font_size = 40
	label.outline_size = 8
	if reverse:
		label.rotation.y = PI
	stage.add_child(label)


func _variants() -> void:
	var shell := CityBuildingBuilder.Shell.new()
	var styles: Array[StringName] = [
		&"plain", &"shutters_open", &"surround", &"leaded", &"panelled", &"shutters_closed", &"slit"
	]
	var glass: Array[StringName] = [
		&"open", &"horn", &"forest", &"clear", &"forest", &"forest", &"open"
	]
	var names := [
		"Bare wood / unglazed",
		"Shutters / horn",
		"Stone / forest glass",
		"Fine lead / clearer glass",
		"Panel borders / earth paint",
		"Closed shutters",
		"Smoke slit"
	]
	var windows: Array[Dictionary] = []
	for i in styles.size():
		var m := Vector2(1.2 + 2.4 * i, 0)
		var house_look := {
			"rural": i == 0 or i == 6,
			"trim": CityWindows.TRIM_PAINTS[i % 6],
			"shutter": CityWindows.TRIM_PAINTS[(i + 2) % 6],
			"style": styles[i],
			"glazing": glass[i],
			"panes": 1 + i % 3
		}
		windows.append(
			{
				"m": m,
				"dir": Vector2.RIGHT,
				"nrm": Vector2(0, 1),
				"base_y": 1.05,
				"y": 1.4 if i == 6 else 1.05,
				"w": 0.62 if i == 6 else 0.72,
				"h": 0.3 if i == 6 else 0.95,
				"jitter": 0.6,
				"style": styles[i],
				"look": house_look
			}
		)
		# Individual panels make the three wall families visible on the same plate.
		var key := "wall:log" if i == 0 or i == 6 else "wall:limestone"
		for z: float in [0.0, -0.62]:
			shell.quad_out(
				key if z == 0 else "interior",
				Vector3(m.x - 1.2, 0, z),
				Vector3(m.x + 1.2, 0, z),
				Vector3(m.x + 1.2, 2.7, z),
				Vector3(m.x - 1.2, 2.7, z),
				Color.WHITE,
				Vector3.BACK if z == 0 else Vector3.FORWARD
			)
		_label(names[i], Vector3(m.x, 3.15, 0.15))
		_label(names[i], Vector3(m.x, 3.15, -0.8), true)
	Openings.cut(shell, windows, 0.62)
	for window in windows:
		CityWindows.add_placed(shell, window)
		CityWindows.add_interior(shell, window, 0.62)
	_mesh(shell)
	# Bright terracotta objects visible only through actual holes/clearer panes.
	for z: float in [-2.5, 2.5]:
		for i in 7:
			var box := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.35, 1.5, 0.35)
			box.mesh = mesh
			box.position = Vector3(1.2 + i * 2.4, 1.5, z)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.72, 0.18, 0.08)
			box.material_override = mat
			stage.add_child(box)


func _plan_samples() -> void:
	var plan := CityPlan.load_default()
	var slot := 0
	for family: String in ["log", "plank", "limestone"]:
		for i in plan.buildings.size():
			var b: Dictionary = plan.buildings[i]
			if b.get("material", "") != family or not b.get("openings", true):
				continue
			if b.get("kind", "") != "house" or float(b["wall_h"]) > 8.0:
				continue
			var ring := plan.footprint(i)
			var centre := Vector2.ZERO
			for p in ring:
				centre += p
			centre /= ring.size()
			for k in ring.size():
				ring[k] -= centre
			var source_floor := plan.floor_height(i)
			var local_b := b.duplicate(true)
			local_b["base_h"] = float(b["base_h"]) - source_floor
			if b.get("door") != null:
				local_b["door"] = [b["door"][0] - centre.x, b["door"][1] - centre.y]
			var built := CityBuildingBuilder.build_building(local_b, ring, 0, true)
			var offset := Vector3(slot * 17, 0, 0)
			_mesh(built["shell"], offset)
			_mesh(built["roof"], offset)
			_label(String(b["id"]), offset + Vector3(0, 0.3, 6))
			print("Plan building: ", b["id"], " / ", family)
			slot += 1
			break


func _save(filename: String) -> void:
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := viewport.get_texture().get_image().save_png(
		ProjectSettings.globalize_path(OUTPUT + filename)
	)
	if error != OK:
		push_error("Capture failed: %s" % filename)
		quit(1)
	print("captured ", OUTPUT + filename)
