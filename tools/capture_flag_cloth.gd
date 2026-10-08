extends SceneTree

## Evidence plates for the hoist-fixed flag cloth shader (map_view_flag_cloth).
## Three Danish tower pennants in light, moderate and strong wind, plus the
## town hall gable flag, each on its own staff. Two plates a moment apart show
## the travelling wave moving toward the fly.
##   tools/godot_render.sh --script tools/capture_flag_cloth.gd

const TownHallModel := preload("res://scripts/map/view3d/map_view_town_hall_model.gd")
const OUTPUT_DIR := "res://docs/reports/images/flag_cloth"
const VIEWPORT_SIZE := Vector2i(1440, 810)
const WIND_DIRECTION := Vector2(0.9285, 0.3714)
const WINDS: Array[float] = [0.08, 0.45, 0.92]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.58, 0.68, 0.80)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.70, 0.74, 0.80)
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	# Sun behind the camera, off to the left, so the folds read in light and shade.
	sun.rotation_degrees = Vector3(-38.0, -25.0, 0.0)
	sun.light_energy = 1.6
	stage.add_child(sun)

	# R-1321: wind is a shared global; full world strength scaled per flag.
	MapViewMaterials.apply_world_wind(WIND_DIRECTION, 1.0)
	for index in WINDS.size():
		var material := MapViewMaterials.flag_cloth().duplicate() as ShaderMaterial
		material.set_shader_parameter("wind_scale", WINDS[index])
		var pennant_mesh := FactionHeraldry.pennant_mesh(FactionHeraldry.DANISH_CROWN)
		_add_flag(stage, Vector3(-4.5 + index * 3.0, 0.0, 0.0), pennant_mesh, material, 2.0)
	var hall_material := MapViewMaterials.flag_cloth(true).duplicate() as ShaderMaterial
	hall_material.set_shader_parameter("wind_scale", 0.45)
	var hall_mesh: ArrayMesh = TownHallModel._banner_mesh(1.5, 1.1, true, 2)
	_add_flag(stage, Vector3(4.5, 0.0, 0.0), hall_mesh, hall_material, 1.0)

	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.fov = 42.0
	# Raised and yawed like the gameplay camera so the fly's depth waves show.
	camera.position = Vector3(-2.5, 7.0, 9.0)
	camera.look_at(Vector3(0.8, 2.8, 0.0), Vector3.UP)
	camera.current = true

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for plate in ["a", "b"]:
		for _frame in 12:
			await process_frame
		# Real time between plates so the travelling wave visibly advances.
		await create_timer(0.4).timeout
		var image := viewport.get_texture().get_image()
		var path := "%s/flag_cloth_%s.png" % [OUTPUT_DIR, plate]
		var error := image.save_png(ProjectSettings.globalize_path(path))
		if error != OK:
			push_error("Could not save %s: %s" % [path, error_string(error)])
			quit(1)
			return
		print("Flag cloth plate: %s" % path)
	quit(0)


func _add_flag(
	stage: Node3D, base: Vector3, mesh: ArrayMesh, material: ShaderMaterial, scale: float
) -> void:
	var staff := MeshInstance3D.new()
	var staff_mesh := CylinderMesh.new()
	staff_mesh.top_radius = 0.04
	staff_mesh.bottom_radius = 0.05
	staff_mesh.height = 3.4
	staff.mesh = staff_mesh
	staff.position = base + Vector3(0.0, 1.7, 0.0)
	stage.add_child(staff)
	var flag := MeshInstance3D.new()
	flag.mesh = mesh
	flag.material_override = material
	flag.scale = Vector3.ONE * scale
	flag.position = base + Vector3(0.0, 3.3, 0.0)
	stage.add_child(flag)
