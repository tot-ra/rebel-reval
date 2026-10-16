extends Node

## Review capture for door stairs (R-2197, docs/SYSTEMS/SEAMLESS_CITY.md): the
## two St Catherine's houses whose doors moved uphill, then the first house of
## every other stair kind (side flight, splayed, straight, timber, slab), with
## Kalev standing on a tread so the plate shows he climbs it. Host scene so
## autoloads resolve:
##   tools/godot_render.sh --resolution 1600x900 res://tools/capture_door_steps.tscn \
##     -- --tag=after [--city-hour=10.5]
## Output: docs/reports/images/city/door_steps_<shot>_<tag>.jpg

const SCENE := preload("res://scenes/world/reval_city/reval_city.tscn")
const OUTPUT_DIR := "res://docs/reports/images/city"
const NAMED := ["bldg.osm.w26902721", "bldg.osm.w28187544"]

var city: Node
var hour := 10.5


func _ready() -> void:
	call_deferred("_run")


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.trim_prefix(prefix)
	return fallback


func _frames(n: int) -> void:
	for _i in n:
		if city != null and city.runtime != null:
			city.runtime.cycle_progress = hour / 24.0
		await get_tree().process_frame


func _save(file: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("%s/%s.jpg" % [OUTPUT_DIR, file])
	get_viewport().get_texture().get_image().save_jpg(path, 0.9)
	print("plate: ", path)


## Buildings to shoot: the named ones, then the first of each remaining kind.
func _targets(plan: CityPlan) -> Array:
	var out: Array = []
	var seen := {}
	for i in plan.buildings.size():
		if String(plan.buildings[i]["id"]) in NAMED:
			out.append([i, "catherine_%d" % out.size()])
	for i in plan.buildings.size():
		var steps := plan.door_steps(i)
		if steps.is_empty() or (steps["treads"] as Array).is_empty():
			continue
		var kind := StringName(CityDoorSteps.KIND_NAMES[int(steps["kind"])])
		var key := "%s_%s" % [kind, "wood" if bool(steps["wood"]) else "stone"]
		if seen.has(key) or String(plan.buildings[i]["id"]) in NAMED:
			continue
		seen[key] = true
		out.append([i, key])
	return out


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var tag := _arg("--tag=", "after")
	hour = float(_arg("--city-hour=", "10.5"))
	city = SCENE.instantiate()
	add_child(city)
	await _frames(120)
	var plan: CityPlan = city.plan
	var cam := Camera3D.new()
	city.world.add_child(cam)
	cam.fov = 55.0
	for target: Array in _targets(plan):
		var index := int(target[0])
		var steps := plan.door_steps(index)
		var treads: Array = steps["treads"]
		var door: Array = plan.buildings[index]["door"]
		var at := Vector2(door[0], door[1])
		var out := Vector2.from_angle(float(door[2]))
		# Kalev on the middle tread; the camera out in the street and to one side.
		var stand: Vector2 = treads[treads.size() / 2]["c"]
		city.player.global_position = CityPlan.to_logic(stand)
		var centre := (at + (treads.back()["c"] as Vector2)) * 0.5
		var back := 6.5 if int(steps["kind"]) == CityDoorSteps.Kind.SIDE else 5.0
		# First open-ground eye: either side, then closer in (rows are tight).
		var eye := centre + out * back
		var found := false
		for dist: float in [back, back * 0.75, back * 0.5, 2.5]:
			for side: float in [0.45, -0.45, 0.0]:
				var p := centre + out * dist + out.orthogonal() * dist * side
				if not found and plan.building_at(p) < 0 and plan.site_at(p) == null:
					eye = p
					found = true
		var floor_y := plan.floor_height(index)
		cam.make_current()
		cam.global_position = Vector3(eye.x, maxf(plan.ground_height(eye) + 1.7, floor_y + 0.6), eye.y)
		cam.look_at(Vector3(centre.x, floor_y - 0.3, centre.y), Vector3.UP)
		await _frames(45)
		print(
			"%s %s kind=%s treads=%d walk=%.2f tread=%.2f" % [
				target[1], plan.buildings[index]["id"],
				CityDoorSteps.KIND_NAMES[int(steps["kind"])], treads.size(),
				plan.walk_height(stand), float(treads[treads.size() / 2]["top"])
			]
		)
		await _save("door_steps_%s_%s" % [target[1], tag])
	get_tree().quit(0)
