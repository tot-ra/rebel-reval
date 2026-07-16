class_name VillageMonasteryDefinitions
extends RefCounted

const Factory := preload("res://scripts/map/definitions/outdoor/outdoor_map_factory.gd")


static func all() -> Array[MapDefinition]:
	return [harju_village(), padise_monastery()]


static func harju_village() -> MapDefinition:
	return Factory.create({
		"package": &"villages_monasteries",
		"map_id": &"prototype.harju_village",
		"location": &"loc.harju_village",
		"size": Vector2i(52, 30),
		"base": MapTypes.TERRAIN_MEADOW,
		"spawn": Vector2i(3, 15),
		"sources": ["res://scenes/world/harju_village.md"],
		"zones": [
			Factory.zone(MapTypes.TERRAIN_FARM_SOIL, Rect2i(2, 2, 15, 9)),
			Factory.zone(MapTypes.TERRAIN_FARM_SOIL, Rect2i(35, 3, 14, 8)),
			Factory.zone(MapTypes.TERRAIN_HAY, Rect2i(4, 23, 10, 5)),
			Factory.zone(MapTypes.TERRAIN_DIRT, Rect2i(0, 13, 52, 5)),
			Factory.zone(MapTypes.TERRAIN_MUD, Rect2i(20, 16, 8, 4)),
			Factory.zone(MapTypes.TERRAIN_FOREST_FLOOR, Rect2i(43, 18, 9, 12)),
		],
		"structures": [
			Factory.structure(&"elder_farmstead", &"farmhouse", Rect2i(18, 7, 8, 4), 54.0),
			Factory.structure(&"threshing_barn", &"barn", Rect2i(30, 7, 9, 4), 58.0),
			Factory.structure(&"west_croft", &"farmhouse", Rect2i(6, 18, 7, 4), 50.0),
			Factory.structure(&"cattle_fence", &"palisade", Rect2i(28, 21, 12, 1), 20.0),
		],
		"props": [
			Factory.prop(&"village_well", &"well", Vector2i(25, 15)),
			Factory.prop(&"hay_rick", &"hay_stack", Vector2i(9, 25)),
			Factory.prop(&"field_cart", &"cart", Vector2i(40, 14)),
		],
		"landmarks": [
			Factory.landmark(&"village_well", &"well", Vector2i(25, 15)),
			Factory.landmark(&"threshing_barn", &"barn", Vector2i(34, 11)),
			Factory.landmark(&"split_fields", &"farm_fields", Vector2i(42, 6)),
		],
		"route": [Vector2i(3, 15), Vector2i(14, 15), Vector2i(25, 15), Vector2i(38, 15), Vector2i(48, 16)],
	})


static func padise_monastery() -> MapDefinition:
	return Factory.create({
		"package": &"villages_monasteries",
		"map_id": &"prototype.padise_monastery",
		"location": &"loc.padise_monastery",
		"size": Vector2i(50, 30),
		"base": MapTypes.TERRAIN_MEADOW,
		"spawn": Vector2i(4, 25),
		"phases": [&"before_attack", &"after_attack"],
		"canonical_phase": &"layout_only",
		"sources": ["res://scenes/world/padise/padise_monastery.md", "res://scenes/world/padise/padise-map.png"],
		"zones": [
			Factory.zone(MapTypes.TERRAIN_FARM_SOIL, Rect2i(2, 3, 12, 9)),
			Factory.zone(MapTypes.TERRAIN_CASTLE_PAVING, Rect2i(16, 6, 27, 19)),
			Factory.zone(MapTypes.TERRAIN_DIRT, Rect2i(0, 24, 50, 4)),
			Factory.zone(MapTypes.TERRAIN_MUD, Rect2i(43, 12, 7, 8)),
		],
		"structures": [
			Factory.structure(&"monastery_church", &"stone_church", Rect2i(20, 7, 10, 6), 82.0),
			Factory.structure(&"cloister_west", &"monastic_range", Rect2i(17, 14, 5, 8), 58.0),
			Factory.structure(&"cloister_east", &"monastic_range", Rect2i(34, 14, 6, 8), 58.0),
			Factory.structure(&"gatehouse", &"gatehouse", Rect2i(26, 23, 6, 3), 68.0),
			Factory.structure(&"work_yard_barn", &"barn", Rect2i(4, 16, 9, 5), 52.0),
			Factory.structure(&"precinct_wall_north", &"wall", Rect2i(15, 5, 29, 1), 40.0),
			Factory.structure(&"precinct_wall_west", &"wall", Rect2i(15, 5, 1, 20), 40.0),
			Factory.structure(&"precinct_wall_east", &"wall", Rect2i(43, 5, 1, 20), 40.0),
		],
		"props": [
			Factory.prop(&"cloister_well", &"well", Vector2i(28, 18)),
			Factory.prop(&"work_cart", &"cart", Vector2i(10, 23)),
			Factory.prop(&"herb_beds", &"garden", Vector2i(39, 10)),
		],
		"landmarks": [
			Factory.landmark(&"church", &"stone_church", Vector2i(25, 13)),
			Factory.landmark(&"cloister", &"cloister", Vector2i(28, 18)),
			Factory.landmark(&"gatehouse", &"gatehouse", Vector2i(29, 26)),
			Factory.landmark(&"work_yard", &"work_yard", Vector2i(10, 23)),
		],
		"route": [Vector2i(4, 25), Vector2i(14, 25), Vector2i(23, 26), Vector2i(33, 26), Vector2i(42, 26)],
	})
