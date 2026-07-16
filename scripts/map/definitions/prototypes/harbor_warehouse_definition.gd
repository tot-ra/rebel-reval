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
		"harbor_warehouse_v1",
		Rect2i(18, 12, 2, 2)
	)

	InteriorMapFactory.add_floor_zone(definition, MapTypes.TERRAIN_STONE, Rect2i(6, 16, 28, 4))
	InteriorMapFactory.add_perimeter_walls(
		definition,
		inner,
		1,
		52.0,
		Color(0.40, 0.36, 0.32),
		Rect2i(17, 20, 6, 1)
	)
	InteriorMapFactory.add_prop_at_cell(definition, &"cargo_crates", MapTypes.PROP_KIND_BARRELS, Rect2i(8, 10, 3, 2))
	InteriorMapFactory.add_prop_at_cell(definition, &"cargo_crates_b", MapTypes.PROP_KIND_BARRELS, Rect2i(26, 10, 3, 2))
	InteriorMapFactory.add_prop_at_cell(definition, &"loading_cart", MapTypes.PROP_KIND_CART, Rect2i(16, 14, 3, 2))
	InteriorMapFactory.add_prop_at_cell(definition, &"quay_stairs", MapTypes.PROP_KIND_STAIRS, Rect2i(18, 18, 4, 2))
	InteriorMapFactory.add_interaction_anchor(definition, &"inspection_spawn", Rect2i(18, 12, 2, 2))
	InteriorMapFactory.add_interaction_anchor(definition, &"loading_bay", Rect2i(16, 14, 3, 2))
	InteriorMapFactory.add_fade_volume(definition, Rect2i(12, 4, 16, 3))
	InteriorMapFactory.add_source_references(
		definition,
		[
			"scenes/harbor/warehouses.md",
			"scenes/harbor/harbor.md",
		]
	)
	return definition
