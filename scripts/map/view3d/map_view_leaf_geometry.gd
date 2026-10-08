extends RefCounted

## R-1194 leaf-cluster atlas tiles (column, row) in
## assets/materials/pbr/foliage_cards/leaf_card_atlas.png. Order matches
## tools/assets/generate_vegetation_atlases.py TILES (R-1329). Species without their own plate
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

## Golden angle (radians): successive needles never stack in one row.
const GOLDEN_ANGLE := 2.39996323


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
	outward_weight: float = 0.55,
	droop: float = 0.0
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
	var custom := Color(base.x, base.y, base.z, card_seed)
	var out_dir := outward.normalized() if outward.length_squared() > 0.0001 else plane
	# Each half is a strip of segments along the card axis. A flat two-facet card
	# lit as one plane reads as a plate; here the strip bows downward (droop, as
	# spruce shoots hang) and every vertex carries a smoothly varying normal that
	# is rounded across the width, so light rolls over the cluster like a volume.
	var segments := 3 if droop > 0.0 else 1
	for half: float in [-1.0, 1.0]:
		var u_edge := 0.5 + half * 0.5
		if mirrored:
			u_edge = 1.0 - u_edge
		# Two columns (spine, edge) x (segments + 1) rows.
		var positions: Array[Vector3] = []
		var normals: Array[Vector3] = []
		var uvs: Array[Vector2] = []
		for row in segments + 1:
			var t := float(row) / float(segments)
			var sag := Vector3.DOWN * (droop * size.y * t * t)
			var slope := axis * size.y + Vector3.DOWN * (2.0 * droop * size.y * t)
			var local_plane := slope.cross(side).normalized()
			if local_plane.dot(plane) < 0.0:
				local_plane = -local_plane
			var spine_n := local_plane.lerp(out_dir, outward_weight).normalized()
			# Edge normal tilts away from the spine: a rounded cross-section.
			var edge_n := (spine_n + side * half * 0.55).normalized()
			var row_origin := base + axis * size.y * t + sag
			positions.append(row_origin)
			normals.append(spine_n)
			uvs.append(Vector2(0.5, t))
			positions.append(row_origin + side * (half * size.x * 0.5) + fold)
			normals.append(edge_n)
			uvs.append(Vector2(u_edge, t))
		for row in segments:
			var i0 := row * 2
			var quad := [i0, i0 + 1, i0 + 3, i0 + 2]
			for triangle: Array in [[0, 1, 2], [0, 2, 3]]:
				var order: Array = [quad[triangle[0]], quad[triangle[1]], quad[triangle[2]]]
				var a := positions[order[0]]
				var b := positions[order[1]]
				var c := positions[order[2]]
				# Godot fronts are clockwise: wind against the spine normal.
				if (c - a).cross(b - a).dot(normals[i0]) < 0.0:
					order = [order[0], order[2], order[1]]
				for index: int in order:
					surface.set_normal(normals[index])
					surface.set_color(color)
					surface.set_uv(uvs[index])
					surface.set_uv2(Vector2(1, 1))
					surface.set_custom(0, custom)
					surface.add_vertex(positions[index])


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
		_append_needles(surface, center, axis, length, color, custom, use_custom)
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
	length: float,
	color: Color,
	custom: Color,
	use_custom: bool
) -> void:
	# A terminal shoot carries round needles instead of one oversized diamond.
	# Twelve three-sided needles cost 36 triangles, shared by all tree instances.
	append_needle_shoot(
		surface,
		center + axis * (-0.48 * length),
		axis,
		length,
		12,
		length * 0.5,
		length * 0.03,
		0.95,
		color,
		custom if use_custom else Color(0, 0, 0, -1.0),
		false
	)


## Bottlebrush conifer shoot: `count` needles spiralling round the shoot axis
## from `base` to `base + axis * length`. Every needle is a three-sided
## tapered pyramid with radial (smoothed) normals, so up close it shades as a
## small cylinder instead of a flat sliver; the old two-triangle diamonds and
## the textured cards both collapsed to a line when seen edge-on.
## `spread` is the needle's angle off the shoot axis (radians); `paired`
## (Scots pine) puts two needles on each fascicle instead of a single spiral.
## Contract matches append_leaf: UV2 = (1, 0) folded-leaf tag, UV.y rising from
## shoot base to tip for the canopy wind weight, CUSTOM0 = (base, seed) when
## custom.a >= 0 so the shoot sways and seasons as one unit.
## Returns the triangle count.
static func append_needle_shoot(
	surface: SurfaceTool,
	base: Vector3,
	axis: Vector3,
	length: float,
	count: int,
	needle_length: float,
	needle_radius: float,
	spread: float,
	color: Color,
	custom: Color,
	paired: bool
) -> int:
	axis = axis.normalized()
	var e1 := axis.cross(Vector3.UP)
	if e1.length_squared() < 0.0001:
		e1 = axis.cross(Vector3.RIGHT)
	e1 = e1.normalized()
	var e2 := axis.cross(e1).normalized()
	if e2.y < 0.0:
		e2 = -e2
	var use_custom := custom.a >= 0.0
	# Needle roots are self-shadowed by the shoot; tips catch the light.
	var root_color := Color(color.r * 0.74, color.g * 0.78, color.b * 0.74, color.a * 0.9)
	var triangles := 0
	var per_station := 2 if paired else 1
	var stations := maxi(1, floori(float(count) / float(per_station)))
	for station in stations:
		var t := (float(station) + 0.5) / float(stations)
		# Needles shorten toward the bud at the shoot tip.
		var needle := needle_length * lerpf(1.0, 0.62, t * t)
		var root := base + axis * (length * t)
		for pair_index in per_station:
			var yaw := float(station) * GOLDEN_ANGLE + float(pair_index) * PI
			var radial := e1 * cos(yaw) + e2 * sin(yaw)
			# Needles crowd onto the lit upper side, as on a real shoot.
			radial = (radial + e2 * 0.35).normalized()
			var heading := (axis * cos(spread) + radial * sin(spread)).normalized()
			triangles += _append_needle(
				surface,
				root,
				heading,
				needle,
				needle_radius,
				root_color,
				color,
				Vector2(t * 0.75, t * 0.75 + 0.25),
				custom,
				use_custom
			)
	return triangles


## One needle: three root corners round `root`, apex at the tip. Corner normals
## point radially out from the needle axis and the apex takes the face's mid
## radial, so the lighting rolls round the needle like a cylinder.
static func _append_needle(
	surface: SurfaceTool,
	root: Vector3,
	heading: Vector3,
	length: float,
	radius: float,
	root_color: Color,
	tip_color: Color,
	uv_y: Vector2,
	custom: Color,
	use_custom: bool
) -> int:
	var a1 := heading.cross(Vector3.UP)
	if a1.length_squared() < 0.0001:
		a1 = heading.cross(Vector3.RIGHT)
	a1 = a1.normalized()
	var a2 := heading.cross(a1).normalized()
	var tip := root + heading * length
	for k in 3:
		var angle_a := TAU * float(k) / 3.0
		var angle_b := TAU * float(k + 1) / 3.0
		var angle_m := (angle_a + angle_b) * 0.5
		var n_a := a1 * cos(angle_a) + a2 * sin(angle_a)
		var n_b := a1 * cos(angle_b) + a2 * sin(angle_b)
		var n_m := a1 * cos(angle_m) + a2 * sin(angle_m)
		var corner_a := root + n_a * radius
		var corner_b := root + n_b * radius
		# Godot fronts are clockwise seen from outside: a, tip, b.
		var points: Array[Vector3] = [corner_a, tip, corner_b]
		if (corner_b - corner_a).cross(tip - corner_a).dot(n_m) < 0.0:
			points = [corner_a, corner_b, tip]
		for point in points:
			var at_tip := point == tip
			var n := n_m if at_tip else (n_a if point == corner_a else n_b)
			surface.set_normal(n)
			surface.set_color(tip_color if at_tip else root_color)
			# UV.x off-centre keeps the folded-leaf midrib stripe off the needle.
			surface.set_uv(Vector2(0.2, uv_y.y if at_tip else uv_y.x))
			surface.set_uv2(Vector2(1, 0))
			if use_custom:
				surface.set_custom(0, custom)
			surface.add_vertex(point)
	return 3


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
