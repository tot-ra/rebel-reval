class_name MapViewTerrainDetails
extends RefCounted

## View-only micro geometry for worked paving and living ground cover. All detail
## is batched by chunk and camera mode; gameplay collision remains the continuous
## terrain mesh owned by MapViewMeshBuilderTerrain.

const DETAIL_TOP_DOWN := &"top_down"
const DETAIL_FIRST_PERSON := &"first_person"

const COBBLE_LENGTH := 0.19
const COBBLE_WIDTH := 0.13
const COBBLE_HEIGHT := 0.072
const COBBLE_EDGE_INSET := 0.01
const COBBLE_MORTAR_JITTER := 0.004
const COBBLE_RADIUS := 0.028
const COBBLE_BEVEL_SEGMENTS := 2
const DETAIL_LIFT := 0.002
const GROUND_COVER_LIFT := 0.006

const GRASS_DETAIL_TERRAINS: Array[StringName] = [
	MapTypes.TERRAIN_GRASS,
	MapTypes.TERRAIN_MEADOW,
	MapTypes.TERRAIN_FOREST_FLOOR,
	MapTypes.TERRAIN_BOG,
]
const PAVING_TERRAINS: Array[StringName] = [
	MapTypes.TERRAIN_COBBLESTONE,
	MapTypes.TERRAIN_CASTLE_PAVING,
]

static var _mesh_cache: Dictionary = {}


static func build_chunk(
	definition: MapDefinition,
	grid: MapTerrainGrid,
	cell_bounds: Rect2i,
	first_person: bool = false
) -> Node3D:
	var root := Node3D.new()
	root.name = "TerrainDetails"
	var level := DETAIL_FIRST_PERSON if first_person else DETAIL_TOP_DOWN
	var cobble_grid := (
		MapViewMeshBuilderConfig.FIRST_PERSON_COBBLE_GRID
		if first_person
		else MapViewMeshBuilderConfig.TOP_DOWN_COBBLE_GRID
	)
	var detail := _build_detail_level(definition, grid, cell_bounds, level, cobble_grid)
	detail.name = "FirstPerson" if first_person else "TopDown"
	root.add_child(detail)
	return root


static func is_first_person(root: Node) -> bool:
	return root != null and root.get_node_or_null("FirstPerson") != null


static func cobble_mesh() -> ArrayMesh:
	const CACHE_KEY := &"rounded_rectangular_cobble"
	if _mesh_cache.has(CACHE_KEY):
		return _mesh_cache[CACHE_KEY]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Two rings plus a raised top fan preserve the rounded 3D silhouette at 36
	# triangles instead of 60 per stone. That saving pays for the tighter courses.
	var rings: Array[Dictionary] = [
		{"y": -COBBLE_HEIGHT * 0.5, "inset": COBBLE_RADIUS * 0.42},
		{"y": COBBLE_HEIGHT * 0.38, "inset": COBBLE_RADIUS * 0.12},
	]
	var ring_points: Array[PackedVector3Array] = []
	for ring in rings:
		ring_points.append(_rounded_rectangle_ring(float(ring["y"]), float(ring["inset"])))
	for ring_index in range(ring_points.size() - 1):
		var lower := ring_points[ring_index]
		var upper := ring_points[ring_index + 1]
		for index in lower.size():
			var next := (index + 1) % lower.size()
			_add_quad(surface, lower[index], lower[next], upper[next], upper[index])
	var top := ring_points[ring_points.size() - 1]
	var top_center := Vector3(0.0, COBBLE_HEIGHT * 0.52, 0.0)
	for index in top.size():
		var next := (index + 1) % top.size()
		_add_triangle(surface, top[index], top[next], top_center)
	surface.generate_normals()
	var mesh := surface.commit()
	_mesh_cache[CACHE_KEY] = mesh
	return mesh


static func _rounded_rectangle_ring(y: float, inset: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	var half_length := COBBLE_LENGTH * 0.5 - inset
	var half_width := COBBLE_WIDTH * 0.5 - inset
	var radius := maxf(COBBLE_RADIUS - inset * 0.35, COBBLE_RADIUS * 0.55)
	var centers: Array[Vector2] = [
		Vector2(half_length - radius, half_width - radius),
		Vector2(-half_length + radius, half_width - radius),
		Vector2(-half_length + radius, -half_width + radius),
		Vector2(half_length - radius, -half_width + radius),
	]
	var starts: Array[float] = [0.0, PI * 0.5, PI, PI * 1.5]
	for corner in centers.size():
		for segment in range(COBBLE_BEVEL_SEGMENTS + 1):
			var angle: float = starts[corner] + float(segment) / float(COBBLE_BEVEL_SEGMENTS) * PI * 0.5
			var point: Vector2 = centers[corner] + Vector2(cos(angle), sin(angle)) * radius
			points.append(Vector3(point.x, y, point.y))
	return points


static func _add_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for vertex in [a, b, c, a, c, d]:
		surface.add_vertex(vertex)


static func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for vertex in [a, b, c]:
		surface.add_vertex(vertex)


static func _build_detail_level(
	definition: MapDefinition,
	grid: MapTerrainGrid,
	cell_bounds: Rect2i,
	level: StringName,
	cobble_grid: Vector2i
) -> Node3D:
	var root := Node3D.new()
	var bounds := cell_bounds.intersection(Rect2i(Vector2i.ZERO, grid.size_cells))
	if bounds.size == Vector2i.ZERO:
		return root
	var field := MapViewMeshBuilderTerrain.ensure_height_field(definition, grid)
	var cobbles: Array[Transform3D] = []
	var cobble_colors: Array[Color] = []
	var meadow_grass: Array[Transform3D] = []
	var meadow_grass_colors: Array[Color] = []
	var dry_grass: Array[Transform3D] = []
	var dry_grass_colors: Array[Color] = []
	var clover: Array[Transform3D] = []
	var clover_colors: Array[Color] = []
	var fern: Array[Transform3D] = []
	var fern_colors: Array[Color] = []

	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var cell := Vector2i(x, y)
			var terrain := grid.get_terrain(cell)
			if terrain in PAVING_TERRAINS:
				_append_cobbles(
					cobbles,
					cobble_colors,
					field,
					cell,
					definition.seed,
					cobble_grid,
					level == DETAIL_FIRST_PERSON,
					terrain
				)
			elif level == DETAIL_FIRST_PERSON and terrain in GRASS_DETAIL_TERRAINS:
				_append_ground_cover(
					meadow_grass,
					meadow_grass_colors,
					dry_grass,
					dry_grass_colors,
					clover,
					clover_colors,
					fern,
					fern_colors,
					field,
					grid,
					cell,
					definition.seed
				)

	_add_layer(root, "Cobbles", cobble_mesh(), cobbles, cobble_colors, MapViewMaterials.cobble_detail())
	_add_foliage_layer(root, "MeadowGrass", MapViewFoliageMeshes.grass_tuft_mesh(), meadow_grass, meadow_grass_colors, GROUND_COVER_LIFT)
	_add_foliage_layer(root, "DryGrass", MapViewFoliageMeshes.grass_seed_head_mesh(), dry_grass, dry_grass_colors, GROUND_COVER_LIFT)
	_add_foliage_layer(root, "Clover", MapViewFoliageMeshes.clover_patch_mesh(), clover, clover_colors, GROUND_COVER_LIFT)
	_add_foliage_layer(root, "Ferns", MapViewFoliageMeshes.fern_frond_mesh(), fern, fern_colors, GROUND_COVER_LIFT)
	if level == DETAIL_FIRST_PERSON:
		for child in root.get_children():
			if child is GeometryInstance3D:
				var geometry := child as GeometryInstance3D
				geometry.visibility_range_end = MapViewMeshBuilderConfig.FIRST_PERSON_DETAIL_RANGE
				geometry.visibility_range_end_margin = MapViewMeshBuilderConfig.FIRST_PERSON_DETAIL_RANGE_MARGIN
	return root


static func _append_cobbles(
	transforms: Array[Transform3D],
	colors: Array[Color],
	field: Dictionary,
	cell: Vector2i,
	map_seed: int,
	cobble_grid: Vector2i,
	_high_detail: bool,
	terrain: StringName
) -> void:
	var columns := maxi(cobble_grid.x, 0)
	var rows := maxi(cobble_grid.y, 0)
	if columns == 0 or rows == 0:
		return
	# Keep neighboring logic cells on one continuous running-bond lattice. This
	# avoids the conspicuous cell-border gutters made by rotating every metre.
	var cell_rotation := (MapViewMeshBuilderPrimitives.hash01(0, 0, map_seed + 6101) - 0.5) * 0.025
	for row in rows:
		for column in columns:
			var index := row * columns + column
			var global_row := cell.y * rows + row
			var base_offset := Vector2(
				(float(column) + 0.5) / float(columns),
				(float(row) + 0.5) / float(rows)
			)
			if global_row % 2 == 1:
				base_offset.x += 0.5 / float(columns)
			base_offset.x = fposmod(base_offset.x, 1.0)
			var jitter := Vector2(
				MapViewMeshBuilderPrimitives.hash01(cell.x * 17 + index, cell.y, map_seed + 6113) - 0.5,
				MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y * 17 + index, map_seed + 6121) - 0.5
			) * COBBLE_MORTAR_JITTER
			var usable := 1.0 - COBBLE_EDGE_INSET * 2.0
			var spot := Vector2(cell) + Vector2(COBBLE_EDGE_INSET, COBBLE_EDGE_INSET) \
				+ base_offset * usable + jitter
			var length_scale := 0.96 + MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y + index, map_seed + 6131) * 0.07
			var width_scale := 0.96 + MapViewMeshBuilderPrimitives.hash01(cell.x + index, cell.y, map_seed + 6143) * 0.07
			var height_scale := 0.84 + MapViewMeshBuilderPrimitives.hash01(cell.x + index, cell.y + index, map_seed + 6151) * 0.24
			var yaw := cell_rotation + (MapViewMeshBuilderPrimitives.hash01(cell.x + index, cell.y, map_seed + 6163) - 0.5) * 0.08
			var basis := Basis(Vector3.UP, yaw).scaled(Vector3(length_scale, height_scale, width_scale))
			var ground := MapViewMeshBuilderTerrain.field_height(field, spot)
			transforms.append(
				Transform3D(
					basis,
					Vector3(spot.x, ground + COBBLE_HEIGHT * height_scale * 0.5 + DETAIL_LIFT, spot.y)
				)
			)
			colors.append(_cobble_tint(cell, index, map_seed, terrain))


## Worn Tallinn paving mixes gray granite, bluish limestone, and iron-stained
## purple-gray cobbles. Instance colors keep the variation inside one MultiMesh.
static func _cobble_tint(cell: Vector2i, index: int, map_seed: int, terrain: StringName) -> Color:
	var roll := MapViewMeshBuilderPrimitives.hash01(cell.x + index, cell.y - index, map_seed + 6173)
	var shade := 0.88 + MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y + index, map_seed + 6181) * 0.18
	var gray := Color(0.76, 0.77, 0.78)
	var blue_gray := Color(0.65, 0.70, 0.76)
	var purple_gray := Color(0.69, 0.65, 0.72)
	var tint: Color
	if roll < 0.52:
		tint = gray
	elif roll < 0.82:
		tint = blue_gray
	else:
		tint = purple_gray
	if terrain == MapTypes.TERRAIN_CASTLE_PAVING:
		tint = tint.lerp(Color(0.62, 0.60, 0.64), 0.22)
	return Color(tint.r * shade, tint.g * shade, tint.b * shade)


static func _append_ground_cover(
	grass: Array[Transform3D],
	grass_colors: Array[Color],
	dry: Array[Transform3D],
	dry_colors: Array[Color],
	clover: Array[Transform3D],
	clover_colors: Array[Color],
	ferns: Array[Transform3D],
	fern_colors: Array[Color],
	field: Dictionary,
	grid: MapTerrainGrid,
	cell: Vector2i,
	map_seed: int
) -> void:
	var terrain := grid.get_terrain(cell)
	var variant := grid.get_style_variant(cell)
	var cover_chance := 0.78
	match terrain:
		MapTypes.TERRAIN_MEADOW:
			cover_chance = 0.94
		MapTypes.TERRAIN_FOREST_FLOOR:
			cover_chance = 0.66
		MapTypes.TERRAIN_BOG:
			cover_chance = 0.58
	if MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, map_seed + 7103) < cover_chance:
		var count := 2 if terrain == MapTypes.TERRAIN_MEADOW else 1
		for index in count:
			var target_transforms := grass
			var target_colors := grass_colors
			var use_dry := variant == TerrainVegetation.VARIANT_GRASS_DRY or MapViewMeshBuilderPrimitives.hash01(cell.x + index, cell.y, map_seed + 7121) < 0.18
			if use_dry:
				target_transforms = dry
				target_colors = dry_colors
			target_transforms.append(_foliage_transform(field, cell, map_seed + 7133 + index * 41, 0.42, 0.86))
			if use_dry:
				target_colors.append(Color(0.86, 0.76, 0.46).lerp(Color(0.68, 0.72, 0.38), MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y + index, map_seed + 7151)))
			else:
				target_colors.append(Color(0.58, 0.82, 0.38).lerp(Color(0.34, 0.62, 0.30), MapViewMeshBuilderPrimitives.hash01(cell.x + index, cell.y, map_seed + 7163)))

	var clover_chance := 0.16
	if variant == TerrainVegetation.VARIANT_GRASS_CLOVER:
		clover_chance = 0.62
	if MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, map_seed + 7207) < clover_chance:
		clover.append(_foliage_transform(field, cell, map_seed + 7211, 0.7, 1.15))
		clover_colors.append(Color(0.55, 0.84, 0.38))

	var fern_chance := 0.06
	if terrain == MapTypes.TERRAIN_FOREST_FLOOR or variant == TerrainVegetation.VARIANT_GRASS_FERN:
		fern_chance = 0.42
	if MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, map_seed + 7307) < fern_chance:
		ferns.append(_foliage_transform(field, cell, map_seed + 7319, 0.54, 0.9))
		fern_colors.append(Color(0.32, 0.64, 0.30))


static func _foliage_transform(
	field: Dictionary,
	cell: Vector2i,
	noise_seed: int,
	scale_min: float,
	scale_max: float
) -> Transform3D:
	var offset := Vector2(
		0.08 + MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, noise_seed + 7) * 0.84,
		0.08 + MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, noise_seed + 13) * 0.84
	)
	var spot := Vector2(cell) + offset
	var scale := lerpf(scale_min, scale_max, MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, noise_seed + 29))
	var yaw := MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, noise_seed + 41) * TAU
	return Transform3D(
		Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale),
		Vector3(spot.x, MapViewMeshBuilderTerrain.field_height(field, spot), spot.y)
	)


static func _add_foliage_layer(
	root: Node3D,
	name: String,
	mesh: Mesh,
	transforms: Array[Transform3D],
	colors: Array[Color],
	lift: float
) -> void:
	if transforms.is_empty():
		return
	var layer := MapViewMeshBuilderPrimitives.multi_mesh(
		name,
		mesh,
		transforms,
		colors,
		MapViewMaterials.grass_blades(),
		Vector3.UP * lift
	)
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(layer)


static func _add_layer(
	root: Node3D,
	name: String,
	mesh: Mesh,
	transforms: Array[Transform3D],
	colors: Array[Color],
	material: Material
) -> void:
	if transforms.is_empty():
		return
	var layer := MapViewMeshBuilderPrimitives.multi_mesh(name, mesh, transforms, colors, material, Vector3.ZERO)
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(layer)
