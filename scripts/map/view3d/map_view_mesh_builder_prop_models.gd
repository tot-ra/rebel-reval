class_name MapViewMeshBuilderPropModels
extends RefCounted

const FishingBoatBuilder := preload("res://scripts/map/view3d/map_view_fishing_boat_builder.gd")
const MerchantBoatBuilder := preload("res://scripts/map/view3d/map_view_merchant_boat_builder.gd")
const WallWalkAccessBuilder := preload("res://scripts/map/view3d/map_view_wall_walk_access_builder.gd")

## Individual authored prop meshes.

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
		WallWalkAccessBuilder.add_to(root, prop, cell_size, definition)
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
		MapTypes.PROP_KIND_TREE:
			_add_authored_tree(root, prop)
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
		MapTypes.PROP_KIND_HORSE:
			_add_horse(root)
		MapTypes.PROP_KIND_FISHING_BOAT:
			_add_fishing_boat(root, prop)
		MapTypes.PROP_KIND_MERCHANT_BOAT:
			_add_merchant_boat(root, prop)
		MapTypes.PROP_KIND_BANNER:
			_add_banner(root, prop)
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
	# Harbor cogs default to Hanseatic cloth when the map omits faction=.
	var faction := FactionHeraldry.resolve(prop)
	if String(faction).is_empty():
		faction = FactionHeraldry.HANSEATIC
	MerchantBoatBuilder.add_to(root, faction)
	# Heavy cogs damp the same wave field so they do not bounce like dinghies.
	_attach_boat_float(root, prop, 0.55)


static func _add_banner(root: Node3D, prop: Dictionary) -> void:
	var faction := FactionHeraldry.resolve(prop)
	if not FactionHeraldry.shows_flag(faction):
		# No bare poles: faction-less / Vitalienbrüder props stay empty footprints.
		return
	# WHY: freestanding masts read as a forest of empty sticks from the dimetric
	# camera. Courtyard cloth hangs from a short wall arm instead.
	MapViewMeshBuilderPrimitives.box(
		root, "BannerMount", Vector3(0.22, 0.14, 0.22), Vector3(0.0, 2.05, 0.0), &"stone"
	)
	MapViewMeshBuilderPrimitives.box(
		root, "BannerArm", Vector3(0.62, 0.055, 0.055), Vector3(0.28, 2.05, 0.0), &"timber"
	)
	var cloth := MeshInstance3D.new()
	cloth.name = "BannerCloth"
	cloth.mesh = FactionHeraldry.banner_mesh(faction, 0.62, 0.95)
	cloth.position = Vector3(0.32, 1.5, 0.0)
	cloth.set_meta(&"faction", faction)
	cloth.material_override = MapViewMaterials.flag_cloth()
	cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(cloth)


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


static func _add_horse(root: Node3D) -> void:
	# A restrained pack-horse silhouette is enough for rural traffic; tack and load
	# distinguish it from cattle without introducing an ambient actor dependency.
	MapViewMeshBuilderPrimitives.sphere(root, "Body", 0.58, Vector3(-0.1, 0.93, 0.0), &"wood", Vector3(1.55, 0.68, 0.62))
	MapViewMeshBuilderPrimitives.box(root, "Neck", Vector3(0.38, 0.82, 0.34), Vector3(0.66, 1.22, 0.0), &"wood")
	MapViewMeshBuilderPrimitives.sphere(root, "Head", 0.3, Vector3(0.89, 1.53, 0.0), &"wood", Vector3(1.2, 0.72, 0.72))
	MapViewMeshBuilderPrimitives.box(root, "Muzzle", Vector3(0.36, 0.2, 0.3), Vector3(1.15, 1.47, 0.0), &"timber")
	for leg_spec in [["LegFL", 0.43, 0.22], ["LegFR", 0.43, -0.22], ["LegBL", -0.56, 0.22], ["LegBR", -0.56, -0.22]]:
		MapViewMeshBuilderPrimitives.box(root, leg_spec[0], Vector3(0.1, 0.9, 0.1), Vector3(leg_spec[1], 0.45, leg_spec[2]), &"timber")
	MapViewMeshBuilderPrimitives.box(root, "PackBlanket", Vector3(0.78, 0.09, 0.78), Vector3(-0.05, 1.42, 0.0), &"hay")
	MapViewMeshBuilderPrimitives.box(root, "PackLeft", Vector3(0.46, 0.42, 0.26), Vector3(-0.12, 1.28, 0.47), &"wood")
	MapViewMeshBuilderPrimitives.box(root, "PackRight", Vector3(0.46, 0.42, 0.26), Vector3(-0.12, 1.28, -0.47), &"wood")


## Layered decorative vegetation and ground clutter. Textured ground cover carries
## most of the grass; sparse small/large tufts, shrubs, and trees add silhouette
## variation without turning every green cell into an object field.

static func _add_authored_tree(root: Node3D, prop: Dictionary) -> void:
	var variant: StringName = prop.get("style_variant", &"")
	if variant.is_empty():
		variant = TerrainVegetation.VARIANT_TREE_MIXED
	var parsed: Dictionary = MapViewTreeSpecies.parse_variant(variant)
	var species: StringName = parsed.get(
		"species",
		MapViewTreeSpecies.pick_species(MapViewTreeSpecies.weights_for_variant(variant), 0.37)
	)
	var size_class: StringName = parsed.get("size", MapViewTreeSpecies.SIZE_MEDIUM)
	var parts := String(variant).split(".")
	if parts.size() < 3:
		size_class = MapViewTreeSpecies.SIZE_MEDIUM
	var scale := MapViewTreeSpecies.instance_scale(size_class, 0.5)
	var bark_kind := MapViewTreeSpecies.bark_kind_for(species)

	var trunk := MeshInstance3D.new()
	trunk.name = "Trunk"
	trunk.mesh = MapViewMeshBuilderPrimitives.tree_wood_mesh(species)
	trunk.scale = scale
	trunk.material_override = MapViewMaterials.bark(bark_kind)
	root.add_child(trunk)

	var canopy := MeshInstance3D.new()
	canopy.name = "Canopy"
	canopy.mesh = MapViewMeshBuilderPrimitives.tree_canopy_mesh(species)
	canopy.scale = scale
	canopy.material_override = MapViewMaterials.canopy(MapViewTreeSpecies.canopy_material_kind(species))
	root.add_child(canopy)

	var fruit_mesh := MapViewMeshBuilderPrimitives.tree_fruit_mesh(species)
	if fruit_mesh != null:
		var fruit := MeshInstance3D.new()
		fruit.name = "Fruit"
		fruit.mesh = fruit_mesh
		fruit.scale = scale
		fruit.material_override = MapViewMaterials.tree_fruit()
		fruit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(fruit)
	root.set_meta(&"tree_species", species)
	root.set_meta(&"tree_size", size_class)
