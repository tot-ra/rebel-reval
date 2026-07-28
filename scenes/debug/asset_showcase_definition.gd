class_name AssetShowcaseDefinition
extends RefCounted

## Developer-only catalog maps. Collections intentionally come from the runtime
## registries so coverage tests fail when a new terrain or prop kind is added
## without a corresponding place in one of the review scenes.

const SHOWCASE_CHARACTERS_ANIMALS := &"characters_animals"
const SHOWCASE_LARGE := &"large"
const SHOWCASE_SMALL := &"small"
const SHOWCASE_KINDS: Array[StringName] = [
	SHOWCASE_CHARACTERS_ANIMALS,
	SHOWCASE_LARGE,
	SHOWCASE_SMALL,
]

const CELL_SIZE := MapTypes.DEFAULT_CELL_SIZE
const CHARACTERS_ANIMALS_SIZE_CELLS := Vector2i(136, 144)
const LARGE_SIZE_CELLS := Vector2i(136, 210)
const SMALL_SIZE_CELLS := Vector2i(96, 116)

# Large assets use wider patches and gaps than the small-object catalog so roofs,
# ships, and tree canopies remain visually isolated during review.
const TERRAIN_COLUMNS := 6
const TERRAIN_START_CELL := Vector2i(4, 5)
const TERRAIN_PATCH_SIZE := Vector2i(16, 12)
const TERRAIN_SPACING_CELLS := Vector2i(21, 15)
const LARGE_PROP_START_CELL := Vector2i(12, 123)
const LARGE_PROP_SPACING_CELLS := Vector2i(32, 18)
const SMALL_PROP_COLUMNS := 8
const SMALL_PROP_START_CELL := Vector2i(4, 6)
const SMALL_PROP_SPACING_CELLS := Vector2i(11, 8)
const ANCIENT_TREE_CELL := Vector2i(108, 123)
# Every registered procedural species gets a neutral medium-size sample. Keeping
# scale fixed makes silhouette, bark, foliage, and fruit differences reviewable.
const TREE_MODEL_COLUMNS := 5
const TREE_MODEL_START_CELL := Vector2i(12, 158)
const TREE_MODEL_SPACING_CELLS := Vector2i(24, 12)
const WALL_WALK_ACCESS_CELL := Vector2i(88, 105)
const WALL_WALK_ACCESS_RECT := Rect2i(84, 103, 8, 5)

const LIVE_PROP_KINDS: Array[StringName] = [
	MapTypes.PROP_KIND_CATTLE,
	MapTypes.PROP_KIND_SHEEP,
	MapTypes.PROP_KIND_HORSE,
]
const LARGE_PROP_KINDS: Array[StringName] = [
	MapTypes.PROP_KIND_TREE,
	MapTypes.PROP_KIND_FISHING_BOAT,
	MapTypes.PROP_KIND_MERCHANT_BOAT,
]
const SPECIALIZED_PROP_IDS: Dictionary = {
	MapTypes.PROP_KIND_ANVIL: &"forge_anvil",
	MapTypes.PROP_KIND_FURNACE: &"forge_furnace",
	MapTypes.PROP_KIND_BELLOWS: &"forge_bellows",
	MapTypes.PROP_KIND_QUENCH: &"quench",
	MapTypes.PROP_KIND_BED: &"bed",
	MapTypes.PROP_KIND_CHAIR: &"work_chair",
}
const BUILDING_SPECS: Array[Dictionary] = [
	{
		"id": &"building_log_thatch",
		"label": "LOG + THATCH",
		"kind": MapTypes.BUILDING_KIND_HOUSE,
		"cell_rect": Rect2i(4, 70, 9, 7),
		"wall_height": 96.0,
		"wall_material": &"log",
		"roof_material": &"thatch",
		"door_side": &"south",
		"ridge_axis": &"x",
	},
	{
		"id": &"building_plank_shingle",
		"label": "PLANK + SHINGLE",
		"kind": MapTypes.BUILDING_KIND_HOUSE,
		"cell_rect": Rect2i(24, 70, 9, 7),
		"wall_height": 112.0,
		"wall_material": &"plank",
		"roof_material": &"shingle",
		"door_side": &"south",
		"ridge_axis": &"x",
	},
	{
		"id": &"building_timber_tile",
		"label": "PLASTER + TILE",
		"kind": MapTypes.BUILDING_KIND_HOUSE,
		"cell_rect": Rect2i(44, 70, 9, 7),
		"wall_height": 128.0,
		"wall_material": &"plaster",
		"roof_material": &"tile",
		"door_side": &"south",
		"ridge_axis": &"x",
	},
	{
		"id": &"building_stone_gable",
		"label": "STONE STEPPED GABLE",
		"kind": MapTypes.BUILDING_KIND_HOUSE,
		"cell_rect": Rect2i(64, 70, 9, 7),
		"wall_height": 144.0,
		"wall_material": &"limestone",
		"roof_material": &"tile",
		"primitive": &"stepped_gable_merchant",
		"door_side": &"south",
		"ridge_axis": &"z",
	},
	{
		"id": &"building_chapel",
		"label": "CHAPEL PRIMITIVE",
		"kind": MapTypes.BUILDING_KIND_HOUSE,
		"cell_rect": Rect2i(84, 70, 10, 7),
		"wall_height": 176.0,
		"wall_material": &"limestone",
		"roof_material": &"tile",
		"primitive": &"holy_spirit_chapel_1343",
		"door_side": &"south",
		"ridge_axis": &"x",
	},
	{
		"id": &"building_town_hall",
		"label": "TOWN HALL PRIMITIVE",
		"kind": MapTypes.BUILDING_KIND_HOUSE,
		"cell_rect": Rect2i(108, 69, 18, 8),
		"wall_height": 180.0,
		"wall_material": &"limestone",
		"roof_material": &"tile",
		"primitive": &"town_hall_1343",
		"door_side": &"north",
		"ridge_axis": &"x",
	},
	{
		"id": &"building_low_wall",
		"label": "LOW WALL",
		"kind": MapTypes.BUILDING_KIND_WALL,
		"cell_rect": Rect2i(4, 90, 12, 1),
		"wall_height": 56.0,
	},
	{
		"id": &"building_fortification",
		"label": "FORTIFICATION + BATTLEMENTS",
		"kind": MapTypes.BUILDING_KIND_WALL,
		"cell_rect": Rect2i(26, 90, 15, 1),
		"wall_height": 144.0,
	},
	{
		"id": &"building_round_tower",
		"label": "ROUND TOWER",
		"kind": MapTypes.BUILDING_KIND_WALL,
		"cell_rect": Rect2i(52, 86, 7, 7),
		"wall_height": 176.0,
		"round_tower": true,
		"tower": true,
		"door_side": &"south",
		"faction": FactionHeraldry.DANISH_CROWN,
	},
	{
		"id": &"building_interior_wall",
		"label": "INTERIOR WALL",
		"kind": MapTypes.BUILDING_KIND_INTERIOR_WALL,
		"cell_rect": Rect2i(70, 90, 12, 1),
		"wall_height": 96.0,
		"wall_material": &"smoked_plaster",
	},
	{
		"id": &"building_interior_block",
		"label": "INTERIOR BLOCK",
		"kind": MapTypes.BUILDING_KIND_INTERIOR_BLOCK,
		"cell_rect": Rect2i(94, 89, 9, 2),
		"wall_height": 56.0,
	},
]
const GATE_SPECS: Array[Dictionary] = [
	{"id": &"gate_oak", "label": "OAK GATE", "cell_rect": Rect2i(4, 104, 7, 3), "gate_variant": &"oak"},
	{"id": &"gate_ironbound", "label": "IRONBOUND GATE", "cell_rect": Rect2i(30, 104, 7, 3), "gate_variant": &"ironbound"},
	{"id": &"gate_portcullis", "label": "RAISED PORTCULLIS", "cell_rect": Rect2i(56, 104, 7, 3), "gate_variant": &"none", "grille_variant": &"portcullis"},
]


static func create(showcase_kind: StringName = SHOWCASE_SMALL) -> MapDefinition:
	assert(SHOWCASE_KINDS.has(showcase_kind), "Unknown asset showcase kind: %s" % String(showcase_kind))
	var large := showcase_kind == SHOWCASE_LARGE
	var characters_animals := showcase_kind == SHOWCASE_CHARACTERS_ANIMALS
	var definition := MapDefinition.new()
	match showcase_kind:
		SHOWCASE_CHARACTERS_ANIMALS:
			definition.map_id = &"debug_characters_animals"
			definition.location = &"loc.debug.characters.animals"
		SHOWCASE_LARGE:
			definition.map_id = &"debug_asset_showcase_large"
			definition.location = &"loc.debug.asset_showcase.large"
		_:
			definition.map_id = &"debug_asset_showcase_small"
			definition.location = &"loc.debug.asset_showcase.small"
	definition.seed = 1343
	definition.cell_size = CELL_SIZE
	definition.size_cells = (
		LARGE_SIZE_CELLS if large
		else CHARACTERS_ANIMALS_SIZE_CELLS if characters_animals
		else SMALL_SIZE_CELLS
	)
	definition.base_terrain = MapTypes.TERRAIN_GRASS
	definition.scope = &"prototype"
	definition.active = false
	definition.palette = MapVisualStyle.TARGET_CLEAN_PAINTED
	definition.player_spawn = _cell_center(
		Vector2i(68, 65) if large
		else Vector2i(68, 70) if characters_animals
		else Vector2i(48, 60)
	)
	definition.camera_bounds = Rect2(Vector2.ZERO, definition.world_size())
	definition.surroundings_sides = {
		&"north": &"woodland",
		&"south": &"town",
		&"east": &"water",
		&"west": &"town",
	}
	if large:
		definition.zones = _terrain_zones()
		definition.buildings = _buildings()
		definition.view_landmarks = _gate_landmarks()
	definition.props = _props(showcase_kind)
	definition.fingerprint = "debug-asset-showcase-%s-v4" % String(showcase_kind)
	return definition


static func create_characters_animals() -> MapDefinition:
	return create(SHOWCASE_CHARACTERS_ANIMALS)


static func create_large() -> MapDefinition:
	return create(SHOWCASE_LARGE)


static func create_small() -> MapDefinition:
	return create(SHOWCASE_SMALL)


static func small_prop_kinds() -> Array[StringName]:
	var kinds: Array[StringName] = []
	for kind in MapTypes.ALL_PROP_KINDS:
		if kind not in LARGE_PROP_KINDS and kind not in LIVE_PROP_KINDS:
			kinds.append(kind)
	return kinds


static func small_prop_cell(kind_index: int) -> Vector2i:
	return SMALL_PROP_START_CELL + Vector2i(
		(kind_index % SMALL_PROP_COLUMNS) * SMALL_PROP_SPACING_CELLS.x,
		(kind_index / SMALL_PROP_COLUMNS) * SMALL_PROP_SPACING_CELLS.y
	)


static func large_prop_cell(kind_index: int) -> Vector2i:
	return LARGE_PROP_START_CELL + Vector2i(kind_index * LARGE_PROP_SPACING_CELLS.x, 0)


static func terrain_cell(terrain_index: int) -> Vector2i:
	return TERRAIN_START_CELL + Vector2i(
		(terrain_index % TERRAIN_COLUMNS) * TERRAIN_SPACING_CELLS.x,
		(terrain_index / TERRAIN_COLUMNS) * TERRAIN_SPACING_CELLS.y
	)


static func tree_model_cell(species_index: int) -> Vector2i:
	return TREE_MODEL_START_CELL + Vector2i(
		(species_index % TREE_MODEL_COLUMNS) * TREE_MODEL_SPACING_CELLS.x,
		(species_index / TREE_MODEL_COLUMNS) * TREE_MODEL_SPACING_CELLS.y
	)


static func prop_id_for(kind: StringName) -> StringName:
	return SPECIALIZED_PROP_IDS.get(kind, StringName("showcase_%s" % String(kind))) as StringName


static func _terrain_zones() -> Array[Dictionary]:
	var zones: Array[Dictionary] = []
	for index in MapTypes.ALL_TERRAINS.size():
		zones.append({
			"terrain": MapTypes.ALL_TERRAINS[index],
			"rect": Rect2i(terrain_cell(index), TERRAIN_PATCH_SIZE),
		})

	# Boats need a real water context instead of hovering over the neutral gallery
	# floor. The bay has extra clearance around both hulls on the large-item grid.
	var fishing_index := LARGE_PROP_KINDS.find(MapTypes.PROP_KIND_FISHING_BOAT)
	var merchant_index := LARGE_PROP_KINDS.find(MapTypes.PROP_KIND_MERCHANT_BOAT)
	var first_boat := large_prop_cell(fishing_index)
	var last_boat := large_prop_cell(merchant_index)
	zones.append({
		"terrain": MapTypes.TERRAIN_DEEP_WATER,
		"rect": Rect2i(first_boat - Vector2i(4, 4), Vector2i(last_boat.x - first_boat.x + 9, 9)),
	})
	return zones


static func _buildings() -> Array[Dictionary]:
	var buildings: Array[Dictionary] = []
	for spec in BUILDING_SPECS:
		var building := spec.duplicate(true)
		building.erase("label")
		building["footprint"] = _cell_rect_to_world(spec["cell_rect"])
		building.erase("cell_rect")
		building["wall_color"] = building.get("wall_color", Color8(126, 116, 99))
		building["roof_color"] = building.get("roof_color", Color8(86, 48, 35))
		buildings.append(building)
	return buildings


static func _props(showcase_kind: StringName) -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	var kinds: Array[StringName] = []
	if showcase_kind == SHOWCASE_LARGE:
		kinds.assign(LARGE_PROP_KINDS)
	elif showcase_kind == SHOWCASE_CHARACTERS_ANIMALS:
		kinds.assign(LIVE_PROP_KINDS)
	else:
		kinds = small_prop_kinds()

	for index in kinds.size():
		var kind: StringName = kinds[index]
		var cell := large_prop_cell(index) if showcase_kind == SHOWCASE_LARGE else small_prop_cell(index)
		var prop := {
			"id": prop_id_for(kind),
			"kind": kind,
			"position": _cell_center(cell),
		}
		if kind == MapTypes.PROP_KIND_BANNER:
			prop["faction"] = FactionHeraldry.DANISH_CROWN
		elif kind == MapTypes.PROP_KIND_TREE:
			prop["style_variant"] = &"tree.oak.large"
		elif kind == MapTypes.PROP_KIND_BUSH:
			prop["style_variant"] = TerrainVegetation.VARIANT_BUSH_DENSE
		elif kind in MapTypes.BOAT_PROP_KINDS:
			prop["footprint"] = _cell_rect_to_world(Rect2i(cell - Vector2i(1, 2), Vector2i(3, 5)))
		props.append(prop)

	if showcase_kind == SHOWCASE_LARGE:
		# Special variants exercise production branches beyond the base kind catalog.
		props.append({
			"id": &"ancient_tree",
			"kind": MapTypes.PROP_KIND_TREE,
			"position": _cell_center(ANCIENT_TREE_CELL),
			"primitive": &"ancient_tree",
		})
		# These entries deliberately resolve through the normal prop builder so this
		# gallery always shows the exact cached procedural models used on maps.
		for index in MapViewTreeSpecies.ALL_SPECIES.size():
			var species: StringName = MapViewTreeSpecies.ALL_SPECIES[index]
			props.append({
				"id": StringName("tree_%s_medium" % String(species)),
				"kind": MapTypes.PROP_KIND_TREE,
				"position": _cell_center(tree_model_cell(index)),
				"style_variant": StringName("tree.%s.medium" % String(species)),
			})
		props.append({
			"id": &"wall_walk_access",
			"kind": MapTypes.PROP_KIND_STAIRS,
			"position": _cell_center(WALL_WALK_ACCESS_CELL),
			"footprint": _cell_rect_to_world(WALL_WALK_ACCESS_RECT),
			"primitive": MapWallWalkAccess.ACCESS_PRIMITIVE,
			"faction": FactionHeraldry.DANISH_CROWN,
			"facing": Vector2.RIGHT,
		})
	return props


static func _gate_landmarks() -> Array[Dictionary]:
	var landmarks: Array[Dictionary] = []
	for spec in GATE_SPECS:
		landmarks.append({
			"id": spec["id"],
			"kind": &"gate_arch",
			"rect": _cell_rect_to_world(spec["cell_rect"]),
			"top_px": 176.0,
			"wall_color": Color8(143, 140, 128),
			"gate_variant": spec["gate_variant"],
			"grille_variant": spec.get("grille_variant", &"none"),
			"passage_axis": &"z",
		})
	return landmarks


static func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * float(CELL_SIZE)


static func _cell_rect_to_world(cell_rect: Rect2i) -> Rect2:
	return Rect2(
		Vector2(cell_rect.position) * float(CELL_SIZE),
		Vector2(cell_rect.size) * float(CELL_SIZE)
	)
