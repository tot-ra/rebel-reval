class_name MapViewMeshBuilderTerrain
extends RefCounted

## Terrain height field and ground mesh generation.

const _Assembly := preload("res://scripts/map/view3d/map_view_assembly.gd")
const _Staged := preload("res://scripts/map/view3d/map_view_mesh_builder_terrain_staged.gd")
## WB-07b: vertex rows per blended-ground bake band. Small enough that the pool
## spreads a district over the group threads, large enough to keep task overhead low.
const GROUND_BAND_ROWS := 16

## Deterministic per-map height field shared by the terrain mesh, scatter,
## trees, and actor sync so everything sits on the same rolling ground.
static var _height_fields: Dictionary = {}
static var _height_field_keys_by_definition: Dictionary = {}
static var _seabed_material: StandardMaterial3D


static func ensure_height_field(definition: MapDefinition, grid: MapTerrainGrid) -> Dictionary:
	var cached := cached_height_field(definition, grid)
	if not cached.is_empty():
		return cached
	return publish_height_field(definition, grid, compute_height_field(definition, grid))


## The published field, or empty when it has not been baked yet. Main thread.
static func cached_height_field(definition: MapDefinition, grid: MapTerrainGrid) -> Dictionary:
	return _height_fields.get(_height_field_key(definition, grid), {})


## WB-07b: stores a field baked by compute_height_field() in the shared caches.
## Main thread only; the first published field for a key wins, so a synchronous
## bake that raced a staged one never replaces the dictionary callers hold.
static func publish_height_field(
	definition: MapDefinition, grid: MapTerrainGrid, field: Dictionary
) -> Dictionary:
	var key := _height_field_key(definition, grid)
	if _height_fields.has(key):
		return _height_fields[key]
	_height_fields[key] = field
	_height_field_keys_by_definition[_definition_height_key(definition)] = key
	return field


## WB-07b: the whole height-field bake as a pure function of the definition and
## grid. It reads them and writes only the returned dictionary, so it may run on
## a WorkerThreadPool thread; publish_height_field() then shares it.
static func compute_height_field(definition: MapDefinition, grid: MapTerrainGrid) -> Dictionary:
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
			water_contours[terrain_id] = MapViewMeshBuilderTerrainWater.bake_water_contour(
				grid, terrain_id
			)
	var field := {
		"seed": definition.seed,
		"ground_elevation": definition.ground_elevation,
		# ADR 0023: the compiled relief is the authoritative base under the
		# procedural detail below. Empty for maps authoring no relief_* statement.
		"relief_heights": definition.relief_heights,
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
	# WHY: water Y used to be the world-zero recess. A moat on a terrace or a
	# quay above the sea would then ignore the compiled relief under it. Shore
	# bases are baked first so bake_vertices and the basin share one level.
	_bake_water_surface_bases(field)
	bake_vertices(field)
	_bake_basin_cells(field, grid)
	bake_bed_vertices(field)
	return field


static func _height_field_key(definition: MapDefinition, grid: MapTerrainGrid) -> String:
	return (
		"%s:%s:%s"
		% [
			_definition_height_key(definition),
			grid.size_cells,
			grid.fingerprint(),
		]
	)


static func _definition_height_key(definition: MapDefinition) -> String:
	return (
		"%s:%s:%s:%d"
		% [
			String(definition.map_id),
			String(definition.fingerprint),
			definition.size_cells,
			definition.seed,
		]
	)


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
			clampi(ceili(affected.end.x), 0, size.x), clampi(ceili(affected.end.y), 0, size.y)
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
	var field_key := String(
		_height_field_keys_by_definition.get(_definition_height_key(definition), "")
	)
	var field: Dictionary = _height_fields.get(field_key, {})
	if field.is_empty():
		return 0.0
	return field_height(field, world_xz)


static func field_height(field: Dictionary, position: Vector2) -> float:
	if field.get("flat_floor", false):
		return 0.0
	var size: Vector2i = field["size"]
	if (
		position.x < 0.0
		or position.y < 0.0
		or position.x > float(size.x)
		or position.y > float(size.y)
	):
		return 0.0
	var cell := Vector2i(floori(position.x), floori(position.y))
	if field["water"].has(cell):
		return water_gameplay_bed_y(field, position)
	var noise_seed: int = field["seed"]
	var macro := (
		(
			value_noise(position / MapViewMeshBuilderConfig.HEIGHT_MACRO_PERIOD, noise_seed + 6949)
			* 2.0
		)
		- 1.0
	)
	var broad := (
		(
			value_noise(position / MapViewMeshBuilderConfig.HEIGHT_BROAD_PERIOD, noise_seed + 7717)
			* 2.0
		)
		- 1.0
	)
	var fine := (
		value_noise(position / MapViewMeshBuilderConfig.HEIGHT_FINE_PERIOD, noise_seed + 8317) * 2.0
		- 1.0
	)
	var relief := (
		macro * MapViewMeshBuilderConfig.HEIGHT_MACRO_AMPLITUDE
		+ broad * MapViewMeshBuilderConfig.HEIGHT_BROAD_AMPLITUDE
		+ fine * MapViewMeshBuilderConfig.HEIGHT_FINE_AMPLITUDE
	)
	# Same function as MapDefinition.height_at_cell_space: tapered datum plus the
	# compiled relief, so view and gameplay read one ground height.
	var base_elevation := (
		float(field.get("ground_elevation", 0.0)) * elevation_factor(field, position)
		+ MapDefinition.sample_relief(
			field.get("relief_heights", PackedFloat32Array()), size, position
		)
	)
	return (
		base_elevation + relief * minf(pad_factor(field, position), water_factor(field, position))
	)


## Elevated outdoor maps share a zero-height datum at their authored bounds so
## reciprocal transition edges still meet. The interior rises smoothly into a
## broad plateau instead of lifting collision or changing 2D map coordinates.
static func elevation_factor(field: Dictionary, position: Vector2) -> float:
	if field.get("flat_floor", false):
		return 0.0
	var size: Vector2i = field["size"]
	var border := minf(
		minf(position.x, float(size.x) - position.x), minf(position.y, float(size.y) - position.y)
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
		minf(position.x, float(size.x) - position.x), minf(position.y, float(size.y) - position.y)
	)
	var factor := clampf(border / MapViewMeshBuilderConfig.BORDER_FLATTEN_CELLS, 0.0, 1.0)
	var rects_by_cell: Dictionary = field.get("rects_by_cell", {})
	var position_cell := Vector2i(floori(position.x), floori(position.y))
	var nearby_rects: Array = rects_by_cell.get(position_cell, [])
	for rect: Rect2 in nearby_rects:
		var dx := maxf(maxf(rect.position.x - position.x, position.x - rect.end.x), 0.0)
		var dy := maxf(maxf(rect.position.y - position.y, position.y - rect.end.y), 0.0)
		var distance := Vector2(dx, dy).length()
		factor = minf(
			factor,
			smoothstep(
				MapViewMeshBuilderConfig.FLATTEN_START,
				MapViewMeshBuilderConfig.FLATTEN_END,
				distance
			)
		)
	return factor


static func water_factor(field: Dictionary, position: Vector2) -> float:
	var size: Vector2i = field["size"]
	var factors: PackedFloat32Array = field["water_factors"]
	# Invalid map definitions produce an empty terrain grid. Keep water flattening
	# neutral so the mesh builder can skip that grid without indexing cell -1.
	if size.x <= 0 or size.y <= 0 or factors.size() != size.x * size.y:
		return 1.0
	var cell := Vector2i(
		clampi(floori(position.x), 0, size.x - 1), clampi(floori(position.y), 0, size.y - 1)
	)
	return factors[cell.y * size.x + cell.x]


## Gameplay bed under water: shore-relative recess when the map authors relief,
## otherwise the historic world-zero recess so maps without relief_* stay identical.
static func water_gameplay_bed_y(field: Dictionary, position: Vector2) -> float:
	return water_surface_base_at(field, position) - MapViewMeshBuilderConfig.WATER_RECESS


## Compiled still-water level for the water body under `position` (datum + relief
## at the lowest dry neighbour), or 0 when the map has no authored relief_*.
static func water_surface_base_at(field: Dictionary, position: Vector2) -> float:
	if not field.has("water_surface_bases"):
		return 0.0
	var bases: PackedFloat32Array = field["water_surface_bases"]
	var water: Dictionary = field["water"]
	var size: Vector2i = field["size"]
	if bases.size() != size.x * size.y:
		return 0.0
	var cell := Vector2i(floori(position.x), floori(position.y))
	if (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < size.x
		and cell.y < size.y
		and water.has(cell)
	):
		return bases[cell.y * size.x + cell.x]
	var found := INF
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var next := cell + Vector2i(ox, oy)
			if next.x < 0 or next.y < 0 or next.x >= size.x or next.y >= size.y:
				continue
			if water.has(next):
				found = minf(found, bases[next.y * size.x + next.x])
	return 0.0 if is_inf(found) else found


## Per connected water body: recess from the lowest dry neighbour. Sea cells
## whose own compiled relief is at or below the datum stay at 0 so a raised quay
## does not lift the harbour. Maps with empty relief_heights skip this bake.
static func _bake_water_surface_bases(field: Dictionary) -> void:
	var water: Dictionary = field["water"]
	var heights: PackedFloat32Array = field.get("relief_heights", PackedFloat32Array())
	if water.is_empty() or heights.is_empty():
		return
	var size: Vector2i = field["size"]
	if heights.size() != size.x * size.y:
		return
	var bases := PackedFloat32Array()
	bases.resize(size.x * size.y)
	var visited := PackedByteArray()
	visited.resize(size.x * size.y)
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	for y in size.y:
		for x in size.x:
			var start := Vector2i(x, y)
			var start_index := y * size.x + x
			if not water.has(start) or visited[start_index] != 0:
				continue
			var stack: Array[Vector2i] = [start]
			var component: Array[Vector2i] = []
			var shore := INF
			var water_min := INF
			visited[start_index] = 1
			while not stack.is_empty():
				var cell: Vector2i = stack.pop_back()
				component.append(cell)
				water_min = minf(water_min, _compiled_ground_at_cell(field, cell))
				for dir: Vector2i in dirs:
					var next := cell + dir
					if next.x < 0 or next.y < 0 or next.x >= size.x or next.y >= size.y:
						continue
					if water.has(next):
						var next_index := next.y * size.x + next.x
						if visited[next_index] == 0:
							visited[next_index] = 1
							stack.append(next)
					else:
						shore = minf(shore, _compiled_ground_at_cell(field, next))
			if is_inf(shore):
				shore = 0.0
			var surface_base := shore
			if water_min <= 0.0:
				surface_base = minf(shore, 0.0)
			for member: Vector2i in component:
				bases[member.y * size.x + member.x] = surface_base
	field["water_surface_bases"] = bases


static func _compiled_ground_at_cell(field: Dictionary, cell: Vector2i) -> float:
	var position := Vector2(cell) + Vector2(0.5, 0.5)
	return (
		float(field.get("ground_elevation", 0.0)) * elevation_factor(field, position)
		+ MapDefinition.sample_relief(
			field.get("relief_heights", PackedFloat32Array()), field["size"], position
		)
	)


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
				jitter = (
					Vector2(
						MapViewMeshBuilderPrimitives.hash01(vx, vy, noise_seed + 8887) - 0.5,
						MapViewMeshBuilderPrimitives.hash01(vx, vy, noise_seed + 9973) - 0.5
					)
					* MapViewMeshBuilderConfig.EDGE_JITTER
					* jitter_scale
				)
				if vx == 0 or vy == 0 or vx == columns - 1 or vy == rows - 1:
					jitter = Vector2.ZERO
				spot = base + jitter
			var height := (
				water_gameplay_bed_y(field, spot)
				if subvertex_touches_water(field, vx, vy)
				else field_height(field, spot)
			)
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


## Rendered seabed height (world units) at a world XZ position: the gameplay bed
## minus the WS-13b sea basin. Equals `ground_height` away from open sea cells.
## View only (underwater cameras, captures, later swimming); gameplay keeps
## `ground_height`.
static func view_bed_height(definition: MapDefinition, world_xz: Vector2) -> float:
	var field_key := String(
		_height_field_keys_by_definition.get(_definition_height_key(definition), "")
	)
	var field: Dictionary = _height_fields.get(field_key, {})
	if field.is_empty():
		return 0.0
	var height := field_height(field, world_xz)
	var cell := Vector2i(floori(world_xz.x), floori(world_xz.y))
	if field["water"].has(cell):
		height -= basin_extra_depth(field, world_xz)
	return height


## WS-13b per-cell basin inputs: the target depth of each sea cell and the chamfer
## distance (cells, centre to centre) to the nearest natural, hard and (WS-13d)
## timber-pier dry cell.
## Cells outside the map count as water, so a basin stays deep up to the border and
## meets the surroundings seabed apron instead of shelving up at every map edge.
static func _bake_basin_cells(field: Dictionary, grid: MapTerrainGrid) -> void:
	if field.get("flat_floor", false):
		return
	var size: Vector2i = grid.size_cells
	var count := size.x * size.y
	if count <= 0:
		return
	var targets := PackedFloat32Array()
	var natural := PackedFloat32Array()
	var hard := PackedFloat32Array()
	var pier := PackedFloat32Array()
	targets.resize(count)
	natural.resize(count)
	hard.resize(count)
	pier.resize(count)
	var far := float(size.x + size.y)
	var has_basin := false
	var has_pier := false
	for y in size.y:
		for x in size.x:
			var index := y * size.x + x
			var terrain := grid.get_terrain(Vector2i(x, y))
			natural[index] = far
			hard[index] = far
			pier[index] = far
			if MapViewMaterials.WATER_TERRAINS.has(terrain):
				targets[index] = float(MapViewMeshBuilderConfig.SEA_BASIN_DEPTH.get(terrain, 0.0))
				has_basin = has_basin or targets[index] > 0.0
			elif terrain in MapViewMeshBuilderConfig.NATURAL_SHORE_TERRAINS:
				natural[index] = 0.0
			elif terrain in MapViewMeshBuilderConfig.SEA_BASIN_PIER_TERRAINS:
				pier[index] = 0.0
				has_pier = true
			else:
				hard[index] = 0.0
	if not has_basin:
		return
	_chamfer_distance(natural, size)
	_chamfer_distance(hard, size)
	field["basin_targets"] = targets
	field["basin_natural"] = natural
	field["basin_hard"] = hard
	if has_pier:
		_chamfer_distance(pier, size)
		field["basin_pier"] = pier


## Two-pass 3x3 chamfer transform (1 and sqrt 2): Euclidean enough for a bank
## profile and linear in the cell count, so startup stays cheap on 160-cell maps.
static func _chamfer_distance(distances: PackedFloat32Array, size: Vector2i) -> void:
	var diagonal := sqrt(2.0)
	for y in size.y:
		for x in size.x:
			var index := y * size.x + x
			var best := distances[index]
			if x > 0:
				best = minf(best, distances[index - 1] + 1.0)
			if y > 0:
				best = minf(best, distances[index - size.x] + 1.0)
				if x > 0:
					best = minf(best, distances[index - size.x - 1] + diagonal)
				if x < size.x - 1:
					best = minf(best, distances[index - size.x + 1] + diagonal)
			distances[index] = best
	for y in range(size.y - 1, -1, -1):
		for x in range(size.x - 1, -1, -1):
			var index := y * size.x + x
			var best := distances[index]
			if x < size.x - 1:
				best = minf(best, distances[index + 1] + 1.0)
			if y < size.y - 1:
				best = minf(best, distances[index + size.x] + 1.0)
				if x < size.x - 1:
					best = minf(best, distances[index + size.x + 1] + diagonal)
				if x > 0:
					best = minf(best, distances[index + size.x - 1] + diagonal)
			distances[index] = best


## Extra view depth below the gameplay bed at a world XZ position: the cell target,
## limited by the bank profile. Distances are bilinear between cell centres, so a
## straight shore gives the exact edge distance and the bed stays smooth.
static func basin_extra_depth(field: Dictionary, position: Vector2) -> float:
	if not field.has("basin_targets"):
		return 0.0
	var size: Vector2i = field["size"]
	var target := _cell_bilinear(field["basin_targets"], size, position)
	var natural := maxf(_cell_bilinear(field["basin_natural"], size, position) - 0.5, 0.0)
	var hard := maxf(_cell_bilinear(field["basin_hard"], size, position) - 0.5, 0.0)
	var bank := minf(
		natural * MapViewMeshBuilderConfig.SEA_BASIN_NATURAL_SLOPE,
		hard * MapViewMeshBuilderConfig.SEA_BASIN_HARD_SLOPE
	)
	if field.has("basin_pier"):
		# Timber decks are not in `basin_hard`; their crib face drops almost straight,
		# while a nearer beach or stone quay still limits the bank as before.
		var pier := maxf(_cell_bilinear(field["basin_pier"], size, position) - 0.5, 0.0)
		bank = minf(bank, pier * MapViewMeshBuilderConfig.SEA_BASIN_PIER_SLOPE)
	return maxf(minf(target, bank), 0.0)


static func _cell_bilinear(values: PackedFloat32Array, size: Vector2i, position: Vector2) -> float:
	var q := position - Vector2(0.5, 0.5)
	var x0 := clampi(floori(q.x), 0, size.x - 1)
	var y0 := clampi(floori(q.y), 0, size.y - 1)
	var x1 := mini(x0 + 1, size.x - 1)
	var y1 := mini(y0 + 1, size.y - 1)
	var fx := clampf(q.x - float(x0), 0.0, 1.0)
	var fy := clampf(q.y - float(y0), 0.0, 1.0)
	var top := lerpf(values[y0 * size.x + x0], values[y0 * size.x + x1], fx)
	var bottom := lerpf(values[y1 * size.x + x0], values[y1 * size.x + x1], fx)
	return lerpf(top, bottom, fy)


## WS-13b rendered bed: a copy of the shared vertices where every subvertex inside
## open sea drops by `basin_extra_depth`. `positions` stays the gameplay bed because
## the water surface, the swash sheet and scatter read it. Vertices on the waterline
## (touching any dry cell) and their normals are unchanged, so every triangle that
## can rise above the surface keeps its exact shape and shading.
static func bake_bed_vertices(field: Dictionary) -> void:
	var positions: PackedVector3Array = field["positions"]
	var offsets := PackedFloat32Array()
	offsets.resize(positions.size())
	if not field.has("basin_targets"):
		field["bed_offsets"] = offsets
		field["bed_positions"] = positions
		field["bed_normals"] = field["normals"]
		return
	var columns: int = field["vertex_columns"]
	var rows := positions.size() / columns
	var size: Vector2i = field["size"]
	var targets: PackedFloat32Array = field["basin_targets"]
	var subdivisions := MapViewMeshBuilderConfig.TERRAIN_SUBDIVISIONS
	var bed := positions.duplicate()
	var visited := PackedByteArray()
	visited.resize(positions.size())
	var deepened := PackedInt32Array()
	# Only sea cells can deepen, and only subvertices on a cell edge can touch a dry
	# neighbour, which keeps this pass a small share of the height-field bake.
	for cell_y in size.y:
		for cell_x in size.x:
			if targets[cell_y * size.x + cell_x] <= 0.0:
				continue
			for sub_y in subdivisions + 1:
				for sub_x in subdivisions + 1:
					var vx := cell_x * subdivisions + sub_x
					var vy := cell_y * subdivisions + sub_y
					var index := vy * columns + vx
					if visited[index] != 0:
						continue
					visited[index] = 1
					var on_cell_edge := (
						sub_x == 0 or sub_y == 0 or sub_x == subdivisions or sub_y == subdivisions
					)
					if on_cell_edge and subvertex_touches_dry(field, vx, vy):
						continue
					var vertex := bed[index]
					var extra := basin_extra_depth(field, Vector2(vertex.x, vertex.z))
					if extra <= 0.0:
						continue
					vertex.y -= extra
					bed[index] = vertex
					offsets[index] = extra
					deepened.append(index)
	var bed_normals: PackedVector3Array = (field["normals"] as PackedVector3Array).duplicate()
	for index in deepened:
		var vx := index % columns
		var vy := index / columns
		var left := bed[vy * columns + maxi(vx - 1, 0)].y
		var right := bed[vy * columns + mini(vx + 1, columns - 1)].y
		var up := bed[maxi(vy - 1, 0) * columns + vx].y
		var down := bed[mini(vy + 1, rows - 1) * columns + vx].y
		bed_normals[index] = Vector3(left - right, 2.0, up - down).normalized()
	field["bed_positions"] = bed
	field["bed_normals"] = bed_normals
	field["bed_offsets"] = offsets


## True when any in-map cell around a subvertex is dry. Out-of-map samples do not
## count, so border vertices of a sea cell can still deepen.
static func subvertex_touches_dry(field: Dictionary, vx: int, vy: int) -> bool:
	var water: Dictionary = field["water"]
	var size: Vector2i = field["size"]
	var base := Vector2(vx, vy) / float(MapViewMeshBuilderConfig.TERRAIN_SUBDIVISIONS)
	for nudge: Vector2 in [
		Vector2(-0.001, -0.001),
		Vector2(0.001, -0.001),
		Vector2(-0.001, 0.001),
		Vector2(0.001, 0.001)
	]:
		var sample: Vector2 = base + nudge
		if sample.x < 0.0 or sample.y < 0.0 or sample.x >= size.x or sample.y >= size.y:
			continue
		if not water.has(Vector2i(floori(sample.x), floori(sample.y))):
			return true
	return false


## Sample each side of a subvertex so shoreline vertices are shared by the
## recessed water and its bank while interior water vertices stay level.


static func subvertex_touches_water(field: Dictionary, vx: int, vy: int) -> bool:
	var water: Dictionary = field["water"]
	var size: Vector2i = field["size"]
	var base := Vector2(vx, vy) / float(MapViewMeshBuilderConfig.TERRAIN_SUBDIVISIONS)
	for nudge: Vector2 in [
		Vector2(-0.001, -0.001),
		Vector2(0.001, -0.001),
		Vector2(-0.001, 0.001),
		Vector2(0.001, 0.001)
	]:
		var sample: Vector2 = base + nudge
		if sample.x < 0.0 or sample.y < 0.0 or sample.x >= size.x or sample.y >= size.y:
			continue
		var cell := Vector2i(floori(sample.x), floori(sample.y))
		if water.has(cell):
			return true
	return false


## One unified dry-ground mesh with per-vertex terrain splatting plus separate
## water-family meshes recessed under animated surfaces. WB-07b: built by the
## same units staged assembly runs (MapViewMeshBuilderTerrainStaged), drained here
## in one call, so both paths produce the same tree.


static func build_terrain(definition: MapDefinition, grid: MapTerrainGrid) -> Node3D:
	var root := Node3D.new()
	root.name = "Terrain"
	_Assembly.drain(_Staged.terrain_units(definition, grid, root))
	return root


## WS-13b: flat strips extruded outward from every map-border segment whose bed
## vertices are deepened. The inner edge reuses the border bed vertices, so the
## apron meets the basin without a crack; land borders get nothing, which keeps
## the floor away from the near-plane clip of the whole-map overview camera.
static func build_seabed_apron_mesh(field: Dictionary) -> ArrayMesh:
	var arrays := seabed_apron_arrays(field)
	if arrays.is_empty():
		return null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## WB-07b: apron surface arrays, empty when no border bed vertex is deepened.
## Pure; staged assembly bakes them on a worker.
static func seabed_apron_arrays(field: Dictionary) -> Array:
	if not field.has("basin_targets"):
		return []
	var positions: PackedVector3Array = field["bed_positions"]
	var offsets: PackedFloat32Array = field["bed_offsets"]
	var columns: int = field["vertex_columns"]
	var rows := positions.size() / columns
	var reach := MapViewMeshBuilderConfig.SEA_BASIN_APRON_REACH
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var added := 0
	# Each side: vertex index along the edge -> buffer index, and the outward step.
	var sides: Array = [
		[columns, func(i: int) -> int: return i, Vector3(0.0, 0.0, -reach)],
		[columns, func(i: int) -> int: return (rows - 1) * columns + i, Vector3(0.0, 0.0, reach)],
		[rows, func(i: int) -> int: return i * columns, Vector3(-reach, 0.0, 0.0)],
		[rows, func(i: int) -> int: return i * columns + columns - 1, Vector3(reach, 0.0, 0.0)],
	]
	for side: Array in sides:
		var count: int = side[0]
		var index_of: Callable = side[1]
		var outward: Vector3 = side[2]
		for i in count - 1:
			var a: int = index_of.call(i)
			var b: int = index_of.call(i + 1)
			if offsets[a] <= 0.0 or offsets[b] <= 0.0:
				continue
			var inner_a := positions[a]
			var inner_b := positions[b]
			var outer_a := inner_a + outward
			var outer_b := inner_b + outward
			# Winding differs per side; the material draws both faces.
			for vertex: Vector3 in [inner_a, inner_b, outer_b, inner_a, outer_b, outer_a]:
				surface.set_normal(Vector3.UP)
				surface.add_vertex(vertex)
			added += 1
	if added == 0:
		return []
	return surface.commit_to_arrays()


static func seabed_apron_material() -> StandardMaterial3D:
	return _seabed_apron_material()


static func _seabed_apron_material() -> StandardMaterial3D:
	if _seabed_material == null:
		_seabed_material = StandardMaterial3D.new()
		_seabed_material.albedo_color = OutdoorTerrainPalette.color(
			MapViewMeshBuilderConfig.SEA_BASIN_BED_TERRAIN
		)
		_seabed_material.roughness = 1.0
		_seabed_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _seabed_material


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
##
## CUSTOM0 carries a per-corner layer pair and blend weight so the blended-ground
## shader can resolve finished albedo at each vertex before raster interpolation.
## Flat per-triangle layer indices caused paving-fringe wedges along stroke borders.
static func _build_blended_ground_mesh(
	field: Dictionary, grid: MapTerrainGrid, noise_seed: int
) -> ArrayMesh:
	if grid.size_cells.x <= 0 or grid.size_cells.y <= 0:
		return null
	var rows := ground_vertex_rows(grid)
	var bands: Array = []
	for band in ground_band_count(rows):
		bands.append(ground_band(field, grid, noise_seed, band))
	return ground_mesh_from_arrays(ground_arrays(field, bands))


## WB-07b: vertex rows of the blended ground (one more than subvertex rows).
static func ground_vertex_rows(grid: MapTerrainGrid) -> int:
	return grid.size_cells.y * MapViewMeshBuilderConfig.TERRAIN_SUBDIVISIONS + 1


static func ground_band_count(rows: int) -> int:
	return ceili(float(rows) / float(GROUND_BAND_ROWS))


## WB-07b: per-vertex splat data and triangle indices for one band of vertex rows.
## Every vertex is independent of the others, so bands can bake on worker
## threads in any order; ground_arrays() joins them in band order, which gives
## exactly the arrays of a single pass.
static func ground_band(
	field: Dictionary, grid: MapTerrainGrid, noise_seed: int, band: int
) -> Dictionary:
	var columns: int = field["vertex_columns"]
	# WS-13b: the rendered ground is the deepened sea bed; see bake_bed_vertices.
	var positions: PackedVector3Array = field["bed_positions"]
	var bed_offsets: PackedFloat32Array = field["bed_offsets"]
	var rows := ground_vertex_rows(grid)
	var row_start := band * GROUND_BAND_ROWS
	var row_end := mini(row_start + GROUND_BAND_ROWS, rows)
	var vertex_count := (row_end - row_start) * columns
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var custom := PackedFloat32Array()
	colors.resize(vertex_count)
	uvs.resize(vertex_count)
	custom.resize(vertex_count * 4)
	for vertex_y in range(row_start, row_end):
		for vertex_x in columns:
			var vertex_index := vertex_y * columns + vertex_x
			var local_index := vertex_index - row_start * columns
			var vertex := positions[vertex_index]
			var spot := Vector2(vertex.x, vertex.z)
			var source_cell := Vector2i(
				clampi(floori(spot.x), 0, grid.size_cells.x - 1),
				clampi(floori(spot.y), 0, grid.size_cells.y - 1)
			)
			var blend := terrain_blend_at(
				field, grid, spot, noise_seed, source_cell.x, source_cell.y
			)
			if bed_offsets[vertex_index] > 0.0:
				blend = _seabed_blend(spot, noise_seed, blend)
			var primary_tint := OutdoorTerrainPalette.color(blend["primary"])
			var secondary_tint := OutdoorTerrainPalette.color(blend["secondary"])
			colors[local_index] = primary_tint.lerp(secondary_tint, float(blend["weight"]))
			uvs[local_index] = spot / MapViewMaterials.TERRAIN_TEXTURE_WORLD_SIZE
			var custom_index := local_index * 4
			custom[custom_index] = float(blend["primary_index"])
			custom[custom_index + 1] = float(blend["secondary_index"])
			custom[custom_index + 2] = float(blend["weight"])
			custom[custom_index + 3] = float(blend["tone"])
	# Patch rows start at every vertex row of the band except the last row overall.
	var patch_end := mini(row_end, rows - 1)
	var indices := PackedInt32Array()
	indices.resize(maxi(patch_end - row_start, 0) * (columns - 1) * 6)
	var write_index := 0
	for patch_y in range(row_start, patch_end):
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
	return {"colors": colors, "uvs": uvs, "custom": custom, "indices": indices}


## Joins ground_band() results in band order into ArrayMesh surface arrays.
## Pure; runs on a worker in staged assembly.
static func ground_arrays(field: Dictionary, bands: Array) -> Array:
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var custom := PackedFloat32Array()
	var indices := PackedInt32Array()
	for band: Dictionary in bands:
		colors.append_array(band["colors"])
		uvs.append_array(band["uvs"])
		custom.append_array(band["custom"])
		indices.append_array(band["indices"])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = field["bed_positions"]
	arrays[Mesh.ARRAY_NORMAL] = field["bed_normals"]
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_CUSTOM0] = custom
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays


## CUSTOM0 carries a per-corner layer pair and blend weight (see below). Main thread.
static func ground_mesh_from_arrays(arrays: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var custom_format := (
		RenderingServer.ARRAY_CUSTOM_RGBA_FLOAT << RenderingServer.ARRAY_FORMAT_CUSTOM0_SHIFT
	)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, custom_format)
	return mesh


## WS-13b: open-sea bed below the waterline is sand with broad silt patches. The
## old fallback (the first dry neighbour, else grass) was hidden under a 9 mm
## column, but reads as a drowned meadow from an underwater camera.
static func _seabed_blend(sample: Vector2, noise_seed: int, base: Dictionary) -> Dictionary:
	var primary := MapViewMeshBuilderConfig.SEA_BASIN_BED_TERRAIN
	var secondary := MapViewMeshBuilderConfig.SEA_BASIN_SILT_TERRAIN
	var silt := smoothstep(0.42, 0.72, value_noise(sample / 5.5, noise_seed + 18233))
	return {
		"primary": primary,
		"secondary": secondary,
		"weight": silt * 0.8,
		"tone": float(base["tone"]),
		"primary_index": MapViewMaterials.terrain_blend_index(primary),
		"secondary_index": MapViewMaterials.terrain_blend_index(secondary),
	}


static func terrain_blend_at(
	field: Dictionary,
	grid: MapTerrainGrid,
	sample: Vector2,
	noise_seed: int,
	cell_x: int,
	cell_y: int
) -> Dictionary:
	var warped := sample
	var warp := (
		Vector2(
			value_noise(sample / 2.4, noise_seed + 12101) - 0.5,
			value_noise(sample / 2.4, noise_seed + 12703) - 0.5
		)
		* MapViewMeshBuilderConfig.VISUAL_EDGE_WARP
	)
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
		if (
			neighbor_cell.x < 0
			or neighbor_cell.y < 0
			or neighbor_cell.x >= grid.size_cells.x
			or neighbor_cell.y >= grid.size_cells.y
		):
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
	field: Dictionary, grid: MapTerrainGrid, sample: Vector2, noise_seed: int
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
		(value_noise(sample * 0.72, noise_seed + 16661) - 0.5)
		* MapViewMeshBuilderConfig.SHORE_COVERAGE_WARP
	)
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
			"weight":
			lerpf(
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
	var coverage := MapViewMeshBuilderTerrainWater.combined_water_coverage_at(
		field, Vector2(cell) + Vector2(0.5, 0.5)
	)
	return (
		coverage >= MapViewMeshBuilderConfig.SHORE_CATTAIL_MIN_COVERAGE
		and coverage < MapViewMeshBuilderConfig.SHORE_CATTAIL_MAX_COVERAGE
	)


## Cattails and authored reed beds belong on enclosed freshwater margins (ponds,
## moats, rivers), not on open Baltic beach strips that use coast sand and
## deep/shallow sea water.
static func is_inland_water_shore_cell(
	field: Dictionary, grid: MapTerrainGrid, cell: Vector2i
) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= grid.size_cells.x or cell.y >= grid.size_cells.y:
		return false
	var terrain := grid.get_terrain(cell)
	if terrain == MapTypes.TERRAIN_COAST_SAND:
		return false
	if terrain not in MapViewMeshBuilderConfig.NATURAL_SHORE_TERRAINS:
		return false
	var sample := Vector2(cell) + Vector2(0.5, 0.5)
	var inland_coverage := MapViewMeshBuilderTerrainWater.water_coverage_at(
		field, sample, MapTypes.TERRAIN_WATER
	)
	return (
		inland_coverage >= MapViewMeshBuilderConfig.SHORE_CATTAIL_MIN_COVERAGE
		and inland_coverage < MapViewMeshBuilderConfig.SHORE_CATTAIL_MAX_COVERAGE
	)


## The recessed bank under a clipped water edge must use a dry palette layer.
## Pick the first adjacent dry terrain deterministically; enclosed water falls
## back to grass because its bed remains fully hidden by the water surface.
static func _ground_terrain_at(grid: MapTerrainGrid, cell: Vector2i) -> StringName:
	var terrain := grid.get_terrain(cell)
	if not MapViewMaterials.WATER_TERRAINS.has(terrain):
		return terrain
	for offset in [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN,
		Vector2i(-1, -1),
		Vector2i(1, -1),
		Vector2i(-1, 1),
		Vector2i(1, 1),
	]:
		var neighbor: Vector2i = cell + offset
		if (
			neighbor.x < 0
			or neighbor.y < 0
			or neighbor.x >= grid.size_cells.x
			or neighbor.y >= grid.size_cells.y
		):
			continue
		var candidate := grid.get_terrain(neighbor)
		if not MapViewMaterials.WATER_TERRAINS.has(candidate):
			return candidate
	return MapTypes.TERRAIN_GRASS

## Hollow stone stack: four walls plus a recessed ink flue so the mouth reads as
## a dark tube instead of a solid cube (same pattern as tower arrow slits).
