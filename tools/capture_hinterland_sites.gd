extends SceneTree

## Review plates for the Act 2 hinterland sites (docs/SYSTEMS/REGIONAL_SITES.md):
## the Harju village, the rebel kings' camp and the sacred grove under their own
## sky, by day, at dusk, at night and in rain, with the point-of-interest
## dressing (smoke, fires, stones, spring) from hinterland_site.gd. Same view
## path as tools/capture_regional_sites.gd, kept separate so parallel site
## tasks do not edit one shot list.
##   tools/godot_render.sh --script tools/capture_hinterland_sites.gd [-- --only=<shot>[,<shot>]]
## Output: docs/reports/images/sites/<shot>.png (1280x720)

const Hinterland := preload("res://scenes/world/sites/hinterland_site.gd")
const OUTPUT_DIR := "res://docs/reports/images/sites"
const VIEWPORT_SIZE := Vector2i(1280, 720)
## Cycle progress: 0.5 is local noon.
const DAY := 0.44
const DUSK := 0.79
const NIGHT := 0.865

## site -> [[shot, weather, progress, eye (x, height above ground, z), look (same), fov]]
const SHOTS := {
	"harju":
	[
		["harju_day_village", &"clear", DAY, Vector3(-150, 24, -60), Vector3(-50, 2, 40), 55.0],
		["harju_day_farmstead", &"clear", DAY, Vector3(-40, 4.5, 20), Vector3(-26, 2.5, -8), 64.0],
		["harju_dusk_fields", &"clear", DUSK, Vector3(10, 9, 30), Vector3(180, 0, -140), 62.0],
		["harju_day_aerial", &"clear", DAY, Vector3(220, 160, 260), Vector3(-30, 0, 20), 56.0],
		["harju_night_village", &"clear", NIGHT, Vector3(-150, 24, -60), Vector3(-50, 2, 40), 55.0],
		["harju_rain_village", &"rain", DAY, Vector3(-96, 6, 46), Vector3(-30, 3, 30), 60.0],
	],
	"rebel_kings":
	[
		["rebel_kings_day_camp", &"clear", DAY, Vector3(70, 22, -150), Vector3(-50, 1, -70), 55.0],
		["rebel_kings_day_stockade", &"clear", DAY, Vector3(14, 4, -80), Vector3(-60, 2, -75), 62.0],
		["rebel_kings_day_aerial", &"clear", DAY, Vector3(160, 150, 160), Vector3(-40, 0, -50), 56.0],
		["rebel_kings_night_camp", &"clear", NIGHT, Vector3(70, 22, -150), Vector3(-50, 1, -70), 55.0],
		["rebel_kings_night_fire", &"clear", NIGHT, Vector3(-40, 3.2, -60), Vector3(-60, 0.8, -75), 62.0],
	],
	"sacred_grove":
	[
		["sacred_grove_day_meadow", &"clear", DAY, Vector3(-44, 3, -40), Vector3(-56, 6, 80), 62.0],
		["sacred_grove_day_stones", &"clear", DAY, Vector3(-46, 3.2, 52), Vector3(-60, 0.5, 80), 64.0],
		["sacred_grove_day_spring", &"clear", DAY, Vector3(8, 3, 98), Vector3(22, 0, 112), 62.0],
		["sacred_grove_day_aerial", &"clear", DAY, Vector3(170, 150, -170), Vector3(-40, 0, 40), 56.0],
		["sacred_grove_night_grove", &"clear", NIGHT, Vector3(-44, 3, -40), Vector3(-56, 6, 80), 62.0],
	],
}

var _only := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.substr(7)
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	for site: String in SHOTS:
		var wanted := (SHOTS[site] as Array).filter(
			func(s: Array) -> bool: return _only.is_empty() or String(s[0]) in _only.split(",")
		)
		if wanted.is_empty():
			continue
		var plan := CityPlan.load_site(site)
		# As site_level.gd does: the sky is computed for the site's own origin.
		SkyAstronomy.set_observer(plan.origin_latitude(), plan.origin_longitude())
		var view := CityMapView.create_city(plan)
		root.add_child(view)
		var dressing: Node3D = Hinterland.dress(plan, view.world)
		for shot: Array in wanted:
			var sky: SkyWeather3D = view._sky_weather
			sky.auto_weather = false
			sky.time_scale = 0.0
			sky.set_weather(shot[1])
			sky.advance(SkyWeather3D.TRANSITION_SECONDS + 0.1)
			sky.advance(17.0)
			view.apply_cycle_progress(shot[2])
			Hinterland.apply_dressing_cycle(dressing, shot[2])
			var eye := _above_ground(plan, shot[3])
			var look := _above_ground(plan, shot[4])
			await _shot(view, shot[0], eye, look, shot[5])
		view.queue_free()
		await process_frame
		SkyAstronomy.reset_observer()
	quit(0)


func _above_ground(plan: CityPlan, p: Vector3) -> Vector3:
	return Vector3(p.x, plan.ground_height(Vector2(p.x, p.z)) + p.y, p.z)


func _shot(view: CityMapView, shot: String, eye: Vector3, look: Vector3, fov: float) -> void:
	var camera: Camera3D = view._camera
	camera.fov = fov
	camera.far = 9000.0
	camera.near = 0.08 if eye.y < 120.0 else 1.0
	camera.look_at_from_position(eye, look, Vector3.UP)
	# Grass, crops and plumes stream round a focus (the level uses Kalev); the
	# particles (flames, smoke) need a moment to fill after they mount.
	var focus := Vector2(look.x, look.z)
	for i in 40:
		view.world.grass.update_for(focus)
		view.world.farmland.update_for(focus)
		view.world.smoke.update_for(focus, 1.0)
		await process_frame
	var image := root.get_texture().get_image()
	if image.get_size() != VIEWPORT_SIZE:
		image.resize(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var path := "%s/%s.png" % [OUTPUT_DIR, shot]
	image.save_png(ProjectSettings.globalize_path(path))
	print("captured %s" % path)
