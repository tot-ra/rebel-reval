extends SceneTree

## Review plates for localized fog banks and horizon heat shimmer
## (docs/SYSTEMS/LOCAL_ATMOSPHERE.md). Builds the seamless city view, sets the weather,
## and shoots the shore from eye level. Needs a renderer:
##   tools/godot_render.sh --script tools/capture_local_fog.gd [-- --only=a,b --tag=now]
## Output: build/local_fog/<shot>_<tag>.png

const OUTPUT_DIR := "res://build/local_fog"
const VIEWPORT_SIZE := Vector2i(1600, 900)
const SETTLE_FRAMES := 240

var _tag := "now"
var _only := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			_tag = arg.substr(6)
		elif arg.begins_with("--only="):
			_only = arg.substr(7)
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var plan := CityPlan.load_default()
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := CityMapView.create_city(plan)
	viewport.add_child(view)
	var landing := Vector2(
		plan.data["harbour"]["crane"]["at"][0], plan.data["harbour"]["crane"]["at"][1]
	)
	var camera := view.view_camera()
	var sky := view.sky_weather()
	sky.auto_weather = false
	view.set_weather_time_scale(0.0)
	var shots: Array[Dictionary] = [
		{
			"name": "fog_overcast_shore", "weather": &"overcast", "progress": 0.33, "wet": true,
			"date": {"day": 21, "month": 4, "year": 1343},
		},
		{
			"name": "fog_overcast_overview", "weather": &"overcast", "progress": 0.33,
			"wet": true, "overview": true, "pitch": 30.0,
			"date": {"day": 21, "month": 4, "year": 1343},
		},
		{
			"name": "fog_overcast_steep", "weather": &"overcast", "progress": 0.33,
			"wet": true, "overview": true, "pitch": 75.0,
			"date": {"day": 21, "month": 4, "year": 1343},
		},
		{
			"name": "fog_after_rain_lowsun", "weather": &"clear", "progress": 0.27, "wet": true,
			"date": {"day": 21, "month": 4, "year": 1343},
		},
		{
			"name": "mirage_midsummer", "weather": &"clear", "progress": 0.5, "wet": false,
			"date": {"day": 21, "month": 6, "year": 1343},
		},
		{
			"name": "clear_april_baseline", "weather": &"clear", "progress": 0.5, "wet": false,
			"date": {"day": 21, "month": 4, "year": 1343},
		},
	]
	for shot in shots:
		if not _only.is_empty() and not shot["name"] in _only.split(","):
			continue
		view.set_calendar_date(shot["date"])
		# Each plate starts independently; summer must not inherit April rain puddles.
		sky.set_weather(&"clear")
		sky.advance(3600.0)
		if shot["wet"]:
			sky.set_weather(&"rain")
			sky.advance(60.0)
		sky.set_weather(shot["weather"])
		sky.advance(30.0)
		view.apply_cycle_progress(shot["progress"], false)
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 70.0
		camera.near = 0.1
		camera.far = 5000.0
		var eye_ground := maxf(plan.ground_height(landing + Vector2(-40.0, 6.0)), 0.0)
		camera.look_at_from_position(
			Vector3(landing.x - 40.0, eye_ground + 2.2, landing.y + 6.0),
			Vector3(landing.x + 30.0, 1.4, landing.y - 40.0),
			Vector3.UP
		)
		for _i in SETTLE_FRAMES:
			view.apply_cycle_progress(shot["progress"], false)
			await process_frame
		await RenderingServer.frame_post_draw
		var atmosphere: Variant = view.get("_local_atmosphere")
		# Walk to the strongest bank so the plate shows fog from the shore, not a far one.
		var strongest: Variant = null
		if atmosphere != null:
			for bank in atmosphere.fog_banks.banks():
				if bank.emitter.visible and (strongest == null or bank.strength > strongest.strength):
					strongest = bank
		if strongest != null:
			var at: Vector3 = strongest.emitter.global_position
			var stand := Vector2(at.x - 12.0, at.z + 24.0)
			var stand_y := maxf(plan.ground_height(stand), 0.0) + 2.2
			camera.look_at_from_position(
				Vector3(stand.x, stand_y, stand.y), at + Vector3(4.0, 1.0, -6.0), Vector3.UP
			)
			for _i in SETTLE_FRAMES / 2:
				view.apply_cycle_progress(shot["progress"], false)
				await process_frame
			await RenderingServer.frame_post_draw
		if bool(shot.get("overview", false)):
			var focus: Vector3 = strongest.emitter.global_position if strongest != null else Vector3(
				landing.x, 0.0, landing.y
			)
			var pitch := deg_to_rad(float(shot["pitch"]))
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = 70.0
			camera.look_at_from_position(
				focus + Vector3(-cos(pitch), sin(pitch), cos(pitch)).normalized() * 100.0,
				focus, Vector3.UP
			)
			for _i in SETTLE_FRAMES / 2:
				view.apply_cycle_progress(shot["progress"], false)
				await process_frame
			await RenderingServer.frame_post_draw
		var banks := -1
		if atmosphere != null:
			banks = atmosphere.fog_banks.visible_bank_count()
			for bank in atmosphere.fog_banks.banks():
				if bank.emitter.visible:
					var at: Vector3 = bank.emitter.global_position
					print("  bank ", bank.cell, " strength=%.2f dist=%.0f screen=%s behind=%s" % [
						bank.strength, camera.global_position.distance_to(at),
						camera.unproject_position(at), camera.is_position_behind(at)
					])
			print("  camera ", camera.global_position, " density=", atmosphere.fog_banks._density)
		var image := viewport.get_texture().get_image()
		var path := "%s/%s_%s.png" % [OUTPUT_DIR, shot["name"], _tag]
		image.save_png(ProjectSettings.globalize_path(path))
		print("captured ", path, " visible banks: ", banks)
	quit(0)
