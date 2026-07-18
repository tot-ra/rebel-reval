class_name HarborWarehouseDefinition
extends RefCounted

## Inactive harbor warehouse interior prototype (scope expansion ADR 0006).


static func create() -> MapDefinition:
	var definition := MapDefinition.new()
	var inner := Rect2i(3, 3, 34, 18)
	InteriorMapFactory.init_definition(
		definition,
		&"harbor_warehouse",
		&"loc.reval_harbor.warehouse",
		&"prototype",
		false,
		&"clean_painted",
		Vector2i(40, 24),
		MapTypes.TERRAIN_TIMBER_FLOOR,
		"harbor_warehouse_v2_street_entry",
		Rect2i(18, 12, 2, 2)
	)

	InteriorMapFactory.add_floor_zone(definition, MapTypes.TERRAIN_STONE, Rect2i(6, 16, 28, 4))
	InteriorMapFactory.add_perimeter_walls(
		definition,
		inner,
		1,
		52.0,
		Color(0.40, 0.36, 0.32),
		Rect2i(17, 21, 6, 1),
		Rect2i(17, 2, 6, 1)
	)
	InteriorMapFactory.add_prop_at_cell(definition, &"cargo_crates", MapTypes.PROP_KIND_BARRELS, Rect2i(8, 10, 3, 2))
	InteriorMapFactory.add_prop_at_cell(definition, &"cargo_crates_b", MapTypes.PROP_KIND_BARRELS, Rect2i(26, 10, 3, 2))
	InteriorMapFactory.add_prop_at_cell(definition, &"loading_cart", MapTypes.PROP_KIND_CART, Rect2i(16, 14, 3, 2))
	InteriorMapFactory.add_prop_at_cell(definition, &"quay_stairs", MapTypes.PROP_KIND_STAIRS, Rect2i(18, 18, 4, 2))
	InteriorMapFactory.add_interaction_anchor(definition, &"inspection_spawn", Rect2i(18, 12, 2, 2))
	InteriorMapFactory.add_interaction_anchor(definition, &"loading_bay", Rect2i(16, 14, 3, 2))

	definition.view_landmarks = [
		{"id": &"street_entry_arch", "kind": &"gate_arch", "rect": definition.cell_rect_to_world_rect(Rect2i(17, 2, 6, 1)), "wall_color": Color(0.46, 0.42, 0.38), "top_px": 120.0, "passage_axis": &"x", "door_material": &"wood"},
		{"id": &"quay_entry_arch", "kind": &"gate_arch", "rect": definition.cell_rect_to_world_rect(Rect2i(17, 21, 6, 1)), "wall_color": Color(0.46, 0.42, 0.38), "top_px": 120.0, "passage_axis": &"x", "door_material": &"wood"},
	]

	InteriorMapFactory.add_transition(
		definition,
		&"to_reval_east",
		Rect2i(17, 2, 6, 1),
		&"reval_east",
		&"viru_road_boundary",
		&"from_reval_east",
		Vector2(-48.0, 0.0),
		true,
		&"street_entry_arch"
	)
	InteriorMapFactory.add_transition(
		definition,
		&"quay_exit",
		Rect2i(17, 21, 6, 1),
		&"reval_harbor",
		&"quay_plaza",
		&"quay_plaza",
		Vector2.ZERO,
		false,
		&"quay_entry_arch"
	)
	InteriorMapFactory.add_fade_volume(definition, Rect2i(12, 4, 16, 3))
	InteriorMapFactory.add_source_references(
		definition,
		[
			"scenes/harbor/warehouses.md",
			"scenes/harbor/harbor.md",
		]
	)
	return definition
