class_name MapView3D
extends Node3D

const DirectionSignBuilder := preload("res://scripts/map/view3d/direction_sign_3d.gd")
const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")
const Lighting := preload("res://scripts/map/view3d/map_view_lighting.gd")
const SkyWeather3D := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const TerrainDetails := preload("res://scripts/map/view3d/map_view_terrain_details.gd")
const MudFootprints3D := preload("res://scripts/map/view3d/mud_footprints_3d.gd")
## P0-052 3D orthographic view layer (ADR 0007). Assembles terrain, building,
## and prop geometry from an immutable MapDefinition, framed by a fixed
## dimetric orthographic camera under a deterministic day/night sun.
## Pure view: it never mutates the definition, grid, fingerprints, collision,
## navigation, or activation state, and actor positions flow one way from the
## logic plane through MapViewBridge.

const TIME_DAY := &"day"
const TIME_NIGHT := &"night"
const FOG_OF_WAR_SCRIPT := preload("res://scripts/map/view3d/map_fog_of_war.gd")
const StaticBatcher := preload("res://scripts/map/view3d/map_view_static_batcher.gd")
## Plume culling runs on a coarse timer: the camera pans slowly and the extra
## margin hides the seam, so per-frame checks would only add cost.
const SMOKE_CULL_INTERVAL := 0.25
const SMOKE_CULL_MARGIN := 12.0
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
## Compatibility aliases keep MapView3D's public lighting constants stable while
## the focused lighting module owns their implementation.
const SUN_DAY_COLOR := Lighting.SUN_DAY_COLOR
const SUN_DAY_ENERGY := Lighting.SUN_DAY_ENERGY
const AMBIENT_DAY_COLOR := Lighting.AMBIENT_DAY_COLOR
const AMBIENT_DAY_ENERGY := Lighting.AMBIENT_DAY_ENERGY
const BACKGROUND_DAY_COLOR := Lighting.BACKGROUND_DAY_COLOR
const BACKGROUND_INTERIOR_TOP_DOWN_COLOR := Lighting.BACKGROUND_INTERIOR_TOP_DOWN_COLOR
const SUN_NIGHT_COLOR := Lighting.SUN_NIGHT_COLOR
const SUN_NIGHT_ENERGY := Lighting.SUN_NIGHT_ENERGY
const AMBIENT_NIGHT_COLOR := Lighting.AMBIENT_NIGHT_COLOR
const AMBIENT_NIGHT_ENERGY := Lighting.AMBIENT_NIGHT_ENERGY
const BACKGROUND_NIGHT_COLOR := Lighting.BACKGROUND_NIGHT_COLOR
const SUNSET_LIGHT_COLOR := Lighting.SUNSET_LIGHT_COLOR
const OVERCAST_LIGHT_COLOR := Lighting.OVERCAST_LIGHT_COLOR
const LIGHTNING_LIGHT_COLOR := Lighting.LIGHTNING_LIGHT_COLOR
const LIGHTNING_SUN_ENERGY := Lighting.LIGHTNING_SUN_ENERGY
const LIGHTNING_AMBIENT_ENERGY := Lighting.LIGHTNING_AMBIENT_ENERGY
const FOG_MORNING_COLOR := Lighting.FOG_MORNING_COLOR
const FOG_MAX_DENSITY := Lighting.FOG_MAX_DENSITY
const FOG_HEIGHT := Lighting.FOG_HEIGHT
const FOG_MAX_HEIGHT_DENSITY := Lighting.FOG_MAX_HEIGHT_DENSITY
const FOG_HOURS_BEFORE_SUNRISE := Lighting.FOG_HOURS_BEFORE_SUNRISE
const FOG_HOURS_AFTER_SUNRISE := Lighting.FOG_HOURS_AFTER_SUNRISE
const FOG_POTENTIAL_MIN := Lighting.FOG_POTENTIAL_MIN
const FOG_POTENTIAL_FULL := Lighting.FOG_POTENTIAL_FULL
const TONEMAP_MODE := Lighting.TONEMAP_MODE
const GRADE_DAY_EXPOSURE := Lighting.GRADE_DAY_EXPOSURE
const GRADE_DAY_SATURATION := Lighting.GRADE_DAY_SATURATION
const GRADE_DAY_CONTRAST := Lighting.GRADE_DAY_CONTRAST
const GRADE_DAY_BRIGHTNESS := Lighting.GRADE_DAY_BRIGHTNESS
const GRADE_NIGHT_EXPOSURE := Lighting.GRADE_NIGHT_EXPOSURE
const GRADE_NIGHT_SATURATION := Lighting.GRADE_NIGHT_SATURATION
const GRADE_NIGHT_CONTRAST := Lighting.GRADE_NIGHT_CONTRAST
const GRADE_NIGHT_BRIGHTNESS := Lighting.GRADE_NIGHT_BRIGHTNESS
const GLOW_HDR_THRESHOLD := Lighting.GLOW_HDR_THRESHOLD
const GLOW_INTENSITY_DAY := Lighting.GLOW_INTENSITY_DAY
const GLOW_INTENSITY_NIGHT := Lighting.GLOW_INTENSITY_NIGHT
const GLOW_BLOOM := Lighting.GLOW_BLOOM
const GLOW_STRENGTH := Lighting.GLOW_STRENGTH
const GLOW_MIX := Lighting.GLOW_MIX
## Shadow cascades only need the max-zoom gameplay frustum, not the authored map
## or the camera far plane. Tighter distance concentrates shadow-map texels on
## the slice the player actually sees.
const SUN_SHADOW_MAX_DISTANCE := MapViewRuntime.ZOOM_MAX_ORTHOGRAPHIC_SIZE * 1.35 + 8.0
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
var _world_environment: WorldEnvironment
var _environment_binding_active := true
var _camera: Camera3D
var _smoke_cull_timer := 0.0
var _fog_of_war: Node3D
var _occluder_bounds: Array[AABB] = []
var _object_index: MapChunkRuntimeIndex
var _object_streamer: MapObjectChunkStreamer
var _scatter_root: Node3D
var _loaded_scatter_chunks: Dictionary = {}
var _active_chunks: Array[Vector2i] = []
var _last_puddle_visible := false
var _first_person_terrain_detail := false
var _terrain_detail_focus_cell := Vector2i(2147483647, 2147483647)
var _decals_node: Node3D
var _mud_footprints: MudFootprints3D

static func create(
	map_definition: MapDefinition, built_grid: MapTerrainGrid, initial_time: StringName = TIME_DAY
) -> MapView3D:
	var view := MapView3D.new()
	view.name = "MapView3D_%s" % String(map_definition.map_id)
	view.definition = map_definition
	view.grid = built_grid
	view._assemble()
	view.set_time_of_day(initial_time)
	return view


func _exit_tree() -> void:
	# The grass material is cached across map views. Clear its dynamic player
	# parameters before this view disappears so a menu or another map cannot
	# retain the last character's bent patch.
	MapViewMaterials.clear_grass_interaction()
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
	_sync_puddle_visibility()
	_cull_offscreen_smoke(delta)
	if _fog_of_war == null:
		return
	var player_rig := get_tree().get_first_node_in_group(&"player_view_rig") as Node3D
	if player_rig == null:
		return
	var facing := Vector2(sin(player_rig.global_rotation.y), cos(player_rig.global_rotation.y))
	_fog_of_war.call("update_view", player_rig.global_position, facing, delta)


## A chimney plume costs the renderer per-system work whether or not it is on
## screen, and a district carries dozens of them. Measured on the workers
## quarter, drawing every plume cost ~6 ms per frame while the particle count
## itself was irrelevant, so visibility - not particle budget - is the lever.
func _cull_offscreen_smoke(delta: float) -> void:
	if _camera == null:
		return
	_smoke_cull_timer -= delta
	if _smoke_cull_timer > 0.0:
		return
	_smoke_cull_timer = SMOKE_CULL_INTERVAL
	var buildings := get_node_or_null("Buildings")
	if buildings == null:
		return
	var to_camera := _camera.global_transform.affine_inverse()
	for building_node in buildings.get_children():
		var smoke := building_node.get_node_or_null("ChimneySmoke") as ChimneySmoke3D
		if smoke == null or not smoke.emitting:
			continue
		smoke.visible = _within_smoke_view(to_camera, smoke.global_position)


func _within_smoke_view(to_camera: Transform3D, world_position: Vector3) -> bool:
	var local := to_camera * world_position
	if local.z > 0.0:
		return false
	if _camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		return _camera.is_position_in_frustum(world_position)
	var half_height := _camera.size * 0.5 + SMOKE_CULL_MARGIN
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := maxf(viewport_size.x / maxf(viewport_size.y, 1.0), 0.1)
	return absf(local.x) <= half_height * aspect and absf(local.y) <= half_height


func _sync_sea_weather() -> void:
	if _sky_weather == null:
		return
	MapViewMaterials.apply_sea_weather(_sky_weather.wind_strength(), _sky_weather.rain_intensity())
	MapViewMaterials.apply_mud_wetness(_sky_weather.mud_wetness())
	# Vegetation, sails, and tower pennants share the same weather wind field as
	# floating hulls so a storm leans the whole harbor one way.
	MapViewMaterials.apply_world_wind(
		_sky_weather.wind_direction_xz(), _sky_weather.wind_strength()
	)


## Puddle geometry remains prebuilt with each scatter chunk, but a fresh map is
## dry. Rain-created wetness reveals it without rebuilding deterministic terrain.
func _sync_puddle_visibility(force: bool = false) -> void:
	if _sky_weather == null or _scatter_root == null:
		return
	var puddle_visible := _sky_weather.puddle_wetness() > 0.001
	if not force and puddle_visible == _last_puddle_visible:
		return
	_last_puddle_visible = puddle_visible
	for chunk in _scatter_root.get_children():
		var puddles := chunk.get_node_or_null("Puddles") as Node3D
		if puddles != null:
			puddles.visible = puddle_visible


func set_time_of_day(next_time: StringName) -> void:
	assert(next_time in ALL_TIMES)
	apply_cycle_progress(0.5 if next_time == TIME_DAY else 0.0, false)


func set_calendar_date(date: Dictionary) -> void:
	_sky_weather.set_calendar_date(date)
	apply_cycle_progress(cycle_progress)


## Scales (or, at 0, pauses) the sky's own time so clouds, weather, and lightning
## keep step with the day/night clock under the shared time controls.
func set_weather_time_scale(scale: float) -> void:
	if _sky_weather != null:
		_sky_weather.time_scale = maxf(scale, 0.0)


func apply_cycle_progress(progress: float, _sweep_sun_yaw: bool = true) -> void:
	cycle_progress = wrapf(progress, 0.0, 1.0)
	var night := Lighting.apply_cycle_progress(
		cycle_progress,
		_sun,
		_environment,
		_sky_weather,
		uses_interior_top_down_background(),
		definition != null and definition.suppresses_exterior_surroundings()
	)
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
			# Candles and forge hearth lights both expose apply_cycle_progress.
			for child in prop_node.get_children():
				if child.has_method(&"apply_cycle_progress"):
					child.call("apply_cycle_progress", cycle_progress)


func world_position(logic_position: Vector2, height: float = 0.0) -> Vector3:
	return MapViewBridge.logic_to_world(logic_position, definition.cell_size, height)


func sync_actor(actor: Node3D, logic_position: Vector2) -> void:
	MapViewBridge.sync_actor(actor, logic_position, definition.cell_size)
	# Actors ride the visible terrain relief; authored wall-walk access and
	# climbable low props add only a derived view elevation while the flat
	# logic position stays authoritative.
	var surface_elevation := maxf(
		MapWallWalkAccess.elevation_at(definition, logic_position),
		MapClimbableProps.elevation_at(definition, logic_position)
	)
	actor.position.y = (
		MapViewMeshBuilder.ground_height(definition, Vector2(actor.position.x, actor.position.z))
		+ surface_elevation
	)


func add_mud_footprint(logic_position: Vector2, movement: Vector2) -> bool:
	var position := world_position(logic_position)
	return add_mud_footprint_at(position, movement, true)


## Places a print under an animated foot bone. Terrain is sampled at that foot,
## not at the actor pivot, so a boot crossing a mud boundary leaves contact only
## where the sole actually lands.
func add_mud_footprint_at(
	foot_world_position: Vector3,
	movement: Vector2,
	apply_lateral_offset: bool = false
) -> bool:
	if _mud_footprints == null or grid == null or _sky_weather == null:
		return false
	var logic_position := MapViewBridge.world_to_logic(foot_world_position, definition.cell_size)
	var cell := Vector2i(
		floori(logic_position.x / float(definition.cell_size)),
		floori(logic_position.y / float(definition.cell_size))
	)
	if grid.get_terrain(cell) != MapTypes.TERRAIN_MUD:
		return false
	foot_world_position.y = MapViewMeshBuilder.ground_height(
		definition, Vector2(foot_world_position.x, foot_world_position.z)
	)
	return _mud_footprints.try_add(
		foot_world_position,
		movement,
		_sky_weather.mud_wetness(),
		apply_lateral_offset
	)


## Pushes the shared grass MultiMesh material so blades part around the player.
## Logic velocity is scaled to world XZ so walk/run wake strength stays readable.
func update_grass_interaction(logic_position: Vector2, logic_velocity: Vector2) -> void:
	var world := world_position(logic_position)
	var scale := MapViewBridge.world_scale(definition.cell_size)
	var world_velocity := Vector2(logic_velocity.x, logic_velocity.y) * scale
	MapViewMaterials.apply_grass_interaction(Vector2(world.x, world.z), world_velocity)


func mud_wetness() -> float:
	return _sky_weather.mud_wetness() if _sky_weather != null else 0.0


func anchor_world_position(anchor_id: StringName) -> Vector3:
	return world_position(MapVerification.anchor_position(definition, anchor_id))


func view_camera() -> Camera3D:
	return _camera


## Runtime toggles for authored prop stable IDs (P4-032 market-day density).
func set_prop_visible(prop_id: StringName, visible_state: bool) -> void:
	var props := get_node_or_null("Props") as Node3D
	if props == null or prop_id.is_empty():
		return
	var prop_node := props.get_node_or_null("Prop_%s" % String(prop_id)) as Node3D
	if prop_node != null:
		prop_node.visible = visible_state


## Close perspective cameras show the interior ceiling and nearby surface detail;
## top-down orthographic gameplay hides both so the floor layout stays readable.
## The shadows-only daylight occluder remains active in every mode.
func set_close_camera_mode(enabled: bool) -> void:
	set_terrain_detail_for_first_person(enabled)
	var interior_shell := get_node_or_null("InteriorShell") as Node3D
	if interior_shell == null:
		return
	for child in interior_shell.get_children():
		if child is Node3D and child.name != &"DaylightOccluder":
			(child as Node3D).visible = enabled
	var daylight_occluder := interior_shell.get_node_or_null("DaylightOccluder") as Node3D
	if daylight_occluder != null:
		daylight_occluder.visible = true
	_sync_interior_top_down_background()


## Compatibility wrapper for existing first-person callers and focused view tests.
func set_interior_shell_for_first_person(enabled: bool) -> void:
	set_close_camera_mode(enabled)


## Surface micro-geometry is deliberately camera-dependent: first-person needs
## parallax and silhouettes near the player, while top-down relies on the
## continuous high-resolution ground material. Detail roots are rebuilt instead
## of retaining hidden duplicate MultiMeshes for every streamed chunk.
func set_terrain_detail_for_first_person(enabled: bool) -> void:
	if _first_person_terrain_detail == enabled:
		return
	_first_person_terrain_detail = enabled
	_terrain_detail_focus_cell = Vector2i(2147483647, 2147483647)
	_rebuild_terrain_details()


## Keep first-person micro geometry in a bounded cell window around the camera.
## Moving within a small bucket does no work; crossing it rebuilds only detail,
## not terrain, props, collisions, or rrmap-derived gameplay state.
func update_terrain_detail_focus(world_position: Vector3) -> void:
	if not _first_person_terrain_detail:
		return
	var focus_cell := Vector2i(floori(world_position.x), floori(world_position.z))
	var step := MapViewMeshBuilderConfig.FIRST_PERSON_DETAIL_REBUILD_STEP_CELLS
	var bucket := Vector2i(floori(float(focus_cell.x) / step), floori(float(focus_cell.y) / step))
	var previous_bucket := Vector2i(
		floori(float(_terrain_detail_focus_cell.x) / step),
		floori(float(_terrain_detail_focus_cell.y) / step)
	)
	if bucket == previous_bucket:
		return
	_terrain_detail_focus_cell = focus_cell
	_rebuild_terrain_details()


func uses_first_person_terrain_detail() -> bool:
	return _first_person_terrain_detail


func is_interior_shell_visible() -> bool:
	var ceiling := get_node_or_null("InteriorShell/Ceiling") as Node3D
	return ceiling != null and ceiling.visible


## Compatibility wrapper retained for focused tests and existing callers.
static func _morning_mist_factor(hour: float, sunrise: float) -> float:
	return Lighting.morning_mist_factor(hour, sunrise)


func uses_interior_top_down_background() -> bool:
	return (
		definition != null
		and definition.suppresses_exterior_surroundings()
		and has_node("InteriorShell/Ceiling")
		and not is_interior_shell_visible()
	)


func _sync_interior_top_down_background() -> void:
	Lighting.sync_background(_environment, uses_interior_top_down_background())


## True when a building or landmark mass crosses the segment. The runtime
## probes from an actor toward the camera to decide when the occluded-actor
## silhouette overlay should show.
## WHY: skip volumes that already contain an endpoint. A follow camera that
## clips into a wall AABB would otherwise always report occlusion, and solid
## house boxes would ghost anyone standing inside their footprint.
func is_segment_occluded(from: Vector3, to: Vector3) -> bool:
	for bounds in _occluder_bounds:
		if bounds.has_point(from) or bounds.has_point(to):
			continue
		if bounds.intersects_segment(from, to):
			return true
	return false


func is_point_inside_occluder(point: Vector3) -> bool:
	for bounds in _occluder_bounds:
		if bounds.has_point(point):
			return true
	return false


func sun_light() -> DirectionalLight3D:
	return _sun


func sky_weather() -> SkyWeather3D:
	return _sky_weather


func environment_weather() -> SkyWeather3D:
	return _sky_weather


## The session owner keeps the simulation alive across map presenters. A view
## only owns this renderer binding while it is the active map.
func activate_environment_binding() -> void:
	_environment_binding_active = true
	set_process(true)
	if _world_environment != null:
		_world_environment.environment = _environment
	if _sky_weather != null:
		_sky_weather.set_process(true)


func deactivate_environment_binding() -> void:
	_environment_binding_active = false
	set_process(false)
	if _world_environment != null:
		_world_environment.environment = null
	if _sky_weather != null:
		_sky_weather.set_process(false)


func environment_binding_active() -> bool:
	return _environment_binding_active


func environment_node() -> WorldEnvironment:
	return _world_environment


func set_weather_rain_suppressed(suppressed: bool) -> void:
	if _sky_weather != null:
		_sky_weather.rain_suppressed = suppressed


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
			for x in range(
				center.x - VIEW_LOAD_RADIUS_CHUNKS, center.x + VIEW_LOAD_RADIUS_CHUNKS + 1
			):
				var coordinates := Vector2i(x, y)
				if grid.get_chunk(coordinates) != null and not chunks.has(coordinates):
					chunks.append(coordinates)
	chunks.sort_custom(
		func(left: Vector2i, right: Vector2i) -> bool:
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
	# P0-157: projected decals (soot, mud, blood) from map data.
	_decals_node = MapViewDecals.build_decals(definition, definition.cell_size)
	add_child(_decals_node)
	var direction_signs := Node3D.new()
	direction_signs.name = "DirectionSigns"
	add_child(direction_signs)

	_object_index = MapChunkRuntimeIndex.build(definition, grid.chunk_size_cells)
	_object_streamer = MapObjectChunkStreamer.new()
	_object_streamer.name = "ObjectStreamer"
	add_child(_object_streamer)
	(
		_object_streamer
		. configure(
			_object_index,
			_create_streamed_object,
			{
				&"building": buildings,
				&"landmark": landmarks,
				&"prop": props,
				&"direction_sign": direction_signs,
			}
		)
	)
	_update_active_chunks(_initial_active_chunks())

	var transition_markers := Node3D.new()
	transition_markers.name = "TransitionMarkers"
	add_child(transition_markers)
	var doors := Node3D.new()
	doors.name = "Doors"
	add_child(doors)
	for transition in definition.transitions:
		if bool(transition.get("highlight_area", false)):
			transition_markers.add_child(
				MapViewMeshBuilder.build_transition_marker(transition, definition.cell_size)
			)
		if (
			not String(transition.get("destination_scene_id", "")).is_empty()
			and (
				transition.get("transition_visual", MapTypes.TRANSITION_VISUAL_DOOR)
				== MapTypes.TRANSITION_VISUAL_DOOR
			)
			and not MapViewMeshBuilder.transition_uses_landmark_visual(definition, transition)
		):
			var attached_building := MapBuildingEntrance.find_building(definition, transition)
			var wall_height := MapViewMeshBuilder.interior_shell_wall_height_world(definition)
			if not attached_building.is_empty():
				wall_height = (
					MapTypes.resolved_wall_height_px(attached_building)
					* MapViewBridge.world_scale(definition.cell_size)
				)
			doors.add_child(
				MapViewMeshBuilder.build_transition_door(
					transition, definition.cell_size, wall_height, attached_building
				)
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
	Lighting.configure_post_process(_environment)
	_world_environment = WorldEnvironment.new()
	_world_environment.name = "ViewEnvironment"
	_world_environment.environment = _environment
	add_child(_world_environment)

	_camera = _create_camera()
	add_child(_camera)

	# Sky dome + weather cycle; replaces the flat background color with a real
	# sky the first-person camera can see, and feeds lighting modifiers above.
	_sky_weather = SkyWeather3D.new()
	_sky_weather.name = "SkyWeather"
	add_child(_sky_weather)
	_sky_weather.configure(_camera, _environment)
	# Enclosed room shells (roofed interiors like the Kalev smithy) must not rain
	# indoors. The weather cycle keeps running for lighting and wind; only the
	# visible rain particles are gated; roof-drum audio follows the same flag.
	_sky_weather.rain_suppressed = (
		definition != null and definition.suppresses_exterior_surroundings()
	)
	_mud_footprints = MudFootprints3D.new()
	_mud_footprints.name = "MudFootprints"
	add_child(_mud_footprints)
	_sync_puddle_visibility(true)

	# Headless uses the dummy renderer, which cannot provide the screen texture
	# sampled by this post-process. Visibility logic remains directly testable.
	if DisplayServer.get_name() != "headless":
		_fog_of_war = FOG_OF_WAR_SCRIPT.new()
		_fog_of_war.call("configure", _camera, definition)
		add_child(_fog_of_war)


func _create_streamed_object(record: Dictionary) -> Node:
	var node := _build_streamed_object(record)
	if node is Node3D:
		var node_3d := node as Node3D
		StaticBatcher.trim_small_shadow_casters(node_3d)
		# Merging happens on the assembled view only, so builder-level tests and
		# tools still see every authored detail node.
		StaticBatcher.merge(node_3d)
	return node


func _build_streamed_object(record: Dictionary) -> Node:
	var source := record["source"] as Dictionary
	match record["kind"] as StringName:
		&"building":
			var entrances: Array[Dictionary] = []
			for transition in definition.transitions:
				if transition.get("building_id", &"") == source.get("id", &""):
					entrances.append(transition)
			var building_node := MapViewMeshBuilder.build_building(
				source,
				definition.cell_size,
				entrances,
				Rect2(Vector2.ZERO, definition.world_size())
			)
			building_node.position.y = MapViewMeshBuilder.ground_height(
				definition, Vector2(building_node.position.x, building_node.position.z)
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
				definition, Vector2(landmark_node.position.x, landmark_node.position.z)
			)
			return landmark_node
		&"prop":
			var prop_node := MapViewMeshBuilder.build_prop(source, definition.cell_size, definition)
			# build_prop applies visual_offset_px in world space; keep that lift when
			# snapping the prop root to sampled terrain height.
			var visual_elevation := prop_node.position.y
			prop_node.position.y = (
				MapViewMeshBuilder.ground_height(
					definition, Vector2(prop_node.position.x, prop_node.position.z)
				)
				+ visual_elevation
			)
			return prop_node
		&"direction_sign":
			var sign_node := DirectionSignBuilder.build(source, definition.cell_size)
			sign_node.position.y = MapViewMeshBuilder.ground_height(
				definition, Vector2(sign_node.position.x, sign_node.position.z)
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
		var scatter := MapViewMeshBuilder.build_scatter(
			definition, grid, grid.chunk_bounds(coordinates)
		)
		scatter.name = "Chunk_%d_%d" % [coordinates.x, coordinates.y]
		_scatter_root.add_child(scatter)
		_loaded_scatter_chunks[coordinates] = scatter
	_sync_puddle_visibility(true)
	_rebuild_terrain_details()


func _rebuild_terrain_details() -> void:
	for coordinates in _loaded_scatter_chunks:
		var scatter := _loaded_scatter_chunks[coordinates] as Node3D
		var current := scatter.get_node_or_null("TerrainDetails") as Node3D
		if current != null:
			scatter.remove_child(current)
			current.free()
		# Top-down needs no per-cell detail nodes: the high-resolution seamless
		# terrain material carries the paving and grass pattern at that distance.
		if not _first_person_terrain_detail:
			continue
		var radius := MapViewMeshBuilderConfig.FIRST_PERSON_DETAIL_BUILD_RADIUS_CELLS
		var focus_bounds := Rect2i(
			_terrain_detail_focus_cell - Vector2i(radius, radius),
			Vector2i(radius * 2 + 1, radius * 2 + 1)
		)
		var bounds := grid.chunk_bounds(coordinates).intersection(focus_bounds)
		if bounds.size == Vector2i.ZERO:
			continue
		scatter.add_child(TerrainDetails.build_chunk(definition, grid, bounds, true))


func _rebuild_occluder_bounds() -> void:
	_occluder_bounds.clear()
	var buildings := get_node_or_null("Buildings") as Node3D
	var landmarks := get_node_or_null("Landmarks") as Node3D
	if buildings != null:
		_append_mesh_bounds(buildings, buildings.transform, _occluder_bounds)
	if landmarks != null:
		_append_mesh_bounds(landmarks, landmarks.transform, _occluder_bounds)
	# InteriorShell (ceiling, beams, daylight twin) is presentation/solar only.
	# Its room-sized AABBs are not outdoor building masses and must not drive
	# the occluded-actor silhouette.


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


static func _append_mesh_bounds(
	node: Node3D, accumulated: Transform3D, bounds: Array[AABB]
) -> void:
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
	camera.size = (
		diagonal * absf(sin(deg_to_rad(CAMERA_PITCH_DEGREES))) * CAMERA_MARGIN + CAMERA_HEADROOM
	)
	camera.far = CAMERA_FAR
	var center := Vector3(world_units.x * 0.5, 0.0, world_units.y * 0.5)
	camera.position = center + camera.transform.basis.z * CAMERA_DISTANCE
	camera.current = true
	return camera
