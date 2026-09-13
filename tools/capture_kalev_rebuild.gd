extends SceneTree

const OUTPUT := "res://docs/reports/images/kalev_rebuild/"
var preview: Node3D

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1280, 1280)
	preview = load("res://assets/characters/kalev_rebuild/preview.tscn").instantiate() as Node3D
	root.add_child(preview)
	await process_frame
	preview.hud.hide()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	preview.set_outfit(0)
	for shot: Array in [["body_front", 0.0], ["body_three_quarter", 0.55], ["body_profile", PI / 2.0], ["body_back", PI]]:
		preview.orbit = shot[1]
		preview._update_camera()
		await _save(shot[0], 0.0)
	preview.orbit = 0.0
	preview.camera_distance = 0.92
	preview.aim_height = 1.79
	preview._update_camera()
	await _save("portrait", 0.0)
	preview.camera_distance = 3.8
	preview.aim_height = 1.05
	preview.orbit = 0.2
	preview._update_camera()
	for i: int in range(1, 4):
		preview.set_outfit(i)
		preview.set_weapon(1 if i == 1 else 2)
		await _save(["", "forge", "travel", "mail"][i], 0.0)
	preview.set_outfit(2)
	preview.set_weapon(0)
	for motion: StringName in [&"walk", &"run", &"guard", &"hammer_attack"]:
		preview.rig.play_animation(motion, 0.0)
		if motion == &"hammer_attack":
			preview.set_weapon(1)
		for frame: int in range(3):
			await _save("%s_%d" % [motion, frame], 0.15 + 0.22 * frame)
	preview.queue_free()
	await process_frame
	quit()

func _save(filename: String, seconds: float) -> void:
	var player: AnimationPlayer = preview.rig.animation_player()
	player.speed_scale = 0.0
	player.seek(seconds, true)
	player.advance(0.0)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OUTPUT + filename + ".png")
	assert(result == OK)
	print("CAPTURED " + filename)
