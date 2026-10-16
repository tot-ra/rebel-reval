extends SceneTree

## Women's headwear (task R-2029, docs/SYSTEMS/CITIZEN_WARDROBE.md#womens-headwear-r-2029): eight women
## (Estonian and German, maid to widow, poor to patrician), dressed through CityCitizens.dye as in
## the city. Writes womens_headwear_{front,back}_{a,b}.png (women 1-4 and 5-8).
## Requires a rendering run:
##   tools/godot_render.sh --script tools/capture_womens_headwear.gd [-- --output-dir=PATH]

const OUTPUT_DIR := "res://docs/reports/images/equipment"
const SPACING := 1.0
## [label, body, status, wear entries, dyes]: eight women by age, purse and people.
const LINEN_WHITE := [0.9, 0.88, 0.82]
const LINEN_NATURAL := [0.8, 0.74, 0.62]
const HABIT_BLACK := [0.1, 0.1, 0.1]
const WOMEN := [
	["Estonian maid, braids", "citizen_f_adult_thin_d", "servant", ["braids@p1_w1"], {}],
	["Estonian girl, kerchief", "citizen_f_adult_average_d", "servant", ["headscarf@p1_w2"], {"headscarf": LINEN_NATURAL}],
	["Estonian wife, head cloth", "citizen_f_adult_sturdy_d", "free_commoner", ["head_cloth@p1_w1"], {"head_cloth": LINEN_WHITE}],
	["Estonian widow, headscarf", "citizen_f_elder_thin", "servant", ["headscarf@p1_w2"], {"headscarf": LINEN_NATURAL}],
	["burgher wife, scarf+veil", "citizen_f_adult_heavy_b", "master_craftsman", ["headscarf@p2_w1", "veil_over@p2_w1"], {"headscarf": LINEN_NATURAL, "veil_over": LINEN_WHITE}],
	["patrician wife, barbette", "citizen_f_adult_average_c", "patrician", ["barbette@p3_w0", "veil_over@p3_w0"], {"barbette": LINEN_WHITE, "veil_over": LINEN_WHITE}],
	["widow, wimple+veil", "citizen_f_elder_heavy", "master_craftsman", ["wimple@p2_w1", "veil_over@p2_w1"], {"wimple": LINEN_WHITE, "veil_over": LINEN_NATURAL}],
	["nun, wimple+black veil", "citizen_f_adult_sturdy_b", "master_craftsman", ["wimple@p2_w0", "veil_over@p2_w0"], {"wimple": LINEN_WHITE, "veil_over": HABIT_BLACK}],
]

var _viewport: SubViewport
var _camera: Camera3D
var _rigs: Array[Node3D] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1600, 900)
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.57, 0.6)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.74)
	_viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	_viewport.add_child(sun)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_viewport.add_child(_camera)
	_camera.current = true
	var out := OUTPUT_DIR
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--output-dir="):
			out = a.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))

	# Close-ups of four women at a time, from the front-left and from behind (the drape).
	for shot in [["front", 25.0], ["back", 160.0]]:
		for i in WOMEN.size():
			_add(WOMEN[i], i, WOMEN.size(), shot[1])
		await _shot(2.2, 1.45, "%s/womens_headwear_%s_a.png" % [out, shot[0]], -1.9)
		await _shot(2.2, 1.45, "%s/womens_headwear_%s_b.png" % [out, shot[0]], 1.9)
		_clear()
	quit(0)


func _add(entry: Array, i: int, count: int, yaw: float) -> void:
	var body := String(entry[1])
	var record := {
		"id": "t.headwear.%s.%d" % [entry[0], i],
		"body": body,
		"sex": "f",
		"status": entry[2],
		"trade": "",
		"cloth": [0.36, 0.33, 0.28],
		"under": [0.22, 0.2, 0.17],
		"wear": entry[3],
		"wear_dye": entry[4],
	}
	var scene := load("res://assets/characters/variants/%s.tscn" % body) as PackedScene
	var rig := scene.instantiate() as SharedCharacterRig
	_viewport.add_child(rig)
	rig.position = Vector3((i - (count - 1) * 0.5) * SPACING, 0.0, 0.0)
	rig.rotation_degrees = Vector3(0, yaw, 0)
	CitizenWardrobe.dress(rig, record)
	CityCitizens.dye(rig, record)
	var label := Label3D.new()
	label.text = String(entry[0])
	label.font_size = 30
	label.pixel_size = 0.004
	label.position = Vector3(0, -0.12, 0.4)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rig.add_child(label)
	_rigs.append(rig)


func _clear() -> void:
	for rig in _rigs:
		rig.queue_free()
	_rigs.clear()


func _shot(size: float, height: float, path: String, cam_x: float = 0.0) -> void:
	_camera.size = size
	_camera.position = Vector3(cam_x, height, 7.0)
	for _frame in 24:
		await process_frame
	_viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("SAVED ", path)
