extends SceneTree

## R-1684: production city roof geometry and material, unobscured by house GLBs.
## tools/godot_render.sh --resolution 1600x900 --script tools/capture_roof_growth.gd
## Optional -- --unbound verifies transparent fallback; --wet verifies rain.
const OUTPUT_DIR := "res://docs/reports/images/vegetation"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	CityBuildingBuilder.bind_ground(CityPlan.load_default())
	var unbound := "--unbound" in OS.get_cmdline_user_args()
	var wet := "--wet" in OS.get_cmdline_user_args()
	var scene := Node3D.new()
	root.add_child(scene)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color8(148, 168, 186)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color8(180, 184, 190)
	env.ambient_light_energy = 0.65
	world.environment = env
	scene.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -28, 0)
	sun.light_color = Color8(255, 236, 208)
	sun.light_energy = 0.95
	scene.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 50.0
	scene.add_child(camera)
	camera.look_at_from_position(Vector3(6, 8.8, -1.5), Vector3(4, 6.2, 2.2))
	camera.make_current()
	var ring := PackedVector2Array([
		Vector2(0, 0), Vector2(8, 0), Vector2(8, 8), Vector2(0, 8),
	])
	for family: StringName in [&"tile", &"shingle", &"thatch"]:
		var b := {
			"id": "capture.roof_growth", "kind": "outbuilding", "material": "plank",
			"roof": String(family), "base_h": 0.0, "wall_h": 4.0,
			"ridge_angle": 0.0, "roof_pitch_deg": 48.0, "openings": false,
		}
		var built := CityBuildingBuilder.build_building(b, ring, 0.0, false)
		var mesh := MeshInstance3D.new()
		mesh.mesh = (built["roof"] as CityBuildingBuilder.Shell).to_mesh(
			CityBuildingBuilder.material_for_key)
		var mat := CityBuildingBuilder.roof_material(family) as ShaderMaterial
		mat.set_shader_parameter("wetness", 1.0 if wet else 0.0)
		if unbound:
			# A fresh shader has no defaults; exercise the actual sampler hints.
			var shader := Shader.new()
			shader.code = mat.shader.code
			var clean := mat.duplicate() as ShaderMaterial
			clean.shader = shader
			mesh.material_override = clean
		scene.add_child(mesh)
		for _frame in 24:
			await process_frame
		await RenderingServer.frame_post_draw
		var suffix := "unbound" if unbound else ("wet" if wet else "dry")
		var path := "%s/r1684_roof_%s_%s.png" % [OUTPUT_DIR, family, suffix]
		var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		if error != OK:
			push_error("Failed roof growth capture: %s" % path)
			quit(1)
			return
		print("captured ", path)
		mesh.queue_free()
		await process_frame
	quit(0)
