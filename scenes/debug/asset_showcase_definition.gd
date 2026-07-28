class_name AssetShowcaseDefinition
extends RefCounted

## Developer-only catalog map. Collections intentionally come from the runtime
## registries so coverage tests fail when a new terrain or prop kind is added
## without a corresponding place in the review scene.

const CELL_SIZE := MapTypes.DEFAULT_CELL_SIZE
const SIZE_CELLS := Vector2i(96, 148)
const TERRAIN_COLUMNS := 7
const TERRAIN_PATCH_SIZE := Vector2i(12, 10)
const PROP_COLUMNS := 8
const PROP_START_CELL := Vector2i(4, 38)
const PROP_SPACING_CELLS := Vector2i(11, 8)
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
		"cell_rect": Rect2i(4, 26, 9, 7),
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
		"cell_rect": Rect2i(17, 26, 9, 7),
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
		"cell_rect": Rect2i(30, 26, 9, 7),
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
		"cell_rect": Rect2i(43, 26, 9, 7),
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
		"cell_rect": Rect2i(56, 26, 10, 7),
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
		"cell_rect": Rect2i(70, 25, 18, 8),
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
		"cell_rect": Rect2i(4, 35, 10, 1),
		"wall_height": 56.0,
	},
	{
		"id": &"building_fortification",
		"label": "FORTIFICATION + BATTLEMENTS",
		"kind": MapTypes.BUILDING_KIND_WALL,
		"cell_rect": Rect2i(18, 35, 13, 1),
		"wall_height": 144.0,
	},
	{
		"id": &"building_round_tower",
		"label": "ROUND TOWER",
		"kind": MapTypes.BUILDING_KIND_WALL,
		"cell_rect": Rect2i(35, 33, 5, 5),
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
		"cell_rect": Rect2i(45, 35, 10, 1),
		"wall_height": 96.0,
		"wall_material": &"smoked_plaster",
	},
	{
		"id": &"building_interior_block",
		"label": "INTERIOR BLOCK",
		"kind": MapTypes.BUILDING_KIND_INTERIOR_BLOCK,
		"cell_rect": Rect2i(59, 34, 7, 2),
		"wall_height": 56.0,
	},
]
const GATE_SPECS: Array[Dictionary] = [
	{"id": &"gate_oak", "label": "OAK GATE", "cell_rect": Rect2i(70, 35, 6, 3), "gate_variant": &"oak"},
	{"id": &"gate_ironbound", "label": "IRONBOUND GATE", "cell_rect": Rect2i(78, 35, 6, 3), "gate_variant": &"ironbound"},
	{"id": &"gate_portcullis", "label": "RAISED PORTCULLIS", "cell_rect": Rect2i(86, 35, 6, 3), "gate_variant": &"none", "grille_variant": &"portcullis"},
]


static func create() -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = &"debug_asset_showcase"
	definition.seed = 1343
	definition.cell_size = CELL_SIZE
	definition.size_cells = SIZE_CELLS
	definition.base_terrain = MapTypes.TERRAIN_GRASS
	definition.location = &"loc.debug.asset_showcase"
	definition.scope = &"prototype"
	definition.active = false
	definition.palette = MapVisualStyle.TARGET_CLEAN_PAINTED
	definition.player_spawn = _cell_center(Vector2i(48, 22))
	definition.camera_bounds = Rect2(Vector2.ZERO, definition.world_size())
	definition.surroundings_sides = {
		&"north": &"woodland",
		&"south": &"town",
		&"east": &"water",
		&"west": &"town",
	}
	definition.zones = _terrain_zones()
	definition.buildings = _buildings()
	definition.props = _props()
	definition.view_landmarks = _gate_landmarks()
	definition.fingerprint = "debug-asset-showcase-v1"
	return definition


static func prop_cell(kind_index: int) -> Vector2i:
	return PROP_START_CELL + Vector2i(
		(kind_index % PROP_COLUMNS) * PROP_SPACING_CELLS.x,
		(kind_index / PROP_COLUMNS) * PROP_SPACING_CELLS.y
	)


static func terrain_cell(terrain_index: int) -> Vector2i:
	return Vector2i(
		(terrain_index % TERRAIN_COLUMNS) * TERRAIN_PATCH_SIZE.x,
		(terrain_index / TERRAIN_COLUMNS) * TERRAIN_PATCH_SIZE.y
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
	# floor. This extra bay is intentionally separate from the one-patch-per-kind
	# catalog above.
	var fishing_index := MapTypes.ALL_PROP_KINDS.find(MapTypes.PROP_KIND_FISHING_BOAT)
	var merchant_index := MapTypes.ALL_PROP_KINDS.find(MapTypes.PROP_KIND_MERCHANT_BOAT)
	var first_boat := prop_cell(fishing_index)
	var last_boat := prop_cell(merchant_index)
	zones.append({
		"terrain": MapTypes.TERRAIN_DEEP_WATER,
		"rect": Rect2i(first_boat - Vector2i(3, 3), Vector2i(last_boat.x - first_boat.x + 7, 7)),
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


static func _props() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	for index in MapTypes.ALL_PROP_KINDS.size():
		var kind: StringName = MapTypes.ALL_PROP_KINDS[index]
		var cell := prop_cell(index)
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

	# Special variants use stable IDs/metadata that select production GLBs or
	# exercise visual branches beyond the base prop kind catalog.
	props.append({
		"id": &"ancient_tree",
		"kind": MapTypes.PROP_KIND_TREE,
		"position": _cell_center(Vector2i(81, 96)),
		"primitive": &"ancient_tree",
	})
	props.append({
		"id": &"wall_walk_access",
		"kind": MapTypes.PROP_KIND_STAIRS,
		"position": _cell_center(Vector2i(15, 36)),
		"footprint": _cell_rect_to_world(Rect2i(12, 35, 6, 4)),
		"primitive": MapWallWalkAccess.ACCESS_PRIMITIVE,
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
