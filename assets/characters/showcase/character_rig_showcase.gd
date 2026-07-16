extends Node3D

const CAPTURE_FLAG := "--capture-p0-037"
const CAPTURE_PATH := "res://docs/reports/images/p0_037_character_rig.png"

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	if CAPTURE_FLAG in OS.get_cmdline_user_args():
		_capture_after_animation_pose.call_deferred()

func _capture_after_animation_pose() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.32).timeout
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(CAPTURE_PATH))
	if error != OK:
		push_error("Could not save P0-037 capture: %s" % error_string(error))
		get_tree().quit(1)
		return
	print("Saved P0-037 capture to %s" % CAPTURE_PATH)
	get_tree().quit(0)

