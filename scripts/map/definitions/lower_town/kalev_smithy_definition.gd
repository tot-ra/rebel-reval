class_name KalevSmithyDefinition
extends RefCounted

## Production interior for Kalev's forge (P2-018).


static func create() -> MapDefinition:
	var definition := MapDefinition.new()
	var inner := Rect2i(2, 2, 36, 20)
	InteriorMapFactory.init_definition(
		definition,
		&"kalev_smithy",
		&"loc.kalev_smithy",
		&"production",
		true,
		&"clean_painted",
		Vector2i(40, 24),
		MapTypes.TERRAIN_STONE,
		"kalev_smithy_v1",
		Rect2i(18, 14, 2, 2)
	)

	InteriorMapFactory.add_floor_zone(definition, MapTypes.TERRAIN_DIRT, Rect2i(10, 10, 16, 8))
	InteriorMapFactory.add_floor_zone(definition, MapTypes.TERRAIN_ASH, Rect2i(28, 8, 6, 6))
	InteriorMapFactory.add_floor_zone(definition, MapTypes.TERRAIN_TIMBER_FLOOR, Rect2i(4, 14, 8, 5))
	InteriorMapFactory.add_floor_zone(definition, MapTypes.TERRAIN_PLASTER, Rect2i(30, 14, 6, 5))

	InteriorMapFactory.add_perimeter_walls(
		definition,
		inner,
		1,
		56.0,
		Color(0.46, 0.44, 0.40),
		Rect2i(17, 21, 6, 1)
	)
	InteriorMapFactory.add_interior_block(definition, &"furnace_mass", Rect2i(29, 7, 5, 4), 64.0)
	InteriorMapFactory.add_interior_block(definition, &"bed_alcove_mass", Rect2i(31, 14, 5, 4), 48.0)
	InteriorMapFactory.add_interior_block(definition, &"storage_mass", Rect2i(4, 5, 4, 3), 40.0)
	InteriorMapFactory.add_interior_block(definition, &"foreground_wall", Rect2i(14, 3, 12, 2), 72.0)

	definition.excluded_areas = [Rect2i(14, 3, 12, 2)]

	InteriorMapFactory.add_prop_at_cell(definition, &"forge_anvil", MapTypes.PROP_KIND_ANVIL, Rect2i(16, 12, 4, 3))
	InteriorMapFactory.add_prop_at_cell(definition, &"forge_furnace", MapTypes.PROP_KIND_FURNACE, Rect2i(29, 8, 3, 3))
	InteriorMapFactory.add_prop_at_cell(definition, &"forge_ledger", MapTypes.PROP_KIND_LEDGER, Rect2i(8, 12, 3, 2))
	InteriorMapFactory.add_prop_at_cell(definition, &"quench", MapTypes.PROP_KIND_QUENCH, Rect2i(22, 12, 3, 2))
	InteriorMapFactory.add_prop_at_cell(definition, &"bed", MapTypes.PROP_KIND_BED, Rect2i(31, 15, 4, 3))
	InteriorMapFactory.add_prop_at_cell(definition, &"chest", MapTypes.PROP_KIND_CHEST, Rect2i(5, 15, 2, 2))
	InteriorMapFactory.add_prop_at_cell(definition, &"food_table", MapTypes.PROP_KIND_TABLE, Rect2i(6, 17, 3, 2))
	InteriorMapFactory.add_prop_at_cell(definition, &"tool_shelf", MapTypes.PROP_KIND_SHELF, Rect2i(5, 6, 2, 2))

	InteriorMapFactory.add_interaction_anchor(definition, &"anvil", Rect2i(16, 12, 4, 3))
	InteriorMapFactory.add_interaction_anchor(definition, &"ledger", Rect2i(8, 12, 3, 2))
	InteriorMapFactory.add_interaction_anchor(definition, &"bed_alcove", Rect2i(29, 16, 2, 2))

	InteriorMapFactory.add_transition(
		definition,
		&"door_courtyard",
		Rect2i(17, 21, 6, 1),
		&"reval_east",
		&"forge",
		&"door_courtyard",
		Vector2(0.0, -48.0)
	)
	# New-game entry uses the authored player_spawn, not the courtyard doorway.
	InteriorMapFactory.add_transition(
		definition,
		&"smithy_start_spawn",
		Rect2i(18, 14, 2, 2),
		&"",
		&"",
		&"smithy_start"
	)
	InteriorMapFactory.add_fade_volume(definition, Rect2i(14, 3, 12, 3))
	InteriorMapFactory.add_source_references(
		definition,
		[
			"scenes/reval_east/forge/forge.tscn",
			"docs/SCENES/the-makers-mark.md",
			"content/locations/loc.kalev_smithy.json",
		]
	)
	return definition
