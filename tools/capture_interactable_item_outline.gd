extends SceneTree

## R-1549: isolated pickup presentation via the production controller and ContentDB.
## tools/godot_render.sh --resolution 1280x720 --script tools/capture_interactable_item_outline.gd
## Not proof of a whole-city input route or the still-unbound chest/anvil props.
const OUTPUT := "res://docs/reports/images/interaction_outline"
const LOCATION := &"loc.outline_capture"
const OBJECT := &"world.outline_capture"
const ITEM := &"item.forge_bearded_axe"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# Late loads, like the test harness, let autoload names resolve before scripts
	# using SessionState are compiled by a SceneTree --script entry point.
	var session := root.get_node("SessionState")
	var state: RefCounted = session.get("state")
	state.call("place_world_item", LOCATION, OBJECT, ITEM, Vector2.ZERO)
	state.call("mark_world_defaults_seeded", LOCATION)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var host := Node2D.new()
	viewport.add_child(host)
	var runtime: Node3D = load("res://scripts/map/view3d/map_view_runtime.gd").new()
	host.add_child(runtime)
	runtime.set_process(false)
	var controller: Node = load("res://scripts/world/world_item_controller.gd").new()
	host.add_child(controller)
	var definition: RefCounted = load("res://scripts/map/map_definition.gd").new()
	controller.call("setup", host, definition, runtime, null, LOCATION)
	controller.set_process(false)
	var sensors: Dictionary = controller.get("_interactables")
	var views: Dictionary = controller.get("_views")
	if sensors.size() != 1 or views.size() != 1:
		push_error("Expected exactly one production pickup")
		quit(1)
		return
	var sensor: Node = sensors.values()[0]
	var view: Node3D = views.values()[0]
	var model: Node3D = view.call("get_item_visual_root")
	if model == null:
		push_error("Pickup model was not resolved through ContentDB")
		quit(1)
		return
	var stage := Node3D.new()
	viewport.add_child(stage)
	_build_stage(stage)
	var dir := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(dir)
	for focused: bool in [false, true]:
		sensor.call("set_focused", focused)
		for frame in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		if image.is_empty():
			push_error("Capture requires tools/godot_render.sh, not the dummy renderer")
			quit(1)
			return
		var label := "focused" if focused else "idle"
		var path := "%s/pickup_%s.png" % [dir, label]
		if image.save_png(path) != OK:
			quit(1)
			return
		print("R-1549 pickup capture: ", path)
	viewport.free()
	quit(0)


func _build_stage(stage: Node3D) -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	settings.background_color = Color(0.06, 0.08, 0.11)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.75, 0.8, 0.9)
	settings.ambient_light_energy = 0.6
	# Metallic pickup faces need a reflection source, not just diffuse ambient.
	settings.sky = Sky.new()
	settings.sky.sky_material = ProceduralSkyMaterial.new()
	environment.environment = settings
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -25, 0)
	light.light_energy = 1.4
	stage.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.19, 0.22)
	material.roughness = 1.0
	floor_mesh.material_override = material
	stage.add_child(floor_mesh)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.6
	stage.add_child(camera)
	camera.position = Vector3(1.7, 1.8, 2.4)
	camera.look_at(Vector3(0, 0.18, 0))
	camera.current = true
