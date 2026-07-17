class_name MapView3D
extends Node3D

const DirectionSignBuilder := preload("res://scripts/map/view3d/direction_sign_3d.gd")
const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")

## P0-052 3D orthographic view layer (ADR 0007). Assembles terrain, building,
## and prop geometry from an immutable MapDefinition, framed by a fixed
## dimetric orthographic camera under a deterministic day/night sun.
## Pure view: it never mutates the definition, grid, fingerprints, collision,
## navigation, or activation state, and actor positions flow one way from the
## logic plane through MapViewBridge.

const TIME_DAY := &"day"
const TIME_NIGHT := &"night"
const FOG_OF_WAR_SCRIPT := preload("res://scripts/map/view3d/map_fog_of_war.gd")
const ALL_TIMES: Array[StringName] = [TIME_DAY, TIME_NIGHT]

## Classic isometric framing per ADR 0007; final values freeze in ART_BIBLE v2 (P0-040).
const CAMERA_PITCH_DEGREES := -30.0
const CAMERA_YAW_DEGREES := 45.0
const CAMERA_DISTANCE := 90.0
const CAMERA_MARGIN := 1.15
const CAMERA_HEADROOM := 5.0
const CAMERA_FAR := 400.0

const SUN_DAY_ROTATION_DEGREES := Vector3(-50.0, -35.0, 0.0)
const SUN_DAY_COLOR := Color8(255, 243, 222)
const SUN_DAY_ENERGY := 1.2
const AMBIENT_DAY_COLOR := Color8(168, 178, 189)
const AMBIENT_DAY_ENERGY := 0.85
const BACKGROUND_DAY_COLOR := Color8(31, 30, 28)

## Deterministic night state carrying the ART_BIBLE rules forward: at least
## 20% darker than day while ambient keeps terrain identities readable.
const SUN_NIGHT_ROTATION_DEGREES := Vector3(-36.0, 142.0, 0.0)
const SUN_NIGHT_COLOR := Color8(142, 162, 210)
const SUN_NIGHT_ENERGY := 0.42
const AMBIENT_NIGHT_COLOR := Color8(52, 66, 100)
const AMBIENT_NIGHT_ENERGY := 0.5
const BACKGROUND_NIGHT_COLOR := Color8(12, 14, 22)

## Shadow cascades only need the max-zoom gameplay frustum, not the authored map
## or the camera far plane. Tighter distance concentrates shadow-map texels on
## the slice the player actually sees.
const SUN_SHADOW_MAX_DISTANCE := (
	CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE * 2.0 * 1.35 + 8.0
)
const SUN_SHADOW_SPLIT_1 := 0.08
const SUN_SHADOW_SPLIT_2 := 0.22
const SUN_SHADOW_SPLIT_3 := 0.48
const SUN_SHADOW_BIAS := 0.05
const SUN_SHADOW_NORMAL_BIAS := 1.2

var definition: MapDefinition
var grid: MapTerrainGrid
var time_of_day: StringName = TIME_DAY
var cycle_progress: float = DayNightCycle.DEFAULT_PROGRESS

var _sun: DirectionalLight3D
var _last_chimney_bucket: StringName = TIME_DAY
var _environment: Environment
var _camera: Camera3D
var _fog_of_war: Node3D
var _memory_animation_state: Dictionary = {}
var _occluder_bounds: Array[AABB] = []


static func create(
	map_definition: MapDefinition,
	built_grid: MapTerrainGrid,
	initial_time: StringName = TIME_DAY
) -> MapView3D:
	var view := MapView3D.new()
	view.name = "MapView3D_%s" % String(map_definition.map_id)
	view.definition = map_definition
	view.grid = built_grid
	view._assemble()
	view.set_time_of_day(initial_time)
	return view


func _process(delta: float) -> void:
	if _fog_of_war == null:
		return
	var player_rig := get_tree().get_first_node_in_group(&"player_view_rig") as Node3D
	if player_rig == null:
		return
	var facing := Vector2(sin(player_rig.global_rotation.y), cos(player_rig.global_rotation.y))
	_fog_of_war.call("update_view", player_rig.global_position, facing, delta)
	_update_memory_animations(player_rig.global_position, facing)


func _update_memory_animations(player_position: Vector3, facing: Vector2) -> void:
	var player_ground := Vector2(player_position.x, player_position.z)
	for animated in get_tree().get_nodes_in_group(&"fog_memory_animation"):
		if not animated is AnimationPlayer:
			continue
		var animation := animated as AnimationPlayer
		var owner := animation.get_parent() as Node3D
		if owner == null:
			continue
		var position := Vector2(owner.global_position.x, owner.global_position.z)
		var alive := float(_fog_of_war.call("visibility_at", position, player_ground, facing)) > 0.5
		var key := animation.get_instance_id()
		if not _memory_animation_state.has(key):
			_memory_animation_state[key] = animation.active
		animation.active = bool(_memory_animation_state[key]) if alive else false

	for smoke in get_tree().get_nodes_in_group(&"fog_memory_particles"):
		if not smoke is GPUParticles3D:
			continue
		var particles := smoke as GPUParticles3D
		var position := Vector2(particles.global_position.x, particles.global_position.z)
		var alive := float(_fog_of_war.call("visibility_at", position, player_ground, facing)) > 0.5
		particles.speed_scale = 1.0 if alive else 0.0


func set_time_of_day(next_time: StringName) -> void:
	assert(next_time in ALL_TIMES)
	apply_cycle_progress(0.5 if next_time == TIME_DAY else 0.0, false)


func apply_cycle_progress(progress: float, sweep_sun_yaw: bool = true) -> void:
	cycle_progress = wrapf(progress, 0.0, 1.0)
	var day_blend := DayNightCycle.day_blend(cycle_progress)
	var night := day_blend < 0.5

	_sun.rotation_degrees.x = lerpf(SUN_NIGHT_ROTATION_DEGREES.x, SUN_DAY_ROTATION_DEGREES.x, day_blend)
	if sweep_sun_yaw:
		# Sweep the sun across the map so shadow direction changes through the loop.
		_sun.rotation_degrees.y = lerpf(
			SUN_DAY_ROTATION_DEGREES.y - 70.0,
			SUN_DAY_ROTATION_DEGREES.y + 110.0,
			cycle_progress
		)
	else:
		_sun.rotation_degrees.y = SUN_NIGHT_ROTATION_DEGREES.y if night else SUN_DAY_ROTATION_DEGREES.y
	_sun.rotation_degrees.z = 0.0
	_sun.light_color = SUN_NIGHT_COLOR.lerp(SUN_DAY_COLOR, day_blend)
	_sun.light_energy = lerpf(SUN_NIGHT_ENERGY, SUN_DAY_ENERGY, day_blend)
	_environment.ambient_light_color = AMBIENT_NIGHT_COLOR.lerp(AMBIENT_DAY_COLOR, day_blend)
	_environment.ambient_light_energy = lerpf(AMBIENT_NIGHT_ENERGY, AMBIENT_DAY_ENERGY, day_blend)
	_environment.background_color = BACKGROUND_NIGHT_COLOR.lerp(BACKGROUND_DAY_COLOR, day_blend)

	var bucket := TIME_NIGHT if night else TIME_DAY
	if bucket != _last_chimney_bucket:
		_last_chimney_bucket = bucket
		time_of_day = bucket
		_update_chimney_smokes()
	_update_window_lights()


func _update_chimney_smokes() -> void:
	var buildings := get_node_or_null("Buildings")
	if buildings == null:
		return
	for building_node in buildings.get_children():
		var smoke := building_node.get_node_or_null("ChimneySmoke") as ChimneySmoke3D
		if smoke != null:
			smoke.add_to_group(&"fog_memory_particles")
			smoke.apply_time_of_day(time_of_day)


func _update_window_lights() -> void:
	var buildings := get_node_or_null("Buildings")
	if buildings == null:
		return
	for building_node in buildings.get_children():
		var lights := building_node.get_node_or_null("WindowLights")
		if lights != null and lights.has_method(&"apply_cycle_progress"):
			lights.call("apply_cycle_progress", cycle_progress)


func world_position(logic_position: Vector2, height: float = 0.0) -> Vector3:
	return MapViewBridge.logic_to_world(logic_position, definition.cell_size, height)


func sync_actor(actor: Node3D, logic_position: Vector2) -> void:
	MapViewBridge.sync_actor(actor, logic_position, definition.cell_size)
	# Actors ride the visible terrain relief; the logic plane stays flat.
	actor.position.y = MapViewMeshBuilder.ground_height(
		definition,
		Vector2(actor.position.x, actor.position.z)
	)


func anchor_world_position(anchor_id: StringName) -> Vector3:
	return world_position(MapVerification.anchor_position(definition, anchor_id))


func view_camera() -> Camera3D:
	return _camera


## True when a building or landmark mass crosses the segment. The runtime
## probes from an actor toward the camera to decide when the occluded-actor
## silhouette overlay should show.
func is_segment_occluded(from: Vector3, to: Vector3) -> bool:
	for bounds in _occluder_bounds:
		if bounds.intersects_segment(from, to):
			return true
	return false


func sun_light() -> DirectionalLight3D:
	return _sun


func _assemble() -> void:
	add_child(MapViewMeshBuilder.build_surroundings(definition))
	add_child(MapViewMeshBuilder.build_terrain(definition, grid))
	add_child(MapViewMeshBuilder.build_scatter(definition, grid))

	var buildings := Node3D.new()
	buildings.name = "Buildings"
	add_child(buildings)
	for building in definition.buildings:
		buildings.add_child(MapViewMeshBuilder.build_building(building, definition.cell_size))

	var landmarks := Node3D.new()
	landmarks.name = "Landmarks"
	add_child(landmarks)
	for landmark in definition.view_landmarks:
		landmarks.add_child(MapViewMeshBuilder.build_landmark(landmark, definition.cell_size))

	# Buildings and landmarks are the only masses tall enough to hide an actor
	# from the dimetric camera; their mesh bounds feed is_segment_occluded.
	_append_mesh_bounds(buildings, buildings.transform, _occluder_bounds)
	_append_mesh_bounds(landmarks, landmarks.transform, _occluder_bounds)

	var transition_markers := Node3D.new()
	transition_markers.name = "TransitionMarkers"
	add_child(transition_markers)
	var doors := Node3D.new()
	doors.name = "Doors"
	add_child(doors)
	for transition in definition.transitions:
		if bool(transition.get("highlight_area", false)):
			transition_markers.add_child(MapViewMeshBuilder.build_transition_marker(transition, definition.cell_size))
		if not String(transition.get("destination_scene_id", "")).is_empty() \
				and not MapViewMeshBuilder.transition_uses_landmark_visual(definition, transition):
			doors.add_child(MapViewMeshBuilder.build_transition_door(transition, definition.cell_size))

	var props := Node3D.new()
	props.name = "Props"
	add_child(props)
	for prop in definition.props:
		var prop_node := MapViewMeshBuilder.build_prop(prop, definition.cell_size)
		prop_node.position.y = MapViewMeshBuilder.ground_height(
			definition,
			Vector2(prop_node.position.x, prop_node.position.z)
		)
		props.add_child(prop_node)

	var direction_signs := Node3D.new()
	direction_signs.name = "DirectionSigns"
	add_child(direction_signs)
	for sign in definition.direction_signs:
		var sign_node := DirectionSignBuilder.build(sign, definition.cell_size)
		sign_node.position.y = MapViewMeshBuilder.ground_height(
			definition,
			Vector2(sign_node.position.x, sign_node.position.z)
		)
		direction_signs.add_child(sign_node)

	var anchors := Node3D.new()
	anchors.name = "Anchors"
	add_child(anchors)
	for anchor in definition.interaction_anchors:
		var marker := Marker3D.new()
		marker.name = String(anchor["id"])
		marker.position = world_position(anchor["position"])
		marker.set_meta("anchor_id", anchor["id"])
		anchors.add_child(marker)

	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_configure_sun_shadows(_sun)
	add_child(_sun)

	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var world_environment := WorldEnvironment.new()
	world_environment.name = "ViewEnvironment"
	world_environment.environment = _environment
	add_child(world_environment)

	_camera = _create_camera()
	add_child(_camera)
	# Headless uses the dummy renderer, which cannot provide the screen texture
	# sampled by this post-process. Visibility logic remains directly testable.
	if DisplayServer.get_name() != "headless":
		_fog_of_war = FOG_OF_WAR_SCRIPT.new()
		_fog_of_war.call("configure", _camera, definition)
		add_child(_fog_of_war)


static func _configure_sun_shadows(sun: DirectionalLight3D) -> void:
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = SUN_SHADOW_MAX_DISTANCE
	sun.directional_shadow_split_1 = SUN_SHADOW_SPLIT_1
	sun.directional_shadow_split_2 = SUN_SHADOW_SPLIT_2
	sun.directional_shadow_split_3 = SUN_SHADOW_SPLIT_3
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = SUN_SHADOW_BIAS
	sun.shadow_normal_bias = SUN_SHADOW_NORMAL_BIAS
	sun.shadow_blur = 0.0
	# Hard shadows: GLES Compatibility does not run PCSS, but zeroing angular size
	# keeps the authored look crisp if the renderer is upgraded later.
	sun.light_angular_distance = 0.0


static func _append_mesh_bounds(node: Node3D, accumulated: Transform3D, bounds: Array[AABB]) -> void:
	if node is MeshInstance3D:
		bounds.append(accumulated * (node as MeshInstance3D).get_aabb())
	for child in node.get_children():
		if child is Node3D:
			_append_mesh_bounds(child, accumulated * (child as Node3D).transform, bounds)


func _create_camera() -> Camera3D:
	var camera := Camera3D.new()
	camera.name = "ViewCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation_degrees = Vector3(CAMERA_PITCH_DEGREES, CAMERA_YAW_DEGREES, 0.0)
	var world_units := Vector2(definition.size_cells)
	# Vertical extent of the ground diagonal under the fixed pitch, plus
	# headroom for building mass; the final size freezes in ART_BIBLE v2.
	var diagonal := (world_units.x + world_units.y) / sqrt(2.0)
	camera.size = diagonal * absf(sin(deg_to_rad(CAMERA_PITCH_DEGREES))) * CAMERA_MARGIN + CAMERA_HEADROOM
	camera.far = CAMERA_FAR
	var center := Vector3(world_units.x * 0.5, 0.0, world_units.y * 0.5)
	camera.position = center + camera.transform.basis.z * CAMERA_DISTANCE
	camera.current = true
	return camera
