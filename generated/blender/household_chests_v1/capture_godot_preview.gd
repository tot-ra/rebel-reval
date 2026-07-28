extends SceneTree

## Evidence-only in-engine lineup using the fixed orthographic gameplay camera.
## Run with a real renderer rather than `--headless`, which selects dummy on macOS:
## godot --display-driver macos --rendering-method gl_compatibility \
##   --rendering-driver opengl3 --audio-driver Dummy --path . \
##   --script res://generated/blender/household_chests_v1/capture_godot_preview.gd

const OUTPUT_PATH := "res://generated/blender/household_chests_v1/godot_preview.png"
const VIEWPORT_SIZE := Vector2i(1200, 600)
const VARIANTS: Array[StringName] = [
	MapPropStyleVariants.CHEST_PLAIN_COFFER,
	MapPropStyleVariants.CHEST_BURGHER,
	MapPropStyleVariants.CHEST_MERCHANT_STRONGBOX,
]
const POSITIONS: Array[Vector3] = [
	Vector3(-1.25, 0.0, 0.0),
	Vector3(0.0, 0.0, 0.0),
	Vector3(1.38, 0.0, 0.0),
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("6f9661")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("dbe5d2")
	environment.ambient_light_energy = 0.75
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	viewport.add_child(world_environment)

	var stage := Node3D.new()
	viewport.add_child(stage)
	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(7.0, 5.0)
	ground.mesh = ground_mesh
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("719b60")
	ground_material.roughness = 1.0
	ground.material_override = ground_material
	stage.add_child(ground)

	for index in VARIANTS.size():
		var prop := MapViewMeshBuilder.build_prop(
			{
				"id": StringName("evidence.chest.%d" % index),
				"kind": MapTypes.PROP_KIND_CHEST,
				"style_variant": VARIANTS[index],
				"position": Vector2.ZERO,
			},
			MapTypes.DEFAULT_CELL_SIZE
		)
		prop.position = POSITIONS[index]
		stage.add_child(prop)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	sun.light_color = Color("f3e5c6")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	stage.add_child(sun)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation_degrees = Vector3(MapView3D.CAMERA_PITCH_DEGREES, MapView3D.CAMERA_YAW_DEGREES, 0.0)
	camera.size = 3.6
	camera.position = Vector3(0.05, 0.30, 0.0) + camera.transform.basis.z * 7.0
	camera.current = true
	stage.add_child(camera)

	for frame in 6:
		await process_frame
	var image := viewport.get_texture().get_image()
	if image == null:
		push_error("Godot preview requires a real rendering driver, not the headless dummy renderer")
		quit(1)
		return
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if error != OK:
		push_error("Could not save household chest Godot preview: %s" % error_string(error))
		quit(1)
		return
	print("HOUSEHOLD_CHESTS_GODOT_PREVIEW=%s" % OUTPUT_PATH)
	quit(0)
