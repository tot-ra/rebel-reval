extends SceneTree

## Isolated LM-01 geometry/material parity and studio capture (R-1123).
## tools/godot_render.sh --script tools/capture_landmark_weathering.gd -- after
## Run the same script against the old builder with -- before for comparison.
## No obsolete map definition or whole-city assembly is needed for this recipe.

const Hall := preload("res://scripts/map/view3d/map_view_town_hall_model.gd")
const SIZE := Vector2(26.0, 7.0)
const HEIGHT := 5.0
const OUTPUT_DIR := "res://build/landmark_weathering"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	# No ViewportContainer displays this studio; WHEN_VISIBLE never renders it.
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var building := {"id": &"town_hall_mass", "primitive": &"town_hall_1343"}
	var hall := Node3D.new()
	stage.add_child(hall)
	var wall := MeshInstance3D.new()
	wall.name = "TownHallBody"
	var box := BoxMesh.new()
	box.size = Vector3(SIZE.x, HEIGHT, SIZE.y)
	wall.mesh = box
	wall.position.y = HEIGHT * 0.5
	wall.material_override = Hall.wall_material(building, box.size)
	hall.add_child(wall)
	Hall.add_details(hall, building, SIZE, HEIGHT)
	var snapshot: Array = []
	for child: MeshInstance3D in hall.get_children():
		# Wind uses shader TIME. Freeze capture-only copies, never cached runtime materials.
		var animated := child.material_override as ShaderMaterial
		if animated != null:
			var frozen := animated.duplicate() as ShaderMaterial
			var shader := Shader.new()
			shader.code = animated.shader.code.replace("TIME", "0.0")
			frozen.shader = shader
			child.material_override = frozen
		var mat := child.material_override as StandardMaterial3D
		var item := {"name": String(child.name), "position": str(child.position),
			"rotation": str(child.rotation), "aabb": str(child.mesh.get_aabb())}
		if mat != null:
			item["color"] = str(mat.albedo_color)
			item["uv"] = str(mat.uv1_scale)
			if child.mesh is QuadMesh:
				item["mask"] = mat.albedo_texture.get_image().get_data().hex_encode()
		snapshot.append(item)
	var args := OS.get_cmdline_user_args()
	var label := "after" if args.is_empty() else String(args[0]).validate_filename()
	var file := FileAccess.open("%s/%s.json" % [OUTPUT_DIR, label], FileAccess.WRITE)
	file.store_string(JSON.stringify(snapshot, "\t"))
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.3, 0.35, 0.4)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.5
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, -30.0, 0.0)
	stage.add_child(sun)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(-18.0, 9.0, -24.0)
	camera.look_at(Vector3(0, 3, 0))
	camera.current = true
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image.is_empty() or not _has_scene_pixels(image):
		push_error("Landmark capture is blank (use godot_render.sh and an updating viewport)")
		quit(1)
		return
	var error := image.save_png("%s/%s.png" % [OUTPUT_DIR, label])
	print("landmark weathering capture: %s/%s (%d meshes)" % [OUTPUT_DIR, label, snapshot.size()])
	quit(0 if error == OK else 1)


func _has_scene_pixels(image: Image) -> bool:
	var background := image.get_pixel(0, 0)
	for x in range(0, image.get_width(), 32):
		for y in range(0, image.get_height(), 32):
			if not image.get_pixel(x, y).is_equal_approx(background):
				return true
	return false
