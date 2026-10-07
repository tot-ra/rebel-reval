extends "res://scripts/global/BaseLevel.gd"

## Seamless Reval 1343 (ADR 0031): the whole walled town, Toompea, the shore and
## the near countryside in one scene. No district seams, no load on the way from
## the Coastal Gate up Pikk jalg to the castle, and houses are entered by
## walking through their door (the roof lifts while Kalev is inside).
##
## Start: main menu > "Reval (seamless preview)", or
##   godot --path . res://scenes/world/reval_city/reval_city.tscn -- --city-spawn=gate.viru

const RIG_SCENE := preload("res://assets/characters/kalev/kalev.tscn")
const DEFAULT_SPAWN := "poi.forum"
const CAMERA_DISTANCE := 7.5
const CAMERA_MIN_DISTANCE := 2.5
const CAMERA_MAX_DISTANCE := 60.0
const INTERIOR_DISTANCE := 5.0
const CAMERA_TARGET_HEIGHT := 1.7
const MOUSE_DEGREES_PER_PIXEL := 0.25
const KEY_ROTATE_DEGREES := 90.0
const HEIGHT_FOLLOW := 14.0
## Day clock speed: one in-game day per 24 real minutes.
const DAY_SECONDS := 1440.0
const LIGHTING_INTERVAL := 0.25

var plan: CityPlan
var world: CityWorld3D
var camera: Camera3D
var rig: SharedCharacterRig
var view_root: Node3D
var minimap: CityMinimap
var yaw := deg_to_rad(-35.0)
var pitch := deg_to_rad(-18.0)
var distance := CAMERA_DISTANCE
var day_progress := 0.38
var inside_building := -1
var _rig_height := 0.0
var _last_facing := Vector2.DOWN
var _lighting_timer := 0.0
var _rotating := false

@onready var actors: Node2D = $Actors
@onready var player: Player = $Actors/Player


func _ready() -> void:
	super()
	plan = CityPlan.load_default()
	CityCollisionBuilder.build(plan, self)
	_hide_logic_visuals()
	view_root = Node3D.new()
	view_root.name = "View"
	add_child(view_root)
	world = CityWorld3D.create(plan)
	view_root.add_child(world)
	camera = Camera3D.new()
	camera.name = "CityCamera"
	camera.near = 0.1
	camera.far = 5000.0
	camera.fov = 62.0
	view_root.add_child(camera)
	camera.current = true
	world.setup_lighting(camera)
	world.apply_time(day_progress)
	rig = RIG_SCENE.instantiate() as SharedCharacterRig
	rig.name = "KalevRig"
	view_root.add_child(rig)
	minimap = CityMinimap.create(plan)
	add_child(minimap)
	_place_player(_spawn_id())
	_rig_height = plan.walk_height(CityPlan.to_world_xz(player.global_position))
	_sync_rig(0.0, true)
	_update_camera()


func _spawn_id() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--city-spawn="):
			return arg.substr(13)
	return DEFAULT_SPAWN


func _place_player(spawn_id: String) -> void:
	var at := Vector2.ZERO
	var g := plan.gate(spawn_id)
	var poi := plan.point_of_interest(spawn_id)
	if not g.is_empty():
		at = Vector2(g["at"][0], g["at"][1])
		# Stand just inside the gate, on the town side.
		var along := Vector2(cos(float(g["angle"])), sin(float(g["angle"])))
		var inward := Vector2(-along.y, along.x)
		at += inward * 6.0
	elif not poi.is_empty():
		at = Vector2(poi["at"][0], poi["at"][1])
	player.global_position = CityPlan.to_logic(at)


func _hide_logic_visuals() -> void:
	for child_name in ["GreyboxVisual", "HealthRing", "StaminaBar", "Camera2D"]:
		var node := player.get_node_or_null(child_name)
		if node is CanvasItem:
			(node as CanvasItem).visible = false
		if node is Camera2D:
			(node as Camera2D).enabled = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_rotating = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(CAMERA_MIN_DISTANCE, distance * 0.9)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(CAMERA_MAX_DISTANCE, distance * 1.1)
	elif event is InputEventMouseMotion and _rotating:
		var mm := event as InputEventMouseMotion
		yaw -= deg_to_rad(mm.relative.x * MOUSE_DEGREES_PER_PIXEL)
		pitch = clampf(
			pitch - deg_to_rad(mm.relative.y * MOUSE_DEGREES_PER_PIXEL),
			deg_to_rad(-80.0),
			deg_to_rad(15.0)
		)


func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_Q):
		yaw += deg_to_rad(KEY_ROTATE_DEGREES) * delta
	if Input.is_key_pressed(KEY_E):
		yaw -= deg_to_rad(KEY_ROTATE_DEGREES) * delta
	# Gamepad right stick orbits the camera.
	var stick := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	if stick.length() > 0.2:
		yaw -= stick.x * deg_to_rad(KEY_ROTATE_DEGREES * 1.5) * delta
		pitch = clampf(
			pitch - stick.y * deg_to_rad(60.0) * delta, deg_to_rad(-80.0), deg_to_rad(15.0)
		)
	_update_movement_basis()
	_update_interior()
	_sync_rig(delta, false)
	_update_camera()
	var xz := CityPlan.to_world_xz(player.global_position)
	world.doors.update_for(xz, delta)
	world.grass.update_for(xz)
	minimap.update_view(xz, _last_facing, yaw, inside_building)
	day_progress = wrapf(day_progress + delta / DAY_SECONDS, 0.0, 1.0)
	_lighting_timer -= delta
	if _lighting_timer <= 0.0:
		_lighting_timer = LIGHTING_INTERVAL
		world.apply_time(day_progress)


## Screen axes in logic space: right follows the camera's right vector, down is
## the ground direction toward the camera.
func _update_movement_basis() -> void:
	var right := Vector2(cos(yaw), -sin(yaw))
	var toward_camera := Vector2(sin(yaw), cos(yaw))
	player.set_screen_movement_basis(right, toward_camera)
	player.set_camera_facing(Vector2.ZERO)


func _update_interior() -> void:
	var xz := CityPlan.to_world_xz(player.global_position)
	var index := plan.building_at(xz)
	if index >= 0 and not bool(plan.buildings[index].get("enterable", false)):
		index = -1
	if index == inside_building:
		return
	if inside_building >= 0:
		world.set_roof_hidden(inside_building, false)
	inside_building = index
	if inside_building >= 0:
		world.set_roof_hidden(inside_building, true)


func _sync_rig(delta: float, snap: bool) -> void:
	var xz := CityPlan.to_world_xz(player.global_position)
	var target_h := plan.walk_height(xz)
	_rig_height = (
		target_h if snap else lerpf(_rig_height, target_h, clampf(delta * HEIGHT_FOLLOW, 0.0, 1.0))
	)
	rig.position = Vector3(xz.x, _rig_height, xz.y)
	var speed := player.velocity.length()
	var moving := speed > MapViewRuntimeActors.WALK_ANIMATION_MIN_SPEED
	var facing := player.view_facing() if player.has_method("view_facing") else Vector2.ZERO
	if facing.is_zero_approx():
		facing = player.velocity.normalized() if moving else _last_facing
	_last_facing = facing.normalized() if not facing.is_zero_approx() else _last_facing
	if snap or not moving:
		rig.set_facing(_last_facing)
	else:
		rig.face_toward(_last_facing, delta)
	var wanted: StringName = (
		player.view_animation() if player.has_method("view_animation") else &"idle"
	)
	if rig.current_canonical_animation() != wanted:
		rig.play_animation(wanted)
	rig.set_locomotion_speed(speed / CityPlan.LOGIC_PX_PER_UNIT)


func _update_camera() -> void:
	var target := rig.position + Vector3(0, CAMERA_TARGET_HEIGHT, 0)
	var dist := INTERIOR_DISTANCE if inside_building >= 0 else distance
	var cam_pitch := minf(pitch, deg_to_rad(-48.0)) if inside_building >= 0 else pitch
	var offset := (
		Vector3(sin(yaw) * cos(cam_pitch), -sin(cam_pitch), cos(yaw) * cos(cam_pitch)) * dist
	)
	var eye := target + offset
	# Pull in in front of walls and houses between Kalev and the camera, using
	# the same logic-plane collision Kalev walks against.
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		player.global_position, CityPlan.to_logic(Vector2(eye.x, eye.z)), CollisionLayers.WORLD
	)
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var hit_xz := CityPlan.to_world_xz(hit["position"])
		var full := Vector2(offset.x, offset.z).length()
		var keep := maxf(0.6, Vector2(hit_xz.x - target.x, hit_xz.y - target.z).length() - 0.35)
		if full > 0.001 and keep < full:
			var k := keep / full
			eye = target + Vector3(offset.x * k, offset.y * maxf(k, 0.55), offset.z * k)
	# Never below the ground (hills, the klint, Pikk jalg banks).
	var ground := plan.ground_height(Vector2(eye.x, eye.z)) + 0.4
	if eye.y < ground:
		eye.y = ground
	camera.look_at_from_position(eye, target, Vector3.UP)
