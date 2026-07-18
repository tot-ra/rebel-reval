class_name MapViewMeshBuilderTerrain
extends RefCounted

## Terrain height field and ground mesh generation.

## Deterministic per-map height field shared by the terrain mesh, scatter,
## trees, and actor sync so everything sits on the same rolling ground.
static var _height_fields: Dictionary = {}

static func ensure_height_field(definition: MapDefinition, grid: MapTerrainGrid) -> Dictionary:
	var key := String(definition.map_id)
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
	var field := {
		"seed": definition.seed,
		"size": grid.size_cells,
		"rects": rects,
		"water": water,
	}
	_height_fields[key] = field
	bake_vertices(field)
	return field


## Ground height (world units) of the visible terrain at a world XZ position.
## Zero when the map has no baked height field or outside the playable bounds.


static func ground_height(definition: MapDefinition, world_xz: Vector2) -> float:
	var field: Dictionary = _height_fields.get(String(definition.map_id), {})
	if field.is_empty():
		return 0.0
	return field_height(field, world_xz)




static func field_height(field: Dictionary, position: Vector2) -> float:
	var size: Vector2i = field["size"]
	if position.x < 0.0 or position.y < 0.0 or position.x > float(size.x) or position.y > float(size.y):
		return 0.0
	var cell := Vector2i(floori(position.x), floori(position.y))
	if field["water"].has(cell):
		return -MapViewMeshBuilderConfig.WATER_RECESS
	var noise_seed: int = field["seed"]
	var broad := value_noise(position / MapViewMeshBuilderConfig.HEIGHT_BROAD_PERIOD, noise_seed + 7717)
	var fine := value_noise(position / MapViewMeshBuilderConfig.HEIGHT_FINE_PERIOD, noise_seed + 8317)
	var height := broad * MapViewMeshBuilderConfig.HEIGHT_BROAD_AMPLITUDE + fine * MapViewMeshBuilderConfig.HEIGHT_FINE_AMPLITUDE
	return height * minf(pad_factor(field, position), water_factor(field, position))


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
	for rect: Rect2 in field["rects"]:
		var dx := maxf(maxf(rect.position.x - position.x, position.x - rect.end.x), 0.0)
		var dy := maxf(maxf(rect.position.y - position.y, position.y - rect.end.y), 0.0)
		var distance := Vector2(dx, dy).length()
		factor = minf(factor, smoothstep(MapViewMeshBuilderConfig.FLATTEN_START, MapViewMeshBuilderConfig.FLATTEN_END, distance))
	return factor




static func water_factor(field: Dictionary, position: Vector2) -> float:
	var cell := Vector2i(floori(position.x), floori(position.y))
	var water: Dictionary = field["water"]
	if water.is_empty():
		return 1.0
	var nearest := float(MapViewMeshBuilderConfig.WATER_FLATTEN_CELLS + 1)
	for oy in range(-MapViewMeshBuilderConfig.WATER_FLATTEN_CELLS, MapViewMeshBuilderConfig.WATER_FLATTEN_CELLS + 1):
		for ox in range(-MapViewMeshBuilderConfig.WATER_FLATTEN_CELLS, MapViewMeshBuilderConfig.WATER_FLATTEN_CELLS + 1):
			if water.has(cell + Vector2i(ox, oy)):
				nearest = minf(nearest, maxf(absf(float(ox)), absf(float(oy))))
	return smoothstep(0.6, float(MapViewMeshBuilderConfig.WATER_FLATTEN_CELLS), nearest)


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
			var jitter_scale := pad_factor(field, base)
			var jitter := Vector2(
				MapViewMeshBuilderPrimitives.hash01(vx, vy, noise_seed + 8887) - 0.5,
				MapViewMeshBuilderPrimitives.hash01(vx, vy, noise_seed + 9973) - 0.5
			) * MapViewMeshBuilderConfig.EDGE_JITTER * jitter_scale
			if vx == 0 or vy == 0 or vx == columns - 1 or vy == rows - 1:
				jitter = Vector2.ZERO
			var spot := base + jitter
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


## One MeshInstance3D per used terrain: every cell of that terrain becomes a
## textured ground quad over the shared jittered height vertices. Water-family
## cells sit slightly recessed under an animated surface so shorelines read in
## the dimetric view without touching walkability.


static func build_terrain(definition: MapDefinition, grid: MapTerrainGrid) -> Node3D:
	var root := Node3D.new()
	root.name = "Terrain"
	var field := ensure_height_field(definition, grid)
	for terrain_id in grid.used_terrain_ids():
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var water := MapViewMaterials.WATER_TERRAINS.has(terrain_id)
		for y in grid.size_cells.y:
			for x in grid.size_cells.x:
				if grid.get_terrain(Vector2i(x, y)) != terrain_id:
					continue
				var variant := grid.get_style_variant(Vector2i(x, y))
				var tone := 1.0 if water else cell_tone(x, y, definition.seed, variant)
				add_cell_quad(surface, field, grid, terrain_id, x, y, definition.seed, tone)
		var instance := MeshInstance3D.new()
		instance.name = "Terrain_%s" % String(terrain_id)
		if water:
			surface.generate_tangents()
		instance.mesh = surface.commit()
		if water:
			instance.material_override = MapViewMaterials.water_surface(terrain_id)
		else:
			instance.material_override = MapViewMaterials.terrain(terrain_id, definition.seed)
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




static func add_cell_quad(
	surface: SurfaceTool,
	field: Dictionary,
	grid: MapTerrainGrid,
	terrain_id: StringName,
	x: int,
	y: int,
	noise_seed: int,
	tone: float = 1.0
) -> void:
	var columns: int = field["vertex_columns"]
	var positions: PackedVector3Array = field["positions"]
	var normals: PackedVector3Array = field["normals"]
	var origin_x := x * MapViewMeshBuilderConfig.TERRAIN_SUBDIVISIONS
	var origin_y := y * MapViewMeshBuilderConfig.TERRAIN_SUBDIVISIONS
	for patch_y in MapViewMeshBuilderConfig.TERRAIN_SUBDIVISIONS:
		for patch_x in MapViewMeshBuilderConfig.TERRAIN_SUBDIVISIONS:
			if visual_patch_terrain(grid, x, y, patch_x, patch_y, noise_seed) != terrain_id:
				continue
			var vertex_x := origin_x + patch_x
			var vertex_y := origin_y + patch_y
			var indices := [
				vertex_y * columns + vertex_x,
				vertex_y * columns + vertex_x + 1,
				(vertex_y + 1) * columns + vertex_x + 1,
				(vertex_y + 1) * columns + vertex_x,
			]
			for index in [0, 1, 2, 0, 2, 3]:
				var vertex := positions[indices[index]]
				surface.set_normal(normals[indices[index]])
				surface.set_uv(Vector2(vertex.x, vertex.z) / MapViewMaterials.TERRAIN_TEXTURE_WORLD_SIZE)
				surface.set_color(Color(tone, tone, tone))
				surface.add_vertex(vertex)


## Smoothly displaces only the visual material lookup. Geometry, collision,
## navigation, height pads, and deterministic definition fingerprints remain
## tied to the authored logic cell.


static func visual_patch_terrain(
	grid: MapTerrainGrid,
	x: int,
	y: int,
	patch_x: int,
	patch_y: int,
	noise_seed: int
) -> StringName:
	var center := Vector2(
		float(x) + (float(patch_x) + 0.5) / float(MapViewMeshBuilderConfig.TERRAIN_SUBDIVISIONS),
		float(y) + (float(patch_y) + 0.5) / float(MapViewMeshBuilderConfig.TERRAIN_SUBDIVISIONS)
	)
	var warp := Vector2(
		value_noise(center / 2.4, noise_seed + 12101) - 0.5,
		value_noise(center / 2.4, noise_seed + 12703) - 0.5
	) * MapViewMeshBuilderConfig.VISUAL_EDGE_WARP * 2.0
	var sample := center + warp
	sample.x = clampf(sample.x, 0.0, float(grid.size_cells.x) - 0.001)
	sample.y = clampf(sample.y, 0.0, float(grid.size_cells.y) - 0.001)
	return grid.get_terrain(Vector2i(floori(sample.x), floori(sample.y)))


## Hollow stone stack: four walls plus a recessed ink flue so the mouth reads as
## a dark tube instead of a solid cube (same pattern as tower arrow slits).
