class_name SmithyCourtyardDefinition
extends RefCounted

## Declarative layout for the Smithy Courtyard and adjacent Lower Town street spike.


static func create() -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = &"smithy_courtyard"
	definition.seed = MapTypes.DEFAULT_SEED
	definition.cell_size = MapTypes.DEFAULT_CELL_SIZE
	definition.size_cells = Vector2i(50, 28)
	definition.base_terrain = MapTypes.TERRAIN_GRASS
	definition.player_spawn = definition.cell_rect_center(Rect2i(20, 15, 2, 2))
	definition.location = &"lower_town"
	definition.scope = &"prototype"
	definition.active = false
	definition.palette = &"clean_painted"
	definition.fingerprint = "smithy_courtyard_v1"
	definition.camera_bounds = definition.cell_rect_to_world_rect(Rect2i(0, 0, 50, 28))

	definition.zones = [
		# Lower Town street band across the north edge.
		{"terrain": MapTypes.TERRAIN_COBBLESTONE, "rect": Rect2i(6, 0, 38, 5)},
		# Cobblestone gutter and side strips.
		{"terrain": MapTypes.TERRAIN_STONE, "rect": Rect2i(6, 5, 38, 1)},
		# Courtyard work yard.
		{"terrain": MapTypes.TERRAIN_DIRT, "rect": Rect2i(4, 8, 34, 16)},
		# Hay storage beside the smithy.
		{"terrain": MapTypes.TERRAIN_HAY, "rect": Rect2i(5, 11, 7, 6)},
		# Forge stone pad.
		{"terrain": MapTypes.TERRAIN_STONE, "rect": Rect2i(14, 13, 8, 5)},
		# Coal and sand pile.
		{"terrain": MapTypes.TERRAIN_SAND, "rect": Rect2i(24, 16, 5, 4)},
		# Drainage trough / quench basin.
		{"terrain": MapTypes.TERRAIN_WATER, "rect": Rect2i(31, 18, 4, 3)},
		# Lane connecting courtyard to the street.
		{"terrain": MapTypes.TERRAIN_COBBLESTONE, "rect": Rect2i(18, 5, 6, 4)},
	]

	var wall_color := Color(0.48, 0.50, 0.54, 1.0)
	var wall_height := 48.0

	definition.buildings = [
		{
			"id": &"smithy_hall",
			"kind": MapTypes.BUILDING_KIND_HOUSE,
			"footprint": definition.cell_rect_to_world_rect(Rect2i(13, 9, 9, 4)),
			"wall_height": 72.0,
			"wall_color": Color(0.34, 0.30, 0.26, 1.0),
			"roof_color": Color(0.22, 0.20, 0.18, 1.0),
		},
		{
			"id": &"coal_store",
			"kind": MapTypes.BUILDING_KIND_HOUSE,
			"footprint": definition.cell_rect_to_world_rect(Rect2i(23, 10, 3, 3)),
			"wall_height": 56.0,
			"wall_color": Color(0.30, 0.28, 0.24, 1.0),
			"roof_color": Color(0.18, 0.17, 0.15, 1.0),
		},
		{
			"id": &"street_shop",
			"kind": MapTypes.BUILDING_KIND_HOUSE,
			"footprint": definition.cell_rect_to_world_rect(Rect2i(39, 1, 5, 3)),
			"wall_height": 64.0,
			"wall_color": Color(0.42, 0.36, 0.30, 1.0),
			"roof_color": Color(0.24, 0.20, 0.16, 1.0),
		},
		# Courtyard enclosure: stone walls with a street-facing gap at the lane.
		{
			"id": &"wall_west",
			"kind": MapTypes.BUILDING_KIND_WALL,
			"footprint": definition.cell_rect_to_world_rect(Rect2i(4, 8, 1, 16)),
			"wall_height": wall_height,
			"wall_color": wall_color,
		},
		{
			"id": &"wall_east",
			"kind": MapTypes.BUILDING_KIND_WALL,
			"footprint": definition.cell_rect_to_world_rect(Rect2i(37, 8, 1, 16)),
			"wall_height": wall_height,
			"wall_color": wall_color,
		},
		{
			"id": &"wall_south",
			"kind": MapTypes.BUILDING_KIND_WALL,
			"footprint": definition.cell_rect_to_world_rect(Rect2i(4, 23, 34, 1)),
			"wall_height": wall_height,
			"wall_color": wall_color,
		},
		{
			"id": &"wall_north_west",
			"kind": MapTypes.BUILDING_KIND_WALL,
			"footprint": definition.cell_rect_to_world_rect(Rect2i(4, 8, 14, 1)),
			"wall_height": wall_height,
			"wall_color": wall_color,
		},
		{
			"id": &"wall_north_east",
			"kind": MapTypes.BUILDING_KIND_WALL,
			"footprint": definition.cell_rect_to_world_rect(Rect2i(24, 8, 14, 1)),
			"wall_height": wall_height,
			"wall_color": wall_color,
		},
	]

	var water_zone := Rect2i(31, 18, 4, 3)

	definition.props = [
		{
			"id": &"anvil",
			"kind": MapTypes.PROP_KIND_ANVIL,
			"position": definition.cell_rect_center(Rect2i(14, 13, 8, 5)),
		},
		{
			"id": &"hay_stack",
			"kind": MapTypes.PROP_KIND_HAY_STACK,
			"position": definition.cell_rect_center(Rect2i(5, 11, 7, 6)),
		},
		{
			"id": &"cart",
			"kind": MapTypes.PROP_KIND_CART,
			"position": definition.cell_rect_center(Rect2i(22, 2, 2, 2)),
		},
		{
			"id": &"well",
			"kind": MapTypes.PROP_KIND_WELL,
			"position": definition.cell_rect_center(water_zone),
		},
		{
			"id": &"barrel_pair",
			"kind": MapTypes.PROP_KIND_BARRELS,
			"position": definition.cell_rect_center(Rect2i(16, 14, 2, 2)),
		},
	]

	return definition
