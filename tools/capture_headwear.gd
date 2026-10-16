extends SceneTree

## Men's headwear (task R-2028, docs/SYSTEMS/CITIZEN_WARDROBE.md#mens-headwear-r-2028): the hood
## with liripipe in its four cells (plain p1 worn, p2 fine, p3 dagged), the coif and wool cap
## by purse, and the dagged hood on the four adult builds, dressed through CityCitizens.dye as
## in the city. Writes headwear_hoods_{front,back}.png, headwear_caps.png, headwear_builds.png.
## Requires a rendering run:
##   tools/godot_render.sh --script tools/capture_headwear.gd [-- --output-dir=PATH]

const OUTPUT_DIR := "res://docs/reports/images/equipment"
const SPACING := 1.0
## [label, layer cell, status]: status sets the wealth grade (poor homespun, mid broadcloth, rich scarlet).
const HOODS := [
	["hood p1_w1", "hood@p1_w1", "labourer"],
	["hood p1_w2 worn", "hood@p1_w2", "labourer"],
	["hood p2_w0", "hood@p2_w0", "burgher"],
	["hood p3_w0 dagged", "hood@p3_w0", "patrician"],
]
const CAPS := [
	["coif p1_w2", "coif@p1_w2", "labourer"],
	["coif p2_w1", "coif@p2_w1", "burgher"],
	["coif p3_w0", "coif@p3_w0", "patrician"],
	["cap p1_w2", "wool_cap@p1_w2", "labourer"],
	["cap p2_w1", "wool_cap@p2_w1", "burgher"],
	["cap p3_w0", "wool_cap@p3_w0", "patrician"],
]
const BUILDS := ["thin", "average", "sturdy", "heavy"]

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

	for side in [["front", 25.0], ["back", 160.0]]:
		for i in HOODS.size():
			_add("citizen_m_adult_average", HOODS[i], i, HOODS.size(), side[1])
		await _shot(3.4, 1.2, "%s/headwear_hoods_%s.png" % [out, side[0]])
		_clear()
	for i in CAPS.size():
		_add("citizen_m_adult_average", CAPS[i], i, CAPS.size(), 25.0)
	await _shot(3.4, 1.2, out + "/headwear_caps.png")
	_clear()
	for i in BUILDS.size():
		_add("citizen_m_adult_%s" % BUILDS[i], [BUILDS[i], HOODS[3][1], HOODS[3][2]], i, BUILDS.size(), 160.0)
	await _shot(3.0, 1.2, out + "/headwear_builds.png")
	_clear()
	quit(0)


func _add(body: String, entry: Array, i: int, count: int, yaw: float) -> void:
	var record := {
		"id": "t.headwear.%s.%d" % [entry[0], i],
		"body": body,
		"sex": "m",
		"status": entry[2],
		"trade": "",
		"cloth": [0.36, 0.33, 0.28],
		"under": [0.22, 0.2, 0.17],
		"wear": [entry[1]],
		"wear_dye": {},
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


func _shot(size: float, height: float, path: String) -> void:
	_camera.size = size
	_camera.position = Vector3(0.0, height, 7.0)
	for _frame in 24:
		await process_frame
	_viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("SAVED ", path)
