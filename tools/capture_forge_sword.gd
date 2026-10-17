extends Node

## Kalev's forge sword in the seamless city (task R-2007, docs/SYSTEMS/EQUIPMENT_VARIANTS.md):
## the arming sword `arming_sword_p2_w0` leaning in the forge bay of site.kalev_smithy, then
## picked up, equipped and drawn. (tools/capture_forge_brawl.gd still frames the retired
## forge.tscn interior, where the weapons no longer stand.) Host scene so autoloads resolve:
##   tools/godot_render.sh --resolution 1600x900 res://tools/capture_forge_sword.tscn \
##     [-- --out=res://build/x]
## Writes forge_sword_on_ground.png and forge_sword_held.png.

const CITY_SCENE := preload("res://scenes/world/reval_city/reval_city.tscn")
const DEFAULT_OUT := "res://docs/reports/images/equipment"
const SWORD := &"item.forge_arming_sword"
const PICKUP := &"interact.pickup.world.forge_arming_sword"
const SCENE_DIR := "res://assets/props/weapons/arming_sword/scenes/"
const GROUND_SCENE := SCENE_DIR + "arming_sword_p2_w0_ground.tscn"
const HELD_SCENE := "res://assets/props/weapons/arming_sword/scenes/arming_sword_p2_w0_held.tscn"

var _out := DEFAULT_OUT


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var city: Node = CITY_SCENE.instantiate()
	add_child(city)
	for _i in 240:
		if city.runtime != null:
			city.runtime.cycle_progress = 11.0 / 24.0
		await get_tree().process_frame
	var player: Player = city.player
	var sword := _find_scene(city, GROUND_SCENE)
	var pickup := _pickup(city)
	print("forge sword: ground %s pickup %s" % [sword != null, pickup != null])
	if sword == null or pickup == null or player == null:
		get_tree().quit(1)
		return
	# Stand back so the hero is not in the way of the leaning sword.
	player.global_position = pickup.global_position + Vector2(64.0, 48.0)
	await _frames(20)
	var at := sword.global_position
	print("forge sword: at ", at)
	# From the open side of the weapon row (Godot FORWARD of the sword), looking along it.
	var cam := _close_camera(at + Vector3(0.0, 0.8, -1.1), at + Vector3(0.0, 0.45, 0.0))
	await _frames(6)
	await _save("forge_sword_on_ground")
	cam.queue_free()
	await _frames(2)

	player.global_position = pickup.global_position + Vector2(24.0, 0.0)
	pickup.register_actor_in_range(player)
	pickup.interact(player)
	await _frames(4)
	var state := SessionState.state
	if state.has_item(SWORD):
		state.unequip_to_bag(&"right_hand")
		state.equip_from_bag(&"right_hand", SWORD)
	player.set_weapon_drawn(true)
	print(
		(
			"forge sword: in bag %s, equipped %s"
			% [state.has_item(SWORD), state.equipped_item(&"right_hand")]
		)
	)
	player.set_view_facing(Vector2(0.4, 1.0))
	await _frames(30)
	var held := _find_scene(city, HELD_SCENE)
	print("forge sword: held node %s" % (held != null))
	var hand := held.global_position if held != null else at
	cam = _close_camera(hand + Vector3(1.4, 0.6, 1.8), hand + Vector3(0.0, 0.1, 0.0))
	await _frames(6)
	await _save("forge_sword_held")
	cam.queue_free()
	get_tree().quit(0)


## The instance of `path` under `root`: the forge sword on the ground (the world item's 3D
## view) or in the hero's hand.
func _find_scene(root: Node, path: String) -> Node3D:
	for node in root.find_children("*", "Node3D", true, false):
		if node.scene_file_path == path:
			return node as Node3D
	return null


func _pickup(root: Node) -> Interactable:
	for node in root.find_children("*", "Area2D", true, false):
		var interactable := node as Interactable
		if interactable != null and interactable.interactable_id == PICKUP:
			return interactable
	return null


func _close_camera(eye: Vector3, target: Vector3) -> Camera3D:
	var current := get_viewport().get_camera_3d()
	var camera := Camera3D.new()
	camera.fov = 45.0
	camera.near = 0.05
	current.get_parent().add_child(camera)
	camera.global_position = eye
	camera.look_at(target, Vector3.UP)
	camera.make_current()
	camera.tree_exiting.connect(
		func() -> void:
			if is_instance_valid(current):
				current.make_current()
	)
	return camera


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _save(stem: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [_out, stem]
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("capture: ", path)
