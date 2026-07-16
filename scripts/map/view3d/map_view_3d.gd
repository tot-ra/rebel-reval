class_name MapView3D
extends Node3D

## P0-052 3D orthographic view layer (ADR 0007). Assembles terrain, building,
## and prop geometry from an immutable MapDefinition, framed by a fixed
## dimetric orthographic camera under a deterministic day/night sun.
## Pure view: it never mutates the definition, grid, fingerprints, collision,
## navigation, or activation state, and actor positions flow one way from the
## logic plane through MapViewBridge.

const TIME_DAY := &"day"
const TIME_NIGHT := &"night"
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

var definition: MapDefinition
var grid: MapTerrainGrid
var time_of_day: StringName = TIME_DAY

var _sun: DirectionalLight3D
var _environment: Environment
var _camera: Camera3D


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


func set_time_of_day(next_time: StringName) -> void:
	assert(next_time in ALL_TIMES)
	time_of_day = next_time
	var night := next_time == TIME_NIGHT
	_sun.rotation_degrees = SUN_NIGHT_ROTATION_DEGREES if night else SUN_DAY_ROTATION_DEGREES
	_sun.light_color = SUN_NIGHT_COLOR if night else SUN_DAY_COLOR
	_sun.light_energy = SUN_NIGHT_ENERGY if night else SUN_DAY_ENERGY
	_environment.ambient_light_color = AMBIENT_NIGHT_COLOR if night else AMBIENT_DAY_COLOR
	_environment.ambient_light_energy = AMBIENT_NIGHT_ENERGY if night else AMBIENT_DAY_ENERGY
	_environment.background_color = BACKGROUND_NIGHT_COLOR if night else BACKGROUND_DAY_COLOR


func world_position(logic_position: Vector2, height: float = 0.0) -> Vector3:
	return MapViewBridge.logic_to_world(logic_position, definition.cell_size, height)


func sync_actor(actor: Node3D, logic_position: Vector2) -> void:
	MapViewBridge.sync_actor(actor, logic_position, definition.cell_size)


func anchor_world_position(anchor_id: StringName) -> Vector3:
	return world_position(MapVerification.anchor_position(definition, anchor_id))


func view_camera() -> Camera3D:
	return _camera


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

	var doors := Node3D.new()
	doors.name = "Doors"
	add_child(doors)
	for transition in definition.transitions:
		if not String(transition.get("destination_scene_id", "")).is_empty():
			doors.add_child(MapViewMeshBuilder.build_transition_door(transition, definition.cell_size))

	var props := Node3D.new()
	props.name = "Props"
	add_child(props)
	for prop in definition.props:
		props.add_child(MapViewMeshBuilder.build_prop(prop, definition.cell_size))

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
	_sun.shadow_enabled = true
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
