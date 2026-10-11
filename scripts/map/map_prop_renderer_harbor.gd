class_name MapPropHarborRenderer
extends RefCounted

## 2D renderers for boats, cargo, and trade-harbour dressing.
## Geometry and node names stay here so the public MapPropRenderer facade can
## route props without coupling unrelated visual domains.

const Draw := preload("res://scripts/map/map_prop_draw.gd")


static func draw_fishing_boat(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	var timber := MapVisualStyle.role_color(&"timber", target, time_of_day)
	var metal := MapVisualStyle.role_color(&"metal", target, time_of_day)
	(
		Draw
		. add_polygon(
			parent,
			"Hull",
			PackedVector2Array(
				[
					Vector2(-54, -5),
					Vector2(-34, -18),
					Vector2(34, -18),
					Vector2(54, -5),
					Vector2(32, 8),
					Vector2(-32, 8),
				]
			),
			wood,
			target,
			time_of_day
		)
	)
	(
		Draw
		. add_polygon(
			parent,
			"Interior",
			PackedVector2Array(
				[
					Vector2(-36, -7),
					Vector2(-27, -13),
					Vector2(27, -13),
					Vector2(36, -7),
					Vector2(25, 1),
					Vector2(-25, 1),
				]
			),
			wood.darkened(0.22),
			target,
			time_of_day
		)
	)
	for index in 3:
		var x := -24.0 + float(index) * 24.0
		Draw.add_rect(
			parent,
			"Bench%d" % index,
			Vector2(x - 3, -14),
			Vector2(6, 19),
			timber,
			target,
			time_of_day
		)
	Draw.add_rect(
		parent, "Mast", Vector2(-3, -47), Vector2(6, 35), timber.darkened(0.12), target, time_of_day
	)
	Draw.add_line(
		parent,
		"Rigging",
		PackedVector2Array([Vector2(0, -43), Vector2(35, -14)]),
		target,
		time_of_day,
		&"metal"
	)
	Draw.add_circle(parent, "MooringRing", Vector2(-44, -4), 3.0, metal, target, time_of_day)


static func draw_merchant_boat(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	# Trade-harbour vessels need a broader high-sided silhouette than the open
	# inshore boats, so they remain distinguishable at district-map scale.
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	var timber := MapVisualStyle.role_color(&"timber", target, time_of_day)
	var plaster := MapVisualStyle.role_color(&"plaster", target, time_of_day)
	(
		Draw
		. add_polygon(
			parent,
			"Hull",
			PackedVector2Array(
				[
					Vector2(-126, -12),
					Vector2(-94, -38),
					Vector2(94, -38),
					Vector2(126, -12),
					Vector2(92, 25),
					Vector2(-92, 25),
				]
			),
			wood,
			target,
			time_of_day
		)
	)
	(
		Draw
		. add_polygon(
			parent,
			"Deck",
			PackedVector2Array(
				[
					Vector2(-88, -19),
					Vector2(88, -19),
					Vector2(73, 10),
					Vector2(-73, 10),
				]
			),
			wood.darkened(0.18),
			target,
			time_of_day
		)
	)
	Draw.add_rect(
		parent, "Aftcastle", Vector2(-90, -34), Vector2(45, 52), timber, target, time_of_day
	)
	Draw.add_rect(
		parent, "Forecastle", Vector2(48, -31), Vector2(42, 46), timber, target, time_of_day
	)
	Draw.add_rect(
		parent,
		"Mast",
		Vector2(-4, -118),
		Vector2(8, 101),
		timber.darkened(0.12),
		target,
		time_of_day
	)
	Draw.add_rect(
		parent, "SquareSail", Vector2(-42, -100), Vector2(84, 58), plaster, target, time_of_day
	)
	Draw.add_line(
		parent,
		"Yard",
		PackedVector2Array([Vector2(-50, -103), Vector2(50, -103)]),
		target,
		time_of_day,
		&"timber"
	)


static func draw_cargo_crates(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	var timber := MapVisualStyle.role_color(&"timber", target, time_of_day)
	Draw.add_rect(
		parent, "CrateLarge", Vector2(-25, -24), Vector2(29, 29), wood, target, time_of_day
	)
	Draw.add_rect(
		parent, "CrateSmall", Vector2(7, -17), Vector2(22, 22), timber, target, time_of_day
	)
	for brace in [
		["LargeBraceH", Vector2(-25, -12), Vector2(29, 4)],
		["LargeBraceV", Vector2(-12, -24), Vector2(4, 29)],
		["SmallBraceH", Vector2(7, -7), Vector2(22, 3)],
	]:
		Draw.add_rect(
			parent, brace[0], brace[1], brace[2], timber.darkened(0.12), target, time_of_day
		)


static func draw_trade_goods(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var plaster := MapVisualStyle.role_color(&"plaster", target, time_of_day)
	var hay := MapVisualStyle.role_color(&"hay", target, time_of_day)
	Draw.add_polygon(
		parent,
		"WoolSackA",
		PackedVector2Array(
			[Vector2(-25, 4), Vector2(-22, -20), Vector2(-10, -28), Vector2(2, -18), Vector2(0, 5)]
		),
		plaster.darkened(0.08),
		target,
		time_of_day
	)
	Draw.add_polygon(
		parent,
		"WoolSackB",
		PackedVector2Array(
			[Vector2(3, 5), Vector2(5, -17), Vector2(16, -23), Vector2(28, -13), Vector2(27, 5)]
		),
		plaster,
		target,
		time_of_day
	)
	Draw.add_rect(
		parent,
		"ClothBale",
		Vector2(-9, -13),
		Vector2(26, 18),
		hay.darkened(0.08),
		target,
		time_of_day
	)
	Draw.add_line(
		parent,
		"BaleCordA",
		PackedVector2Array([Vector2(-2, -13), Vector2(-2, 5)]),
		target,
		time_of_day,
		&"timber"
	)
	Draw.add_line(
		parent,
		"BaleCordB",
		PackedVector2Array([Vector2(10, -13), Vector2(10, 5)]),
		target,
		time_of_day,
		&"timber"
	)


static func draw_barrels(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	Draw.add_rect(
		parent,
		"BarrelA",
		Vector2(-22, -19),
		Vector2(18, 25),
		wood.darkened(0.08),
		target,
		time_of_day
	)
	Draw.add_rect(parent, "BarrelB", Vector2(4, -17), Vector2(18, 23), wood, target, time_of_day)
	Draw.add_rect(
		parent,
		"BandA",
		Vector2(-22, -8),
		Vector2(18, 3),
		MapVisualStyle.role_color(&"metal", target, time_of_day),
		target,
		time_of_day
	)
	Draw.add_rect(
		parent,
		"BandB",
		Vector2(4, -7),
		Vector2(18, 3),
		MapVisualStyle.role_color(&"metal", target, time_of_day),
		target,
		time_of_day
	)
