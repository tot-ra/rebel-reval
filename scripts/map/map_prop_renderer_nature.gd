class_name MapPropNatureRenderer
extends RefCounted

## 2D renderers for vegetation, fences, and farm animals.
## Geometry and node names stay here so the public MapPropRenderer facade can
## route props without coupling unrelated visual domains.

const Draw := preload("res://scripts/map/map_prop_draw.gd")


static func draw_bush(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var foliage := MapVisualStyle.role_color(&"vegetation", target, time_of_day)
	Draw.add_circle(parent, "BushA", Vector2(-8, -6), 11.0, foliage.darkened(0.06), target, time_of_day)
	Draw.add_circle(parent, "BushB", Vector2(7, -8), 10.0, foliage, target, time_of_day)
	Draw.add_circle(parent, "BushC", Vector2(1, -3), 8.0, foliage.lightened(0.08), target, time_of_day)


static func draw_tree(parent: Node2D, prop: Dictionary, target: StringName, time_of_day: StringName) -> void:
	var foliage := MapVisualStyle.role_color(&"vegetation", target, time_of_day)
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	var variant: StringName = prop.get("style_variant", &"tree.mixed")
	var parsed: Dictionary = MapViewTreeSpecies.parse_variant(variant)
	var species: StringName = parsed.get("species", MapViewTreeSpecies.SPECIES_OAK)
	var size_class: StringName = parsed.get("size", MapViewTreeSpecies.SIZE_MEDIUM)
	var parts := String(variant).split(".")
	if parts.size() < 3:
		size_class = MapViewTreeSpecies.SIZE_MEDIUM
	var scale := 1.0
	match size_class:
		MapViewTreeSpecies.SIZE_SMALL:
			scale = 0.72
		MapViewTreeSpecies.SIZE_LARGE:
			scale = 1.35
	var trunk_color := wood.darkened(0.12)
	if species == MapViewTreeSpecies.SPECIES_BIRCH:
		trunk_color = Color(0.9, 0.88, 0.82)
	Draw.add_rect(parent, "Trunk", Vector2(-3 * scale, -8 * scale), Vector2(6 * scale, 18 * scale), trunk_color, target, time_of_day)
	match MapViewTreeSpecies.silhouette_for(species):
		MapViewTreeSpecies.SILHOUETTE_SPRUCE, MapViewTreeSpecies.SILHOUETTE_PINE:
			Draw.add_polygon(
				parent,
				"Canopy",
				PackedVector2Array([
					Vector2(0, -42 * scale),
					Vector2(16 * scale, -12 * scale),
					Vector2(-16 * scale, -12 * scale),
				]),
				foliage.darkened(0.08),
				target,
				time_of_day
			)
			Draw.add_polygon(
				parent,
				"CanopyMid",
				PackedVector2Array([
					Vector2(0, -28 * scale),
					Vector2(20 * scale, -2 * scale),
					Vector2(-20 * scale, -2 * scale),
				]),
				foliage,
				target,
				time_of_day
			)
		MapViewTreeSpecies.SILHOUETTE_COLUMN:
			Draw.add_circle(parent, "CrownLow", Vector2(0, -14 * scale), 11.0 * scale, foliage.darkened(0.04), target, time_of_day)
			Draw.add_circle(parent, "CrownHigh", Vector2(2 * scale, -28 * scale), 9.0 * scale, foliage.lightened(0.05), target, time_of_day)
		_:
			Draw.add_circle(parent, "Crown", Vector2(0, -22 * scale), 18.0 * scale, foliage, target, time_of_day)
			Draw.add_circle(parent, "CrownSide", Vector2(10 * scale, -16 * scale), 11.0 * scale, foliage.darkened(0.05), target, time_of_day)



static func draw_timber_fence(parent: Node2D, prop: Dictionary, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	var footprint: Rect2 = prop.get("footprint", Rect2(Vector2.ZERO, Vector2(96, 32)))
	var horizontal := footprint.size.x >= footprint.size.y
	var length := maxf(maxf(footprint.size.x, footprint.size.y) - 12.0, 38.0)
	var post_count := maxi(2, ceili(length / 48.0) + 1)
	if horizontal:
		Draw.add_rect(parent, "RailTop", Vector2(-length * 0.5, -19), Vector2(length, 5), wood, target, time_of_day)
		Draw.add_rect(parent, "RailBottom", Vector2(-length * 0.5, -7), Vector2(length, 5), wood.darkened(0.08), target, time_of_day)
		for index in post_count:
			var x := lerpf(-length * 0.5, length * 0.5 - 5.0, float(index) / float(post_count - 1))
			Draw.add_rect(parent, "Post%d" % index, Vector2(x, -27), Vector2(5, 32), wood.darkened(0.15), target, time_of_day)
	else:
		Draw.add_rect(parent, "RailLeft", Vector2(-12, -length * 0.5), Vector2(5, length), wood, target, time_of_day)
		Draw.add_rect(parent, "RailRight", Vector2(5, -length * 0.5), Vector2(5, length), wood.darkened(0.08), target, time_of_day)
		for index in post_count:
			var y := lerpf(-length * 0.5, length * 0.5 - 5.0, float(index) / float(post_count - 1))
			Draw.add_rect(parent, "Post%d" % index, Vector2(-17, y), Vector2(32, 5), wood.darkened(0.15), target, time_of_day)


static func draw_cattle(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var hide := MapVisualStyle.role_color(&"wood", target, time_of_day).darkened(0.12)
	var horn := MapVisualStyle.role_color(&"hay", target, time_of_day).lightened(0.12)
	Draw.add_polygon(parent, "Body", Draw.ellipse(Vector2(-3, -10), Vector2(26, 16), 16), hide, target, time_of_day)
	Draw.add_polygon(parent, "Head", PackedVector2Array([Vector2(17, -19), Vector2(34, -15), Vector2(36, -4), Vector2(18, -3)]), hide.darkened(0.06), target, time_of_day)
	Draw.add_line(parent, "HornNorth", PackedVector2Array([Vector2(25, -17), Vector2(34, -25)]), target, time_of_day, &"hay")
	Draw.add_line(parent, "HornSouth", PackedVector2Array([Vector2(27, -5), Vector2(36, 1)]), target, time_of_day, &"hay")
	for leg in [-17.0, 11.0]:
		Draw.add_rect(parent, "Leg%d" % int(leg), Vector2(leg, 0), Vector2(5, 15), hide.darkened(0.18), target, time_of_day)
	Draw.add_circle(parent, "Muzzle", Vector2(36, -8), 5.0, horn.darkened(0.18), target, time_of_day)


static func draw_sheep(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var wool := MapVisualStyle.role_color(&"plaster", target, time_of_day)
	var hide := MapVisualStyle.role_color(&"wood", target, time_of_day).darkened(0.22)
	for tuft in [Vector2(-13, -11), Vector2(0, -16), Vector2(13, -10), Vector2(-3, -4)]:
		Draw.add_circle(parent, "Wool%d" % parent.get_child_count(), tuft, 12.0, wool.darkened(absf(tuft.x) * 0.002), target, time_of_day)
	Draw.add_polygon(parent, "Head", PackedVector2Array([Vector2(17, -14), Vector2(31, -11), Vector2(30, 0), Vector2(17, -2)]), hide, target, time_of_day)
	Draw.add_rect(parent, "LegA", Vector2(-13, -1), Vector2(4, 13), hide, target, time_of_day)
	Draw.add_rect(parent, "LegB", Vector2(10, -1), Vector2(4, 13), hide, target, time_of_day)
static func draw_horse(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var coat := MapVisualStyle.role_color(&"wood", target, time_of_day).darkened(0.04)
	var dark := coat.darkened(0.2)
	Draw.add_polygon(parent, "Body", Draw.ellipse(Vector2(-5, -13), Vector2(27, 14), 16), coat, target, time_of_day)
	Draw.add_polygon(parent, "Neck", PackedVector2Array([Vector2(13, -21), Vector2(25, -33), Vector2(34, -27), Vector2(22, -8)]), coat.darkened(0.04), target, time_of_day)
	Draw.add_polygon(parent, "Head", PackedVector2Array([Vector2(24, -36), Vector2(43, -35), Vector2(46, -27), Vector2(31, -24)]), coat, target, time_of_day)
	Draw.add_polygon(parent, "Ear", PackedVector2Array([Vector2(28, -35), Vector2(28, -45), Vector2(34, -36)]), dark, target, time_of_day)
	for leg in [-18.0, -4.0, 10.0, 19.0]:
		Draw.add_rect(parent, "Leg%d" % int(leg), Vector2(leg, -4), Vector2(4, 19), dark, target, time_of_day)
	Draw.add_line(parent, "Tail", PackedVector2Array([Vector2(-30, -18), Vector2(-39, -8), Vector2(-37, 4)]), target, time_of_day, &"ink")
	Draw.add_rect(parent, "PackCloth", Vector2(-13, -27), Vector2(20, 12), MapVisualStyle.role_color(&"hay", target, time_of_day).darkened(0.12), target, time_of_day)
