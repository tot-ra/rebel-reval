extends SceneTree

## Horse review plate through the runtime loader (MapViewMedievalAnimalModels),
## so the shot shows the same coat, hair-card and eye materials as the game.
## tools/godot_render.sh --script tools/capture_horse_review.gd
const OUT := "res://docs/reports/images/fauna/"
const AnimalModels := preload("res://scripts/map/view3d/map_view_medieval_animal_models.gd")
const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")
# name: [camera offset from the target, target key]. Targets come from the
# posed meshes: the whole body, the near (-X) eye, or the rump.
const SHOTS := {
	"three_quarter": [Vector3(-1.5, 0.35, -1.9), &"body"],
	"head": [Vector3(-0.75, 0.10, -0.40), &"eye"],
	"tail": [Vector3(-1.2, 0.20, 1.5), &"rump"],
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var plate := Image.create(1800, 600, false, Image.FORMAT_RGBA8)
	var index := 0
	for shot_name: String in SHOTS:
		var spec: Array = SHOTS[shot_name]
		var viewport := SubViewport.new()
		viewport.size = Vector2i(600, 600)
		viewport.own_world_3d = true
		viewport.msaa_3d = Viewport.MSAA_4X
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var scene := Node3D.new()
		viewport.add_child(scene)
		var environment := Environment.new()
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color("6f7f88")
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color("c5d6dd")
		environment.ambient_light_energy = 0.6
		environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		var world := WorldEnvironment.new()
		world.environment = environment
		scene.add_child(world)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-40, -140, 0)
		sun.light_color = Color("fff0d9")
		sun.light_energy = 1.3
		sun.shadow_enabled = true
		scene.add_child(sun)
		var actor := Node3D.new()
		scene.add_child(actor)
		var model := AnimalModels.add_model(actor, MammalSpecies.SPECIES_HORSE)
		assert(model != null)
		var players := model.find_children("*", "AnimationPlayer", true, false)
		if not players.is_empty():
			var player := players[0] as AnimationPlayer
			player.play(player.get_animation_list()[0] if not player.has_animation("Idle") else &"Idle")
			player.seek(0.0, true)
			player.pause()
		for frame in 4:
			await process_frame
		var target := _target(model, spec[1] as StringName)
		var camera := Camera3D.new()
		camera.fov = 30.0
		scene.add_child(camera)
		var offset := spec[0] as Vector3
		if spec[1] != &"eye":
			offset *= _body_bounds(model).size.length()
		camera.position = target + offset
		camera.look_at(target)
		camera.current = true
		for frame in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		image.save_jpg(ProjectSettings.globalize_path(OUT + "horse_" + shot_name + ".jpg"), 0.88)
		plate.blit_rect(image, Rect2i(0, 0, 600, 600), Vector2i(index * 600, 0))
		index += 1
		viewport.queue_free()
		await process_frame
	plate.save_jpg(ProjectSettings.globalize_path(OUT + "horse_review_plate.jpg"), 0.88)
	print("Horse review capture complete")
	quit()


func _body_bounds(model: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var box := mesh.global_transform * mesh.bake_mesh_from_current_skeleton_pose().get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


func _target(model: Node3D, key: StringName) -> Vector3:
	var bounds := _body_bounds(model)
	if key == &"rump":
		return bounds.get_center() + Vector3(0.0, 0.0, bounds.size.z * 0.3)
	if key == &"eye":
		var best := Vector3.INF
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var lower := String(mesh.name).to_lower()
			if not lower.contains("eye") or lower.contains("lid"):
				continue
			var posed := mesh.bake_mesh_from_current_skeleton_pose()
			var centre := (mesh.global_transform * posed.get_aabb()).get_center()
			if centre.x < best.x:
				best = centre
		if best != Vector3.INF:
			return best
	return bounds.get_center()
