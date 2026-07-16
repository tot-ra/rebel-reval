extends SceneTree

const SCENE_PATH := "res://scenes/map_prototype/smithy_courtyard.tscn"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		push_error("Usage: godot --path . --script capture_visual_target.gd -- <target> <day|night> <png>")
		quit(2)
		return

	var target := StringName(args[0])
	var time_of_day := StringName(args[1])
	if not MapVisualStyle.is_valid_target(target) or not MapVisualStyle.is_valid_time(time_of_day):
		push_error("Invalid visual target or time of day: %s / %s" % [target, time_of_day])
		quit(2)
		return

	var packed_scene := load(SCENE_PATH) as PackedScene
	var instance := packed_scene.instantiate()
	instance.configure_style(target, time_of_day)
	root.add_child(instance)
	await process_frame
	await process_frame
	await process_frame

	var image := root.get_texture().get_image()
	var output_path := ProjectSettings.globalize_path(args[2]) if args[2].begins_with("res://") else args[2]
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Could not save P0-036 capture: %s" % error_string(error))
		quit(1)
		return
	print("P0-036 capture: %s %s -> %s" % [target, time_of_day, output_path])
	quit(0)
