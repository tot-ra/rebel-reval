class_name MapViewMeshBuilderTerrainWater
extends RefCounted

## Smoothed water contours and recessed water-surface mesh generation.


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
	return {"values": values, "source": source, "columns": columns, "rows": rows, "max_coverage": max_coverage}


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
		lerpf(top_left, top_right, local.x),
		lerpf(bottom_left, bottom_right, local.x),
		local.y
	)


static func combined_water_coverage_at(field: Dictionary, sample: Vector2) -> float:
	var coverage := 0.0
	for terrain_id: StringName in field.get("water_contours", {}).keys():
		coverage = maxf(coverage, water_coverage_at(field, sample, terrain_id))
	return coverage


static func cell_near_terrain(field: Dictionary, cell: Vector2i, terrain_id: StringName) -> bool:
	for probe in [
		Vector2(cell), Vector2(cell) + Vector2(1.0, 0.0), Vector2(cell) + Vector2.ONE,
		Vector2(cell) + Vector2(0.0, 1.0), Vector2(cell) + Vector2(0.5, 0.5),
	]:
		if water_coverage_at(field, probe, terrain_id) >= MapViewMeshBuilderConfig.WATER_CONTOUR_THRESHOLD:
			return true
	return false


static func add_water_cell_quad(
	surface: SurfaceTool,
	field: Dictionary,
	grid: MapTerrainGrid,
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
				corners.append({
					"position": vertex,
					"coverage": water_coverage_at(field, Vector2(vertex.x, vertex.z), terrain_id),
				})
			if (vertex_x + vertex_y) % 2 == 0:
				_add_clipped_water_triangle(surface, corners[0], corners[1], corners[2])
				_add_clipped_water_triangle(surface, corners[0], corners[2], corners[3])
			else:
				_add_clipped_water_triangle(surface, corners[0], corners[1], corners[3])
				_add_clipped_water_triangle(surface, corners[1], corners[2], corners[3])


static func _water_contour_sample(contour: Dictionary, cell: Vector2i) -> float:
	var columns: int = contour["columns"]
	var rows: int = contour["rows"]
	var clamped := Vector2i(clampi(cell.x, 0, columns - 1), clampi(cell.y, 0, rows - 1))
	var values: PackedFloat32Array = contour["values"]
	if float(contour["max_coverage"]) < MapViewMeshBuilderConfig.WATER_CONTOUR_THRESHOLD:
		values = contour["source"]
	return values[clamped.y * columns + clamped.x]


static func _add_clipped_water_triangle(
	surface: SurfaceTool,
	first: Dictionary,
	second: Dictionary,
	third: Dictionary
) -> void:
	var polygon: Array[Dictionary] = [first, second, third]
	var clipped: Array[Dictionary] = []
	for index in polygon.size():
		var current := polygon[index]
		var previous := polygon[(index + polygon.size() - 1) % polygon.size()]
		var threshold := MapViewMeshBuilderConfig.WATER_CONTOUR_THRESHOLD
		var current_inside := float(current["coverage"]) >= threshold
		var previous_inside := float(previous["coverage"]) >= threshold
		if current_inside != previous_inside:
			var previous_coverage := float(previous["coverage"])
			var span := float(current["coverage"]) - previous_coverage
			var weight := (threshold - previous_coverage) / span
			clipped.append({
				"position": (previous["position"] as Vector3).lerp(current["position"] as Vector3, weight),
				"coverage": threshold,
			})
		if current_inside:
			clipped.append(current)
	if clipped.size() < 3:
		return
	for index in range(1, clipped.size() - 1):
		_add_water_vertex(surface, clipped[0]["position"], float(clipped[0]["coverage"]))
		_add_water_vertex(surface, clipped[index]["position"], float(clipped[index]["coverage"]))
		_add_water_vertex(
			surface,
			clipped[index + 1]["position"],
			float(clipped[index + 1]["coverage"])
		)


static func _add_water_vertex(surface: SurfaceTool, source: Vector3, coverage: float) -> void:
	var vertex := Vector3(
		source.x,
		-MapViewMeshBuilderConfig.WATER_RECESS + MapViewMeshBuilderConfig.WATER_SURFACE_LIFT,
		source.z
	)
	var threshold := MapViewMeshBuilderConfig.WATER_CONTOUR_THRESHOLD
	var interior_coverage := inverse_lerp(threshold, 1.0, coverage)
	surface.set_normal(Vector3.UP)
	surface.set_uv(Vector2(vertex.x, vertex.z) / MapViewMaterials.TERRAIN_TEXTURE_WORLD_SIZE)
	surface.set_color(Color(interior_coverage, interior_coverage, interior_coverage, 1.0))
	surface.add_vertex(vertex)
