class_name MapViewTerrainDetails
extends RefCounted

## View-only living ground cover. Worked paving is rendered directly by the
## continuous terrain mesh with baked color and normal detail, so cobblestones
## never become per-stone nodes, instances, geometry, or collision.

const DETAIL_TOP_DOWN := &"top_down"
const DETAIL_FIRST_PERSON := &"first_person"
const GROUND_COVER_LIFT := 0.006

const GRASS_DETAIL_TERRAINS: Array[StringName] = [
	MapTypes.TERRAIN_GRASS,
	MapTypes.TERRAIN_MEADOW,
	MapTypes.TERRAIN_FOREST_FLOOR,
	MapTypes.TERRAIN_BOG,
]


static func build_chunk(
	definition: MapDefinition,
	grid: MapTerrainGrid,
	cell_bounds: Rect2i,
	first_person: bool = false
) -> Node3D:
	var root := Node3D.new()
	root.name = "TerrainDetails"
	var detail := _build_detail_level(definition, grid, cell_bounds, first_person)
	detail.name = "FirstPerson" if first_person else "TopDown"
	root.add_child(detail)
	return root


static func is_first_person(root: Node) -> bool:
	return root != null and root.get_node_or_null("FirstPerson") != null


static func _build_detail_level(
	definition: MapDefinition,
	grid: MapTerrainGrid,
	cell_bounds: Rect2i,
	first_person: bool
) -> Node3D:
	var root := Node3D.new()
	var bounds := cell_bounds.intersection(Rect2i(Vector2i.ZERO, grid.size_cells))
	if bounds.size == Vector2i.ZERO or not first_person:
		return root
	var field := MapViewMeshBuilderTerrain.ensure_height_field(definition, grid)
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
			if grid.get_terrain(cell) not in GRASS_DETAIL_TERRAINS:
				continue
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

	_add_foliage_layer(root, "MeadowGrass", MapViewFoliageMeshes.grass_tuft_mesh(), meadow_grass, meadow_grass_colors, GROUND_COVER_LIFT)
	_add_foliage_layer(root, "DryGrass", MapViewFoliageMeshes.grass_seed_head_mesh(), dry_grass, dry_grass_colors, GROUND_COVER_LIFT)
	_add_foliage_layer(root, "Clover", MapViewFoliageMeshes.clover_patch_mesh(), clover, clover_colors, GROUND_COVER_LIFT)
	_add_foliage_layer(root, "Ferns", MapViewFoliageMeshes.fern_frond_mesh(), fern, fern_colors, GROUND_COVER_LIFT)
	for child in root.get_children():
		if child is GeometryInstance3D:
			var geometry := child as GeometryInstance3D
			geometry.visibility_range_end = MapViewMeshBuilderConfig.FIRST_PERSON_DETAIL_RANGE
			geometry.visibility_range_end_margin = MapViewMeshBuilderConfig.FIRST_PERSON_DETAIL_RANGE_MARGIN
	return root


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
