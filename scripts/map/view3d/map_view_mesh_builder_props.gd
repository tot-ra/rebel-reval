class_name MapViewMeshBuilderProps
extends RefCounted

## Prop meshes and ground scatter.

static func build_prop(prop: Dictionary, cell_size: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Prop_%s" % String(prop["id"])
	root.position = MapViewBridge.logic_to_world(prop["position"], cell_size)
	if prop.has("visual_offset_px"):
		var offset: Vector2 = prop["visual_offset_px"]
		var scale := MapViewBridge.world_scale(cell_size)
		root.position.x += offset.x * scale
		root.position.y -= offset.y * scale

	match prop["kind"] as StringName:
		MapTypes.PROP_KIND_ANVIL:
			MapViewMeshBuilderPrimitives.box(root, "Base", Vector3(0.9, 0.22, 0.5), Vector3(0.0, 0.11, 0.0), &"wood")
			MapViewMeshBuilderPrimitives.box(root, "Body", Vector3(0.65, 0.3, 0.32), Vector3(0.0, 0.37, 0.0), &"metal")
			MapViewMeshBuilderPrimitives.box(root, "Face", Vector3(1.05, 0.14, 0.34), Vector3(0.0, 0.59, 0.0), &"metal")
		MapTypes.PROP_KIND_HAY_STACK:
			MapViewMeshBuilderPrimitives.sphere(root, "Mound", 0.85, Vector3(0.0, 0.42, 0.0), &"hay", Vector3(1.0, 0.62, 1.0))
			MapViewMeshBuilderPrimitives.sphere(root, "Crown", 0.5, Vector3(0.1, 0.78, -0.05), &"hay", Vector3(1.0, 0.6, 1.0))
		MapTypes.PROP_KIND_CART:
			MapViewMeshBuilderPrimitives.box(root, "Bed", Vector3(1.6, 0.16, 0.9), Vector3(0.0, 0.6, 0.0), &"wood")
			MapViewMeshBuilderPrimitives.cylinder(root, "WheelLeft", 0.34, 0.1, Vector3(-0.45, 0.34, 0.5), &"wood", true)
			MapViewMeshBuilderPrimitives.cylinder(root, "WheelRight", 0.34, 0.1, Vector3(-0.45, 0.34, -0.5), &"wood", true)
			MapViewMeshBuilderPrimitives.box(root, "Handle", Vector3(0.9, 0.08, 0.5), Vector3(1.1, 0.62, 0.0), &"wood")
		MapTypes.PROP_KIND_WELL:
			MapViewMeshBuilderPrimitives.cylinder(root, "Ring", 0.55, 0.5, Vector3(0.0, 0.25, 0.0), &"stone")
			MapViewMeshBuilderPrimitives.cylinder(root, "Water", 0.42, 0.06, Vector3(0.0, 0.49, 0.0), &"water_highlight")
			MapViewMeshBuilderPrimitives.box(root, "PostLeft", Vector3(0.1, 1.0, 0.1), Vector3(-0.5, 0.75, 0.0), &"wood")
			MapViewMeshBuilderPrimitives.box(root, "PostRight", Vector3(0.1, 1.0, 0.1), Vector3(0.5, 0.75, 0.0), &"wood")
			MapViewMeshBuilderPrimitives.box(root, "RoofBeam", Vector3(1.3, 0.1, 0.5), Vector3(0.0, 1.3, 0.0), &"roof")
		MapTypes.PROP_KIND_BARRELS:
			MapViewMeshBuilderPrimitives.cylinder(root, "BarrelA", 0.28, 0.62, Vector3(-0.24, 0.31, 0.05), &"wood")
			MapViewMeshBuilderPrimitives.cylinder(root, "BarrelB", 0.28, 0.62, Vector3(0.3, 0.31, -0.14), &"wood")
		MapTypes.PROP_KIND_FURNACE:
			MapViewMeshBuilderPrimitives.box(root, "Mass", Vector3(1.35, 1.35, 1.1), Vector3(0.0, 0.68, 0.0), &"stone")
			MapViewMeshBuilderPrimitives.box(root, "Mouth", Vector3(0.52, 0.42, 0.08), Vector3(0.0, 0.42, 0.58), &"ember")
			# The flue must rise from the masonry as one breast: it seats into the
			# mass top and runs past the interior ceiling plane (3.65+) so it never
			# reads as a floating brick block from first-person.
			MapViewMeshBuilderPrimitives.add_chimney_stack(root, "Chimney", 0.44, 2.55, Vector3(0.0, 1.25, -0.15))
		MapTypes.PROP_KIND_LEDGER:
			MapViewMeshBuilderPrimitives.box(root, "Stand", Vector3(0.16, 0.9, 0.16), Vector3(0.0, 0.45, 0.0), &"wood")
			MapViewMeshBuilderPrimitives.box(root, "Book", Vector3(0.52, 0.08, 0.42), Vector3(0.0, 0.95, 0.0), &"plaster")
		MapTypes.PROP_KIND_BED:
			MapViewMeshBuilderPrimitives.box(root, "Frame", Vector3(2.4, 0.38, 1.35), Vector3(0.0, 0.19, 0.0), &"wood")
			MapViewMeshBuilderPrimitives.box(root, "Mattress", Vector3(2.2, 0.16, 1.2), Vector3(0.0, 0.46, 0.0), &"plaster")
			MapViewMeshBuilderPrimitives.box(root, "Pillow", Vector3(0.42, 0.14, 0.72), Vector3(-0.82, 0.58, 0.0), &"hay")
		MapTypes.PROP_KIND_CHEST:
			MapViewMeshBuilderPrimitives.box(root, "Box", Vector3(0.7, 0.42, 0.46), Vector3(0.0, 0.21, 0.0), &"wood")
			MapViewMeshBuilderPrimitives.box(root, "Lid", Vector3(0.72, 0.14, 0.48), Vector3(0.0, 0.49, 0.0), &"timber")
		MapTypes.PROP_KIND_TABLE:
			MapViewMeshBuilderPrimitives.box(root, "Top", Vector3(1.5, 0.08, 0.95), Vector3(0.0, 0.58, 0.0), &"wood")
			MapViewMeshBuilderPrimitives.box(root, "LegsLeft", Vector3(0.1, 0.54, 0.78), Vector3(-0.62, 0.27, 0.0), &"timber")
			MapViewMeshBuilderPrimitives.box(root, "LegsRight", Vector3(0.1, 0.54, 0.78), Vector3(0.62, 0.27, 0.0), &"timber")
		MapTypes.PROP_KIND_SHELF:
			MapViewMeshBuilderPrimitives.box(root, "Frame", Vector3(0.9, 1.4, 0.3), Vector3(0.0, 0.7, 0.0), &"timber")
			for level in 3:
				MapViewMeshBuilderPrimitives.box(root, "Board%d" % level, Vector3(0.82, 0.06, 0.26), Vector3(0.0, 0.35 + 0.4 * level, 0.0), &"wood")
		MapTypes.PROP_KIND_QUENCH:
			MapViewMeshBuilderPrimitives.cylinder(root, "Bucket", 0.3, 0.46, Vector3(0.0, 0.23, 0.0), &"wood")
			MapViewMeshBuilderPrimitives.cylinder(root, "Water", 0.24, 0.05, Vector3(0.0, 0.44, 0.0), &"water_highlight")
		MapTypes.PROP_KIND_STAIRS:
			for step in 3:
				MapViewMeshBuilderPrimitives.box(
					root,
					"Step%d" % step,
					Vector3(1.0, 0.2, 0.4),
					Vector3(0.0, 0.1 + 0.2 * step, -0.35 * step),
					&"stone"
				)
		MapTypes.PROP_KIND_STALL:
			MapViewMeshBuilderPrimitives.box(root, "Counter", Vector3(1.4, 0.8, 0.6), Vector3(0.0, 0.4, 0.0), &"wood")
			MapViewMeshBuilderPrimitives.box(root, "PostLeft", Vector3(0.08, 1.5, 0.08), Vector3(-0.65, 0.75, -0.4), &"timber")
			MapViewMeshBuilderPrimitives.box(root, "PostRight", Vector3(0.08, 1.5, 0.08), Vector3(0.65, 0.75, -0.4), &"timber")
			MapViewMeshBuilderPrimitives.box(root, "Canopy", Vector3(1.6, 0.08, 1.1), Vector3(0.0, 1.55, -0.1), &"hay")
		MapTypes.PROP_KIND_HEARTH:
			MapViewMeshBuilderPrimitives.box(root, "Base", Vector3(1.0, 0.4, 1.0), Vector3(0.0, 0.2, 0.0), &"stone")
			MapViewMeshBuilderPrimitives.box(root, "Fire", Vector3(0.5, 0.22, 0.5), Vector3(0.0, 0.5, 0.0), &"ember")
		MapTypes.PROP_KIND_CHAIR:
			MapViewMeshBuilderPrimitives.box(root, "Seat", Vector3(0.5, 0.08, 0.45), Vector3(0.0, 0.42, 0.0), &"wood")
			MapViewMeshBuilderPrimitives.box(root, "Back", Vector3(0.48, 0.5, 0.06), Vector3(0.0, 0.72, -0.18), &"timber")
			MapViewMeshBuilderPrimitives.box(root, "LegFL", Vector3(0.06, 0.4, 0.06), Vector3(-0.18, 0.2, 0.14), &"timber")
			MapViewMeshBuilderPrimitives.box(root, "LegFR", Vector3(0.06, 0.4, 0.06), Vector3(0.18, 0.2, 0.14), &"timber")
		MapTypes.PROP_KIND_CANDLE:
			MapViewMeshBuilderPrimitives.cylinder(root, "Holder", 0.12, 0.06, Vector3(0.0, 0.03, 0.0), &"metal")
			MapViewMeshBuilderPrimitives.cylinder(root, "Wax", 0.05, 0.22, Vector3(0.0, 0.2, 0.0), &"plaster")
			var flame := MeshInstance3D.new()
			flame.name = "Flame"
			var flame_mesh := SphereMesh.new()
			flame_mesh.radius = 0.07
			flame_mesh.height = 0.14
			flame_mesh.radial_segments = 8
			flame_mesh.rings = 4
			flame.mesh = flame_mesh
			flame.position = Vector3(0.0, 0.36, 0.0)
			flame.material_override = MapViewMeshBuilderPrimitives.role_material(&"ember")
			root.add_child(flame)
			var candle_light := OmniLight3D.new()
			candle_light.name = "Omni"
			candle_light.position = Vector3(0.0, 0.42, 0.0)
			root.add_child(candle_light)
			var controller = MapViewMeshBuilderConfig.CANDLE_LIGHT_SCRIPT.new()
			controller.configure(candle_light, flame)
			root.add_child(controller)
		MapTypes.PROP_KIND_BUSH:
			MapViewMeshBuilderPrimitives.sphere(root, "BushA", 0.42, Vector3(-0.18, 0.28, 0.08), &"vegetation", Vector3(1.0, 0.72, 1.0))
			MapViewMeshBuilderPrimitives.sphere(root, "BushB", 0.36, Vector3(0.22, 0.24, -0.12), &"vegetation", Vector3(1.0, 0.68, 1.0))
			MapViewMeshBuilderPrimitives.sphere(root, "BushC", 0.3, Vector3(0.04, 0.18, 0.16), &"vegetation", Vector3(1.0, 0.66, 1.0))
		_:
			MapViewMeshBuilderPrimitives.box(root, "Marker", Vector3(0.5, 0.5, 0.5), Vector3(0.0, 0.25, 0.0), &"ink")
	return root


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
	var tree_trunks: Array[Transform3D] = []
	var tree_trunk_colors: Array[Color] = []
	var spruce_canopies: Array[Transform3D] = []
	var spruce_colors: Array[Color] = []
	var leaf_canopies: Array[Transform3D] = []
	var leaf_colors: Array[Color] = []
	var reeds: Array[Transform3D] = []
	var reed_colors: Array[Color] = []
	var cattails: Array[Transform3D] = []
	var cattail_colors: Array[Color] = []
	var clovers: Array[Transform3D] = []
	var clover_colors: Array[Color] = []
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

			# Cattails are a view-only riverbank layer driven by the smoothed
			# shoreline. Authored reed zones remain available for deliberate beds.
			if (
				MapViewMeshBuilderTerrain.is_natural_shore_cell(field, grid, cell)
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

			if MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 1500) < float(profile.get("dense_bush_chance", 0.0)) * density:
				dense_bushes.append(_scatter_transform(field, x, y, definition.seed + 1700, 0.62, 0.95))
				dense_bush_colors.append(Color(0.78, 0.94, 0.68))
			if MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 1529) < float(profile.get("scrub_bush_chance", 0.0)) * density:
				scrub_bushes.append(_scatter_transform_elliptical(field, x, y, definition.seed + 1733, 0.7, 0.45))
				scrub_bush_colors.append(Color(0.76, 0.88, 0.58))

			var tree_chance := float(profile.get("tree_chance", MapViewMeshBuilderConfig.SCATTER_TREE_CHANCE.get(terrain, 0.0))) * density
			if MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 2309) < tree_chance:
				var tree_transform := _scatter_transform(field, x, y, definition.seed + 2311, 0.72, 1.12)
				tree_trunks.append(tree_transform)
				var bark := 0.82 + MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 2333) * 0.25
				tree_trunk_colors.append(Color(bark, bark, bark))
				var spruce_ratio := float(profile.get("spruce_ratio", MapViewMeshBuilderConfig.SCATTER_TREE_SPRUCE_RATIO.get(terrain, 0.5)))
				var foliage_tint := 0.82 + MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 2357) * 0.28
				if MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 2371) < spruce_ratio:
					spruce_canopies.append(tree_transform)
					spruce_colors.append(Color(foliage_tint * 0.88, foliage_tint, foliage_tint * 0.86))
				else:
					leaf_canopies.append(tree_transform)
					leaf_colors.append(Color(foliage_tint * 0.96, foliage_tint, foliage_tint * 0.78))

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

	if not tree_trunks.is_empty():
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.09
		trunk_mesh.bottom_radius = 0.15
		trunk_mesh.height = 1.2
		trunk_mesh.radial_segments = 7
		root.add_child(MapViewMeshBuilderPrimitives.multi_mesh("TreeTrunks", trunk_mesh, tree_trunks, tree_trunk_colors, MapViewMaterials.bark(), Vector3(0.0, 0.6, 0.0)))
	if not spruce_canopies.is_empty():
		root.add_child(MapViewMeshBuilderPrimitives.multi_mesh("SpruceTrees", MapViewMeshBuilderPrimitives.spruce_canopy_mesh(), spruce_canopies, spruce_colors, MapViewMaterials.canopy(&"spruce"), Vector3(0.0, 0.4, 0.0)))
	if not leaf_canopies.is_empty():
		root.add_child(MapViewMeshBuilderPrimitives.multi_mesh("DeciduousTrees", MapViewMeshBuilderPrimitives.leaf_canopy_mesh(), leaf_canopies, leaf_colors, MapViewMaterials.canopy(&"leaf"), Vector3(0.0, 1.55, 0.0)))

	if not reeds.is_empty():
		_add_grass_layer(root, "Reeds", reeds, reed_colors, MapViewMeshBuilderPrimitives.reed_stem_mesh())
	if not cattails.is_empty():
		_add_cattail_layer(root, cattails, cattail_colors)
	if not clovers.is_empty():
		var clover_instances := MapViewMeshBuilderPrimitives.multi_mesh("Clovers", MapViewMeshBuilderPrimitives.clover_patch_mesh(), clovers, clover_colors, MapViewMaterials.foliage_tuft(), Vector3(0.0, 0.02, 0.0))
		clover_instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(clover_instances)

	if not puddles.is_empty():
		var puddle_mesh := PlaneMesh.new()
		puddle_mesh.size = Vector2(0.88, 0.88)
		var puddle_instances := MapViewMeshBuilderPrimitives.multi_mesh("Puddles", puddle_mesh, puddles, puddle_colors, MapViewMaterials.puddle_surface(), Vector3(0.0, 0.012, 0.0))
		puddle_instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puddle_instances.sorting_offset = 0.5
		root.add_child(puddle_instances)

	var stone_mesh := SphereMesh.new()
	stone_mesh.radius = 0.09
	stone_mesh.height = 0.11
	stone_mesh.radial_segments = 8
	stone_mesh.rings = 4
	root.add_child(MapViewMeshBuilderPrimitives.multi_mesh("Stones", stone_mesh, stones, stone_colors, MapViewMaterials.role(&"stone"), Vector3(0.0, 0.03, 0.0)))
	return root


static func _is_urban_map(definition: MapDefinition) -> bool:
	for kind: Variant in definition.resolved_surroundings_sides().values():
		if kind == &"town":
			return true
	return false


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
	var offset := Vector2(
		MapViewMeshBuilderPrimitives.hash01(x, y, noise_seed + 7) * 0.9 + 0.05,
		MapViewMeshBuilderPrimitives.hash01(x, y, noise_seed + 13) * 0.9 + 0.05
	)
	var scale := scale_min + MapViewMeshBuilderPrimitives.hash01(x, y, noise_seed + 29) * (scale_max - scale_min)
	var yaw := MapViewMeshBuilderPrimitives.hash01(x, y, noise_seed + 41) * TAU
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
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
