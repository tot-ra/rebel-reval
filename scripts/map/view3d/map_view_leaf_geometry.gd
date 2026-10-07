extends RefCounted

## R-1194 leaf-cluster atlas tiles (column, row) in
## assets/materials/pbr/foliage_cards/leaf_card_atlas.png. Order matches
## tools/assets/build_leaf_card_atlas.py TILES. Species without their own plate
## borrow the closest leaf shape.
const CARD_ATLAS_GRID := Vector2(4, 2)
const CARD_TILES := {
	&"birch": Vector2(0, 0),
	&"aspen": Vector2(0, 0),
	&"willow": Vector2(0, 0),
	&"ash": Vector2(0, 0),
	&"rowan": Vector2(0, 0),
	&"oak": Vector2(1, 0),
	&"maple": Vector2(2, 0),
	&"hawthorn": Vector2(2, 0),
	&"linden": Vector2(3, 0),
	&"alder": Vector2(3, 0),
	&"hazel": Vector2(3, 0),
	&"elm": Vector2(3, 0),
	&"apple": Vector2(0, 1),
	&"cherry": Vector2(0, 1),
	&"plum": Vector2(0, 1),
	&"pear": Vector2(0, 1),
	&"blackthorn": Vector2(0, 1),
	&"spruce": Vector2(1, 1),
	&"juniper": Vector2(1, 1),
	&"pine": Vector2(2, 1),
}


static func card_tile(species: StringName) -> Vector2:
	return CARD_TILES.get(species, Vector2(3, 0))


## Alpha-scissor leaf-cluster card (R-1194): one atlas cluster of several leaves
## on a quad folded along its midline, so it keeps some volume from the side.
## Two halves, four triangles. UV is the card-local 0..1 square with UV.y = 0 at
## the twig end, so the canopy shader's petiole wind weight (UV.y^2) and the
## seasonal CUSTOM0 collapse work exactly as for folded leaves. UV2 = (1, 1)
## tags a card; the species material picks the atlas tile.
## Normals lean toward `outward` (away from the crown centre): a crown of flat
## cards otherwise lights like scattered paper instead of one leafy volume.
static func append_card(
	surface: SurfaceTool,
	base: Vector3,
	axis: Vector3,
	facing: Vector3,
	outward: Vector3,
	size: Vector2,
	color: Color,
	card_seed: float,
	mirrored: bool,
	outward_weight: float = 0.55
) -> void:
	axis = axis.normalized()
	var side := facing.cross(axis)
	if side.length_squared() < 0.0001:
		side = axis.cross(Vector3.RIGHT if absf(axis.x) < 0.9 else Vector3.FORWARD)
	side = side.normalized()
	var plane := axis.cross(side).normalized()
	if plane.dot(facing) < 0.0:
		plane = -plane
	var fold := plane * (-size.x * 0.16)
	var tip := axis * size.y
	var custom := Color(base.x, base.y, base.z, card_seed)
	for half: float in [-1.0, 1.0]:
		var edge := side * (half * size.x * 0.5) + fold
		var points: Array[Vector3] = [base, base + edge, base + edge + tip, base + tip]
		var u_edge := 0.5 + half * 0.5
		if mirrored:
			u_edge = 1.0 - u_edge
		var uvs: Array[Vector2] = [
			Vector2(0.5, 0.0), Vector2(u_edge, 0.0), Vector2(u_edge, 1.0), Vector2(0.5, 1.0)
		]
		var facet := (edge.cross(tip) * half).normalized()
		if facet.dot(plane) < 0.0:
			facet = -facet
		var normal := facet.lerp(outward.normalized(), outward_weight).normalized()
		if normal.length_squared() < 0.5:
			normal = facet
		for triangle: Array in [[0, 1, 2], [0, 2, 3]]:
			var a := points[triangle[0]]
			var b := points[triangle[1]]
			var c := points[triangle[2]]
			var order: Array = triangle
			# Godot fronts are clockwise: keep the winding consistent with the
			# leaning normal so back-face lighting fix-ups stay predictable.
			if (c - a).cross(b - a).dot(normal) < 0.0:
				order = [triangle[0], triangle[2], triangle[1]]
			for index: int in order:
				surface.set_normal(normal)
				surface.set_color(color)
				surface.set_uv(uvs[index])
				surface.set_uv2(Vector2(1, 1))
				surface.set_custom(0, custom)
				surface.add_vertex(points[index])


## Small opaque folded leaves: no textures or per-leaf nodes. Since R-1194 they
## are the close-up silhouette detail; append_card cluster cards carry the mass.
## The existing tree skeleton still owns leaf positions and species identity.
##
## Seasonal contract (R-1187): when `leaf_seed` >= 0 every vertex carries
## CUSTOM0 = (petiole xyz, leaf_seed). The canopy shader shrinks a leaf toward
## its petiole for young spring leaves, collapses it to a point when the season
## says it has fallen, and picks its autumn hue from the seed. The caller must
## enable SurfaceTool custom channel 0 (CUSTOM_RGBA_FLOAT) before appending.
static func append_leaf(
	surface: SurfaceTool,
	species: StringName,
	center: Vector3,
	direction: Vector3,
	length: float,
	width: float,
	color: Color,
	leaf_seed: float = -1.0
) -> void:
	var axis := direction.normalized()
	var side := axis.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = axis.cross(Vector3.RIGHT)
	side = side.normalized()
	var normal := side.cross(axis).normalized()
	var needle := species in [&"spruce", &"pine", &"juniper"]
	var petiole := center + axis * (-0.48 * length)
	var custom := Color(petiole.x, petiole.y, petiole.z, leaf_seed)
	var use_custom := leaf_seed >= 0.0
	if needle:
		_append_needles(surface, center, axis, side, normal, length, color, custom, use_custom)
		return
	var lobed := species in [&"oak", &"maple", &"hawthorn"]
	var steps := 5 if lobed else 3
	var rim: Array[Vector2] = [Vector2(0.5, 0)]
	for i in steps:
		var t := float(i + 1) / float(steps + 1)
		rim.append(Vector2(0.5 + _width_at(species, t, i) * 0.5, t))
	rim.append(Vector2(0.5, 1))
	for i in range(steps - 1, -1, -1):
		var t := float(i + 1) / float(steps + 1)
		rim.append(Vector2(0.5 - _width_at(species, t, i) * 0.48, t))
	var ridge := center + normal * width * 0.12
	for i in rim.size():
		var uv_a := rim[i]
		var uv_b := rim[(i + 1) % rim.size()]
		var a := _point(center, axis, side, normal, length, width, uv_a)
		var b := _point(center, axis, side, normal, length, width, uv_b)
		var face_normal := (b - ridge).cross(a - ridge).normalized()
		for point: Array in [[ridge, Vector2(0.5, 0.48)], [a, uv_a], [b, uv_b]]:
			surface.set_normal(face_normal)
			surface.set_color(color)
			surface.set_uv(point[1])
			surface.set_uv2(Vector2(1, 0))
			if use_custom:
				surface.set_custom(0, custom)
			surface.add_vertex(point[0])


static func _append_needles(
	surface: SurfaceTool,
	center: Vector3,
	axis: Vector3,
	side: Vector3,
	normal: Vector3,
	length: float,
	color: Color,
	custom: Color,
	use_custom: bool
) -> void:
	# A terminal shoot carries paired needles instead of one oversized diamond.
	# Fourteen opaque needles cost 28 triangles, shared by all tree instances.
	for pair in 7:
		var t := float(pair) / 7.0
		var root := center + axis * ((t - 0.48) * length)
		for sign_value: float in [-1.0, 1.0]:
			var heading := (axis * 0.55 + side * sign_value * 0.82 + normal * 0.12).normalized()
			var tip := root + heading * length * (0.48 - t * 0.18)
			var mid := root.lerp(tip, 0.40)
			var cross_axis := normal.cross(heading).normalized() * length * 0.018
			var points: Array[Vector3] = [root, mid + cross_axis, tip, root, tip, mid - cross_axis]
			for i in points.size():
				surface.set_normal(normal)
				surface.set_color(color)
				# Shoot base stays attached; fine needles flex toward the shoot tip.
				surface.set_uv(
					Vector2(
						0.5 if i in [0, 2, 3, 4] else (1.0 if i == 1 else 0.0),
						t + (0.12 if i in [2, 4] else 0.0)
					)
				)
				surface.set_uv2(Vector2(1, 0))
				if use_custom:
					surface.set_custom(0, custom)
				surface.add_vertex(points[i])


static func _point(
	center: Vector3,
	axis: Vector3,
	side: Vector3,
	normal: Vector3,
	length: float,
	width: float,
	uv: Vector2
) -> Vector3:
	# The tip curls away from the midrib; the two halves meet at a raised ridge.
	return (
		center
		+ axis * ((uv.y - 0.48) * length)
		+ side * ((uv.x - 0.5) * width)
		- normal * (uv.y * uv.y * width * 0.16)
	)


static func _width_at(species: StringName, t: float, index: int) -> float:
	if species in [&"spruce", &"pine", &"juniper"]:
		return 1.0
	if species in [&"oak", &"maple", &"hawthorn"]:
		return sin(PI * t) * (0.65 if index % 2 == 1 else 1.0)
	if species == &"birch":
		return pow(1.0 - t, 0.7) * 1.35
	if species in [&"aspen", &"alder", &"hazel", &"linden"]:
		return pow(sin(PI * t), 0.45)
	return sin(PI * t)
