extends SceneTree

## R-1400 review captures of the discrete cloud cells over the seamless city:
## their ground shadows from the air and from above, cumulus seen from the street,
## a cumulonimbus with a cloud-to-ground stroke and an in-cloud flash, and sunbeams
## from behind a cell. Needs a renderer:
##   tools/godot_render.sh --script tools/capture_cloud_cells.gd [-- --only=<shot>[,<shot>...]]
## Output: docs/reports/images/weather/<shot>.png

const OUTPUT_DIR := "res://docs/reports/images/weather"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const CloudCellsScript := preload("res://scripts/map/view3d/cloud_cells.gd")
const AERIAL_EYE := Vector3(700, 380, -900)
const AERIAL_LOOK := Vector3(-80, 20, -150)

var _only := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.substr(7)
	call_deferred("_run")


func _wanted(shot: String) -> bool:
	return _only.is_empty() or shot in _only.split(",")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var plan := CityPlan.load_default()
	# WHY root, not a SubViewport: the ground shadow and god-ray passes composite
	# over the live framebuffer, which is only the real play path in the root
	# window (see tools/capture_ws12_cloud_shadows.gd).
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	var viewport: Viewport = root
	var view := CityMapView.create_city(plan)
	viewport.add_child(view)
	var camera: Camera3D = view.camera_3d() if view.has_method("camera_3d") else view._camera
	var sky: SkyWeather3D = view._sky_weather
	sky.auto_weather = false
	sky.time_scale = 0.0

	if _wanted("cells_aerial_clear"):
		await _settle(view, sky, SkyWeather3D.WEATHER_CLEAR, 0.42)
		await _shot(viewport, camera, "cells_aerial_clear", AERIAL_EYE, AERIAL_LOOK, 50.0)
	if _wanted("cells_aerial_cloudy"):
		await _settle(view, sky, SkyWeather3D.WEATHER_CLOUDY, 0.42)
		await _shot(viewport, camera, "cells_aerial_cloudy", AERIAL_EYE, AERIAL_LOOK, 50.0)
	if _wanted("cells_topdown_shadow"):
		await _settle(view, sky, SkyWeather3D.WEATHER_CLOUDY, 0.42)
		var edge := _shadow_edge_point(sky, CloudCellsScript.KIND_CUMULUS)
		await _shot(viewport, camera, "cells_topdown_shadow", edge + Vector3(0, 260, 1), edge, 60.0)
	if _wanted("cells_street_cumulus"):
		await _settle(view, sky, SkyWeather3D.WEATHER_CLOUDY, 0.42)
		var cell := _strongest(sky, CloudCellsScript.KIND_CUMULUS)
		var target := _near_copy(sky.cloud_cells().centers[cell], Vector3(-60, 0, -200))
		await _shot(viewport, camera, "cells_street_cumulus", Vector3(-60, 30, -200), target, 70.0)
	if _wanted("cells_storm_ground_stroke") or _wanted("cells_storm_in_cloud"):
		await _settle(view, sky, SkyWeather3D.WEATHER_STORM, 0.40)
		var slot := _strongest(sky, CloudCellsScript.KIND_STORM)
		var cells = sky.cloud_cells()
		var eye := Vector3(-60, 30, -200)
		var center := _near_copy(cells.centers[slot], eye, CloudCellsScript.KIND_STORM)
		# Stand ~6 km off: storm cells are kilometres wide.
		var away := Vector3(eye.x - center.x, 0, eye.z - center.z).normalized()
		eye = Vector3(center.x, 30, center.z) + away * 6500.0
		var look := Vector3(center.x, 1000, center.z)
		for kind in [SkyWeather3D.LIGHTNING_KIND_GROUND, SkyWeather3D.LIGHTNING_KIND_CLOUD]:
			var ground_stroke: bool = kind == SkyWeather3D.LIGHTNING_KIND_GROUND
			var shot := "cells_storm_ground_stroke" if ground_stroke else "cells_storm_in_cloud"
			if not _wanted(shot):
				continue
			camera.look_at_from_position(eye, look, Vector3.UP)
			await process_frame
			sky._place_strike(slot)
			sky._lightning_kind = kind
			if kind == SkyWeather3D.LIGHTNING_KIND_GROUND:
				var c: Vector3 = cells.centers[slot]
				sky._lightning_origin.y = c.y + cells.heights[slot] * 0.08
			sky._lightning_time = 0.03
			sky.advance(0.0)
			await _shot(viewport, camera, shot, eye, look, 62.0)
			sky._lightning_time = -1.0
			sky._lightning = 0.0
	if _wanted("cells_storm_rain_under") or _wanted("cells_storm_rain_away"):
		# R-1400 follow-up: storm rain falls only inside a cell's shaft. One street
		# view; the cloud drift is shifted so the strongest cumulonimbus sits over the
		# camera, then 3 km east of it. Cells are a pure function of the drift.
		await _settle(view, sky, SkyWeather3D.WEATHER_STORM, 0.40)
		var slot := _strongest(sky, CloudCellsScript.KIND_STORM)
		var street := Vector2(-60, -200)
		# Just above the roofs, so the plate shows rain against the town, not a wall.
		var eye := Vector3(street.x, plan.walk_height(street) + 16.0, street.y)
		var look := eye + Vector3(-20, -9, -60)
		var shifts := {"cells_storm_rain_under": 0.0, "cells_storm_rain_away": 3000.0}
		for shot: String in shifts:
			if not _wanted(shot):
				continue
			var c: Vector3 = sky.cloud_cells().centers[slot]
			var to_eye := CloudCellsScript.wrap_delta(
				Vector2(eye.x + float(shifts[shot]), eye.z), Vector2(c.x, c.z),
				CloudCellsScript.KIND_STORM
			)
			sky._cloud_offset += to_eye / CloudCellsScript.METRES_PER_UV
			camera.look_at_from_position(eye, look, Vector3.UP)
			sky.advance(0.0)
			print("%s local rain %.2f emitter %s" % [
				shot, sky.local_rain_factor(), sky.rain_emitter_visible()
			])
			# Let the particles fill the air before the plate.
			for i in 60:
				await process_frame
			await _shot(viewport, camera, shot, eye, look, 70.0)
	if _wanted("cells_harbour_shadow"):
		# R-1400 follow-up: the water dims its own sun under a cell, so one cloud
		# shadow continues from the shore across the sea instead of stopping at it.
		await _settle(view, sky, SkyWeather3D.WEATHER_CLOUDY, 0.42)
		# Walk the cell clock in fixed steps until a shadow straddles the coast
		# (deterministic: same plan and weather give the same frame).
		var shore := _shore_shadow_point(sky, plan)
		for step in 120:
			if shore.y == 0.0:
				break
			sky.advance(10.0)
			shore = _shore_shadow_point(sky, plan)
		shore.y = 0.0
		for i in 3:
			await process_frame
		await _shot(viewport, camera, "cells_harbour_shadow", shore + Vector3(0, 420, 520), shore, 55.0)
	if _wanted("cells_sunbeams"):
		await _settle(view, sky, SkyWeather3D.WEATHER_CLOUDY, 0.30)
		var sun := SkyWeather3D.solar_direction(0.30, sky.calendar_date)
		var cell := _strongest(sky, CloudCellsScript.KIND_CUMULUS)
		var cells = sky.cloud_cells()
		var c: Vector3 = cells.centers[cell]
		var layer: float = c.y + cells.heights[cell] * 0.35
		# Stand just outside the cell's shadow so its edge sits on the sun.
		var under := Vector3(c.x, 0, c.z) - Vector3(sun.x, 0, sun.z) / maxf(sun.y, 0.15) * layer
		var side: Vector3 = Vector3(sun.z, 0, -sun.x).normalized() * float(cells.radii[cell]) * 0.9
		var eye := _near_copy(under + side, Vector3(-60, 0, -200)) + Vector3(0, 30, 0)
		await _shot(viewport, camera, "cells_sunbeams", eye, eye + sun * 100.0, 75.0)
	quit(0)


func _settle(view: CityMapView, sky: SkyWeather3D, weather: StringName, progress: float) -> void:
	sky.set_weather(weather)
	sky.advance(SkyWeather3D.TRANSITION_SECONDS + 0.1)
	# Walk the cell clock into a frame where cells of this weather are well grown.
	sky.advance(17.0)
	view.apply_cycle_progress(progress)
	for i in 3:
		await process_frame


func _shot(
	viewport: Viewport, camera: Camera3D, shot: String, eye: Vector3, look: Vector3, fov: float
) -> void:
	camera.fov = fov
	camera.far = 9000.0
	# Aerial plates sit ~1 km from the ground; the gameplay near plane (0.08) leaves
	# too little depth precision there for the shadow pass to rebuild positions.
	camera.near = 0.08 if eye.y < 120.0 else 1.0
	var vertical := absf((look - eye).normalized().y) >= 0.99
	camera.look_at_from_position(eye, look, Vector3.FORWARD if vertical else Vector3.UP)
	for i in 6:
		await process_frame
	var path := "%s/%s.png" % [OUTPUT_DIR, shot]
	var image := viewport.get_texture().get_image()
	# HiDPI windows render above the requested size; evidence plates are 1280x720
	# (docs/ASSET_STORAGE_POLICY.md).
	if image.get_size() != VIEWPORT_SIZE:
		image.resize(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	image.save_png(ProjectSettings.globalize_path(path))
	print("captured %s" % path)


func _strongest(sky: SkyWeather3D, kind: int) -> int:
	var cells = sky.cloud_cells()
	var best := 0
	var best_w := -1.0
	for slot in CloudCellsScript.SLOTS:
		if CloudCellsScript.kind_of(slot) == kind and cells.weights[slot] > best_w:
			best_w = cells.weights[slot]
			best = slot
	print("strongest kind %d slot %d weight %.2f" % [kind, best, best_w])
	return best


## Copy of wrapped cell position `c` nearest to `near` (ground y unchanged).
func _near_copy(c: Vector3, near: Vector3, kind: int = 0) -> Vector3:
	var d := CloudCellsScript.wrap_delta(Vector2(c.x, c.z), Vector2(near.x, near.z), kind)
	return Vector3(near.x + d.x, c.y, near.z + d.y)


## Sea point under a cloud-cell shadow that also covers land within 250 m, nearest
## the town, so one plate shows the shadow crossing the waterline.
func _shore_shadow_point(sky: SkyWeather3D, plan: CityPlan) -> Vector3:
	var cells = sky.cloud_cells()
	var sun := SkyWeather3D.solar_direction(0.42, sky.calendar_date)
	var town := Vector2(-60, -200)
	# y = 1 flags "not found" for the caller's search loop.
	var best := Vector3(town.x, 1, town.y)
	var best_d := INF
	# Inset from the plan edge: past it the terrain skirt and OpenSea do not meet
	# along a real coast.
	var r := plan.bounds.grow(-150.0)
	for j in int(r.size.y / 40.0):
		for i in int(r.size.x / 40.0):
			var p := r.position + Vector2(i, j) * 40.0
			if not _is_sea(plan, p) or cells.shadow_at(Vector3(p.x, 0, p.y), sun) < 0.6:
				continue
			for k in 8:
				var q := p + Vector2.from_angle(TAU * k / 8.0) * 250.0
				if not _is_sea(plan, q) and plan.ground_height(q) > 0.5 \
						and cells.shadow_at(Vector3(q.x, 0, q.y), sun) > 0.6:
					var d := p.distance_to(town)
					if d < best_d:
						best_d = d
						best = Vector3(p.x, 0, p.y)
					break
	print("harbour shadow at %s (%.0f m from town centre)" % [best, best_d])
	return best


func _is_sea(plan: CityPlan, p: Vector2) -> bool:
	return plan.ground_height(p) < -0.5


## Ground point on the shadow edge of the grown cell of `kind` whose shadow falls
## nearest the town centre, so the plate shows a shadow edge on roofs, not sea.
func _shadow_edge_point(sky: SkyWeather3D, kind: int) -> Vector3:
	var cells = sky.cloud_cells()
	var sun := SkyWeather3D.solar_direction(0.42, sky.calendar_date)
	var town := Vector3(-60, 0, -200)
	var best := town
	var best_d := INF
	for slot in CloudCellsScript.SLOTS:
		if CloudCellsScript.kind_of(slot) != kind or cells.weights[slot] < 0.8:
			continue
		var c: Vector3 = cells.centers[slot]
		var layer: float = c.y + cells.heights[slot] * 0.35
		var under := Vector3(c.x, 0, c.z) - Vector3(sun.x, 0, sun.z) / maxf(sun.y, 0.15) * layer
		under = _near_copy(under, town, kind)
		var edge := Vector3(under.x + cells.radii[slot] * 0.9, 0, under.z)
		var d := Vector2(edge.x - town.x, edge.z - town.z).length()
		if d < best_d:
			best_d = d
			best = edge
	print("topdown edge %s (%.0f m from town centre)" % [best, best_d])
	return best
