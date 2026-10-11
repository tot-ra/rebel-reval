extends Node

## Review capture for moss, lichen and the forest floor (R-1661,
## docs/SYSTEMS/VEGETATION_REALISM.md): the north side of a mossy trunk with a
## tinder bracket, the north wall of a stone house and the shaded ground strip
## in front of it, and the woods floor in April (false morels) and August
## (chanterelle, porcini, fly agaric). Host scene so autoloads resolve:
##   tools/godot_render.sh --resolution 1600x900 res://tools/capture_city_moss.tscn
## Append `-- --walls` to stop after the wall shots.
## Output: docs/reports/images/vegetation/r1661_<shot>.png

const SCENE := preload("res://scenes/world/reval_city/reval_city.tscn")
const OUTPUT_DIR := "res://docs/reports/images/vegetation"

var city: Node
var cam: Camera3D


func _ready() -> void:
	call_deferred("_run")


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _shot(at: Vector2, eye: Vector3, target: Vector3, file: String, fov := 55.0) -> void:
	city.player.global_position = CityPlan.to_logic(at)
	city.runtime.cycle_progress = 0.5
	await _frames(90)
	# Step Kalev out of frame; the streamed chunks round the spot stay loaded.
	city.player.global_position = CityPlan.to_logic(at + Vector2(14.0, 14.0))
	await _frames(6)
	cam.global_position = eye
	cam.look_at(target, Vector3.UP)
	cam.fov = fov
	cam.make_current()
	await _frames(4)
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT_DIR, file])
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	city = SCENE.instantiate()
	add_child(city)
	await _frames(120)
	var plan: CityPlan = city.plan
	cam = Camera3D.new()
	city.world.add_child(cam)
	var forest := city.world.get_node("Dressing/ForestFloor") as CityForestFloor
	forest.set_day_of_year(111)
	var placed := forest.placements()
	# 1. North side of a birch carrying a tinder bracket: camera north of the trunk.
	for entry: Array in placed:
		if entry[0] == CityForestFloor.KIND_BRACKET:
			var o: Vector3 = (entry[1] as Transform3D).origin
			var p := Vector2(o.x, o.z)
			var ground := plan.ground_height(p)
			await _shot(p, Vector3(o.x + 0.5, ground + 1.5, o.z - 1.8), Vector3(o.x, ground + 1.0, o.z),
				"r1661_tree_north_moss", 60.0)
			break
	# 2-3. North wall of a stone house and the shaded strip in front of it.
	for index: int in plan.buildings_near(Vector2(-60.0, -40.0), 2000.0):
		var b: Dictionary = plan.buildings[index]
		if String(b.get("material", "")) != "limestone" or String(b.get("landmark_id", "")) != "":
			continue
		var ring := plan.footprint(index)
		var lo := ring[0]
		var hi := ring[0]
		for q in ring:
			lo = lo.min(q)
			hi = hi.max(q)
		var mid := Vector2((lo.x + hi.x) * 0.5, lo.y)
		var probe := mid + Vector2(0.0, -4.0)
		if plan.buildings_near(probe, 1.0).size() > 0:
			continue  # another house stands in front: no view of the wall
		var ground := plan.ground_height(mid)
		await _shot(probe, Vector3(mid.x + 2.0, ground + 1.7, mid.y - 6.0),
			Vector3(mid.x, ground + 1.0, mid.y), "r1661_wall_north_moss")
		await _shot(probe, Vector3(mid.x - 4.0, ground + 7.0, mid.y - 11.0),
			Vector3(mid.x, ground, mid.y - 2.5), "r1661_shaded_ground")
		# Close-up of the moss plate at the foot of the wall (eye height of a
		# crouching player, 1.6 m off the face).
		await _shot(probe, Vector3(mid.x + 0.6, ground + 0.9, mid.y - 1.6),
			Vector3(mid.x - 0.4, ground + 0.35, mid.y), "r1661_wall_moss_closeup", 60.0)
		break
	if "--walls" in OS.get_cmdline_user_args():
		get_tree().quit(0)
		return
	# 4-5. Woods floor: a false morel troop in April, then the same wood in August.
	for kind: StringName in [CityForestFloor.KIND_GYROMITRA, CityForestFloor.KIND_CHANTERELLE]:
		var day := 111 if kind == CityForestFloor.KIND_GYROMITRA else 230
		forest.set_day_of_year(day)
		for entry: Array in placed:
			if entry[0] != kind:
				continue
			var o: Vector3 = (entry[1] as Transform3D).origin
			var p := Vector2(o.x, o.z)
			await _shot(p, Vector3(o.x + 1.4, o.y + 1.3, o.z + 1.6), o + Vector3(0, 0.05, 0),
				"r1661_forest_floor_%s" % ("april" if day == 111 else "august"), 50.0)
			await _shot(p, Vector3(o.x + 7.0, o.y + 2.2, o.z + 8.0), o,
				"r1661_woods_%s" % ("april" if day == 111 else "august"), 60.0)
			break
	get_tree().quit(0)
