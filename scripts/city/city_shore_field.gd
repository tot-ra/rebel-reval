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
## Contour gradient (metres per world unit) between beach and hard edge. The city's
## generated beaches sit at 0.05-0.35; quays, rocks and the bluff are above 0.75.
const BEACH_SLOPE_MIN := 0.42
const BEACH_SLOPE_MAX := 0.7
## Sheet band, matching MapViewMeshBuilderTerrainWater.SHORE_SHEET_*.
const SHEET_REACH := 3.0
const SHEET_SEAWARD_MARGIN := 0.35
const SHEET_LIFT := 0.05
const SHEET_STEP := 1.0


## Returns {texture, origin, size}. One texel per height node, centred on the node.
static func bake(plan: CityPlan) -> Dictionary:
	var grid := plan.height_grid_size()
	var cell := plan.height_cell()
	var node_origin := plan.height_origin()
	var count := grid.x * grid.y
	var best := PackedFloat32Array()
	best.resize(count)
	best.fill(MAX_DISTANCE * MAX_DISTANCE)
	var near_x := PackedFloat32Array()
	near_x.resize(count)
	var near_y := PackedFloat32Array()
	near_y.resize(count)
	var beach := PackedFloat32Array()
	beach.resize(count)
	var found := PackedByteArray()
	found.resize(count)
	var reach := int(ceil(MAX_DISTANCE / cell)) + 1
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
				signed = clampf(d if water else -d, -MAX_DISTANCE, MAX_DISTANCE)
				if d > 0.0001:
					dir = (seed - centre) / d if water else (centre - seed) / d
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
		"grid": grid,
		# Waterline segment midpoints, for the spray emitters (CityShoreSpray).
		"contour": contour,
	}


## Thin film over beach sand, SHEET_REACH units inland of the waterline, lying on
## the terrain (+ SHEET_LIFT) at one vertex per world unit. The water shader paints
## the run-up front, its foam bead and the wet sheen on it (shore_swash.gdshaderinc).
## Mirrors MapViewMeshBuilderTerrainWater.swash_sheet_arrays for the city heightfield.
static func build_sheet(plan: CityPlan, shore: Dictionary) -> ArrayMesh:
	var grid: Vector2i = shore["grid"]
	var distance: PackedFloat32Array = shore["distance"]
	var beach: PackedFloat32Array = shore["beach"]
	var cell := plan.height_cell()
	var node_origin := plan.height_origin()
	var steps := int(round(cell / SHEET_STEP))
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var lift := Vector3(0.0, SHEET_LIFT, 0.0)
	for j in grid.y - 1:
		for i in grid.x - 1:
			var index := j * grid.x + i
			var land := -distance[index]
			if land < -SHEET_SEAWARD_MARGIN - cell or land > SHEET_REACH + cell:
				continue
			if beach[index] < 0.5:
				continue
			var base := node_origin + Vector2(float(i), float(j)) * cell
			for sy in steps:
				for sx in steps:
					var p := base + Vector2(float(sx), float(sy)) * SHEET_STEP
					var q := _lerp_land(shore, plan, p + Vector2(SHEET_STEP, SHEET_STEP) * 0.5)
					if q < -SHEET_SEAWARD_MARGIN or q > SHEET_REACH:
						continue
					var corners: Array[Vector3] = []
					for offset in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
						var c: Vector2 = p + (offset as Vector2) * SHEET_STEP
						corners.append(Vector3(c.x, plan.ground_height(c), c.y) + lift)
					for tri in [[0, 1, 2], [0, 2, 3]]:
						for vi: int in tri:
							vertices.append(corners[vi])
							normals.append(Vector3.UP)
	if vertices.is_empty():
		return null
	var colors := PackedColorArray()
	colors.resize(vertices.size())
	colors.fill(Color.WHITE)
	var uvs := PackedVector2Array()
	uvs.resize(vertices.size())
	for k in vertices.size():
		uvs[k] = Vector2(vertices[k].x, vertices[k].z) * 0.1
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Distance inland (world units, + land) at a point, nearest height node.
static func _lerp_land(shore: Dictionary, plan: CityPlan, p: Vector2) -> float:
	var grid: Vector2i = shore["grid"]
	var cell := plan.height_cell()
	var f := (p - plan.height_origin()) / cell
	var i := clampi(int(round(f.x)), 0, grid.x - 1)
	var j := clampi(int(round(f.y)), 0, grid.y - 1)
	return -(shore["distance"] as PackedFloat32Array)[j * grid.x + i]


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
