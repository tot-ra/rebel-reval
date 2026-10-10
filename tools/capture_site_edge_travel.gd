extends Node

## Edge-to-travel-map plate for a regional site (ADR 0042 verification,
## docs/SYSTEMS/REGIONAL_SITES.md): loads the real site scene, walks the player
## into the east edge band and captures the global travel map it opens.
## Host scene so autoloads (DoorNavigator, SessionState) resolve:
##   tools/godot_render.sh res://tools/capture_site_edge_travel.tscn [-- --site=harju]
## Output: docs/reports/images/sites/<site>_edge_travel_map.png (1280x720), exit 1 on failure.

const OUTPUT_DIR := "res://docs/reports/images/sites"
const VIEWPORT_SIZE := Vector2i(1280, 720)

var _site := "harju"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--site="):
			_site = arg.substr(7)
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	var tree := get_tree()
	var scene: Node = load("res://scenes/world/sites/%s.tscn" % _site).instantiate()
	add_child(scene)
	if not scene.is_node_ready():
		await scene.ready
	for i in 30:
		await tree.process_frame
	var plan: CityPlan = scene.get("plan")
	var player: Node2D = scene.get("player")
	# A step past the edge band at mid-height of the east edge, as a walking player reaches it.
	var outside := Vector2(plan.bounds.end.x - 4.0, plan.bounds.get_center().y)
	player.global_position = CityPlan.to_logic(outside)
	scene.call("_check_city_edge", outside)
	var controller := player.get_node_or_null("WorldMapController") as WorldMapController
	if controller == null or not controller.is_open():
		push_error("%s edge did not open the travel map" % _site)
		tree.quit(1)
		return
	for i in 30:
		await tree.process_frame
	var image := get_viewport().get_texture().get_image()
	if image.get_size() != VIEWPORT_SIZE:
		image.resize(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var path := "%s/%s_edge_travel_map.png" % [OUTPUT_DIR, _site]
	image.save_png(ProjectSettings.globalize_path(path))
	print("captured %s" % path)
	tree.quit(0)
