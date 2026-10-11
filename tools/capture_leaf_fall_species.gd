extends SceneTree

## Falling-leaf plate for CityLeafFall on a plain backdrop: four fake trees
## (maple, birch, oak, rowan) shed in mid October so each species' atlas leaf
## and autumn tint can be checked without the city around it.
##   tools/godot_render.sh --script tools/capture_leaf_fall_species.gd
## Output: build/season/leaf_fall_species.png

const OUTPUT := "res://build/season/leaf_fall_species.png"


class FakeLod:
	extends Node

	func trees_near(_focus: Vector3, _radius: float) -> Array:
		return [
			[&"maple", Vector3(0, 0, 0), 1.0],
			[&"birch", Vector3(4, 0, 2), 1.0],
			[&"oak", Vector3(-4, 0, 2), 1.0],
			[&"rowan", Vector3(0, 0, 5), 1.0],
		]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Leaf plates need a real renderer (tools/godot_render.sh)")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/season"))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.62, 0.5)
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	viewport.add_child(sun)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.current = true
	var lod := FakeLod.new()
	viewport.add_child(lod)
	var leaves := CityLeafFall.new()
	viewport.add_child(leaves)
	leaves.configure(lod, 600)
	var eye := Vector3(0, 1.6, -3.5)
	camera.look_at_from_position(eye, Vector3(0, 0.9, 2.0), Vector3.UP)
	camera.fov = 55.0
	var date := {"year": 1343, "month": 10, "day": 15}
	# Four seconds of fall so the air is full before the frame is taken.
	for i in 240:
		leaves.update_leaves(Vector3.ZERO, date, Vector2(1, 0), 0.4, 1.0 / 60.0, Vector3(0, 0, 1))
		await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT))
	print("leaf fall plate ", OUTPUT, " shedding ", leaves.shedding)
	quit(0)
