class_name MapPropRenderer
extends RefCounted

## Style-profiled props. Every prop keeps the shared definition anchor as its Y-sort pivot.


static func create_prop(
	prop: Dictionary,
	target: StringName = MapVisualStyle.TARGET_CLEAN_PAINTED,
	time_of_day: StringName = MapVisualStyle.TIME_DAY
) -> Node2D:
	var root := Node2D.new()
	root.name = "Prop_%s" % String(prop["id"])
	root.position = prop["position"]
	if prop.has("visual_offset_px"):
		root.position += prop["visual_offset_px"] as Vector2
	root.set_meta("y_sort_anchor", prop["position"])
	root.set_meta("visual_target", target)

	var shadow := Polygon2D.new()
	shadow.name = "Shadow"
	if prop["kind"] == MapTypes.PROP_KIND_FISHING_BOAT:
		shadow.visible = false
	shadow.polygon = _ellipse(Vector2(0, 2) + MapVisualStyle.shadow_offset(target) * 0.35, Vector2(26, 9), 16)
	shadow.color = Color(MapVisualStyle.role_color(&"ink", target, time_of_day), MapVisualStyle.shadow_alpha(target, time_of_day))
	shadow.z_index = -2
	root.add_child(shadow)

	match prop["kind"] as StringName:
		MapTypes.PROP_KIND_ANVIL: _draw_anvil(root, target, time_of_day)
		MapTypes.PROP_KIND_HAY_STACK: _draw_hay_stack(root, target, time_of_day)
		MapTypes.PROP_KIND_CART: _draw_cart(root, target, time_of_day)
		MapTypes.PROP_KIND_WELL: _draw_well(root, target, time_of_day)
		MapTypes.PROP_KIND_BARRELS: _draw_barrels(root, target, time_of_day)
		MapTypes.PROP_KIND_FURNACE: _draw_furnace(root, target, time_of_day)
		MapTypes.PROP_KIND_LEDGER: _draw_ledger(root, target, time_of_day)
		MapTypes.PROP_KIND_BED: _draw_bed(root, target, time_of_day)
		MapTypes.PROP_KIND_CHEST: _draw_chest(root, target, time_of_day)
		MapTypes.PROP_KIND_TABLE: _draw_table(root, target, time_of_day)
		MapTypes.PROP_KIND_SHELF: _draw_shelf(root, target, time_of_day)
		MapTypes.PROP_KIND_QUENCH: _draw_quench(root, target, time_of_day)
		MapTypes.PROP_KIND_STAIRS: _draw_stairs(root, target, time_of_day)
		MapTypes.PROP_KIND_STALL: _draw_stall(root, target, time_of_day)
		MapTypes.PROP_KIND_HEARTH: _draw_hearth(root, target, time_of_day)
		MapTypes.PROP_KIND_CHAIR: _draw_chair(root, target, time_of_day)
		MapTypes.PROP_KIND_CANDLE: _draw_candle(root, target, time_of_day)
		MapTypes.PROP_KIND_BUSH: _draw_bush(root, target, time_of_day)
		MapTypes.PROP_KIND_FISHING_BOAT: _draw_fishing_boat(root, target, time_of_day)
		MapTypes.PROP_KIND_CARGO_CRATES: _draw_cargo_crates(root, target, time_of_day)
		MapTypes.PROP_KIND_TRADE_GOODS: _draw_trade_goods(root, target, time_of_day)
		MapTypes.PROP_KIND_TIMBER_FENCE: _draw_timber_fence(root, prop, target, time_of_day)
		MapTypes.PROP_KIND_CATTLE: _draw_cattle(root, target, time_of_day)
		MapTypes.PROP_KIND_SHEEP: _draw_sheep(root, target, time_of_day)
		_: _add_rect(root, "Marker", Vector2(-8, -8), Vector2(16, 16), Color.MAGENTA, target, time_of_day)
	if prop["kind"] in MapTypes.BOAT_PROP_KINDS and _has_tall_footprint(prop):
		root.rotation = PI * 0.5
	return root


static func _has_tall_footprint(prop: Dictionary) -> bool:
	var footprint: Variant = prop.get("footprint")
	return footprint is Rect2 and footprint.size.y > footprint.size.x


static func _draw_anvil(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var metal := MapVisualStyle.role_color(&"metal", target, time_of_day)
	_add_rect(parent, "Base", Vector2(-16, -7), Vector2(32, 11), metal.darkened(0.18), target, time_of_day)
	_add_polygon(parent, "AnvilBody", PackedVector2Array([Vector2(-12, -20), Vector2(13, -20), Vector2(18, -14), Vector2(7, -9), Vector2(-10, -9)]), metal, target, time_of_day)
	_add_rect(parent, "Face", Vector2(-17, -25), Vector2(35, 7), metal.lightened(0.16), target, time_of_day)


static func _draw_hay_stack(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var hay := MapVisualStyle.role_color(&"hay", target, time_of_day)
	for index in 3:
		var offset := float(index) * 6.0
		_add_rect(parent, "Bale%d" % index, Vector2(-21 + offset, -15 - offset), Vector2(42, 13), hay.darkened(index * 0.05), target, time_of_day)
		if target == MapVisualStyle.TARGET_WOODCUT:
			_add_line(parent, "Straw%d" % index, PackedVector2Array([Vector2(-17 + offset, -10 - offset), Vector2(16 + offset, -15 - offset)]), target, time_of_day)


static func _draw_cart(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	_add_rect(parent, "Bed", Vector2(-29, -18), Vector2(58, 19), wood, target, time_of_day)
	_add_circle(parent, "WheelL", Vector2(-20, 4), 9.0, wood.darkened(0.28), target, time_of_day)
	_add_circle(parent, "WheelR", Vector2(20, 4), 9.0, wood.darkened(0.28), target, time_of_day)
	_add_rect(parent, "Shaft", Vector2(26, -6), Vector2(25, 4), wood.darkened(0.12), target, time_of_day)


static func _draw_well(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var stone := MapVisualStyle.role_color(&"stone", target, time_of_day)
	var water := MapVisualStyle.terrain_color(MapTypes.TERRAIN_WATER, target, time_of_day)
	_add_circle(parent, "Rim", Vector2(0, -9), 23.0, stone, target, time_of_day)
	_add_circle(parent, "Water", Vector2(0, -10), 14.0, water, target, time_of_day)
	_add_rect(parent, "Curb", Vector2(-24, -4), Vector2(48, 8), stone.darkened(0.10), target, time_of_day)
	_add_line(parent, "WaterGlint", PackedVector2Array([Vector2(-8, -12), Vector2(8, -12)]), target, time_of_day, &"water_highlight")


static func _draw_furnace(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var stone := MapVisualStyle.role_color(&"stone", target, time_of_day)
	var ember := MapVisualStyle.role_color(&"ember", target, time_of_day)
	_add_rect(parent, "FurnaceBase", Vector2(-32, -22), Vector2(64, 36), stone.darkened(0.10), target, time_of_day)
	_add_rect(parent, "FireMouth", Vector2(-18, -12), Vector2(36, 20), ember, target, time_of_day)
	_add_rect(parent, "Chimney", Vector2(-12, -50), Vector2(24, 30), stone, target, time_of_day)


static func _draw_ledger(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	_add_rect(parent, "LedgerDesk", Vector2(-20, -10), Vector2(40, 14), wood, target, time_of_day)
	_add_rect(parent, "LedgerBook", Vector2(-10, -18), Vector2(20, 10), wood.lightened(0.18), target, time_of_day)


static func _draw_bed(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	var plaster := MapVisualStyle.role_color(&"plaster", target, time_of_day)
	_add_rect(parent, "BedFrame", Vector2(-44, -14), Vector2(88, 26), wood, target, time_of_day)
	_add_rect(parent, "BedRoll", Vector2(-36, -22), Vector2(72, 16), plaster.lightened(0.10), target, time_of_day)


static func _draw_chest(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	_add_rect(parent, "ChestBody", Vector2(-16, -12), Vector2(32, 20), wood.darkened(0.08), target, time_of_day)
	_add_rect(parent, "ChestLid", Vector2(-16, -18), Vector2(32, 8), wood, target, time_of_day)


static func _draw_table(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	_add_rect(parent, "TableTop", Vector2(-36, -10), Vector2(72, 14), wood, target, time_of_day)
	_add_rect(parent, "LegL", Vector2(-30, 4), Vector2(7, 14), wood.darkened(0.12), target, time_of_day)
	_add_rect(parent, "LegR", Vector2(23, 4), Vector2(7, 14), wood.darkened(0.12), target, time_of_day)


static func _draw_shelf(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	_add_rect(parent, "ShelfBack", Vector2(-18, -28), Vector2(36, 34), wood.darkened(0.10), target, time_of_day)
	_add_rect(parent, "ShelfMid", Vector2(-16, -10), Vector2(32, 4), wood, target, time_of_day)
	_add_rect(parent, "ShelfTop", Vector2(-16, -24), Vector2(32, 4), wood, target, time_of_day)


static func _draw_quench(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	var water := MapVisualStyle.terrain_color(MapTypes.TERRAIN_WATER, target, time_of_day)
	_add_rect(parent, "Trough", Vector2(-18, -8), Vector2(36, 12), wood, target, time_of_day)
	_add_rect(parent, "Water", Vector2(-14, -6), Vector2(28, 6), water, target, time_of_day)


static func _draw_stairs(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var stone := MapVisualStyle.role_color(&"stone", target, time_of_day)
	for step in 4:
		var y := step * 5
		_add_rect(parent, "Step%d" % step, Vector2(-20 + step * 3, -8 + y), Vector2(40 - step * 6, 5), stone.darkened(step * 0.04), target, time_of_day)


static func _draw_stall(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	var plaster := MapVisualStyle.role_color(&"plaster", target, time_of_day)
	_add_rect(parent, "StallCounter", Vector2(-22, -10), Vector2(44, 12), wood, target, time_of_day)
	_add_polygon(parent, "Awning", PackedVector2Array([Vector2(-26, -18), Vector2(26, -18), Vector2(18, -28), Vector2(-18, -28)]), plaster.darkened(0.05), target, time_of_day)


static func _draw_hearth(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var stone := MapVisualStyle.role_color(&"stone", target, time_of_day)
	var ember := MapVisualStyle.role_color(&"ember", target, time_of_day)
	_add_rect(parent, "HearthBase", Vector2(-20, -10), Vector2(40, 16), stone, target, time_of_day)
	_add_rect(parent, "HearthFire", Vector2(-10, -6), Vector2(20, 8), ember, target, time_of_day)


static func _draw_chair(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	_add_rect(parent, "Seat", Vector2(-10, -4), Vector2(20, 8), wood, target, time_of_day)
	_add_rect(parent, "Back", Vector2(-9, -18), Vector2(18, 14), wood.darkened(0.08), target, time_of_day)
	_add_rect(parent, "LegL", Vector2(-8, 4), Vector2(4, 10), wood.darkened(0.14), target, time_of_day)
	_add_rect(parent, "LegR", Vector2(4, 4), Vector2(4, 10), wood.darkened(0.14), target, time_of_day)


static func _draw_candle(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var plaster := MapVisualStyle.role_color(&"plaster", target, time_of_day)
	var ember := MapVisualStyle.role_color(&"ember", target, time_of_day)
	_add_rect(parent, "Holder", Vector2(-5, 2), Vector2(10, 6), MapVisualStyle.role_color(&"metal", target, time_of_day), target, time_of_day)
	_add_rect(parent, "Wax", Vector2(-2, -6), Vector2(4, 10), plaster.lightened(0.12), target, time_of_day)
	_add_circle(parent, "Flame", Vector2(0, -10), 4.0, ember, target, time_of_day)


static func _draw_bush(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var foliage := MapVisualStyle.role_color(&"vegetation", target, time_of_day)
	_add_circle(parent, "BushA", Vector2(-8, -6), 11.0, foliage.darkened(0.06), target, time_of_day)
	_add_circle(parent, "BushB", Vector2(7, -8), 10.0, foliage, target, time_of_day)
	_add_circle(parent, "BushC", Vector2(1, -3), 8.0, foliage.lightened(0.08), target, time_of_day)


static func _draw_fishing_boat(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	var timber := MapVisualStyle.role_color(&"timber", target, time_of_day)
	var metal := MapVisualStyle.role_color(&"metal", target, time_of_day)
	_add_polygon(
		parent,
		"Hull",
		PackedVector2Array([
			Vector2(-54, -5),
			Vector2(-34, -18),
			Vector2(34, -18),
			Vector2(54, -5),
			Vector2(32, 8),
			Vector2(-32, 8),
		]),
		wood,
		target,
		time_of_day
	)
	_add_polygon(
		parent,
		"Interior",
		PackedVector2Array([
			Vector2(-36, -7),
			Vector2(-27, -13),
			Vector2(27, -13),
			Vector2(36, -7),
			Vector2(25, 1),
			Vector2(-25, 1),
		]),
		wood.darkened(0.22),
		target,
		time_of_day
	)
	for index in 3:
		var x := -24.0 + float(index) * 24.0
		_add_rect(parent, "Bench%d" % index, Vector2(x - 3, -14), Vector2(6, 19), timber, target, time_of_day)
	_add_rect(parent, "Mast", Vector2(-3, -47), Vector2(6, 35), timber.darkened(0.12), target, time_of_day)
	_add_line(parent, "Rigging", PackedVector2Array([Vector2(0, -43), Vector2(35, -14)]), target, time_of_day, &"metal")
	_add_circle(parent, "MooringRing", Vector2(-44, -4), 3.0, metal, target, time_of_day)

static func _draw_cargo_crates(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	var timber := MapVisualStyle.role_color(&"timber", target, time_of_day)
	_add_rect(parent, "CrateLarge", Vector2(-25, -24), Vector2(29, 29), wood, target, time_of_day)
	_add_rect(parent, "CrateSmall", Vector2(7, -17), Vector2(22, 22), timber, target, time_of_day)
	for brace in [
		["LargeBraceH", Vector2(-25, -12), Vector2(29, 4)],
		["LargeBraceV", Vector2(-12, -24), Vector2(4, 29)],
		["SmallBraceH", Vector2(7, -7), Vector2(22, 3)],
	]:
		_add_rect(parent, brace[0], brace[1], brace[2], timber.darkened(0.12), target, time_of_day)


static func _draw_trade_goods(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var plaster := MapVisualStyle.role_color(&"plaster", target, time_of_day)
	var hay := MapVisualStyle.role_color(&"hay", target, time_of_day)
	_add_polygon(parent, "WoolSackA", PackedVector2Array([Vector2(-25, 4), Vector2(-22, -20), Vector2(-10, -28), Vector2(2, -18), Vector2(0, 5)]), plaster.darkened(0.08), target, time_of_day)
	_add_polygon(parent, "WoolSackB", PackedVector2Array([Vector2(3, 5), Vector2(5, -17), Vector2(16, -23), Vector2(28, -13), Vector2(27, 5)]), plaster, target, time_of_day)
	_add_rect(parent, "ClothBale", Vector2(-9, -13), Vector2(26, 18), hay.darkened(0.08), target, time_of_day)
	_add_line(parent, "BaleCordA", PackedVector2Array([Vector2(-2, -13), Vector2(-2, 5)]), target, time_of_day, &"timber")
	_add_line(parent, "BaleCordB", PackedVector2Array([Vector2(10, -13), Vector2(10, 5)]), target, time_of_day, &"timber")


static func _draw_timber_fence(parent: Node2D, prop: Dictionary, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	var footprint: Rect2 = prop.get("footprint", Rect2(Vector2.ZERO, Vector2(96, 32)))
	var horizontal := footprint.size.x >= footprint.size.y
	var length := maxf(maxf(footprint.size.x, footprint.size.y) - 12.0, 38.0)
	var post_count := maxi(2, ceili(length / 48.0) + 1)
	if horizontal:
		_add_rect(parent, "RailTop", Vector2(-length * 0.5, -19), Vector2(length, 5), wood, target, time_of_day)
		_add_rect(parent, "RailBottom", Vector2(-length * 0.5, -7), Vector2(length, 5), wood.darkened(0.08), target, time_of_day)
		for index in post_count:
			var x := lerpf(-length * 0.5, length * 0.5 - 5.0, float(index) / float(post_count - 1))
			_add_rect(parent, "Post%d" % index, Vector2(x, -27), Vector2(5, 32), wood.darkened(0.15), target, time_of_day)
	else:
		_add_rect(parent, "RailLeft", Vector2(-12, -length * 0.5), Vector2(5, length), wood, target, time_of_day)
		_add_rect(parent, "RailRight", Vector2(5, -length * 0.5), Vector2(5, length), wood.darkened(0.08), target, time_of_day)
		for index in post_count:
			var y := lerpf(-length * 0.5, length * 0.5 - 5.0, float(index) / float(post_count - 1))
			_add_rect(parent, "Post%d" % index, Vector2(-17, y), Vector2(32, 5), wood.darkened(0.15), target, time_of_day)


static func _draw_cattle(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var hide := MapVisualStyle.role_color(&"wood", target, time_of_day).darkened(0.12)
	var horn := MapVisualStyle.role_color(&"hay", target, time_of_day).lightened(0.12)
	_add_polygon(parent, "Body", _ellipse(Vector2(-3, -10), Vector2(26, 16), 16), hide, target, time_of_day)
	_add_polygon(parent, "Head", PackedVector2Array([Vector2(17, -19), Vector2(34, -15), Vector2(36, -4), Vector2(18, -3)]), hide.darkened(0.06), target, time_of_day)
	_add_line(parent, "HornNorth", PackedVector2Array([Vector2(25, -17), Vector2(34, -25)]), target, time_of_day, &"hay")
	_add_line(parent, "HornSouth", PackedVector2Array([Vector2(27, -5), Vector2(36, 1)]), target, time_of_day, &"hay")
	for leg in [-17.0, 11.0]:
		_add_rect(parent, "Leg%d" % int(leg), Vector2(leg, 0), Vector2(5, 15), hide.darkened(0.18), target, time_of_day)
	_add_circle(parent, "Muzzle", Vector2(36, -8), 5.0, horn.darkened(0.18), target, time_of_day)


static func _draw_sheep(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var wool := MapVisualStyle.role_color(&"plaster", target, time_of_day)
	var hide := MapVisualStyle.role_color(&"wood", target, time_of_day).darkened(0.22)
	for tuft in [Vector2(-13, -11), Vector2(0, -16), Vector2(13, -10), Vector2(-3, -4)]:
		_add_circle(parent, "Wool%d" % parent.get_child_count(), tuft, 12.0, wool.darkened(absf(tuft.x) * 0.002), target, time_of_day)
	_add_polygon(parent, "Head", PackedVector2Array([Vector2(17, -14), Vector2(31, -11), Vector2(30, 0), Vector2(17, -2)]), hide, target, time_of_day)
	_add_rect(parent, "LegA", Vector2(-13, -1), Vector2(4, 13), hide, target, time_of_day)
	_add_rect(parent, "LegB", Vector2(10, -1), Vector2(4, 13), hide, target, time_of_day)


static func _draw_barrels(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	_add_rect(parent, "BarrelA", Vector2(-22, -19), Vector2(18, 25), wood.darkened(0.08), target, time_of_day)
	_add_rect(parent, "BarrelB", Vector2(4, -17), Vector2(18, 23), wood, target, time_of_day)
	_add_rect(parent, "BandA", Vector2(-22, -8), Vector2(18, 3), MapVisualStyle.role_color(&"metal", target, time_of_day), target, time_of_day)
	_add_rect(parent, "BandB", Vector2(4, -7), Vector2(18, 3), MapVisualStyle.role_color(&"metal", target, time_of_day), target, time_of_day)


static func _add_rect(parent: Node, node_name: String, position: Vector2, size: Vector2, color: Color, target: StringName, time_of_day: StringName) -> void:
	_add_polygon(parent, node_name, PackedVector2Array([position, position + Vector2(size.x, 0), position + size, position + Vector2(0, size.y)]), color, target, time_of_day)


static func _add_circle(parent: Node, node_name: String, center: Vector2, radius: float, color: Color, target: StringName, time_of_day: StringName) -> void:
	_add_polygon(parent, node_name, _ellipse(center, Vector2(radius, radius), 16), color, target, time_of_day)


static func _add_polygon(parent: Node, node_name: String, points: PackedVector2Array, color: Color, target: StringName, time_of_day: StringName) -> void:
	var polygon := Polygon2D.new()
	polygon.name = node_name
	polygon.polygon = points
	polygon.color = color
	parent.add_child(polygon)
	var outline := Line2D.new()
	outline.name = "%sOutline" % node_name
	outline.points = points
	outline.closed = true
	outline.width = MapVisualStyle.outline_width(target)
	outline.default_color = MapVisualStyle.role_color(&"ink", target, time_of_day)
	outline.z_index = 1
	parent.add_child(outline)


static func _add_line(parent: Node, node_name: String, points: PackedVector2Array, target: StringName, time_of_day: StringName, role: StringName = &"ink") -> void:
	var line := Line2D.new()
	line.name = node_name
	line.points = points
	line.width = MapVisualStyle.outline_width(target)
	line.default_color = MapVisualStyle.role_color(role, target, time_of_day)
	line.z_index = 2
	parent.add_child(line)


static func _ellipse(center: Vector2, radii: Vector2, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step in steps:
		var angle := float(step) / float(steps) * TAU
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points
