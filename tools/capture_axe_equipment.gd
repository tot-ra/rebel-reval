extends SceneTree

## The period axes of R-2009 in a hand (docs/SYSTEMS/EQUIPMENT_VARIANTS.md): the player's
## apprentice with the peasant axe (idle, then the chop at its contact frame), a census rebel
## with the battered peasant axe (w2) and a census carpenter with the broad axe. Residents
## are dressed through CitizenGear exactly as in the city; the axes are mounted by hand since
## the census gives no one an axe kit. Writes a row and a close-up of the three hands.
## Requires a rendering run:
##   tools/godot_render.sh --script tools/capture_axe_equipment.gd [-- --output-dir=PATH]

const CloseupScript := preload("res://tools/capture_character_closeup.gd")
const OUTPUT_DIR := "res://docs/reports/images/equipment"
const APPRENTICE := "res://assets/characters/variants/apprentice.tscn"
const SCENES := "res://assets/props/weapons/%s/scenes/%s_held.tscn"
const SPACING := 1.25


func _initialize() -> void:
	call_deferred("_run")


func _first(roster: CitizenRoster, faction: String, trade: String) -> Dictionary:
	for r: Dictionary in roster.residents:
		if String(r.get("sex", "")) != "m" or int(r.get("age", 0)) < 22 or int(r.get("age", 0)) > 50:
			continue
		if faction != "" and String(r.get("faction", "")) != faction:
			continue
		if trade != "" and String(r.get("trade", "")) != trade:
			continue
		return r
	return {}


func _person(viewport: SubViewport, record: Dictionary, held: String, x: float) -> SharedCharacterRig:
	var body := APPRENTICE
	if not record.is_empty():
		body = "res://assets/characters/variants/%s.tscn" % record["body"]
	var rig := (load(body) as PackedScene).instantiate() as SharedCharacterRig
	viewport.add_child(rig)
	rig.position = Vector3(x, 0.0, 0.0)
	rig.rotation_degrees = Vector3(0, 25, 0)
	if not record.is_empty():
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
	viewport.size = Vector2i(1500, 800)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(CloseupScript.build_stage("day"))
	var roster := CitizenRoster.load_default()
	var rebel := _first(roster, "harju_kings", "")
	var carpenter := _first(roster, "", "carpenter")
	print("REBEL ", rebel.get("id"), " ", rebel.get("body"), "  CARPENTER ", carpenter.get("id"), " ", carpenter.get("body"))
	var player := _person(viewport, {}, "axe_peasant_p1_w1", -SPACING)
	var rebel_rig := _person(viewport, rebel, "axe_peasant_p1_w2", 0.0)
	var carpenter_rig := _person(viewport, carpenter, "axe_broad_p2_w1", SPACING)
	for rig: SharedCharacterRig in [player, rebel_rig, carpenter_rig]:
		rig.play_animation(&"idle", 0.0)
		rig.animation_player().seek(0.0, true)
		rig.animation_player().pause()
		rig.skeleton().force_update_all_bone_transforms()
	for i in 3:
		var label := Label3D.new()
		label.text = ["player\npeasant axe p1_w1", "rebel\npeasant axe p1_w2", "carpenter\nbroad axe p2_w1"][i]
		label.font_size = 34
		label.pixel_size = 0.004
		label.position = Vector3((i - 1) * SPACING, -0.16, 0.5)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		viewport.add_child(label)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.6
	camera.position = Vector3(0.0, 1.0, 7.0)
	viewport.add_child(camera)
	camera.current = true
	for _frame in 24:
		await process_frame
	_save(viewport, out + "/axe_equipment_row.png")
	# Hands and heads: the idle haft stands up behind the fist, the head at shoulder height.
	camera.size = 1.3
	camera.position = Vector3(0.0, 1.25, 7.0)
	for _frame in 3:
		await process_frame
	_save(viewport, out + "/axe_equipment_hands.png")
	# The player's chop at its contact frame (CombatMoveCatalog axe_attack), three-quarter view.
	rebel_rig.visible = false
	carpenter_rig.visible = false
	player.position = Vector3.ZERO
	player.play_animation(&"axe_attack", 0.0)
	player.animation_player().seek(0.68, true)
	player.animation_player().pause()
	player.skeleton().force_update_all_bone_transforms()
	camera.size = 2.6
	camera.position = Vector3(3.0, 1.2, 6.0)
	camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	for _frame in 6:
		await process_frame
	_save(viewport, out + "/axe_equipment_chop.png")
	quit(0)


func _save(viewport: SubViewport, path: String) -> void:
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("SAVED ", path)
