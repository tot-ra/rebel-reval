extends Node

## Review plates for CityFauna in the seamless city: Kalev beside the animal
## groups at the forum, the Karja farmsteads, a gate and a fallow field. Reports
## the live animal count at each stop and exits 1 when a stop has none.
##   tools/godot_render.sh --resolution 1600x900 res://tools/capture_city_fauna.tscn
## Output: docs/reports/images/city/fauna_<stop>.png

const SCENE := preload("res://scenes/world/reval_city/reval_city.tscn")
const OUTPUT_DIR := "res://docs/reports/images/city"
const SETTLE_SEC := 6.0

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var city: Node = SCENE.instantiate()
	get_tree().root.add_child(city)
	await get_tree().process_frame
	await get_tree().process_frame
	var plan: CityPlan = city.plan
	var fauna: CityFauna = city.world.get_node("CityFauna")
	var stops: Array[Array] = []
	for group in CityFauna.groups_for(plan):
		var id := String(group["id"])
		for key: String in ["poi.forum/horse", "poi.smithy.harju/horse", "poi.slaughter.karja/pig"]:
			if id.begins_with(key) and not _has_stop(stops, key):
				stops.append([key, group["centre"]])
	var args := OS.get_cmdline_user_args()
	for stop in stops:
		var label := String(stop[0]).replace(".", "_").replace("/", "_")
		var at: Vector2 = stop[1]
		city.player.global_position = CityPlan.to_logic(at + Vector2(0, 5))
		city.player.velocity = Vector2.ZERO
		var waited := 0.0
		while waited < SETTLE_SEC:
			await get_tree().process_frame
			waited += get_process_delta_time()
		var count := fauna.live_actor_count()
		print("stop %s: %d live animals" % [label, count])
		if count == 0:
			_failures.append(label)
		if not args.has("--no-shots"):
			var image := get_tree().root.get_viewport().get_texture().get_image()
			image.save_png(ProjectSettings.globalize_path("%s/fauna_%s.png" % [OUTPUT_DIR, label]))
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _has_stop(stops: Array[Array], key: String) -> bool:
	for stop in stops:
		if stop[0] == key:
			return true
	return false
