extends SceneTree

## Sky reference plates (R-1766): a low wide camera over the city looking across the sun
## at fixed times and weathers, so sky exposure and cloud shading can be compared before
## and after a lighting change. Promoted from the build/witcher_sky_probe.gd scratch probe.
##   tools/godot_render.sh --script tools/capture_sky_reference.gd
##   tools/godot_render.sh --script tools/capture_sky_reference.gd -- --out=res://build/sky_before
##   tools/godot_render.sh --script tools/capture_sky_reference.gd -- --only=noon_side_clear
##   tools/godot_render.sh --disable-vsync --script tools/capture_sky_reference.gd \
##     -- --bench=120 --decks=0,1
## Output: docs/reports/images/weather/sky_reference_<shot>.png (or <out>/sky_reference_<shot>.png)
## R-1768: --deck=N captures with that `cloud_deck_mode` (0 flat deck, 1 lit 2.5D deck);
## --ab captures every mode in --decks per shot in one run (sky_reference_<shot>_deck<N>.png);
## --bench=N skips the PNGs and prints the mean wall-clock frame time of N frames per
## shot for each mode in --decks (alternating rounds, best of three), so the deck cost
## is the difference between modes on the same view.
## R-1873: mode 2 is the high tier's ray-marched slab (CloudSlabEffect); switching to it
## waits SLAB_SETTLE_FRAMES so the temporal history converges before a capture/bench.
##   tools/godot_render.sh --script tools/capture_sky_reference.gd -- --ab --decks=1,2
##   tools/godot_render.sh --disable-vsync --script tools/capture_sky_reference.gd \
##     -- --bench=120 --decks=1,2
## --slab-cost=N isolates the slab pass's GPU cost: Metal has no GPU timestamps and the
## wall-clock A/B is within noise, so it reruns march + resolve N times on a local
## RenderingDevice with the shot's live parameters (submit + sync each) and prints the best.
##   tools/godot_render.sh --disable-vsync --script tools/capture_sky_reference.gd -- --slab-cost=60

const DEFAULT_OUT := "res://docs/reports/images/weather"
const SIZE := Vector2i(1280, 720)
const SLAB_SETTLE_FRAMES := 40
# [name, weather, cycle progress, yaw offset from sun (deg), pitch (deg), fov]
const SHOTS := [
	["noon_side_clear", SkyWeather3D.WEATHER_CLEAR, 0.42, 70.0, 14.0, 80.0],
	["aft_side_cloudy", SkyWeather3D.WEATHER_CLOUDY, 0.71, 60.0, 18.0, 85.0],
	# R-1769: cloudless-ish sky, sun behind the shoulder, for the wind-combed cirrus layer.
	["aft_side_clear", SkyWeather3D.WEATHER_CLEAR, 0.71, 60.0, 18.0, 85.0],
	# R-1768: steep view so the deck fills the frame (overhead lobes, bench worst case).
	["up_cloudy", SkyWeather3D.WEATHER_CLOUDY, 0.71, 60.0, 50.0, 85.0],
	["gold_side_cloudy", SkyWeather3D.WEATHER_CLOUDY, 0.80, 70.0, 14.0, 80.0],
	# R-1767 golden-hour series: sun roughly 22 / 14 / 8 deg high, same side-on framing.
	["gold_070_cloudy", SkyWeather3D.WEATHER_CLOUDY, 0.70, 70.0, 14.0, 80.0],
	["gold_074_cloudy", SkyWeather3D.WEATHER_CLOUDY, 0.74, 70.0, 14.0, 80.0],
	["gold_077_cloudy", SkyWeather3D.WEATHER_CLOUDY, 0.77, 70.0, 14.0, 80.0],
]

var _out := DEFAULT_OUT
var _only := ""
var _deck := -2
var _bench := 0
var _decks: PackedStringArray = ["0", "1"]
var _ab := false
var _slab_cost := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.substr(7)
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--deck="):
			_deck = int(arg.substr(7))
		elif arg.begins_with("--bench="):
			_bench = int(arg.substr(8))
		elif arg.begins_with("--decks="):
			_decks = arg.substr(8).split(",")
		elif arg.begins_with("--slab-cost="):
			_slab_cost = int(arg.substr(12))
		elif arg == "--ab":
			_ab = true
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var plan := CityPlan.load_default()
	DisplayServer.window_set_size(SIZE)
	var view := CityMapView.create_city(plan)
	root.add_child(view)
	var camera: Camera3D = view.camera_3d() if view.has_method("camera_3d") else view._camera
	var sky: SkyWeather3D = view._sky_weather
	sky.auto_weather = false
	sky.time_scale = 0.0
	# Open ground south-west of the old town, 35 m up so roofs do not fill the frame.
	var ground := Vector2(-60, -200)
	var eye := Vector3(ground.x, plan.walk_height(ground) + 35.0, ground.y)
	for s in SHOTS:
		if not _only.is_empty() and not (s[0] in _only.split(",")):
			continue
		sky.set_weather(s[1])
		sky.advance(SkyWeather3D.TRANSITION_SECONDS + 0.1)
		sky.advance(17.0)
		view.apply_cycle_progress(s[2])
		var sun := SkyWeather3D.solar_direction(s[2], sky.calendar_date)
		var yaw := atan2(sun.x, sun.z) + deg_to_rad(s[3])
		var pitch := deg_to_rad(s[4])
		var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
		camera.fov = s[5]
		camera.far = 9000.0
		camera.near = 0.1
		camera.look_at_from_position(eye, eye + dir * 100.0, Vector3.UP)
		# Several frames so the sky radiance cubemap and screen passes settle.
		for i in 8:
			await process_frame
		if _slab_cost > 0:
			await _slab_cost_shot(s[0], sky)
			continue
		if _bench > 0:
			await _bench_shot(s[0], sky)
			continue
		if _ab:
			# Same run, same frames: the A/B differs only in the deck mode.
			for mode in _decks:
				await _capture(sky, int(mode), "%s_deck%s" % [s[0], mode], sun)
		else:
			await _capture(sky, _deck, s[0], sun)
	quit()


func _set_deck(sky: SkyWeather3D, deck: int) -> void:
	sky.set_cloud_deck_mode(deck)
	for i in (SLAB_SETTLE_FRAMES if deck == 2 else 4):
		await process_frame
	if deck == 2 and not sky.cloud_slab_active():
		push_warning("deck 2 requested but the slab pass is not running; plate shows the lit deck")


func _capture(sky: SkyWeather3D, deck: int, label: String, sun: Vector3) -> void:
	if deck > -2:
		await _set_deck(sky, deck)
	var image := root.get_texture().get_image()
	if image.get_size() != SIZE:
		image.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
	var path := ProjectSettings.globalize_path("%s/sky_reference_%s.png" % [_out, label])
	image.save_png(path)
	print("captured %s sun=%s" % [path, sun])


func _bench_shot(shot: String, sky: SkyWeather3D) -> void:
	var best := {}
	for round in 3:
		for mode in _decks:
			await _set_deck(sky, int(mode))
			for i in 10:
				await process_frame
			var start := Time.get_ticks_usec()
			for i in _bench:
				await process_frame
			var ms := float(Time.get_ticks_usec() - start) / 1000.0 / float(_bench)
			best[mode] = minf(float(best.get(mode, INF)), ms)
	var parts: PackedStringArray = []
	for mode in _decks:
		parts.append("deck%s=%.2f ms" % [mode, best[mode]])
	print("bench %s %dx%d: %s" % [shot, root.size.x, root.size.y, ", ".join(parts)])


func _slab_cost_shot(shot: String, sky: SkyWeather3D) -> void:
	await _set_deck(sky, 2)
	if not sky.cloud_slab_active():
		push_warning("slab pass not running; no cost to measure")
		return
	var size := Vector2i((root.size.x + 1) / 2, (root.size.y + 1) / 2)
	var ms: float = sky._cloud_slab.measure_local_gpu(size, _slab_cost)
	print("slab-cost %s %dx%d: %.3f ms per slab pass (march + resolve at %dx%d, best of %d)" % [
		shot, root.size.x, root.size.y, ms, size.x, size.y, _slab_cost])
