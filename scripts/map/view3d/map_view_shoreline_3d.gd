class_name MapViewShoreline3D
extends RefCounted

## Deterministic view-only rock scatter for open coastal water. Rocks sit on the
## blocked water side of coast-sand cells, so they break up harbor silhouettes
## without pretending to be gameplay collision.

const ROCK_KEEP_RATIO := 0.19
const ROCK_CLUSTER_CHANCE := 0.38
const ROCK_INSET := 0.42
const CARDINAL_NEIGHBORS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
]


static func build(
	definition: MapDefinition,
	grid: MapTerrainGrid,
	cell_bounds: Rect2i = Rect2i(Vector2i.ZERO, Vector2i.ZERO)
) -> Node3D:
	var root := Node3D.new()
	root.name = "ShorelineDetails"
	add_to(root, definition, grid, cell_bounds)
	return root


static func add_to(
	root: Node3D,
	definition: MapDefinition,
	grid: MapTerrainGrid,
	cell_bounds: Rect2i = Rect2i(Vector2i.ZERO, Vector2i.ZERO)
) -> void:
	var bounds := cell_bounds
	if bounds.size == Vector2i.ZERO:
		bounds = Rect2i(Vector2i.ZERO, grid.size_cells)
	bounds = bounds.intersection(Rect2i(Vector2i.ZERO, grid.size_cells))
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var cell := Vector2i(x, y)
			if grid.get_terrain(cell) != MapTypes.TERRAIN_COAST_SAND:
				continue
			var water_offset := _water_neighbor(grid, cell, definition.seed)
			if water_offset == Vector2i.ZERO:
				continue
			if MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 23003) > ROCK_KEEP_RATIO:
				continue
			_add_rock(transforms, colors, cell, water_offset, definition.seed, 0)
			if MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 23131) < ROCK_CLUSTER_CHANCE:
				_add_rock(transforms, colors, cell, water_offset, definition.seed, 1)
	if transforms.is_empty():
		return

	var mesh := SphereMesh.new()
	mesh.radius = 0.48
	mesh.height = 0.68
	mesh.radial_segments = 7
	mesh.rings = 4
	root.add_child(MapViewMeshBuilderPrimitives.multi_mesh(
		"CoastalRocks",
		mesh,
		transforms,
		colors,
		MapViewMaterials.natural_rock(),
		Vector3.ZERO
	))


static func _water_neighbor(grid: MapTerrainGrid, cell: Vector2i, seed: int) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for offset in CARDINAL_NEIGHBORS:
		if MapTypes.WATER_TERRAINS.has(grid.get_terrain(cell + offset)):
			candidates.append(offset)
	if candidates.is_empty():
		return Vector2i.ZERO
	var pick := floori(MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, seed + 22807) * candidates.size())
	return candidates[mini(pick, candidates.size() - 1)]


static func _add_rock(
	transforms: Array[Transform3D],
	colors: Array[Color],
	cell: Vector2i,
	water_offset: Vector2i,
	seed: int,
	cluster_index: int
) -> void:
	var salt := cluster_index * 977
	var along := Vector2(-water_offset.y, water_offset.x)
	var side_jitter := MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, seed + 23321 + salt) - 0.5
	var water_jitter := MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, seed + 23447 + salt) * 0.18
	var spot := (
		Vector2(cell) + Vector2(0.5, 0.5)
		+ Vector2(water_offset) * (ROCK_INSET + water_jitter)
		+ along * side_jitter * 0.72
	)
	var size := 0.48 + MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, seed + 23561 + salt) * 0.82
	if cluster_index > 0:
		size *= 0.58
	var stretch := Vector3(
		size * (0.82 + MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, seed + 23663 + salt) * 0.42),
		size * (0.72 + MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, seed + 23767 + salt) * 0.48),
		size * (0.78 + MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, seed + 23869 + salt) * 0.46)
	)
	var yaw := MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, seed + 23971 + salt) * TAU
	var basis := Basis(Vector3.UP, yaw).scaled(stretch)
	var water_y := -MapViewMeshBuilderConfig.WATER_RECESS + MapViewMeshBuilderConfig.WATER_SURFACE_LIFT
	# Sink the lower half so these read as wave-washed natural rocks, not pebbles
	# balanced on top of the water plane.
	var origin := Vector3(spot.x, water_y + 0.13 * stretch.y, spot.y)
	transforms.append(Transform3D(basis, origin))
	var tone := 0.72 + MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, seed + 24077 + salt) * 0.28
	colors.append(Color(tone * 0.90, tone * 0.94, tone))
