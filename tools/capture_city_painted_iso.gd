extends Node

## Review capture for the painted-iso camera preset (R-1744, docs/CONTROLS.md):
## stands Kalev on Raekoja plats and in the forge street outside Kalev's smithy
## at a pinned hour and saves the gameplay frame in third person (before) and in
## painted iso (after), plus a roof-cutaway proof with Kalev standing right
## behind a house as seen from the lens. Host scene so autoloads resolve:
##   tools/godot_render.sh --resolution 1600x900 res://tools/capture_city_painted_iso.tscn \
##     [-- --city-hour=10.5]
## Output: docs/reports/images/city/painted_iso_<spot>_<mode>.jpg

const SCENE := preload("res://scenes/world/reval_city/reval_city.tscn")
const OUTPUT_DIR := "res://docs/reports/images/city"

var city: Node


func _ready() -> void:
	call_deferred("_run")


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.trim_prefix(prefix)
	return fallback


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


## The smithy spawn stands at the hearth; walk outward to the first open street
## cell so the capture shows the forge from the lane in front of it.
func _forge_street(plan: CityPlan) -> Vector2:
	var hearth := CityTravel.spawn_position(plan, "kalev_smithy")
	var view: CityMapView = city.view
	for radius: float in [6.0, 8.0, 10.0, 12.0, 15.0, 18.0]:
		for step in 16:
			var angle := TAU * float(step) / 16.0
			var p := hearth + Vector2(cos(angle), sin(angle)) * radius
			if plan.site_at(p) != null:
				continue
			var y := plan.ground_height(p)
			if not view.is_point_inside_occluder(Vector3(p.x, y + 1.0, p.y)):
				return p
	return hearth


## A street point just past a house on the far side from the iso lens, so its
## roof stands between the camera and Kalev and the cutaway has to open it.
func _behind_house(plan: CityPlan, near: Vector2) -> Vector2:
	var view: CityMapView = city.view
	var camera := view.view_camera()
	var forward := -camera.global_transform.basis.z
	var away := Vector2(forward.x, forward.z).normalized()
	var picks := plan.buildings_near(near, 120.0)
	picks.sort_custom(func(a: int, b: int) -> bool:
		return _centre(plan, a).distance_to(near) < _centre(plan, b).distance_to(near))
	for index: int in picks:
		var centre := _centre(plan, index)
		var reach := 0.0
		for p in plan.footprint(index):
			reach = maxf(reach, (p - centre).dot(away))
		var spot := centre + away * (reach + 1.2)
		if plan.site_at(spot) != null:
			continue
		if not view.is_point_inside_occluder(Vector3(spot.x, plan.ground_height(spot) + 1.0, spot.y)):
			return spot
	return near


func _centre(plan: CityPlan, index: int) -> Vector2:
	var ring := plan.footprint(index)
	var c := Vector2.ZERO
	for p in ring:
		c += p
	return c / maxf(float(ring.size()), 1.0)


func _shot(at: Vector2, spot: String, hour: float, iso_only := false) -> void:
	var runtime: MapViewRuntime = city.runtime
	city.player.global_position = CityPlan.to_logic(at)
	var modes: Array = [[MapViewRuntimeCamera.CameraMode.PAINTED_ISO, "iso"]]
	if not iso_only:
		modes.push_front([MapViewRuntimeCamera.CameraMode.THIRD_PERSON, "third"])
	for mode: Array in modes:
		runtime.cycle_progress = hour / 24.0
		runtime.set_camera_mode(mode[0])
		# Streaming, the follow glide and the shadow range all settle first.
		await _frames(150)
		await RenderingServer.frame_post_draw
		var path := ProjectSettings.globalize_path(
			"%s/painted_iso_%s_%s.jpg" % [OUTPUT_DIR, spot, mode[1]]
		)
		get_viewport().get_texture().get_image().save_jpg(path, 0.88)
		print("saved ", path)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	city = SCENE.instantiate()
	add_child(city)
	await _frames(120)
	var plan: CityPlan = city.plan
	var hour := float(_arg("--city-hour=", "10.5"))
	var forum := CityTravel.spawn_position(plan, "poi.forum")
	await _shot(forum, "forum", hour)
	await _shot(_forge_street(plan), "forge", hour)
	await _shot(_behind_house(plan, forum), "cutaway", hour, true)
	get_tree().quit(0)
