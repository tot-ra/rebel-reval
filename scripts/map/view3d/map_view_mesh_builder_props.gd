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
			MapViewMeshBuilderPrimitives.add_chimney_stack(root, "Chimney", 0.38, 0.72, Vector3(0.25, 1.62, -0.15))
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


## Decorative ground clutter per terrain family: wind-swaying grass blade
## tufts on green cells, pebbles on worked ground. Deterministic from the map
## seed, skips building footprints, and stays under knee height so it never
## suggests collision.


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

	var tufts: Array[Transform3D] = []
	var tuft_colors: Array[Color] = []
	var bushes: Array[Transform3D] = []
	var bush_colors: Array[Color] = []
	var stones: Array[Transform3D] = []
	var stone_colors: Array[Color] = []
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var cell := Vector2i(x, y)
			if MapViewMeshBuilderPrimitives.cell_blocked(cell, blocked):
				continue
			var terrain := grid.get_terrain(cell)
			var variant := grid.get_style_variant(cell)
			var profile := TerrainVegetation.scatter_profile(variant)
			var roll := MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 4242)
			var tuft_chance := float(MapViewMeshBuilderConfig.SCATTER_TUFT_CHANCE.get(terrain, 0.0)) * float(profile.get("chance_scale", 1.0))
			if roll < tuft_chance:
				var count := 2 + int(MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 511) * 2.0)
				for tuft_index in count:
					var height_min := float(profile.get("height_min", 0.7))
					var height_max := float(profile.get("height_max", 1.4))
					tufts.append(_scatter_transform(field, x, y, definition.seed + 31 * (tuft_index + 1), height_min, height_max))
					var green := 0.86 + MapViewMeshBuilderPrimitives.hash01(x + tuft_index, y, definition.seed + 77) * 0.28
					var tint := TerrainVegetation.ground_color_tint(variant)
					tuft_colors.append(Color(green * 0.94 * tint.r, green * tint.g, green * 0.8 * tint.b))
					if float(profile.get("flower_chance", 0.0)) > 0.0 and MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 1200 + tuft_index) < float(profile["flower_chance"]):
						tufts.append(_scatter_transform(field, x, y, definition.seed + 71 * (tuft_index + 1), 0.35, 0.55))
						tuft_colors.append(MapVisualStyle.role_color(&"flower", MapVisualStyle.TARGET_CLEAN_PAINTED, MapVisualStyle.TIME_DAY))
				if float(profile.get("bush_chance", 0.0)) > 0.0 and MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 1500) < float(profile["bush_chance"]):
					bushes.append(_scatter_transform(field, x, y, definition.seed + 1700, 0.8, 1.2))
					var bush_green := MapVisualStyle.role_color(&"vegetation", MapVisualStyle.TARGET_CLEAN_PAINTED, MapVisualStyle.TIME_DAY)
					bush_colors.append(bush_green)
			elif roll < tuft_chance + MapViewMeshBuilderConfig.SCATTER_STONE_CHANCE.get(terrain, 0.0):
				stones.append(_scatter_transform(field, x, y, definition.seed + 913, 0.6, 1.6))
				var gray := 0.8 + MapViewMeshBuilderPrimitives.hash01(x, y, definition.seed + 154) * 0.35
				stone_colors.append(Color(gray, gray, gray * 0.97))

	var grass_tufts := MapViewMeshBuilderPrimitives.multi_mesh("Tufts", MapViewMeshBuilderPrimitives.grass_tuft_mesh(), tufts, tuft_colors, MapViewMaterials.grass_blades(), Vector3.ZERO)
	# Knee-height scatter should not cast shadows: wind-swayed vertices make
	# directional shadow maps flicker on paper-thin blade geometry.
	grass_tufts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(grass_tufts)

	if not bushes.is_empty():
		var bush_mesh := SphereMesh.new()
		bush_mesh.radius = 0.22
		bush_mesh.height = 0.34
		var bush_instances := MapViewMeshBuilderPrimitives.multi_mesh("Bushes", bush_mesh, bushes, bush_colors, MapViewMaterials.foliage_tuft(), Vector3(0.0, 0.08, 0.0))
		bush_instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(bush_instances)

	var stone_mesh := SphereMesh.new()
	stone_mesh.radius = 0.09
	stone_mesh.height = 0.11
	stone_mesh.radial_segments = 8
	stone_mesh.rings = 4
	root.add_child(MapViewMeshBuilderPrimitives.multi_mesh("Stones", stone_mesh, stones, stone_colors, MapViewMaterials.role(&"stone"), Vector3(0.0, 0.03, 0.0)))
	return root


## A handful of tapered blades leaning out from a shared root: reads as a real
## grass clump instead of a cone, and gives the wind shader tips to move.
## UV.y runs root (0) to tip (1) for both sway weight and shading.


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


