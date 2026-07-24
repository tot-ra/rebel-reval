class_name MapViewAnvilMeshes
extends RefCounted

## Cached procedural London-pattern anvil: tapered horn, flat face, pinched waist,
## heel block, and flared feet. Hex-ring loft reads as forged iron instead of a
## rectangular banana slab.

static var _mesh_cache: Dictionary = {}


static func body_mesh() -> ArrayMesh:
	const CACHE_KEY := &"anvil_body_v2"
	if _mesh_cache.has(CACHE_KEY):
		return _mesh_cache[CACHE_KEY]

	# Stations run horn tip (-X) through face to heel (+X). Each ring is a
	# vertical hex (yt/yb half-depth hz) so the silhouette softens without
	# losing the classic London-pattern read.
	var stations: Array[Dictionary] = [
		{"x": -0.62, "yt": 0.34, "yb": 0.30, "hz": 0.025}, # horn tip
		{"x": -0.42, "yt": 0.38, "yb": 0.27, "hz": 0.07},
		{"x": -0.22, "yt": 0.40, "yb": 0.24, "hz": 0.11},
		{"x": -0.06, "yt": 0.405, "yb": 0.22, "hz": 0.13}, # face start
		{"x": 0.10, "yt": 0.405, "yb": 0.20, "hz": 0.135}, # face
		{"x": 0.22, "yt": 0.40, "yb": 0.16, "hz": 0.12},
		{"x": 0.30, "yt": 0.34, "yb": 0.10, "hz": 0.085}, # waist
		{"x": 0.38, "yt": 0.32, "yb": 0.08, "hz": 0.10}, # heel rise
		{"x": 0.48, "yt": 0.30, "yb": 0.06, "hz": 0.12},
		{"x": 0.54, "yt": 0.22, "yb": 0.05, "hz": 0.13}, # heel end
	]

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in stations.size() - 1:
		_loft_hex_ring(surface, stations[index], stations[index + 1])

	# Flat striking face sits proud of the loft so the working surface reads.
	_add_box(surface, Vector3(0.02, 0.415, 0.0), Vector3(0.36, 0.035, 0.28))
	# Flared feet under the waist/heel so the body does not float as a slab.
	_add_box(surface, Vector3(0.16, 0.04, 0.0), Vector3(0.38, 0.09, 0.30))
	_add_box(surface, Vector3(0.28, 0.02, 0.0), Vector3(0.24, 0.05, 0.36))

	surface.generate_normals()
	var mesh := surface.commit()
	_mesh_cache[CACHE_KEY] = mesh
	return mesh


static func _loft_hex_ring(surface: SurfaceTool, a: Dictionary, b: Dictionary) -> void:
	var a_ring := _hex_ring(float(a["x"]), float(a["yt"]), float(a["yb"]), float(a["hz"]))
	var b_ring := _hex_ring(float(b["x"]), float(b["yt"]), float(b["yb"]), float(b["hz"]))
	for i in 6:
		var next_i := (i + 1) % 6
		_quad(surface, a_ring[i], b_ring[i], b_ring[next_i], a_ring[next_i])

	# Cap the open horn tip and heel end so the loft is solid.
	if float(a["x"]) < -0.55:
		_cap_hex(surface, a_ring, true)
	if float(b["x"]) > 0.50:
		_cap_hex(surface, b_ring, false)


static func _hex_ring(x: float, yt: float, yb: float, hz: float) -> Array[Vector3]:
	# Order: top-back, top-front, mid-front, bottom-front, bottom-back, mid-back.
	var mid_y := (yt + yb) * 0.5
	var side_hz := hz * 1.08
	return [
		Vector3(x, yt, -hz),
		Vector3(x, yt, hz),
		Vector3(x, mid_y, side_hz),
		Vector3(x, yb, hz),
		Vector3(x, yb, -hz),
		Vector3(x, mid_y, -side_hz),
	]


static func _cap_hex(surface: SurfaceTool, ring: Array[Vector3], outward_negative_x: bool) -> void:
	# Fan from ring centroid so hex end caps stay planar.
	var center := Vector3.ZERO
	for point in ring:
		center += point
	center /= float(ring.size())
	for i in 6:
		var next_i := (i + 1) % 6
		if outward_negative_x:
			_tri(surface, center, ring[next_i], ring[i])
		else:
			_tri(surface, center, ring[i], ring[next_i])


static func _add_box(surface: SurfaceTool, center: Vector3, size: Vector3) -> void:
	var half := size * 0.5
	var p := [
		center + Vector3(-half.x, -half.y, -half.z),
		center + Vector3(half.x, -half.y, -half.z),
		center + Vector3(half.x, -half.y, half.z),
		center + Vector3(-half.x, -half.y, half.z),
		center + Vector3(-half.x, half.y, -half.z),
		center + Vector3(half.x, half.y, -half.z),
		center + Vector3(half.x, half.y, half.z),
		center + Vector3(-half.x, half.y, half.z),
	]
	_quad(surface, p[4], p[5], p[6], p[7]) # top
	_quad(surface, p[0], p[3], p[2], p[1]) # bottom
	_quad(surface, p[0], p[1], p[5], p[4]) # -Z
	_quad(surface, p[3], p[7], p[6], p[2]) # +Z
	_quad(surface, p[0], p[4], p[7], p[3]) # -X
	_quad(surface, p[1], p[2], p[6], p[5]) # +X


static func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(surface, a, b, c)
	_tri(surface, a, c, d)


static func _tri(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
