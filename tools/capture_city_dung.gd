extends Node

## Plates for animal dung (R-2077, docs/SYSTEMS/ANIMAL_DUNG.md) in the running
## seamless city: Kalev stands at the densest stretch of cow pats on a drove
## road, a manure heap, horse dung and sheep pellets; each stop is shot through
## the game camera and close up. Exits 1 when a kind has nothing on the ground.
##   tools/godot_render.sh --resolution 1600x900 res://tools/capture_city_dung.tscn [-- --date=7-15]
## Output: build/season/dung_<month>_<day>_<stop>[_near].png

const SCENE := preload("res://scenes/world/reval_city/reval_city.tscn")
const OUTPUT_DIR := "res://build/season"
const SETTLE_SEC := 4.0
const CLUSTER_RADIUS := 10.0

var _date := {"year": 1343, "month": 7, "day": 15}
var _failures: Array[String] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--date="):
			var md := arg.substr(7).split("-")
			_date = {"year": 1343, "month": int(md[0]), "day": int(md[1])}
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var city: Node = SCENE.instantiate()
	get_tree().root.add_child(city)
	await get_tree().process_frame
	await get_tree().process_frame
	city.view.set_calendar_date(_date)
	var dung: CityDung = city.world.get_node("CityDung")
	var tag := "%d_%d" % [_date["month"], _date["day"]]
	for stop: Array in [
		["road", CityDung.KIND_COW_PAT], ["heap", CityDung.KIND_HEAP],
		["horse", CityDung.KIND_HORSE], ["pellets", CityDung.KIND_PELLETS],
	]:
		var at := _densest(dung, stop[1], city.plan if stop[0] == "road" else null)
		if at == Vector3.INF:
			_failures.append(stop[0])
			continue
		var xz := Vector2(at.x, at.z)
		city.player.global_position = CityPlan.to_logic(xz + Vector2(0.0, 2.5))
		city.player.velocity = Vector2.ZERO
		await _settle(SETTLE_SEC)
		_save("%s/dung_%s_%s.png" % [OUTPUT_DIR, tag, stop[0]])
		# Close up from a hand-held camera, then back to the game camera.
		var game_camera := get_viewport().get_camera_3d()
		var near := Camera3D.new()
		near.fov = 50.0
		near.near = 0.03
		city.world.add_child(near)
		var reach := 1.4 if stop[1] == CityDung.KIND_PELLETS else 2.6
		near.look_at_from_position(at + Vector3(0.5, reach * 0.75, reach), at, Vector3.UP)
		near.make_current()
		await _settle(0.5)
		_save("%s/dung_%s_%s_near.png" % [OUTPUT_DIR, tag, stop[0]])
		near.queue_free()
		if game_camera != null:
			game_camera.make_current()
	get_tree().quit(1 if not _failures.is_empty() else 0)


## Centre of the shown instance of `kind` with the most neighbours of its kind.
## With `on_streets`, only instances on a drove street count (the road plate).
func _densest(dung: CityDung, kind: StringName, on_streets: CityPlan = null) -> Vector3:
	var spots: Array[Vector3] = []
	for entry: Array in dung.placements():
		var o := (entry[1] as Transform3D).origin
		if entry[0] == kind and (on_streets == null or _on_street(on_streets, Vector2(o.x, o.z))):
			spots.append(o)
	var best := Vector3.INF
	var best_n := -1
	for p in spots:
		var n := 0
		for q in spots:
			if Vector2(p.x, p.z).distance_squared_to(Vector2(q.x, q.z)) < CLUSTER_RADIUS ** 2:
				n += 1
		if n > best_n:
			best_n = n
			best = p
	print("dung plate: densest %s at %s (%d within %.0f m)" % [kind, best, best_n, CLUSTER_RADIUS])
	return best


func _on_street(plan: CityPlan, xz: Vector2) -> bool:
	for s: Dictionary in plan.streets:
		if CityDung.DROVE_CLASSES.has(String(s.get("class", ""))):
			var hit := CityDung._closest_on(CityPlan.points(s["points"]), xz)
			if float(hit[2]) < float(s.get("width", 4.0)) * 0.5:
				return true
	return false


func _settle(seconds: float) -> void:
	var waited := 0.0
	while waited < seconds:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await RenderingServer.frame_post_draw


func _save(path: String) -> void:
	get_tree().root.get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path(path)
	)
	print("dung plate: ", path)
