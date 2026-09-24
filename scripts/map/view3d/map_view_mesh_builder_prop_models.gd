class_name MapViewMeshBuilderPropModels
extends RefCounted

const DistrictLifeProps := preload(
	"res://scripts/map/view3d/map_view_mesh_builder_district_life_props.gd"
)
const RuralLifeProps := preload(
	"res://scripts/map/view3d/map_view_mesh_builder_rural_life_props.gd"
)
const BushMeshes := preload("res://scripts/map/view3d/map_view_bush_meshes.gd")
const BushSpecies := preload("res://scripts/map/view3d/map_view_bush_species.gd")
const FishingBoatBuilder := preload("res://scripts/map/view3d/map_view_fishing_boat_builder.gd")
const MerchantBoatBuilder := preload("res://scripts/map/view3d/map_view_merchant_boat_builder.gd")
const WallWalkAccessBuilder := preload(
	"res://scripts/map/view3d/map_view_wall_walk_access_builder.gd"
)
const HayMeshes := preload("res://scripts/map/view3d/map_view_hay_meshes.gd")
const SmithyPropBuilder := preload("res://scripts/map/view3d/map_view_smithy_prop_builder.gd")
const MedievalAnimalModels := preload("res://scripts/map/view3d/map_view_medieval_animal_models.gd")
const MarketStallModels := preload("res://scripts/map/view3d/map_view_market_stall_models.gd")
const TableModels := preload("res://scripts/map/view3d/map_view_table_models.gd")
const MedievalLightingModels := preload(
	"res://scripts/map/view3d/map_view_medieval_lighting_models.gd"
)
const DomesticHearthModels := preload("res://scripts/map/view3d/map_view_domestic_hearth_models.gd")
const KitchenwareModels := preload("res://scripts/map/view3d/map_view_kitchenware_models.gd")
const HouseholdClutterModels := preload(
	"res://scripts/map/view3d/map_view_household_clutter_models.gd"
)
const ChestModels := preload("res://scripts/map/view3d/map_view_chest_models.gd")
const WellModels := preload("res://scripts/map/view3d/map_view_well_models.gd")
const StorageFurnitureModels := preload(
	"res://scripts/map/view3d/map_view_storage_furniture_models.gd"
)
const MedievalHandToolModels := preload(
	"res://scripts/map/view3d/map_view_medieval_hand_tool_models.gd"
)
const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")
const CartModels := preload("res://scripts/map/view3d/map_view_cart_models.gd")
const TradeGoodsModels := preload("res://scripts/map/view3d/map_view_trade_goods_models.gd")
# gdlint: ignore=max-line-length
const SACRED_GROVE_ANCIENT_OAK_SCENE_PATH := "res://assets/props/environment/sacred_grove_ancient_oak.glb"
# gdlint: ignore=max-line-length
const PLOT_DRESSING_SCENE_PATH := "res://assets/props/architecture/houses/plot_dressing/plot_dressing.glb"
const PLOT_DRESSING_COMPONENTS: Dictionary = {
	MapTypes.PROP_KIND_CELLAR_NECK: &"CellarNeck",
	MapTypes.PROP_KIND_PLOT_WALL: &"PlotWall",
	MapTypes.PROP_KIND_WATTLE_FENCE: &"WattleFence",
	MapTypes.PROP_KIND_YARD_GATE: &"YardGate",
	MapTypes.PROP_KIND_PRIVY: &"Privy",
	MapTypes.PROP_KIND_WELL_SWEEP: &"WellSweep",
	MapTypes.PROP_KIND_SERVANT_LEAN_TO: &"ServantLeanTo",
	MapTypes.PROP_KIND_HOIST_BEAM: &"HoistBeam",
	MapTypes.PROP_KIND_LOADING_HATCH: &"LoadingHatch",
}
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
const ANCIENT_TREE_PRIMITIVE := &"ancient_tree"

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
		head.mesh = MapViewMeshBuilderPrimitives.barrel_head_mesh(
			BARREL_HEAD_RADIUS, BARREL_HEAD_THICKNESS
		)
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


static func build_prop(
	prop: Dictionary, cell_size: int, definition: MapDefinition = null
) -> Node3D:
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
		root.position.y = (
			-MapViewMeshBuilderConfig.WATER_RECESS + MapViewMeshBuilderConfig.WATER_SURFACE_LIFT
		)
	if MapWallWalkAccess.is_access_prop(prop) or MapWallWalkAccess.is_platform_prop(prop):
		WallWalkAccessBuilder.add_to(root, prop, cell_size, definition)
		return root
	# Wall-walk props consume `facing` as an access direction above, so furniture
	# yaw is resolved only after that early return.
	root.rotation.y += MapTypes.prop_facing_yaw(prop)

	match prop["kind"] as StringName:
		MapTypes.PROP_KIND_ANVIL:
			if StringName(prop["id"]) == SmithyPropBuilder.ANVIL_PROP_ID:
				SmithyPropBuilder.add_smithy_anvil(root)
			else:
				SmithyPropBuilder.add_anvil_fallback(root)
		MapTypes.PROP_KIND_HAY_STACK:
			# Size is authored explicitly while the stable ID still varies only the
			# hand-built contour, so map edits never reshuffle nearby stack heights.
			var hay_size: StringName = prop.get("style_variant", HayMeshes.DEFAULT_SIZE)
			HayMeshes.add_rick(
				root, "HayRick", int(String(prop["id"]).hash()), Vector3.ZERO, Vector3.ONE, hay_size
			)
		MapTypes.PROP_KIND_CART:
			CartModels.add_model(root)
		MapTypes.PROP_KIND_WELL:
			WellModels.add_model(root)
		MapTypes.PROP_KIND_BARRELS:
			_add_barrel(root, "BarrelA", Vector3(-0.26, 0.0, 0.08), -0.12)
			_add_barrel(root, "BarrelB", Vector3(0.32, 0.0, -0.16), 0.19)
		MapTypes.PROP_KIND_FURNACE:
			if StringName(prop["id"]) == SmithyPropBuilder.FURNACE_PROP_ID:
				SmithyPropBuilder.add_smithy_furnace(root)
			else:
				SmithyPropBuilder.add_furnace_fallback(root)
		MapTypes.PROP_KIND_BELLOWS:
			if StringName(prop["id"]) == SmithyPropBuilder.BELLOWS_PROP_ID:
				SmithyPropBuilder.add_smithy_bellows(root)
			else:
				SmithyPropBuilder.add_bellows_fallback(root)
		# gdlint: ignore=max-line-length
		MapTypes.PROP_KIND_BLACKSMITH_TONGS, MapTypes.PROP_KIND_BLACKSMITH_HAMMER, MapTypes.PROP_KIND_BLACKSMITH_PUNCH, MapTypes.PROP_KIND_PITCHFORK, MapTypes.PROP_KIND_SCYTHE, MapTypes.PROP_KIND_SICKLE, MapTypes.PROP_KIND_RAKE, MapTypes.PROP_KIND_WOODEN_SHOVEL:
			MedievalHandToolModels.add_model(root, prop["kind"])
		MapTypes.PROP_KIND_LEDGER:
			MapViewMeshBuilderPrimitives.box(
				root, "Stand", Vector3(0.16, 0.9, 0.16), Vector3(0.0, 0.45, 0.0), &"wood"
			)
			MapViewMeshBuilderPrimitives.box(
				root, "Book", Vector3(0.52, 0.08, 0.42), Vector3(0.0, 0.95, 0.0), &"plaster"
			)
		MapTypes.PROP_KIND_BED:
			if prop.get("id", &"") == SmithyPropBuilder.BED_PROP_ID:
				SmithyPropBuilder.add_smithy_bed(root)
			else:
				SmithyPropBuilder.add_bed_fallback(root)
		MapTypes.PROP_KIND_CHEST:
			ChestModels.add_model(root, prop)
		MapTypes.PROP_KIND_TABLE:
			TableModels.add_model(root, prop)
		MapTypes.PROP_KIND_SHELF:
			StorageFurnitureModels.add_model(root, prop)
		MapTypes.PROP_KIND_QUENCH:
			if prop.get("id", &"") == SmithyPropBuilder.QUENCH_PROP_ID:
				SmithyPropBuilder.add_smithy_quench_bucket(root)
			else:
				SmithyPropBuilder.add_quench_fallback(root)
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
			if StringName(prop.get("id", &"")) in SmithyPropBuilder.CHAIR_PROP_IDS:
				SmithyPropBuilder.add_smithy_chair(root)
			else:
				SmithyPropBuilder.add_chair_fallback(root)
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
			if PLOT_DRESSING_COMPONENTS.has(prop["kind"]):
				_add_plot_dressing_component(root, prop["kind"])
			elif prop["kind"] in MapTypes.DISTRICT_LIFE_PROP_KINDS:
				DistrictLifeProps.add_to(root, prop["kind"], prop)
			elif prop["kind"] in MapTypes.RURAL_LIFE_PROP_KINDS:
				RuralLifeProps.add_to(root, prop["kind"])
			else:
				MapViewMeshBuilderPrimitives.box(
					root, "Marker", Vector3(0.5, 0.5, 0.5), Vector3(0.0, 0.25, 0.0), &"ink"
				)
	return root


static func _add_plot_dressing_component(root: Node3D, kind: StringName) -> void:
	var scene := load(PLOT_DRESSING_SCENE_PATH) as PackedScene
	assert(scene != null, "Plot dressing GLB must be imported before map assembly")
	var component_name: StringName = PLOT_DRESSING_COMPONENTS.get(kind, &"")
	assert(not component_name.is_empty(), "Unknown plot dressing component: %s" % String(kind))
	var source := scene.instantiate() as Node3D
	assert(source != null, "Plot dressing GLB root must be Node3D")
	# WHY: Blender exports the component library under a named kit root. Search below
	# that wrapper so the renderer remains stable if Godot preserves the import root.
	var component := source.find_child(String(component_name), true, false) as Node3D
	assert(component != null, "Plot dressing GLB is missing component: %s" % String(component_name))
	var model := component.duplicate() as Node3D
	assert(
		model != null,
		"Plot dressing component must duplicate as Node3D: %s" % String(component_name)
	)
	model.name = "%sModel" % String(component_name)
	root.add_child(model)
	source.free()


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
	# WHY: the old +X projecting arm plus UV.x wind read as a hammer stick with
	# cloth flying sideways (especially indoors in the smithy). Banners now hang
	# like a wall tapestry: short brackets, rod parallel to the plaster, cloth
	# face toward model +X (into the room when facing=east on a west wall).
	MapViewMeshBuilderPrimitives.box(
		root, "BannerMount", Vector3(0.08, 0.08, 0.10), Vector3(0.02, 2.10, -0.28), &"stone"
	)
	MapViewMeshBuilderPrimitives.box(
		root, "BannerPeg", Vector3(0.08, 0.08, 0.10), Vector3(0.02, 2.10, 0.28), &"stone"
	)
	# BannerArm keeps its historical node name for tests; it is the top rod.
	MapViewMeshBuilderPrimitives.box(
		root, "BannerArm", Vector3(0.04, 0.04, 0.70), Vector3(0.05, 2.10, 0.0), &"timber"
	)
	var cloth_width := 0.62
	var cloth_height := 0.95
	var cloth := MeshInstance3D.new()
	cloth.name = "BannerCloth"
	var albedo := MapViewMaterials.faction_banner_albedo(faction)
	if albedo != null:
		# Textured plate: white verts so the embroidered albedo is not tinted.
		cloth.mesh = FactionHeraldry.banner_textured_mesh(cloth_width, cloth_height)
	else:
		cloth.mesh = FactionHeraldry.banner_mesh(faction, cloth_width, cloth_height)
	# banner_mesh lies in XY with its lit face toward -Z; +90 deg Y turns that
	# face toward +X (into the room) and the width along +Z. Center on the rod.
	cloth.rotation.y = PI * 0.5
	cloth.position = Vector3(0.08, 1.58, -cloth_width * 0.5)
	cloth.set_meta(&"faction", faction)
	cloth.material_override = MapViewMaterials.hanging_banner_cloth(albedo)
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
	MapViewMeshBuilderPrimitives.box(
		crate,
		"BraceTop",
		Vector3(size.x + 0.035, 0.075, brace_depth),
		Vector3(0.0, size.y * 0.33, 0.0),
		&"timber"
	)
	MapViewMeshBuilderPrimitives.box(
		crate,
		"BraceBottom",
		Vector3(size.x + 0.035, 0.075, brace_depth),
		Vector3(0.0, -size.y * 0.33, 0.0),
		&"timber"
	)
	MapViewMeshBuilderPrimitives.box(
		crate, "BraceVertical", Vector3(0.075, size.y, brace_depth), Vector3.ZERO, &"timber"
	)


static func _add_trade_goods(root: Node3D, prop: Dictionary) -> void:
	# WHY: named harbor and market props need four distinct Hanseatic cargo reads
	# instead of one repeated sack-and-bale silhouette at gameplay distance.
	TradeGoodsModels.add_model(root, StringName(prop.get("id", &"trade_goods")))


static func _add_timber_fence(root: Node3D, prop: Dictionary, cell_size: int) -> void:
	var footprint: Rect2 = prop.get(
		"footprint", Rect2(Vector2.ZERO, Vector2(cell_size * 3, cell_size))
	)
	var scale := MapViewBridge.world_scale(cell_size)
	var horizontal := footprint.size.x >= footprint.size.y
	var length := maxf(maxf(footprint.size.x, footprint.size.y) * scale - 0.25, 0.75)
	var post_count := maxi(2, ceili(length / 1.4) + 1)
	for index in post_count:
		var along := lerpf(-length * 0.5, length * 0.5, float(index) / float(post_count - 1))
		var position := Vector3(along, 0.48, 0.0) if horizontal else Vector3(0.0, 0.48, along)
		MapViewMeshBuilderPrimitives.box(
			root, "Post%d" % index, Vector3(0.12, 0.96, 0.12), position, &"timber"
		)
	for rail_index in 2:
		var rail_y := 0.32 + float(rail_index) * 0.34
		var rail_size := Vector3(length, 0.1, 0.1) if horizontal else Vector3(0.1, 0.1, length)
		MapViewMeshBuilderPrimitives.box(
			root, "Rail%d" % rail_index, rail_size, Vector3(0.0, rail_y, 0.0), &"wood"
		)


static func _add_cattle(root: Node3D) -> void:
	MedievalAnimalModels.add_model(root, MammalSpecies.SPECIES_COW)


static func _add_sheep(root: Node3D) -> void:
	MedievalAnimalModels.add_model(root, MammalSpecies.SPECIES_SHEEP)


static func _add_horse(root: Node3D) -> void:
	MedievalAnimalModels.add_model(root, MammalSpecies.SPECIES_HORSE)


## Layered decorative vegetation and ground clutter. Textured ground cover carries
## most of the grass; sparse small/large tufts, shrubs, and trees add silhouette
## variation without turning every green cell into an object field.
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
	canopy.material_override = MapViewMaterials.canopy(
		MapViewTreeSpecies.canopy_material_kind(species)
	)
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
		"species", BushSpecies.pick_species(BushSpecies.weights_for_variant(variant), 0.41)
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
	assert(
		oak_scene != null,
		"Sacred Grove ancient oak GLB must be imported before the map view is assembled"
	)
	var oak := oak_scene.instantiate() as Node3D
	oak.name = "SacredGroveAncientOakModel"
	root.add_child(oak)
	root.set_meta(&"tree_species", MapViewTreeSpecies.SPECIES_OAK)
	root.set_meta(&"tree_size", MapViewTreeSpecies.SIZE_LARGE)
	root.set_meta(&"tree_model", &"sacred_grove_ancient_oak_glb")
	root.set_meta(&"tree_asset_path", SACRED_GROVE_ANCIENT_OAK_SCENE_PATH)
