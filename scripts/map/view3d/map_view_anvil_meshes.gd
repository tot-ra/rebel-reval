class_name MapViewAnvilMeshes
extends RefCounted

## Cached procedural London-pattern anvil: horn, face, waist, heel, and flared
## feet. Replaces the three-box stand-in so the smithy reads as a working tool.

static var _mesh_cache: Dictionary = {}


static func body_mesh() -> ArrayMesh:
	const CACHE_KEY := &"anvil_body_v1"
	if _mesh_cache.has(CACHE_KEY):
		return _mesh_cache[CACHE_KEY]

	# Stations run horn tip (-X) through face to heel (+X). Each ring is a
	# vertical rectangle (yt/yb) with half-width hz so the silhouette tapers.
	var stations: Array[Dictionary] = [
		{"x": -0.78, "yt": 0.50, "yb": 0.455, "hz": 0.03},
		{"x": -0.52, "yt": 0.555, "yb": 0.40, "hz": 0.085},
		{"x": -0.22, "yt": 0.62, "yb": 0.355, "hz": 0.145},
		{"x": -0.02, "yt": 0.625, "yb": 0.34, "hz": 0.165},
		{"x": 0.18, "yt": 0.62, "yb": 0.33, "hz": 0.16},
		{"x": 0.28, "yt": 0.55, "yb": 0.20, "hz": 0.11},
		{"x": 0.38, "yt": 0.52, "yb": 0.175, "hz": 0.125},
		{"x": 0.46, "yt": 0.40, "yb": 0.15, "hz": 0.14},
		{"x": 0.52, "yt": 0.26, "yb": 0.13, "hz": 0.145},
	]

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in stations.size() - 1:
		_loft_ring(surface, stations[index], stations[index + 1])

	# Flared feet under the waist/heel so the body does not float as a slab.
	_add_box(
		surface,
		Vector3(0.08, 0.07, 0.0),
		Vector3(0.42, 0.14, 0.34)
	)
	_add_box(
		surface,
		Vector3(0.30, 0.045, 0.0),
		Vector3(0.28, 0.09, 0.40)
	)

	surface.generate_normals()
	var mesh := surface.commit()
	_mesh_cache[CACHE_KEY] = mesh
	return mesh


static func _loft_ring(surface: SurfaceTool, a: Dictionary, b: Dictionary) -> void:
	var ax := float(a["x"])
	var bx := float(b["x"])
	var a_yt := float(a["yt"])
	var a_yb := float(a["yb"])
	var a_hz := float(a["hz"])
	var b_yt := float(b["yt"])
	var b_yb := float(b["yb"])
	var b_hz := float(b["hz"])

	var a_tl := Vector3(ax, a_yt, -a_hz)
	var a_tr := Vector3(ax, a_yt, a_hz)
	var a_br := Vector3(ax, a_yb, a_hz)
	var a_bl := Vector3(ax, a_yb, -a_hz)
	var b_tl := Vector3(bx, b_yt, -b_hz)
	var b_tr := Vector3(bx, b_yt, b_hz)
	var b_br := Vector3(bx, b_yb, b_hz)
	var b_bl := Vector3(bx, b_yb, -b_hz)

	_quad(surface, a_tl, b_tl, b_tr, a_tr) # top
	_quad(surface, a_bl, a_br, b_br, b_bl) # bottom
	_quad(surface, a_tl, a_bl, b_bl, b_tl) # -Z
	_quad(surface, a_tr, b_tr, b_br, a_br) # +Z

	# Cap the open horn tip and heel end so the loft is solid.
	if ax < -0.70:
		_quad(surface, a_tl, a_tr, a_br, a_bl)
	if bx > 0.50:
		_quad(surface, b_tl, b_bl, b_br, b_tr)


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
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
	surface.add_vertex(a)
	surface.add_vertex(c)
	surface.add_vertex(d)
