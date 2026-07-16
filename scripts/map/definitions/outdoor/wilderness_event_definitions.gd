class_name WildernessEventDefinitions
extends RefCounted

const Factory := preload("res://scripts/map/definitions/outdoor/outdoor_map_factory.gd")


static func all() -> Array[MapDefinition]:
	return [
		sacred_grove(),
		_event(&"pernau", &"loc.parnu", &"town_barricade", MapTypes.TERRAIN_MUD, ["res://scenes/events/pernau.md"]),
		_event(&"pskov_arrival_battle", &"event.pskov_arrival_battle", &"opposing_field_camps", MapTypes.TERRAIN_MEADOW, ["res://scenes/events/pskov_arrival_battle.md"]),
		_event(&"rebel_kings_camp", &"event.rebel_kings_camp", &"council_camp", MapTypes.TERRAIN_MEADOW, ["res://scenes/events/rebel_kings.md"]),
		_event(&"saaremaa", &"loc.saaremaa", &"island_coast_reference", MapTypes.TERRAIN_BOG, ["res://scenes/events/saaremaa.md"]),
		_event(&"swedish_outpost", &"loc.swedish_outpost", &"timber_stockade", MapTypes.TERRAIN_FOREST_FLOOR, ["res://scenes/events/swedesh_outpost.md"]),
		_event(&"swedish_arrival", &"event.swedish_arrival", &"fleet_signal_shore", MapTypes.TERRAIN_COAST_SAND, ["res://scenes/events/swedish_arrival.md"]),
	]


static func sacred_grove() -> MapDefinition:
	return Factory.create({
		"package": &"wilderness_events",
		"map_id": &"prototype.sacred_grove",
		"location": &"loc.sacred_grove",
		"size": Vector2i(46, 28),
		"base": MapTypes.TERRAIN_FOREST_FLOOR,
		"spawn": Vector2i(4, 23),
		"sources": ["res://scenes/world/sacred_grove.md", "res://docs/CANON.md"],
		"zones": [
			Factory.zone(MapTypes.TERRAIN_MEADOW, Rect2i(12, 6, 22, 16)),
			Factory.zone(MapTypes.TERRAIN_BOG, Rect2i(34, 4, 10, 18)),
			Factory.zone(MapTypes.TERRAIN_SHALLOW_WATER, Rect2i(36, 7, 6, 11)),
			Factory.zone(MapTypes.TERRAIN_MUD, Rect2i(6, 21, 32, 4)),
		],
		"excluded": [Rect2i(36, 7, 6, 11)],
		"structures": [
			Factory.structure(&"oak_ring_north", &"tree_line", Rect2i(12, 5, 22, 1), 62.0),
			Factory.structure(&"oak_ring_west", &"tree_line", Rect2i(11, 6, 1, 16), 62.0),
			Factory.structure(&"oak_ring_east", &"tree_line", Rect2i(34, 6, 1, 16), 62.0),
		],
		"props": [
			Factory.prop(&"offering_stone", &"offering_stone", Vector2i(23, 14)),
			Factory.prop(&"ancient_oak", &"ancient_tree", Vector2i(23, 9)),
			Factory.prop(&"spring_marker", &"spring", Vector2i(35, 18)),
		],
		"landmarks": [
			Factory.landmark(&"ancient_oak", &"ancient_tree", Vector2i(23, 9)),
			Factory.landmark(&"offering_stone", &"offering_stone", Vector2i(23, 14)),
			Factory.landmark(&"bog_spring", &"spring", Vector2i(35, 18)),
		],
		"route": [Vector2i(4, 23), Vector2i(12, 23), Vector2i(18, 18), Vector2i(23, 14), Vector2i(28, 10)],
	})


static func _event(
	slug: StringName,
	location: StringName,
	landmark_kind: StringName,
	base: StringName,
	sources: Array
) -> MapDefinition:
	var water_event := slug in [&"saaremaa", &"swedish_arrival"]
	var stockade_event := slug == &"swedish_outpost"
	var zones: Array[Dictionary] = [
		Factory.zone(MapTypes.TERRAIN_DIRT, Rect2i(3, 12, 44, 6)),
		Factory.zone(MapTypes.TERRAIN_MUD, Rect2i(12, 18, 26, 5)),
		Factory.zone(MapTypes.TERRAIN_STRAW, Rect2i(6, 5, 10, 5)),
	]
	var excluded: Array[Rect2i] = []
	if water_event:
		zones.append(Factory.zone(MapTypes.TERRAIN_SHALLOW_WATER, Rect2i(0, 0, 50, 6)))
		zones.append(Factory.zone(MapTypes.TERRAIN_DEEP_WATER, Rect2i(0, 0, 50, 3)))
		excluded.append(Rect2i(0, 0, 50, 6))

	var structures: Array[Dictionary] = [
		Factory.structure(&"west_camp", &"camp", Rect2i(6, 6, 10, 5), 34.0),
		Factory.structure(&"east_camp", &"camp", Rect2i(34, 6, 10, 5), 34.0),
		Factory.structure(&"supply_shelter", &"work_shed", Rect2i(20, 19, 8, 4), 44.0),
	]
	if stockade_event:
		structures.append(Factory.structure(&"stockade_north", &"palisade", Rect2i(4, 5, 42, 1), 44.0))
		structures.append(Factory.structure(&"bailiff_hall", &"timber_hall", Rect2i(33, 17, 10, 5), 60.0))

	return Factory.create({
		"package": &"wilderness_events",
		"map_id": StringName("prototype.%s" % String(slug)),
		"location": location,
		"size": Vector2i(50, 28),
		"base": base,
		"spawn": Vector2i(4, 24),
		"sources": sources,
		"zones": zones,
		"excluded": excluded,
		"structures": structures,
		"props": [
			Factory.prop(&"central_signal", &"signal_fire", Vector2i(25, 15)),
			Factory.prop(&"supply_cart", &"cart", Vector2i(21, 22)),
			Factory.prop(&"field_standard", &"standard", Vector2i(32, 14)),
		],
		"landmarks": [
			Factory.landmark(&"primary", landmark_kind, Vector2i(25, 15)),
			Factory.landmark(&"west_camp", &"camp", Vector2i(11, 11)),
			Factory.landmark(&"east_camp", &"camp", Vector2i(39, 11)),
		],
		"route": [Vector2i(4, 24), Vector2i(14, 23), Vector2i(25, 23), Vector2i(36, 23), Vector2i(46, 24)],
	})
