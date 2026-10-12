extends SceneTree

## Cloth grade and wear plate (docs/SYSTEMS/CITIZEN_WARDROBE.md, task R-1667):
## a rich merchant, a poor porter and a smith, each shot from 3 m, plus the
## texture memory the grade sets add (RENDER_TEXTURE_MEM_USED before and after
## CitizenWardrobe.weave). Requires a rendering run:
##   tools/godot_render.sh --script tools/capture_citizen_textiles.gd [-- --output-dir=PATH]

const OUTPUT_DIR := "res://docs/reports/images/characters"
const DISTANCE := 3.0
const ROW_SPACING := 30.0
## [label, record]; the records are what build_citizen_runtime.py writes.
const RESIDENTS := [
	[
		"rich",
		{
			"id": "cit.capture.rich", "body": "citizen_m_adult_heavy_b", "status": "patrician",
			"trade": "merchant", "cloth": [0.42, 0.13, 0.1], "under": [0.2, 0.17, 0.15],
			"wear": ["hood", "keys"], "wear_dye": {"hood": [0.2, 0.17, 0.15]},
		},
	],
	[
		"poor",
		{
			"id": "cit.capture.poor", "body": "citizen_m_adult_thin", "status": "labourer",
			"trade": "porter", "cloth": [0.46, 0.44, 0.4], "under": [0.36, 0.28, 0.2],
			"wear": ["wool_cap", "back_sack"], "wear_dye": {"wool_cap": [0.36, 0.28, 0.2]},
		},
	],
	[
		"smith",
		{
			"id": "cit.capture.smith", "body": "citizen_m_adult_sturdy", "status": "master_craftsman",
			"trade": "smith", "cloth": [0.36, 0.4, 0.28], "under": [0.22, 0.2, 0.17],
			"wear": ["smith_apron", "coif"], "wear_dye": {"coif": [0.74, 0.7, 0.6]},
		},
	],
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(900, 1200)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.5, 0.52, 0.55)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.62, 0.63, 0.68)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	viewport.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 40.0
	viewport.add_child(camera)
	camera.current = true

	var rigs: Array[SharedCharacterRig] = []
	for i in RESIDENTS.size():
		var record: Dictionary = RESIDENTS[i][1]
		var scene := load("res://assets/characters/variants/%s.tscn" % record["body"]) as PackedScene
		var rig := scene.instantiate() as SharedCharacterRig
		viewport.add_child(rig)
		rig.position = Vector3(i * ROW_SPACING, 0.0, 0.0)
		rigs.append(rig)
	for _frame in 4:
		await process_frame
	# Baseline: bodies dyed and every layer mounted, as before R-1667.
	for i in rigs.size():
		var record: Dictionary = RESIDENTS[i][1]
		CityCitizens.dye(rigs[i], record)
		for layer: String in record["wear"]:
			var layer_scene := CitizenWardrobe.layer_scene(record["body"], layer)
			if layer_scene != null:
				rigs[i].equip_garment(StringName(CitizenWardrobe.GARMENT_PREFIX + layer), layer_scene)
	var before := await _texture_memory(camera, rigs)
	for i in rigs.size():
		CitizenWardrobe.dress(rigs[i], RESIDENTS[i][1])
	var after := await _texture_memory(camera, rigs)
	print("citizen textiles: texture memory %.2f MiB -> %.2f MiB (delta %.2f MiB)" % [
		before / 1048576.0, after / 1048576.0, (after - before) / 1048576.0
	])

	var out := OUTPUT_DIR
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--output-dir="):
			out = a.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var shots: Array[Image] = []
	for i in rigs.size():
		var target := rigs[i].global_position + Vector3(0.0, 1.0, 0.0)
		camera.position = target + Vector3(0.35, 0.15, DISTANCE)
		camera.look_at(target)
		for _frame in 4:
			await process_frame
		var image := viewport.get_texture().get_image()
		var path := out + "/citizen_textiles_%s.jpg" % RESIDENTS[i][0]
		image.save_jpg(ProjectSettings.globalize_path(path), 0.9)
		shots.append(image)
	var width := viewport.size.x * shots.size()
	var plate := Image.create(width, viewport.size.y, false, shots[0].get_format())
	for i in shots.size():
		plate.blit_rect(shots[i], Rect2i(Vector2i.ZERO, viewport.size), Vector2i(i * viewport.size.x, 0))
	plate.save_jpg(ProjectSettings.globalize_path(out + "/citizen_textiles_3m.jpg"), 0.9)
	quit(0)


## Renders every resident once so their textures are uploaded, then reads the monitor.
func _texture_memory(camera: Camera3D, rigs: Array[SharedCharacterRig]) -> float:
	for rig in rigs:
		camera.position = rig.global_position + Vector3(0.0, 1.0, DISTANCE)
		camera.look_at(rig.global_position + Vector3(0.0, 1.0, 0.0))
		for _frame in 3:
			await process_frame
	return Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
