class_name MapViewMeshBuilderTerrainWater
extends RefCounted

## Smoothed water contours and recessed water-surface mesh generation.

const RIVER_FLOW := preload("res://scripts/map/view3d/map_view_river_flow.gd")

const SHORE_FIELD_TEXELS_PER_CELL := 4
## Signed distance clamp in world units (+ = water, - = land).
const SHORE_FIELD_MAX_DISTANCE := 8.0
## The swash sheet reaches this far inland; run-up is clamped just below it.
const SHORE_SHEET_REACH := 3.0
## Sheet triangles start slightly seaward so the shader, not the mesh edge, cuts
## the sheet exactly at the waterline.
const SHORE_SHEET_SEAWARD_MARGIN := 0.35
const SHORE_SHEET_LIFT := 0.01
## Rivers keep their bank treatment and are left out of the field.
const SHORE_SWASH_WATER: Array[StringName] = [
	MapTypes.TERRAIN_WATER,
	MapTypes.TERRAIN_SHALLOW_WATER,
	MapTypes.TERRAIN_DEEP_WATER,
]
## Only open sea runs up a beach; ponds and moats get the hard-edge slosh.
const SHORE_SEA_WATER: Array[StringName] = [
	MapTypes.TERRAIN_SHALLOW_WATER,
	MapTypes.TERRAIN_DEEP_WATER,
]
const SHORE_BEACH_TERRAINS: Array[StringName] = [
	MapTypes.TERRAIN_SAND,
	MapTypes.TERRAIN_COAST_SAND,
]
const _SHORE_NO_SEED := 1.0e20
const _SHORE_PROBE_STEP := 0.3
const _SHORE_PROBE_STEPS := 5
## Ownership needs coverage + meander to beat every rival; below this a family
## cannot win anywhere in the cell (rivals then hold >= threshold - this).
const _FAMILY_PROBE_MIN_COVERAGE := 0.03


static func bake_water_contour(grid: MapTerrainGrid, terrain_id: StringName) -> Dictionary:
	var columns := grid.size_cells.x
	var rows := grid.size_cells.y
	var sigma := MapViewMeshBuilderConfig.WATER_CONTOUR_SIGMA_CELLS
	var radius := MapViewMeshBuilderConfig.WATER_CONTOUR_RADIUS_CELLS
	var kernel := PackedFloat32Array()
	kernel.resize(radius * 2 + 1)
	var kernel_total := 0.0
	for offset in range(-radius, radius + 1):
		var weight := exp(-float(offset * offset) / (2.0 * sigma * sigma))
		kernel[offset + radius] = weight
		kernel_total += weight
	for index in kernel.size():
		kernel[index] /= kernel_total
	var source := PackedFloat32Array()
	source.resize(columns * rows)
	for y in rows:
		for x in columns:
			source[y * columns + x] = 1.0 if grid.get_terrain(Vector2i(x, y)) == terrain_id else 0.0
	var horizontal := PackedFloat32Array()
	horizontal.resize(source.size())
	for y in rows:
		for x in columns:
			var value := 0.0
			for offset in range(-radius, radius + 1):
				var sample_x := clampi(x + offset, 0, columns - 1)
				value += source[y * columns + sample_x] * kernel[offset + radius]
			horizontal[y * columns + x] = value
	var values := PackedFloat32Array()
	values.resize(source.size())
	var max_coverage := 0.0
	for y in rows:
		for x in columns:
			var value := 0.0
			for offset in range(-radius, radius + 1):
				var sample_y := clampi(y + offset, 0, rows - 1)
				value += horizontal[sample_y * columns + x] * kernel[offset + radius]
			values[y * columns + x] = value
			max_coverage = maxf(max_coverage, value)
	# WHY: the radius-4 Gaussian fills a short dirt causeway between two
	# stretches of still water (R-529 monastery east ditch). Enclosed ponds,
	# ditches and moats must keep authored dry interruptions dry. River and
	# sea keep the broad field so stair-stepped banks can still round.
	if terrain_id == MapTypes.TERRAIN_WATER:
		max_coverage = 0.0
		for index in values.size():
			if source[index] < 0.5:
				values[index] = 0.0
			else:
				max_coverage = maxf(max_coverage, values[index])
	return {
		"values": values,
		"source": source,
		"columns": columns,
		"rows": rows,
		"max_coverage": max_coverage
	}


static func water_coverage_at(field: Dictionary, sample: Vector2, terrain_id: StringName) -> float:
	var contour: Dictionary = field["water_contours"].get(terrain_id, {})
	if contour.is_empty():
		return 0.0
	var centered := sample - Vector2(0.5, 0.5)
	var base := Vector2i(floori(centered.x), floori(centered.y))
	var local := centered - Vector2(base)
	var top_left := _water_contour_sample(contour, base)
	var top_right := _water_contour_sample(contour, base + Vector2i.RIGHT)
	var bottom_left := _water_contour_sample(contour, base + Vector2i.DOWN)
	var bottom_right := _water_contour_sample(contour, base + Vector2i(1, 1))
	return lerpf(
		lerpf(top_left, top_right, local.x), lerpf(bottom_left, bottom_right, local.x), local.y
	)


## Union water coverage (see _union_node): the one contour every family's mesh is
## clipped against, so shore bands, boats and the swash field share its waterline.
static func combined_water_coverage_at(field: Dictionary, sample: Vector2) -> float:
	var contours: Dictionary = field.get("water_contours", {})
	if contours.is_empty():
		return 0.0
	var centered := sample - Vector2(0.5, 0.5)
	var base := Vector2i(floori(centered.x), floori(centered.y))
	var local := centered - Vector2(base)
	var families := contours.keys()
	return lerpf(
		lerpf(
			_union_sample(field, base, families),
			_union_sample(field, base + Vector2i.RIGHT, families),
			local.x
		),
		lerpf(
			_union_sample(field, base + Vector2i.DOWN, families),
			_union_sample(field, base + Vector2i(1, 1), families),
			local.x
		),
		local.y
	)


## Cached union node grid for every water family, baked with the height field so
## per-vertex lookups stay cheap. Pure; runs on the height-field worker.
static func bake_water_union(field: Dictionary) -> Dictionary:
	var contours: Dictionary = field.get("water_contours", {})
	if contours.is_empty():
		return {}
	var first: Dictionary = contours.values()[0]
	var columns: int = first["columns"]
	var rows: int = first["rows"]
	var families := contours.keys()
	var values := PackedFloat32Array()
	values.resize(maxi(columns * rows, 0))
	for y in rows:
		for x in columns:
			values[y * columns + x] = _union_node(field, Vector2i(x, y), families)
	return {"values": values, "columns": columns, "rows": rows}


static func _union_sample(field: Dictionary, cell: Vector2i, families: Array) -> float:
	var union: Dictionary = field.get("water_union", {})
	if union.is_empty():
		# Hand-built test fields have no cached grid; the node is a pure function.
		return _union_node(field, cell, families)
	var columns: int = union["columns"]
	var rows: int = union["rows"]
	if columns <= 0 or rows <= 0:
		return 0.0
	var values: PackedFloat32Array = union["values"]
	return values[clampi(cell.y, 0, rows - 1) * columns + clampi(cell.x, 0, columns - 1)]


## WHY: each family used to be clipped against its own contour. At a shallow/deep
## drop-off both sit near 0.5, so each drew its own "shoreline" there - fading
## waves, edge foam and tide retreat along a straight cell line, with the two
## transparent sheets overlapping. Families own disjoint cells, so the sum of
## their Gaussian fields is the Gaussian of the union: open water stays at full
## coverage across a family border and only a real bank reaches the waterline.
## Sea edges also get a low-frequency wobble so rect-authored coves and spits
## stop running cell-straight (view only; gameplay water stays the authored cells).
static func _union_node(field: Dictionary, cell: Vector2i, families: Array) -> float:
	var contours: Dictionary = field.get("water_contours", {})
	var total := 0.0
	var sea := 0.0
	var clamped := cell
	for terrain_id: StringName in families:
		var contour: Dictionary = contours.get(terrain_id, {})
		if contour.is_empty():
			continue
		clamped = Vector2i(
			clampi(cell.x, 0, maxi(int(contour["columns"]) - 1, 0)),
			clampi(cell.y, 0, maxi(int(contour["rows"]) - 1, 0))
		)
		var value := _water_contour_sample(contour, clamped)
		total += value
		if SHORE_SEA_WATER.has(terrain_id):
			sea += value
	if sea <= 0.0 or total <= 0.0 or total >= 1.0:
		return minf(total, 1.0)
	var noise_seed := int(field.get("seed", 0))
	var node := Vector2(clamped) + Vector2(0.5, 0.5)
	var wobble := (
		(
			MapViewMeshBuilderTerrain.value_noise(
				node / MapViewMeshBuilderConfig.SEA_SHORE_NOISE_PERIOD_CELLS, noise_seed + 21011
			)
			- 0.5
		)
		* 2.0
		* MapViewMeshBuilderConfig.SEA_SHORE_NOISE
		+ (
			MapViewMeshBuilderTerrain.value_noise(
				node / MapViewMeshBuilderConfig.SEA_SHORE_DETAIL_PERIOD_CELLS, noise_seed + 21313
			)
			- 0.5
		)
		* 2.0
		* MapViewMeshBuilderConfig.SEA_SHORE_DETAIL_NOISE
	)
	var edge := 4.0 * total * (1.0 - total)
	return clampf(total + wobble * edge * (sea / total), 0.0, 1.0)


## Signed ownership of `terrain_id` at a sample: >= 0 where it beats every other
## water family (coverage plus a per-family meander), so adjacent families
## partition the union exactly along one wavy line. 1 when it has no rival.
static func water_family_margin_at(
	field: Dictionary, sample: Vector2, terrain_id: StringName
) -> float:
	var contours: Dictionary = field.get("water_contours", {})
	if contours.size() < 2:
		return 1.0
	var own := _water_family_score(field, sample, terrain_id)
	var best_other := -INF
	for other: StringName in contours.keys():
		if other != terrain_id:
			best_other = maxf(best_other, _water_family_score(field, sample, other))
	return own - best_other


static func _water_family_score(
	field: Dictionary, sample: Vector2, terrain_id: StringName
) -> float:
	var family_seed := (
		int(field.get("seed", 0)) + 23011 + MapTypes.WATER_TERRAINS.find(terrain_id) * 7919
	)
	var meander := MapViewMeshBuilderTerrain.value_noise(
		sample / MapViewMeshBuilderConfig.WATER_FAMILY_BORDER_PERIOD_CELLS, family_seed
	)
	return (
		water_coverage_at(field, sample, terrain_id)
		+ (meander - 0.5) * 2.0 * MapViewMeshBuilderConfig.WATER_FAMILY_BORDER_NOISE
	)


## WB-07b: one water family's clipped surface as SurfaceTool arrays, empty when
## no cell of that family produced a triangle. Pure; runs on a worker in staged
## assembly. ArrayMesh.add_surface_from_arrays() with no flags then matches what
## SurfaceTool.commit() built before (no custom channels, no material).
static func water_surface_arrays(
	field: Dictionary, grid: MapTerrainGrid, terrain_id: StringName
) -> Array:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cells := 0
	for y in grid.size_cells.y:
		for x in grid.size_cells.x:
			if not cell_near_terrain(field, Vector2i(x, y), terrain_id, grid):
				continue
			add_water_cell_quad(surface, field, grid, x, y, terrain_id)
			cells += 1
	if cells == 0:
		return []
	var arrays := surface.commit_to_arrays()
	var vertices: Variant = arrays[Mesh.ARRAY_VERTEX] if arrays.size() > 0 else null
	if not vertices is PackedVector3Array or (vertices as PackedVector3Array).is_empty():
		return []
	return arrays


static func cell_near_terrain(
	field: Dictionary, cell: Vector2i, terrain_id: StringName, grid: MapTerrainGrid
) -> bool:
	if terrain_id == MapTypes.TERRAIN_WATER and grid.get_terrain(cell) != terrain_id:
		return false
	for probe in [
		Vector2(cell),
		Vector2(cell) + Vector2(1.0, 0.0),
		Vector2(cell) + Vector2.ONE,
		Vector2(cell) + Vector2(0.0, 1.0),
		Vector2(cell) + Vector2(0.5, 0.5),
	]:
		# The mesh is clipped by the union contour, but this family can only win
		# ownership where it has some coverage of its own.
		if (
			combined_water_coverage_at(field, probe)
			>= MapViewMeshBuilderConfig.WATER_CONTOUR_THRESHOLD
			and water_coverage_at(field, probe, terrain_id) >= _FAMILY_PROBE_MIN_COVERAGE
		):
			return true
	return false


static func add_water_cell_quad(
	surface: SurfaceTool,
	field: Dictionary,
	_grid: MapTerrainGrid,
	x: int,
	y: int,
	terrain_id: StringName
) -> void:
	var columns: int = field["vertex_columns"]
	var positions: PackedVector3Array = field["positions"]
	var origin_x := x * MapViewMeshBuilderConfig.TERRAIN_SUBDIVISIONS
	var origin_y := y * MapViewMeshBuilderConfig.TERRAIN_SUBDIVISIONS
	for patch_y in MapViewMeshBuilderConfig.TERRAIN_SUBDIVISIONS:
		for patch_x in MapViewMeshBuilderConfig.TERRAIN_SUBDIVISIONS:
			var vertex_x := origin_x + patch_x
			var vertex_y := origin_y + patch_y
			var indices := [
				vertex_y * columns + vertex_x,
				vertex_y * columns + vertex_x + 1,
				(vertex_y + 1) * columns + vertex_x + 1,
				(vertex_y + 1) * columns + vertex_x,
			]
			var corners: Array[Dictionary] = []
			for index in indices:
				var vertex: Vector3 = positions[index]
				var spot := Vector2(vertex.x, vertex.z)
				corners.append(
					{
						"position": vertex,
						"coverage": combined_water_coverage_at(field, spot),
						"margin": water_family_margin_at(field, spot, terrain_id),
					}
				)
			if (vertex_x + vertex_y) % 2 == 0:
				_add_clipped_water_triangle(surface, field, corners[0], corners[1], corners[2])
				_add_clipped_water_triangle(surface, field, corners[0], corners[2], corners[3])
			else:
				_add_clipped_water_triangle(surface, field, corners[0], corners[1], corners[3])
				_add_clipped_water_triangle(surface, field, corners[1], corners[2], corners[3])


static func _water_contour_sample(contour: Dictionary, cell: Vector2i) -> float:
	var columns: int = contour["columns"]
	var rows: int = contour["rows"]
	if columns <= 0 or rows <= 0:
		# Invalid map definitions can leave an empty view field after MapBuilder
		# rejects them. Treat that field as dry instead of indexing an empty array.
		return 0.0
	var values: PackedFloat32Array = contour.get("values", PackedFloat32Array())
	var source: PackedFloat32Array = contour.get("source", PackedFloat32Array())
	if float(contour["max_coverage"]) < MapViewMeshBuilderConfig.WATER_CONTOUR_THRESHOLD:
		values = source
	if values.size() < columns * rows:
		return 0.0
	var clamped := Vector2i(clampi(cell.x, 0, columns - 1), clampi(cell.y, 0, rows - 1))
	return values[clamped.y * columns + clamped.x]


## Clips one terrain triangle to the union waterline, then to this family's
## ownership. Neighbouring families clip the same triangle with the negated
## margin, so their cut vertices coincide and the seam stays watertight.
static func _add_clipped_water_triangle(
	surface: SurfaceTool,
	field: Dictionary,
	first: Dictionary,
	second: Dictionary,
	third: Dictionary
) -> void:
	var polygon: Array[Dictionary] = [first, second, third]
	polygon = _clip_water_polygon(
		polygon, "coverage", MapViewMeshBuilderConfig.WATER_CONTOUR_THRESHOLD
	)
	polygon = _clip_water_polygon(polygon, "margin", 0.0)
	if polygon.size() < 3:
		return
	for index in range(1, polygon.size() - 1):
		_add_water_vertex(surface, field, polygon[0])
		_add_water_vertex(surface, field, polygon[index])
		_add_water_vertex(surface, field, polygon[index + 1])


## Sutherland-Hodgman against `key >= threshold`; cut points interpolate every
## scalar channel so the second pass and the vertex colours stay consistent.
static func _clip_water_polygon(
	polygon: Array[Dictionary], key: String, threshold: float
) -> Array[Dictionary]:
	var clipped: Array[Dictionary] = []
	if polygon.size() < 3:
		return clipped
	for index in polygon.size():
		var current := polygon[index]
		var previous := polygon[(index + polygon.size() - 1) % polygon.size()]
		var current_inside := float(current[key]) >= threshold
		var previous_inside := float(previous[key]) >= threshold
		if current_inside != previous_inside:
			var previous_value := float(previous[key])
			var weight := (threshold - previous_value) / (float(current[key]) - previous_value)
			clipped.append(
				{
					"position":
					(previous["position"] as Vector3).lerp(current["position"] as Vector3, weight),
					"coverage":
					lerpf(float(previous["coverage"]), float(current["coverage"]), weight),
					"margin": lerpf(float(previous["margin"]), float(current["margin"]), weight),
				}
			)
			clipped[-1][key] = threshold
		if current_inside:
			clipped.append(current)
	return clipped


static func _add_water_vertex(surface: SurfaceTool, field: Dictionary, corner: Dictionary) -> void:
	var source: Vector3 = corner["position"]
	var coverage := float(corner["coverage"])
	# Look up the still-water bed from XZ. Clipped shoreline vertices lerp Y
	# toward the bank, which must not tilt the surface out of the water body.
	var bed_y := MapViewMeshBuilderTerrain.water_gameplay_bed_y(
		field, Vector2(source.x, source.z)
	)
	var vertex := Vector3(
		source.x, bed_y + MapViewMeshBuilderConfig.WATER_SURFACE_LIFT, source.z
	)
	var threshold := MapViewMeshBuilderConfig.WATER_CONTOUR_THRESHOLD
	var interior_coverage := inverse_lerp(threshold, 1.0, coverage)
	surface.set_normal(Vector3.UP)
	surface.set_uv(Vector2(vertex.x, vertex.z) / MapViewMaterials.TERRAIN_TEXTURE_WORLD_SIZE)
	# COLOR.g fades waves to rest at a family border (shallow/deep drop-off), so
	# the two families' different wave heights meet on one sealed rest line.
	var junction := clampf(
		float(corner["margin"]) / MapViewMeshBuilderConfig.WATER_FAMILY_JUNCTION_BAND, 0.0, 1.0
	)
	surface.set_color(Color(interior_coverage, junction, interior_coverage, 1.0))
	# WS-13b: UV2 = (1, gameplay bed y). Maps without relief keep -WATER_RECESS.
	# The shader maps a deeper rendered sea bed back to this plane.
	surface.set_uv2(Vector2(1.0, bed_y))
	surface.add_vertex(vertex)


# --- WS-08 shore distance field and beach swash sheet -----------------------------
# Both are generated view output (see docs/MAP_AUTHORING.md): no stable IDs, no
# collision, no effect on walkable cells. The shaders derive every swash effect
# analytically from this field, so the water and the wet sand always agree.

## Signed distance to the clipped water contour at 4 texels per cell, cached on the
## height field. Empty when the map has no sea/pond water.
##   distance (R): world units, + water / - land, clamped to +-8
##   direction (G, B): unit vector pointing towards land
##   type (A): 1 = beach (sand/coast_sand against open sea), 0 = hard edge
static func bake_shore_field(field: Dictionary, grid: MapTerrainGrid) -> Dictionary:
	if field.has("shore_field"):
		return field["shore_field"]
	var shore := finish_shore_field(compute_shore_field(field, grid))
	field["shore_field"] = shore
	return shore


## WB-07b: turns the worker-baked image into the shader texture. Main thread.
static func finish_shore_field(shore: Dictionary) -> Dictionary:
	if shore.has("image"):
		shore["texture"] = ImageTexture.create_from_image(shore["image"])
		shore.erase("image")
	return shore


## WB-07b: the shore bake as a pure function of the field and grid (no texture,
## no cache write), so it may run on a worker. finish_shore_field() completes it.
static func compute_shore_field(field: Dictionary, grid: MapTerrainGrid) -> Dictionary:
	var columns := grid.size_cells.x
	var rows := grid.size_cells.y
	var contours: Array[Dictionary] = []
	for terrain_id in SHORE_SWASH_WATER:
		var contour: Dictionary = field.get("water_contours", {}).get(terrain_id, {})
		if not contour.is_empty():
			contours.append(contour)
	if contours.is_empty() or columns <= 0 or rows <= 0:
		return {}
	# The same union nodes that clip the water mesh (see _union_node), limited to
	# the swash families so a river mouth stays a junction, not a shoreline.
	var families: Array = []
	for terrain_id in SHORE_SWASH_WATER:
		if field.get("water_contours", {}).has(terrain_id):
			families.append(terrain_id)
	var all_families: Array = field.get("water_contours", {}).keys()
	var reuse_cache := families.size() == all_families.size()
	var combined := PackedFloat32Array()
	combined.resize(columns * rows)
	for y in rows:
		for x in columns:
			var node := Vector2i(x, y)
			combined[y * columns + x] = (
				_union_sample(field, node, all_families)
				if reuse_cache
				else _union_node(field, node, families)
			)
	var texels := SHORE_FIELD_TEXELS_PER_CELL
	var width := columns * texels
	var height := rows * texels
	var inv := 1.0 / float(texels)
	var coverage := PackedFloat32Array()
	coverage.resize(width * height)
	for ty in height:
		var sy := (float(ty) + 0.5) * inv - 0.5
		var fy := sy - floorf(sy)
		var y0 := clampi(floori(sy), 0, rows - 1) * columns
		var y1 := clampi(floori(sy) + 1, 0, rows - 1) * columns
		for tx in width:
			var sx := (float(tx) + 0.5) * inv - 0.5
			var fx := sx - floorf(sx)
			var x0 := clampi(floori(sx), 0, columns - 1)
			var x1 := clampi(floori(sx) + 1, 0, columns - 1)
			coverage[ty * width + tx] = lerpf(
				lerpf(combined[y0 + x0], combined[y0 + x1], fx),
				lerpf(combined[y1 + x0], combined[y1 + x1], fx),
				fy
			)
	var threshold := MapViewMeshBuilderConfig.WATER_CONTOUR_THRESHOLD
	var seed_x := PackedFloat32Array()
	var seed_y := PackedFloat32Array()
	var seed_type := PackedFloat32Array()
	var best := PackedFloat32Array()
	seed_x.resize(width * height)
	seed_y.resize(width * height)
	seed_type.resize(width * height)
	best.resize(width * height)
	best.fill(_SHORE_NO_SEED)
	# Seeds are the exact sub-texel contour crossings between neighbouring texel
	# centres, so the transform below measures distance to the same iso-line
	# that clips the water mesh rather than to a stair-stepped texel boundary.
	var crossings: Array[Array] = []
	for ty in height:
		for tx in width:
			var index := ty * width + tx
			var inside := coverage[index] >= threshold
			if tx + 1 < width and (coverage[index + 1] >= threshold) != inside:
				_add_shore_crossing(crossings, grid, coverage, width, index, index + 1, Vector2(1, 0))
			if ty + 1 < height and (coverage[index + width] >= threshold) != inside:
				_add_shore_crossing(
					crossings, grid, coverage, width, index, index + width, Vector2(0, 1)
				)
	var has_beach := false
	for crossing in crossings:
		var point: Vector2 = crossing[2]
		var kind: float = crossing[3]
		has_beach = has_beach or kind > 0.5
		for target: int in [crossing[0], crossing[1]]:
			var centre := Vector2(float(target % width) + 0.5, float(target / width) + 0.5) * inv
			var d2 := centre.distance_squared_to(point)
			if d2 < best[target]:
				best[target] = d2
				seed_x[target] = point.x
				seed_y[target] = point.y
				seed_type[target] = kind
	# Two-pass nearest-seed propagation (a vector distance transform): each texel
	# adopts a neighbour's seed when that seed is closer. Carrying the seed point
	# instead of a scalar distance keeps the result Euclidean to well under 0.1 cell.
	var forward: Array[Vector2i] = [
		Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(1, -1)
	]
	var backward: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)
	]
	for pass_index in 2:
		var offsets := forward if pass_index == 0 else backward
		for step_y in height:
			var ty := step_y if pass_index == 0 else height - 1 - step_y
			var cy := (float(ty) + 0.5) * inv
			for step_x in width:
				var tx := step_x if pass_index == 0 else width - 1 - step_x
				var index := ty * width + tx
				var cx := (float(tx) + 0.5) * inv
				for offset in offsets:
					var nx := tx + offset.x
					var ny := ty + offset.y
					if nx < 0 or ny < 0 or nx >= width or ny >= height:
						continue
					var other := ny * width + nx
					if best[other] >= _SHORE_NO_SEED:
						continue
					var dx := seed_x[other] - cx
					var dy := seed_y[other] - cy
					var d2 := dx * dx + dy * dy
					if d2 < best[index]:
						best[index] = d2
						seed_x[index] = seed_x[other]
						seed_y[index] = seed_y[other]
						seed_type[index] = seed_type[other]
	var distance := PackedFloat32Array()
	var direction := PackedVector2Array()
	var shore_type := PackedFloat32Array()
	distance.resize(width * height)
	direction.resize(width * height)
	shore_type.resize(width * height)
	var rgba := PackedFloat32Array()
	rgba.resize(width * height * 4)
	var limit := SHORE_FIELD_MAX_DISTANCE
	for ty in height:
		for tx in width:
			var index := ty * width + tx
			var inside := coverage[index] >= threshold
			var signed := limit if inside else -limit
			var towards_land := Vector2.ZERO
			var kind := 0.0
			if best[index] < _SHORE_NO_SEED:
				var centre := Vector2(float(tx) + 0.5, float(ty) + 0.5) * inv
				var seed := Vector2(seed_x[index], seed_y[index])
				var d := sqrt(best[index])
				signed = clampf(d if inside else -d, -limit, limit)
				if d > 0.0001:
					towards_land = (seed - centre) / d if inside else (centre - seed) / d
				kind = seed_type[index]
			distance[index] = signed
			direction[index] = towards_land
			shore_type[index] = kind
			rgba[index * 4] = signed
			rgba[index * 4 + 1] = towards_land.x * 0.5 + 0.5
			rgba[index * 4 + 2] = towards_land.y * 0.5 + 0.5
			rgba[index * 4 + 3] = kind
	# Half float keeps +-8 units at ~0.004 precision and is a filterable GLES3
	# format; building through RGBAF avoids a per-texel set_pixel loop.
	var image := Image.create_from_data(
		width, height, false, Image.FORMAT_RGBAF, rgba.to_byte_array()
	)
	image.convert(Image.FORMAT_RGBAH)
	return {
		"image": image,
		"origin": Vector2.ZERO,
		"size": Vector2(columns, rows),
		"width": width,
		"height": height,
		"distance": distance,
		"direction": direction,
		"type": shore_type,
		"has_beach": has_beach,
	}


## Records one contour crossing as [texel, texel, point, type]; sea/river
## junctions (type -1) are not shorelines and are skipped.
static func _add_shore_crossing(
	crossings: Array[Array],
	grid: MapTerrainGrid,
	coverage: PackedFloat32Array,
	width: int,
	index: int,
	other_index: int,
	step: Vector2
) -> void:
	var threshold := MapViewMeshBuilderConfig.WATER_CONTOUR_THRESHOLD
	var inv := 1.0 / float(SHORE_FIELD_TEXELS_PER_CELL)
	var here := coverage[index]
	var there := coverage[other_index]
	var a := Vector2(float(index % width) + 0.5, float(index / width) + 0.5) * inv
	var point := a + step * inv * ((threshold - here) / (there - here))
	var land_dir := step if here >= threshold else -step
	var kind := _shore_seed_type(grid, point, land_dir)
	if kind >= 0.0:
		crossings.append([index, other_index, point, kind])


## 1 = beach, 0 = hard edge, -1 = not a shoreline (a sea/river junction).
static func _shore_seed_type(grid: MapTerrainGrid, point: Vector2, land_dir: Vector2) -> float:
	var land := _probe_terrain(grid, point, land_dir, false)
	var water := _probe_terrain(grid, point, -land_dir, true)
	if land == &"" or MapTypes.WATER_TERRAINS.has(land):
		return -1.0
	if land in SHORE_BEACH_TERRAINS and water in SHORE_SEA_WATER:
		return 1.0
	return 0.0


## First terrain along the probe whose water-ness matches `want_water`.
static func _probe_terrain(
	grid: MapTerrainGrid, point: Vector2, direction: Vector2, want_water: bool
) -> StringName:
	for step in range(1, _SHORE_PROBE_STEPS + 1):
		var sample := point + direction * (_SHORE_PROBE_STEP * float(step))
		var cell := Vector2i(
			clampi(floori(sample.x), 0, grid.size_cells.x - 1),
			clampi(floori(sample.y), 0, grid.size_cells.y - 1)
		)
		var terrain := grid.get_terrain(cell)
		var is_water := MapTypes.WATER_TERRAINS.has(terrain)
		if want_water and is_water:
			return terrain
		if not want_water and (not is_water or terrain == MapTypes.TERRAIN_RIVER_WATER):
			return terrain
	return &""


## Bilinear signed distance (world units) at a world XZ position.
static func shore_distance_at(shore: Dictionary, world_xz: Vector2) -> float:
	return _shore_bilinear(shore, shore["distance"], world_xz)


static func shore_type_at(shore: Dictionary, world_xz: Vector2) -> float:
	return _shore_bilinear(shore, shore["type"], world_xz)


static func shore_direction_at(shore: Dictionary, world_xz: Vector2) -> Vector2:
	var width: int = shore["width"]
	var height: int = shore["height"]
	var texel := (world_xz - (shore["origin"] as Vector2)) * float(SHORE_FIELD_TEXELS_PER_CELL)
	var cell := Vector2i(
		clampi(floori(texel.x), 0, width - 1), clampi(floori(texel.y), 0, height - 1)
	)
	return (shore["direction"] as PackedVector2Array)[cell.y * width + cell.x]


static func _shore_bilinear(
	shore: Dictionary, values: PackedFloat32Array, world_xz: Vector2
) -> float:
	var width: int = shore["width"]
	var height: int = shore["height"]
	var texel := (
		(world_xz - (shore["origin"] as Vector2)) * float(SHORE_FIELD_TEXELS_PER_CELL)
		- Vector2(0.5, 0.5)
	)
	var base := Vector2i(floori(texel.x), floori(texel.y))
	var local := texel - Vector2(base)
	var x0 := clampi(base.x, 0, width - 1)
	var x1 := clampi(base.x + 1, 0, width - 1)
	var y0 := clampi(base.y, 0, height - 1) * width
	var y1 := clampi(base.y + 1, 0, height - 1) * width
	return lerpf(
		lerpf(values[y0 + x0], values[y0 + x1], local.x),
		lerpf(values[y1 + x0], values[y1 + x1], local.x),
		local.y
	)


## Thin view-only film over beach sand, SHORE_SHEET_REACH units inland. Every
## terrain triangle in the band is split at its edge midpoints, so the sheet lies
## exactly in the terrain plane (+ lift) at twice the terrain density: 18 rows
## across a 3-unit reach. Returns null when the map has no beach.
static func build_swash_sheet_mesh(field: Dictionary, shore: Dictionary) -> ArrayMesh:
	var arrays := swash_sheet_arrays(field, shore)
	if arrays.is_empty():
		return null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## WB-07b: the swash sheet surface arrays, empty when there is no beach band.
## Pure; staged assembly bakes them on a worker.
static func swash_sheet_arrays(field: Dictionary, shore: Dictionary) -> Array:
	if shore.is_empty() or not bool(shore.get("has_beach", false)):
		return []
	if not field.has("positions"):
		return []
	var columns: int = field["vertex_columns"]
	var positions: PackedVector3Array = field["positions"]
	var normals: PackedVector3Array = field["normals"]
	var size: Vector2i = field["size"]
	var subdivisions := MapViewMeshBuilderConfig.TERRAIN_SUBDIVISIONS
	var vertices := PackedVector3Array()
	var vertex_normals := PackedVector3Array()
	# Cell centres farther than a cell diagonal from the band cannot touch it.
	var band_margin := 0.75
	for cell_y in size.y:
		for cell_x in size.x:
			var land := -shore_distance_at(shore, Vector2(cell_x + 0.5, cell_y + 0.5))
			if (
				land < -(SHORE_SHEET_SEAWARD_MARGIN + band_margin)
				or land > SHORE_SHEET_REACH + band_margin
			):
				continue
			for patch_y in subdivisions:
				for patch_x in subdivisions:
					var top_left := (
						(cell_y * subdivisions + patch_y) * columns + cell_x * subdivisions + patch_x
					)
					var bottom_left := top_left + columns
					# Same diagonal as the blended ground mesh, so midpoints stay on it.
					for triangle: Array in [
						[top_left, top_left + 1, bottom_left + 1],
						[top_left, bottom_left + 1, bottom_left],
					]:
						_add_sheet_triangle(
							vertices, vertex_normals, shore, positions, normals, triangle
						)
	if vertices.is_empty():
		return []
	var colors := PackedColorArray()
	colors.resize(vertices.size())
	# COLOR.r is the water shader's shore factor; the sheet sits past the contour.
	colors.fill(Color.WHITE)
	var uvs := PackedVector2Array()
	uvs.resize(vertices.size())
	for index in vertices.size():
		uvs[index] = (
			Vector2(vertices[index].x, vertices[index].z)
			/ MapViewMaterials.TERRAIN_TEXTURE_WORLD_SIZE
		)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = vertex_normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	return arrays


static func _add_sheet_triangle(
	vertices: PackedVector3Array,
	vertex_normals: PackedVector3Array,
	shore: Dictionary,
	positions: PackedVector3Array,
	normals: PackedVector3Array,
	triangle: Array
) -> void:
	var corners: Array[Vector3] = []
	var corner_normals: Array[Vector3] = []
	var nearest := INF
	var farthest := -INF
	for index: int in triangle:
		var corner := positions[index]
		corners.append(corner)
		corner_normals.append(normals[index])
		var land := -shore_distance_at(shore, Vector2(corner.x, corner.z))
		nearest = minf(nearest, land)
		farthest = maxf(farthest, land)
	if farthest < -SHORE_SHEET_SEAWARD_MARGIN or nearest > SHORE_SHEET_REACH:
		return
	var centroid := (corners[0] + corners[1] + corners[2]) / 3.0
	if shore_type_at(shore, Vector2(centroid.x, centroid.z)) < 0.5:
		return
	var mid: Array[Vector3] = [
		(corners[0] + corners[1]) * 0.5,
		(corners[1] + corners[2]) * 0.5,
		(corners[2] + corners[0]) * 0.5,
	]
	var mid_normals: Array[Vector3] = [
		(corner_normals[0] + corner_normals[1]).normalized(),
		(corner_normals[1] + corner_normals[2]).normalized(),
		(corner_normals[2] + corner_normals[0]).normalized(),
	]
	var lift := Vector3(0.0, SHORE_SHEET_LIFT, 0.0)
	for sub: Array in [
		[corners[0], mid[0], mid[2], corner_normals[0], mid_normals[0], mid_normals[2]],
		[mid[0], corners[1], mid[1], mid_normals[0], corner_normals[1], mid_normals[1]],
		[mid[2], mid[1], corners[2], mid_normals[2], mid_normals[1], corner_normals[2]],
		[mid[0], mid[1], mid[2], mid_normals[0], mid_normals[1], mid_normals[2]],
	]:
		for vertex_index in 3:
			vertices.append((sub[vertex_index] as Vector3) + lift)
			vertex_normals.append(sub[vertex_index + 3] as Vector3)


## R-1160: the river channel centreline of this map, as a pure function of the
## grid, so it can be baked on a worker beside the shore field.
static func compute_river_flow(grid: MapTerrainGrid) -> PackedVector3Array:
	return RIVER_FLOW.channel_centreline(grid, MapViewMaterials.WATER_MATERIALS.RIVER_FLOW_DIRECTION)


## Main-thread half of compute_river_flow(). Rebinding on every tree entry
## follows the shore field: the water materials are shared by all map views, and
## a cached map scene re-enters the tree without being rebuilt.
static func attach_river_flow(root: Node3D, path: PackedVector3Array) -> void:
	MapViewMaterials.apply_river_flow(path)
	root.tree_entered.connect(func() -> void: MapViewMaterials.apply_river_flow(path))


## Binds the shore field to the shared terrain/water materials and adds the swash
## sheet under the terrain root. The binding is repeated on every tree entry:
## the materials are shared by all map views, and a cached map scene re-enters
## the tree without being rebuilt.
static func add_shore_swash(root: Node3D, field: Dictionary, grid: MapTerrainGrid) -> void:
	var shore := {} if field.get("flat_floor", false) else bake_shore_field(field, grid)
	var sheet_arrays: Array = []
	if MapViewMaterials.shore_swash_sheet_enabled():
		sheet_arrays = swash_sheet_arrays(field, shore)
	attach_shore_swash(root, grid, shore, sheet_arrays)


## Main-thread half of add_shore_swash(): binds a finished shore field and adds
## the sheet built from swash_sheet_arrays() (empty arrays add no sheet).
static func attach_shore_swash(
	root: Node3D, grid: MapTerrainGrid, shore: Dictionary, sheet_arrays: Array
) -> void:
	var texture: Texture2D = shore.get("texture", null)
	var origin: Vector2 = shore.get("origin", Vector2.ZERO)
	var extent: Vector2 = shore.get("size", Vector2.ONE)
	MapViewMaterials.apply_shore_field(texture, origin, extent)
	root.tree_entered.connect(
		func() -> void: MapViewMaterials.apply_shore_field(texture, origin, extent)
	)
	if sheet_arrays.is_empty():
		return
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sheet_arrays)
	var sheet_terrain := MapTypes.TERRAIN_SHALLOW_WATER
	var used := grid.used_terrain_ids()
	if not used.has(sheet_terrain) and used.has(MapTypes.TERRAIN_DEEP_WATER):
		sheet_terrain = MapTypes.TERRAIN_DEEP_WATER
	var sheet := MeshInstance3D.new()
	sheet.name = "ShoreSwashSheet"
	sheet.mesh = mesh
	sheet.material_override = MapViewMaterials.swash_sheet_material(sheet_terrain)
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(sheet)
