class_name MapPropHeraldryRenderer
extends RefCounted

## 2D faction-banner renderer and its small heraldic charges.
## Geometry and node names stay here so the public MapPropRenderer facade can
## route props without coupling unrelated visual domains.

const Draw := preload("res://scripts/map/map_prop_draw.gd")


static func draw_banner(
	parent: Node2D, prop: Dictionary, target: StringName, time_of_day: StringName
) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	var faction := FactionHeraldry.resolve(prop)
	var field := FactionHeraldry.field_color(faction)
	var charge := FactionHeraldry.charge_color(faction)
	if not FactionHeraldry.shows_flag(faction):
		return
	# Top rod + vertical hanging cloth; matches the 3D wall-tapestry banner.
	Draw.add_rect(
		parent,
		"BannerMount",
		Vector2(-2, -50),
		Vector2(6, 6),
		wood.darkened(0.12),
		target,
		time_of_day
	)
	Draw.add_rect(
		parent,
		"BannerArm",
		Vector2(-10, -48),
		Vector2(28, 3),
		wood.darkened(0.08),
		target,
		time_of_day
	)
	Draw.add_rect(
		parent, "BannerField", Vector2(-8, -45), Vector2(24, 40), field, target, time_of_day
	)
	match FactionHeraldry.pattern_for(faction):
		FactionHeraldry.PATTERN_CROSS:
			Draw.add_rect(
				parent, "BannerCrossV", Vector2(0, -45), Vector2(6, 40), charge, target, time_of_day
			)
			Draw.add_rect(
				parent,
				"BannerCrossH",
				Vector2(-8, -28),
				Vector2(24, 6),
				charge,
				target,
				time_of_day
			)
		FactionHeraldry.PATTERN_PALE:
			Draw.add_rect(
				parent, "BannerPale", Vector2(-8, -45), Vector2(12, 40), charge, target, time_of_day
			)
		FactionHeraldry.PATTERN_FESS:
			Draw.add_rect(
				parent, "BannerFess", Vector2(-8, -45), Vector2(24, 20), charge, target, time_of_day
			)
		FactionHeraldry.PATTERN_BEAR:
			draw_banner_bear(parent, charge, target, time_of_day)
		FactionHeraldry.PATTERN_LYNX:
			draw_banner_lynx(parent, charge, target, time_of_day)
		FactionHeraldry.PATTERN_BEAR_LYNX:
			draw_banner_bear(
				parent, FactionHeraldry.secondary_charge_color(faction), target, time_of_day
			)
			draw_banner_lynx(parent, charge, target, time_of_day)
		FactionHeraldry.PATTERN_SWALLOW:
			draw_banner_swallow(parent, charge, target, time_of_day)


## 2D stand-ins for beast charges; UV silhouettes live in FactionHeraldry for 3D.
static func draw_banner_bear(
	parent: Node2D, charge: Color, target: StringName, time_of_day: StringName
) -> void:
	Draw.add_circle(parent, "BearBody", Vector2(14, -30), 7.0, charge, target, time_of_day)
	Draw.add_circle(parent, "BearHead", Vector2(20, -40), 4.5, charge, target, time_of_day)
	Draw.add_circle(parent, "BearSnout", Vector2(24, -39), 2.5, charge, target, time_of_day)
	Draw.add_rect(parent, "BearLegF", Vector2(16, -24), Vector2(3, 8), charge, target, time_of_day)
	Draw.add_rect(parent, "BearLegR", Vector2(10, -24), Vector2(3, 8), charge, target, time_of_day)
	Draw.add_polygon(
		parent,
		"BearArm",
		PackedVector2Array(
			[Vector2(16, -34), Vector2(24, -30), Vector2(23, -27), Vector2(15, -31)]
		),
		charge,
		target,
		time_of_day
	)


static func draw_banner_lynx(
	parent: Node2D, charge: Color, target: StringName, time_of_day: StringName
) -> void:
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


static func draw_banner_swallow(
	parent: Node2D, charge: Color, target: StringName, time_of_day: StringName
) -> void:
	# Forked-tail swallow centered on the taller vertical field.
	Draw.add_polygon(
		parent,
		"SwallowBody",
		PackedVector2Array([Vector2(-2, -28), Vector2(8, -30), Vector2(8, -24), Vector2(-2, -22)]),
		charge,
		target,
		time_of_day
	)
	Draw.add_circle(parent, "SwallowHead", Vector2(10, -26), 3.0, charge, target, time_of_day)
	Draw.add_polygon(
		parent,
		"SwallowBeak",
		PackedVector2Array([Vector2(12, -27), Vector2(16, -26), Vector2(12, -25)]),
		charge,
		target,
		time_of_day
	)
	Draw.add_polygon(
		parent,
		"SwallowWingU",
		PackedVector2Array([Vector2(-4, -28), Vector2(4, -40), Vector2(7, -38), Vector2(0, -28)]),
		charge,
		target,
		time_of_day
	)
	Draw.add_polygon(
		parent,
		"SwallowWingL",
		PackedVector2Array([Vector2(-4, -22), Vector2(4, -10), Vector2(7, -12), Vector2(0, -22)]),
		charge,
		target,
		time_of_day
	)
	Draw.add_polygon(
		parent,
		"SwallowTailU",
		PackedVector2Array(
			[Vector2(-12, -34), Vector2(-2, -28), Vector2(-2, -26), Vector2(-11, -30)]
		),
		charge,
		target,
		time_of_day
	)
	Draw.add_polygon(
		parent,
		"SwallowTailL",
		PackedVector2Array(
			[Vector2(-12, -16), Vector2(-2, -22), Vector2(-2, -24), Vector2(-11, -20)]
		),
		charge,
		target,
		time_of_day
	)
