class_name MapViewMeshBuilderScatter
extends RefCounted

const Shoreline3D := preload("res://scripts/map/view3d/map_view_shoreline_3d.gd")
const PlantSpecies := preload("res://scripts/map/view3d/map_view_plant_species.gd")
const PlantMeshes := preload("res://scripts/map/view3d/map_view_plant_meshes.gd")

## Layered decorative vegetation and ground clutter. Textured ground cover carries
## most of the grass; sparse small/large tufts, shrubs, and trees add silhouette
## variation without turning every green cell into an object field.
static func build_scatter(
	definition: MapDefinition,
	grid: MapTerrainGrid,
	cell_bounds: Rect2i = Rect2i(Vector2i.ZERO, Vector2i.ZERO)
) -> Node3D:
	var root := Node3D.new()
	root.name = "Scatter"
	var blocked := MapViewMeshBuilderPrimitives.building_cell_rects(definition)
	var field := MapViewMeshBuilderTerrain.ensure_height_field(definition, grid)
	var bounds := cell_bounds
	if bounds.size == Vector2i.ZERO:
		bounds = Rect2i(Vector2i.ZERO, grid.size_cells)
	bounds = bounds.intersection(Rect2i(Vector2i.ZERO, grid.size_cells))
	var is_urban := _is_urban_map(definition)

	var small_grass: Array[Transform3D] = []
	var small_grass_colors: Array[Color] = []
	var large_grass: Array[Transform3D] = []
	var large_grass_colors: Array[Color] = []
	var dense_bushes: Array[Transform3D] = []
	var dense_bush_colors: Array[Color] = []
	var scrub_bushes: Array[Transform3D] = []
	var scrub_bush_colors: Array[Color] = []
	# Batched by silhouette/bark so MultiMesh stays shared across species tints.
	var tree_batches: Dictionary = {}
	var reeds: Array[Transform3D] = []
	var reed_colors: Array[Color] = []
	var cattails: Array[Transform3D] = []
	var cattail_colors: Array[Color] = []
	var clovers: Array[Transform3D] = []
	var clover_colors: Array[Color] = []
	# Concrete plant variants batch by species so each botanical profile keeps its
	# own cached silhouette while authored beds remain cheap to render.
	var plant_batches: Dictionary = {}
	var stones: Array[Transform3D] = []
	var stone_colors: Array[Color] = []
	var puddles: Array[Transform3D] = []
	var puddle_colors: Array[Color] = []

	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var cell := Vector2i(x, y)
			if MapViewMeshBuilderPrimitives.cell_blocked(cell, blocked):
				continue
			var terrain := grid.get_terrain(cell)
			var variant := grid.get_style_variant(cell)
			var profile := TerrainVegetation.scatter_profile(variant)
			var density := TerrainVegetation.object_density_multiplier(is_urban, variant)
			var tint := TerrainVegetation.ground_color_tint(variant)

			# Cattails are a view-only inland-bank layer driven by the smoothed
			# freshwater shoreline. Authored reed.shore zones cover moat ditches.
			if (
				MapViewMeshBuilderTerrain.is_inland_water_shore_cell(field, grid, cell)
				and MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 2879)
				< MapViewMeshBuilderConfig.SHORE_CATTAIL_CHANCE
			):
				var cluster_count := 1 + int(MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 2887) > 0.54)
				for cattail_index in cluster_count:
					cattails.append(_scatter_transform(field, x, y, definition.seed + 2903 + cattail_index * 31, 0.78, 1.18))
					var cattail_tint := MapViewMeshBuilderPrimitives.hash01(x + cattail_index, y, definition.seed + 2917)
					cattail_colors.append(Color(0.72, 0.83, 0.52).lerp(Color(0.49, 0.66, 0.36), cattail_tint))

			var puddle_chance := float(MapViewMeshBuilderConfig.PUDDLE_CHANCE.get(terrain, 0.0))
			if puddle_chance > 0.0:
				var height := MapViewMeshBuilderTerrain.field_height(field, Vector2(float(x) + 0.5, float(y) + 0.5))
				var low_bias := 1.0 - clampf(height / MapViewMeshBuilderConfig.HEIGHT_BROAD_AMPLITUDE, 0.0, 1.0)
				puddle_chance *= lerpf(0.65, 1.0, low_bias * MapViewMeshBuilderConfig.PUDDLE_LOW_HEIGHT_BIAS)
				if MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 1907) < puddle_chance:
					var puddle_scale_x := 0.42 + MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 1913) * 0.62
					var puddle_scale_z := 0.38 + MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 1919) * 0.68
					puddles.append(_scatter_transform_elliptical(field, x, y, definition.seed + 1921, puddle_scale_x, puddle_scale_z))
					var puddle_tint := 0.9 + MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 1929) * 0.14
					puddle_colors.append(Color(puddle_tint, puddle_tint, puddle_tint + 0.03))

			var small_chance := float(MapViewMeshBuilderConfig.SCATTER_SMALL_GRASS_CHANCE.get(terrain, 0.0))
			small_chance *= float(profile.get("small_chance_scale", 1.0)) * density
			if MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 4242) < small_chance:
				var small_min := float(profile.get("small_height_min", 0.34))
				var small_max := float(profile.get("small_height_max", 0.62))
				small_grass.append(_scatter_transform(field, x, y, definition.seed + 511, small_min, small_max))
				var green := 0.86 + MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 77) * 0.28
				small_grass_colors.append(Color(green * 0.94 * tint.r, green * tint.g, green * 0.8 * tint.b))

			var large_chance := float(profile.get("large_chance", 0.0)) * density
			if MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 4357) < large_chance:
				var large_min := float(profile.get("large_height_min", 0.75))
				var large_max := float(profile.get("large_height_max", 1.05))
				large_grass.append(_scatter_transform(field, x, y, definition.seed + 607, large_min, large_max))
				var large_green := 0.8 + MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 89) * 0.22
				large_grass_colors.append(Color(large_green * 0.92 * tint.r, large_green * tint.g, large_green * 0.76 * tint.b))

			if MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 1200) < float(profile.get("flower_chance", 0.0)) * density:
				small_grass.append(_scatter_transform(field, x, y, definition.seed + 1271, 0.35, 0.55))
				small_grass_colors.append(MapVisualStyle.role_color(&"flower", MapVisualStyle.TARGET_CLEAN_PAINTED, MapVisualStyle.TIME_DAY))
			if MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 1400) < float(profile.get("clover_chance", 0.0)) * density:
				clovers.append(_scatter_transform(field, x, y, definition.seed + 1450, 0.7, 1.0))
				clover_colors.append(Color(0.62, 0.86, 0.48))
			if MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 1300) < float(profile.get("fern_chance", 0.0)) * density:
				large_grass.append(_scatter_transform(field, x, y, definition.seed + 1310, 0.5, 0.82))
				large_grass_colors.append(Color(0.48, 0.72, 0.42))
			if MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 1600) < float(profile.get("reed_chance", 0.0)) * density:
				for reed_index in 2:
					reeds.append(_scatter_transform(field, x, y, definition.seed + 1800 + reed_index, 0.9, 1.35))
					reed_colors.append(Color(0.72, 0.82, 0.58).lerp(Color(0.58, 0.74, 0.48), MapViewMeshBuilderPrimitives.hash01(x + reed_index, y, definition.seed + 1811)))

			var plant_chance := float(profile.get("plant_chance", 0.0)) * density
			if plant_chance > 0.0 and MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 1867) < plant_chance:
				var plant_species: StringName = profile.get("plant_species", &"")
				_append_scattered_plant(plant_batches, field, x, y, definition.seed, plant_species)

			if MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 1500) < float(profile.get("dense_bush_chance", 0.0)) * density:
				dense_bushes.append(_scatter_transform(field, x, y, definition.seed + 1700, 0.62, 0.95))
				dense_bush_colors.append(Color(0.78, 0.94, 0.68))
			if MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 1529) < float(profile.get("scrub_bush_chance", 0.0)) * density:
				scrub_bushes.append(_scatter_transform_elliptical(field, x, y, definition.seed + 1733, 0.7, 0.45))
				scrub_bush_colors.append(Color(0.76, 0.88, 0.58))

			var tree_chance := float(profile.get("tree_chance", MapViewMeshBuilderConfig.SCATTER_TREE_CHANCE.get(terrain, 0.0))) * density
			if MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 2309) < tree_chance:
				var tree_variant: StringName = profile.get("tree_variant", variant)
				if tree_variant.is_empty() and TerrainVegetation.is_tree_variant(variant):
					tree_variant = variant
				elif tree_variant.is_empty():
					tree_variant = TerrainVegetation.VARIANT_TREE_MIXED
				_append_scattered_tree(
					tree_batches,
					field,
					x,
					y,
					definition.seed,
					tree_variant
				)

			var stone_chance := float(MapViewMeshBuilderConfig.SCATTER_STONE_CHANCE.get(terrain, 0.0))
			if MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 913) < stone_chance:
				stones.append(_scatter_transform(field, x, y, definition.seed + 947, 0.6, 1.6))
				var gray := 0.8 + MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 154) * 0.35
				stone_colors.append(Color(gray, gray, gray * 0.97))

	_add_grass_layer(root, "SmallGrass", small_grass, small_grass_colors, MapViewMeshBuilderPrimitives.grass_tuft_mesh())
	_add_grass_layer(root, "LargeGrass", large_grass, large_grass_colors, MapViewMeshBuilderPrimitives.grass_tuft_mesh())

	if not dense_bushes.is_empty():
		var dense_instances := MapViewMeshBuilderPrimitives.multi_mesh("DenseBushes", MapViewMeshBuilderPrimitives.leaf_canopy_mesh(), dense_bushes, dense_bush_colors, MapViewMaterials.canopy(&"leaf"), Vector3(0.0, 0.42, 0.0))
		dense_instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(dense_instances)
	if not scrub_bushes.is_empty():
		var scrub_mesh := SphereMesh.new()
		scrub_mesh.radius = 0.34
		scrub_mesh.height = 0.38
		scrub_mesh.radial_segments = 8
		scrub_mesh.rings = 4
		var scrub_instances := MapViewMeshBuilderPrimitives.multi_mesh("ScrubBushes", scrub_mesh, scrub_bushes, scrub_bush_colors, MapViewMaterials.foliage_tuft(), Vector3(0.0, 0.16, 0.0))
		scrub_instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(scrub_instances)

	if not tree_batches.is_empty():
		_emit_tree_batches(root, tree_batches)

	if not reeds.is_empty():
		_add_grass_layer(root, "Reeds", reeds, reed_colors, MapViewMeshBuilderPrimitives.reed_stem_mesh())
	if not cattails.is_empty():
		_add_cattail_layer(root, cattails, cattail_colors)
	if not clovers.is_empty():
		var clover_instances := MapViewMeshBuilderPrimitives.multi_mesh("Clovers", MapViewMeshBuilderPrimitives.clover_patch_mesh(), clovers, clover_colors, MapViewMaterials.foliage_tuft(), Vector3(0.0, 0.02, 0.0))
		clover_instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(clover_instances)

	if not plant_batches.is_empty():
		_emit_plant_batches(root, plant_batches)

	if not puddles.is_empty():
		var puddle_mesh := PlaneMesh.new()
		puddle_mesh.size = Vector2(0.88, 0.88)
		var puddle_instances := MapViewMeshBuilderPrimitives.multi_mesh("Puddles", puddle_mesh, puddles, puddle_colors, MapViewMaterials.puddle_surface(), Vector3(0.0, 0.012, 0.0))
		puddle_instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puddle_instances.sorting_offset = 0.5
		root.add_child(puddle_instances)

	if not stones.is_empty():
		var stone_mesh := SphereMesh.new()
		stone_mesh.radius = 0.09
		stone_mesh.height = 0.11
		stone_mesh.radial_segments = 8
		stone_mesh.rings = 4
		root.add_child(MapViewMeshBuilderPrimitives.multi_mesh("Stones", stone_mesh, stones, stone_colors, MapViewMaterials.natural_rock(), Vector3(0.0, 0.03, 0.0)))
	Shoreline3D.add_to(root, definition, grid, bounds)
	return root


static func _is_urban_map(definition: MapDefinition) -> bool:
	for kind: Variant in definition.resolved_surroundings_sides().values():
		if kind == &"town":
			return true
	return false


## Collect one concrete botanical species into its own cached MultiMesh batch.
static func _append_scattered_plant(
	batches: Dictionary,
	field: Dictionary,
	x: int,
	y: int,
	map_seed: int,
	species: StringName
) -> void:
	if not PlantSpecies.is_known_species(species):
		return
	var key := String(species)
	if not batches.has(key):
		batches[key] = {
			"transforms": [] as Array[Transform3D],
			"colors": [] as Array[Color],
			"species": species,
		}
	var scale_range := PlantSpecies.scale_range(species)
	var batch: Dictionary = batches[key]
	(batch["transforms"] as Array).append(
		_scatter_transform(field, x, y, map_seed + 1879, scale_range.x, scale_range.y)
	)
	(batch["colors"] as Array).append(
		PlantSpecies.instance_tint(
			species,
			MapViewMeshBuilderPrimitives.hash01(x, y, map_seed + 1889)
		)
	)


static func _emit_plant_batches(root: Node3D, batches: Dictionary) -> void:
	for key: Variant in batches.keys():
		var batch: Dictionary = batches[key]
		var transforms: Array[Transform3D] = []
		var colors: Array[Color] = []
		for transform: Variant in batch["transforms"]:
			transforms.append(transform as Transform3D)
		for color: Variant in batch["colors"]:
			colors.append(color as Color)
		if transforms.is_empty():
			continue
		var species: StringName = batch["species"]
		var instances := MapViewMeshBuilderPrimitives.multi_mesh(
			"Plants_%s" % String(species).to_pascal_case(),
			PlantMeshes.mesh_for(species),
			transforms,
			colors,
			MapViewMaterials.grass_blades(),
			Vector3.ZERO
		)
		instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instances.set_meta(&"plant_species", species)
		root.add_child(instances)


## Collect one procedural tree into species MultiMesh buckets. Species-specific
## cached geometry preserves branch architecture while keeping three draw calls
## at most per visible species: wood, leaves, and optional fruit.
static func _append_scattered_tree(
	batches: Dictionary,
	field: Dictionary,
	x: int,
	y: int,
	map_seed: int,
	tree_variant: StringName
) -> void:
	var parsed: Dictionary = MapViewTreeSpecies.parse_variant(tree_variant)
	var weights := MapViewTreeSpecies.weights_for_variant(tree_variant)
	var species := MapViewTreeSpecies.pick_species(
		weights,
		MapViewMeshBuilderPrimitives.hash01(x, y, map_seed + 2371)
	)
	var pinned_size: StringName = parsed.get("size", &"")
	# Pinned size from tree.oak.large; otherwise roll the natural size mix.
	if pinned_size == MapViewTreeSpecies.SIZE_MEDIUM and not String(tree_variant).ends_with(".medium"):
		# Default parse size is medium; treat as unpinned unless the author
		# wrote an explicit size suffix.
		var parts := String(tree_variant).split(".")
		if parts.size() < 3:
			pinned_size = &""
	var size_class := MapViewTreeSpecies.pick_size(
		MapViewMeshBuilderPrimitives.hash01(x, y, map_seed + 2393),
		pinned_size
	)
	var scale_vec := MapViewTreeSpecies.instance_scale(
		size_class,
		MapViewMeshBuilderPrimitives.hash01(x, y, map_seed + 2311 + 29)
	)
	var tree_transform := _scatter_transform_scaled(
		field,
		x,
		y,
		map_seed + 2311,
		scale_vec
	)
	_push_tree_instance(
		batches,
		species,
		tree_transform,
		MapViewMeshBuilderPrimitives.hash01(x, y, map_seed + 2333),
		MapViewMeshBuilderPrimitives.hash01(x, y, map_seed + 2357)
	)


static func _push_tree_instance(
	batches: Dictionary,
	species: StringName,
	tree_transform: Transform3D,
	bark_roll: float,
	canopy_roll: float
) -> void:
	var species_key := String(species)
	var trunk_key := "tree_wood:%s" % species_key
	var canopy_key := "tree_canopy:%s" % species_key
	if not batches.has(trunk_key):
		batches[trunk_key] = {
			"transforms": [] as Array[Transform3D],
			"colors": [] as Array[Color],
			"layer": &"wood",
			"species": species,
		}
	if not batches.has(canopy_key):
		batches[canopy_key] = {
			"transforms": [] as Array[Transform3D],
			"colors": [] as Array[Color],
			"layer": &"canopy",
			"species": species,
		}
	var trunk_batch: Dictionary = batches[trunk_key]
	(trunk_batch["transforms"] as Array).append(tree_transform)
	(trunk_batch["colors"] as Array).append(MapViewTreeSpecies.bark_tint(species, bark_roll))
	var canopy_batch: Dictionary = batches[canopy_key]
	(canopy_batch["transforms"] as Array).append(tree_transform)
	(canopy_batch["colors"] as Array).append(MapViewTreeSpecies.canopy_tint(species, canopy_roll))
	var fruit_mesh := MapViewMeshBuilderPrimitives.tree_fruit_mesh(species)
	if fruit_mesh != null:
		var fruit_key := "tree_fruit:%s" % species_key
		if not batches.has(fruit_key):
			batches[fruit_key] = {
				"transforms": [] as Array[Transform3D],
				"colors": [] as Array[Color],
				"layer": &"fruit",
				"species": species,
			}
		var fruit_batch: Dictionary = batches[fruit_key]
		(fruit_batch["transforms"] as Array).append(tree_transform)
		(fruit_batch["colors"] as Array).append(Color.WHITE)


static func _emit_tree_batches(root: Node3D, batches: Dictionary) -> void:
	var emitted_default_trunk := false
	var emitted_birch_trunk := false
	for key: Variant in batches.keys():
		var batch: Dictionary = batches[key]
		var transforms: Array = batch["transforms"]
		if transforms.is_empty():
			continue
		var typed_transforms: Array[Transform3D] = []
		var typed_colors: Array[Color] = []
		for index in transforms.size():
			typed_transforms.append(transforms[index])
			typed_colors.append(batch["colors"][index])
		var species: StringName = batch["species"]
		var layer: StringName = batch["layer"]
		var mesh: Mesh
		var material: Material
		var layer_name: String
		match layer:
			&"wood":
				mesh = MapViewMeshBuilderPrimitives.tree_wood_mesh(species)
				var bark_kind := MapViewTreeSpecies.bark_kind_for(species)
				material = MapViewMaterials.bark(bark_kind)
				if bark_kind == MapViewTreeSpecies.BARK_BIRCH and not emitted_birch_trunk:
					layer_name = "TreeTrunksBirch"
					emitted_birch_trunk = true
				elif bark_kind != MapViewTreeSpecies.BARK_BIRCH and not emitted_default_trunk:
					layer_name = "TreeTrunks"
					emitted_default_trunk = true
				else:
					layer_name = "TreeTrunks_%s" % String(species).capitalize()
			&"fruit":
				mesh = MapViewMeshBuilderPrimitives.tree_fruit_mesh(species)
				material = MapViewMaterials.tree_fruit()
				layer_name = "TreeFruit_%s" % String(species).capitalize()
			_:
				mesh = MapViewMeshBuilderPrimitives.tree_canopy_mesh(species)
				material = MapViewMaterials.canopy(MapViewTreeSpecies.canopy_material_kind(species))
				layer_name = "Trees_%s" % String(species).capitalize()
		var instances := MapViewMeshBuilderPrimitives.multi_mesh(
			layer_name,
			mesh,
			typed_transforms,
			typed_colors,
			material,
			Vector3.ZERO
		)
		if layer == &"fruit":
			instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(instances)


static func _add_grass_layer(root: Node3D, layer_name: String, transforms: Array[Transform3D], colors: Array[Color], mesh: Mesh) -> void:
	if transforms.is_empty():
		return
	var instances := MapViewMeshBuilderPrimitives.multi_mesh(layer_name, mesh, transforms, colors, MapViewMaterials.grass_blades(), Vector3.ZERO)
	# Paper-thin wind-animated blades flicker in directional shadow maps.
	instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(instances)


static func _add_cattail_layer(
	root: Node3D,
	transforms: Array[Transform3D],
	colors: Array[Color]
) -> void:
	# Unlike generic wind grass, cattails carry per-vertex leaf and seed-head
	# colors, so a lightweight vertex-colored material preserves both silhouettes.
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.95
	var instances := MapViewMeshBuilderPrimitives.multi_mesh(
		"BankCattails",
		MapViewMeshBuilderPrimitives.cattail_cluster_mesh(),
		transforms,
		colors,
		material,
		Vector3.ZERO
	)
	instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(instances)


## Deterministic placement helpers shared by all terrain scatter layers.


static func _scatter_transform(field: Dictionary, x: int, y: int, noise_seed: int, scale_min: float, scale_max: float) -> Transform3D:
	var scale := scale_min + MapViewMeshBuilderPrimitives.hash01(x, y, noise_seed + 29) * (scale_max - scale_min)
	return _scatter_transform_scaled(field, x, y, noise_seed, Vector3.ONE * scale)


static func _scatter_transform_scaled(
	field: Dictionary,
	x: int,
	y: int,
	noise_seed: int,
	scale: Vector3
) -> Transform3D:
	var offset := Vector2(
		MapViewMeshBuilderPrimitives.hash01(x, y, noise_seed + 7) * 0.9 + 0.05,
		MapViewMeshBuilderPrimitives.hash01(x, y, noise_seed + 13) * 0.9 + 0.05
	)
	var yaw := MapViewMeshBuilderPrimitives.hash01(x, y, noise_seed + 41) * TAU
	var basis := Basis(Vector3.UP, yaw).scaled(scale)
	var spot := Vector2(float(x) + offset.x, float(y) + offset.y)
	return Transform3D(basis, Vector3(spot.x, MapViewMeshBuilderTerrain.field_height(field, spot), spot.y))


static func _scatter_transform_elliptical(
	field: Dictionary,
	x: int,
	y: int,
	noise_seed: int,
	scale_x: float,
	scale_z: float
) -> Transform3D:
	var offset := Vector2(
		MapViewMeshBuilderPrimitives.hash01(x, y, noise_seed + 7) * 0.9 + 0.05,
		MapViewMeshBuilderPrimitives.hash01(x, y, noise_seed + 13) * 0.9 + 0.05
	)
	var yaw := MapViewMeshBuilderPrimitives.hash01(x, y, noise_seed + 41) * TAU
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3(scale_x, 1.0, scale_z))
	var spot := Vector2(float(x) + offset.x, float(y) + offset.y)
	return Transform3D(basis, Vector3(spot.x, MapViewMeshBuilderTerrain.field_height(field, spot), spot.y))
