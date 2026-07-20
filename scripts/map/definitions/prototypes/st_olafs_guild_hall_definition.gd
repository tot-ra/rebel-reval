class_name StOlafsGuildHallDefinition
extends RefCounted

## Inactive guild hall interior prototype (P4-014).


static func create() -> MapDefinition:
	var definition := MapDefinition.new()
	var inner := Rect2i(2, 2, 28, 16)
	InteriorMapFactory.init_definition(
		definition,
		&"st_olafs_guild_hall",
		&"loc.lower_town.st_olafs_guild_hall",
		&"prototype",
		false,
		&"clean_painted",
		Vector2i(32, 20),
		MapTypes.TERRAIN_TIMBER_FLOOR,
		"st_olafs_guild_hall_v1",
		Rect2i(14, 10, 2, 2)
	)

	InteriorMapFactory.add_floor_zone(definition, MapTypes.TERRAIN_STONE, Rect2i(12, 4, 8, 3))
	InteriorMapFactory.add_floor_zone(definition, MapTypes.TERRAIN_PLASTER, Rect2i(4, 12, 24, 4))
	InteriorMapFactory.add_perimeter_walls(
		definition,
		inner,
		1,
		56.0,
		Color(0.42, 0.40, 0.36),
		Rect2i(14, 17, 4, 1)
	)
	InteriorMapFactory.add_interior_block(definition, &"dais_block", Rect2i(13, 5, 6, 2))
	InteriorMapFactory.add_prop_at_cell(definition, &"long_table_a", MapTypes.PROP_KIND_TABLE, Rect2i(8, 10, 6, 2))
	InteriorMapFactory.add_prop_at_cell(definition, &"long_table_b", MapTypes.PROP_KIND_TABLE, Rect2i(18, 10, 6, 2))
	InteriorMapFactory.add_prop_at_cell(definition, &"guild_chest", MapTypes.PROP_KIND_CHEST, Rect2i(6, 6, 2, 2))
	InteriorMapFactory.add_prop_at_cell(definition, &"guild_hearth", MapTypes.PROP_KIND_HEARTH, Rect2i(22, 6, 3, 2))
	InteriorMapFactory.add_interaction_anchor(definition, &"inspection_spawn", Rect2i(14, 10, 2, 2))
	InteriorMapFactory.add_interaction_anchor(definition, &"dais", Rect2i(14, 5, 4, 2))
	InteriorMapFactory.add_transition(
		definition,
		&"to_reval_center",
		Rect2i(14, 17, 4, 2),
		&"reval_center",
		&"to_guild_hall",
		&"from_reval_center",
		# Clear the 4x2 door volume plus player capsule so return trips do not loop.
		Vector2(0.0, -96.0),
		true
	)
	InteriorMapFactory.add_fade_volume(definition, Rect2i(10, 3, 12, 3))
	InteriorMapFactory.add_source_references(
		definition,
		[
			"scenes/reval_center/market_civic_quarter/olaf_guild_hall.tscn",
			"scenes/reval_center/market_civic_quarter/st_olafs_guild_hall.md",
		]
	)
	return definition
