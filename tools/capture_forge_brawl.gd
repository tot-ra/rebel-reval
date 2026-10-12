extends Node

## Acceptance capture for the forge weapon set and brawls with citizens
## (R-1754..R-1756, docs/SYSTEMS/COMBAT.md). Host scene so autoloads resolve:
##   tools/godot_render.sh --resolution 1600x900 res://tools/capture_forge_brawl.tscn \
##     -- --city-spawn=poi.forum --city-hour=11 [--out=res://build/x]
## 1. Kalev's smithy: the weapon row, then the arming sword picked up and equipped.
## 2. The city: a real sword swing on a man (he fights back, bars show) and on a
##    woman or child (she runs).

const FORGE_SCENE := preload("res://scenes/reval_east/forge/forge.tscn")
const CITY_SCENE := preload("res://scenes/world/reval_city/reval_city.tscn")
const DEFAULT_OUT := "res://docs/reports/images/combat/forge_weapons"
const SWORD := &"item.forge_arming_sword"
const SHIELD := &"item.forge_heater_shield"

var _out := DEFAULT_OUT


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await _capture_forge()
	await _capture_city()
	get_tree().quit(0)


func _capture_forge() -> void:
	var forge: Node = FORGE_SCENE.instantiate()
	add_child(forge)
	await _frames(90)
	var player := forge.get_node("Actors/Player") as Player
	# Stand in the forge bay facing the divider wall where the weapons lean.
	player.global_position = Vector2(19.0, 10.6) * 32.0
	player.set_view_facing(Vector2.LEFT)
	await _frames(30)
	await _save("forge_overview")
	# World units are rrmap cells: the weapons stand at x 17, z 9.2..12.2,
	# on the open forge-bay side of the divider wall.
	var close := _close_camera(Vector3(19.8, 1.55, 12.2), Vector3(17.0, 0.75, 10.6))
	await _frames(6)
	await _save("forge_weapon_row")
	close.queue_free()
	var pickup := _pickup(forge, &"interact.pickup.world.forge_arming_sword")
	var shield := _pickup(forge, &"interact.pickup.world.forge_heater_shield")
	for interactable: Interactable in [pickup, shield]:
		if interactable == null:
			push_error("forge weapon pickup missing")
			continue
		player.global_position = interactable.global_position + Vector2(24.0, 0.0)
		interactable.register_actor_in_range(player)
		interactable.interact(player)
		await _frames(4)
	var state := SessionState.state
	if state.has_item(SWORD) and state.has_item(SHIELD):
		state.unequip_to_bag(&"right_hand")
		state.equip_from_bag(&"right_hand", SWORD)
		state.equip_from_bag(&"left_hand", SHIELD)
	print("forge: sword %s shield %s equipped %s / %s" % [
		state.has_item(SWORD), state.has_item(SHIELD),
		state.equipped_item(&"right_hand"), state.equipped_item(&"left_hand"),
	])
	player.global_position = Vector2(17.4, 10.4) * 32.0
	player.set_view_facing(Vector2(-1.0, 0.6))
	await _frames(30)
	close = _close_camera(Vector3(19.4, 1.7, 12.4), Vector3(17.2, 0.9, 10.3))
	await _frames(6)
	await _save("forge_sword_and_shield_equipped")
	close.queue_free()
	forge.queue_free()
	await _frames(4)


func _capture_city() -> void:
	var city: Node = CITY_SCENE.instantiate()
	add_child(city)
	var pinned := float(_arg("--city-hour=", "11"))
	for _i in 240:
		if city.runtime != null:
			city.runtime.cycle_progress = pinned / 24.0
		await get_tree().process_frame
	var citizens := city.find_child("CityCitizens", true, false) as CityCitizens
	var player: Player = city.player
	if citizens == null or player == null:
		push_error("city has no CityCitizens or player")
		return
	var man := _resident(citizens, player, true)
	var runner := _resident(citizens, player, false)
	print("city: live %d, man %s, runner %s" % [
		citizens.live_count(),
		man.record["name"] if man != null else "-",
		runner.record["name"] if runner != null else "-",
	])
	if man != null:
		await _swing_at(player, man)
		await _frames(50)
		await _save("brawl_man_fights_back")
		var rig: SharedCharacterRig = city.runtime.get_actor_rig(man)
		if rig != null:
			var at := rig.global_position
			var cam := _close_camera(at + Vector3(2.6, 2.0, 2.6), at + Vector3(0.0, 1.0, 0.0))
			await _frames(4)
			await _save("brawl_man_fights_back_close")
			cam.queue_free()
		print("man: mode %d health %.0f/%.0f stamina %.0f, hero health %.0f" % [
			man.brawler.mode, man.health, man.max_health, man.stamina, player.health,
		])
	if runner != null:
		await _swing_at(player, runner)
		await _frames(45)
		await _save("brawl_bystander_flees")
		print("runner: mode %d" % runner.brawler.mode if runner.brawler != null else "runner: not hit")


## Steps up to the resident, faces them and swings the equipped weapon for real.
func _swing_at(player: Player, actor: CitizenActor) -> void:
	var offset := (player.global_position - actor.global_position)
	var side := offset.normalized() if offset.length() > 1.0 else Vector2.RIGHT
	# Swing at once: a walking resident leaves the cone within a few frames.
	player.global_position = actor.global_position + side * 26.0
	player.set_view_facing(-side)
	player.request_primary_attack()
	await _frames(40)


## A temporary perspective camera in the current 3D world, made current.
func _close_camera(eye: Vector3, target: Vector3) -> Camera3D:
	var current := get_viewport().get_camera_3d()
	var camera := Camera3D.new()
	camera.fov = 50.0
	current.get_parent().add_child(camera)
	camera.global_position = eye
	camera.look_at(target, Vector3.UP)
	camera.make_current()
	camera.tree_exiting.connect(func() -> void:
		if is_instance_valid(current):
			current.make_current()
	)
	return camera


func _resident(citizens: CityCitizens, player: Player, fighter: bool) -> CitizenActor:
	var best: CitizenActor = null
	var best_d := INF
	for actor in citizens.live_actors():
		if not actor.outdoors or actor.at_home or actor.brawler != null:
			continue
		if bool(CitizenBrawler.stats_for(actor.record)["fights"]) != fighter:
			continue
		var d := actor.global_position.distance_to(player.global_position)
		if d < best_d:
			best = actor
			best_d = d
	return best


func _pickup(root: Node, interactable_id: StringName) -> Interactable:
	for node in root.find_children("*", "Area2D", true, false):
		var interactable := node as Interactable
		if interactable != null and interactable.interactable_id == interactable_id:
			return interactable
	return null


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.trim_prefix(prefix)
	return fallback


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _save(stem: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [_out, stem]
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("capture: ", path)
