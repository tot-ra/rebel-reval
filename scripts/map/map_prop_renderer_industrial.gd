class_name MapPropIndustrialRenderer
extends RefCounted

## 2D renderers for forge, household, market, and indoor props.
## Geometry and node names stay here so the public MapPropRenderer facade can
## route props without coupling unrelated visual domains.

const Draw := preload("res://scripts/map/map_prop_draw.gd")


static func draw_anvil(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var metal := MapVisualStyle.role_color(&"metal", target, time_of_day)
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	Draw.add_rect(parent, "Stump", Vector2(-14, -2), Vector2(28, 14), wood.darkened(0.08), target, time_of_day)
	# Horned London-pattern silhouette so the 2D stand-in matches the 3D mesh.
	Draw.add_polygon(
		parent,
		"AnvilBody",
		PackedVector2Array([
			Vector2(-28, -18),
			Vector2(-10, -24),
			Vector2(12, -24),
			Vector2(22, -20),
			Vector2(26, -12),
			Vector2(18, -8),
			Vector2(8, -8),
			Vector2(4, -14),
			Vector2(-8, -14),
			Vector2(-16, -10),
		]),
		metal,
		target,
		time_of_day
	)
	Draw.add_rect(parent, "Face", Vector2(-12, -26), Vector2(26, 5), metal.lightened(0.16), target, time_of_day)


static func draw_hay_stack(parent: Node2D, prop: Dictionary, target: StringName, time_of_day: StringName) -> void:
	var hay := MapVisualStyle.role_color(&"hay", target, time_of_day)
	var size_variant := StringName(prop.get("style_variant", MapPropStyleVariants.DEFAULT_HAY_STACK_VARIANT))
	var scale_by_variant := {
		MapPropStyleVariants.HAY_STACK_SMALL: Vector2(0.74, 0.72),
		MapPropStyleVariants.HAY_STACK_MEDIUM: Vector2.ONE,
		MapPropStyleVariants.HAY_STACK_TALL: Vector2(1.08, 1.62),
	}
	var size_scale: Vector2 = scale_by_variant.get(size_variant, Vector2.ONE)
	# A layered rick silhouette keeps the overview map aligned with the rounded 3D
	# profile while still making tall stacks visibly taller than the player marker.
	Draw.add_polygon(
		parent,
		"RickBody",
		PackedVector2Array([
			Vector2(-25.0 * size_scale.x, 0.0),
			Vector2(-27.0 * size_scale.x, -13.0 * size_scale.y),
			Vector2(-21.0 * size_scale.x, -29.0 * size_scale.y),
			Vector2(-11.0 * size_scale.x, -42.0 * size_scale.y),
			Vector2(1.0 * size_scale.x, -48.0 * size_scale.y),
			Vector2(13.0 * size_scale.x, -39.0 * size_scale.y),
			Vector2(23.0 * size_scale.x, -24.0 * size_scale.y),
			Vector2(27.0 * size_scale.x, -8.0 * size_scale.y),
			Vector2(20.0 * size_scale.x, 0.0),
		]),
		hay,
		target,
		time_of_day
	)
	if target == MapVisualStyle.TARGET_WOODCUT:
		for index in 3:
			var y := (-10.0 - float(index) * 11.0) * size_scale.y
			Draw.add_line(
				parent,
				"StrawLayer%d" % index,
				PackedVector2Array([
					Vector2(-20.0 * size_scale.x, y),
					Vector2(19.0 * size_scale.x, y - 3.0 * size_scale.y),
				]),
				target,
				time_of_day
			)


static func draw_cart(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	Draw.add_rect(parent, "Bed", Vector2(-29, -18), Vector2(58, 19), wood, target, time_of_day)
	Draw.add_circle(parent, "WheelL", Vector2(-20, 4), 9.0, wood.darkened(0.28), target, time_of_day)
	Draw.add_circle(parent, "WheelR", Vector2(20, 4), 9.0, wood.darkened(0.28), target, time_of_day)
	Draw.add_rect(parent, "Shaft", Vector2(26, -6), Vector2(25, 4), wood.darkened(0.12), target, time_of_day)



static func draw_well(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var stone := MapVisualStyle.role_color(&"stone", target, time_of_day)
	var water := MapVisualStyle.terrain_color(MapTypes.TERRAIN_WATER, target, time_of_day)
	Draw.add_circle(parent, "Rim", Vector2(0, -9), 23.0, stone, target, time_of_day)
	Draw.add_circle(parent, "Water", Vector2(0, -10), 14.0, water, target, time_of_day)
	Draw.add_rect(parent, "Curb", Vector2(-24, -4), Vector2(48, 8), stone.darkened(0.10), target, time_of_day)
	Draw.add_line(parent, "WaterGlint", PackedVector2Array([Vector2(-8, -12), Vector2(8, -12)]), target, time_of_day, &"water_highlight")


static func draw_furnace(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var stone := MapVisualStyle.role_color(&"stone", target, time_of_day)
	var ember := MapVisualStyle.role_color(&"ember", target, time_of_day)
	var ink := MapVisualStyle.role_color(&"ink", target, time_of_day)
	Draw.add_rect(parent, "FurnaceBase", Vector2(-42, -26), Vector2(84, 48), stone.darkened(0.10), target, time_of_day)
	Draw.add_rect(parent, "LeftCheek", Vector2(-34, -16), Vector2(12, 30), stone, target, time_of_day)
	Draw.add_rect(parent, "RightCheek", Vector2(22, -16), Vector2(12, 30), stone, target, time_of_day)
	Draw.add_rect(parent, "Firebox", Vector2(-20, -12), Vector2(40, 22), ink.lightened(0.05), target, time_of_day)
	Draw.add_rect(parent, "CoalBed", Vector2(-16, -2), Vector2(32, 10), ember.darkened(0.25), target, time_of_day)
	Draw.add_rect(parent, "FireMouth", Vector2(-12, -14), Vector2(24, 16), ember, target, time_of_day)
	Draw.add_rect(parent, "Chimney", Vector2(-14, -58), Vector2(28, 34), stone, target, time_of_day)


static func draw_bellows(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	var metal := MapVisualStyle.role_color(&"metal", target, time_of_day)
	var leather := wood.darkened(0.22).lerp(Color8(92, 58, 34), 0.65)
	Draw.add_rect(parent, "Stand", Vector2(-16, 2), Vector2(28, 8), wood.darkened(0.12), target, time_of_day)
	Draw.add_rect(parent, "BoardBottom", Vector2(-18, -4), Vector2(34, 6), wood, target, time_of_day)
	Draw.add_rect(parent, "Leather", Vector2(-14, -16), Vector2(26, 12), leather, target, time_of_day)
	Draw.add_rect(parent, "BoardTop", Vector2(-16, -22), Vector2(30, 6), wood.lightened(0.05), target, time_of_day)
	Draw.add_rect(parent, "Nozzle", Vector2(14, -10), Vector2(18, 5), metal, target, time_of_day)
	Draw.add_rect(parent, "Lever", Vector2(-20, -34), Vector2(5, 14), wood.darkened(0.08), target, time_of_day)


static func draw_ledger(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	Draw.add_rect(parent, "LedgerDesk", Vector2(-20, -10), Vector2(40, 14), wood, target, time_of_day)
	Draw.add_rect(parent, "LedgerBook", Vector2(-10, -18), Vector2(20, 10), wood.lightened(0.18), target, time_of_day)


static func draw_bed(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	var plaster := MapVisualStyle.role_color(&"plaster", target, time_of_day)
	Draw.add_rect(parent, "BedFrame", Vector2(-44, -14), Vector2(88, 26), wood, target, time_of_day)
	Draw.add_rect(parent, "BedRoll", Vector2(-36, -22), Vector2(72, 16), plaster.lightened(0.10), target, time_of_day)


static func draw_chest(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	Draw.add_rect(parent, "ChestBody", Vector2(-16, -12), Vector2(32, 20), wood.darkened(0.08), target, time_of_day)
	Draw.add_rect(parent, "ChestLid", Vector2(-16, -18), Vector2(32, 8), wood, target, time_of_day)


static func draw_table(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	Draw.add_rect(parent, "TableTop", Vector2(-36, -10), Vector2(72, 14), wood, target, time_of_day)
	Draw.add_rect(parent, "LegL", Vector2(-30, 4), Vector2(7, 14), wood.darkened(0.12), target, time_of_day)
	Draw.add_rect(parent, "LegR", Vector2(23, 4), Vector2(7, 14), wood.darkened(0.12), target, time_of_day)


static func draw_shelf(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	Draw.add_rect(parent, "ShelfBack", Vector2(-18, -28), Vector2(36, 34), wood.darkened(0.10), target, time_of_day)
	Draw.add_rect(parent, "ShelfMid", Vector2(-16, -10), Vector2(32, 4), wood, target, time_of_day)
	Draw.add_rect(parent, "ShelfTop", Vector2(-16, -24), Vector2(32, 4), wood, target, time_of_day)


static func draw_quench(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	var water := MapVisualStyle.terrain_color(MapTypes.TERRAIN_WATER, target, time_of_day)
	Draw.add_rect(parent, "Trough", Vector2(-18, -8), Vector2(36, 12), wood, target, time_of_day)
	Draw.add_rect(parent, "Water", Vector2(-14, -6), Vector2(28, 6), water, target, time_of_day)


static func draw_stairs(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var stone := MapVisualStyle.role_color(&"stone", target, time_of_day)
	for step in 4:
		var y := step * 5
		Draw.add_rect(parent, "Step%d" % step, Vector2(-20 + step * 3, -8 + y), Vector2(40 - step * 6, 5), stone.darkened(step * 0.04), target, time_of_day)


static func draw_stall(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	var plaster := MapVisualStyle.role_color(&"plaster", target, time_of_day)
	Draw.add_rect(parent, "StallCounter", Vector2(-22, -10), Vector2(44, 12), wood, target, time_of_day)
	Draw.add_polygon(parent, "Awning", PackedVector2Array([Vector2(-26, -18), Vector2(26, -18), Vector2(18, -28), Vector2(-18, -28)]), plaster.darkened(0.05), target, time_of_day)


static func draw_hearth(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var stone := MapVisualStyle.role_color(&"stone", target, time_of_day)
	var ember := MapVisualStyle.role_color(&"ember", target, time_of_day)
	Draw.add_rect(parent, "HearthBase", Vector2(-20, -10), Vector2(40, 16), stone, target, time_of_day)
	Draw.add_rect(parent, "HearthFire", Vector2(-10, -6), Vector2(20, 8), ember, target, time_of_day)


static func draw_kitchenware(parent: Node2D, prop: Dictionary, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	var pottery := MapVisualStyle.role_color(&"plaster", target, time_of_day).darkened(0.12)
	var variant := StringName(prop.get("style_variant", MapTypes.DEFAULT_KITCHENWARE_VARIANT))
	if variant.begins_with(&"kitchenware.group."):
		Draw.add_rect(parent, "GroupBase", Vector2(-18, -10), Vector2(36, 14), wood, target, time_of_day)
		Draw.add_rect(parent, "GroupAccent", Vector2(-10, -14), Vector2(20, 6), pottery, target, time_of_day)
		return
	match variant:
		MapTypes.KITCHENWARE_KNIFE, MapTypes.KITCHENWARE_SPOON:
			Draw.add_rect(parent, "Utensil", Vector2(-10, -2), Vector2(20, 4), wood, target, time_of_day)
		MapTypes.KITCHENWARE_JUG, MapTypes.KITCHENWARE_COOKING_POT_LIDDED:
			Draw.add_rect(parent, "Vessel", Vector2(-6, -12), Vector2(12, 16), pottery, target, time_of_day)
		MapTypes.KITCHENWARE_BASIN_CLOTH:
			Draw.add_circle(parent, "Basin", Vector2(0, -4), 10.0, wood, target, time_of_day)
		_:
			Draw.add_rect(parent, "Kitchenware", Vector2(-10, -6), Vector2(20, 10), wood, target, time_of_day)


static func draw_chair(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	Draw.add_rect(parent, "Seat", Vector2(-10, -4), Vector2(20, 8), wood, target, time_of_day)
	Draw.add_rect(parent, "Back", Vector2(-9, -18), Vector2(18, 14), wood.darkened(0.08), target, time_of_day)
	Draw.add_rect(parent, "LegL", Vector2(-8, 4), Vector2(4, 10), wood.darkened(0.14), target, time_of_day)
	Draw.add_rect(parent, "LegR", Vector2(4, 4), Vector2(4, 10), wood.darkened(0.14), target, time_of_day)


static func draw_candle(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var plaster := MapVisualStyle.role_color(&"plaster", target, time_of_day)
	var ember := MapVisualStyle.role_color(&"ember", target, time_of_day)
	Draw.add_rect(parent, "Holder", Vector2(-5, 2), Vector2(10, 6), MapVisualStyle.role_color(&"metal", target, time_of_day), target, time_of_day)
	Draw.add_rect(parent, "Wax", Vector2(-2, -6), Vector2(4, 10), plaster.lightened(0.12), target, time_of_day)
	Draw.add_circle(parent, "Flame", Vector2(0, -10), 4.0, ember, target, time_of_day)
