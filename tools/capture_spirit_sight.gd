extends SceneTree

## R-1484 (SS-1): day and night plates, physical vs spirit sight, on the same map and camera.
## Run via tools/godot_render.sh --resolution 1280x720 --script tools/capture_spirit_sight.gd.
## Writes four plates plus a 2x2 sheet under docs/reports/images/spirit_sight/ (only sheet.png,
## downscaled to 1600 px wide, is committed as evidence).

const Registry := preload("res://scripts/map/map_audit_registry.gd")
const Builder := preload("res://scripts/map/map_builder.gd")
const View := preload("res://scripts/map/view3d/map_view_3d.gd")
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const Sight := preload("res://scripts/combat/spirit_sight.gd")
const MAP_ID := "smithy_courtyard"
const OUT_DIR := "res://docs/reports/images/spirit_sight"
const PLATE := Vector2i(1280, 720)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Spirit sight plates need tools/godot_render.sh (GPU renderer)")
		quit(2)
		return
	var definition: MapDefinition = Registry.by_id().get(MAP_ID)
	if definition == null:
		push_error("No capture map found: %s" % MAP_ID)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var view := View.create(definition, Builder.build(definition), View.TIME_DAY)
	root.add_child(view)
	view.set_weather_time_scale(0.0)
	view.set_process(false)
	var sky := view.sky_weather()
	sky.auto_weather = false
	sky.set_weather(SkyWeather.WEATHER_CLEAR)
	view.view_camera().current = true
	# Fixture mode: the controller grades the view's own environment and sun directly.
	var sight := Sight.new()
	sight.follow_session = false
	sight.state = GameState.new()
	sight.environment_override = view.environment_node().environment
	sight.sun_override = view.get("_sun")
	root.add_child(sight)
	var sheet := Image.create(PLATE.x * 2, PLATE.y * 2, false, Image.FORMAT_RGBA8)
	var row := 0
	for time: StringName in [View.TIME_DAY, View.TIME_NIGHT]:
		view.set_time_of_day(time)
		for column in range(2):
			var on := column == 1
			sight.leave_immediately()
			if on:
				sight.state.spirit_sight = true
				sight.blend = 1.0
			for _frame in range(30):
				await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			# Retina viewports may double CLI resolution; evidence follows the 720p policy.
			if image.get_size() != PLATE:
				image.resize(PLATE.x, PLATE.y, Image.INTERPOLATE_LANCZOS)
			image.convert(Image.FORMAT_RGBA8)
			var name := "%s_%s.png" % [String(time), "sight" if on else "physical"]
			image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUT_DIR, name]))
			sheet.blit_rect(image, Rect2i(Vector2i.ZERO, PLATE), Vector2i(column, row) * PLATE)
			print("CAPTURED ", name)
		row += 1
	sight.leave_immediately()
	var error := sheet.save_png(ProjectSettings.globalize_path(OUT_DIR + "/sheet.png"))
	print("Saved sheet (error=%d)" % error)
	quit(0 if error == OK else 1)
