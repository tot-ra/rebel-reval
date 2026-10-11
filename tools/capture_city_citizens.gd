extends Node

## Acceptance capture for the census citizens in the seamless city
## (docs/SYSTEMS/CITIZENS.md): loads the city at a pinned hour, reports who is
## outdoors near the spawn, clicks the nearest resident and saves the street view
## before and after. Host scene so autoloads resolve:
##   tools/godot_render.sh --resolution 1600x900 res://tools/capture_city_citizens.tscn \
##     -- --city-spawn=poi.forum --city-hour=10 [--tag=morning]
## Output: docs/reports/images/city/citizens_<tag>.png, citizens_<tag>_panel.png and
## citizens_<tag>_named_panel.png (a registry named NPC, docs/SYSTEMS/NAMED_NPCS.md)

const SCENE := preload("res://scenes/world/reval_city/reval_city.tscn")
const OUTPUT_DIR := "res://docs/reports/images/city"


func _ready() -> void:
	call_deferred("_run")


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.trim_prefix(prefix)
	return fallback


func _run() -> void:
	var tag := _arg("--tag=", "forum")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var city: Node = SCENE.instantiate()
	add_child(city)
	var pinned := float(_arg("--city-hour=", "-1"))
	for _i in 240:
		# Sky and light at the pinned hour too (--city-hour only pins the people).
		if pinned >= 0.0 and city.runtime != null:
			city.runtime.cycle_progress = pinned / 24.0
		await get_tree().process_frame
	var citizens := city.find_child("CityCitizens", true, false) as CityCitizens
	if citizens == null:
		push_error("no CityCitizens in the city scene")
		get_tree().quit(1)
		return
	print("hour %.2f, live citizens %d" % [citizens.hour(), citizens.live_count()])
	var bodies := {}
	for actor in citizens.live_actors():
		bodies[actor.record["body"]] = int(bodies.get(actor.record["body"], 0)) + 1
	print("bodies in view: ", bodies)
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("%s/citizens_%s.png" % [OUTPUT_DIR, tag])
	)
	var camera: Camera3D = city.view.view_camera()
	var best: CitizenActor = null
	var best_d := INF
	for actor in citizens.live_actors():
		var rig: SharedCharacterRig = city.runtime.get_actor_rig(actor)
		if rig == null:
			continue
		var screen := camera.unproject_position(rig.global_position + Vector3.UP * 0.9)
		var d := screen.distance_to(get_viewport().get_visible_rect().size * 0.5)
		if d < best_d and not camera.is_position_behind(rig.global_position):
			best = actor
			best_d = d
	if best == null:
		print("no rig to click")
		get_tree().quit(1)
		return
	var rig2: SharedCharacterRig = city.runtime.get_actor_rig(best)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = camera.unproject_position(rig2.global_position + Vector3.UP * 0.9)
	Input.parse_input_event(click)
	for _i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("clicked ", best.record["name"], " panel open: ", citizens._panel.is_open())
	print("panel rect ", citizens._panel.panel_rect(), " viewport ", get_viewport().get_visible_rect())
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("%s/citizens_%s_panel.png" % [OUTPUT_DIR, tag])
	)
	_capture_named(city, camera)
	for _i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("panel shows ", citizens.info_panel().shown_id)
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("%s/citizens_%s_named_panel.png" % [OUTPUT_DIR, tag])
	)
	get_tree().quit(0)


## Registry named NPCs in view (docs/SYSTEMS/NAMED_NPCS.md): lists them and
## clicks the one nearest the screen centre to open its portrait panel.
func _capture_named(city: Node, camera: Camera3D) -> void:
	var named := city.find_child("CityNamedNpcs", true, false) as CityNamedNpcs
	if named == null:
		print("no CityNamedNpcs in the city scene")
		return
	var names := PackedStringArray()
	var best: NamedNpcActor = null
	var best_d := INF
	for actor in named.live_actors():
		names.append(String(actor.npc["display_name"]))
		var rig: SharedCharacterRig = city.runtime.get_actor_rig(actor)
		if rig == null or camera.is_position_behind(rig.global_position):
			continue
		var d := camera.unproject_position(rig.global_position).distance_to(
			get_viewport().get_visible_rect().size * 0.5
		)
		if d < best_d:
			best = actor
			best_d = d
	print("named NPCs live %d: %s" % [named.live_count(), ", ".join(names)])
	if best == null:
		print("no named NPC rig to click")
		return
	var rig2: SharedCharacterRig = city.runtime.get_actor_rig(best)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = camera.unproject_position(rig2.global_position + Vector3.UP * 0.9)
	# Input events arrive in window pixels; the render window may be scaled from the viewport.
	click.position = get_viewport().get_screen_transform() * click.position
	Input.parse_input_event(click)
	print("clicked named ", best.npc["display_name"])
