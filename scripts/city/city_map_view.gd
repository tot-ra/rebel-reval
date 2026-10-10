class_name CityMapView
extends MapView3D

## MapView3D adapter for the seamless city (ADR 0031). MapViewRuntime talks to
## its view through a small surface (camera, sky, actor sync, occlusion, time);
## this class answers it from CityWorld3D so the city inherits the game's
## three camera modes, actor rigs, magic VFX, swimmer presenter and session
## clock unchanged. Everything else about the old district view stays unused.

## How far ahead of the camera (world units) the ripple window is centred.
const CITY_RIPPLE_FOCUS_AHEAD := 6.0
const CityWaterSurfaceScript := preload("res://scripts/city/city_water_surface.gd")
## WR-5: farthest the waves-around-rocks window centre sits ahead of the camera, where
## its view meets the sea (world units).
const CITY_OBSTACLE_FOCUS_AHEAD := 26.0

var world: CityWorld3D
var plan: CityPlan
## Kalev's current interior (building index) or -1; set by the city scene.
var inside_building := -1
## WR-5 waves around rocks (WaterRippleSim in obstacle mode); null when off.
var water_obstacle_sim: WaterRippleSimScript


static func create_city(city_plan: CityPlan) -> CityMapView:
	var view := CityMapView.new()
	view.name = "MapView3D"
	view.plan = city_plan
	view.definition = CityMapDefinition.from_plan(city_plan)
	view.world = CityWorld3D.create(city_plan)
	view.add_child(view.world)
	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.near = 0.08
	camera.far = 5000.0
	view.add_child(camera)
	camera.current = true
	view._camera = camera
	view.world.setup_lighting(camera)
	view._sun = view.world.sun
	view._environment = view.world.environment
	view._world_environment = view.world.world_environment
	view._sky_weather = view.world.sky_weather
	view._occluder_bounds = view._building_bounds()
	view._create_sky_passes()
	view._create_city_ripple_sim()
	view._create_city_obstacle_sim()
	view._create_city_underwater_pass()
	return view


func _create_city_underwater_pass() -> void:
	_underwater_pass = UnderwaterPassScript.new()
	add_child(_underwater_pass)
	_underwater_pass.configure(_camera, _underwater_probe, _sky_weather.quality_tier)


## CityPlan supplies metre-scale sea, stream and ditch heights; the district grid
## does not exist here. Keep the optical rest plane separate from the camera wave.
func _underwater_probe(world_xz: Vector2) -> Dictionary:
	if inside_building >= 0 or world == null:
		return {}
	var probe := world.water_medium_at(world_xz)
	if probe.is_empty():
		return probe
	var sea := bool(probe["sea"])
	probe["metres_per_unit"] = 1.0
	# The camera tests against the displaced sea the player sees, not the rest plane.
	var surface := float(probe["surface_y"])
	if sea and OceanFftSampler.ensure_loaded():
		surface += CityWaterSurfaceScript.sea_height(world, world_xz)
	probe["local_surface_y"] = surface
	probe["camera_surface_y"] = probe["local_surface_y"]
	probe["wave_margin"] = 0.015
	var material: ShaderMaterial = probe["material"]
	if sea:
		# Same spectral profile and weather multiplier above and below the sea.
		var extinction: Variant = material.get_shader_parameter("physical_extinction")
		var turbidity: Variant = material.get_shader_parameter("water_turbidity")
		probe["extinction_per_m"] = (
			(Vector3(0.40, 0.24, 0.30) if extinction == null else extinction)
			* (1.0 if turbidity == null else float(turbidity))
		)
	else:
		# Authored humic water absorbs blue most; stream and moat stay distinct.
		var depth: Variant = material.get_shader_parameter("deep_depth")
		probe["extinction_per_m"] = (
			Vector3(0.9, 1.4, 2.2) * (1.6 / (1.6 if depth == null else maxf(float(depth), 0.1)))
		)
	probe["lighting_material"] = MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER)
	return probe


## WS-15 wake for the city: the district maps' ripple sim, its window centred
## ahead of the camera on Kalev (the stream and moat lie well above y = 0, so
## the base view's sea-plane ray hit would land far off). It feeds the sea
## material and every city water material (moat and stream), so wading and
## swimming leave a trail in all of them. Off on tiers without the sim.
func _create_city_ripple_sim() -> void:
	var tier: Variant = _sky_weather.quality_tier if _sky_weather != null else null
	if not WaterRippleSimScript.should_create(tier, false, true):
		_bind_city_ripples(null, Vector4(0.0, 0.0, WaterRippleSimScript.WINDOW_WORLD_SIZE, 0.0), 1.0)
		return
	_water_ripple_sim = WaterRippleSimScript.new()
	_water_ripple_sim.name = "WaterRippleSim"
	add_child(_water_ripple_sim)
	_water_ripple_sim.configure(WaterRippleSimScript.sim_size_for_tier(tier))
	_water_ripple_sim.focus_provider = _city_ripple_focus
	_water_ripple_sim.bind_callback = _bind_city_ripples


## WR-5: waves reflect, bend and foam around rocks, the stacks and quays near the camera
## (docs/SYSTEMS/CITY_SEA.md "Waves around rocks"). The mask is the plan's bathymetry
## plus every shore rock CityShore built; the sea material's swell drives the field.
## Coastal plans only, off on the minimum sea tier (the sea keeps its window invalid).
func _create_city_obstacle_sim() -> void:
	var sea := MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER)
	var size := WaterRippleSimScript.obstacle_sim_size_for_tier(
		MapViewMaterials.WATER_MATERIALS.sea_lod_tier()
	)
	if size <= 0 or not plan.has_coast():
		sea.set_shader_parameter(
			"obstacle_window", Vector4(0.0, 0.0, WaterRippleSimScript.WINDOW_WORLD_SIZE, 0.0)
		)
		return
	var mask := CityObstacleMask.new(plan.ground_height, 0.0)
	mask.set_rocks(CityObstacleMask.rocks_from_multimeshes(world))
	water_obstacle_sim = WaterRippleSimScript.new()
	water_obstacle_sim.name = "WaterObstacleSim"
	add_child(water_obstacle_sim)
	water_obstacle_sim.configure_obstacles(size, mask, sea)
	water_obstacle_sim.focus_provider = _city_obstacle_focus
	water_obstacle_sim.bind_callback = func(
		texture: Texture2D, window: Vector4, texels: float
	) -> void:
		sea.set_shader_parameter("obstacle_state", texture)
		sea.set_shader_parameter("obstacle_window", window)
		sea.set_shader_parameter("obstacle_texel_count", texels)


## Where the camera's view meets the sea, at most CITY_OBSTACLE_FOCUS_AHEAD ahead.
func _city_obstacle_focus() -> Vector3:
	if _camera == null or not _camera.is_inside_tree():
		return Vector3.ZERO
	var origin := _camera.global_position
	var forward := -_camera.global_transform.basis.z
	var flat := Vector2(forward.x, forward.z)
	if flat.length() < 0.01:
		return origin
	var reach := CITY_OBSTACLE_FOCUS_AHEAD
	if forward.y < -0.01 and origin.y > 0.0:
		reach = minf(reach, origin.y / -forward.y * flat.length())
	var ahead := flat.normalized() * reach
	return origin + Vector3(ahead.x, 0.0, ahead.y)


## Ground point a few units ahead of the camera along its heading: Kalev in the
## third-person and first-person views, the screen centre seen from above.
func _city_ripple_focus() -> Vector3:
	if _camera == null or not _camera.is_inside_tree():
		return Vector3.ZERO
	var forward := -_camera.global_transform.basis.z
	var flat := Vector2(forward.x, forward.z)
	var origin := _camera.global_position
	if flat.length() < 0.01:
		return origin
	return origin + Vector3(flat.x, 0.0, flat.y).normalized() * CITY_RIPPLE_FOCUS_AHEAD


func _bind_city_ripples(texture: Texture2D, window: Vector4, texel_count: float) -> void:
	_bind_water_ripples(texture, window, texel_count)
	var state := (
		texture if texture != null and window.w > 0.5
		else MapViewMaterials.WATER_MATERIALS.ripple_off_texture()
	)
	var bound := window if texture != null else Vector4(window.x, window.y, window.z, 0.0)
	for mat in world.water_materials:
		mat.set_shader_parameter("ripple_state", state)
		mat.set_shader_parameter("ripple_window", bound)
		mat.set_shader_parameter("ripple_texel_count", maxf(texel_count, 1.0))


## R-1400: the city had a sky but no cloud-shadow or god-ray pass, so clouds threw
## no shadows on Reval. Mount both like MapView3D's view-effects stage; god rays
## rasterise the city's building boxes from the plan's corner (the city is centred
## on the origin). Terrain is left out of that raster: sampling the relief per
## texel over the whole city would stall the first visible frame.
func _create_sky_passes() -> void:
	_create_cloud_shadow_pass()
	_create_city_atmosphere()
	if _sky_weather == null or not GodRayPassScript.should_create(false):
		return
	_god_ray_pass = GodRayPassScript.new()
	add_child(_god_ray_pass)
	_god_ray_pass.configure(
		_camera, plan.bounds.size, func() -> Array[AABB]: return _occluder_bounds, Callable(),
		plan.bounds.position
	)


## Patchy fog on the shore, moat and stream, and horizon heat shimmer. The city always
## has water, so the fog layer probes the plan's sea/moat surface directly.
func _create_city_atmosphere() -> void:
	if _sky_weather == null or not LocalAtmosphereScript.should_create(false):
		return
	_local_atmosphere = LocalAtmosphereScript.new()
	add_child(_local_atmosphere)
	_local_atmosphere.configure(
		_camera,
		Callable(self, &"water_surface_height_at"),
		func(world_xz: Vector2) -> float: return plan.ground_height(world_xz)
	)


func _process(delta: float) -> void:
	if _sky_weather == null:
		return
	if _underwater_pass != null:
		_underwater_pass.update(delta)
	var presentation := _sky_weather.presentation_snapshot(
		cycle_progress, SkyWeather3D.daylight_blend(cycle_progress, _sky_weather.calendar_date)
	)
	if _cloud_shadow_pass != null:
		_cloud_shadow_pass.update_share(presentation)
	if world != null:
		world.apply_cloud_cells(presentation.cloud_cells)
	if _god_ray_pass != null:
		_god_ray_pass.update(delta, presentation)
	if _local_atmosphere != null:
		_local_atmosphere.update(delta, presentation, _sky_weather.cloud_cell_clock())
	if water_obstacle_sim != null and water_obstacle_sim.wave_source != null:
		# Impact foam drifts downwind, faster in a rougher sea.
		var wind: Variant = water_obstacle_sim.wave_source.get_shader_parameter("wind_direction")
		var sea_state: Variant = water_obstacle_sim.wave_source.get_shader_parameter("shore_sea_state")
		if wind is Vector2 and sea_state is float:
			water_obstacle_sim.foam_wind = (wind as Vector2).normalized() * clampf(sea_state, 0.0, 1.0)


func _exit_tree() -> void:
	MapViewMaterials.clear_grass_interaction()
	if water_obstacle_sim != null and water_obstacle_sim.wave_source != null:
		# The sea material is process-wide; do not leave it reading a freed viewport.
		water_obstacle_sim.wave_source.set_shader_parameter(
			"obstacle_window", Vector4(0.0, 0.0, WaterRippleSimScript.WINDOW_WORLD_SIZE, 0.0)
		)


func apply_cycle_progress(progress: float, _sweep_sun_yaw: bool = true) -> void:
	cycle_progress = progress
	world.apply_time(progress)


func set_time_of_day(_next_time: StringName) -> void:
	pass


func set_calendar_date(date: Dictionary) -> void:
	if _sky_weather != null:
		_sky_weather.set_calendar_date(date)
	if world != null and world.farmland != null:
		world.farmland.set_calendar_date(date)
	# Wild plants flower, seed and die back with the same date (R-1557).
	if world != null and world.grass != null:
		world.grass.forbs.set_calendar_date(date)


func sync_actor(actor: Node3D, logic_position: Vector2) -> void:
	var xz := logic_position / float(definition.cell_size)
	var y := plan.walk_height(xz)
	var surface := world.water_surface_at(xz)
	if surface > y:
		# MapViewSwimmerPresenter reads the bed as (actor y - depth): keep the actor
		# at the surface so the rig wades on, and swims over, the real bed.
		y = surface - MapViewMeshBuilderConfig.WATER_SURFACE_LIFT
	actor.position = Vector3(xz.x, y, xz.y)


## Water column above the ground at `world_xz` (0 on dry land), for the player.
func water_depth_at(world_xz: Vector2) -> float:
	return maxf(world.water_surface_at(world_xz) - plan.walk_height(world_xz), 0.0)


## The city runs in logic pixels (32 per world unit); the grass shader wants world XZ.
func update_grass_interaction(logic_position: Vector2, logic_velocity: Vector2) -> void:
	MapViewMaterials.apply_grass_interaction(
		CityPlan.to_world_xz(logic_position), CityPlan.to_world_xz(logic_velocity)
	)


func add_mud_footprint(_logic_position: Vector2, _movement: Vector2) -> bool:
	return false


func add_mud_footprint_at(
	_foot_world_position: Vector3, _movement: Vector2, _apply_lateral_offset: bool = false
) -> bool:
	return false


func mud_wetness() -> float:
	return 0.0


func strike_vegetation(
	_logic_position: Vector2,
	_logic_facing: Vector2,
	_reach_px: float,
	_facing_dot: float,
	_strength: float
) -> Dictionary:
	return {}


func update_terrain_detail_focus(_world_position: Vector3) -> void:
	pass


func set_close_camera_mode(_enabled: bool) -> void:
	pass


func set_interior_shell_for_first_person(_enabled: bool) -> void:
	pass


func set_terrain_detail_for_first_person(_enabled: bool) -> void:
	pass


## Water surface at view XZ: the sea, the stream and the moat sit at sea level
## or their pool level; land returns -INF.
func water_surface_height_at(world_xz: Vector2) -> float:
	var surface := world.water_surface_at(world_xz)
	return surface if surface > -INF else NAN


func water_coverage_at(world_xz: Vector2) -> float:
	return 1.0 if water_depth_at(world_xz) > 0.0 else 0.0


## While Kalev is inside a house its own walls must not count as occluders,
## or the camera would be pushed out through them.
func is_point_inside_occluder(point: Vector3) -> bool:
	for i in _occluder_bounds.size():
		if i == inside_building:
			continue
		if _occluder_bounds[i].has_point(point):
			return true
	return false


func is_segment_occluded(from: Vector3, to: Vector3) -> bool:
	for i in _occluder_bounds.size():
		if i == inside_building:
			continue
		var bounds := _occluder_bounds[i]
		if bounds.has_point(from) or bounds.has_point(to):
			continue
		if bounds.intersects_segment(from, to):
			return true
	return false


## One AABB per building (index-aligned with plan.buildings), walls to eave.
func _building_bounds() -> Array[AABB]:
	var out: Array[AABB] = []
	for i in plan.buildings.size():
		var ring := plan.footprint(i)
		var box := Rect2(ring[0], Vector2.ZERO)
		for p in ring:
			box = box.expand(p)
		var b: Dictionary = plan.buildings[i]
		var y0 := float(b["base_h"]) - 0.5
		var y1 := plan.floor_height(i) + float(b["wall_h"])
		out.append(
			AABB(
				Vector3(box.position.x, y0, box.position.y),
				Vector3(box.size.x, y1 - y0, box.size.y)
			)
		)
	# Then one per site building (ADR 0032), in site order: index
	# plan.buildings.size() + k, as CityWorld3D.site_occluder_index() returns.
	for site in plan.sites:
		var specs: Array = site.data.get("buildings", [])
		var footprints: Array = site.placed.get("footprints", [])
		for k in footprints.size():
			var ring := CityPlan.points(footprints[k])
			var box := Rect2(ring[0], Vector2.ZERO)
			for p in ring:
				box = box.expand(p)
			var y1 := site.level + float((specs[k] as Dictionary).get("wall_h", 6.0))
			out.append(
				AABB(
					Vector3(box.position.x, site.level - 0.5, box.position.y),
					Vector3(box.size.x, y1 - site.level + 0.5, box.size.y)
				)
			)
	return out
