extends RefCounted


## Small opaque folded leaves: no alpha cards, textures or per-leaf nodes.
## The existing tree skeleton still owns leaf positions and species identity.
static func append_leaf(
	surface: SurfaceTool,
	species: StringName,
	center: Vector3,
	direction: Vector3,
	length: float,
	width: float,
	color: Color
) -> void:
	var axis := direction.normalized()
	var side := axis.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = axis.cross(Vector3.RIGHT)
	side = side.normalized()
	var normal := side.cross(axis).normalized()
	var needle := species in [&"spruce", &"pine", &"juniper"]
	if needle:
		_append_needles(surface, center, axis, side, normal, length, color)
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
			surface.add_vertex(point[0])


static func _append_needles(
	surface: SurfaceTool,
	center: Vector3,
	axis: Vector3,
	side: Vector3,
	normal: Vector3,
	length: float,
	color: Color
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
