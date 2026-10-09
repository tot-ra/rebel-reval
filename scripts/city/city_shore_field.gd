extends RefCounted

## Shore distance field for the seamless city (docs/SYSTEMS/CITY_SEA.md).
##
## WHY: the sea shader's whole surf (breaker bore, run-up, foam, slosh at quays)
## is analytic in a per-map shore field (shore_swash.gdshaderinc). The district maps
## bake it from their terrain grid; the city never bound one, so its sea met the
## land as a hard cut with no foam. This bakes the same texture layout from the
## plan heightfield: contour at ground height 0 (marching squares), then the
## nearest-contour distance, direction and beach/hard-edge flag per height node.
##
## Layout (must match MapViewMeshBuilderTerrainWater.compute_shore_field):
##   R signed distance in world units (+ water, - land, clamped to +-MAX_DISTANCE)
##   G, B unit direction towards land, encoded 0..1 (0.5, 0.5 = no shoreline near)
##   A 1 = beach (gentle slope), 0 = hard edge (quay, rock, bluff)

const MAX_DISTANCE := 8.0
## World units per field unit. The field stores world distance / DISTANCE_SCALE so the
## shader's 8-unit surf zone spans 24 world units: breakers a few metres wide and
## about a metre tall (shore_depth_scale carries the same factor into the shader).
const DISTANCE_SCALE := 3.0
## Contour gradient (metres per world unit) between beach and hard edge. The city's
## generated beaches sit at 0.05-0.35; quays, rocks and the bluff are above 0.75.
const BEACH_SLOPE_MIN := 0.42
const BEACH_SLOPE_MAX := 0.7
## Fine water band along the coast: the 4-unit sea grid is far too coarse to carry
## a breaker (a crest is ~2 units wide), so the surf zone gets its own mesh.
const COARSE_STEP := 4.0
const BAND_STEP := 0.5
const BAND_SEA := 7.5
## Covers the full 2.9-field-unit run-up plus tide/filter margin (about 10 m).
const BAND_LAND := 3.5
## Includes shader-raised surf/terrain so grazing cameras cannot cull the run-up.
const SURFACE_CULL_MARGIN := 6.0
## The band is cut into tiles of this many world units so frustum culling works.
const BAND_TILE := 128.0


## Returns {texture, origin, size}. One texel per height node, centred on the node.
static func bake(plan: CityPlan) -> Dictionary:
	var grid := plan.height_grid_size()
	var cell := plan.height_cell()
	var node_origin := plan.height_origin()
	var count := grid.x * grid.y
	var best := PackedFloat32Array()
	best.resize(count)
	best.fill(pow(MAX_DISTANCE * DISTANCE_SCALE, 2.0))
	var near_x := PackedFloat32Array()
	near_x.resize(count)
	var near_y := PackedFloat32Array()
	near_y.resize(count)
	var beach := PackedFloat32Array()
	beach.resize(count)
	var found := PackedByteArray()
	found.resize(count)
	var reach := int(ceil(MAX_DISTANCE * DISTANCE_SCALE / cell)) + 1
	var contour := PackedVector2Array()
	for j in grid.y - 1:
		for i in grid.x - 1:
			var h00 := plan.grid_height(i, j)
			var h10 := plan.grid_height(i + 1, j)
			var h11 := plan.grid_height(i + 1, j + 1)
			var h01 := plan.grid_height(i, j + 1)
			var wet := int(h00 < 0.0) + int(h10 < 0.0) + int(h11 < 0.0) + int(h01 < 0.0)
			if wet == 0 or wet == 4:
				continue
			var base := node_origin + Vector2(float(i), float(j)) * cell
			# Crossings on top, right, bottom, left edges, in that order.
			var points: Array[Vector2] = []
			_cross(points, base, Vector2(cell, 0.0), h00, h10)
			_cross(points, base + Vector2(cell, 0.0), Vector2(0.0, cell), h10, h11)
			_cross(points, base + Vector2(0.0, cell), Vector2(cell, 0.0), h01, h11)
			_cross(points, base, Vector2(0.0, cell), h00, h01)
			var slope := maxf(
				maxf(absf(h00 - h11), absf(h10 - h01)),
				maxf(absf(h00 - h10), absf(h00 - h01))
			) / cell
			var flag := 1.0 - smoothstep(BEACH_SLOPE_MIN, BEACH_SLOPE_MAX, slope)
			for k in range(0, points.size() - 1, 2):
				contour.append((points[k] + points[k + 1]) * 0.5)
				_stamp(
					points[k], points[k + 1], flag, node_origin, cell, grid, reach,
					best, near_x, near_y, beach, found
				)
	var rgba := PackedFloat32Array()
	rgba.resize(count * 4)
	var distance := PackedFloat32Array()
	distance.resize(count)
	var beach_out := PackedFloat32Array()
	beach_out.resize(count)
	for j in grid.y:
		for i in grid.x:
			var index := j * grid.x + i
			var water := plan.grid_height(i, j) < 0.0
			var signed := MAX_DISTANCE if water else -MAX_DISTANCE
			var dir := Vector2.ZERO
			var kind := 0.0
			if found[index] != 0:
				var centre := node_origin + Vector2(float(i), float(j)) * cell
				var seed := Vector2(near_x[index], near_y[index])
				var d := sqrt(best[index])
				signed = clampf((d if water else -d) / DISTANCE_SCALE, -MAX_DISTANCE, MAX_DISTANCE)
				if d > 0.0001:
					dir = (seed - centre) / d if water else (centre - seed) / d
				else:
					# A node exactly on the contour still has a shore. Zero
					# direction made filtering grow an invalid island around it.
					dir = Vector2(
						plan.grid_height(i + 1, j) - plan.grid_height(i - 1, j),
						plan.grid_height(i, j + 1) - plan.grid_height(i, j - 1)
					).normalized()
				kind = beach[index]
			distance[index] = signed
			beach_out[index] = kind
			rgba[index * 4] = signed
			rgba[index * 4 + 1] = dir.x * 0.5 + 0.5
			rgba[index * 4 + 2] = dir.y * 0.5 + 0.5
			rgba[index * 4 + 3] = kind
	var image := Image.create_from_data(
		grid.x, grid.y, false, Image.FORMAT_RGBAF, rgba.to_byte_array()
	)
	image.convert(Image.FORMAT_RGBAH)
	return {
		"texture": ImageTexture.create_from_image(image),
		"origin": node_origin - Vector2(cell, cell) * 0.5,
		"size": Vector2(float(grid.x), float(grid.y)) * cell,
		"distance": distance,
		"beach": beach_out,
		"samples": rgba,
		"grid": grid,
		# Waterline segment midpoints, for the spray emitters (CityShoreSpray).
		"contour": contour,
	}


static func _cross(
	into: Array[Vector2], from: Vector2, edge: Vector2, h_a: float, h_b: float
) -> void:
	if (h_a < 0.0) == (h_b < 0.0):
		return
	into.append(from + edge * (h_a / (h_a - h_b)))


## Updates every height node within MAX_DISTANCE of the segment a-b.
static func _stamp(
	a: Vector2, b: Vector2, flag: float, node_origin: Vector2, cell: float, grid: Vector2i,
	reach: int, best: PackedFloat32Array, near_x: PackedFloat32Array,
	near_y: PackedFloat32Array, beach: PackedFloat32Array, found: PackedByteArray
) -> void:
	var mid := (a + b) * 0.5
	var ci := int(round((mid.x - node_origin.x) / cell))
	var cj := int(round((mid.y - node_origin.y) / cell))
	var ab := b - a
	var length_sq := maxf(ab.length_squared(), 1.0e-8)
	for j in range(maxi(cj - reach, 0), mini(cj + reach, grid.y - 1) + 1):
		for i in range(maxi(ci - reach, 0), mini(ci + reach, grid.x - 1) + 1):
			var p := node_origin + Vector2(float(i), float(j)) * cell
			var t := clampf((p - a).dot(ab) / length_sq, 0.0, 1.0)
			var nearest := a + ab * t
			var d2 := p.distance_squared_to(nearest)
			var index := j * grid.x + i
			if d2 < best[index]:
				best[index] = d2
				near_x[index] = nearest.x
				near_y[index] = nearest.y
				beach[index] = flag
				found[index] = 1


## Signed distance to the waterline (+ water) at a point, nearest height node.
static func signed_distance_at(shore: Dictionary, plan: CityPlan, p: Vector2) -> float:
	var grid: Vector2i = shore["grid"]
	var f := (p - plan.height_origin()) / plan.height_cell()
	var i := clampi(int(round(f.x)), 0, grid.x - 1)
	var j := clampi(int(round(f.y)), 0, grid.y - 1)
	return (shore["distance"] as PackedFloat32Array)[j * grid.x + i]


## One ownership test for both coarse and fine geometry. Transparent surfaces
## must never overlap: two alpha layers expose a grid of dark/light triangles.
static func covers_coarse_cell(shore: Dictionary, plan: CityPlan, origin: Vector2) -> bool:
	for offset: Vector2 in [Vector2.ZERO, Vector2(COARSE_STEP, 0),
		Vector2(0, COARSE_STEP), Vector2.ONE * COARSE_STEP, Vector2.ONE * COARSE_STEP * 0.5]:
		var d := signed_distance_at(shore, plan, origin + offset)
		if d < BAND_SEA and d > -BAND_LAND:
			return true
	return false


static func in_band(shore: Dictionary, plan: CityPlan, p: Vector2) -> bool:
	var cell := ((p - plan.bounds.position) / COARSE_STEP).floor()
	var origin := plan.bounds.position + cell * COARSE_STEP
	return covers_coarse_cell(shore, plan, origin)


## Fine water mesh along the waterline, one mesh per BAND_TILE square. Vertex
## colour R = water depth / depth_norm, exactly like the coarse sea grid, so the
## same water material shades it (shore lift, curl, foam all come from the shader).
static func build_band(plan: CityPlan, shore: Dictionary, depth_norm: float) -> Array[ArrayMesh]:
	var bounds := plan.bounds
	var tiles := {}
	var nx := int(ceil(bounds.size.x / COARSE_STEP))
	var nz := int(ceil(bounds.size.y / COARSE_STEP))
	var subdivisions := int(COARSE_STEP / BAND_STEP)
	for j in nz:
		for i in nx:
			var coarse := bounds.position + Vector2(i, j) * COARSE_STEP
			if not covers_coarse_cell(shore, plan, coarse):
				continue
			var bed_normals := {}
			for cell in subdivisions * subdivisions:
				var p0 := coarse + Vector2(cell % subdivisions, cell / subdivisions) * BAND_STEP
				var corners: Array[Vector2] = [p0, p0 + Vector2(BAND_STEP, 0),
					p0 + Vector2.ONE * BAND_STEP, p0 + Vector2(0, BAND_STEP)]
				var depths: Array[float] = []
				for corner in corners:
					depths.append(-plan.ground_height(corner))
				var key := Vector2i(int(floor((p0.x - bounds.position.x) / BAND_TILE)),
					int(floor((p0.y - bounds.position.y) / BAND_TILE)))
				if not tiles.has(key):
					var surface := SurfaceTool.new()
					surface.begin(Mesh.PRIMITIVE_TRIANGLES)
					surface.set_normal(Vector3.UP)
					tiles[key] = surface
				var surface: SurfaceTool = tiles[key]
				# Match the terrain's parent-cell diagonal. Shared vertices are
				# indexed below, so the denser crest costs fewer vertex evaluations
				# than the former unindexed 1 m grid (six copies per cell).
				for index: int in _terrain_triangles(plan, p0):
					var c := corners[index]
					if not bed_normals.has(c):
						bed_normals[c] = _bed_normal(plan, c)
					surface.set_normal(bed_normals[c])
					surface.set_color(Color(clampf(depths[index] / depth_norm, 0.0, 1.0), 0, 0))
					surface.set_uv2(Vector2(0.0, -depths[index]))
					surface.add_vertex(Vector3(c.x, 0.0, c.y))
	var meshes: Array[ArrayMesh] = []
	for surface: SurfaceTool in tiles.values():
		surface.index()
		meshes.append(surface.commit())
	return meshes


## Continuous central differences match terrain normals at the height nodes.
## Baked once, never sampled on the CPU per frame; shared tile edges agree.
static func _bed_normal(plan: CityPlan, p: Vector2) -> Vector3:
	var e := plan.height_cell()
	var dx := plan.ground_height(p + Vector2(e, 0)) - plan.ground_height(p - Vector2(e, 0))
	var dz := plan.ground_height(p + Vector2(0, e)) - plan.ground_height(p - Vector2(0, e))
	return Vector3(-dx, 2.0 * e, -dz).normalized()


## Fine cells divide the 2 m terrain cells exactly; use that parent diagonal.
static func _terrain_triangles(plan: CityPlan, p: Vector2) -> Array[int]:
	var cell := Vector2i(((p - plan.height_origin()) / plan.height_cell()).floor())
	var a := plan.grid_height(cell.x, cell.y)
	var b := plan.grid_height(cell.x + 1, cell.y)
	var c := plan.grid_height(cell.x + 1, cell.y + 1)
	var d := plan.grid_height(cell.x, cell.y + 1)
	if absf(a - c) < absf(b - d):
		return [0, 1, 2, 0, 2, 3]
	return [0, 1, 3, 1, 2, 3]
