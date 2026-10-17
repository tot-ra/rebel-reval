extends SceneTree

## Arming sword family and sword belt (task R-2007, docs/SYSTEMS/EQUIPMENT_VARIANTS.md):
## census residents who gird a sword, dressed and armed through CityCitizens.dye and
## CitizenGear.arm as in the city. Writes to docs/reports/images/equipment/:
##   arming_sword_residents.png - watch sergeant (sword drawn, empty scabbard), vassal knight,
##     crown man on duty (spear and sheathed sword), man-at-arms; three-quarter view
##   arming_sword_residents_side.png - the same from their left, where the scabbard hangs
##   arming_sword_walk.png - the sergeant and the knight walking
##   arming_sword_hip_closeup.png - the knight's and the sergeant's hips
## Requires a rendering run:
##   tools/godot_render.sh --script tools/capture_arming_swords.gd [-- --output-dir=PATH]

const OUTPUT_DIR := "res://docs/reports/images/equipment"
const SPACING := 1.2

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

	var people := _residents()
	for yaw_and_name: Array in [
		[30.0, "arming_sword_residents"], [-90.0, "arming_sword_residents_side"]
	]:
		for i in people.size():
			var person: Dictionary = people[i]
			_add(person["record"], i, people.size(), yaw_and_name[0], false, person["label"])
		await _shot(Vector3(0.0, 1.25, 7.0), 3.4, out + "/%s.png" % yaw_and_name[1])
		_clear()
	for i in 2:
		var person: Dictionary = people[i]
		_add(person["record"], i, 2, 60.0, true, person["label"])
	await _shot(Vector3(0.0, 1.25, 7.0), 2.6, out + "/arming_sword_walk.png")
	_clear()
	for i in 2:
		var person: Dictionary = people[1 - i]
		_add(person["record"], i, 2, -70.0, false, "")
	await _shot(Vector3(0.0, 1.05, 7.0), 1.3, out + "/arming_sword_hip_closeup.png")
	quit(0)


## [{label, record}]: the census watch sergeant, a vassal knight, a crown man on duty and a
## man-at-arms off duty, each the first such resident with a sword.
func _residents() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var residents: Array = CitizenRoster.load_default().residents
	for kind: String in ["watch sergeant", "knight", "crown man on duty", "man-at-arms"]:
		for r: Dictionary in residents:
			if (
				bool(r.get("sword", false))
				and String(r.get("body", "")).begins_with("citizen_m_adult")
				and _is(kind, r)
			):
				var label := "%s %s" % [kind, r.get("gear_variant", "")]
				print("RESIDENT ", label, " ", r.get("id"), " ", r.get("body"))
				found.append({"label": label, "record": r.duplicate(true)})
				break
	return found


func _is(kind: String, r: Dictionary) -> bool:
	match kind:
		"watch sergeant":
			return _kit(r) == "sergeant"
		"knight":
			return r.get("trade") == "knight" and r.get("status") == "noble" and _kit(r).is_empty()
		"crown man on duty":
			return _kit(r) == "crown"
	return r.get("trade") == "man_at_arms" and _kit(r).is_empty()


func _kit(r: Dictionary) -> String:
	return String((r.get("duty", {}) as Dictionary).get("kit", ""))


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
	if not text.is_empty():
		var label := Label3D.new()
		label.text = text
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


func _shot(at: Vector3, size: float, path: String) -> void:
	_camera.size = size
	_camera.position = at
	for _frame in 24:
		await process_frame
	_viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("SAVED ", path)
