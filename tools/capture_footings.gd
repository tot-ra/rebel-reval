extends Node

## Review capture for the irregular wall footings (R-1933,
## docs/SYSTEMS/SEAMLESS_CITY.md): the forge street outside Kalev's smithy in
## the painted-iso gameplay camera (the smithy lean-to that read as a plank
## wall going straight into the dirt), a close oblique of that lean-to, the
## nearest log outbuilding (no footing before R-1933) and the plank house on
## the steepest ground nearby. Host scene so autoloads resolve:
##   tools/godot_render.sh --resolution 1600x900 res://tools/capture_footings.tscn \
##     -- --tag=after [--city-hour=10.5]
## Output: docs/reports/images/city/footing_<shot>_<tag>.jpg

const SCENE := preload("res://scenes/world/reval_city/reval_city.tscn")
const OUTPUT_DIR := "res://docs/reports/images/city"

var city: Node
var hour := 10.5


func _ready() -> void:
	call_deferred("_run")


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.trim_prefix(prefix)
	return fallback


## Holds the clock on the pinned hour every frame (a game day is 60 real seconds).
func _frames(n: int) -> void:
	for _i in n:
		if city != null and city.runtime != null:
			city.runtime.cycle_progress = hour / 24.0
		await get_tree().process_frame


## Same spot as capture_wall_foot.gd: the first open street cell round the hearth.
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


## Midpoint and outward normal of the longest south-facing edge of building
## `index` (the side the 10:30 sun lights).
func _sunny_edge(plan: CityPlan, index: int) -> Array:
	var ring := plan.footprint(index)
	var centre := Vector2.ZERO
	for p in ring:
		centre += p
	centre /= maxf(float(ring.size()), 1.0)
	var best := [centre, Vector2.DOWN]
	var best_len := -1.0
	for i in ring.size():
		var a := ring[i]
		var b := ring[(i + 1) % ring.size()]
		var n := (b - a).orthogonal().normalized()
		if n.dot((a + b) * 0.5 - centre) < 0.0:
			n = -n
		var length := a.distance_to(b) * (1.0 if n.y > 0.2 else 0.3)
		if length > best_len:
			best_len = length
			best = [(a + b) * 0.5, n]
	return best


## Nearest building to `at` matching `want` (a Callable on the record).
func _nearest(plan: CityPlan, at: Vector2, want: Callable) -> int:
	var best := -1
	var best_d := INF
	for index: int in plan.buildings_near(at, 160.0):
		if not want.call(plan.buildings[index]):
			continue
		var ring := plan.footprint(index)
		var d := ring[0].distance_to(at)
		if d < best_d:
			best_d = d
			best = index
	return best


## Oblique camera on the wall foot at `mid` (outward normal `n`).
func _frame_wall(plan: CityPlan, cam: Camera3D, mid: Vector2, n: Vector2, back: float) -> void:
	var foot := Vector3(mid.x, plan.ground_height(mid), mid.y)
	var eye := mid + n * back + n.orthogonal() * back * 0.4
	cam.global_position = Vector3(eye.x, plan.ground_height(eye) + back * 0.5, eye.y)
	cam.look_at(foot + Vector3(n.x, 0.4, n.y) * 0.6, Vector3.UP)


func _save(file: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("%s/%s.jpg" % [OUTPUT_DIR, file])
	get_viewport().get_texture().get_image().save_jpg(path, 0.9)
	print("saved ", path)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var tag := _arg("--tag=", "after")
	hour = float(_arg("--city-hour=", "10.5"))
	city = SCENE.instantiate()
	add_child(city)
	await _frames(120)
	var plan: CityPlan = city.plan
	var at := _forge_street(plan)
	city.player.global_position = CityPlan.to_logic(at)
	city.runtime.set_camera_mode(MapViewRuntimeCamera.CameraMode.PAINTED_ISO)
	await _frames(150)
	await _save("footing_iso_%s" % tag)
	var cam := Camera3D.new()
	city.world.add_child(cam)
	cam.fov = 55.0
	cam.make_current()
	# The smithy lean-to from the street, outside its open south-east corner.
	var site: CitySite = null
	for s in plan.sites:
		if s.id == &"site.kalev_smithy":
			site = s
	var shed_mid := site.to_world(Vector2(17.0, 4.0))
	var shed_eye := site.to_world(Vector2(23.5, -2.5))
	cam.global_position = Vector3(shed_eye.x, site.level + 2.6, shed_eye.y)
	cam.look_at(Vector3(shed_mid.x, site.level + 0.6, shed_mid.y), Vector3.UP)
	city.player.global_position = CityPlan.to_logic(site.to_world(Vector2(8.0, -6.0)))
	await _frames(40)
	await _save("footing_shed_%s" % tag)
	var outbuilding := _nearest(
		plan, at, func(b: Dictionary) -> bool: return not bool(b.get("openings", true))
	)
	var edge: Array = _sunny_edge(plan, outbuilding)
	print("outbuilding %s" % plan.buildings[outbuilding]["id"])
	_frame_wall(plan, cam, edge[0], edge[1], 5.0)
	city.player.global_position = CityPlan.to_logic(edge[0] + edge[1] * 9.0)
	await _frames(40)
	await _save("footing_outbuilding_%s" % tag)
	var sloped := -1
	var span := -1.0
	for index: int in plan.buildings_near(at, 120.0):
		var b: Dictionary = plan.buildings[index]
		if String(b["material"]) == "plank" and float(b["base_span"]) > span:
			span = float(b["base_span"])
			sloped = index
	print("sloped plank house %s span %.2f" % [plan.buildings[sloped]["id"], span])
	edge = _sunny_edge(plan, sloped)
	_frame_wall(plan, cam, edge[0], edge[1], 5.5)
	city.player.global_position = CityPlan.to_logic(edge[0] + edge[1] * 9.0)
	await _frames(40)
	await _save("footing_slope_%s" % tag)
	var log_house := _nearest(
		plan, at, func(b: Dictionary) -> bool:
			return String(b["material"]) == "log" and bool(b.get("openings", true))
	)
	edge = _sunny_edge(plan, log_house)
	_frame_wall(plan, cam, edge[0], edge[1], 4.5)
	city.player.global_position = CityPlan.to_logic(edge[0] + edge[1] * 9.0)
	await _frames(40)
	await _save("footing_log_%s" % tag)
	get_tree().quit(0)
