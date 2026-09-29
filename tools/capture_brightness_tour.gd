extends SceneTree

## Exposure review tour: renders several production maps from the shipped gameplay
## camera and from eye level at morning, noon and late afternoon, and prints the
## mean/percentile luminance of each frame.
##
## WHY: players reported the town reads too dark. Lighting constants live in
## MapViewLighting, so a before/after comparison needs the same poses, times and a
## numeric brightness readout rather than one hand-picked screenshot.
##   tools/godot_render.sh --script tools/capture_brightness_tour.gd [-- --out=res://build/x --label=after]

const Registry := preload("res://scripts/map/map_audit_registry.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const CharacterScale := preload("res://assets/characters/shared/character_scale.gd")

const DEFAULT_OUTPUT_DIR := "res://build/brightness_tour"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const MAP_IDS: Array[StringName] = [
	&"lower_town_slice",
	&"market_civic_quarter",
	&"north_quarter",
	&"reval_harbor_east",
	&"kalev_smithy",
]
## 08:00, 12:00, 17:00, 20:30 and midnight on the 24 h cycle.
const TIMES := {
	"morning": 8.0 / 24.0,
	"noon": 0.5,
	"evening": 17.0 / 24.0,
	"dusk": 20.5 / 24.0,
	"night": 0.0,
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_dir := DEFAULT_OUTPUT_DIR
	var label := "before"
	var map_ids: Array[StringName] = MAP_IDS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--label="):
			label = arg.trim_prefix("--label=")
		elif arg == "--no-cloud-shadows":
			RenderingServer.global_shader_parameter_set(&"cloud_shadow_strength", 0.0)
		elif arg.begins_with("--maps="):
			map_ids.assign(Array(arg.trim_prefix("--maps=").split(",")).map(
				func(id: String) -> StringName: return StringName(id)
			))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var maps := Registry.by_id()
	for map_id in map_ids:
		if not maps.has(String(map_id)):
			push_warning("Brightness tour: unknown map %s" % map_id)
			continue
		await _capture_map(maps[String(map_id)], output_dir, label)
	quit(0)


func _capture_map(definition: MapDefinition, output_dir: String, label: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := MapView3D.create(definition, MapBuilder.build(definition), MapView3D.TIME_DAY)
	viewport.add_child(view)
	# create() stages assembly; without finishing it only sky and ground render.
	await view.assemble_async(200.0)
	view.update_active_chunks_from_logic_positions([definition.player_spawn])
	# Freeze clouds so frames differ only by the lighting under review.
	view.set_weather_time_scale(0.0)
	var spawn := view.world_position(definition.player_spawn, 0.8)
	var ortho := view.view_camera()
	var eye_camera := Camera3D.new()
	eye_camera.fov = 65.0
	eye_camera.near = 0.05
	eye_camera.far = 400.0
	viewport.add_child(eye_camera)
	for time_id: String in TIMES:
		view.apply_cycle_progress(TIMES[time_id], false)
		var sun := view.sun_light()
		var env := view.environment_node().environment
		print("LIGHT %s %s sun=%.2f %s ambient=%.2f %s exposure=%.2f elev=%.1f" % [
			definition.map_id, time_id, sun.light_energy, sun.light_color.to_html(false),
			env.ambient_light_energy, env.ambient_light_color.to_html(false),
			env.tonemap_exposure, rad_to_deg(asin(clampf(sun.global_transform.basis.z.y, -1.0, 1.0))),
		])
		ortho.make_current()
		view.set_close_camera_mode(false)
		ortho.size = CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE
		ortho.global_position = spawn + ortho.global_transform.basis.z * MapView3D.CAMERA_DISTANCE
		for _frame in 10:
			await process_frame
		_save(viewport, "%s/%s_%s_gameplay_%s.jpg" % [output_dir, definition.map_id, time_id, label])
		view.set_close_camera_mode(true)
		eye_camera.make_current()
		eye_camera.global_position = spawn + Vector3(-4.0, 1.9, 4.0)
		eye_camera.look_at(spawn + Vector3(6.0, 1.2, -6.0), Vector3.UP)
		for _frame in 6:
			await process_frame
		_save(viewport, "%s/%s_%s_eye_%s.jpg" % [output_dir, definition.map_id, time_id, label])
	viewport.queue_free()
	await process_frame


func _save(viewport: SubViewport, output: String) -> void:
	var image := viewport.get_texture().get_image()
	image.save_jpg(ProjectSettings.globalize_path(output), 0.85)
	print("TOUR %s %s" % [output.get_file(), _luma_stats(image)])


## Mean, median and 90th-percentile sRGB luma on a coarse grid (0..255).
static func _luma_stats(image: Image) -> String:
	var values: Array[float] = []
	var step := 8
	for y in range(0, image.get_height(), step):
		for x in range(0, image.get_width(), step):
			var c := image.get_pixel(x, y)
			values.append((0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * 255.0)
	values.sort()
	var total := 0.0
	for v in values:
		total += v
	return "mean=%.0f p50=%.0f p90=%.0f" % [
		total / values.size(), values[values.size() / 2], values[int(values.size() * 0.9)]
	]
