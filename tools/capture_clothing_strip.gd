extends SceneTree

## Clothing strip proof (docs/SYSTEMS/CLOTHING_STRIP.md): Aita is undressed layer by layer through
## the real mouse path (press on a garment, drag down), one frame per layer. Needs a GPU run:
##   tools/godot_render.sh --script tools/capture_clothing_strip.gd [-- --output=PATH]
## Output stays under build/ by default: nothing here is an asset.

const OUTPUT := "res://build/clothing_strip/strip_sequence.png"
## Garments to pull in order, each aimed at the box centre so the ray lands on that layer.
const ORDER: Array[String] = ["outerwear", "head", "feet", "torso"]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var output := OUTPUT
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(480, 760)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, 25.0, 0.0)
	viewport.add_child(sun)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.5, 0.58, 0.68)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.7, 0.7, 0.72)
	viewport.add_child(environment)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 1.0, 3.6), Vector3(0.0, 0.95, 0.0))
	camera.current = true
	var rig := (
		(load("res://assets/characters/variants/aita.tscn") as PackedScene).instantiate()
		as SharedCharacterRig
	)
	rig.start_animation = &"idle"
	viewport.add_child(rig)
	var strip := ClothingStrip.new()
	strip.camera_provider = func() -> Camera3D: return camera
	root.add_child(strip)
	strip.register(rig)

	var frames: Array[Image] = []
	await _settle()
	frames.append(viewport.get_texture().get_image())
	for slot in ORDER:
		var aim := _screen_point(camera, rig, slot)
		if aim == Vector2.INF:
			push_error("no %s garment to aim at" % slot)
			continue
		# Same events the player produces: press on the garment, drag down past the threshold.
		_send(strip, aim, true, Vector2.ZERO)
		_send_motion(strip, aim + Vector2(0.0, ClothingStrip.DRAG_PX + 8.0))
		_send(strip, aim, false, Vector2.ZERO)
		await _settle()
		frames.append(viewport.get_texture().get_image())
	var sheet := Image.create(
		frames.size() * viewport.size.x, viewport.size.y, false, Image.FORMAT_RGBA8
	)
	for index in frames.size():
		frames[index].convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(
			frames[index],
			Rect2i(Vector2i.ZERO, viewport.size),
			Vector2i(index * viewport.size.x, 0)
		)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output).get_base_dir())
	sheet.save_png(ProjectSettings.globalize_path(output))
	print("saved %s (%d frames)" % [output, frames.size()])
	quit()


func _settle() -> void:
	for i in 12:
		await process_frame


func _screen_point(camera: Camera3D, rig: SharedCharacterRig, slot: String) -> Vector2:
	for child: Node in rig.skeleton().get_children():
		var mesh := child as MeshInstance3D
		if mesh != null and String(mesh.name).begins_with("Garment_wearable_%s_" % slot):
			var box := mesh.get_aabb()
			var local := (
				box.get_center()
				+ (Vector3(0.0, box.size.y * 0.4, 0.0) if slot == "torso" else Vector3.ZERO)
			)
			return camera.unproject_position(mesh.global_transform * local)
	return Vector2.INF


func _send(strip: ClothingStrip, at: Vector2, pressed: bool, _unused: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	strip._unhandled_input(event)


func _send_motion(strip: ClothingStrip, at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	strip._unhandled_input(event)
