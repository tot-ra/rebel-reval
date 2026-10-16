extends SceneTree

## R-2112 review plate: the four cereal clumps of CityGrainMeshes side by side
## (rye, wheat, barley, oats, left to right), each as a small planted patch on
## tilled soil, at one calendar stage, from eye level and from the gameplay
## height. Needs a renderer:
##   tools/godot_render.sh --script tools/capture_grain_lineup.gd \
##     [-- --stage=ripe|headed|leafy|stubble] [--far]
## Output: docs/reports/images/r2112/grain_lineup_<stage>[_far]_<eye|high>.jpg

const GrainMeshes := preload("res://scripts/city/city_grain_meshes.gd")

const OUTPUT_DIR := "res://docs/reports/images/r2112"
const SIZE := Vector2i(1600, 900)
const PATCH := Vector2i(5, 4)
const ROW := 0.8
const STEP := 0.55
const GAP := 4.5

var _stage := GrainMeshes.STAGE_RIPE
var _far := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="):
			_stage = StringName(arg.substr(8))
		elif arg == "--far":
			_far = true
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(_scene())
	var camera := Camera3D.new()
	camera.fov = 45.0
	viewport.add_child(camera)
	camera.current = true
	var width := GAP * 3.0
	var centre := Vector3(width * 0.5, 0.6, 0.0)
	var failed := false
	for shot: Array in [["eye", Vector3(width * 0.5, 1.6, 15.0), centre], ["high", Vector3(width * 0.5, 10.0, 16.0), Vector3(centre.x, 0.0, 0.0)]]:  # gdlint: ignore=max-line-length
		camera.look_at_from_position(shot[1], shot[2], Vector3.UP)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
		var path := "%s/grain_lineup_%s%s_%s.jpg" % [OUTPUT_DIR, _stage, "_far" if _far else "", shot[0]]
		var error := viewport.get_texture().get_image().save_jpg(ProjectSettings.globalize_path(path), 0.82)  # gdlint: ignore=max-line-length
		if error != OK:
			push_error("could not save %s" % path)
			failed = true
		else:
			print("captured %s" % path)
	quit(1 if failed else 0)


func _scene() -> Node3D:
	var stage := Node3D.new()
	var environment := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, -30.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120.0, 120.0)
	ground.mesh = plane
	var soil := StandardMaterial3D.new()
	soil.albedo_color = Color(0.30, 0.23, 0.16)
	soil.roughness = 1.0
	ground.material_override = soil
	stage.add_child(ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2112
	for i in GrainMeshes.ALL_CROPS.size():
		var crop := GrainMeshes.ALL_CROPS[i]
		var transforms: Array[Transform3D] = []
		var colors: Array[Color] = []
		for r in PATCH.y:
			for c in PATCH.x:
				var at := Vector3(
					GAP * i + (c - PATCH.x * 0.5) * STEP * (2.0 if _far else 1.0) + rng.randf_range(-0.1, 0.1),
					0.0,
					(r - PATCH.y * 0.5) * ROW + rng.randf_range(-0.1, 0.1)
				)
				var size := rng.randf_range(0.9, 1.1)
				transforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), at))  # gdlint: ignore=max-line-length
				colors.append(Color.WHITE)
		var inst := MapViewMeshBuilderPrimitives.multi_mesh(
			"Crop_%s" % crop, GrainMeshes.mesh_for(crop, _stage, _far), transforms, colors,
			GrainMeshes.material(_far), Vector3.ZERO
		)
		stage.add_child(inst)
	# The far tier fades out round the player; with no player here it would fade
	# by camera distance, so the plate switches the fade off.
	GrainMeshes.material(true).set_shader_parameter("fade_end", 0.0)
	return stage
