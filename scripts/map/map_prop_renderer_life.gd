class_name MapPropLifeRenderer
extends RefCounted

## 2D renderer variants for the district-life and rural-life prop kits.
## Geometry and node names stay here so the public MapPropRenderer facade can
## route props without coupling unrelated visual domains.

const Draw := preload("res://scripts/map/map_prop_draw.gd")
const Harbor := preload("res://scripts/map/map_prop_renderer_harbor.gd")


static func draw_district_life_prop(
	parent: Node2D,
	kind: StringName,
	target: StringName,
	time_of_day: StringName
) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	var timber := MapVisualStyle.role_color(&"timber", target, time_of_day)
	var plaster := MapVisualStyle.role_color(&"plaster", target, time_of_day)
	var metal := MapVisualStyle.role_color(&"metal", target, time_of_day)
	var hay := MapVisualStyle.role_color(&"hay", target, time_of_day)
	var vegetation := MapVisualStyle.role_color(&"vegetation", target, time_of_day)
	var stone := MapVisualStyle.role_color(&"stone", target, time_of_day)
	match kind:
		MapTypes.PROP_KIND_FISHING_NETS, MapTypes.PROP_KIND_FISH_DRYING_RACK, MapTypes.PROP_KIND_SMOKE_RACK:
			Draw.add_rect(parent, "Frame", Vector2(-18, -24), Vector2(36, 6), timber, target, time_of_day)
			Draw.add_line(parent, "Mesh", PackedVector2Array([Vector2(-14, -18), Vector2(14, -18), Vector2(14, 6), Vector2(-14, 6)]), target, time_of_day, &"plaster")
		MapTypes.PROP_KIND_FISH_SPLITTING_TABLE:
			Draw.add_rect(parent, "Top", Vector2(-20, -10), Vector2(40, 8), wood, target, time_of_day)
			Draw.add_rect(parent, "Slab", Vector2(4, -16), Vector2(12, 4), stone, target, time_of_day)
		MapTypes.PROP_KIND_BOAT_TIMBER_STACK:
			for index in 3:
				Draw.add_rect(parent, "Log%d" % index, Vector2(-16 + index * 5, -6 - index * 2), Vector2(28, 5), wood.darkened(index * 0.04), target, time_of_day)
		MapTypes.PROP_KIND_FIREWOOD_STACK:
			for index in 3:
				Draw.add_rect(parent, "Billet%d" % index, Vector2(-14 + index * 4, -4 - index * 3), Vector2(22, 5), wood.darkened(index * 0.05), target, time_of_day)
		MapTypes.PROP_KIND_ROPE_COIL:
			Draw.add_circle(parent, "Coil", Vector2(0, 0), 11.0, hay, target, time_of_day)
		MapTypes.PROP_KIND_SAIL_CLOTH_BALE, MapTypes.PROP_KIND_MALT_SACK_PILE, MapTypes.PROP_KIND_SALT_PILE:
			Draw.add_rect(parent, "Bale", Vector2(-14, -10), Vector2(28, 14), plaster, target, time_of_day)
		MapTypes.PROP_KIND_COOPER_STAVES:
			for index in 3:
				Draw.add_rect(parent, "Stave%d" % index, Vector2(-10 + index * 8, -18), Vector2(4, 22), wood, target, time_of_day)
		MapTypes.PROP_KIND_BREWERY_KEG_STACK:
			Draw.add_circle(parent, "KegLow", Vector2(-8, 2), 8.0, wood, target, time_of_day)
			Draw.add_circle(parent, "KegHigh", Vector2(8, -6), 8.0, wood.darkened(0.08), target, time_of_day)
		MapTypes.PROP_KIND_CHARCOAL_PILE:
			Draw.add_circle(parent, "Coal", Vector2(0, 0), 12.0, stone.darkened(0.35), target, time_of_day)
		MapTypes.PROP_KIND_IRON_SCRAP_PILE:
			Draw.add_rect(parent, "ScrapA", Vector2(-12, -4), Vector2(14, 6), metal, target, time_of_day)
			Draw.add_rect(parent, "ScrapB", Vector2(0, -10), Vector2(10, 8), metal.lightened(0.08), target, time_of_day)
		MapTypes.PROP_KIND_WEAPON_RACK:
			Draw.add_rect(parent, "Back", Vector2(-4, -20), Vector2(8, 24), wood, target, time_of_day)
			Draw.add_line(parent, "Blade", PackedVector2Array([Vector2(6, -18), Vector2(6, 4)]), target, time_of_day, &"metal")
		MapTypes.PROP_KIND_HERB_DRYING_RACK:
			Draw.add_rect(parent, "Bar", Vector2(-16, -18), Vector2(32, 4), timber, target, time_of_day)
			Draw.add_circle(parent, "Bundle", Vector2(0, -8), 6.0, vegetation, target, time_of_day)
		MapTypes.PROP_KIND_MARKET_GOODS_PALLET:
			Harbor.draw_trade_goods(parent, target, time_of_day)
		MapTypes.PROP_KIND_TANNING_FRAME:
			Draw.add_line(parent, "FrameL", PackedVector2Array([Vector2(-10, 8), Vector2(0, -18)]), target, time_of_day, &"timber")
			Draw.add_line(parent, "FrameR", PackedVector2Array([Vector2(10, 8), Vector2(0, -18)]), target, time_of_day, &"timber")
			Draw.add_rect(parent, "Hide", Vector2(-10, -10), Vector2(20, 16), plaster.darkened(0.12), target, time_of_day)
		MapTypes.PROP_KIND_WASH_TUB:
			Draw.add_circle(parent, "Tub", Vector2(0, 0), 10.0, wood, target, time_of_day)
			Draw.add_circle(parent, "Water", Vector2(0, -1), 7.0, MapVisualStyle.role_color(&"water_highlight", target, time_of_day), target, time_of_day)
		_:
			Draw.add_rect(parent, "Yard", Vector2(-10, -10), Vector2(20, 20), hay.darkened(0.1), target, time_of_day)


static func draw_rural_life_prop(
	parent: Node2D,
	kind: StringName,
	target: StringName,
	time_of_day: StringName
) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	var timber := MapVisualStyle.role_color(&"timber", target, time_of_day)
	var plaster := MapVisualStyle.role_color(&"plaster", target, time_of_day)
	var metal := MapVisualStyle.role_color(&"metal", target, time_of_day)
	var hay := MapVisualStyle.role_color(&"hay", target, time_of_day)
	var vegetation := MapVisualStyle.role_color(&"vegetation", target, time_of_day)
	var stone := MapVisualStyle.role_color(&"stone", target, time_of_day)
	match kind:
		MapTypes.PROP_KIND_KITCHEN_GARDEN:
			Draw.add_rect(parent, "BedNorth", Vector2(-18, -16), Vector2(36, 10), stone.darkened(0.12), target, time_of_day)
			Draw.add_rect(parent, "BedSouth", Vector2(-18, 6), Vector2(36, 10), stone.darkened(0.12), target, time_of_day)
			for index in 3:
				Draw.add_circle(parent, "Leaf%d" % index, Vector2(-10 + index * 10, -10), 4.0, vegetation, target, time_of_day)
		MapTypes.PROP_KIND_FIELD_STRIP:
			for index in 3:
				Draw.add_rect(parent, "Furrow%d" % index, Vector2(-20, -10 + index * 8), Vector2(40, 4), stone.darkened(0.08), target, time_of_day)
		MapTypes.PROP_KIND_HAY_WAGON:
			Draw.add_rect(parent, "Bed", Vector2(-16, -8), Vector2(32, 16), wood, target, time_of_day)
			Draw.add_circle(parent, "Load", Vector2(0, -2), 12.0, hay, target, time_of_day)
		MapTypes.PROP_KIND_PASTURE_FENCE:
			Draw.add_rect(parent, "Rail", Vector2(-20, -4), Vector2(40, 4), timber, target, time_of_day)
			for index in 4:
				Draw.add_rect(parent, "Post%d" % index, Vector2(-18 + index * 12, -10), Vector2(4, 14), wood, target, time_of_day)
		MapTypes.PROP_KIND_PIGSTY:
			Draw.add_rect(parent, "Pen", Vector2(-16, -10), Vector2(32, 20), stone.darkened(0.18), target, time_of_day)
			Draw.add_rect(parent, "Roof", Vector2(-14, -14), Vector2(28, 6), hay, target, time_of_day)
		MapTypes.PROP_KIND_CHICKEN_RUN:
			Draw.add_rect(parent, "Frame", Vector2(-16, -12), Vector2(32, 24), timber, target, time_of_day)
			for index in 3:
				Draw.add_circle(parent, "Hen%d" % index, Vector2(-8 + index * 8, 2), 3.0, plaster, target, time_of_day)
		MapTypes.PROP_KIND_FLAX_DRYING_FRAME:
			Draw.add_rect(parent, "Bar", Vector2(-18, -18), Vector2(36, 4), timber, target, time_of_day)
			for index in 3:
				Draw.add_rect(parent, "Bundle%d" % index, Vector2(-10 + index * 10, -12), Vector2(4, 16), hay, target, time_of_day)
		MapTypes.PROP_KIND_ROOT_CELLAR_MOUND:
			Draw.add_circle(parent, "Mound", Vector2(0, 0), 14.0, stone.darkened(0.1), target, time_of_day)
			Draw.add_rect(parent, "Door", Vector2(-8, -2), Vector2(16, 10), timber, target, time_of_day)
		MapTypes.PROP_KIND_ORCHARD_ROW:
			for index in 3:
				Draw.add_circle(parent, "Crown%d" % index, Vector2(-12 + index * 12, -6), 7.0, vegetation, target, time_of_day)
				Draw.add_rect(parent, "Trunk%d" % index, Vector2(-2 + index * 12, 2), Vector2(4, 8), wood, target, time_of_day)
		MapTypes.PROP_KIND_FARM_CART:
			Draw.add_rect(parent, "Bed", Vector2(-14, -6), Vector2(28, 12), wood, target, time_of_day)
			Draw.add_rect(parent, "Crate", Vector2(-6, -10), Vector2(12, 8), plaster, target, time_of_day)
		MapTypes.PROP_KIND_PITCHFORK:
			Draw.add_line(parent, "Shaft", PackedVector2Array([Vector2(-7, 12), Vector2(3, -24)]), target, time_of_day, &"wood")
			for tine in 3:
				var tine_x := -4.0 + float(tine) * 5.0
				Draw.add_line(parent, "Tine%d" % tine, PackedVector2Array([Vector2(3, -24), Vector2(tine_x, -36)]), target, time_of_day, &"metal")
		MapTypes.PROP_KIND_SCYTHE:
			Draw.add_line(parent, "Snath", PackedVector2Array([Vector2(-8, 12), Vector2(0, -8), Vector2(6, -28)]), target, time_of_day, &"wood")
			Draw.add_line(parent, "Grip", PackedVector2Array([Vector2(-1, -8), Vector2(-10, -13)]), target, time_of_day, &"wood")
			Draw.add_polygon(parent, "Blade", PackedVector2Array([Vector2(-8, 12), Vector2(9, 10), Vector2(25, 3), Vector2(20, 9), Vector2(5, 14)]), metal, target, time_of_day)
		MapTypes.PROP_KIND_SICKLE:
			Draw.add_line(parent, "Grip", PackedVector2Array([Vector2(-8, 12), Vector2(-2, -4)]), target, time_of_day, &"wood")
			Draw.add_polygon(parent, "Blade", PackedVector2Array([Vector2(-3, -5), Vector2(6, -17), Vector2(20, -23), Vector2(27, -19), Vector2(17, -15), Vector2(7, -8)]), metal, target, time_of_day)
		MapTypes.PROP_KIND_RAKE:
			Draw.add_line(parent, "Shaft", PackedVector2Array([Vector2(-4, 13), Vector2(3, -28)]), target, time_of_day, &"wood")
			Draw.add_line(parent, "Head", PackedVector2Array([Vector2(-17, -27), Vector2(22, -30)]), target, time_of_day, &"wood")
			for tooth in 6:
				var tooth_x := -15.0 + float(tooth) * 7.0
				Draw.add_line(parent, "Tooth%d" % tooth, PackedVector2Array([Vector2(tooth_x, -28), Vector2(tooth_x, -36)]), target, time_of_day, &"wood")
		MapTypes.PROP_KIND_WOODEN_SHOVEL:
			Draw.add_line(parent, "Shaft", PackedVector2Array([Vector2(0, 8), Vector2(0, -27)]), target, time_of_day, &"wood")
			Draw.add_line(parent, "Grip", PackedVector2Array([Vector2(-7, -28), Vector2(7, -28)]), target, time_of_day, &"wood")
			Draw.add_polygon(parent, "Blade", PackedVector2Array([Vector2(-11, 8), Vector2(11, 8), Vector2(9, 23), Vector2(0, 28), Vector2(-9, 23)]), wood, target, time_of_day)
		_:
			Draw.add_rect(parent, "Yard", Vector2(-10, -10), Vector2(20, 20), hay.darkened(0.1), target, time_of_day)
