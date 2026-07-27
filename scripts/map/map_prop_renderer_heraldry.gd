class_name MapPropHeraldryRenderer
extends RefCounted

## 2D faction-banner renderer and its small heraldic charges.
## Geometry and node names stay here so the public MapPropRenderer facade can
## route props without coupling unrelated visual domains.

const Draw := preload("res://scripts/map/map_prop_draw.gd")


static func draw_banner(parent: Node2D, prop: Dictionary, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	var faction := FactionHeraldry.resolve(prop)
	var field := FactionHeraldry.field_color(faction)
	var charge := FactionHeraldry.charge_color(faction)
	if not FactionHeraldry.shows_flag(faction):
		return
	# Short wall arm + hanging cloth; matches the 3D wall-mount banner.
	Draw.add_rect(parent, "BannerMount", Vector2(-4, -48), Vector2(8, 8), wood.darkened(0.12), target, time_of_day)
	Draw.add_rect(parent, "BannerArm", Vector2(2, -46), Vector2(22, 4), wood.darkened(0.08), target, time_of_day)
	Draw.add_rect(parent, "BannerField", Vector2(4, -44), Vector2(26, 34), field, target, time_of_day)
	match FactionHeraldry.pattern_for(faction):
		FactionHeraldry.PATTERN_CROSS:
			Draw.add_rect(parent, "BannerCrossV", Vector2(14, -44), Vector2(6, 34), charge, target, time_of_day)
			Draw.add_rect(parent, "BannerCrossH", Vector2(4, -30), Vector2(26, 6), charge, target, time_of_day)
		FactionHeraldry.PATTERN_PALE:
			Draw.add_rect(parent, "BannerPale", Vector2(4, -44), Vector2(13, 34), charge, target, time_of_day)
		FactionHeraldry.PATTERN_FESS:
			Draw.add_rect(parent, "BannerFess", Vector2(4, -44), Vector2(26, 17), charge, target, time_of_day)
		FactionHeraldry.PATTERN_BEAR:
			draw_banner_bear(parent, charge, target, time_of_day)
		FactionHeraldry.PATTERN_LYNX:
			draw_banner_lynx(parent, charge, target, time_of_day)
		FactionHeraldry.PATTERN_BEAR_LYNX:
			draw_banner_bear(parent, FactionHeraldry.secondary_charge_color(faction), target, time_of_day)
			draw_banner_lynx(parent, charge, target, time_of_day)
		FactionHeraldry.PATTERN_SWALLOW:
			draw_banner_swallow(parent, charge, target, time_of_day)


## 2D stand-ins for beast charges; UV silhouettes live in FactionHeraldry for 3D.
static func draw_banner_bear(parent: Node2D, charge: Color, target: StringName, time_of_day: StringName) -> void:
	Draw.add_circle(parent, "BearBody", Vector2(14, -30), 7.0, charge, target, time_of_day)
	Draw.add_circle(parent, "BearHead", Vector2(20, -40), 4.5, charge, target, time_of_day)
	Draw.add_circle(parent, "BearSnout", Vector2(24, -39), 2.5, charge, target, time_of_day)
	Draw.add_rect(parent, "BearLegF", Vector2(16, -24), Vector2(3, 8), charge, target, time_of_day)
	Draw.add_rect(parent, "BearLegR", Vector2(10, -24), Vector2(3, 8), charge, target, time_of_day)
	Draw.add_polygon(
		parent,
		"BearArm",
		PackedVector2Array([Vector2(16, -34), Vector2(24, -30), Vector2(23, -27), Vector2(15, -31)]),
		charge,
		target,
		time_of_day
	)


static func draw_banner_lynx(parent: Node2D, charge: Color, target: StringName, time_of_day: StringName) -> void:
	Draw.add_circle(parent, "LynxBody", Vector2(15, -31), 6.5, charge, target, time_of_day)
	Draw.add_circle(parent, "LynxHead", Vector2(21, -39), 4.0, charge, target, time_of_day)
	Draw.add_polygon(
		parent,
		"LynxEarL",
		PackedVector2Array([Vector2(18, -42), Vector2(19, -47), Vector2(21, -42)]),
		charge,
		target,
		time_of_day
	)
	Draw.add_polygon(
		parent,
		"LynxEarR",
		PackedVector2Array([Vector2(22, -42), Vector2(24, -47), Vector2(25, -41)]),
		charge,
		target,
		time_of_day
	)
	Draw.add_rect(parent, "LynxLegA", Vector2(11, -24), Vector2(2, 9), charge, target, time_of_day)
	Draw.add_rect(parent, "LynxLegB", Vector2(15, -24), Vector2(2, 9), charge, target, time_of_day)
	Draw.add_rect(parent, "LynxLegC", Vector2(18, -24), Vector2(2, 8), charge, target, time_of_day)
	Draw.add_circle(parent, "LynxTail", Vector2(8, -30), 2.0, charge, target, time_of_day)


static func draw_banner_swallow(parent: Node2D, charge: Color, target: StringName, time_of_day: StringName) -> void:
	Draw.add_polygon(
		parent,
		"SwallowBody",
		PackedVector2Array([Vector2(12, -34), Vector2(22, -36), Vector2(22, -32), Vector2(12, -30)]),
		charge,
		target,
		time_of_day
	)
	Draw.add_circle(parent, "SwallowHead", Vector2(24, -34), 2.5, charge, target, time_of_day)
	Draw.add_polygon(
		parent,
		"SwallowWingU",
		PackedVector2Array([Vector2(10, -34), Vector2(18, -44), Vector2(20, -42), Vector2(14, -34)]),
		charge,
		target,
		time_of_day
	)
	Draw.add_polygon(
		parent,
		"SwallowWingL",
		PackedVector2Array([Vector2(10, -30), Vector2(18, -20), Vector2(20, -22), Vector2(14, -30)]),
		charge,
		target,
		time_of_day
	)
	Draw.add_polygon(
		parent,
		"SwallowTailU",
		PackedVector2Array([Vector2(6, -38), Vector2(12, -34), Vector2(12, -32), Vector2(7, -35)]),
		charge,
		target,
		time_of_day
	)
	Draw.add_polygon(
		parent,
		"SwallowTailL",
		PackedVector2Array([Vector2(6, -26), Vector2(12, -30), Vector2(12, -32), Vector2(7, -29)]),
		charge,
		target,
		time_of_day
	)
