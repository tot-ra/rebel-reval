extends SceneTree

## Side-by-side plate of the faction visual identity (docs/SYSTEMS/FACTIONS_AND_ECONOMY.md,
## task R-1565): one named NPC per faction in its livery, with the clothing accent,
## the overhead "!" marker with its faction chip and the faction name. Needs a renderer:
##   tools/godot_render.sh --script tools/capture_faction_identity.gd [-- --tag=plate] [--back]
## Output: docs/reports/images/city/faction_identity_<tag>.png (front, or back with --back)

const OUTPUT_DIR := "res://docs/reports/images/city"
const BODY := "res://assets/characters/variants/citizen_m_adult_average.tscn"
const SPACING := 1.15
const PLATE := Vector2i(2600, 800)

var _tag := "plate"
var _back := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			_tag = arg.substr(6)
		elif arg == "--back":
			_back = true
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var viewport := SubViewport.new()
	viewport.size = PLATE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.46, 0.5, 0.52)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.85, 0.85, 0.9)
	environment.environment.ambient_light_energy = 0.7
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -25.0 if not _back else 155.0, 0.0)
	sun.light_energy = 1.1
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	(ground.mesh as PlaneMesh).size = Vector2(40.0, 10.0)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.36, 0.32, 0.26)
	ground.material_override = ground_material
	world.add_child(ground)

	var factions: Array[String] = []
	for id in FactionIdentity.ids():
		factions.append(id)
	var count := factions.size()
	var rigs: Array[Node3D] = []
	for i in count:
		var faction := factions[i]
		var rig := (load(BODY) as PackedScene).instantiate() as Node3D
		world.add_child(rig)
		rig.position = Vector3((i - (count - 1) * 0.5) * SPACING, 0.0, 0.0)
		if _back:
			rig.rotation.y = PI
		rigs.append(rig)
		var marker := NamedNpcMarker.new()
		marker.name = "NamedNpcMarker"
		rig.add_child(marker)
		marker.setup({"id": "char.%d" % i, "faction": faction, "marker": "available"}, 1.0)
		var label := Label3D.new()
		label.text = String(FactionIdentity.row(faction)["display_name"])
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.0042
		label.font_size = 30
		label.width = 260.0
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.outline_size = 12
		label.position = Vector3(0.0, -0.18, 0.4)
		rig.add_child(label)
	for _i in 12:
		await process_frame
	for i in count:
		var rig := rigs[i]
		var record := FactionIdentity.styled_record(
			{"cloth": [0.5, 0.45, 0.4], "under": [0.2, 0.2, 0.2]}, factions[i]
		)
		CityCitizens.dye(rig, record)
		FactionIdentity.attach_accent(rig, factions[i], 1.0)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.9
	world.add_child(camera)
	camera.position = Vector3(0.0, 1.55, 12.0 if not _back else -12.0)
	camera.look_at(Vector3(0.0, 1.45, 0.0), Vector3.UP)
	camera.rotation.z = 0.0
	for _i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/faction_identity_%s.png" % [OUTPUT_DIR, _tag if not _back else _tag + "_back"]
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("saved ", path, " factions ", count)
	quit(0)
