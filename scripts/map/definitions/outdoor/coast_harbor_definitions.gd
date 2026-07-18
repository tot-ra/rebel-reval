class_name CoastHarborDefinitions
extends RefCounted

const Factory := preload("res://scripts/map/definitions/outdoor/outdoor_map_factory.gd")


static func all() -> Array[MapDefinition]:
	return [paldiski_outpost()]


static func reval_harbor() -> MapDefinition:
	return Factory.create({
		"package": &"coast_harbor",
		"map_id": &"prototype.reval_harbor_surroundings",
		"location": &"loc.reval_harbor",
		"size": Vector2i(56, 32),
		"base": MapTypes.TERRAIN_MEADOW,
		"spawn": Vector2i(7, 24),
		"sources": [
			"res://scenes/harbor/harbor.md",
			"res://scenes/harbor/great_coast_gate.md",
			"res://scenes/harbor/warehouses.md",
			"res://scenes/harbor/Screenshot 2025-08-24 at 22.46.16.png",
		],
		"zones": [
			Factory.zone(MapTypes.TERRAIN_DEEP_WATER, Rect2i(0, 0, 56, 8)),
			Factory.zone(MapTypes.TERRAIN_SHALLOW_WATER, Rect2i(0, 8, 56, 3)),
			Factory.zone(MapTypes.TERRAIN_COAST_SAND, Rect2i(0, 11, 56, 3)),
			Factory.zone(MapTypes.TERRAIN_CASTLE_PAVING, Rect2i(4, 14, 48, 6)),
			Factory.zone(MapTypes.TERRAIN_MUD, Rect2i(2, 20, 52, 3)),
			Factory.zone(MapTypes.TERRAIN_GRASS, Rect2i(0, 23, 56, 9)),
		],
		"excluded": [Rect2i(0, 0, 56, 11)],
		"structures": [
			Factory.structure(&"great_coast_gate", &"gatehouse", Rect2i(43, 22, 8, 5), 88.0),
			Factory.structure(&"warehouse_west", &"warehouse", Rect2i(8, 22, 10, 5), 64.0),
			Factory.structure(&"warehouse_east", &"warehouse", Rect2i(21, 22, 10, 5), 64.0),
			Factory.structure(&"stone_quay", &"wall", Rect2i(4, 13, 48, 1), 24.0),
			Factory.structure(&"pier_west", &"pier", Rect2i(10, 8, 3, 6), 18.0),
			Factory.structure(&"pier_east", &"pier", Rect2i(28, 8, 3, 6), 18.0),
		],
		"props": [
			Factory.prop(&"quay_crane", &"crane", Vector2i(34, 17)),
			Factory.prop(&"cargo_barrels", &"barrels", Vector2i(19, 18)),
			Factory.prop(&"drying_nets", &"nets", Vector2i(6, 18)),
		],
		"landmarks": [
			Factory.landmark(&"coast_gate", &"gatehouse", Vector2i(47, 24)),
			Factory.landmark(&"warehouse_row", &"warehouse", Vector2i(26, 24)),
			Factory.landmark(&"quay_crane", &"crane", Vector2i(34, 17)),
			Factory.landmark(&"twin_piers", &"pier", Vector2i(20, 13)),
		],
		"route": [Vector2i(7, 24), Vector2i(5, 19), Vector2i(19, 19), Vector2i(34, 19), Vector2i(40, 21), Vector2i(40, 27)],
	})


static func paldiski_outpost() -> MapDefinition:
	return Factory.create({
		"package": &"coast_harbor",
		"map_id": &"prototype.paldiski_coastal_outpost",
		"location": &"loc.paldiski",
		"size": Vector2i(48, 28),
		"base": MapTypes.TERRAIN_MEADOW,
		"spawn": Vector2i(5, 22),
		"sources": ["res://scenes/events/paldiski.md"],
		"zones": [
			Factory.zone(MapTypes.TERRAIN_DEEP_WATER, Rect2i(0, 0, 48, 7)),
			Factory.zone(MapTypes.TERRAIN_SHALLOW_WATER, Rect2i(0, 7, 48, 3)),
			Factory.zone(MapTypes.TERRAIN_COAST_SAND, Rect2i(0, 10, 48, 4)),
			Factory.zone(MapTypes.TERRAIN_MUD, Rect2i(0, 14, 48, 4)),
			Factory.zone(MapTypes.TERRAIN_DIRT, Rect2i(3, 18, 42, 6)),
			Factory.zone(MapTypes.TERRAIN_FOREST_FLOOR, Rect2i(0, 24, 48, 4)),
		],
		"excluded": [Rect2i(0, 0, 48, 10)],
		"structures": [
			Factory.structure(&"timber_stockade", &"palisade", Rect2i(3, 17, 42, 1), 42.0),
			Factory.structure(&"outpost_hall", &"timber_hall", Rect2i(29, 19, 9, 4), 62.0),
			Factory.structure(&"shore_tavern", &"house", Rect2i(7, 19, 8, 4), 56.0),
			Factory.structure(&"shipyard_shed", &"work_shed", Rect2i(18, 19, 7, 3), 48.0),
			Factory.structure(&"outpost_pier", &"pier", Rect2i(20, 7, 3, 10), 18.0),
		],
		"props": [
			Factory.prop(&"ship_frame", &"ship_frame", Vector2i(25, 15)),
			Factory.prop(&"smuggler_cargo", &"crates", Vector2i(17, 20)),
			Factory.prop(&"shore_beacon", &"beacon", Vector2i(42, 14)),
		],
		"landmarks": [
			Factory.landmark(&"outpost_hall", &"timber_hall", Vector2i(33, 22)),
			Factory.landmark(&"shipyard", &"shipyard", Vector2i(22, 20)),
			Factory.landmark(&"long_pier", &"pier", Vector2i(21, 14)),
		],
		"route": [Vector2i(5, 22), Vector2i(16, 22), Vector2i(26, 23), Vector2i(40, 23), Vector2i(42, 18)],
	})
