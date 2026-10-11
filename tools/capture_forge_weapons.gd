extends SceneTree

## Visual check for the forge weapon set (R-1754, R-1755): the apprentice holds each
## weapon in idle and at its attack contact frame, so grip orientation and scale can
## be judged. Needs a renderer:
## tools/godot_render.sh --script tools/capture_forge_weapons.gd [-- --output-dir=PATH]

const CloseupScript := preload("res://tools/capture_character_closeup.gd")
const RIG_SCENE := "res://assets/characters/variants/apprentice.tscn"
const DEFAULT_OUTPUT_DIR := "res://docs/reports/images/combat/forge_weapons"
const VIEWPORT_SIZE := Vector2i(560, 700)
const FIGURE_HEIGHT := 2.0

## slug -> slot, attack animation and its contact time (CombatMoveCatalog).
const WEAPONS: Array[Dictionary] = [
	{"slug": "arming_sword", "slot": &"right_hand", "attack": &"sword_attack", "time": 0.40},
	{"slug": "bearded_axe", "slot": &"right_hand", "attack": &"axe_attack", "time": 0.68},
	{"slug": "war_hammer", "slot": &"right_hand", "attack": &"hammer_attack", "time": 0.68},
	{"slug": "spear", "slot": &"right_hand", "attack": &"spear_attack", "time": 0.45},
	{"slug": "longbow", "slot": &"left_hand", "attack": &"bow_attack", "time": 0.30},
	{"slug": "heater_shield", "slot": &"left_hand", "attack": &"guard", "time": 0.35},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_dir := DEFAULT_OUTPUT_DIR
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			output_dir = argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(CloseupScript.build_stage("day"))
	var rig: SharedCharacterRig = (load(RIG_SCENE) as PackedScene).instantiate()
	viewport.add_child(rig)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = FIGURE_HEIGHT * 1.45
	viewport.add_child(camera)
	camera.current = true
	var focus := Vector3(0.0, FIGURE_HEIGHT * 0.5, 0.0)
	camera.position = focus + Vector3(20.0, 15.0, 20.0).normalized() * 12.0
	camera.look_at(focus, Vector3.UP)

	for weapon: Dictionary in WEAPONS:
		var slug := String(weapon["slug"])
		var scene := load("res://assets/props/weapons/%s/%s_held.tscn" % [slug, slug]) as PackedScene
		for slot: StringName in SharedCharacterRig.EQUIPMENT_SLOTS:
			rig.unequip(slot)
		if slug != "heater_shield":
			# The shield is shown beside a sword, as it is carried in a fight.
			rig.equip(weapon["slot"], scene)
		else:
			rig.equip(&"right_hand", load("res://assets/props/weapons/arming_sword/arming_sword_held.tscn"))
			rig.equip(&"left_hand", scene)
		for pose: Array in [[&"idle", 0.0, "idle"], [weapon["attack"], weapon["time"], "attack"]]:
			rig.rotation_degrees = Vector3(0.0, 25.0, 0.0)
			rig.play_animation(pose[0], 0.0)
			rig.animation_player().seek(float(pose[1]), true)
			rig.animation_player().pause()
			rig.skeleton().force_update_all_bone_transforms()
			for _frame in 3:
				await process_frame
			var output := "%s/%s_%s.png" % [output_dir, slug, pose[2]]
			viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
			print("Forge weapon capture: %s" % output)
	viewport.queue_free()
	quit(0)
