class_name MapViewMeshBuilderPropModels
extends RefCounted

const DistrictLifeProps := preload("res://scripts/map/view3d/map_view_mesh_builder_district_life_props.gd")
const RuralLifeProps := preload("res://scripts/map/view3d/map_view_mesh_builder_rural_life_props.gd")
const BushMeshes := preload("res://scripts/map/view3d/map_view_bush_meshes.gd")
const BushSpecies := preload("res://scripts/map/view3d/map_view_bush_species.gd")
const FishingBoatBuilder := preload("res://scripts/map/view3d/map_view_fishing_boat_builder.gd")
const MerchantBoatBuilder := preload("res://scripts/map/view3d/map_view_merchant_boat_builder.gd")
const WallWalkAccessBuilder := preload("res://scripts/map/view3d/map_view_wall_walk_access_builder.gd")
const AnvilMeshes := preload("res://scripts/map/view3d/map_view_anvil_meshes.gd")
const HayMeshes := preload("res://scripts/map/view3d/map_view_hay_meshes.gd")
const MedievalAnimalModels := preload("res://scripts/map/view3d/map_view_medieval_animal_models.gd")
const MarketStallModels := preload("res://scripts/map/view3d/map_view_market_stall_models.gd")
const TableModels := preload("res://scripts/map/view3d/map_view_table_models.gd")
const MedievalLightingModels := preload("res://scripts/map/view3d/map_view_medieval_lighting_models.gd")
const DomesticHearthModels := preload("res://scripts/map/view3d/map_view_domestic_hearth_models.gd")
const KitchenwareModels := preload("res://scripts/map/view3d/map_view_kitchenware_models.gd")
const HouseholdClutterModels := preload("res://scripts/map/view3d/map_view_household_clutter_models.gd")
const ChestModels := preload("res://scripts/map/view3d/map_view_chest_models.gd")
const WellModels := preload("res://scripts/map/view3d/map_view_well_models.gd")
const StorageFurnitureModels := preload("res://scripts/map/view3d/map_view_storage_furniture_models.gd")
const MedievalHandToolModels := preload("res://scripts/map/view3d/map_view_medieval_hand_tool_models.gd")
const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")
# Runtime loading avoids a clean-clone bootstrap cycle where GDScript parses
# before Godot has registered the first GLB import.
const SMITHY_ANVIL_SCENE_PATH := "res://assets/props/forge/smithy_anvil.glb"
const SMITHY_ANVIL_PROP_ID := &"forge_anvil"
const SMITHY_FURNACE_SCENE_PATH := "res://assets/props/forge/smithy_furnace.glb"
const SMITHY_FURNACE_PROP_ID := &"forge_furnace"
const SMITHY_BELLOWS_SCENE_PATH := "res://assets/props/forge/smithy_bellows.glb"
const SMITHY_BELLOWS_PROP_ID := &"forge_bellows"
const SMITHY_CHAIR_SCENE_PATH := "res://assets/props/furniture/smithy_chair.glb"
const SMITHY_CHAIR_PROP_ID := &"work_chair"
## Seating in Kalev's dwelling shares the one authored chair GLB. Town Hall and
## other civic chairs stay on the neutral fallback until they get their own art.
const SMITHY_CHAIR_PROP_IDS: Array[StringName] = [
	SMITHY_CHAIR_PROP_ID,
	&"kitchen_stool",
	&"table_stool_west",
	&"table_stool_east",
]
const SMITHY_QUENCH_SCENE_PATH := "res://assets/props/forge/smithy_quench_bucket.glb"
const SMITHY_QUENCH_PROP_ID := &"quench"
const SMITHY_BED_SCENE_PATH := "res://assets/props/furniture/smithy_bed.glb"
const CartModels := preload("res://scripts/map/view3d/map_view_cart_models.gd")
const TradeGoodsModels := preload("res://scripts/map/view3d/map_view_trade_goods_models.gd")
const SMITHY_BED_PROP_ID := &"bed"
const SACRED_GROVE_ANCIENT_OAK_SCENE_PATH := "res://assets/props/environment/sacred_grove_ancient_oak.glb"

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
	# Wall-walk props consume `facing` as an access direction above, so furniture
	# yaw is resolved only after that early return.
	root.rotation.y += MapTypes.prop_facing_yaw(prop)

	match prop["kind"] as StringName:
		MapTypes.PROP_KIND_ANVIL:
			if StringName(prop["id"]) == SMITHY_ANVIL_PROP_ID:
				_add_smithy_anvil(root)
			else:
				_add_anvil_fallback(root)
		MapTypes.PROP_KIND_HAY_STACK:
			# Size is authored explicitly while the stable ID still varies only the
			# hand-built contour, so map edits never reshuffle nearby stack heights.
			var hay_size: StringName = prop.get("style_variant", HayMeshes.DEFAULT_SIZE)
			HayMeshes.add_rick(
				root,
				"HayRick",
				int(String(prop["id"]).hash()),
				Vector3.ZERO,
				Vector3.ONE,
				hay_size
			)
		MapTypes.PROP_KIND_CART:
			CartModels.add_model(root)
		MapTypes.PROP_KIND_WELL:
			WellModels.add_model(root)
		MapTypes.PROP_KIND_BARRELS:
			_add_barrel(root, "BarrelA", Vector3(-0.26, 0.0, 0.08), -0.12)
			_add_barrel(root, "BarrelB", Vector3(0.32, 0.0, -0.16), 0.19)
		MapTypes.PROP_KIND_FURNACE:
			if StringName(prop["id"]) == SMITHY_FURNACE_PROP_ID:
				_add_smithy_furnace(root)
			else:
				_add_furnace_fallback(root)
		MapTypes.PROP_KIND_BELLOWS:
			if StringName(prop["id"]) == SMITHY_BELLOWS_PROP_ID:
				_add_smithy_bellows(root)
			else:
				_add_bellows_fallback(root)
		MapTypes.PROP_KIND_BLACKSMITH_TONGS, MapTypes.PROP_KIND_BLACKSMITH_HAMMER, MapTypes.PROP_KIND_BLACKSMITH_PUNCH, MapTypes.PROP_KIND_PITCHFORK, MapTypes.PROP_KIND_SCYTHE, MapTypes.PROP_KIND_SICKLE, MapTypes.PROP_KIND_RAKE, MapTypes.PROP_KIND_WOODEN_SHOVEL:
			MedievalHandToolModels.add_model(root, prop["kind"])
		MapTypes.PROP_KIND_LEDGER:
			MapViewMeshBuilderPrimitives.box(root, "Stand", Vector3(0.16, 0.9, 0.16), Vector3(0.0, 0.45, 0.0), &"wood")
			MapViewMeshBuilderPrimitives.box(root, "Book", Vector3(0.52, 0.08, 0.42), Vector3(0.0, 0.95, 0.0), &"plaster")
		MapTypes.PROP_KIND_BED:
			if prop.get("id", &"") == SMITHY_BED_PROP_ID:
				_add_smithy_bed(root)
			else:
				_add_bed_fallback(root)
		MapTypes.PROP_KIND_CHEST:
			ChestModels.add_model(root, prop)
		MapTypes.PROP_KIND_TABLE:
			TableModels.add_model(root, prop)
		MapTypes.PROP_KIND_SHELF:
			StorageFurnitureModels.add_model(root, prop)
		MapTypes.PROP_KIND_QUENCH:
			if prop.get("id", &"") == SMITHY_QUENCH_PROP_ID:
				_add_smithy_quench_bucket(root)
			else:
				_add_quench_fallback(root)
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
			MarketStallModels.add_model(root, prop)
		MapTypes.PROP_KIND_HEARTH:
			DomesticHearthModels.add_model(root, prop)
		MapTypes.PROP_KIND_KITCHENWARE:
			KitchenwareModels.add_model(root, prop)
		MapTypes.PROP_KIND_HOUSEHOLD_CLUTTER:
			HouseholdClutterModels.add_model(root, prop)
		MapTypes.PROP_KIND_CHAIR:
			if StringName(prop.get("id", &"")) in SMITHY_CHAIR_PROP_IDS:
				_add_smithy_chair(root)
			else:
				_add_chair_fallback(root)
		MapTypes.PROP_KIND_CANDLE:
			MedievalLightingModels.add_model(root, prop)
		MapTypes.PROP_KIND_BUSH:
			_add_authored_bush(root, prop)
		MapTypes.PROP_KIND_TREE:
			_add_authored_tree(root, prop)
		MapTypes.PROP_KIND_CARGO_CRATES:
			_add_cargo_crates(root)
		MapTypes.PROP_KIND_TRADE_GOODS:
			_add_trade_goods(root, prop)
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
			if prop["kind"] in MapTypes.DISTRICT_LIFE_PROP_KINDS:
				DistrictLifeProps.add_to(root, prop["kind"], prop)
			elif prop["kind"] in MapTypes.RURAL_LIFE_PROP_KINDS:
				RuralLifeProps.add_to(root, prop["kind"])
			else:
				MapViewMeshBuilderPrimitives.box(root, "Marker", Vector3(0.5, 0.5, 0.5), Vector3(0.0, 0.25, 0.0), &"ink")
	return root


static func _add_smithy_bed(root: Node3D) -> void:
	# WHY: this close interior rest landmark needs period joinery and soft bedding,
	# while gameplay collision, navigation, and interaction remain owned by rrmap.
	var bed_scene := load(SMITHY_BED_SCENE_PATH) as PackedScene
	assert(bed_scene != null, "Smithy bed GLB must be imported before the map view is assembled")
	var bed := bed_scene.instantiate() as Node3D
	bed.name = "SmithyBedModel"
	root.add_child(bed)


static func _add_bed_fallback(root: Node3D) -> void:
	# Other maps can continue using the lightweight neutral bed until they receive
	# authored furniture matched to their location and status.
	MapViewMeshBuilderPrimitives.box(root, "Frame", Vector3(2.4, 0.38, 1.35), Vector3(0.0, 0.19, 0.0), &"wood")
	MapViewMeshBuilderPrimitives.box(root, "Mattress", Vector3(2.2, 0.16, 1.2), Vector3(0.0, 0.46, 0.0), &"plaster")
	MapViewMeshBuilderPrimitives.box(root, "Pillow", Vector3(0.42, 0.14, 0.72), Vector3(-0.82, 0.58, 0.0), &"hay")


static func _add_smithy_chair(root: Node3D) -> void:
	# WHY: the smithy's authored chair is a close, recurring interior prop. A
	# dedicated GLB gives it readable joinery while collision/navigation remain on
	# the immutable 2D map definition, just like every other view-only prop.
	var chair_scene := load(SMITHY_CHAIR_SCENE_PATH) as PackedScene
	assert(chair_scene != null, "Smithy chair GLB must be imported before the map view is assembled")
	var chair := chair_scene.instantiate() as Node3D
	chair.name = "SmithyChairModel"
	root.add_child(chair)


static func _add_chair_fallback(root: Node3D) -> void:
	# Town Hall chairs share the generic map kind but need a separate high-status
	# model later, so they deliberately keep the neutral procedural fallback.
	MapViewMeshBuilderPrimitives.box(root, "Seat", Vector3(0.5, 0.08, 0.45), Vector3(0.0, 0.42, 0.0), &"wood")
	MapViewMeshBuilderPrimitives.box(root, "Back", Vector3(0.48, 0.5, 0.06), Vector3(0.0, 0.72, -0.18), &"timber")
	MapViewMeshBuilderPrimitives.box(root, "LegFL", Vector3(0.06, 0.4, 0.06), Vector3(-0.18, 0.2, 0.14), &"timber")
	MapViewMeshBuilderPrimitives.box(root, "LegFR", Vector3(0.06, 0.4, 0.06), Vector3(0.18, 0.2, 0.14), &"timber")


static func _add_smithy_anvil(root: Node3D) -> void:
	# WHY: forge_anvil is the close, gameplay-critical smithy workstation. Its
	# authored GLB improves silhouette and materials while the immutable rrmap
	# footprint remains the sole collision/navigation authority.
	var anvil_scene := load(SMITHY_ANVIL_SCENE_PATH) as PackedScene
	assert(anvil_scene != null, "Smithy anvil GLB must be imported before the map view is assembled")
	var anvil := anvil_scene.instantiate() as Node3D
	anvil.name = "SmithyAnvilModel"
	root.add_child(anvil)


static func _add_anvil_fallback(root: Node3D) -> void:
	# Outdoor and future anvils keep the lightweight procedural model until they
	# receive location-specific art; this prevents smithy wear from leaking out.
	MapViewMeshBuilderPrimitives.cylinder(root, "Stump", 0.28, 0.42, Vector3(0.0, 0.21, 0.0), &"wood")
	MapViewMeshBuilderPrimitives.cylinder(root, "StumpBand", 0.295, 0.045, Vector3(0.0, 0.34, 0.0), &"metal")
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = AnvilMeshes.body_mesh()
	# Mesh local Y already includes the standing height above the stump crown.
	body.position = Vector3(0.0, 0.42, 0.0)
	body.material_override = MapViewMeshBuilderPrimitives.role_material(&"metal")
	root.add_child(body)


static func _add_smithy_furnace(root: Node3D) -> void:
	# WHY: forge_furnace is a close hero prop, but its rrmap footprint must remain
	# the sole collision/navigation authority. The GLB replaces only the masonry;
	# live embers, particles, and day/night fire lighting remain engine-driven.
	var furnace_scene := load(SMITHY_FURNACE_SCENE_PATH) as PackedScene
	assert(furnace_scene != null, "Smithy furnace GLB must be imported before the map view is assembled")
	var furnace := furnace_scene.instantiate() as Node3D
	furnace.name = "SmithyFurnaceModel"
	root.add_child(furnace)
	_add_furnace_ember_bed(root)
	_add_furnace_coal_bed(root)
	var flames := _add_furnace_flames(root)
	var particles := _add_furnace_fire_particles(root)
	var smoke := _add_furnace_smoke_particles(root)
	var forge_light := OmniLight3D.new()
	forge_light.name = "Omni"
	forge_light.position = Vector3(0.0, 0.7, 0.85)
	root.add_child(forge_light)
	var controller = MapViewMeshBuilderConfig.FORGE_FIRE_LIGHT_SCRIPT.new()
	controller.configure(forge_light, flames, particles, smoke)
	root.add_child(controller)


static func _add_furnace_fallback(root: Node3D) -> void:
	# Open-mouth masonry forge: rear bulk + cheeks + lintel leave a real cavity
	# so red coal and flame read from the working bay (not a solid black box).
	MapViewMeshBuilderPrimitives.box(root, "Mass", Vector3(2.4, 1.55, 1.35), Vector3(0.0, 0.78, -0.22), &"stone")
	MapViewMeshBuilderPrimitives.box(root, "LeftCheek", Vector3(0.38, 1.05, 1.05), Vector3(-0.92, 0.62, 0.52), &"stone")
	MapViewMeshBuilderPrimitives.box(root, "RightCheek", Vector3(0.38, 1.05, 1.05), Vector3(0.92, 0.62, 0.52), &"stone")
	MapViewMeshBuilderPrimitives.box(root, "Lintel", Vector3(1.55, 0.32, 1.05), Vector3(0.0, 1.3, 0.52), &"stone")
	MapViewMeshBuilderPrimitives.box(root, "HearthShelf", Vector3(1.55, 0.18, 1.0), Vector3(0.0, 0.16, 0.58), &"stone")
	MapViewMeshBuilderPrimitives.box(root, "Breast", Vector3(2.1, 0.5, 0.7), Vector3(0.0, 1.7, 0.18), &"stone")
	# Sooted cavity back sits deep inside the mouth, not as a front-facing plug.
	MapViewMeshBuilderPrimitives.box(root, "Firebox", Vector3(1.35, 0.85, 0.14), Vector3(0.0, 0.72, 0.05), &"ink")
	# Bright ember bed fills the hearth floor so the mouth always shows heat.
	_add_furnace_ember_bed(root)
	_add_furnace_coal_bed(root)
	var flames := _add_furnace_flames(root)
	var particles := _add_furnace_fire_particles(root)
	var smoke := _add_furnace_smoke_particles(root)
	# Tuyere stub on the left cheek - bellows nozzle aims here (axis along X).
	_add_axis_cylinder(root, "Tuyere", 0.06, 0.42, Vector3(-1.15, 0.48, 0.55), &"metal")
	# Flue seats into the breast and clears the interior ceiling plane.
	MapViewMeshBuilderPrimitives.add_chimney_stack(root, "Chimney", 0.58, 2.35, Vector3(0.0, 1.85, -0.35))

	var forge_light := OmniLight3D.new()
	forge_light.name = "Omni"
	forge_light.position = Vector3(0.0, 0.7, 0.85)
	root.add_child(forge_light)
	var controller = MapViewMeshBuilderConfig.FORGE_FIRE_LIGHT_SCRIPT.new()
	controller.configure(forge_light, flames, particles, smoke)
	root.add_child(controller)


static func _add_smithy_bellows(root: Node3D) -> void:
	# The authored mechanism supplies readable leather folds, joinery, tacks, and
	# a tapered nozzle without changing the declarative smithy prop footprint.
	var bellows_scene := load(SMITHY_BELLOWS_SCENE_PATH) as PackedScene
	assert(bellows_scene != null, "Smithy bellows GLB must be imported before the map view is assembled")
	var bellows := bellows_scene.instantiate() as Node3D
	bellows.name = "SmithyBellowsModel"
	root.add_child(bellows)


static func _add_bellows_fallback(root: Node3D) -> void:
	# Double-board leather bellows aimed +X toward the forge tuyere.
	MapViewMeshBuilderPrimitives.box(root, "Stand", Vector3(0.55, 0.12, 0.7), Vector3(0.0, 0.06, 0.0), &"timber")
	MapViewMeshBuilderPrimitives.box(root, "BoardBottom", Vector3(0.85, 0.06, 0.48), Vector3(0.05, 0.28, 0.0), &"wood")
	MapViewMeshBuilderPrimitives.box(root, "BoardTop", Vector3(0.78, 0.06, 0.42), Vector3(-0.02, 0.72, 0.0), &"wood")
	# Accordion leather folds between the boards.
	for index in 4:
		var t := float(index) / 3.0
		var y := lerpf(0.36, 0.64, t)
		var width := lerpf(0.82, 0.7, t)
		var depth := lerpf(0.46, 0.38, absf(t - 0.5) * 2.0)
		var fold := MeshInstance3D.new()
		fold.name = "Leather%d" % index
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width, 0.07, depth)
		fold.mesh = mesh
		fold.position = Vector3(0.02, y, 0.0)
		fold.material_override = MapViewMaterials.leather()
		root.add_child(fold)
	# Nozzle / pipe points into the furnace mouth from the west (axis along X).
	_add_axis_cylinder(root, "Nozzle", 0.055, 0.55, Vector3(0.55, 0.42, 0.0), &"metal")
	_add_axis_cylinder(root, "NozzleTip", 0.04, 0.18, Vector3(0.88, 0.42, 0.0), &"metal")
	# Pump lever on the top board.
	MapViewMeshBuilderPrimitives.box(root, "Lever", Vector3(0.08, 0.55, 0.08), Vector3(-0.28, 1.0, 0.0), &"timber")
	MapViewMeshBuilderPrimitives.box(root, "Handle", Vector3(0.28, 0.06, 0.08), Vector3(-0.38, 1.28, 0.0), &"wood")
	MapViewMeshBuilderPrimitives.cylinder(root, "Hinge", 0.04, 0.5, Vector3(-0.4, 0.5, 0.0), &"metal")


static func _add_quench_fallback(root: Node3D) -> void:
	MapViewMeshBuilderPrimitives.cylinder(root, "Bucket", 0.3, 0.46, Vector3(0.0, 0.23, 0.0), &"wood")
	MapViewMeshBuilderPrimitives.cylinder(root, "Water", 0.24, 0.05, Vector3(0.0, 0.44, 0.0), &"water_highlight")


static func _add_smithy_quench_bucket(root: Node3D) -> void:
	# WHY: the smithy's close workstation needs a visibly hollow, metal quench
	# vessel, while generic map buckets retain the cheap procedural fallback.
	# The rrmap footprint remains the sole collision/navigation authority.
	var bucket_scene := load(SMITHY_QUENCH_SCENE_PATH) as PackedScene
	assert(bucket_scene != null, "Smithy quench bucket GLB must be imported before the map view is assembled")
	var bucket := bucket_scene.instantiate() as Node3D
	bucket.name = "SmithyQuenchBucketModel"
	root.add_child(bucket)


static func _add_axis_cylinder(
	root: Node3D,
	node_name: String,
	radius: float,
	length: float,
	position: Vector3,
	role: StringName
) -> void:
	# Primitive side_axis lies along Z; forge tuyere/nozzle need the X axis.
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	instance.mesh = mesh
	instance.position = position
	instance.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	instance.material_override = MapViewMeshBuilderPrimitives.role_material(role)
	root.add_child(instance)


static func _add_furnace_ember_bed(root: Node3D) -> void:
	var bed := MeshInstance3D.new()
	bed.name = "EmberBed"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.05, 0.1, 0.7)
	bed.mesh = mesh
	bed.position = Vector3(0.0, 0.3, 0.58)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color8(180, 48, 18)
	material.emission_enabled = true
	material.emission = Color8(255, 90, 28)
	material.emission_energy_multiplier = 3.4
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bed.material_override = material
	bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bed)


static func _add_furnace_coal_bed(root: Node3D) -> void:
	var cold := MapViewMaterials.charcoal()
	var hot := MapViewMaterials.hot_coal()
	for spec in [
		{"name": "CoalA", "radius": 0.17, "pos": Vector3(-0.28, 0.36, 0.68), "scale": Vector3(1.35, 0.55, 1.15), "hot": true},
		{"name": "CoalB", "radius": 0.15, "pos": Vector3(0.24, 0.34, 0.72), "scale": Vector3(1.25, 0.52, 1.1), "hot": true},
		{"name": "CoalC", "radius": 0.14, "pos": Vector3(-0.02, 0.38, 0.55), "scale": Vector3(1.4, 0.5, 1.2), "hot": true},
		{"name": "CoalD", "radius": 0.12, "pos": Vector3(0.36, 0.32, 0.52), "scale": Vector3(1.15, 0.45, 1.0), "hot": false},
		{"name": "CoalE", "radius": 0.11, "pos": Vector3(-0.4, 0.32, 0.5), "scale": Vector3(1.1, 0.42, 0.95), "hot": false},
		{"name": "CoalF", "radius": 0.10, "pos": Vector3(0.08, 0.42, 0.7), "scale": Vector3(1.1, 0.42, 1.05), "hot": true},
		{"name": "CoalG", "radius": 0.09, "pos": Vector3(-0.14, 0.4, 0.74), "scale": Vector3(1.05, 0.38, 1.0), "hot": true},
		{"name": "CoalH", "radius": 0.08, "pos": Vector3(0.18, 0.4, 0.48), "scale": Vector3(1.0, 0.36, 0.95), "hot": true},
	]:
		var lump := MeshInstance3D.new()
		lump.name = spec["name"]
		var mesh := SphereMesh.new()
		mesh.radius = spec["radius"]
		mesh.height = spec["radius"] * 2.0
		mesh.radial_segments = 7
		mesh.rings = 3
		lump.mesh = mesh
		lump.position = spec["pos"]
		lump.scale = spec["scale"]
		lump.material_override = hot if spec["hot"] else cold
		lump.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(lump)


static func _add_furnace_flames(root: Node3D) -> Node3D:
	# WHY: solid pulsing spheres read as plastic blobs, not fire. Overlapping
	# billboard flame tongues (the CandleFlame3D vocabulary, hearth scale) give
	# turbulent licks, a cooling color ramp, and additive glow instead.
	var flames = MapViewMeshBuilderConfig.FORGE_FLAME_SCRIPT.new()
	flames.position = Vector3(0.0, 0.36, 0.6)
	flames.configure()
	root.add_child(flames)
	return flames


static func _add_furnace_fire_particles(root: Node3D) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "FireSparks"
	particles.position = Vector3(0.0, 0.48, 0.62)
	particles.amount = 28
	particles.lifetime = 1.05
	particles.preprocess = 0.55
	particles.explosiveness = 0.08
	particles.randomness = 0.4
	particles.visibility_aabb = AABB(Vector3(-0.9, -0.2, -0.7), Vector3(1.8, 2.0, 1.4))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.4, 0.06, 0.22)
	process.direction = Vector3.UP
	process.spread = 28.0
	process.initial_velocity_min = 0.55
	process.initial_velocity_max = 1.45
	process.gravity = Vector3(0.0, 0.45, 0.0)
	process.damping_min = 0.35
	process.damping_max = 1.0
	process.angular_velocity_min = -60.0
	process.angular_velocity_max = 60.0
	process.scale_min = 0.025
	process.scale_max = 0.06
	# WHY: sparks cool as they rise. A white-hot birth fading through orange to
	# dead red plus shrink-over-life sells ember trajectories, not orange dots.
	var spark_scale := Curve.new()
	spark_scale.add_point(Vector2(0.0, 1.0))
	spark_scale.add_point(Vector2(0.55, 0.7))
	spark_scale.add_point(Vector2(1.0, 0.15))
	var spark_scale_texture := CurveTexture.new()
	spark_scale_texture.curve = spark_scale
	process.scale_curve = spark_scale_texture
	var spark_ramp := Gradient.new()
	spark_ramp.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	spark_ramp.set_color(1, Color(0.6, 0.08, 0.0, 0.0))
	spark_ramp.add_point(0.4, Color(1.0, 0.6, 0.15, 0.9))
	spark_ramp.add_point(0.75, Color(0.9, 0.25, 0.02, 0.5))
	var spark_ramp_texture := GradientTexture1D.new()
	spark_ramp_texture.gradient = spark_ramp
	process.color_ramp = spark_ramp_texture
	particles.process_material = process
	var draw := SphereMesh.new()
	draw.radius = 0.5
	draw.height = 1.0
	draw.radial_segments = 6
	draw.rings = 3
	particles.draw_pass_1 = draw
	var spark_mat := StandardMaterial3D.new()
	spark_mat.vertex_color_use_as_albedo = true
	spark_mat.albedo_color = Color.WHITE
	spark_mat.emission_enabled = true
	spark_mat.emission = Color8(255, 140, 40)
	spark_mat.emission_energy_multiplier = 2.4
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particles.material_override = spark_mat
	root.add_child(particles)
	return particles


static func _add_furnace_smoke_particles(root: Node3D) -> GPUParticles3D:
	# Thin soot stream above the mouth: without it the fire looks weightless.
	# Soft radial puffs grow, gray out, and dissolve as they clear the lintel.
	var particles := GPUParticles3D.new()
	particles.name = "FireSmoke"
	particles.position = Vector3(0.0, 0.95, 0.55)
	particles.amount = 12
	particles.lifetime = 2.4
	particles.preprocess = 1.6
	particles.explosiveness = 0.0
	particles.randomness = 0.5
	particles.local_coords = true
	particles.visibility_aabb = AABB(Vector3(-1.0, -0.4, -0.8), Vector3(2.0, 3.2, 1.6))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.28, 0.05, 0.14)
	process.direction = Vector3.UP
	process.spread = 10.0
	process.initial_velocity_min = 0.35
	process.initial_velocity_max = 0.6
	process.gravity = Vector3(0.0, 0.12, 0.0)
	process.damping_min = 0.05
	process.damping_max = 0.2
	process.angular_velocity_min = -18.0
	process.angular_velocity_max = 18.0
	process.scale_min = 0.55
	process.scale_max = 0.85
	var smoke_scale := Curve.new()
	smoke_scale.add_point(Vector2(0.0, 0.3))
	smoke_scale.add_point(Vector2(0.4, 0.9))
	smoke_scale.add_point(Vector2(1.0, 1.7))
	var smoke_scale_texture := CurveTexture.new()
	smoke_scale_texture.curve = smoke_scale
	process.scale_curve = smoke_scale_texture
	# Puffs darken and thin over life so the column dissolves instead of popping.
	var smoke_ramp := Gradient.new()
	smoke_ramp.set_color(0, Color(0.32, 0.28, 0.25, 0.0))
	smoke_ramp.set_color(1, Color(0.16, 0.15, 0.14, 0.0))
	smoke_ramp.add_point(0.25, Color(0.3, 0.27, 0.24, 0.3))
	smoke_ramp.add_point(0.65, Color(0.22, 0.2, 0.19, 0.22))
	var smoke_ramp_texture := GradientTexture1D.new()
	smoke_ramp_texture.gradient = smoke_ramp
	process.color_ramp = smoke_ramp_texture
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	particles.draw_pass_1 = quad
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mat.vertex_color_use_as_albedo = true
	# Procedural radial falloff keeps the puff soft without a texture asset.
	var falloff := Gradient.new()
	falloff.set_color(0, Color.WHITE)
	falloff.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	falloff.add_point(0.55, Color(1.0, 1.0, 1.0, 0.55))
	var falloff_texture := GradientTexture2D.new()
	falloff_texture.gradient = falloff
	falloff_texture.fill = GradientTexture2D.FILL_RADIAL
	falloff_texture.fill_from = Vector2(0.5, 0.5)
	falloff_texture.fill_to = Vector2(1.0, 0.5)
	smoke_mat.albedo_texture = falloff_texture
	smoke_mat.albedo_color = Color.WHITE
	smoke_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smoke_mat.billboard_keep_scale = true
	particles.material_override = smoke_mat
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(particles)
	return particles


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


static func _add_trade_goods(root: Node3D, prop: Dictionary) -> void:
	# WHY: named harbor and market props need four distinct Hanseatic cargo reads
	# instead of one repeated sack-and-bale silhouette at gameplay distance.
	TradeGoodsModels.add_model(root, StringName(prop.get("id", &"trade_goods")))


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
	MedievalAnimalModels.add_model(root, MammalSpecies.SPECIES_COW)


static func _add_sheep(root: Node3D) -> void:
	MedievalAnimalModels.add_model(root, MammalSpecies.SPECIES_SHEEP)


static func _add_horse(root: Node3D) -> void:
	MedievalAnimalModels.add_model(root, MammalSpecies.SPECIES_HORSE)


## Layered decorative vegetation and ground clutter. Textured ground cover carries
## most of the grass; sparse small/large tufts, shrubs, and trees add silhouette
## variation without turning every green cell into an object field.

const ANCIENT_TREE_PRIMITIVE := &"ancient_tree"


static func _add_authored_tree(root: Node3D, prop: Dictionary) -> void:
	# Sacred Grove hingepuu and any other ancient_tree prop use the landmark mesh.
	if prop.get("primitive", &"") == ANCIENT_TREE_PRIMITIVE:
		_add_ancient_oak(root)
		return
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


static func _add_authored_bush(root: Node3D, prop: Dictionary) -> void:
	var variant: StringName = prop.get("style_variant", &"")
	if variant.is_empty():
		variant = TerrainVegetation.VARIANT_BUSH_SCRUB
	var parsed: Dictionary = BushSpecies.parse_variant(variant)
	var species: StringName = parsed.get(
		"species",
		BushSpecies.pick_species(BushSpecies.weights_for_variant(variant), 0.41)
	)
	var scale_range := BushSpecies.scale_range(species)
	var uniform := lerpf(scale_range.x, scale_range.y, 0.5)
	var bush := MeshInstance3D.new()
	bush.name = "Bush"
	bush.mesh = BushMeshes.mesh_for(species)
	bush.scale = Vector3(uniform, uniform, uniform)
	var material_kind: StringName = BushSpecies.material_kind(species)
	bush.material_override = (
		MapViewMaterials.canopy(material_kind)
		if material_kind == &"leaf"
		else MapViewMaterials.foliage_tuft()
	)
	bush.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bush)
	root.set_meta(&"bush_species", species)


static func _add_ancient_oak(root: Node3D) -> void:
	# WHY: the hingepuu is the grove's close hero landmark. Its custom GLB carries
	# continuous tapered boughs, buttress roots, shaped leaves, bark relief, and
	# weathering. Collision/navigation remain owned by the unchanged rrmap.
	var oak_scene := load(SACRED_GROVE_ANCIENT_OAK_SCENE_PATH) as PackedScene
	assert(oak_scene != null, "Sacred Grove ancient oak GLB must be imported before the map view is assembled")
	var oak := oak_scene.instantiate() as Node3D
	oak.name = "SacredGroveAncientOakModel"
	root.add_child(oak)
	root.set_meta(&"tree_species", MapViewTreeSpecies.SPECIES_OAK)
	root.set_meta(&"tree_size", MapViewTreeSpecies.SIZE_LARGE)
	root.set_meta(&"tree_model", &"sacred_grove_ancient_oak_glb")
	root.set_meta(&"tree_asset_path", SACRED_GROVE_ANCIENT_OAK_SCENE_PATH)
