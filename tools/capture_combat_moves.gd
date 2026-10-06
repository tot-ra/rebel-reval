extends SceneTree

## Contact sheets for the R-1161 combat animation system
## (docs/SYSTEMS/COMBAT_ANIMATION.md): each weapon class's three-step chain and
## heavy strike at their contact frames, the roll phases and the cast gestures.
## Poses go through SharedCharacterRig.sync_action_presentation, the same path
## the map view uses, so a frozen pose here means a frozen pose in game.
## Needs a GPU renderer: tools/godot_render.sh --script tools/capture_combat_moves.gd

const KALEV_SCENE := preload("res://assets/characters/kalev/kalev.tscn")
const OUTPUT_DIR := "res://docs/reports/images/combat"
const VIEWPORT_SIZE := Vector2i(1440, 720)
const WEAPONS: Dictionary = {
	&"hammer": "res://assets/characters/shared/hammer.tscn",
	&"sword": "res://assets/characters/shared/sword.tscn",
	&"spear": "res://assets/characters/shared/spear_thrust_grip.tscn",
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for weapon_class: StringName in CombatMoveCatalog.WEAPON_CLASSES:
		var poses: Array[Dictionary] = []
		for step in CombatMoveCatalog.combo_length(weapon_class):
			poses.append(
				_contact_pose(
					CombatMoveCatalog.light_move(weapon_class, step), "LIGHT %d" % (step + 1)
				)
			)
		poses.append(_contact_pose(CombatMoveCatalog.heavy_move(weapon_class), "HEAVY"))
		await _capture(
			"combat_%s_chain_contact" % weapon_class,
			"%s CHAIN - CONTACT FRAMES" % String(weapon_class).to_upper(),
			poses,
			weapon_class
		)
	var roll := CombatMoveCatalog.action_move(CombatMoveCatalog.ROLL_FORWARD)
	var roll_poses: Array[Dictionary] = []
	for fraction: float in [0.12, 0.35, 0.55, 0.85]:
		(
			roll_poses
			. append(
				{
					"id": roll.id,
					"t": roll.duration_sec * fraction,
					"duration": roll.duration_sec,
					"label": "ROLL %d%%" % int(fraction * 100.0),
				}
			)
		)
	await _capture(
		"combat_roll_forward_phases", "ROLL - PUSH-OFF, TUCK, TUMBLE, GET-UP", roll_poses, &""
	)
	var cast_poses: Array[Dictionary] = []
	for id: StringName in [
		CombatMoveCatalog.CAST_PROJECTILE, CombatMoveCatalog.CAST_SELF, CombatMoveCatalog.CAST_AREA
	]:
		var cast := CombatMoveCatalog.action_move(id)
		cast_poses.append(
			{
				"id": id,
				"t": cast.impact_sec,
				"duration": cast.duration_sec,
				"label": String(id).to_upper()
			}
		)
	await _capture("combat_cast_gestures_release", "CAST GESTURES - RELEASE FRAME", cast_poses, &"")
	quit(0)


func _contact_pose(move: CombatMove, label: String) -> Dictionary:
	return {"id": move.id, "t": move.impact_sec, "duration": move.duration_sec, "label": label}


func _capture(
	slug: String, title: String, poses: Array[Dictionary], weapon_class: StringName
) -> void:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(_build_stage())

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.0
	viewport.add_child(camera)
	camera.current = true
	camera.position = Vector3(6.0, 4.5, 8.0)
	camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	var screen_right := camera.global_transform.basis.x.normalized()

	var spacing := 9.6 / float(maxi(poses.size(), 1))
	for index in poses.size():
		var pose: Dictionary = poses[index]
		var rig := KALEV_SCENE.instantiate() as SharedCharacterRig
		rig.position = screen_right * (-4.8 + spacing * (float(index) + 0.5))
		viewport.add_child(rig)
		if WEAPONS.has(weapon_class):
			rig.equip(&"right_hand", load(WEAPONS[weapon_class]) as PackedScene)
		rig.play_animation(pose["id"], 0.0)
		# The game re-syncs every frame; a still capture must stop the player's
		# own clock or the render frames below would advance past the pose.
		rig.animation_player().callback_mode_process = (
			AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		)
		rig.sync_action_presentation(pose["id"], float(pose["t"]), float(pose["duration"]))
	_add_labels(viewport, title, poses, spacing)

	for _frame in 4:
		await process_frame
	var output := "%s/%s.png" % [OUTPUT_DIR, slug]
	var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Could not save combat capture %s: %s" % [output, error_string(error)])
		quit(1)
		return
	print("Combat move capture: %s" % output)
	viewport.queue_free()
	await process_frame


func _add_labels(
	viewport: SubViewport, title: String, poses: Array[Dictionary], spacing: float
) -> void:
	var layer := CanvasLayer.new()
	viewport.add_child(layer)
	var header := Label.new()
	header.text = title
	header.position = Vector2(32.0, 24.0)
	header.add_theme_font_size_override("font_size", 28)
	header.add_theme_color_override("font_color", Color(1.0, 0.83, 0.53))
	layer.add_child(header)
	var column_px := float(VIEWPORT_SIZE.x) * spacing / 9.6
	for index in poses.size():
		var label := Label.new()
		label.text = "%s\n%s" % [poses[index]["label"], poses[index]["id"]]
		label.position = Vector2(float(index) * column_px + 24.0, 640.0)
		label.add_theme_font_size_override("font_size", 17)
		label.add_theme_color_override("font_color", Color(0.94, 0.94, 0.90))
		layer.add_child(label)


func _build_stage() -> Node3D:
	var stage := Node3D.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.047, 0.047)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.60, 0.68, 0.74)
	environment.ambient_light_energy = 0.44
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color(1.0, 0.86, 0.68)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(24.0, 16.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.106, 0.125, 0.122)
	floor_material.roughness = 1.0
	floor_mesh.material = floor_material
	var floor_instance := MeshInstance3D.new()
	floor_instance.mesh = floor_mesh
	stage.add_child(floor_instance)
	return stage
