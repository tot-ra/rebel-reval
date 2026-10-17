extends SceneTree

## Re-cut aketon (task R-2019, docs/SYSTEMS/EQUIPMENT_VARIANTS.md): the four variant
## looks, a census town watchman idle and walking, and the watch kit on the four adult
## male builds, all dressed through CityCitizens.dye and CitizenGear.arm as in the city.
## Writes aketon_variants.png (+ _closeup), aketon_watchman.png, aketon_builds.png,
## aketon_armour.png (the kits that stack mail, coif, surcoat or plates over the aketon) and
## aketon_watchman_hero.png (the Tier 1 watchman, assets/characters/variants/watchman.tscn).
## Requires a rendering run:
##   tools/godot_render.sh --script tools/capture_aketon_variants.gd [-- --output-dir=PATH]

const OUTPUT_DIR := "res://docs/reports/images/equipment"
const BODY := "citizen_m_adult_average"
const SPACING := 1.2
## [label, aketon cell, other layers]: p3 is shown bare (in the city mail and surcoat cover it).
const VARIANTS := [
	["p1_w1 undyed, stained", "p1_w1", ["kettle_hat"]],
	["p1_w2 patched", "p1_w2", ["kettle_hat"]],
	["p2_w0 dyed (crown)", "p2_w0", ["kettle_hat"]],
	["p3_w0 silk-covered", "p3_w0", []],
]
## [label, yaw degrees, walk]
const POSES := [
	["front", 0.0, false],
	["side", 90.0, false],
	["walk 3/4", 30.0, true],
	["walk side", 90.0, true]
]
const BUILDS := ["thin", "average", "sturdy", "heavy"]
## [label, wear, surcoat or plate dye]: crown, sergeant, vassal knight, Order brother.
const ARMOUR := [
	[
		"crown p2_w1",
		["gambeson@p2_w1", "mail_haubergeon@p2_w1", "surcoat@p2_w1", "kettle_hat@p2_w1"],
		[0.58, 0.11, 0.09]
	],
	[
		"sergeant p2_w1",
		["gambeson@p2_w1", "mail_haubergeon@p2_w1", "mail_coif@p2_w1", "kettle_hat@p2_w1"],
		[]
	],
	[
		"knight p3_w0",
		[
			"gambeson@p3_w0",
			"mail_haubergeon@p3_w0",
			"coat_of_plates@p3_w0",
			"aventail@p3_w0",
			"bascinet@p3_w0"
		],
		[0.17, 0.24, 0.38]
	],
	[
		"Order p3_w0",
		[
			"gambeson@p3_w0",
			"mail_haubergeon@p3_w0",
			"surcoat@p3_w0",
			"order_mantle@p3_w0",
			"mail_coif@p3_w0"
		],
		[0.92, 0.9, 0.84]
	],
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

	for i in VARIANTS.size():
		var v: Array = VARIANTS[i]
		var wear: Array = ["gambeson@" + String(v[1])]
		for layer: String in v[2]:
			wear.append("%s@%s" % [layer, v[1]])
		var record := _record(BODY, wear, "t.aketon.%d" % i)
		if String(v[1]).begins_with("p1"):
			record["duty"] = {"kit": "watch", "post": "gate.viru", "shift": "day"}
		_add(record, i, VARIANTS.size(), 20.0, false, String(v[0]))
	await _shot(2.95, 1.3, out + "/aketon_variants.png")
	await _shot(2.0, 1.3, out + "/aketon_variants_closeup.png")
	_clear()

	var watchman := _census_watchman()
	print("WATCHMAN ", watchman.get("id"), " ", watchman.get("wear"))
	for i in POSES.size():
		var pose: Array = POSES[i]
		_add(watchman.duplicate(true), i, POSES.size(), pose[1], pose[2], String(pose[0]))
	await _shot(2.95, 1.3, out + "/aketon_watchman.png")
	_clear()

	for i in BUILDS.size():
		var body := "citizen_m_adult_%s" % BUILDS[i]
		var record := _record(body, ["gambeson@p1_w1", "kettle_hat@p1_w1"], "t.build.%d" % i)
		record["duty"] = {"kit": "watch", "post": "gate.viru", "shift": "day"}
		_add(record, i, BUILDS.size(), 30.0, false, BUILDS[i])
	await _shot(2.95, 1.3, out + "/aketon_builds.png")
	_clear()

	for i in ARMOUR.size():
		var kit: Array = ARMOUR[i]
		var record := _record("citizen_m_adult_sturdy", kit[1], "t.armour.%d" % i)
		var dye: Array = kit[2]
		if not dye.is_empty():
			for layer in ["surcoat", "coat_of_plates", "order_mantle"]:
				record["wear_dye"][layer] = dye
		_add(record, i, ARMOUR.size(), 30.0, false, String(kit[0]))
	await _shot(2.95, 1.3, out + "/aketon_armour.png")
	_clear()

	for i in POSES.size():
		var pose: Array = POSES[i]
		var hero := (
			(load("res://assets/characters/variants/watchman.tscn") as PackedScene).instantiate()
		)
		var rig := hero as SharedCharacterRig
		_viewport.add_child(rig)
		rig.position = Vector3((i - (POSES.size() - 1) * 0.5) * SPACING, 0.0, 0.0)
		rig.rotation_degrees = Vector3(0, pose[1], 0)
		if pose[2]:
			rig.play_animation(&"walk")
		_rigs.append(rig)
	await _shot(3.1, 1.4, out + "/aketon_watchman_hero.png")
	quit(0)


func _record(body: String, wear: Array, id: String) -> Dictionary:
	return {
		"id": id,
		"body": body,
		"status": "soldier",
		"trade": "watchman",
		"cloth": [0.36, 0.33, 0.28],
		"under": [0.22, 0.2, 0.17],
		"wear": wear,
		"wear_dye": {},
	}


## The first census resident on watch duty (the man the city shows at the gate).
func _census_watchman() -> Dictionary:
	for r: Dictionary in CitizenRoster.load_default().residents:
		var duty: Dictionary = r.get("duty", {})
		if (
			String(duty.get("kit", "")) == "watch"
			and String(r.get("body", "")).begins_with("citizen_m_adult")
		):
			return r
	return _record(BODY, ["gambeson@p1_w1", "kettle_hat@p1_w1"], "t.fallback")


func _add(record: Dictionary, i: int, count: int, yaw: float, walk: bool, text: String) -> void:
	var scene := load("res://assets/characters/variants/%s.tscn" % record["body"]) as PackedScene
	var rig := scene.instantiate() as SharedCharacterRig
	_viewport.add_child(rig)
	rig.position = Vector3((i - (count - 1) * 0.5) * SPACING, 0.0, 0.0)
	rig.rotation_degrees = Vector3(0, yaw, 0)
	CityCitizens.dye(rig, record)
	CitizenGear.arm(rig, record)
	if walk:
		rig.play_animation(&"walk")
	var label := Label3D.new()
	label.text = text
	label.font_size = 34
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
