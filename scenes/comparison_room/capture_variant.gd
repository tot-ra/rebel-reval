extends SceneTree


func _init() -> void:
	var user_args := OS.get_cmdline_user_args()
	if user_args.size() != 2:
		push_error("Usage: godot --script capture_variant.gd -- <scene> <png> (graphics renderer required)")
		quit(2)
		return

	var packed_scene := load(user_args[0]) as PackedScene
	if packed_scene == null:
		push_error("Could not load scene: " + user_args[0])
		quit(2)
		return

	var instance := packed_scene.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(user_args[1])
	instance.queue_free()
	if error != OK:
		push_error("Could not save screenshot: %s" % error_string(error))
		quit(1)
		return
	print("Saved P0-035 snapshot: " + user_args[1])
	quit(0)
