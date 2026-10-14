extends Node

## Review capture for the wall-foot band on the city ground (R-1930,
## docs/SYSTEMS/SEAMLESS_CITY.md): the forge street outside Kalev's smithy in
## the painted-iso gameplay camera (plank wall and plinth house next to Kalev),
## plus a close oblique of the nearest wall foot and (R-1931) an oblique of the
## steepest south-facing wall foot nearby, so the wall-side band can be checked
## on a sloped street. R-1932 adds a busy-street shot (a wall beside the most
## worn cart road nearby) for the 3D wall-foot scatter; --no-scatter hides
## CityWallFootScatter for the matching "before" plate. Host scene so autoloads
## resolve:
##   tools/godot_render.sh --resolution 1600x900 res://tools/capture_wall_foot.tscn \
##     -- --tag=after [--city-hour=10.5] [--no-scatter]
## Output: docs/reports/images/city/wall_foot_<shot>_<tag>.jpg

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


## Same spot as capture_city_painted_iso.gd "forge": the first open street cell
## round the smithy hearth.
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


## Midpoint and outward normal of the sunlit footprint edge nearest to `at`.
func _nearest_wall(plan: CityPlan, at: Vector2) -> Array:
	var best := [at, Vector2.RIGHT]
	var best_d := INF
	for index: int in plan.buildings_near(at, 30.0):
		var ring := plan.footprint(index)
		var centre := Vector2.ZERO
		for p in ring:
			centre += p
		centre /= maxf(float(ring.size()), 1.0)
		for i in ring.size():
			var a := ring[i]
			var b := ring[(i + 1) % ring.size()]
			if a.distance_to(b) < 2.5:
				continue
			var mid := (a + b) * 0.5
			var d := mid.distance_to(at)
			var n := (b - a).orthogonal().normalized()
			if n.dot(mid - centre) < 0.0:
				n = -n
			# South-facing walls only (+z is south), so the foot is in sunlight.
			if d < best_d and n.y > 0.5:
				best_d = d
				best = [mid, n]
	return best


## R-1931: midpoint and outward normal of the south-facing footprint edge within
## 120 m of `at` whose ground falls the most along it (a sloped street).
func _sloped_wall(plan: CityPlan, at: Vector2) -> Array:
	var best := [at, Vector2.DOWN]
	var best_drop := -1.0
	for index: int in plan.buildings_near(at, 120.0):
		var ring := plan.footprint(index)
		var centre := Vector2.ZERO
		for p in ring:
			centre += p
		centre /= maxf(float(ring.size()), 1.0)
		for i in ring.size():
			var a := ring[i]
			var b := ring[(i + 1) % ring.size()]
			if a.distance_to(b) < 5.0:
				continue
			var n := (b - a).orthogonal().normalized()
			if n.dot((a + b) * 0.5 - centre) < 0.0:
				n = -n
			if n.y < 0.5 or plan.site_at((a + b) * 0.5 + n * 2.0) != null:
				continue
			var drop := absf(plan.ground_height(a + n * 0.6) - plan.ground_height(b + n * 0.6))
			if drop > best_drop:
				best_drop = drop
				best = [(a + b) * 0.5, n]
	print("sloped wall drop %.2f m at %s" % [best_drop, best[0]])
	return best


## R-1932: midpoint and outward normal of the long footprint edge within 120 m
## of `at` that fronts the most worn cart road (roads.png B), 1.5-4.5 m out.
func _busy_wall(plan: CityPlan, at: Vector2) -> Array:
	var grass: CityGrass = city.world.grass
	var best := [at, Vector2.DOWN]
	var best_wear := -1.0
	for index: int in plan.buildings_near(at, 120.0):
		var ring := plan.footprint(index)
		for i in ring.size():
			var a := ring[i]
			var b := ring[(i + 1) % ring.size()]
			if a.distance_to(b) < 5.0:
				continue
			var n := (b - a).orthogonal().normalized()
			var mid := (a + b) * 0.5
			if Geometry2D.is_point_in_polygon(mid + n * 0.1, ring):
				n = -n
			# Cart roads keep a verge off the wall: probe a few metres out.
			for out: float in [1.5, 3.0, 4.5]:
				var road := grass.road_at(mid + n * out)
				if road.r > 0.2 and road.b > best_wear:
					best_wear = road.b
					best = [mid, n]
	print("busy wall wear %.2f at %s" % [best_wear, best[0]])
	return best


## Oblique camera on the wall foot at `mid` (outward normal `n`).
func _frame_wall(plan: CityPlan, cam: Camera3D, mid: Vector2, n: Vector2, back: float) -> void:
	var foot := Vector3(mid.x, plan.ground_height(mid), mid.y)
	var eye := mid + n * back + n.orthogonal() * back * 0.4
	cam.global_position = Vector3(eye.x, plan.ground_height(eye) + back * 0.7, eye.y)
	cam.look_at(foot + Vector3(n.x, 0.0, n.y) * 0.6, Vector3.UP)


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
	if "--no-scatter" in OS.get_cmdline_user_args():
		city.world.grass.wall_foot.visible = false
	var plan: CityPlan = city.plan
	var at := _forge_street(plan)
	city.player.global_position = CityPlan.to_logic(at)
	city.runtime.set_camera_mode(MapViewRuntimeCamera.CameraMode.PAINTED_ISO)
	await _frames(150)
	await _save("wall_foot_iso_%s" % tag)
	var scatter: CityWallFootScatter = city.world.grass.wall_foot
	var counts := PackedStringArray()
	for kind: StringName in CityWallFootScatter.ALL_KINDS:
		counts.append("%s=%d" % [kind, scatter.instance_count(kind)])
	print("wall-foot scatter: ", ", ".join(counts))
	# Close oblique of the nearest wall foot, Kalev stepped aside.
	var wall: Array = _nearest_wall(plan, at)
	var mid: Vector2 = wall[0]
	var n: Vector2 = wall[1]
	var cam := Camera3D.new()
	city.world.add_child(cam)
	var foot := Vector3(mid.x, plan.ground_height(mid), mid.y)
	var eye2 := mid + n * 3.2 + n.orthogonal() * 1.2
	cam.global_position = Vector3(eye2.x, plan.ground_height(eye2) + 2.2, eye2.y)
	cam.look_at(foot + Vector3(n.x, 0.0, n.y) * 0.6, Vector3.UP)
	cam.fov = 55.0
	cam.make_current()
	city.player.global_position = CityPlan.to_logic(at + n.orthogonal() * 8.0)
	await _frames(30)
	await _save("wall_foot_close_%s" % tag)
	var slope: Array = _sloped_wall(plan, at)
	_frame_wall(plan, cam, slope[0], slope[1], 6.0)
	city.player.global_position = CityPlan.to_logic(slope[0] + slope[1] * 4.0)
	await _frames(60)
	await _save("wall_foot_slope_%s" % tag)
	var busy: Array = _busy_wall(plan, at)
	_frame_wall(plan, cam, busy[0], busy[1], 6.0)
	city.player.global_position = CityPlan.to_logic(busy[0] + busy[1] * 4.0)
	await _frames(60)
	await _save("wall_foot_busy_%s" % tag)
	get_tree().quit(0)
