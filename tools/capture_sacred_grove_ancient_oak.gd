extends SceneTree

## Reproducible in-engine review capture for the Sacred Grove hero oak.
## Run: godot --path . --script tools/capture_sacred_grove_ancient_oak.gd

const Registry := preload("res://scripts/map/map_audit_registry.gd")
const OUTPUT_DIR := "res://generated/blender/sacred_grove_ancient_oak_v1/godot"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const MAP_ID := "world.sacred_grove"
const OAK_BASE := Vector3(32.0, 0.0, 13.0)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var definitions := Registry.by_id()
	if not definitions.has(MAP_ID):
		push_error("Sacred Grove definition is unavailable: %s" % MAP_ID)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var definition: MapDefinition = definitions[MAP_ID]
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var view := MapView3D.create(definition, MapBuilder.build(definition), MapView3D.TIME_DAY)
	viewport.add_child(view)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 58.0
	camera.near = 0.05
	camera.far = 250.0
	viewport.add_child(camera)
	camera.make_current()
	camera.position = Vector3(32.0, 1.7, 23.0)
	camera.look_at(OAK_BASE + Vector3(0.0, 8.0, 0.0), Vector3.UP)
	for frame in 10:
		await process_frame
	var output := "%s/sacred_grove_ancient_oak_path_approach.png" % OUTPUT_DIR
	var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Could not save Sacred Grove oak capture %s: %s" % [output, error_string(error)])
		quit(1)
		return
	print("Sacred Grove oak capture: %s" % output)
	quit(0)
