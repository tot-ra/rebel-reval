class_name MapViewMeshBuilderTerrain
extends RefCounted

## Terrain height field and ground mesh generation.

## Deterministic per-map height field shared by the terrain mesh, scatter,
## trees, and actor sync so everything sits on the same rolling ground.
static var _height_fields: Dictionary = {}
static var _height_field_keys_by_definition: Dictionary = {}

static func ensure_height_field(definition: MapDefinition, grid: MapTerrainGrid) -> Dictionary:
	var key := _height_field_key(definition, grid)
	if _height_fields.has(key):
		return _height_fields[key]
	var scale := MapViewBridge.world_scale(definition.cell_size)
	var rects: Array[Rect2] = []
	for building in definition.buildings:
		var footprint: Rect2 = building["footprint"]
		rects.append(Rect2(footprint.position * scale, footprint.size * scale).grow(0.75))
	for transition in definition.transitions:
		var rect: Rect2 = transition["rect"]
		rects.append(Rect2(rect.position * scale, rect.size * scale).grow(0.5))
	for landmark in definition.view_landmarks:
		var rect: Rect2 = landmark["rect"]
		rects.append(Rect2(rect.position * scale, rect.size * scale).grow(0.75))
	var water := {}
	for y in grid.size_cells.y:
		for x in grid.size_cells.x:
			if MapViewMaterials.WATER_TERRAINS.has(grid.get_terrain(Vector2i(x, y))):
				water[Vector2i(x, y)] = true
	var water_factors := _bake_water_factors(water, grid.size_cells)
	var water_contours := {}
	for terrain_id in grid.used_terrain_ids():
		if MapViewMaterials.WATER_TERRAINS.has(terrain_id):
			water_contours[terrain_id] = MapViewMeshBuilderTerrainWater.bake_water_contour(grid, terrain_id)
	var field := {
		"seed": definition.seed,
		"ground_elevation": definition.ground_elevation,
		"size": grid.size_cells,
		"rects": rects,
		"rects_by_cell": _index_flatten_rects(rects, grid.size_cells),
		"water": water,
		"water_factors": water_factors,
		"water_contours": water_contours,
		# Enclosed interior shells keep gameplay on a flat logic plane; rolling
		# outdoor relief would lift props and actors off the floor in 3D view.
		"flat_floor": definition.suppresses_exterior_surroundings(),
	}
	_height_fields[key] = field
	_height_field_keys_by_definition[_definition_height_key(definition)] = key
	bake_vertices(field)
	return field


static func _height_field_key(definition: MapDefinition, grid: MapTerrainGrid) -> String:
	return "%s:%s:%s" % [
		_definition_height_key(definition),
		grid.size_cells,
		grid.fingerprint(),
	]


static func _definition_height_key(definition: MapDefinition) -> String:
	return "%s:%s:%s:%d" % [
		String(definition.map_id),
		String(definition.fingerprint),
		definition.size_cells,
		definition.seed,
	]

## Index level pads by the only cells they can influence. Height sampling runs for
## every terrain subvertex, so scanning every building and transition there made
## district startup O(vertices * map objects) even though the flatten radius is local.
static func _index_flatten_rects(rects: Array[Rect2], size: Vector2i) -> Dictionary:
	var indexed := {}
	var influence := MapViewMeshBuilderConfig.FLATTEN_END
	for rect in rects:
		var affected := rect.grow(influence)
		var start := Vector2i(
			clampi(floori(affected.position.x), 0, size.x - 1),
			clampi(floori(affected.position.y), 0, size.y - 1)
		)
		var finish := Vector2i(
			clampi(ceili(affected.end.x), 0, size.x),
			clampi(ceili(affected.end.y), 0, size.y)
		)
		for y in range(start.y, finish.y):
			for x in range(start.x, finish.x):
				var cell := Vector2i(x, y)
				if not indexed.has(cell):
					indexed[cell] = []
				(indexed[cell] as Array).append(rect)
	return indexed

static func _bake_water_factors(water: Dictionary, size: Vector2i) -> PackedFloat32Array:
	var factors := PackedFloat32Array()
	factors.resize(size.x * size.y)
	if water.is_empty():
		factors.fill(1.0)
		return factors
	var radius := MapViewMeshBuilderConfig.WATER_FLATTEN_CELLS
	for y in size.y:
		for x in size.x:
			var nearest := float(radius + 1)
			var cell := Vector2i(x, y)
			for oy in range(-radius, radius + 1):
				for ox in range(-radius, radius + 1):
					if water.has(cell + Vector2i(ox, oy)):
						nearest = minf(nearest, maxf(absf(float(ox)), absf(float(oy))))
			factors[y * size.x + x] = smoothstep(0.6, float(radius), nearest)
	return factors


## Ground height (world units) of the visible terrain at a world XZ position.
## Zero when the map has no baked height field or outside the playable bounds.


static func ground_height(definition: MapDefinition, world_xz: Vector2) -> float:
	var field_key := String(_height_field_keys_by_definition.get(_definition_height_key(definition), ""))
	var field: Dictionary = _height_fields.get(field_key, {})
	if field.is_empty():
		return 0.0
	return field_height(field, world_xz)




static func field_height(field: Dictionary, position: Vector2) -> float:
	if field.get("flat_floor", false):
		return 0.0
	var size: Vector2i = field["size"]
	if position.x < 0.0 or position.y < 0.0 or position.x > float(size.x) or position.y > float(size.y):
		return 0.0
	var cell := Vector2i(floori(position.x), floori(position.y))
	if field["water"].has(cell):
		return -MapViewMeshBuilderConfig.WATER_RECESS
	var noise_seed: int = field["seed"]
	var broad := value_noise(position / MapViewMeshBuilderConfig.HEIGHT_BROAD_PERIOD, noise_seed + 7717)
	var fine := value_noise(position / MapViewMeshBuilderConfig.HEIGHT_FINE_PERIOD, noise_seed + 8317)
	var relief := broad * MapViewMeshBuilderConfig.HEIGHT_BROAD_AMPLITUDE + fine * MapViewMeshBuilderConfig.HEIGHT_FINE_AMPLITUDE
	var base_elevation := float(field.get("ground_elevation", 0.0)) * elevation_factor(field, position)
	return base_elevation + relief * minf(pad_factor(field, position), water_factor(field, position))


## Elevated outdoor maps share a zero-height datum at their authored bounds so
## reciprocal transition edges still meet. The interior rises smoothly into a
## broad plateau instead of lifting collision or changing 2D map coordinates.
static func elevation_factor(field: Dictionary, position: Vector2) -> float:
	if field.get("flat_floor", false):
		return 0.0
	var size: Vector2i = field["size"]
	var border := minf(
		minf(position.x, float(size.x) - position.x),
		minf(position.y, float(size.y) - position.y)
	)
	return smoothstep(0.0, MapViewMeshBuilderConfig.ELEVATION_SLOPE_CELLS, border)


## Smooth value noise in [0, 1] over an integer lattice.


static func value_noise(p: Vector2, noise_seed: int) -> float:
	var xi := floori(p.x)
	var yi := floori(p.y)
	var fx := p.x - float(xi)
	var fy := p.y - float(yi)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := MapViewMeshBuilderPrimitives.hash01(xi, yi, noise_seed)
	var b := MapViewMeshBuilderPrimitives.hash01(xi + 1, yi, noise_seed)
	var c := MapViewMeshBuilderPrimitives.hash01(xi, yi + 1, noise_seed)
	var d := MapViewMeshBuilderPrimitives.hash01(xi + 1, yi + 1, noise_seed)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


## 0 on building/transition pads and at the map border, easing to 1 beyond
## MapViewMeshBuilderConfig.FLATTEN_END so level gameplay pads blend into the rolling ground.


static func pad_factor(field: Dictionary, position: Vector2) -> float:
	var size: Vector2i = field["size"]
	var border := minf(
		minf(position.x, float(size.x) - position.x),
		minf(position.y, float(size.y) - position.y)
	)
	var factor := clampf(border / MapViewMeshBuilderConfig.BORDER_FLATTEN_CELLS, 0.0, 1.0)
	var rects_by_cell: Dictionary = field.get("rects_by_cell", {})
	var position_cell := Vector2i(floori(position.x), floori(position.y))
	var nearby_rects: Array = rects_by_cell.get(position_cell, [])
	for rect: Rect2 in nearby_rects:
		var dx := maxf(maxf(rect.position.x - position.x, position.x - rect.end.x), 0.0)
		var dy := maxf(maxf(rect.position.y - position.y, position.y - rect.end.y), 0.0)
		var distance := Vector2(dx, dy).length()
		factor = minf(factor, smoothstep(MapViewMeshBuilderConfig.FLATTEN_START, MapViewMeshBuilderConfig.FLATTEN_END, distance))
	return factor




static func water_factor(field: Dictionary, position: Vector2) -> float:
	var size: Vector2i = field["size"]
	var cell := Vector2i(
		clampi(floori(position.x), 0, size.x - 1),
		clampi(floori(position.y), 0, size.y - 1)
	)
	var factors: PackedFloat32Array = field["water_factors"]
	return factors[cell.y * size.x + cell.x]


## Shared sub-cell vertex positions and normals: lateral jitter bends terrain
## borders while neighboring patches reuse identical vertices, keeping the
## ground watertight. Vertices touching water drop to the recess depth.


static func bake_vertices(field: Dictionary) -> void:
	var size: Vector2i = field["size"]
	var noise_seed: int = field["seed"]
	var columns := size.x * MapViewMeshBuilderConfig.TERRAIN_SUBDIVISIONS + 1
	var rows := size.y * MapViewMeshBuilderConfig.TERRAIN_SUBDIVISIONS + 1
	var positions := PackedVector3Array()
	positions.resize(columns * rows)
	for vy in rows:
		for vx in columns:
			var base := Vector2(vx, vy) / float(MapViewMeshBuilderConfig.TERRAIN_SUBDIVISIONS)
			var jitter := Vector2.ZERO
			var spot := base
			if not field.get("flat_floor", false):
				var jitter_scale := pad_factor(field, base)
				jitter = Vector2(
					MapViewMeshBuilderPrimitives.hash01(vx, vy, noise_seed + 8887) - 0.5,
					MapViewMeshBuilderPrimitives.hash01(vx, vy, noise_seed + 9973) - 0.5
				) * MapViewMeshBuilderConfig.EDGE_JITTER * jitter_scale
				if vx == 0 or vy == 0 or vx == columns - 1 or vy == rows - 1:
					jitter = Vector2.ZERO
				spot = base + jitter
			var height := -MapViewMeshBuilderConfig.WATER_RECESS if subvertex_touches_water(field, vx, vy) else field_height(field, spot)
			positions[vy * columns + vx] = Vector3(spot.x, height, spot.y)
	var normals := PackedVector3Array()
	normals.resize(columns * rows)
	for vy in rows:
		for vx in columns:
			var left := positions[vy * columns + maxi(vx - 1, 0)].y
			var right := positions[vy * columns + mini(vx + 1, columns - 1)].y
			var up := positions[maxi(vy - 1, 0) * columns + vx].y
			var down := positions[mini(vy + 1, rows - 1) * columns + vx].y
			normals[vy * columns + vx] = Vector3(left - right, 2.0, up - down).normalized()
	field["positions"] = positions
	field["normals"] = normals
	field["vertex_columns"] = columns


## Sample each side of a subvertex so shoreline vertices are shared by the
## recessed water and its bank while interior water vertices stay level.


static func subvertex_touches_water(field: Dictionary, vx: int, vy: int) -> bool:
	var water: Dictionary = field["water"]
	var size: Vector2i = field["size"]
	var base := Vector2(vx, vy) / float(MapViewMeshBuilderConfig.TERRAIN_SUBDIVISIONS)
	for nudge: Vector2 in [Vector2(-0.001, -0.001), Vector2(0.001, -0.001), Vector2(-0.001, 0.001), Vector2(0.001, 0.001)]:
		var sample: Vector2 = base + nudge
		if sample.x < 0.0 or sample.y < 0.0 or sample.x >= size.x or sample.y >= size.y:
			continue
		var cell := Vector2i(floori(sample.x), floori(sample.y))
		if water.has(cell):
			return true
	return false


## One unified dry-ground mesh with per-vertex terrain splatting plus separate
## water-family meshes recessed under animated surfaces.


static func build_terrain(definition: MapDefinition, grid: MapTerrainGrid) -> Node3D:
	var root := Node3D.new()
	root.name = "Terrain"
	var field := ensure_height_field(definition, grid)
	var ground_mesh := _build_blended_ground_mesh(field, grid, definition.seed)
	if ground_mesh != null:
		var ground := MeshInstance3D.new()
		ground.name = "Terrain_Ground"
		ground.mesh = ground_mesh
		ground.material_override = MapViewMaterials.blended_ground(definition.seed)
		root.add_child(ground)
	for terrain_id in grid.used_terrain_ids():
		if not MapViewMaterials.WATER_TERRAINS.has(terrain_id):
			continue
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for y in grid.size_cells.y:
			for x in grid.size_cells.x:
				if not MapViewMeshBuilderTerrainWater.cell_near_terrain(field, Vector2i(x, y), terrain_id):
					continue
				MapViewMeshBuilderTerrainWater.add_water_cell_quad(surface, field, grid, x, y, terrain_id)
		var instance := MeshInstance3D.new()
		instance.name = "Terrain_%s" % String(terrain_id)
		var mesh := surface.commit()
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		instance.mesh = mesh
		instance.material_override = MapViewMaterials.water_surface(terrain_id)
		root.add_child(instance)
	return root


## Deterministic per-cell brightness: fine jitter over a broad patch drift.


static func cell_tone(x: int, y: int, noise_seed: int, style_variant: StringName = &"") -> float:
	var fine := MapViewMeshBuilderPrimitives.hash01(x, y, noise_seed)
	var patch := MapViewMeshBuilderPrimitives.hash01(
		floori(float(x) / MapViewMeshBuilderConfig.TERRAIN_PATCH_CELLS),
		floori(float(y) / MapViewMeshBuilderConfig.TERRAIN_PATCH_CELLS),
		noise_seed + 977
	)
	var tone := 1.0
	tone += (fine * 2.0 - 1.0) * MapViewMeshBuilderConfig.TERRAIN_JITTER
	tone += (patch * 2.0 - 1.0) * MapViewMeshBuilderConfig.TERRAIN_PATCH_STRENGTH
	var tint := TerrainVegetation.ground_color_tint(style_variant)
	tone *= (tint.r + tint.g + tint.b) / 3.0
	return clampf(tone, 0.75, 1.2)




## Build the continuous ground as packed indexed arrays. The old SurfaceTool path
## emitted every triangle corner separately and recalculated its terrain blend,
## turning a 176 x 112 map into more than one million vertices during every scene
## change. The visual 3 x 3 grid is unchanged; each shared vertex is evaluated once.
static func _build_blended_ground_mesh(
	field: Dictionary,
	grid: MapTerrainGrid,
	noise_seed: int
) -> ArrayMesh:
	if grid.size_cells.x <= 0 or grid.size_cells.y <= 0:
		return null
	var columns: int = field["vertex_columns"]
	var positions: PackedVector3Array = field["positions"]
	var normals: PackedVector3Array = field["normals"]
	var rows := grid.size_cells.y * MapViewMeshBuilderConfig.TERRAIN_SUBDIVISIONS + 1
	var vertex_count := columns * rows
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var custom := PackedFloat32Array()
	colors.resize(vertex_count)
	uvs.resize(vertex_count)
	custom.resize(vertex_count * 4)
	for vertex_y in rows:
		for vertex_x in columns:
			var vertex_index := vertex_y * columns + vertex_x
			var vertex := positions[vertex_index]
			var spot := Vector2(vertex.x, vertex.z)
			var source_cell := Vector2i(
				clampi(floori(spot.x), 0, grid.size_cells.x - 1),
				clampi(floori(spot.y), 0, grid.size_cells.y - 1)
			)
			var blend := terrain_blend_at(
				field,
				grid,
				spot,
				noise_seed,
				source_cell.x,
				source_cell.y
			)
			var primary_tint := OutdoorTerrainPalette.color(blend["primary"])
			var secondary_tint := OutdoorTerrainPalette.color(blend["secondary"])
			colors[vertex_index] = primary_tint.lerp(secondary_tint, float(blend["weight"]))
			uvs[vertex_index] = spot / MapViewMaterials.TERRAIN_TEXTURE_WORLD_SIZE
			var custom_index := vertex_index * 4
			custom[custom_index] = float(blend["primary_index"])
			custom[custom_index + 1] = float(blend["secondary_index"])
			custom[custom_index + 2] = float(blend["weight"])
			custom[custom_index + 3] = float(blend["tone"])
	var indices := PackedInt32Array()
	indices.resize((rows - 1) * (columns - 1) * 6)
	var write_index := 0
	for patch_y in rows - 1:
		for patch_x in columns - 1:
			var top_left := patch_y * columns + patch_x
			var bottom_left := top_left + columns
			indices[write_index] = top_left
			indices[write_index + 1] = top_left + 1
			indices[write_index + 2] = bottom_left + 1
			indices[write_index + 3] = top_left
			indices[write_index + 4] = bottom_left + 1
			indices[write_index + 5] = bottom_left
			write_index += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_CUSTOM0] = custom
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	var custom_format := RenderingServer.ARRAY_CUSTOM_RGBA_FLOAT << RenderingServer.ARRAY_FORMAT_CUSTOM0_SHIFT
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, custom_format)
	return mesh


static func terrain_blend_at(
	field: Dictionary,
	grid: MapTerrainGrid,
	sample: Vector2,
	noise_seed: int,
	cell_x: int,
	cell_y: int
) -> Dictionary:
	var warped := sample
	var warp := Vector2(
		value_noise(sample / 2.4, noise_seed + 12101) - 0.5,
		value_noise(sample / 2.4, noise_seed + 12703) - 0.5
	) * MapViewMeshBuilderConfig.VISUAL_EDGE_WARP
	warped += warp
	warped.x = clampf(warped.x, 0.0, float(grid.size_cells.x) - 0.001)
	warped.y = clampf(warped.y, 0.0, float(grid.size_cells.y) - 0.001)
	var cell := Vector2i(floori(warped.x), floori(warped.y))
	var primary: StringName = _ground_terrain_at(grid, cell)
	var secondary: StringName = primary
	var weight := 0.0
	var local := Vector2(warped.x - float(cell.x), warped.y - float(cell.y))
	var blend_width := MapViewMeshBuilderConfig.TERRAIN_BLEND_WIDTH
	var neighbors := [
		[Vector2i(1, 0), local.x, 1.0 - local.x],
		[Vector2i(-1, 0), 1.0 - local.x, local.x],
		[Vector2i(0, 1), local.y, 1.0 - local.y],
		[Vector2i(0, -1), 1.0 - local.y, local.y],
	]
	for entry in neighbors:
		var offset: Vector2i = entry[0]
		var edge_distance: float = entry[2]
		if edge_distance > blend_width:
			continue
		var neighbor_cell := cell + offset
		if neighbor_cell.x < 0 or neighbor_cell.y < 0 or neighbor_cell.x >= grid.size_cells.x or neighbor_cell.y >= grid.size_cells.y:
			continue
		var neighbor: StringName = _ground_terrain_at(grid, neighbor_cell)
		if neighbor == primary:
			continue
		var candidate := smoothstep(blend_width, 0.0, edge_distance)

		if candidate > weight:
			weight = candidate
			secondary = neighbor
	if weight > 0.01 and weight < 0.99:
		var dither := value_noise(warped * 7.5, noise_seed + 555) * 0.14 - 0.07
		weight = clampf(weight + dither, 0.0, 1.0)
	var variant := grid.get_style_variant(Vector2i(cell_x, cell_y))
	var tone := cell_tone(cell_x, cell_y, noise_seed, variant)
	var shore := shore_blend_at(field, grid, sample, noise_seed)
	if not shore.is_empty():
		primary = shore["primary"]
		secondary = shore["secondary"]
		weight = shore["weight"]
		tone *= shore["tone"]
	return {
		"primary": primary,
		"secondary": secondary,
		"weight": weight,
		"tone": tone,
		"primary_index": MapViewMaterials.terrain_blend_index(primary),
		"secondary_index": MapViewMaterials.terrain_blend_index(secondary),
	}




## Soft inland bank from the combined smoothed water field:
## damp dirt into muted coast silt, then wet mud with only mild darkening.
## Returning an empty dictionary leaves hard-surface quay edges untouched.
static func shore_blend_at(
	field: Dictionary,
	grid: MapTerrainGrid,
	sample: Vector2,
	noise_seed: int
) -> Dictionary:
	var cell := Vector2i(
		clampi(floori(sample.x), 0, grid.size_cells.x - 1),
		clampi(floori(sample.y), 0, grid.size_cells.y - 1)
	)
	var authored_ground := _ground_terrain_at(grid, cell)
	if authored_ground not in MapViewMeshBuilderConfig.NATURAL_SHORE_TERRAINS:
		return {}
	var coverage := MapViewMeshBuilderTerrainWater.combined_water_coverage_at(field, sample)
	var band_warp := (
		value_noise(sample * 0.72, noise_seed + 16661) - 0.5
	) * MapViewMeshBuilderConfig.SHORE_COVERAGE_WARP
	coverage += band_warp
	var outer := MapViewMeshBuilderConfig.SHORE_SAND_OUTER_COVERAGE
	var silt_inner := MapViewMeshBuilderConfig.SHORE_SAND_INNER_COVERAGE
	var mud_inner := MapViewMeshBuilderConfig.SHORE_MUD_INNER_COVERAGE
	var waterline := MapViewMeshBuilderConfig.WATER_CONTOUR_THRESHOLD
	if coverage < outer or coverage >= waterline:
		return {}
	# Outer: authored grass/meadow keeps reading through a damp dirt veil.
	if coverage < silt_inner:
		var outer_t := smoothstep(outer, silt_inner, coverage)
		return {
			"primary": authored_ground,
			"secondary": MapTypes.TERRAIN_DIRT,
			"weight": outer_t * MapViewMeshBuilderConfig.SHORE_SILT_BLEND_CAP,
			"tone": lerpf(1.0, 0.97, outer_t),
		}
	# Mid: damp dirt feathers straight into wet mud. Bright sand is avoided so
	# the bank stays value-matched with grass instead of flashing a beach stripe.
	if coverage < mud_inner:
		var mid_t := smoothstep(silt_inner, mud_inner, coverage)
		return {
			"primary": MapTypes.TERRAIN_DIRT,
			"secondary": MapTypes.TERRAIN_MUD,
			"weight": lerpf(
				MapViewMeshBuilderConfig.SHORE_SILT_BLEND_CAP * 0.55,
				MapViewMeshBuilderConfig.SHORE_MUD_BLEND_CAP,
				mid_t
			),
			"tone": lerpf(0.97, 0.91, mid_t),
		}
	# Waterline: wet mud with a little leftover silt so the rim stays soft.
	var wet_t := smoothstep(mud_inner, waterline, coverage)
	return {
		"primary": MapTypes.TERRAIN_MUD,
		"secondary": MapTypes.TERRAIN_COAST_SAND,
		"weight": (1.0 - wet_t) * 0.28,
		"tone": lerpf(0.91, 0.86, wet_t),
	}


static func is_natural_shore_cell(field: Dictionary, grid: MapTerrainGrid, cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= grid.size_cells.x or cell.y >= grid.size_cells.y:
		return false
	var terrain := grid.get_terrain(cell)
	if terrain not in MapViewMeshBuilderConfig.NATURAL_SHORE_TERRAINS:
		return false
	var coverage := MapViewMeshBuilderTerrainWater.combined_water_coverage_at(field, Vector2(cell) + Vector2(0.5, 0.5))
	return (
		coverage >= MapViewMeshBuilderConfig.SHORE_CATTAIL_MIN_COVERAGE
		and coverage < MapViewMeshBuilderConfig.SHORE_CATTAIL_MAX_COVERAGE
	)
## The recessed bank under a clipped water edge must use a dry palette layer.
## Pick the first adjacent dry terrain deterministically; enclosed water falls
## back to grass because its bed remains fully hidden by the water surface.
static func _ground_terrain_at(grid: MapTerrainGrid, cell: Vector2i) -> StringName:
	var terrain := grid.get_terrain(cell)
	if not MapViewMaterials.WATER_TERRAINS.has(terrain):
		return terrain
	for offset in [
		Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
	]:
		var neighbor: Vector2i = cell + offset
		if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= grid.size_cells.x or neighbor.y >= grid.size_cells.y:
			continue
		var candidate := grid.get_terrain(neighbor)
		if not MapViewMaterials.WATER_TERRAINS.has(candidate):
			return candidate
	return MapTypes.TERRAIN_GRASS


## Hollow stone stack: four walls plus a recessed ink flue so the mouth reads as
## a dark tube instead of a solid cube (same pattern as tower arrow slits).
