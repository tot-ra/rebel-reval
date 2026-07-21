class_name MapViewMeshBuilderProps
extends RefCounted

const FishingBoatBuilder := preload("res://scripts/map/view3d/map_view_fishing_boat_builder.gd")
const MerchantBoatBuilder := preload("res://scripts/map/view3d/map_view_merchant_boat_builder.gd")

## Prop meshes and ground scatter.

const BARREL_HEIGHT := 0.72
const BARREL_BELLY_RADIUS := 0.29
const BARREL_HEAD_RADIUS := BARREL_BELLY_RADIUS * 0.78
const BARREL_HEAD_THICKNESS := 0.028
## Hoop height and radius follow the coopered body profile. Paired rings around
## the bilge and quarter sections make the silhouette read as a bound vessel,
## rather than as a cylinder with decorative stripes.
const BARREL_HOOP_PROFILE: Array[Vector2] = [
	Vector2(0.06, 0.88),
	Vector2(0.22, 0.965),
	Vector2(0.40, 0.998),
	Vector2(0.60, 0.998),
	Vector2(0.78, 0.965),
	Vector2(0.94, 0.88),
]


static func _add_barrel(parent: Node3D, node_name: String, position: Vector3, yaw: float) -> Node3D:
	var barrel := Node3D.new()
	barrel.name = node_name
	barrel.position = position
	barrel.rotation.y = yaw
	parent.add_child(barrel)

	var staves := MeshInstance3D.new()
	staves.name = "Staves"
	staves.mesh = MapViewMeshBuilderPrimitives.barrel_stave_mesh(BARREL_BELLY_RADIUS, BARREL_HEIGHT)
	staves.material_override = MapViewMeshBuilderPrimitives.role_material(&"wood")
	barrel.add_child(staves)

	# Barrel heads sit just below the stave ends, leaving a narrow protective lip.
	# That recess is especially important in the top-down camera, where it turns a
	# flat cylinder cap into a visibly assembled coopered vessel.
	for head_spec in [
		{"name": "BottomHead", "y": BARREL_HEAD_THICKNESS * 0.75},
		{"name": "TopHead", "y": BARREL_HEIGHT - BARREL_HEAD_THICKNESS * 0.75},
	]:
		var head := MeshInstance3D.new()
		head.name = head_spec["name"]
		head.mesh = MapViewMeshBuilderPrimitives.barrel_head_mesh(BARREL_HEAD_RADIUS, BARREL_HEAD_THICKNESS)
		head.position = Vector3(0.0, float(head_spec["y"]), 0.0)
		head.material_override = MapViewMeshBuilderPrimitives.role_material(&"wood")
		barrel.add_child(head)

	for hoop_index in BARREL_HOOP_PROFILE.size():
		var hoop_spec := BARREL_HOOP_PROFILE[hoop_index]
		var hoop := MeshInstance3D.new()
		hoop.name = "Hoop%d" % hoop_index
		hoop.mesh = MapViewMeshBuilderPrimitives.barrel_hoop_mesh(BARREL_BELLY_RADIUS * hoop_spec.y)
		hoop.position = Vector3(0.0, BARREL_HEIGHT * hoop_spec.x, 0.0)
		# A flattened torus gives each hoop the broad vertical face and thin radial
		# edge of forged strap iron without filling the barrel like a solid disc.
		hoop.scale.y = 1.55
		hoop.material_override = MapViewMeshBuilderPrimitives.role_material(&"metal")
		barrel.add_child(hoop)
	return barrel

static func build_prop(prop: Dictionary, cell_size: int, definition: MapDefinition = null) -> Node3D:
	var root := Node3D.new()
	root.name = "Prop_%s" % String(prop["id"])
	root.position = MapViewBridge.logic_to_world(prop["position"], cell_size)
	if prop.has("visual_offset_px"):
		var offset: Vector2 = prop["visual_offset_px"]
		var scale := MapViewBridge.world_scale(cell_size)
		root.position.x += offset.x * scale
		root.position.y -= offset.y * scale
	if prop["kind"] in MapTypes.BOAT_PROP_KINDS and _has_tall_footprint(prop):
		root.rotation.y = PI * 0.5
		root.position.y = -MapViewMeshBuilderConfig.WATER_RECESS + MapViewMeshBuilderConfig.WATER_SURFACE_LIFT
	if MapWallWalkAccess.is_access_prop(prop) or MapWallWalkAccess.is_platform_prop(prop):
		_add_wall_walk_access(root, prop, cell_size, definition)
		return root

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
			_add_barrel(root, "BarrelA", Vector3(-0.26, 0.0, 0.08), -0.12)
			_add_barrel(root, "BarrelB", Vector3(0.32, 0.0, -0.16), 0.19)
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
		MapTypes.PROP_KIND_CARGO_CRATES:
			_add_cargo_crates(root)
		MapTypes.PROP_KIND_TRADE_GOODS:
			_add_trade_goods(root)
		MapTypes.PROP_KIND_TIMBER_FENCE:
			_add_timber_fence(root, prop, cell_size)
		MapTypes.PROP_KIND_CATTLE:
			_add_cattle(root)
		MapTypes.PROP_KIND_SHEEP:
			_add_sheep(root)
		MapTypes.PROP_KIND_FISHING_BOAT:
			_add_fishing_boat(root, prop)
		MapTypes.PROP_KIND_MERCHANT_BOAT:
			_add_merchant_boat(root, prop)
		_:
			MapViewMeshBuilderPrimitives.box(root, "Marker", Vector3(0.5, 0.5, 0.5), Vector3(0.0, 0.25, 0.0), &"ink")
	return root


static func _has_tall_footprint(prop: Dictionary) -> bool:
	var footprint: Variant = prop.get("footprint")
	return footprint is Rect2 and footprint.size.y > footprint.size.x


static func _add_fishing_boat(root: Node3D, prop: Dictionary) -> void:
	FishingBoatBuilder.add_to(root)
	# Inshore boats are lively on chop; motion_scale 1 keeps them readable.
	_attach_boat_float(root, prop, 1.0)


static func _add_merchant_boat(root: Node3D, prop: Dictionary) -> void:
	MerchantBoatBuilder.add_to(root)
	# Heavy cogs damp the same wave field so they do not bounce like dinghies.
	_attach_boat_float(root, prop, 0.55)


static func _attach_boat_float(root: Node3D, prop: Dictionary, motion_scale: float) -> void:
	var floater = MapViewMeshBuilderConfig.BOAT_FLOAT_SCRIPT.new()
	floater.configure(root, motion_scale, String(prop.get("id", root.name)).hash())
	root.add_child(floater)


static func _add_cargo_crates(root: Node3D) -> void:
	_add_crate(root, "CrateLarge", Vector3(0.68, 0.62, 0.62), Vector3(-0.34, 0.31, 0.03))
	_add_crate(root, "CrateSmall", Vector3(0.5, 0.46, 0.5), Vector3(0.34, 0.23, -0.16))


static func _add_crate(root: Node3D, node_name: String, size: Vector3, position: Vector3) -> void:
	var crate := Node3D.new()
	crate.name = node_name
	crate.position = position
	root.add_child(crate)
	MapViewMeshBuilderPrimitives.box(crate, "Boards", size, Vector3.ZERO, &"wood")
	var brace_depth := size.z + 0.012
	MapViewMeshBuilderPrimitives.box(crate, "BraceTop", Vector3(size.x + 0.035, 0.075, brace_depth), Vector3(0.0, size.y * 0.33, 0.0), &"timber")
	MapViewMeshBuilderPrimitives.box(crate, "BraceBottom", Vector3(size.x + 0.035, 0.075, brace_depth), Vector3(0.0, -size.y * 0.33, 0.0), &"timber")
	MapViewMeshBuilderPrimitives.box(crate, "BraceVertical", Vector3(0.075, size.y, brace_depth), Vector3.ZERO, &"timber")


static func _add_trade_goods(root: Node3D) -> void:
	# Baltic cargo is represented generically as wool/flour sacks and bound cloth
	# bales, avoiding unsupported claims about exact goods on a given plot.
	MapViewMeshBuilderPrimitives.sphere(root, "SackA", 0.34, Vector3(-0.34, 0.34, 0.03), &"plaster", Vector3(0.72, 1.15, 0.78))
	MapViewMeshBuilderPrimitives.sphere(root, "SackB", 0.31, Vector3(0.14, 0.31, -0.16), &"plaster", Vector3(0.78, 1.12, 0.72))
	MapViewMeshBuilderPrimitives.box(root, "ClothBale", Vector3(0.72, 0.38, 0.54), Vector3(0.34, 0.19, 0.25), &"hay")
	MapViewMeshBuilderPrimitives.box(root, "BaleCordA", Vector3(0.07, 0.4, 0.56), Vector3(0.17, 0.2, 0.25), &"timber")
	MapViewMeshBuilderPrimitives.box(root, "BaleCordB", Vector3(0.07, 0.4, 0.56), Vector3(0.51, 0.2, 0.25), &"timber")


static func _add_timber_fence(root: Node3D, prop: Dictionary, cell_size: int) -> void:
	var footprint: Rect2 = prop.get("footprint", Rect2(Vector2.ZERO, Vector2(cell_size * 3, cell_size)))
	var scale := MapViewBridge.world_scale(cell_size)
	var horizontal := footprint.size.x >= footprint.size.y
	var length := maxf(maxf(footprint.size.x, footprint.size.y) * scale - 0.25, 0.75)
	var post_count := maxi(2, ceili(length / 1.4) + 1)
	for index in post_count:
		var along := lerpf(-length * 0.5, length * 0.5, float(index) / float(post_count - 1))
		var position := Vector3(along, 0.48, 0.0) if horizontal else Vector3(0.0, 0.48, along)
		MapViewMeshBuilderPrimitives.box(root, "Post%d" % index, Vector3(0.12, 0.96, 0.12), position, &"timber")
	for rail_index in 2:
		var rail_y := 0.32 + float(rail_index) * 0.34
		var rail_size := Vector3(length, 0.1, 0.1) if horizontal else Vector3(0.1, 0.1, length)
		MapViewMeshBuilderPrimitives.box(root, "Rail%d" % rail_index, rail_size, Vector3(0.0, rail_y, 0.0), &"wood")


static func _add_cattle(root: Node3D) -> void:
	MapViewMeshBuilderPrimitives.sphere(root, "Body", 0.62, Vector3(-0.1, 0.72, 0.0), &"wood", Vector3(1.45, 0.75, 0.68))
	MapViewMeshBuilderPrimitives.sphere(root, "Head", 0.34, Vector3(0.83, 0.78, 0.0), &"wood", Vector3(0.85, 0.95, 0.78))
	MapViewMeshBuilderPrimitives.box(root, "Muzzle", Vector3(0.28, 0.2, 0.34), Vector3(1.1, 0.69, 0.0), &"hay")
	for leg_spec in [["LegFL", 0.46, 0.27], ["LegFR", 0.46, -0.27], ["LegBL", -0.52, 0.27], ["LegBR", -0.52, -0.27]]:
		MapViewMeshBuilderPrimitives.box(root, leg_spec[0], Vector3(0.13, 0.7, 0.13), Vector3(leg_spec[1], 0.35, leg_spec[2]), &"timber")
	for horn_z in [-0.21, 0.21]:
		var horn_name := "HornL" if horn_z > 0.0 else "HornR"
		MapViewMeshBuilderPrimitives.cylinder(root, horn_name, 0.045, 0.34, Vector3(0.91, 1.04, horn_z), &"hay", true)


static func _add_sheep(root: Node3D) -> void:
	MapViewMeshBuilderPrimitives.sphere(root, "Fleece", 0.55, Vector3(-0.08, 0.58, 0.0), &"plaster", Vector3(1.28, 0.88, 0.82))
	MapViewMeshBuilderPrimitives.sphere(root, "Head", 0.27, Vector3(0.68, 0.57, 0.0), &"wood", Vector3(0.82, 1.0, 0.76))
	for leg_spec in [["LegFL", 0.3, 0.2], ["LegFR", 0.3, -0.2], ["LegBL", -0.42, 0.2], ["LegBR", -0.42, -0.2]]:
		MapViewMeshBuilderPrimitives.box(root, leg_spec[0], Vector3(0.09, 0.46, 0.09), Vector3(leg_spec[1], 0.23, leg_spec[2]), &"timber")


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

static func _add_wall_walk_access(
	root: Node3D,
	prop: Dictionary,
	cell_size: int,
	definition: MapDefinition
) -> void:
	var target := MapWallWalkAccess.target_height(definition, prop)
	if target <= 0.0:
		return
	var footprint: Rect2 = prop["footprint"]
	var scale := MapViewBridge.world_scale(cell_size)
	var size := footprint.size * scale
	if MapWallWalkAccess.is_platform_prop(prop):
		MapViewMeshBuilderPrimitives.box(
			root, "WallWalkPlatform", Vector3(size.x, 0.14, size.y),
			Vector3(0.0, target, 0.0), &"wood"
		)
		return

	var facing := Vector2(prop.get("facing", Vector2.RIGHT)).normalized()
	var along_x := absf(facing.x) >= absf(facing.y)
	var run := size.x if along_x else size.y
	var step_count := maxi(3, ceili(target / MapViewMeshBuilderConfig.WALL_WALK_ACCESS_STEP_RISE))
	var tread := run * MapViewMeshBuilderConfig.WALL_WALK_ACCESS_CLIMB_FRACTION / float(step_count)
	var width := minf(
		size.y if along_x else size.x,
		MapViewMeshBuilderConfig.WALL_WALK_ACCESS_STAIR_WIDTH
	)
	for step_index in step_count:
		var progress := (float(step_index) + 0.5) / float(step_count)
		var along := -run * 0.5 + progress * run * MapViewMeshBuilderConfig.WALL_WALK_ACCESS_CLIMB_FRACTION
		if (facing.x if along_x else facing.y) < 0.0:
			along = -along
		var center := Vector3(along, target * progress, 0.0) if along_x else Vector3(0.0, target * progress, along)
		var tread_size := Vector3(tread + 0.03, MapViewMeshBuilderConfig.WALL_WALK_ACCESS_TREAD_THICKNESS, width) if along_x else Vector3(width, MapViewMeshBuilderConfig.WALL_WALK_ACCESS_TREAD_THICKNESS, tread + 0.03)
		MapViewMeshBuilderPrimitives.box(root, "WallStairStep%d" % step_index, tread_size, center, &"wood")

	var landing_length := run * (1.0 - MapViewMeshBuilderConfig.WALL_WALK_ACCESS_CLIMB_FRACTION)
	var landing_along := run * 0.5 - landing_length * 0.5
	if (facing.x if along_x else facing.y) < 0.0:
		landing_along = -landing_along
	var landing_size := Vector3(landing_length, 0.14, width) if along_x else Vector3(width, 0.14, landing_length)
	var landing_position := Vector3(landing_along, target, 0.0) if along_x else Vector3(0.0, target, landing_along)
	MapViewMeshBuilderPrimitives.box(root, "WallStairLanding", landing_size, landing_position, &"wood")

	var direction := Vector3(facing.x, 0.0, facing.y)
	var cross := Vector3(-direction.z, 0.0, direction.x)
	var start := -direction * run * 0.5
	var finish := start + direction * run * MapViewMeshBuilderConfig.WALL_WALK_ACCESS_CLIMB_FRACTION + Vector3.UP * target
	for side in [-1.0, 1.0]:
		var offset := cross * width * 0.48
		_add_access_beam(root, "WallStairRail%d" % int(side), start + offset * side + Vector3.UP * 0.55, finish + offset * side + Vector3.UP * MapViewMeshBuilderConfig.WALL_WALK_ACCESS_RAIL_HEIGHT, 0.09)
		for progress in [0.0, 0.25, 0.5, 0.75, 1.0]:
			var foot: Vector3 = start.lerp(finish, progress) + offset * side
			_add_access_beam(root, "WallStairPost%d_%d" % [int(side), int(progress * 100.0)], foot, foot + Vector3.UP * MapViewMeshBuilderConfig.WALL_WALK_ACCESS_RAIL_HEIGHT, 0.08)


static func _add_access_beam(root: Node3D, name: String, from: Vector3, to: Vector3, thickness: float) -> void:
	var direction := to - from
	if direction.is_zero_approx():
		return
	var beam := MeshInstance3D.new()
	beam.name = name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(thickness, thickness, direction.length())
	beam.mesh = mesh
	beam.position = (from + to) * 0.5
	var up := Vector3.RIGHT if absf(direction.normalized().dot(Vector3.UP)) > 0.98 else Vector3.UP
	beam.basis = Basis.looking_at(direction.normalized(), up)
	beam.material_override = MapViewMaterials.role(&"timber")
	root.add_child(beam)
