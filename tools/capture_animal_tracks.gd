extends SceneTree

## Plate: every city animal's prints side by side, one labelled lane per species,
## in settled January snow or soaked summer mud. Lanes are walked through the same
## call the city makes each frame (CityAnimalTracks.track via CityTrailFeed).
##   tools/godot_render.sh --script tools/capture_animal_tracks.gd [-- --mode=snow|mud]
## Output: build/season/animal_tracks_<mode>_<shot>.png

const OUTPUT_DIR := "res://build/season"
const VIEWPORT_SIZE := Vector2i(1600, 900)
const SPECIES: Array[StringName] = [
	&"horse", &"cow", &"pig", &"sheep", &"goat", &"dog", &"red_fox", &"cat", &"hare",
	&"rat", &"chicken", &"goose",
]
const LANE_GAP := 0.75
const LANE_LENGTH := 5.0

var _mode := "snow"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.substr(7)
	call_deferred("_run")


## Open, flat ground near the pasture closest to the centre (the area the
## snow-print plate uses), no building or tree near: deepest snow in January,
## bare earth in summer.
func _find_spot(plan: CityPlan, world: CityWorld3D, cover: float) -> Vector2:
	var focus := Vector2.ZERO
	var best := INF
	for f in CityFarmland.features_for(plan):
		if f["kind"] == &"pasture" and (f["centre"] as Vector2).length() < best:
			best = (f["centre"] as Vector2).length()
			focus = f["centre"]
	var pick := focus
	var best_score := -INF
	for dy in range(-240, 241, 4):
		for dx in range(-240, 241, 4):
			var p := focus + Vector2(dx, dy)
			if plan.slope_at(p) > 0.12 or not _clear(plan, p, 9.0):
				continue
			var score := CitySnow.depth_at(p, cover)
			if cover <= 0.0:
				# Mud needs bare earth: grass takes only a faint print and hides it.
				var s: Color = world.grass.surface_at(p)
				# Splat green is packed earth, alpha marsh mud: earth, well above the water.
				if s.g - s.r < 0.6 or plan.ground_height(p) < 1.5 or not _soft_around(world, p):
					continue
				score = -p.distance_to(focus)
			if score > best_score:
				best_score = score
				pick = p
	return pick


## Bare earth over the whole lane block, not just at its centre.
func _soft_around(world: CityWorld3D, at: Vector2) -> bool:
	for dy in range(-4, 5, 2):
		for dx in range(-3, 4, 3):
			var s: Color = world.grass.surface_at(at + Vector2(dx, dy))
			if s.g - s.r < 0.5:
				return false
	return true


func _clear(plan: CityPlan, at: Vector2, radius: float) -> bool:
	if plan.building_at(at) >= 0:
		return false
	for ring in [0.35, 0.7, 1.0]:
		for k in 12:
			var probe := at + Vector2.from_angle(float(k) / 12.0 * TAU) * radius * float(ring)
			if plan.building_at(probe) >= 0:
				return false
	for t: Array in plan.data.get("trees", []):
		if Vector2(float(t[0]), float(t[1])).distance_squared_to(at) < radius * radius:
			return false
	return true


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Animal track plates need a real renderer (tools/godot_render.sh)")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var plan := CityPlan.load_default()
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := CityWorld3D.create(plan)
	viewport.add_child(world)
	var camera := Camera3D.new()
	camera.far = 4000.0
	camera.near = 0.05
	viewport.add_child(camera)
	camera.current = true
	world.setup_lighting(camera)
	var snow := _mode == "snow"
	var date := {"year": 1343, "month": 1 if snow else 7, "day": 15}
	MapViewMaterials.apply_vegetation_season(date)
	world.apply_season(date)
	var wet := 0.0 if snow else 0.9
	var ground := CityTerrainBuilder.shared_material()
	var focus := _find_spot(plan, world, world.snow_cover)
	print("animal track plate spot ", focus, " cover ", world.snow_cover)
	# Kalev stands at the lanes' near end and does not move: only the animals print.
	var kalev := focus + Vector2(0.0, -float(SPECIES.size()) * LANE_GAP * 0.5 - 1.0)
	world.trail.update_for(kalev, 0.016)
	world.trail.wetness = wet
	for lane in SPECIES.size():
		var y := focus.y + (float(lane) - float(SPECIES.size() - 1) * 0.5) * LANE_GAP
		var start := Vector2(focus.x - LANE_LENGTH * 0.5, y)
		var pos := start
		for i in int(LANE_LENGTH / 0.05):
			pos += Vector2(0.05, 0.0)
			world.trail.update_for(kalev, 0.016)
			CityAnimalTracks.track(world.trail, lane, pos, SPECIES[lane])
		var label := Label3D.new()
		label.text = String(SPECIES[lane])
		label.font_size = 40
		label.pixel_size = 0.004
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(0.1, 0.1, 0.12) if snow else Color(1, 1, 0.92)
		label.outline_size = 8
		label.outline_modulate = Color(1, 1, 1, 0.6) if snow else Color(0, 0, 0, 0.7)
		var lift := CitySnow.depth_at(start, world.snow_cover)
		label.position = Vector3(start.x - 0.45, plan.ground_height(start) + lift + 0.15, y)
		world.add_child(label)
	var g := plan.ground_height(focus) + CitySnow.depth_at(focus, world.snow_cover)
	var shots := [
		["top", Vector3(focus.x - 0.4, g + 9.5, focus.y + 0.6), Vector3(focus.x - 0.4, g, focus.y), 55.0],
		["near", Vector3(focus.x - 1.0, g + 2.2, focus.y + 1.2), Vector3(focus.x + 0.4, g, focus.y - 1.6), 55.0],  # gdlint: ignore=max-line-length
	]
	for shot: Array in shots:
		camera.fov = shot[3]
		camera.look_at_from_position(shot[1], shot[2], Vector3.UP)
		for i in 40:
			world.apply_time(0.45)
			# apply_time pushes the live weather's wetness; the plate holds its own.
			world.trail.wetness = wet
			if ground != null:
				ground.set_shader_parameter("wetness", wet)
				ground.set_shader_parameter("puddles", wet * 0.4)
			world.grass.update_for(focus)
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/animal_tracks_%s_%s.png" % [OUTPUT_DIR, _mode, shot[0]]
		viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("animal track plate: ", path)
	quit(0)
