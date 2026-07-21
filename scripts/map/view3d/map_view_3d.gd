class_name MapView3D
extends Node3D

const DirectionSignBuilder := preload("res://scripts/map/view3d/direction_sign_3d.gd")
const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")
const SkyWeather3D := preload("res://scripts/map/view3d/sky_weather_3d.gd")

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
## Far plane must clear the view-only surroundings ring past map edges at max
## zoom; keep it above SURROUNDINGS_CONTINUATION_DEPTH plus CAMERA_DISTANCE.
const CAMERA_FAR := 800.0
## The orthographic camera can expose objects more than two 32-cell chunks away,
## especially on wide viewports and at maximum zoom-out. Keep one extra ring
## resident so authored district frontages never disappear inside the viewport.
const VIEW_LOAD_RADIUS_CHUNKS := MapTerrainRenderer.DEFAULT_LOAD_RADIUS_CHUNKS + 1

const SUN_DAY_COLOR := Color8(255, 243, 222)
const SUN_DAY_ENERGY := 1.2
const AMBIENT_DAY_COLOR := Color8(168, 178, 189)
const AMBIENT_DAY_ENERGY := 0.85
const BACKGROUND_DAY_COLOR := Color8(31, 30, 28)
## Top-down interior gameplay hides the ceiling; a flat black clear color keeps
## the room readable instead of letting the outdoor sky dome read through the
## open shell. First-person restores BG_SKY so windows can still show sky.
const BACKGROUND_INTERIOR_TOP_DOWN_COLOR := Color.BLACK

## Deterministic night state carrying the ART_BIBLE rules forward: at least
## 20% darker than day while ambient keeps terrain identities readable.
const SUN_NIGHT_COLOR := Color8(142, 162, 210)
const SUN_NIGHT_ENERGY := 0.42
const AMBIENT_NIGHT_COLOR := Color8(52, 66, 100)
const AMBIENT_NIGHT_ENERGY := 0.5
const BACKGROUND_NIGHT_COLOR := Color8(12, 14, 22)

## Golden-hour and overcast tints blended onto sun/ambient by SkyWeather3D
## lighting modifiers (0 amount reproduces the authored day/night look exactly).
const SUNSET_LIGHT_COLOR := Color8(255, 148, 64)
const OVERCAST_LIGHT_COLOR := Color8(172, 182, 196)

## Shadow cascades only need the max-zoom gameplay frustum, not the authored map
## or the camera far plane. Tighter distance concentrates shadow-map texels on
## the slice the player actually sees.
const SUN_SHADOW_MAX_DISTANCE := (
	MapViewRuntime.ZOOM_MAX_ORTHOGRAPHIC_SIZE * 1.35 + 8.0
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
var _sky_weather: SkyWeather3D
var _last_chimney_bucket: StringName = TIME_DAY
var _environment: Environment
var _camera: Camera3D
var _fog_of_war: Node3D
var _occluder_bounds: Array[AABB] = []
var _interior_shell_occludes := false
var _object_index: MapChunkRuntimeIndex
var _object_streamer: MapObjectChunkStreamer
var _scatter_root: Node3D
var _loaded_scatter_chunks: Dictionary = {}
var _active_chunks: Array[Vector2i] = []


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


func _exit_tree() -> void:
	# WHY: headless/dummy RenderingServer logs ERROR when MultiMeshInstance3D
	# nodes with ShaderMaterial + instance colors are freed while their material
	# RIDs are already invalid. Detach first so teardown stays quiet.
	_strip_geometry_materials(self)


static func _strip_geometry_materials(node: Node) -> void:
	# WHY: nulling material_override while MultiMesh/Mesh still reference the
	# RenderingServer instance triggers dummy-renderer
	# material_get_instance_shader_parameters ERROR. Detach geometry first, leave
	# materials alone so free() does not query a null material RID.
	if node is MultiMeshInstance3D:
		(node as MultiMeshInstance3D).multimesh = null
	elif node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.material_overlay = null
		mesh_instance.mesh = null
	for child in node.get_children():
		_strip_geometry_materials(child)


func _process(delta: float) -> void:
	_sync_sea_weather()
	if _fog_of_war == null:
		return
	var player_rig := get_tree().get_first_node_in_group(&"player_view_rig") as Node3D
	if player_rig == null:
		return
	var facing := Vector2(sin(player_rig.global_rotation.y), cos(player_rig.global_rotation.y))
	_fog_of_war.call("update_view", player_rig.global_position, facing, delta)


func _sync_sea_weather() -> void:
	if _sky_weather == null:
		return
	MapViewMaterials.apply_sea_weather(_sky_weather.wind_strength(), _sky_weather.rain_intensity())


func set_time_of_day(next_time: StringName) -> void:
	assert(next_time in ALL_TIMES)
	apply_cycle_progress(0.5 if next_time == TIME_DAY else 0.0, false)


func set_calendar_date(date: Dictionary) -> void:
	_sky_weather.set_calendar_date(date)
	apply_cycle_progress(cycle_progress)


func apply_cycle_progress(progress: float, _sweep_sun_yaw: bool = true) -> void:
	cycle_progress = wrapf(progress, 0.0, 1.0)
	var sun_direction := SkyWeather3D.solar_direction(cycle_progress, _sky_weather.calendar_date)
	var day_blend := SkyWeather3D.daylight_blend(cycle_progress, _sky_weather.calendar_date)
	var night := day_blend < 0.5

	# DirectionalLight3D emits along local -Z, so local +Z points back toward
	# the celestial body. During twilight the light smoothly hands off between
	# the moving sun and the date-driven moon shown by the sky shader.
	var moon_direction := SkyWeather3D.lunar_direction(
		cycle_progress,
		_sky_weather.calendar_date
	)
	var sun_elevation := SkyWeather3D.solar_elevation_degrees(
		cycle_progress,
		_sky_weather.calendar_date
	)
	var sun_light_weight := smoothstep(-6.0, 0.0, sun_elevation)
	var light_direction := moon_direction.slerp(sun_direction, sun_light_weight).normalized()
	_sun.basis = Basis.looking_at(-light_direction, Vector3.UP)
	# Sky dome follows the cycle first; its weather/golden-hour modifiers then
	# temper the authored day/night lerp so overcast and dusk read in the light.
	_sky_weather.apply_sky_state(cycle_progress, day_blend, sun_direction)
	var weather := _sky_weather.lighting_modifiers()
	var sun_color := SUN_NIGHT_COLOR.lerp(SUN_DAY_COLOR, day_blend)
	sun_color = sun_color.lerp(SUNSET_LIGHT_COLOR, weather["sunset_tint"])
	sun_color = sun_color.lerp(OVERCAST_LIGHT_COLOR, weather["overcast"])
	_sun.light_color = sun_color
	var moonlight := SkyWeather3D.moonlight_strength(cycle_progress, _sky_weather.calendar_date)
	var celestial_energy := lerpf(SUN_NIGHT_ENERGY * moonlight, SUN_DAY_ENERGY, day_blend)
	_sun.light_energy = celestial_energy * weather["sun_energy"]
	var ambient := AMBIENT_NIGHT_COLOR.lerp(AMBIENT_DAY_COLOR, day_blend)
	ambient = ambient.lerp(OVERCAST_LIGHT_COLOR, weather["overcast"] * 0.5)
	_environment.ambient_light_color = ambient
	_environment.ambient_light_energy = lerpf(AMBIENT_NIGHT_ENERGY, AMBIENT_DAY_ENERGY, day_blend) * weather["ambient_energy"]
	# Outdoor / first-person keep the cycle-tinted clear color under the sky
	# dome; interior top-down overrides to a flat black void below.
	_environment.background_color = BACKGROUND_NIGHT_COLOR.lerp(BACKGROUND_DAY_COLOR, day_blend)
	_sync_interior_top_down_background()

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
			smoke.apply_time_of_day(time_of_day)


func _update_window_lights() -> void:
	var buildings := get_node_or_null("Buildings")
	if buildings != null:
		for building_node in buildings.get_children():
			var lights := building_node.get_node_or_null("WindowLights")
			if lights != null and lights.has_method(&"apply_cycle_progress"):
				lights.call("apply_cycle_progress", cycle_progress)
	var landmarks := get_node_or_null("Landmarks")
	if landmarks != null:
		for landmark_node in landmarks.get_children():
			var interior_lights := landmark_node.get_node_or_null("InteriorWindowLights")
			if interior_lights != null and interior_lights.has_method(&"apply_cycle_progress"):
				interior_lights.call("apply_cycle_progress", cycle_progress)
	var props := get_node_or_null("Props")
	if props != null:
		for prop_node in props.get_children():
			var candle := prop_node.get_node_or_null("CandleLight")
			if candle != null and candle.has_method(&"apply_cycle_progress"):
				candle.call("apply_cycle_progress", cycle_progress)


func world_position(logic_position: Vector2, height: float = 0.0) -> Vector3:
	return MapViewBridge.logic_to_world(logic_position, definition.cell_size, height)


func sync_actor(actor: Node3D, logic_position: Vector2) -> void:
	MapViewBridge.sync_actor(actor, logic_position, definition.cell_size)
	# Actors ride the visible terrain relief; authored access zones add only a
	# derived view elevation while the flat logic position stays authoritative.
	actor.position.y = MapViewMeshBuilder.ground_height(
		definition,
		Vector2(actor.position.x, actor.position.z)
	) + MapWallWalkAccess.elevation_at(definition, logic_position)


func anchor_world_position(anchor_id: StringName) -> Vector3:
	return world_position(MapVerification.anchor_position(definition, anchor_id))


func view_camera() -> Camera3D:
	return _camera


## Top-down orthographic gameplay hides the interior ceiling so the player can
## read floor layout; first-person enables the raised shell and occlusion.
func set_interior_shell_for_first_person(enabled: bool) -> void:
	var interior_shell := get_node_or_null("InteriorShell") as Node3D
	if interior_shell == null:
		return
	interior_shell.visible = enabled
	_interior_shell_occludes = enabled
	_rebuild_occluder_bounds()
	_sync_interior_top_down_background()


func is_interior_shell_visible() -> bool:
	var interior_shell := get_node_or_null("InteriorShell") as Node3D
	return interior_shell != null and interior_shell.visible


## Enclosed interiors in top-down view: black clear color instead of sky dome.
## Sun, ambient, and InteriorWindowLights still follow the day/night cycle.
func uses_interior_top_down_background() -> bool:
	return (
		definition != null
		and definition.suppresses_exterior_surroundings()
		and has_node("InteriorShell/Ceiling")
		and not is_interior_shell_visible()
	)


func _sync_interior_top_down_background() -> void:
	if _environment == null:
		return
	if uses_interior_top_down_background():
		_environment.background_mode = Environment.BG_COLOR
		_environment.background_color = BACKGROUND_INTERIOR_TOP_DOWN_COLOR
	else:
		_environment.background_mode = Environment.BG_SKY


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


func sky_weather() -> SkyWeather3D:
	return _sky_weather


func object_streamer() -> MapObjectChunkStreamer:
	return _object_streamer


func update_active_chunks_from_logic_positions(logic_positions: Array[Vector2]) -> void:
	var chunks: Array[Vector2i] = []
	for position in logic_positions:
		var cell := Vector2i(
			floori(position.x / float(definition.cell_size)),
			floori(position.y / float(definition.cell_size))
		)
		var center := grid.chunk_for_cell(cell)
		for y in range(center.y - VIEW_LOAD_RADIUS_CHUNKS, center.y + VIEW_LOAD_RADIUS_CHUNKS + 1):
			for x in range(center.x - VIEW_LOAD_RADIUS_CHUNKS, center.x + VIEW_LOAD_RADIUS_CHUNKS + 1):
				var coordinates := Vector2i(x, y)
				if grid.get_chunk(coordinates) != null and not chunks.has(coordinates):
					chunks.append(coordinates)
	chunks.sort_custom(func(left: Vector2i, right: Vector2i) -> bool:
		return left.y < right.y or (left.y == right.y and left.x < right.x)
	)
	_update_active_chunks(chunks)


## Headless tests and editor preview need every streamed object and scatter
## chunk resident; gameplay keeps the spawn-radius window from _initial_active_chunks.
func activate_all_chunks() -> void:
	var chunks: Array[Vector2i] = []
	var count := grid.chunk_count()
	for chunk_y in count.y:
		for chunk_x in count.x:
			if grid.get_chunk(Vector2i(chunk_x, chunk_y)) != null:
				chunks.append(Vector2i(chunk_x, chunk_y))
	_update_active_chunks(chunks)


func _assemble() -> void:
	add_child(MapViewMeshBuilder.build_surroundings(definition))
	add_child(MapViewMeshBuilder.build_terrain(definition, grid))
	add_child(MapViewMeshBuilder.build_interior_shell(definition))

	_scatter_root = Node3D.new()
	_scatter_root.name = "Scatter"
	add_child(_scatter_root)

	var buildings := Node3D.new()
	buildings.name = "Buildings"
	add_child(buildings)
	var landmarks := Node3D.new()
	landmarks.name = "Landmarks"
	add_child(landmarks)
	var props := Node3D.new()
	props.name = "Props"
	add_child(props)
	var direction_signs := Node3D.new()
	direction_signs.name = "DirectionSigns"
	add_child(direction_signs)

	_object_index = MapChunkRuntimeIndex.build(definition, grid.chunk_size_cells)
	_object_streamer = MapObjectChunkStreamer.new()
	_object_streamer.name = "ObjectStreamer"
	add_child(_object_streamer)
	_object_streamer.configure(_object_index, _create_streamed_object, {
		&"building": buildings,
		&"landmark": landmarks,
		&"prop": props,
		&"direction_sign": direction_signs,
	})
	_update_active_chunks(_initial_active_chunks())

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
				and transition.get("transition_visual", MapTypes.TRANSITION_VISUAL_DOOR) == MapTypes.TRANSITION_VISUAL_DOOR \
				and not MapViewMeshBuilder.transition_uses_landmark_visual(definition, transition):
			var shell_height := MapViewMeshBuilder.interior_shell_wall_height_world(definition)
			doors.add_child(
				MapViewMeshBuilder.build_transition_door(transition, definition.cell_size, shell_height)
			)

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

	# Sky dome + weather cycle; replaces the flat background color with a real
	# sky the first-person camera can see, and feeds lighting modifiers above.
	_sky_weather = SkyWeather3D.new()
	_sky_weather.name = "SkyWeather"
	add_child(_sky_weather)
	_sky_weather.configure(_camera, _environment)

	# Headless uses the dummy renderer, which cannot provide the screen texture
	# sampled by this post-process. Visibility logic remains directly testable.
	if DisplayServer.get_name() != "headless":
		_fog_of_war = FOG_OF_WAR_SCRIPT.new()
		_fog_of_war.call("configure", _camera, definition)
		add_child(_fog_of_war)


func _create_streamed_object(record: Dictionary) -> Node:
	var source := record["source"] as Dictionary
	match record["kind"] as StringName:
		&"building":
			var building_node := MapViewMeshBuilder.build_building(source, definition.cell_size)
			building_node.position.y = MapViewMeshBuilder.ground_height(
				definition,
				Vector2(building_node.position.x, building_node.position.z)
			)
			return building_node
		&"landmark":
			# Interior windows size their opening infill from the wall height;
			# without it they fall back to the default and leave a sky gap
			# between the infill top and the ceiling on taller walls.
			var landmark_node := MapViewMeshBuilder.build_landmark(
				source,
				definition.cell_size,
				MapViewMeshBuilder.interior_shell_wall_height_world(definition)
			)
			landmark_node.position.y = MapViewMeshBuilder.ground_height(
				definition,
				Vector2(landmark_node.position.x, landmark_node.position.z)
			)
			return landmark_node
		&"prop":
			var prop_node := MapViewMeshBuilder.build_prop(source, definition.cell_size, definition)
			# build_prop applies visual_offset_px in world space; keep that lift when
			# snapping the prop root to sampled terrain height.
			var visual_elevation := prop_node.position.y
			prop_node.position.y = MapViewMeshBuilder.ground_height(
				definition,
				Vector2(prop_node.position.x, prop_node.position.z)
			) + visual_elevation
			return prop_node
		&"direction_sign":
			var sign_node := DirectionSignBuilder.build(source, definition.cell_size)
			sign_node.position.y = MapViewMeshBuilder.ground_height(
				definition,
				Vector2(sign_node.position.x, sign_node.position.z)
			)
			return sign_node
	return null


func _initial_active_chunks() -> Array[Vector2i]:
	var focus_cell := Vector2i(
		floori(definition.player_spawn.x / float(definition.cell_size)),
		floori(definition.player_spawn.y / float(definition.cell_size))
	)
	var focus := grid.chunk_for_cell(focus_cell)
	var chunks: Array[Vector2i] = []
	for y in range(focus.y - VIEW_LOAD_RADIUS_CHUNKS, focus.y + VIEW_LOAD_RADIUS_CHUNKS + 1):
		for x in range(focus.x - VIEW_LOAD_RADIUS_CHUNKS, focus.x + VIEW_LOAD_RADIUS_CHUNKS + 1):
			var coordinates := Vector2i(x, y)
			if grid.get_chunk(coordinates) != null:
				chunks.append(coordinates)
	return chunks


func _update_active_chunks(chunks: Array[Vector2i]) -> void:
	_active_chunks = chunks.duplicate()
	_object_streamer.update_active_chunks(chunks)
	_update_scatter_chunks(chunks)
	_rebuild_occluder_bounds()
	_update_chimney_smokes()
	_update_window_lights()


func _update_scatter_chunks(chunks: Array[Vector2i]) -> void:
	var wanted: Dictionary = {}
	for coordinates in chunks:
		wanted[coordinates] = true
	for coordinates in _loaded_scatter_chunks.keys():
		if wanted.has(coordinates):
			continue
		var stale := _loaded_scatter_chunks[coordinates] as Node3D
		_loaded_scatter_chunks.erase(coordinates)
		_scatter_root.remove_child(stale)
		stale.free()
	for coordinates in chunks:
		if _loaded_scatter_chunks.has(coordinates):
			continue
		var scatter := MapViewMeshBuilder.build_scatter(definition, grid, grid.chunk_bounds(coordinates))
		scatter.name = "Chunk_%d_%d" % [coordinates.x, coordinates.y]
		_scatter_root.add_child(scatter)
		_loaded_scatter_chunks[coordinates] = scatter


func _rebuild_occluder_bounds() -> void:
	_occluder_bounds.clear()
	var buildings := get_node_or_null("Buildings") as Node3D
	var landmarks := get_node_or_null("Landmarks") as Node3D
	var interior_shell := get_node_or_null("InteriorShell") as Node3D
	if buildings != null:
		_append_mesh_bounds(buildings, buildings.transform, _occluder_bounds)
	if landmarks != null:
		_append_mesh_bounds(landmarks, landmarks.transform, _occluder_bounds)
	if interior_shell != null and _interior_shell_occludes:
		_append_mesh_bounds(interior_shell, interior_shell.transform, _occluder_bounds)


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
