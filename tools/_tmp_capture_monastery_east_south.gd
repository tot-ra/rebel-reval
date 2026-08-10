extends SceneTree

const MonasteryQuarterDefinition := preload("res://scripts/map/definitions/prototypes/monastery_quarter_definition.gd")
const OUTPUT_PATH := "/tmp/monastery_east_south_after.png"
const VIEWPORT_SIZE := Vector2i(1600, 1000)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var definition: MapDefinition = MonasteryQuarterDefinition.create()
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := MapView3D.create(definition, MapBuilder.build(definition), MapView3D.TIME_DAY)
	viewport.add_child(view)
	var camera := view.get_node("ViewCamera") as Camera3D
	var target := Vector3(218.0, 0.0, 86.0)
	camera.size = 92.0
	camera.position = target + camera.basis.z * 180.0
	camera.look_at(target, Vector3.UP)
	camera.current = true
	for frame in 8:
		await process_frame
	var image := viewport.get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("Could not save %s: %s" % [OUTPUT_PATH, error_string(error)])
		quit(1)
		return
	print("MONASTERY_CAPTURE=%s" % OUTPUT_PATH)
	quit(0)
