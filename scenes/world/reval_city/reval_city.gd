extends "res://scripts/global/BaseLevel.gd"

## Seamless Reval 1343 (ADR 0031): the whole walled town, Toompea, the shore and
## the near countryside in one scene. No district seams, no load on the way from
## the Coastal Gate up Pikk jalg to the castle, and houses are entered by
## walking through their door (the door swings open, the roof and ceiling lift).
##
## Presentation runs on the shared MapViewRuntime (CityRuntime), so the city
## has the game's three camera modes, Kalev's rig, magic VFX and the session
## clock and weather of every other location.
##
## Start: main menu "Start" (Kalev's smithy, whose door leads here), or
##   godot --path . res://scenes/world/reval_city/reval_city.tscn -- --city-spawn=gate.viru

const DEFAULT_SPAWN := "poi.forum"
## Travel speed for crossing the city on foot (maintainer request 2026-10-07).
const SPEED_MULTIPLIER := 5.0
## Within this many units of the plan edge the travel map opens: beyond the
## city and its fields lie the regions reached by a journey.
const EDGE_MARGIN := 28.0

var plan: CityPlan
var view: CityMapView
var world: CityWorld3D
var runtime: MapViewRuntime
var minimap: CityMinimap
## Furnished houses round Kalev and their people at home (docs/SYSTEMS/HOUSEHOLDS.md).
var interiors: CityInteriors
var music_zones := CityMusicZones.new()
var inside_building := -1
var _music_timer := 0.0
var _smithy := -1
## Site room Kalev stands in: {site, room} and its key, or empty.
var _site_room: Dictionary = {}
var _site_room_key := ""
var _cut := true
## Armed once Kalev has been outside the smithy (no bounce on arrival).
var _leaving := true

@onready var actors: Node2D = $Actors
@onready var player: Player = $Actors/Player


func _ready() -> void:
	super()
	add_to_group(&"seamless_city")
	plan = CityPlan.load_default()
	CityCollisionBuilder.build(plan, self)
	player.walk_speed = int(player.walk_speed * SPEED_MULTIPLIER)
	player.run_speed = int(player.run_speed * SPEED_MULTIPLIER)
	var arrival := spawn_id()
	_place_player(arrival)
	actors.add_child(CityNpcs.create(plan, player))
	view = CityMapView.create_city(plan)
	world = view.world
	runtime = CityRuntime.install(self, view, player)
	world.add_child(CityFauna.create(plan, player))
	world.add_child(CityFish.create(plan, player))
	interiors = CityInteriors.create(plan, CitizenRoster.load_default(), world.chimneys)
	interiors.collision_parent = self
	interiors.enabled = not "--no-interiors" in OS.get_cmdline_user_args()
	world.add_child(interiors)
	# ADR 0021 swimming: sea and moat depth come from the city's water, not a grid.
	player.set_water_depth_provider(
		func(logic: Vector2) -> float: return view.water_depth_at(CityPlan.to_world_xz(logic))
	)
	# Waist-high meadow drags at the legs (ADR 0039); scythed verges do not.
	player.set_ground_drag_provider(
		func() -> float: return world.grass.walk_drag_at(CityPlan.to_world_xz(player.global_position))
	)
	minimap = CityMinimap.create(plan)
	add_child(minimap)
	_smithy = CityTravel.building_index(plan, "kalev_smithy")
	_face_door_on_arrival(arrival)
	_update_music(CityPlan.to_world_xz(player.global_position))


## Spawn requested by the command line, a pending travel arrival or the default.
func spawn_id() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--city-spawn="):
			return arg.substr(13)
	var pending := String(CityTravel.consume_pending_spawn())
	return pending if not pending.is_empty() else DEFAULT_SPAWN


func _place_player(id: String) -> void:
	player.global_position = CityPlan.to_logic(CityTravel.spawn_position(plan, id))


## Fast travel inside the city (DoorNavigator calls this instead of reloading).
func arrive_at(id: String) -> void:
	_place_player(id)
	_face_door_on_arrival(id)


## Arriving at a building spawn (the new game starts in front of Kalev's smithy)
## turns the gameplay camera to look at its door, so the lane's walls stay behind
## the camera instead of filling the view. The smithy stands in a narrow lane, so
## the nearest look direction whose camera spot is clear of houses is used.
func _face_door_on_arrival(id: String) -> void:
	if runtime == null:
		return
	var index := CityTravel.building_index(plan, id)
	if index < 0 or plan.buildings[index].get("door") == null:
		return
	var door := Vector2(plan.buildings[index]["door"][0], plan.buildings[index]["door"][1])
	var here := CityPlan.to_world_xz(player.global_position)
	var toward := door - here
	if toward.is_zero_approx():
		return
	var best := toward.angle()
	for step in range(0, 17):
		var sign := 1.0 if step % 2 == 0 else -1.0
		var offset: float = ceilf(step / 2.0) * (PI / 8.0) * sign
		var look := Vector2.from_angle(toward.angle() + offset)
		if (
			plan.building_at(here - look * 2.5) < 0
			and plan.building_at(here - look * 5.5) < 0
		):
			best = look.angle()
			break
	var dir := Vector2.from_angle(best)
	var yaw := rad_to_deg(atan2(-dir.x, -dir.y))
	runtime._camera_controller.rotate_view_degrees(yaw - view.view_camera().rotation_degrees.y)


func _process(delta: float) -> void:
	var xz := CityPlan.to_world_xz(player.global_position)
	_update_interior(xz)
	if inside_building != _smithy:
		_leaving = false
	elif _smithy >= 0 and not _leaving:
		# The forge interior keeps its own scene (commission ledger, anvil, quests).
		_leaving = true
		DoorNavigator.go_to_scene(&"forge", &"door_courtyard")
		return
	_check_city_edge(xz)
	world.doors.update_for(xz, delta)
	interiors.update_for(xz, delta)
	world.grass.update_for(xz)
	world.farmland.update_for(xz)
	world.trail.update_for(xz, delta)
	world.smoke.update_for(xz, delta)
	var camera := view.view_camera()
	var forward := -camera.global_transform.basis.z
	var yaw := atan2(-forward.x, -forward.z)
	minimap.update_view(xz, player.view_facing(), yaw, inside_building)
	_music_timer -= delta
	if _music_timer <= 0.0:
		_music_timer = 0.25
		_update_music(xz)


## Music follows where Kalev is (CityMusicZones), not a scene route. The runtime
## already pushes the shared clock to MusicDirector, so only the zone theme is set.
func _update_music(xz: Vector2) -> void:
	var director := get_node_or_null("/root/MusicDirector")
	if director == null:
		return
	var theme := music_zones.update(xz, plan.district_id_at(xz))
	if theme.is_empty():
		director.clear_zone_theme_override()
	else:
		director.set_zone_theme_override(theme)


func _update_interior(xz: Vector2) -> void:
	# Cutaway (roof, ceiling and walls above head height lift away) for the
	# top-down and third-person cameras; first person keeps the whole room.
	var cut := runtime.camera_mode() != MapViewRuntimeCamera.CameraMode.FIRST_PERSON
	var index := plan.building_at(xz)
	if index >= 0 and not bool(plan.buildings[index].get("enterable", false)):
		index = -1
	if index != inside_building or cut != _cut:
		if inside_building >= 0:
			world.set_roof_hidden(inside_building, false)
		inside_building = index
		if inside_building >= 0:
			world.set_roof_hidden(inside_building, cut)
	# Landmark site rooms (ADR 0032) lift their own roof and upper nodes.
	var room := plan.site_room_at(xz)
	var key := "" if room.is_empty() else "%s/%s" % [room["site"].id, room["room"]["id"]]
	if key != _site_room_key or cut != _cut:
		if not _site_room.is_empty():
			world.set_site_room_hidden(_site_room["site"], _site_room["room"], false)
		_site_room = room
		_site_room_key = key
		if not room.is_empty():
			world.set_site_room_hidden(room["site"], room["room"], cut)
	_cut = cut
	view.inside_building = (
		inside_building
		if inside_building >= 0
		else world.site_occluder_index(xz) if key != "" else -1
	)


## Walking out past the fields opens the travel map (global view) instead of
## running off the edge of the plan; Kalev is set back inside.
func _check_city_edge(xz: Vector2) -> void:
	var r := plan.bounds.grow(-EDGE_MARGIN)
	if r.has_point(xz):
		return
	var back := xz.clamp(r.position + Vector2(6, 6), r.end - Vector2(6, 6))
	player.global_position = CityPlan.to_logic(back)
	var world_map := player.get_node_or_null("WorldMapController")
	if world_map != null and world_map.has_method("open"):
		world_map.call("open")
		var overlay: Variant = world_map.call("get_overlay")
		if overlay != null and overlay.has_method("show_global_map"):
			overlay.call("show_global_map")
