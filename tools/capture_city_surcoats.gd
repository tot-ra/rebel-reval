extends Node

## Crown men-at-arms and knights in their surcoats, in the seamless city at gameplay distance
## (task R-2022; the R-1994 historical-walk shot of the Toompea castle bailey). Loads the city
## at a pinned hour, walks Kalev up behind up to three live residents who wear a surcoat
## layer, and saves the gameplay view of each. Host scene so autoloads resolve:
##   tools/godot_render.sh --resolution 1600x900 res://tools/capture_city_surcoats.tscn \
##     -- --city-spawn=poi.well.castle --city-hour=10 [--output-dir=PATH]
## Output: <output-dir>/city_surcoat_<n>.jpg (default docs/reports/images/equipment).

const SCENE := preload("res://scenes/world/reval_city/reval_city.tscn")
const COUNT := 3
## Kalev stands this far from the resident (metres, logic plane), toward the spawn.
const STAND_OFF := 3.0


func _ready() -> void:
	call_deferred("_run")


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.trim_prefix(prefix)
	return fallback


func _run() -> void:
	var out := _arg("--output-dir=", "res://docs/reports/images/equipment")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var city: Node = SCENE.instantiate()
	add_child(city)
	var hour := float(_arg("--city-hour=", "10"))
	for _i in 240:
		if city.runtime != null:
			city.runtime.cycle_progress = hour / 24.0
		await get_tree().process_frame
	var citizens := city.find_child("CityCitizens", true, false) as CityCitizens
	var shot := 0
	for actor in citizens.live_actors():
		if shot >= COUNT:
			break
		var wear: Array = actor.record.get("wear", [])
		if not wear.any(func(e: String) -> bool: return e.begins_with("surcoat")):
			continue
		var rig: SharedCharacterRig = city.runtime.get_actor_rig(actor)
		if rig == null:
			continue
		# Kalev lives on the logic plane (2D); step him back from the resident toward where he was.
		var player: Node2D = city.player
		var here := CityPlan.to_world_xz(player.global_position)
		var at: Vector2 = actor.world_xz()
		var away := (here - at).normalized() if here.distance_to(at) > 0.1 else Vector2.DOWN
		player.global_position = CityPlan.to_logic(at + away * STAND_OFF)
		for _i in 30:
			city.runtime.cycle_progress = hour / 24.0
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		shot += 1
		print("SURCOAT %d %s %s %s" % [shot, actor.record["id"], actor.record.get("trade"), wear])
		get_viewport().get_texture().get_image().save_jpg(
			ProjectSettings.globalize_path("%s/city_surcoat_%d.jpg" % [out, shot]), 0.88
		)
	print("surcoat wearers shot: %d" % shot)
	get_tree().quit(0 if shot > 0 else 1)
