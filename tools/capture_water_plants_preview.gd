extends SceneTree

## Close-up of the moat water plants (textured lily pad, bloom, duckweed patch,
## reed and cattail clumps) on a flat water plane, so mesh detail can be reviewed
## without finding them in the city.
##   tools/godot_render.sh --script tools/capture_water_plants_preview.gd
## Output: build/water_plants_preview.png


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	water.mesh = plane
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.2, 0.28, 0.18)
	water.material_override = wm
	root.add_child(water)
	var holder := Node3D.new()
	root.add_child(holder)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, 30, 0)
	root.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.75, 0.8)
	root.add_child(env)
	var xs := {
		"pad": [CityMoatPlants._pad_mesh(), CityMoatPlants.PAD_TINT, -1.5, 1.0,
			CityMoatPlants.PAD_TEXTURE],
		"flower": [CityMoatPlants._quad_mesh(0.17, 0.03), Color.WHITE, -0.9, 1.0,
			CityMoatPlants.FLOWER_TEXTURE],
		"duckweed": [CityMoatPlants._quad_mesh(1.0, 0.0), CityMoatPlants.DUCKWEED_TINT, 1.6, 0.6,
			CityMoatPlants.DUCKWEED_TEXTURE],
	}
	for key: String in xs:
		var d: Array = xs[key]
		var basis := Basis().scaled(Vector3.ONE * float(d[3]) * 2.2)
		var xf: Array[Transform3D] = [Transform3D(basis, Vector3(float(d[2]), 0.02, 0))]
		var c: Array[Color] = [Color.WHITE]
		CityMoatPlants._add_floating(holder, key, d[0], xf, c, d[1], d[4])
	# A reed clump and a cattail clump behind the floaters, for the blade detail.
	var clump := Basis().scaled(Vector3.ONE * 2.0)
	var reed_xf: Array[Transform3D] = [Transform3D(clump, Vector3(-0.6, 0, -1.6))]
	var cat_xf: Array[Transform3D] = [Transform3D(clump, Vector3(0.8, 0, -1.6))]
	var white: Array[Color] = [Color.WHITE]
	CityMoatPlants._add_reeds(holder, reed_xf, white)
	CityMoatPlants._add_cattails(holder, cat_xf, white)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0, 3.2, 3.2)
	cam.look_at(Vector3(0, 0, 0))
	for i in 10:
		await process_frame
	root.get_texture().get_image().save_png("res://build/water_plants_preview.png")
	quit()
