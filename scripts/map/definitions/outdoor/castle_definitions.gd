class_name CastleDefinitions
extends RefCounted

const Factory := preload("res://scripts/map/definitions/outdoor/outdoor_map_factory.gd")


static func all() -> Array[MapDefinition]:
	return [
		_castle(&"haapsalu", &"loc.haapsalu_castle", &"coastal_bishop_castle", MapTypes.TERRAIN_MEADOW, ["res://scenes/world/haapsalu_castle.md"]),
		_castle(&"paide", &"loc.paide_castle", &"limestone_tower", MapTypes.TERRAIN_MEADOW, ["res://scenes/world/paide_castle.md"]),
		_castle(&"viljandi", &"loc.viljandi_castle", &"order_storehouse", MapTypes.TERRAIN_FARM_SOIL, ["res://scenes/world/viljandi_castle.md"]),
		_castle(&"poide", &"loc.poide_castle", &"island_chapel", MapTypes.TERRAIN_MUD, ["res://scenes/world/poide_castle.md"]),
		_castle(&"maasilinna", &"loc.maasilinna_castle", &"coastal_atonement_keep", MapTypes.TERRAIN_COAST_SAND, ["res://scenes/world/maasilinna_castle.md"], &"post_uprising_concept"),
		karja_fortress(),
	]


static func karja_fortress() -> MapDefinition:
	return Factory.create({
		"package": &"castles",
		"map_id": &"prototype.karja_fortress",
		"location": &"loc.karja_fortress",
		"size": Vector2i(48, 30),
		"base": MapTypes.TERRAIN_MEADOW,
		"spawn": Vector2i(4, 25),
		"sources": ["res://scenes/world/karja_fortress.md"],
		"zones": [
			Factory.zone(MapTypes.TERRAIN_MUD, Rect2i(7, 5, 34, 22)),
			Factory.zone(MapTypes.TERRAIN_DIRT, Rect2i(10, 8, 28, 16)),
			Factory.zone(MapTypes.TERRAIN_STRAW, Rect2i(14, 17, 8, 5)),
		],
		"excluded": [Rect2i(7, 5, 34, 2), Rect2i(7, 25, 34, 2)],
		"structures": [
			Factory.structure(&"palisade_north", &"palisade", Rect2i(8, 6, 32, 1), 44.0),
			Factory.structure(&"palisade_west", &"palisade", Rect2i(8, 6, 1, 20), 44.0),
			Factory.structure(&"palisade_east", &"palisade", Rect2i(39, 6, 1, 20), 44.0),
			Factory.structure(&"gatehouse", &"gatehouse", Rect2i(21, 24, 6, 3), 58.0),
			Factory.structure(&"longhouse", &"timber_hall", Rect2i(14, 10, 10, 5), 58.0),
		],
		"props": [
			Factory.prop(&"council_fire", &"campfire", Vector2i(30, 17)),
			Factory.prop(&"supply_cart", &"cart", Vector2i(17, 21)),
		],
		"landmarks": [
			Factory.landmark(&"palisade_gate", &"gatehouse", Vector2i(24, 26)),
			Factory.landmark(&"rebel_longhouse", &"timber_hall", Vector2i(19, 15)),
			Factory.landmark(&"earthwork_ditch", &"ditch", Vector2i(8, 16)),
		],
		"route": [Vector2i(4, 25), Vector2i(12, 24), Vector2i(24, 24), Vector2i(30, 19), Vector2i(36, 12)],
	})


static func _castle(
	slug: StringName,
	location: StringName,
	special_landmark: StringName,
	outer_terrain: StringName,
	sources: Array,
	phase: StringName = &"concept"
) -> MapDefinition:
	return Factory.create({
		"package": &"castles",
		"map_id": StringName("prototype.%s_castle" % String(slug)),
		"location": location,
		"size": Vector2i(50, 30),
		"base": outer_terrain,
		"spawn": Vector2i(4, 26),
		"canonical_phase": phase,
		"sources": sources,
		"zones": [
			Factory.zone(MapTypes.TERRAIN_MUD, Rect2i(5, 4, 40, 23)),
			Factory.zone(MapTypes.TERRAIN_CASTLE_PAVING, Rect2i(9, 7, 32, 17)),
			Factory.zone(MapTypes.TERRAIN_STONE, Rect2i(20, 10, 11, 8)),
			Factory.zone(MapTypes.TERRAIN_DIRT, Rect2i(0, 25, 50, 4)),
		],
		"excluded": [Rect2i(5, 4, 40, 2), Rect2i(5, 25, 17, 2), Rect2i(28, 25, 17, 2)],
		"structures": [
			Factory.structure(&"curtain_north", &"wall", Rect2i(7, 5, 36, 1), 56.0),
			Factory.structure(&"curtain_west", &"wall", Rect2i(7, 5, 1, 21), 56.0),
			Factory.structure(&"curtain_east", &"wall", Rect2i(42, 5, 1, 21), 56.0),
			Factory.structure(&"gatehouse", &"gatehouse", Rect2i(22, 24, 6, 3), 76.0),
			Factory.structure(&"keep", &"stone_keep", Rect2i(20, 9, 11, 8), 92.0),
			Factory.structure(&"chapel_or_hall", &"stone_hall", Rect2i(10, 9, 7, 6), 68.0),
			Factory.structure(&"storehouse", &"storehouse", Rect2i(33, 16, 7, 5), 54.0),
		],
		"props": [
			Factory.prop(&"yard_well", &"well", Vector2i(27, 20)),
			Factory.prop(&"supply_cart", &"cart", Vector2i(15, 20)),
		],
		"landmarks": [
			Factory.landmark(&"gatehouse", &"gatehouse", Vector2i(25, 26)),
			Factory.landmark(&"central_keep", &"stone_keep", Vector2i(25, 17)),
			Factory.landmark(&"special", special_landmark, Vector2i(13, 15)),
		],
		"route": [Vector2i(4, 26), Vector2i(15, 27), Vector2i(25, 27), Vector2i(25, 22), Vector2i(36, 22)],
	})
