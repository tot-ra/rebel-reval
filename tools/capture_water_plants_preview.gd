extends SceneTree

## Close-up of the moat floating plants (lily pads, blooms, duckweed fronds) on a
## flat water plane, so mesh detail can be reviewed without finding them in the city.
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
		"pad": [CityMoatPlants._pad_mesh(), Color(0.2, 0.42, 0.16), -1.5, 1.0],
		"flower": [CityMoatPlants._flower_mesh(), Color.WHITE, 0.0, 1.0],
		"fronds": [CityMoatPlants._frond_cluster_mesh(), Color.WHITE, 1.8, 2.0],
	}
	for key: String in xs:
		var d: Array = xs[key]
		var basis := Basis().scaled(Vector3.ONE * float(d[3]) * 2.2)
		var xf: Array[Transform3D] = [Transform3D(basis, Vector3(float(d[2]), 0.02, 0))]
		var c: Array[Color] = [Color.WHITE]
		CityMoatPlants._add_floating(holder, key, d[0], xf, c, d[1])
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0, 4.0, 3.0)
	cam.look_at(Vector3(0, 0, 0))
	for i in 10:
		await process_frame
	root.get_texture().get_image().save_png("res://build/water_plants_preview.png")
	quit()
