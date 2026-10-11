extends "res://tests/godot/test_case.gd"

## WR-3 (R-1508, docs/SYSTEMS/CITY_SEA.md "LOD"): camera-centred sea rings. The
## morph below is a line-for-line port of _sea_lod_vertex / _sea_lod_level_at in
## map_view_water.gdshader, run on a synthetic lattice: an island of land ringed
## by static skirt cells in open water.

const WaterMaterials := preload("res://scripts/map/view3d/map_view_water_materials.gd")
const WATER_SHADER := "res://scripts/map/view3d/map_view_water.gdshader"
const SANDBOX := "res://tools/water_sandbox/water_sandbox.gd"
const WaterSurface := preload("res://scripts/city/city_water_surface.gd")
const SNAP := 0.9995
const CELLS := Vector2i(160, 160)
const ISLAND := Rect2i(100, 100, 8, 8)
const SKIRT := 2
const EYES: Array[Vector3] = [
	Vector3(20.0, 3.0, 30.0),
	Vector3(380.0, 1.7, 400.0),
	Vector3(130.0, 2.0, 100.0),
	Vector3(-30.0, 10.0, -30.0),
]


func after_each() -> void:
	# The water materials are shared; leave the LOD off and undo the city's storm
	# swell boost (the sandbox build sets it) for later tests.
	WaterMaterials.set_wave_height_boost(1.0)
	WaterMaterials.apply_sea_lod(
		Vector4(0.0, 0.0, 4.0, 0.0), Vector4(1.0, 64.0, 2.0, 6.0), WaterMaterials.sea_lod_preset()
	)
	super.after_each()


func _lod() -> CitySeaLod:
	var rings := PackedByteArray()
	var statics := PackedByteArray()
	rings.resize(CELLS.x * CELLS.y)
	statics.resize(CELLS.x * CELLS.y)
	var skirt := ISLAND.grow(SKIRT)
	for j in CELLS.y:
		for i in CELLS.x:
			var c := Vector2i(i, j)
			if ISLAND.has_point(c):
				continue
			if skirt.has_point(c):
				statics[j * CELLS.x + i] = 1
			else:
				rings[j * CELLS.x + i] = 1
	var preset := {
		"base_spacing": 1.0,
		"ring_range": 16.0,
		"rings": 6,
		"displacement_cascades": 2,
		"foam_detail_layers": 4,
		"spray_particles": 1,
	}
	var lod := CitySeaLod.new()
	lod.configure(
		Vector2(-8.0, 12.0), 4.0, CELLS, rings, statics,
		func(p: Vector2) -> float: return -3.0 - 0.01 * p.x, preset, null
	)
	return lod


## Port of _sea_lod_level_at.
func _level_at(lod: CitySeaLod, q: Vector2, on_cells: bool) -> float:
	var xz := lod.lattice_origin + q * lod.base_spacing
	var shore := float(lod.shore_level)
	var d := Vector3(xz.x, 0.0, xz.y).distance_to(lod.eye)
	var level := maxf(
		CitySeaLod.ring_level(d, lod.ring_range, lod.last_level), shore * lod.field_at(xz).z
	)
	var cap := shore
	if on_cells:
		var a := lod._texel(Vector2i((q / lod._cell_span()).round())).w
		cap = shore + a - (CitySeaLod.DRAWN if a >= CitySeaLod.DRAWN - 0.5 else 0.0)
	return minf(level, minf(cap, float(lod.last_level)))


## Port of _sea_lod_vertex: (lattice g.x, g.y, mesh level).
func _morph(lod: CitySeaLod, node: Vector4, local: Vector2) -> Vector3:
	var span := node.w
	var g0 := (Vector2(node.x, node.y) * CitySeaLod.NODE_QUADS + local) * span
	var g := g0
	var level := node.z
	var previous := 1.0
	var mesh_level := level
	for k in 16:
		if level + k >= lod.last_level:
			break
		var q := g0 - _mod(g0, span)
		var m := clampf(_level_at(lod, q, span >= lod._cell_span()) - (level + k), 0.0, 1.0)
		m = minf(1.0 if m >= SNAP else m, previous)
		if m <= 0.0:
			break
		g = g.lerp(g0 - _mod(g0, span * 2.0), m)
		mesh_level += m
		previous = m
		span *= 2.0
	return Vector3(g.x, g.y, mesh_level)


static func _mod(v: Vector2, s: float) -> Vector2:
	return Vector2(fposmod(v.x, s), fposmod(v.y, s))


func _node_rect(node: Vector4) -> Rect2:
	var size := CitySeaLod.NODE_QUADS * node.w
	return Rect2(Vector2(node.x, node.y) * size, Vector2.ONE * size)


## Boundary vertices of a node in order around it, as local grid indices.
func _boundary() -> Array[Vector2]:
	var n := CitySeaLod.NODE_QUADS
	var out: Array[Vector2] = []
	for i in n:
		out.append(Vector2(i, 0))
	for i in n:
		out.append(Vector2(n, i))
	for i in n:
		out.append(Vector2(n - i, n))
	for i in n:
		out.append(Vector2(0, n - i))
	return out


func test_selection_drops_dry_nodes_and_respects_clearance() -> void:
	var lod := _lod()
	for at in EYES:
		lod.update_eye(at, true)
		assert_true(lod.nodes.size() > 0, "rings selected around %s" % at)
		for node in lod.nodes:
			var rect := _node_rect(node)
			var c0 := Vector2i((rect.position / lod._cell_span()).floor())
			var c1 := Vector2i((rect.end / lod._cell_span()).ceil())
			assert_true(lod._any_ring_cell(c0, c1), "every node holds a ring cell")
			if int(node.z) > lod.shore_level:
				var need := 1 << (int(node.z) - lod.shore_level)
				for j in range(c0.y, c1.y + 1):
					for i in range(c0.x, c1.x + 1):
						if lod._clearance_at(Vector2i(i, j)) < need:
							fail("coarse node %s spans a cell the rings do not own" % node)
							lod.free()
							return
	lod.free()


func test_rings_meet_without_cracks() -> void:
	var lod := _lod()
	var boundary := _boundary()
	var all_levels := {}
	for at in EYES:
		lod.update_eye(at, true)
		var levels := {}
		var outlines: Array[PackedVector2Array] = []
		for node in lod.nodes:
			levels[int(node.z)] = true
			var outline := PackedVector2Array()
			for local in boundary:
				var m := _morph(lod, node, local)
				outline.append(Vector2(m.x, m.y))
			outlines.append(outline)
		assert_true(levels.size() >= 2, "several ring levels around %s" % at)
		all_levels.merge(levels)
		var checked := 0
		for a in lod.nodes.size():
			var rect := _node_rect(lod.nodes[a])
			for v in boundary.size():
				var local := boundary[v]
				var g0 := rect.position + local * lod.nodes[a].w
				var outward := Vector2(
					-1.0 if local.x == 0 else (1.0 if local.x == CitySeaLod.NODE_QUADS else 0.0),
					-1.0 if local.y == 0 else (1.0 if local.y == CitySeaLod.NODE_QUADS else 0.0)
				)
				if outward.x != 0.0 and outward.y != 0.0:
					continue
				var probe := g0 + outward * 0.5
				for b in lod.nodes.size():
					if b == a or not _node_rect(lod.nodes[b]).has_point(probe):
						continue
					if _distance_to_outline(outlines[a][v], outlines[b]) > 0.0001:
						fail("crack at %s between %s and %s (eye %s)" % [
							g0, lod.nodes[a], lod.nodes[b], at
						])
						lod.free()
						return
					checked += 1
		assert_true(checked > 100, "shared ring edges checked: %d" % checked)
	assert_true(all_levels.size() >= 4, "levels 0..3 meet somewhere: %s" % [all_levels.keys()])
	lod.free()


static func _distance_to_outline(p: Vector2, outline: PackedVector2Array) -> float:
	var best := INF
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return best


func test_split_does_not_pop() -> void:
	# A node about to split must look exactly like its four children: at the
	# split distance the children are fully morphed onto the parent grid.
	var lod := _lod()
	var popped := 0
	var compared := 0
	for at in EYES:
		lod.update_eye(at, true)
		for node in lod.nodes:
			var level := int(node.z)
			if level == 0 or level > lod.shore_level:
				continue
			var parent_points := {}
			for j in CitySeaLod.NODE_QUADS + 1:
				for i in CitySeaLod.NODE_QUADS + 1:
					var m := _morph(lod, node, Vector2(i, j))
					parent_points[Vector2(m.x, m.y).snappedf(0.0001)] = true
			var rect := _node_rect(node)
			var near := Vector2(
				clampf(at.x, lod.lattice_origin.x + rect.position.x, lod.lattice_origin.x + rect.end.x),
				clampf(at.z, lod.lattice_origin.y + rect.position.y, lod.lattice_origin.y + rect.end.y)
			)
			if Vector3(near.x, 0.0, near.y).distance_to(at) < lod.ring_range * pow(2.0, level - 1) * 1.02:
				continue
			for k in 4:
				var child := Vector4(node.x * 2 + (k & 1), node.y * 2 + (k >> 1), level - 1, node.w / 2)
				for j in CitySeaLod.NODE_QUADS + 1:
					for i in CitySeaLod.NODE_QUADS + 1:
						var m := _morph(lod, child, Vector2(i, j))
						compared += 1
						if not parent_points.has(Vector2(m.x, m.y).snappedf(0.0001)):
							popped += 1
	assert_true(compared > 0, "split candidates compared")
	assert_eq(popped, 0, "children at the split distance sit on the parent grid")
	lod.free()


func test_skirt_edge_keeps_four_metre_spacing() -> void:
	# Ring vertices touching a static (skirt/band) cell sit at the 4 m level, so
	# they share position and C0/C1 weights with the static mesh's vertex.
	var lod := _lod()
	lod.update_eye(Vector3(lod.lattice_origin.x + 98.0 * 4.0, 1.7, lod.lattice_origin.y + 104.0 * 4.0), true)
	var touched := 0
	for node in lod.nodes:
		for j in CitySeaLod.NODE_QUADS + 1:
			for i in CitySeaLod.NODE_QUADS + 1:
				var g0 := (Vector2(node.x, node.y) * CitySeaLod.NODE_QUADS + Vector2(i, j)) * node.w
				var u := g0 / lod._cell_span()
				if u != u.floor():
					continue
				var v := Vector2i(u)
				var static_touch := false
				for k in 4:
					static_touch = static_touch or lod._static_cell(v - Vector2i(1 - (k & 1), 1 - (k >> 1)))
				if not static_touch:
					continue
				var m := _morph(lod, node, Vector2(i, j))
				touched += 1
				assert_eq(Vector2(m.x, m.y), g0, "skirt vertex stays on the lattice")
				assert_eq(m.z, float(lod.shore_level), "skirt vertex at the 4 m level")
	assert_true(touched > 0, "ring vertices meet the skirt")
	lod.free()


func test_ring_level_is_continuous_and_capped() -> void:
	var previous := 0.0
	for step in 4000:
		var d := float(step) * 0.5
		var level := CitySeaLod.ring_level(d, 64.0, 6)
		assert_true(level >= previous - 0.000001, "level never drops with distance")
		assert_true(level - previous < 0.02, "no jump at %f" % d)
		previous = level
	assert_eq(CitySeaLod.ring_level(10.0, 64.0, 6), 0.0, "ring 0 near the camera")
	assert_almost_eq(CitySeaLod.ring_level(128.0, 64.0, 6), 2.0, 0.0001, "ring 1 ends at 2x range")
	assert_eq(CitySeaLod.ring_level(1.0e5, 64.0, 6), 6.0, "capped at the last ring")


func test_displacement_weights_follow_spacing_and_tier() -> void:
	var lod := _lod()
	var at := Vector3(20.0, 3.0, 30.0)
	lod.update_eye(at, true)
	var near := lod.displacement_weights(Vector2(at.x, at.z))
	assert_eq(near, Vector2(1.0, 1.0), "C0 and C1 in the mesh at the camera")
	assert_eq(lod.displacement_weights(Vector2(at.x, at.z), 4.0).y, 0.0, "no C1 on a 4 m grid")
	assert_eq(lod.displacement_weights(Vector2(at.x + 600.0, at.z)).x, 0.0, "far rings normal-only")
	lod.preset["displacement_cascades"] = 1
	assert_eq(lod.displacement_weights(Vector2(at.x, at.z)).y, 0.0, "C0-only tier")
	lod.free()


func test_tier_presets() -> void:
	var minimum := WaterMaterials.sea_lod_preset(&"minimum")
	var recommended := WaterMaterials.sea_lod_preset(&"recommended")
	var high := WaterMaterials.sea_lod_preset(&"high")
	assert_eq(int(minimum["displacement_cascades"]), 1, "minimum keeps C1 in the normal")
	assert_eq(int(recommended["displacement_cascades"]), 2, "recommended displaces C1 near the camera")
	assert_true(
		float(minimum["base_spacing"]) > float(recommended["base_spacing"])
		and float(recommended["base_spacing"]) > float(high["base_spacing"]),
		"finer base spacing per tier"
	)
	assert_true(int(minimum["foam_detail_layers"]) < int(recommended["foam_detail_layers"]), "foam")
	assert_true(int(minimum["spray_particles"]) < int(recommended["spray_particles"]), "spray")
	for preset: Dictionary in [minimum, recommended, high]:
		var cell_span := 4.0 / float(preset["base_spacing"])
		assert_eq(cell_span, pow(2.0, round(log(cell_span) / log(2.0))), "4 m is a ring level")
		# Root nodes stay one kilometre, so selection depth matches across tiers.
		assert_eq(
			CitySeaLod.NODE_QUADS * float(preset["base_spacing"]) * pow(2.0, int(preset["rings"]) - 1),
			1024.0, "root node size"
		)
	assert_eq(
		int(minimum["ripple_sim_size"]),
		int(SkyWeather3D.quality_settings(&"minimum")["ripple_sim_size"]),
		"ripple sim size follows the SkyWeather tier"
	)
	assert_eq(String(WaterMaterials.sea_lod_preset(&"auto")["tier"]), "recommended", "auto")


func test_shader_contract() -> void:
	var shader := FileAccess.get_file_as_string(WATER_SHADER)
	assert_true(shader.contains("instance uniform bool sea_lod"), "ring instances flagged per instance")
	assert_true(shader.contains("INSTANCE_CUSTOM"), "node layout from MultiMesh custom data")
	assert_true(shader.contains("texelFetch(sea_depth_map"), "exact lattice field reads")
	assert_true(shader.contains("_sea_lod_pixel_drawn"), "cells owned elsewhere are cut")
	assert_false(shader.contains("render_mode") and shader.contains("tessellat"), "no tessellation")


func test_sandbox_sea_is_owned_once_and_samples_finite() -> void:
	var sandbox: Node3D = load(SANDBOX).create()
	var world: CityWorld3D = sandbox.world
	var lod := world.sea_lod
	assert_true(lod != null, "the sandbox sea runs the rings")
	if lod == null:
		sandbox.free()
		return
	var rings := 0
	for i in lod.ring_cells.size():
		assert_false(
			lod.ring_cells[i] == 1 and lod.static_cells[i] == 1, "one owner per cell"
		)
		rings += lod.ring_cells[i]
	assert_true(rings > 1000, "most of the sandbox sea is ring-drawn: %d" % rings)
	var eye := Vector3(float(sandbox.bay_centres["sand"]), 3.0, -150.0)
	lod.update_eye(eye, true)
	assert_true(lod.nodes.size() > 0, "nodes selected")
	OceanFftSampler.ensure_loaded()
	for p: Vector2 in [Vector2(eye.x, eye.z), Vector2(eye.x + 40.0, eye.z - 30.0), Vector2(eye.x, -4.0)]:
		var h: float = WaterSurface.sea_height(world, p)
		assert_true(is_finite(h) and absf(h) < 6.0, "finite CPU sea height at %s: %f" % [p, h])
	sandbox.free()
