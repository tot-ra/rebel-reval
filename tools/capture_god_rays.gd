extends SceneTree

## God-ray review plates: the shipped orthographic gameplay camera, a top-down view and
## an eye-level lens toward a low sun, each with and without the god-ray pass.
## WHY: the pass is volumetric (ray-marched against the architecture height raster),
## so the review needs the same poses with the overlay on and off to judge whether the
## shafts follow roofs and gaps, vanish behind buildings, and stay off a top-down view.
##   tools/godot_render.sh --script tools/capture_god_rays.gd [-- --map=lower_town_slice
##   --weather=cloudy --out=res://build/god_rays]

const Registry := preload("res://scripts/map/map_audit_registry.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const GodRayPass := preload("res://scripts/map/view3d/god_ray_pass.gd")
const CharacterScale := preload("res://assets/characters/shared/character_scale.gd")

const VIEWPORT_SIZE := Vector2i(1280, 720)
const SETTLE_FRAMES := 8


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var map_id := "lower_town_slice"
	var weather := &"cloudy"
	var output_dir := "res://build/god_rays"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			map_id = arg.trim_prefix("--map=")
		elif arg.begins_with("--weather="):
			weather = StringName(arg.trim_prefix("--weather="))
		elif arg.begins_with("--out="):
			output_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var definition: MapDefinition = Registry.by_id()[map_id]
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := MapView3D.create(definition, MapBuilder.build(definition), MapView3D.TIME_DAY)
	viewport.add_child(view)
	await view.assemble_async(200.0)
	view.update_active_chunks_from_logic_positions([definition.player_spawn])
	var sky := view.sky_weather()
	sky.auto_weather = false
	sky.set_weather(weather)
	sky.advance(30.0)
	view.set_weather_time_scale(0.0)
	var ortho := view.view_camera()
	var progress := _best_gameplay_progress(view, ortho)
	view.apply_cycle_progress(progress, false)
	# The height raster rebuilds once the streamed masses have been stable a moment.
	for _frame in SETTLE_FRAMES * 6:
		await process_frame
	var light := view.god_ray_pass()
	var sun_dir := _sun_direction(view, progress)
	print("GODRAY progress=%.3f hour=%.2f sun=%s strength=%.3f" % [
		progress, progress * 24.0, sun_dir, light.strength
	])
	var spawn := view.world_position(definition.player_spawn, 0.8)
	var eye := Camera3D.new()
	eye.fov = 65.0
	eye.near = 0.05
	eye.far = 400.0
	viewport.add_child(eye)
	var poses := {
		"gameplay": func() -> void:
			view.set_close_camera_mode(false)
			ortho.make_current()
			ortho.size = CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE * 1.6
			ortho.global_position = spawn + ortho.global_transform.basis.z * MapView3D.CAMERA_DISTANCE,
		"topdown": func() -> void:
			view.set_close_camera_mode(false)
			eye.make_current()
			eye.look_at_from_position(spawn + Vector3(0.0, 60.0, 0.01), spawn, Vector3.UP),
		"eye": func() -> void:
			view.set_close_camera_mode(true)
			eye.make_current()
			var flat := Vector3(sun_dir.x, 0.0, sun_dir.z).normalized()
			eye.look_at_from_position(
				spawn - flat * 6.0 + Vector3(0.0, 1.1, 0.0), spawn + flat * 20.0 + Vector3(0.0, 6.0, 0.0)
			),
	}
	for pose: String in poses:
		(poses[pose] as Callable).call()
		for state: String in ["on", "off"]:
			var overlay := light.get_node("GodRayOverlay") as MeshInstance3D
			# MapView3D._process re-shows the overlay every frame; pause it for the off plate.
			view.set_process(state == "on")
			for _frame in SETTLE_FRAMES:
				await process_frame
				if state == "off":
					overlay.visible = false
			var path := "%s/%s_%s_%s.png" % [output_dir, map_id, pose, state]
			viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
			print("GODRAY %s strength=%.3f overlay=%s" % [path.get_file(), light.strength, overlay.visible])
	if OS.get_cmdline_user_args().has("--bench"):
		(poses["gameplay"] as Callable).call()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		for state: String in ["on", "off", "on", "off"]:
			view.set_process(state == "on")
			light.get_node("GodRayOverlay").visible = state == "on"
			for _frame in 30:
				await process_frame
			var start := Time.get_ticks_usec()
			for _frame in 200:
				await process_frame
			print("GODRAY bench %s %.2f ms/frame" % [state, (Time.get_ticks_usec() - start) / 200000.0])
	quit(0)


func _sun_direction(view: MapView3D, progress: float) -> Vector3:
	var sky := view.sky_weather()
	var blend := SkyWeather3D.daylight_blend(progress, sky.calendar_date)
	return sky.presentation_snapshot(progress, blend).sun_direction.normalized()


## Daytime clock where the gameplay camera looks most directly into a sun that is
## still above the roofs (the only time the fixed dimetric lens can see shafts).
func _best_gameplay_progress(view: MapView3D, ortho: Camera3D) -> float:
	var best := 0.75
	var best_score := -1.0
	for step in range(240, 960, 3):
		var progress := float(step) / 1000.0
		var sun := _sun_direction(view, progress)
		if sun.y < 0.08:
			continue
		var score := GodRayPass.phase(-ortho.global_transform.basis.z.dot(sun))
		if score > best_score:
			best_score = score
			best = progress
	return best
