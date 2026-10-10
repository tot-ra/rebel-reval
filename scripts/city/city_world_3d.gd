class_name CityWorld3D
extends Node3D

## View of the continuous Reval 1343 city (ADR 0031): one terrain, every
## building, the walls and the water in a single scene, so walking between
## districts never crosses a seam or a load. Building shells are merged per
## CHUNK so the draw-call count stays flat; roofs of enterable houses are
## separate nodes so the runtime can lift the roof Kalev is standing under.

const ShoreField := preload("res://scripts/city/city_shore_field.gd")
const ShoreSpray := preload("res://scripts/city/city_shore_spray.gd")
const Fort := preload("res://scripts/city/city_fortification_builder.gd")
const WATER_SHADER := preload("res://scripts/city/city_water.gdshader")
const MOAT_WATER_SHADER := preload("res://scripts/city/city_moat_water.gdshader")
## Length of the moat's tapered end stretches, metres (see _moat_pools).
const MOAT_TAPER_M := 80.0
const MoatPlants := preload("res://scripts/city/city_moat_plants.gd")
const CHUNK := 96.0
const SEA_STEP := ShoreField.COARSE_STEP
## Storm swell scale for the open 1 m-per-unit sea (district maps use 1.0).
const SEA_WAVE_BOOST := 5.0
## Depth (world units) at which the sea shader's shore factor reaches open water.
const SEA_SHORE_DEPTH := 2.5
## Surf strength on the open 1 m-per-unit Baltic: breaker height and run-up gain over
## the district default (shore_swash.gdshaderinc), so a gale breaks tall and a calm
## day still washes visibly up the sand.
const SURF_WAVE_GAIN := 2.0
const SURF_RUNUP_GAIN := 1.8
## Districts compress surf crests to 0.12 (the water column is centimetres deep); the
## city sea is metres deep, so crests keep nearly their physical height.
const SURF_GEOMETRY_SCALE := 1.3
## Breaker foam gain: a metre-tall surf should be white water along its whole face.
const SURF_FOAM_GAIN := 2.2
## WR-1: rounded spilling crest (shore_crest_shape) instead of the district lip.
const SURF_CREST_SHAPE := 1.0
const BUILDING_RANGE := 1600.0
## The stream ribbon reaches this far (world units) past the waterline into the bank.
const STREAM_BANK_OVERLAP := 1.5
## Farthest a stream bank is probed for the waterline from the trace. The
## upstream end sits on the plan edge where the ground drops ~5 m under the
## stream level, so an unbounded probe would spread a pool across the border.
const STREAM_PROBE_MAX := 16.0
## Trees and bushes need their foot this far above any water surface.
const TREE_WATERLINE_CLEARANCE := 0.25
## Stream grid spacing (world units) along and across the water.
const STREAM_GRID_STEP := 1.5
## Stream vertex depth encoding: COLOR.r = (depth + OFFSET) / SCALE, so the
## bank above the waterline (negative depth) still fades smoothly to zero.
const STREAM_DEPTH_OFFSET := 0.5
const STREAM_DEPTH_SCALE := 2.5

var plan: CityPlan
## Spray emitters on the waterline (CityShoreSpray); null until the sea is built.
var spray: Node3D
var sun: DirectionalLight3D
var environment: Environment
var world_environment: WorldEnvironment
var sky_weather: SkyWeather3D
## True while Kalev is under a roof; reval_city reports it from the plan every
## frame. Gates the same state MapView3D gates for map interiors (R-1539):
## exterior rain particles and rain_exterior ambience off, the muffled roof-drum
## bed on, and no sky reflections, morning mist or rain haze inside.
var enclosed_interior := false
## building index -> MeshInstance3D roof node (enterable houses only)
var roof_nodes: Dictionary = {}
var water_materials: Array[ShaderMaterial] = []
var stream_material: ShaderMaterial
var moat_material: ShaderMaterial
var stream_segment_count := 0
var sea_shore: Dictionary = {}
## WR-3 camera-centred sea rings (CitySeaLod); null until the sea is built.
var sea_lod: CitySeaLod
var doors: CityDoors
var grass: CityGrass
var farmland: CityFarmland
var trail: CityGroundTrail
var build_stats: Dictionary = {}
## Wet moat and stream stretches as [a, b, surface_a, surface_b, half_width] (swimming).
var moat_water: Array = []
## Chimney tops as [Vector3 top, StringName building id] (CityChimneySmoke).
var chimneys: Array = []
var smoke: CityChimneySmoke
## Landmark site models by site id (ADR 0032).
var site_nodes: Dictionary = {}
var ships: CityShips
## _surface_grid(split_rings): 1 per 4 m cell drawn by the rings / by a static
## sea mesh (surf band or the stitched skirt), row-major over the sea lattice.
var _sea_ring_cells := PackedByteArray()
var _sea_static_cells := PackedByteArray()
## WR-9 `shore_*` uniform names of the ground shader (mirror_shore_to_ground).
var _ground_shore_uniforms := PackedStringArray()


static func create(city_plan: CityPlan) -> CityWorld3D:
	var world := CityWorld3D.new()
	world.name = "CityWorld3D"
	world.plan = city_plan
	world._build()
	return world


func _build() -> void:
	var t0 := Time.get_ticks_usec()
	CityBuildingBuilder.bind_ground(plan)
	Fort.bind_ground()
	CityTerrainBuilder.build(plan, self)
	var t1 := Time.get_ticks_usec()
	_build_buildings()
	var t2 := Time.get_ticks_usec()
	Fort.build(plan, self)
	var t3 := Time.get_ticks_usec()
	_build_water()
	CityBridges.build(plan, self)
	CityHarbour.build(plan, self)
	add_child(CityShore.create(plan))
	CityVegetationBuilder.build(plan, self)
	CityDressingBuilder.build(plan, self)
	CityWallFoot.build(plan, self)
	_build_sites()
	doors = CityDoors.create(plan)
	add_child(doors)
	grass = CityGrass.create(plan)
	add_child(grass)
	farmland = CityFarmland.create(plan)
	add_child(farmland)
	trail = CityGroundTrail.create(plan, grass.surface_at)
	add_child(trail)
	smoke = CityChimneySmoke.create(chimneys)
	add_child(smoke)
	ships = CityShips.create(plan)
	add_child(ships)
	var t4 := Time.get_ticks_usec()
	build_stats = {
		"terrain_ms": (t1 - t0) / 1000.0,
		"buildings_ms": (t2 - t1) / 1000.0,
		"fortifications_ms": (t3 - t2) / 1000.0,
		"water_vegetation_ms": (t4 - t3) / 1000.0,
		"buildings": plan.buildings.size(),
		"enterable_roofs": roof_nodes.size(),
	}


## Sun, environment and the shared sky/weather; call after a camera exists.
func setup_lighting(camera: Camera3D) -> void:
	var lighting := MapView3D.create_global_lighting()
	sun = lighting["sun"]
	environment = lighting["environment"]
	world_environment = lighting["world_environment"]
	sun.directional_shadow_max_distance = 170.0
	add_child(sun)
	add_child(world_environment)
	sky_weather = SkyWeather3D.new()
	sky_weather.name = "SkyWeather"
	add_child(sky_weather)
	sky_weather.configure(camera, environment)
	sky_weather.rain_suppressed = enclosed_interior
	environment.fog_enabled = true
	environment.fog_density = 0.0016
	environment.fog_aerial_perspective = 0.6


## Report whether Kalev is indoors; called every frame, so it only remembers the
## flag and pushes the roof gate into the weather. apply_time then forwards it
## to the lighting, which runs per frame anyway.
func set_enclosed_interior(value: bool) -> void:
	enclosed_interior = value
	if sky_weather != null:
		sky_weather.rain_suppressed = value


func apply_time(progress: float) -> void:
	if sun == null:
		return
	MapViewLighting.apply_cycle_progress(
		progress, sun, environment, sky_weather, enclosed_interior
	)
	# Church glass throws coloured sunlight that follows this sun (R-1451).
	ChurchSunlight.push_light(sun)
	# One wind for everything that moves: flags, ropes, trees, grass, the sea.
	var day_blend := SkyWeather3D.daylight_blend(progress, sky_weather.calendar_date)
	var presentation := sky_weather.presentation_snapshot(progress, day_blend)
	MapViewMaterials.apply_world_wind(presentation.wind_direction, presentation.wind_strength)
	MapViewMaterials.apply_sea_weather(
		presentation.wind_strength, presentation.rain_intensity, presentation.wind_direction
	)
	mirror_shore_to_ground()
	if spray != null:
		spray.set_wind(presentation.wind_strength)
	set_wind(presentation.wind_direction)
	var ground := CityTerrainBuilder.shared_material()
	if ground != null:
		ground.set_shader_parameter("puddles", presentation.puddle_wetness)
		ground.set_shader_parameter("rain_intensity", presentation.rain_intensity)
		ground.set_shader_parameter("ground_dryness", presentation.ground_dryness)
		ground.set_shader_parameter(
			"wetness",
			clamp(presentation.rain_intensity * 0.6 + presentation.puddle_wetness * 0.4, 0.0, 1.0)
		)
		if trail != null:
			trail.wetness = clamp(
				presentation.rain_intensity * 0.6 + presentation.puddle_wetness * 0.4, 0.0, 1.0
			)
	# Walls and roofs darken in the rain too.
	CityBuildingBuilder.set_wetness(
		clamp(presentation.rain_intensity * 0.8 + presentation.puddle_wetness * 0.3, 0.0, 1.0)
	)
	smoke.set_time_of_day(MapView3D.TIME_DAY if day_blend > 0.35 else MapView3D.TIME_NIGHT)


## Site building footprints (world XZ) near `ring`: generic roofs must not
## overhang into a landmark (CityBuildingBuilder keep_out).
func _site_keep_out(ring: PackedVector2Array) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var box := Rect2(ring[0], Vector2.ZERO)
	for p in ring:
		box = box.expand(p)
	box = box.grow(1.0)
	for site in plan.sites:
		if not site.bounds().intersects(box):
			continue
		for poly: Array in site.placed.get("footprints", []):
			out.append(CityPlan.points(poly))
	return out


## Landmark sites (ADR 0032): each manifest's visual at its anchor and level.
func _build_sites() -> void:
	for site in plan.sites:
		var visual: Dictionary = site.data.get("visual", {})
		var node: Node3D
		match String(visual.get("kind", "")):
			"builder":
				var script: Script = load(String(visual["script"]))
				node = script.call("build", site, plan)
			"scene":
				node = (load(String(visual["path"])) as PackedScene).instantiate()
		if node == null:
			push_error("City site %s has no visual" % site.id)
			continue
		node.transform = site.transform3d()
		add_child(node)
		site_nodes[site.id] = node


## Hides (or shows) the nodes a site room lists in `hide` (roof, ceiling).
func set_site_room_hidden(site: CitySite, room: Dictionary, hidden: bool) -> void:
	var node: Node3D = site_nodes.get(site.id)
	if node == null:
		return
	for path: String in room.get("hide", []):
		var target := node.get_node_or_null(path) as Node3D
		if target != null:
			target.visible = not hidden


## Occluder index of the site building at `world_xz` (see CityMapView), or -1.
func site_occluder_index(world_xz: Vector2) -> int:
	var index := plan.buildings.size()
	for site in plan.sites:
		var k := site.building_index_at(world_xz)
		if k >= 0:
			return index + k
		index += (site.placed.get("footprints", []) as Array).size()
	return -1


func set_roof_hidden(index: int, hidden: bool) -> void:
	var node: MeshInstance3D = roof_nodes.get(index)
	if node != null:
		node.visible = not hidden


func _build_buildings() -> void:
	var root := Node3D.new()
	root.name = "Buildings"
	add_child(root)
	var chunks: Dictionary = {}
	for i in plan.buildings.size():
		var b: Dictionary = plan.buildings[i]
		var ring := plan.footprint(i)
		if ring.size() < 3:
			continue
		var enterable := bool(b.get("enterable", false))
		var floor_y := plan.floor_height(i)
		var built := CityBuildingBuilder.build_building(
			b, ring, floor_y, enterable, plan.ground_height, _site_keep_out(ring)
		)
		var top: Vector3 = built["chimney"]
		if top != Vector3.INF:
			chimneys.append([top, StringName(b["id"])])
		var center := Vector2.ZERO
		for p in ring:
			center += p
		center /= ring.size()
		var key := Vector2i(floori(center.x / CHUNK), floori(center.y / CHUNK))
		if not chunks.has(key):
			chunks[key] = CityBuildingBuilder.Shell.new()
		var chunk: CityBuildingBuilder.Shell = chunks[key]
		chunk.merge(built["shell"])
		if String(b.get("landmark_id", "")) != "":
			_landmark_extras(chunk, b, ring, built["frame"])
		if enterable:
			var roof_inst := MeshInstance3D.new()
			roof_inst.name = "Roof_%s" % String(b["id"]).replace(".", "_")
			roof_inst.mesh = (built["roof"] as CityBuildingBuilder.Shell).to_mesh(
				CityBuildingBuilder.material_for_key
			)
			roof_inst.visibility_range_end = BUILDING_RANGE
			root.add_child(roof_inst)
			roof_nodes[i] = roof_inst
		else:
			chunk.merge(built["roof"])
	var keys := chunks.keys()
	keys.sort()
	for key: Vector2i in keys:
		var inst := MeshInstance3D.new()
		inst.name = "Chunk_%d_%d" % [key.x, key.y]
		inst.mesh = (chunks[key] as CityBuildingBuilder.Shell).to_mesh(_material_for_key)
		inst.visibility_range_end = BUILDING_RANGE
		root.add_child(inst)


static func _material_for_key(key: String) -> Material:
	if key == "stone":
		return Fort._stone_material()
	return CityBuildingBuilder.material_for_key(key)


## Church towers: St Olaf's stands unfinished (upper stages 1364+) with a
## timber belfry and scaffold; the others get a stone tower and a tiled spire.
func _landmark_extras(
	shell: CityBuildingBuilder.Shell, b: Dictionary, _ring: PackedVector2Array, frame: Dictionary
) -> void:
	var tower_h := float(b.get("tower_h", 0.0))
	if tower_h <= 0.0:
		return
	var r: Vector2 = frame["r"]
	var n: Vector2 = frame["n"]
	var mid: float = frame["mid"]
	var amin: float = frame["amin"]
	var amax: float = frame["amax"]
	# West end (smaller x) carries the tower.
	var end_a := r * amin + n * mid
	var end_b := r * amax + n * mid
	var west := end_a if end_a.x < end_b.x else end_b
	var inward := (end_b - end_a).normalized() * (1.0 if west == end_a else -1.0)
	var size := minf(float(frame["half"]) * 1.3, 8.5)
	var c := west + inward * (size * 0.5)
	var base := float(b["base_h"]) - 0.6
	var top := maxf(float(b["base_h"]) + tower_h, float(frame["ridge"]) + 5.0)
	Fort._obox(shell, "stone", c, r, size * 0.5, size * 0.5, base, top)
	if String(b.get("landmark_id", "")) == "landmark.st_olaf":
		Fort._scaffold(shell, plan, c - r * size * 0.5, c + r * size * 0.5, tower_h, size)
		Fort._obox(shell, "timber", c, r, size * 0.32, size * 0.32, top, top + 4.0)
		Fort._pyramid(shell, "roof", c, r, size * 0.36, size * 0.36, top + 4.0, 3.0)
	else:
		Fort._pyramid(shell, "tile", c, r, size * 0.5 + 0.2, size * 0.5 + 0.2, top, size * 1.6)


func _build_water() -> void:
	var root := Node3D.new()
	root.name = "Water"
	add_child(root)
	# Sea: the surf zone is drawn by the fine band (below); the 4 m cells stitched
	# to it stay a static "skirt" grid (vertex colour R = depth hint), and every
	# other wet cell belongs to the camera-centred rings (WR-3, CitySeaLod).
	var shore: Dictionary = ShoreField.bake(plan)
	sea_shore = shore
	var sea := _surface_grid(
		0.0,
		func(p: Vector2) -> float: return -plan.ground_height(p),
		SEA_SHORE_DEPTH,
		func(_centre: Vector2, corners: Array) -> bool:
			return ShoreField.covers_coarse_cell(shore, plan, corners[0]),
		true
	)
	if sea != null or _sea_ring_cells.has(1):
		var inst := MeshInstance3D.new()
		inst.name = "Sea"
		inst.mesh = sea
		# The district maps' ocean: baked FFT waves, whitecaps, foam, storm swell,
		# caustics and refraction, so the sea reads the same on every map.
		inst.material_override = MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER)
		_bind_shore_field(shore)
		_build_sea_lod(root, inst.material_override)
		# R-1437: physical bathymetry belongs to this mesh, not the cached
		# district material. Instance state keeps shared weather updates intact.
		inst.set_instance_shader_parameter("sea_physical_depth", true)
		inst.extra_cull_margin = ShoreField.SURFACE_CULL_MARGIN
		MapViewMaterials.WATER_MATERIALS.set_wave_height_boost(SEA_WAVE_BOOST)
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(inst)
		var band_index := 0
		for band_mesh in ShoreField.build_band(plan, shore, SEA_SHORE_DEPTH):
			var band := MeshInstance3D.new()
			band.name = "SeaSurfBand%d" % band_index
			band_index += 1
			band.mesh = band_mesh
			band.material_override = inst.material_override
			band.set_instance_shader_parameter("sea_physical_depth", true)
			band.extra_cull_margin = ShoreField.SURFACE_CULL_MARGIN
			band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(band)
	# Open water beyond the plan to the horizon.
	var outer := MeshInstance3D.new()
	outer.name = "OpenSea"
	var plane := PlaneMesh.new()
	plane.size = Vector2(9000, 9000)
	outer.mesh = plane
	# North of the plan only: the Gulf. Land to the east, south and west is the
	# terrain's horizon skirt.
	outer.position = Vector3(plan.bounds.get_center().x, -0.05, plan.bounds.position.y - 4480.0)
	outer.material_override = _water_material(0.22, 0.0)
	outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(outer)
	# The Hareapea stream as a ribbon along its trace.
	var hj: Dictionary = plan.data.get("harjapea", {})
	if not hj.is_empty():
		var trace := CityPlan.points(hj["points"])
		var halves := _stream_wet_halves(trace, hj["widths"], hj["surfaces"])
		var ribbon := _stream_mesh(trace, halves, hj["surfaces"])
		_stream_water(trace, halves, hj["surfaces"])
		stream_segment_count = moat_water.size()
		var r_inst := MeshInstance3D.new()
		r_inst.name = "Harjapea"
		r_inst.mesh = ribbon
		stream_material = _stream_material()
		r_inst.material_override = stream_material
		r_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(r_inst)
	# Moat pools in the lowest stretches of the ditch (1343: mostly dry).
	var moat: Dictionary = plan.data.get("moat", {})
	if not moat.is_empty():
		var line := CityPlan.points(moat["points"])
		var lows: Array[float] = []
		for p in line:
			lows.append(plan.ground_height(p))
		var sorted := lows.duplicate()
		sorted.sort()
		var cutoff: float = sorted[int(
			clampf(float(moat["wet_fraction"]), 0.0, 1.0) * (sorted.size() - 1)
		)]
		var pool_mesh := _moat_pools(line, float(moat["width"]), lows, cutoff)
		if pool_mesh != null:
			var m_inst := MeshInstance3D.new()
			m_inst.name = "MoatPools"
			m_inst.mesh = pool_mesh
			moat_material = _moat_material()
			m_inst.material_override = moat_material
			root.add_child(m_inst)
	# Reeds, cattails and floating plants in the moat and along the stream banks.
	if not moat_water.is_empty():
		root.add_child(MoatPlants.build(plan, moat_water))
	_clear_wet_trees()


## Half width of the stream's water at each trace point, out to where the bank
## climbs above the surface. The plan's channel width is only the flat bed: the
## carved banks stay under the surface for several metres more, so a ribbon cut
## at the bed width ended in a step over a dry pit. The ribbon reaches
## STREAM_BANK_OVERLAP past the waterline; the terrain hides the excess and the
## murky shader's depth rim fades the edge into the mud.
func _stream_wet_halves(
	points: PackedVector2Array, widths: Array, levels: Array
) -> PackedFloat32Array:
	var halves := PackedFloat32Array()
	for i in points.size():
		var side := _ribbon_side(points, i)
		var surface := float(levels[i])
		var wet := float(widths[i]) * 0.5
		for sign: float in [-1.0, 1.0]:
			var d := wet
			while (
				d < STREAM_PROBE_MAX and plan.ground_height(points[i] + side * sign * d) < surface
			):
				d += 0.5
			wet = maxf(wet, d)
		halves.append(wet + STREAM_BANK_OVERLAP)
	return halves


## Stream segments for swimming/wading (same record shape as the moat pools).
## Past the waterline the bank is above the surface, so the extra reach never
## puts Kalev in water on dry ground (water_depth_at clamps at 0).
func _stream_water(points: PackedVector2Array, halves: PackedFloat32Array, levels: Array) -> void:
	for i in points.size() - 1:
		moat_water.append(
			[
				points[i],
				points[i + 1],
				float(levels[i]),
				float(levels[i + 1]),
				(halves[i] + halves[i + 1]) * 0.5
			]
		)


## The plan scatters open-country trees, woods and bank thickets without
## knowing where the stream bed is, so some stood in the water. Drop every tree
## and bush whose foot is under, or within TREE_WATERLINE_CLEARANCE of, a
## stream, moat or sea surface; the reeds and cattails of CityMoatPlants grow
## there instead.
func _clear_wet_trees() -> void:
	for key: String in ["trees", "bushes"]:
		var kept: Array = []
		for t: Array in plan.data.get(key, []):
			var p := Vector2(float(t[0]), float(t[1]))
			if water_surface_at(p) > plan.ground_height(p) - TREE_WATERLINE_CLEARANCE:
				continue
			kept.append(t)
		plan.data[key] = kept


## Murky ditch water with a soft bank edge (city_moat_water.gdshader).
func _moat_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = MOAT_WATER_SHADER
	mat.set_shader_parameter("wave_strength", 0.025)
	mat.set_shader_parameter("flow_speed", 0.0)
	mat.set_shader_parameter("vertex_depth_offset", STREAM_DEPTH_OFFSET)
	mat.set_shader_parameter("vertex_depth_scale", STREAM_DEPTH_SCALE)
	water_materials.append(mat)
	return mat


## Authored humic/silty Hareapea profile, with ripples travelling downstream.
## This peat-brown appearance is a plausible art profile, not a measurement of
## medieval water clarity or a claim about every Estonian river.
func _stream_material() -> ShaderMaterial:
	var mat := _moat_material()
	mat.set_shader_parameter("shallow_color", Color(0.31, 0.29, 0.19))
	mat.set_shader_parameter("deep_color", Color(0.09, 0.09, 0.06))
	mat.set_shader_parameter("mud_color", Color(0.29, 0.23, 0.15))
	mat.set_shader_parameter("deep_depth", 1.0)
	mat.set_shader_parameter("edge_soft", 0.4)
	mat.set_shader_parameter("wave_strength", 0.02)
	mat.set_shader_parameter("flow_speed", 0.35)
	mat.set_shader_parameter("vertex_depth_offset", STREAM_DEPTH_OFFSET)
	mat.set_shader_parameter("vertex_depth_scale", STREAM_DEPTH_SCALE)
	return mat


func _water_material(wave: float, flow: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("wave_strength", wave)
	mat.set_shader_parameter("flow_speed", flow)
	water_materials.append(mat)
	return mat


## WR-3: the camera-centred rings over the cells _surface_grid(split_rings) left
## to them. Their lattice field replaces the old per-cell depth map (it carries
## the depth too), and the graphics tier (MapViewWaterMaterials.sea_lod_preset)
## also sets the shore spray budget.
func _build_sea_lod(root: Node3D, material: Material) -> void:
	var r := plan.bounds
	var preset := MapViewMaterials.WATER_MATERIALS.sea_lod_preset()
	sea_lod = CitySeaLod.new()
	sea_lod.name = "SeaLod"
	sea_lod.configure(
		r.position,
		SEA_STEP,
		Vector2i(int(r.size.x / SEA_STEP) + 1, int(r.size.y / SEA_STEP) + 1),
		_sea_ring_cells,
		_sea_static_cells,
		func(p: Vector2) -> float: return plan.ground_height(p),
		preset,
		material
	)
	root.add_child(sea_lod)
	if spray != null:
		for emitter in spray.get_children():
			if emitter is GPUParticles3D:
				(emitter as GPUParticles3D).amount = int(preset["spray_particles"])


## The surf (bore foam, run-up, quay slosh) is analytic in a shore distance field;
## without one the sea meets the land as a hard cut. The materials are shared with
## the district maps, which rebind their own field, so the city rebinds on tree entry.
func _bind_shore_field(shore: Dictionary) -> void:
	var texture: Texture2D = shore["texture"]
	var origin: Vector2 = shore["origin"]
	var extent: Vector2 = shore["size"]
	MapViewMaterials.apply_shore_field(texture, origin, extent)
	MapViewMaterials.apply_surf_gain(
		SURF_WAVE_GAIN,
		SURF_RUNUP_GAIN,
		SURF_GEOMETRY_SCALE,
		ShoreField.DISTANCE_SCALE,
		SURF_FOAM_GAIN,
		SURF_CREST_SHAPE
	)
	# WR-4: the surf feels the baked bathymetry (bars, reefs, shingle, quays).
	var bed: Texture2D = shore["bed_texture"]
	MapViewMaterials.apply_shore_bed(bed)
	mirror_shore_to_ground()
	spray = ShoreSpray.new()
	spray.name = "ShoreSpray"
	add_child(spray)
	spray.configure(plan, shore["contour"])
	tree_entered.connect(
		func() -> void:
			MapViewMaterials.apply_shore_field(texture, origin, extent)
			MapViewMaterials.apply_surf_gain(
				SURF_WAVE_GAIN,
				SURF_RUNUP_GAIN,
				SURF_GEOMETRY_SCALE,
				ShoreField.DISTANCE_SCALE,
				SURF_FOAM_GAIN,
				SURF_CREST_SHAPE
			)
			MapViewMaterials.apply_shore_bed(bed)
			mirror_shore_to_ground()
	)


## WR-9: the beach (city_ground.gdshader) evaluates the same analytic swash as the
## sea, so it needs the sea's shore uniforms. The ground is not one of the shared
## map-view shore materials, so copy them from the sea after every shore or sea-state
## change (field binding, surf gain, weather, tide). Every `shore_*` uniform the
## ground declares is copied, so new swash uniforms cannot drift out of sync.
func mirror_shore_to_ground() -> void:
	var ground := CityTerrainBuilder.shared_material()
	if ground == null or ground.shader == null or sea_shore.is_empty():
		return
	var sea := MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER)
	# apply_time runs every frame: list the ground's uniforms once.
	if _ground_shore_uniforms.is_empty():
		_ground_shore_uniforms = shore_uniform_names(ground.shader)
	for uniform_name in _ground_shore_uniforms:
		ground.set_shader_parameter(uniform_name, sea.get_shader_parameter(uniform_name))


static func shore_uniform_names(shader: Shader) -> PackedStringArray:
	var names := PackedStringArray()
	for uniform: Dictionary in shader.get_shader_uniform_list():
		var uniform_name := String(uniform["name"])
		if uniform_name.begins_with("shore_"):
			names.append(uniform_name)
	return names


## R-1400: the city sea, stream, moat and harbour water read the discrete cloud
## cells and dim their own direct sun (the shadow pass draws before them).
func apply_cloud_cells(cells: PackedVector4Array) -> void:
	for mat in water_materials:
		mat.set_shader_parameter("cloud_cells", cells)
	MapViewMaterials.apply_cloud_cells(cells)


func set_wind(direction: Vector2) -> void:
	for mat in water_materials:
		mat.set_shader_parameter("wind_dir", direction)
	if ships != null:
		ships.set_wind(direction)


## Grid at `y` over cells where depth_at(p) > 0 (any corner). With split_rings
## (WR-3) only the cells stitched to the fine band are built; the plain cells are
## recorded in _sea_ring_cells for CitySeaLod, band and stitched cells in
## _sea_static_cells.
func _surface_grid(
	y: float, depth_at: Callable, depth_norm := 5.0, skip := Callable(), split_rings := false
) -> ArrayMesh:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var normals := PackedVector3Array()
	var r := plan.bounds
	var nx := int(r.size.x / SEA_STEP) + 1
	var nz := int(r.size.y / SEA_STEP) + 1
	if split_rings:
		_sea_ring_cells = PackedByteArray()
		_sea_ring_cells.resize(nx * nz)
		_sea_static_cells = PackedByteArray()
		_sea_static_cells.resize(nx * nz)
	for j in nz:
		for i in nx:
			var p0 := r.position + Vector2(i, j) * SEA_STEP
			var corners := [
				p0,
				p0 + Vector2(SEA_STEP, 0),
				p0 + Vector2(SEA_STEP, SEA_STEP),
				p0 + Vector2(0, SEA_STEP)
			]
			var depths: Array[float] = []
			var any_wet := false
			for c: Vector2 in corners:
				var d: float = depth_at.call(c)
				depths.append(d)
				if d > -0.4:
					any_wet = true
			var banded := (
				skip.is_valid()
				and (any_wet or split_rings)
				and bool(skip.call(p0 + Vector2(SEA_STEP, SEA_STEP) * 0.5, corners))
			)
			if split_rings and banded:
				# Ring vertices touching any band cell keep its 4 m spacing.
				_sea_static_cells[j * nx + i] = 1
			if not any_wet:
				continue
			# The fine surf band draws this quad instead (CityShoreField.build_band).
			if banded:
				continue
			# Stitch the 4 m sea to the 0.5 m surf band. Both sides must sample the
			# exact same displaced vertices; ownership alone leaves animated cracks.
			var ring: Array[Vector2] = []
			var stitched := false
			for edge in 4:
				var a: Vector2 = corners[edge]
				var b: Vector2 = corners[(edge + 1) % 4]
				var neighbour: Vector2 = (
					p0
					+ [
						Vector2(0, -SEA_STEP),
						Vector2(SEA_STEP, 0),
						Vector2(0, SEA_STEP),
						Vector2(-SEA_STEP, 0)
					][edge]
				)
				var adjacent := [
					neighbour,
					neighbour + Vector2(SEA_STEP, 0),
					neighbour + Vector2.ONE * SEA_STEP,
					neighbour + Vector2(0, SEA_STEP)
				]
				var fine_edge := (
					skip.is_valid()
					and bool(skip.call(neighbour + Vector2.ONE * SEA_STEP * 0.5, adjacent))
				)
				var steps := int(SEA_STEP / ShoreField.BAND_STEP) if fine_edge else 1
				stitched = stitched or fine_edge
				for k in steps:
					ring.append(a.lerp(b, float(k) / steps))
			if split_rings:
				if not stitched:
					_sea_ring_cells[j * nx + i] = 1
					continue
				_sea_static_cells[j * nx + i] = 1
			if stitched:
				var centre := p0 + Vector2.ONE * SEA_STEP * 0.5
				for edge in ring.size():
					for point: Vector2 in [centre, ring[edge], ring[(edge + 1) % ring.size()]]:
						verts.append(Vector3(point.x, y, point.y))
						colors.append(
							Color(clampf(float(depth_at.call(point)) / depth_norm, 0.0, 1.0), 0, 0)
						)
						normals.append(Vector3.UP)
				continue
			var vs: Array[Vector3] = []
			var cs: Array[Color] = []
			for k in 4:
				var c: Vector2 = corners[k]
				vs.append(Vector3(c.x, y, c.y))
				cs.append(Color(clampf(depths[k] / depth_norm, 0.0, 1.0), 0, 0))
			for idx: int in [0, 1, 2, 0, 2, 3]:
				verts.append(vs[idx])
				colors.append(cs[idx])
				normals.append(Vector3.UP)
	if verts.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_NORMAL] = normals
	var bed := PackedVector2Array()
	bed.resize(verts.size())
	for i in verts.size():
		bed[i] = Vector2(0.0, plan.ground_height(Vector2(verts[i].x, verts[i].z)))
	arrays[Mesh.ARRAY_TEX_UV2] = bed
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## `levels` holds the water level at each trace point (the stream runs downhill).
## Stream water as a grid ribbon along `points`, `halves[i]` wide either side
## of each point and mitred at the bends (no overlap or wedge gap). Each vertex
## carries its water depth over the plan ground in COLOR.r (STREAM_DEPTH_SCALE):
## the murky shader's depth-texture column read ~0 in perspective under GL
## Compatibility, so the stream rendered fully clear. Vertex depth needs no
## depth texture and fades the edge where the bank rises out of the water.
func _stream_mesh(
	points: PackedVector2Array, halves: PackedFloat32Array, levels: Array
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var along := 0.0
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var sa := _ribbon_side(points, i) * halves[i]
		var sb := _ribbon_side(points, i + 1) * halves[i + 1]
		var seg := a.distance_to(b)
		var rows := maxi(int(ceil(seg / STREAM_GRID_STEP)), 1)
		var cols := maxi(int(ceil(maxf(halves[i], halves[i + 1]) * 2.0 / STREAM_GRID_STEP)), 2)
		var grid: Array[Vector3] = []
		var colors: Array[Color] = []
		var uvs: Array[Vector2] = []
		for r in rows + 1:
			var t := float(r) / float(rows)
			var centre := a.lerp(b, t)
			var side := sa.lerp(sb, t)
			var surface := lerpf(float(levels[i]), float(levels[i + 1]), t)
			for c in cols + 1:
				var u := float(c) / float(cols)
				var q := centre + side * (u * 2.0 - 1.0)
				var depth := surface - plan.ground_height(q)
				grid.append(Vector3(q.x, surface, q.y))
				colors.append(
					Color(
						clampf((depth + STREAM_DEPTH_OFFSET) / STREAM_DEPTH_SCALE, 0.0, 1.0), 0, 0
					)
				)
				uvs.append(Vector2((along + seg * t) / 10.0, u))
		for r in rows:
			for c in cols:
				var k := r * (cols + 1) + c
				for idx: int in [k, k + cols + 1, k + cols + 2, k, k + cols + 2, k + 1]:
					st.set_color(colors[idx])
					st.set_uv(uvs[idx])
					st.set_normal(Vector3.UP)
					st.add_vertex(grid[idx])
		along += seg
	return st.commit()


## Unit-width mitre at trace point `i`: the mean of the adjacent segment
## normals, lengthened so the ribbon keeps its width through the bend.
func _ribbon_side(points: PackedVector2Array, i: int) -> Vector2:
	var normal := Vector2.ZERO
	if i > 0:
		normal += (points[i] - points[i - 1]).normalized().orthogonal()
	if i < points.size() - 1:
		normal += (points[i + 1] - points[i]).normalized().orthogonal()
	var mitre := normal.normalized()
	var reference := (
		((points[i + 1] - points[i]) if i < points.size() - 1 else (points[i] - points[i - 1]))
		. normalized()
		. orthogonal()
	)
	return mitre / maxf(mitre.dot(reference), 0.5)


## Water along the ditch: one ribbon whose surface follows the ditch floor
## (a sluiced moat steps down with the ground), mitred at each vertex so
## neighbouring stretches share edges.
func _moat_pools(
	line: PackedVector2Array, width: float, lows: Array[float], cutoff: float
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	var half := width * CityPlan.MOAT_WATER_HALF_FACTOR
	# The ditch shallows and narrows over its last MOAT_TAPER_M at both ends
	# (mirrors MOAT_TAPER_M in build_reval_city_plan.py), so the water thins out
	# instead of stopping at a blunt edge.
	var arc: Array[float] = [0.0]
	for i in range(1, line.size()):
		arc.append(arc[i - 1] + line[i].distance_to(line[i - 1]))
	var edges: Array[Vector2] = []
	for i in line.size():
		var prev := line[maxi(i - 1, 0)]
		var next := line[mini(i + 1, line.size() - 1)]
		var dir := (next - prev).normalized()
		var fade := smoothstep(0.0, MOAT_TAPER_M, minf(arc[i], arc[-1] - arc[i]))
		edges.append(Vector2(-dir.y, dir.x) * half * (0.15 + 0.85 * fade))
	for i in line.size() - 1:
		if lows[i] > cutoff and lows[i + 1] > cutoff:
			continue
		var ya := lows[i] + 1.1
		var yb := lows[i + 1] + 1.1
		var a := line[i]
		var b := line[i + 1]
		moat_water.append([a, b, ya, yb, (edges[i].length() + edges[i + 1].length()) * 0.5])
		# Three lateral rows (bank, middle, bank): the ditch floor is deepest in the
		# middle, and a two-row ribbon would interpolate the bank's zero depth
		# across the whole width.
		for lane in 2:
			var l0 := float(lane) - 1.0  # -1 then 0
			var l1 := l0 + 1.0  # 0 then 1
			var quad := [
				Vector3(a.x + edges[i].x * l0, ya, a.y + edges[i].y * l0),
				Vector3(b.x + edges[i + 1].x * l0, yb, b.y + edges[i + 1].y * l0),
				Vector3(b.x + edges[i + 1].x * l1, yb, b.y + edges[i + 1].y * l1),
				Vector3(a.x + edges[i].x * l1, ya, a.y + edges[i].y * l1),
			]
			for idx: int in [0, 1, 2, 0, 2, 3]:
				# Water column baked per vertex (the shader's vertex_depth path): the
				# depth texture read ~0 from low camera pitches, so the moat vanished.
				var v: Vector3 = quad[idx]
				var column := maxf(v.y - plan.ground_height(Vector2(v.x, v.z)), 0.0)
				st.set_color(Color((column + STREAM_DEPTH_OFFSET) / STREAM_DEPTH_SCALE, 0, 0))
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
		count += 1
	return st.commit() if count > 0 else null


## Water surface height at `world_xz` (sea at 0, moat pools at their level),
## or -INF on dry ground.
func water_surface_at(world_xz: Vector2) -> float:
	if plan.ground_height(world_xz) < 0.0:
		return 0.0
	for m: Array in moat_water:
		var a: Vector2 = m[0]
		var b: Vector2 = m[1]
		var ab := b - a
		var t := clampf((world_xz - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		if world_xz.distance_to(a + ab * t) < float(m[4]):
			return lerpf(float(m[2]), float(m[3]), t)
	return -INF


## Rendering medium at the camera. Dry ribbon overlap is not underwater.
func water_medium_at(world_xz: Vector2) -> Dictionary:
	var bed := plan.ground_height(world_xz)
	var surface := water_surface_at(world_xz)
	if surface <= bed:
		return {}
	if bed < 0.0:
		return {
			"surface_y": surface,
			"sea": true,
			"material": MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER)
		}
	for i in moat_water.size():
		var m: Array = moat_water[i]
		var a: Vector2 = m[0]
		var b: Vector2 = m[1]
		if (
			Geometry2D.get_closest_point_to_segment(world_xz, a, b).distance_to(world_xz)
			< float(m[4])
		):
			return {
				"surface_y": surface,
				"sea": false,
				"material": stream_material if i < stream_segment_count else moat_material
			}
	return {}
