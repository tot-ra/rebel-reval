class_name CityMapView
extends MapView3D

## MapView3D adapter for the seamless city (ADR 0031). MapViewRuntime talks to
## its view through a small surface (camera, sky, actor sync, occlusion, time);
## this class answers it from CityWorld3D so the city inherits the game's
## three camera modes, actor rigs, magic VFX, swimmer presenter and session
## clock unchanged. Everything else about the old district view stays unused.

## How far ahead of the camera (world units) the ripple window is centred.
const CITY_RIPPLE_FOCUS_AHEAD := 6.0

var world: CityWorld3D
var plan: CityPlan
## Kalev's current interior (building index) or -1; set by the city scene.
var inside_building := -1


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
	return view


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


func _exit_tree() -> void:
	MapViewMaterials.clear_grass_interaction()


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
