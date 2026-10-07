class_name CityWorld3D
extends Node3D

## View of the continuous Reval 1343 city (ADR 0031): one terrain, every
## building, the walls and the water in a single scene, so walking between
## districts never crosses a seam or a load. Building shells are merged per
## CHUNK so the draw-call count stays flat; roofs of enterable houses are
## separate nodes so the runtime can lift the roof Kalev is standing under.

const Fort := preload("res://scripts/city/city_fortification_builder.gd")
const WATER_SHADER := preload("res://scripts/city/city_water.gdshader")
const CHUNK := 96.0
const SEA_STEP := 6.0
const BUILDING_RANGE := 1600.0

var plan: CityPlan
var sun: DirectionalLight3D
var environment: Environment
var world_environment: WorldEnvironment
var sky_weather: SkyWeather3D
## building index -> MeshInstance3D roof node (enterable houses only)
var roof_nodes: Dictionary = {}
var water_materials: Array[ShaderMaterial] = []
var doors: CityDoors
var grass: CityGrass
var build_stats: Dictionary = {}


static func create(city_plan: CityPlan) -> CityWorld3D:
	var world := CityWorld3D.new()
	world.name = "CityWorld3D"
	world.plan = city_plan
	world._build()
	return world


func _build() -> void:
	var t0 := Time.get_ticks_usec()
	CityTerrainBuilder.build(plan, self)
	var t1 := Time.get_ticks_usec()
	_build_buildings()
	var t2 := Time.get_ticks_usec()
	Fort.build(plan, self)
	var t3 := Time.get_ticks_usec()
	_build_water()
	CityVegetationBuilder.build(plan, self)
	CityDressingBuilder.build(plan, self)
	doors = CityDoors.create(plan)
	add_child(doors)
	grass = CityGrass.create(plan)
	add_child(grass)
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
	environment.fog_enabled = true
	environment.fog_density = 0.0016
	environment.fog_aerial_perspective = 0.6


func apply_time(progress: float) -> void:
	if sun == null:
		return
	MapViewLighting.apply_cycle_progress(progress, sun, environment, sky_weather, false)
	# One wind for everything that moves: flags, ropes, trees, grass, the sea.
	var day_blend := SkyWeather3D.daylight_blend(progress, sky_weather.calendar_date)
	var presentation := sky_weather.presentation_snapshot(progress, day_blend)
	MapViewMaterials.apply_world_wind(presentation.wind_direction, presentation.wind_strength)
	set_wind(presentation.wind_direction)


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
		var built := CityBuildingBuilder.build_building(b, ring, floor_y, enterable)
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
	# Sea: a grid over every wet cell, vertex colour R = depth hint.
	var sea := _surface_grid(0.0, func(p: Vector2) -> float: return -plan.ground_height(p))
	if sea != null:
		var inst := MeshInstance3D.new()
		inst.name = "Sea"
		inst.mesh = sea
		inst.material_override = _water_material(0.18, 0.0)
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(inst)
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
		var ribbon := _ribbon(
			CityPlan.points(hj["points"]), hj["widths"], float(hj["surface"]) + 0.05
		)
		var r_inst := MeshInstance3D.new()
		r_inst.name = "Harjapea"
		r_inst.mesh = ribbon
		r_inst.material_override = _water_material(0.06, 0.55)
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
			m_inst.material_override = _water_material(0.04, 0.0)
			root.add_child(m_inst)


func _water_material(wave: float, flow: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("wave_strength", wave)
	mat.set_shader_parameter("flow_speed", flow)
	water_materials.append(mat)
	return mat


func set_wind(direction: Vector2) -> void:
	for mat in water_materials:
		mat.set_shader_parameter("wind_dir", direction)


## Grid at `y` over cells where depth_at(p) > 0 (any corner).
func _surface_grid(y: float, depth_at: Callable) -> ArrayMesh:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var normals := PackedVector3Array()
	var r := plan.bounds
	var nx := int(r.size.x / SEA_STEP) + 1
	var nz := int(r.size.y / SEA_STEP) + 1
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
			if not any_wet:
				continue
			var vs: Array[Vector3] = []
			var cs: Array[Color] = []
			for k in 4:
				var c: Vector2 = corners[k]
				vs.append(Vector3(c.x, y, c.y))
				cs.append(Color(clampf(depths[k] / 5.0, 0.0, 1.0), 0, 0))
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
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _ribbon(points: PackedVector2Array, widths: Array, y: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var along := 0.0
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x)
		var wa := float(widths[i]) * 0.5 + 1.0
		var wb := float(widths[i + 1]) * 0.5 + 1.0
		var seg := a.distance_to(b)
		var quad := [a + side * wa, b + side * wb, b - side * wb, a - side * wa]
		var uvs := [
			Vector2(along, 0), Vector2(along + seg, 0), Vector2(along + seg, 1), Vector2(along, 1)
		]
		for idx: int in [0, 1, 2, 0, 2, 3]:
			var q: Vector2 = quad[idx]
			st.set_color(Color(0.35, 0, 0))
			st.set_uv(uvs[idx] / Vector2(10.0, 1.0))
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(q.x, y, q.y))
		along += seg
	return st.commit()


## Water along the ditch: one ribbon whose surface follows the ditch floor
## (a sluiced moat steps down with the ground), mitred at each vertex so
## neighbouring stretches share edges.
func _moat_pools(
	line: PackedVector2Array, width: float, lows: Array[float], cutoff: float
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	var half := width * 0.46
	var edges: Array[Vector2] = []
	for i in line.size():
		var prev := line[maxi(i - 1, 0)]
		var next := line[mini(i + 1, line.size() - 1)]
		var dir := (next - prev).normalized()
		edges.append(Vector2(-dir.y, dir.x) * half)
	for i in line.size() - 1:
		if lows[i] > cutoff and lows[i + 1] > cutoff:
			continue
		var ya := lows[i] + 1.1
		var yb := lows[i + 1] + 1.1
		var a := line[i]
		var b := line[i + 1]
		var quad := [
			Vector3(a.x + edges[i].x, ya, a.y + edges[i].y),
			Vector3(b.x + edges[i + 1].x, yb, b.y + edges[i + 1].y),
			Vector3(b.x - edges[i + 1].x, yb, b.y - edges[i + 1].y),
			Vector3(a.x - edges[i].x, ya, a.y - edges[i].y),
		]
		for idx: int in [0, 1, 2, 0, 2, 3]:
			st.set_color(Color(0.3, 0, 0))
			st.set_normal(Vector3.UP)
			st.add_vertex(quad[idx])
		count += 1
	return st.commit() if count > 0 else null
