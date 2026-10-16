extends SceneTree

## Modelled shields on census bearers (docs/SYSTEMS/CITIZEN_WARDROBE.md, R-2013): Order
## brother, crown man-at-arms, a knight's field shield and a plain scuffed one, armed
## through CitizenGear exactly as in the city, front and three-quarter.
## Requires a rendering run:
##   tools/godot_render.sh --script tools/capture_shields.gd [-- --output-dir=PATH]

const OUTPUT_DIR := "res://docs/reports/images/equipment"
const SPACING := 1.2
## [label, wear layers, shield kind, gear cell, dye]
const BEARERS := [
	["Order brother", ["order_mantle"], "order", "p3_w1", {}],
	["crown man-at-arms", ["mail_haubergeon"], "crown", "p2_w1", {}],
	["knight (field)", ["mail_haubergeon", "surcoat"], "field", "p3_w1", {"surcoat": [0.15, 0.3, 0.55]}],
	["man-at-arms (plain)", ["mail_haubergeon"], "plain", "p1_w2", {}],
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.57, 0.6)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.74)
	viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	viewport.add_child(sun)
	var rigs: Array[SharedCharacterRig] = []
	for i in BEARERS.size():
		var bearer: Array = BEARERS[i]
		var scene := load("res://assets/characters/variants/citizen_m_adult_average.tscn") as PackedScene
		var rig := scene.instantiate() as SharedCharacterRig
		viewport.add_child(rig)
		rig.position = Vector3((i - (BEARERS.size() - 1) * 0.5) * SPACING, 0.0, 0.0)
		rigs.append(rig)
		var record := {
			"body": "citizen_m_adult_average", "cloth": [0.3, 0.3, 0.28], "under": [0.22, 0.2, 0.17],
			"wear": bearer[1], "wear_dye": bearer[4], "shield": bearer[2], "gear_variant": bearer[3],
		}
		CityCitizens.dye(rig, record)
		CitizenGear.arm(rig, record)
		var label := Label3D.new()
		label.text = bearer[0]
		label.font_size = 40
		label.pixel_size = 0.004
		label.position = Vector3(0, -0.12, 0.4)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		rig.add_child(label)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.4
	camera.position = Vector3(0.0, 1.0, 7.0)
	viewport.add_child(camera)
	camera.current = true
	var out := OUTPUT_DIR
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--output-dir="):
			out = a.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	# The shield arm is the bearer's left (viewer's right when facing the camera): turn
	# toward it for the face, away for the inside of the board.
	for view: Array in [["front", -50.0], ["back", -130.0]]:
		for rig in rigs:
			rig.rotation_degrees = Vector3(0, view[1], 0)
		for _frame in 24:
			await process_frame
		_save(viewport, "%s/shields_%s.png" % [out, view[0]])
	quit(0)


func _save(viewport: SubViewport, path: String) -> void:
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("SAVED ", path)
