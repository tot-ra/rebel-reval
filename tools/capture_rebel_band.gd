extends SceneTree

## A rebel band with the levy weapons of R-2014 (docs/SYSTEMS/EQUIPMENT_VARIANTS.md "Rebel
## levy weapons"): five census rebels (harju_kings, black_cloaks) of different builds and
## ages, each with a different battered (w2) tool, since rebels always roll wear w2. They are
## dressed through CitizenGear exactly as in the city; the weapons are mounted by hand since
## the census gives no one a rebel kit yet. Writes a row and a close-up of hands and heads.
## Requires a rendering run:
##   tools/godot_render.sh --script tools/capture_rebel_band.gd [-- --output-dir=PATH]

const CloseupScript := preload("res://tools/capture_character_closeup.gd")
const OUTPUT_DIR := "res://docs/reports/images/equipment/rebel"
const SCENES := "res://assets/props/weapons/rebel/%s/scenes/%s_held.tscn"
const SPACING := 1.15
const BAND := [
	"hayfork_p1_w2", "threshing_flail_p1_w2", "club_oak_p1_w2", "club_ironbound_p1_w2", "sickle_p1_w2",
]
const LABELS := ["hayfork", "threshing flail", "oak club", "iron-bound club", "sickle"]


func _initialize() -> void:
	call_deferred("_run")


## Five adult men of the rebel factions, one per body type where the census allows it,
## so the band is not five copies of one build.
func _band(roster: CitizenRoster) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var bodies := {}
	for strict in 2:
		for r: Dictionary in roster.residents:
			if out.size() == BAND.size():
				return out
			if not String(r.get("faction", "")) in ["harju_kings", "black_cloaks"]:
				continue
			if String(r.get("sex", "")) != "m" or int(r.get("age", 0)) < 18 or int(r.get("age", 0)) > 62:
				continue
			if out.has(r):
				continue
			var body := String(r.get("body", ""))
			if strict == 0 and bodies.has(body):
				continue
			bodies[body] = true
			out.append(r)
	return out


func _person(
	viewport: SubViewport, record: Dictionary, held: String, x: float
) -> SharedCharacterRig:
	var body := load("res://assets/characters/variants/%s.tscn" % record["body"]) as PackedScene
	var rig := body.instantiate() as SharedCharacterRig
	viewport.add_child(rig)
	rig.position = Vector3(x, 0.0, 0.0)
	rig.rotation_degrees = Vector3(0, 20, 0)
	CityCitizens.dye(rig, record)
	CitizenGear.arm(rig, record)
	var family := held.rsplit("_", true, 2)[0]
	rig.equip(&"right_hand", load(SCENES % [family, held]) as PackedScene)
	return rig


func _run() -> void:
	var out := OUTPUT_DIR
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--output-dir="):
			out = a.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1700, 850)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(CloseupScript.build_stage("day"))
	var band := _band(CitizenRoster.load_default())
	var rigs: Array[SharedCharacterRig] = []
	for i in band.size():
		var r: Dictionary = band[i]
		print("REBEL ", r.get("id"), " ", r.get("faction"), " ", r.get("body"), " ", BAND[i])
		var x := (i - (band.size() - 1) * 0.5) * SPACING
		rigs.append(_person(viewport, r, BAND[i], x))
		var label := Label3D.new()
		label.text = "%s\n%s, %d\n%s" % [
			LABELS[i], String(r.get("trade", "")), int(r.get("age", 0)), String(r.get("faction", ""))
		]
		label.font_size = 30
		label.pixel_size = 0.004
		label.position = Vector3(x, -0.2, 0.5)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		viewport.add_child(label)
	for rig in rigs:
		rig.play_animation(&"idle", 0.0)
		rig.animation_player().seek(0.0, true)
		rig.animation_player().pause()
		rig.skeleton().force_update_all_bone_transforms()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.9
	camera.position = Vector3(0.0, 1.05, 7.0)
	viewport.add_child(camera)
	camera.current = true
	for _frame in 24:
		await process_frame
	_save(viewport, out + "/rebel_band.png")
	# Hands and heads: the tools stand up behind the fists, heads at shoulder height and above.
	camera.size = 1.6
	camera.position = Vector3(0.0, 1.35, 7.0)
	for _frame in 3:
		await process_frame
	_save(viewport, out + "/rebel_band_closeup.png")
	quit(0)


func _save(viewport: SubViewport, path: String) -> void:
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("SAVED ", path)
