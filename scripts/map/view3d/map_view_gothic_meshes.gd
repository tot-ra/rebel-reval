extends RefCounted

## Small procedural mesh kit for Gothic masonry details: equilateral pointed
## openings (solid panels and arch bands), convex prisms (gables, gablets,
## weatherings), pyramid caps, and merged box batches.
##
## WHY: landmark builders place dozens of quoins, putlog holes and scaffold
## members; merging them into one mesh per material keeps the node and draw
## count low. Every triangle's winding is derived from its intended normal, so
## callers cannot produce inside-out faces. Meshes are cached per size key.

static var _cache: Dictionary = {}


## Equilateral pointed arch outline from bottom-left, over the apex, to
## bottom-right. Each arc has radius = width and springs from the opposite jamb.
static func pointed_outline(
	width: float, outline_height: float, segments: int = 6
) -> PackedVector2Array:
	var half := width * 0.5
	var rise := width * sqrt(3.0) * 0.5
	var spring := maxf(outline_height - rise, 0.0)
	var points := PackedVector2Array([Vector2(-half, 0.0), Vector2(-half, spring)])
	for index in range(1, segments):
		var angle := lerpf(PI, PI * 2.0 / 3.0, float(index) / float(segments))
		points.append(Vector2(half + cos(angle) * width, spring + sin(angle) * width))
	points.append(Vector2(0.0, spring + rise))
	for index in range(1, segments):
		var angle := lerpf(PI / 3.0, 0.0, float(index) / float(segments))
		points.append(Vector2(-half + cos(angle) * width, spring + sin(angle) * width))
	points.append(Vector2(half, spring))
	points.append(Vector2(half, 0.0))
	return points


static func pointed_panel(width: float, panel_height: float, depth: float) -> ArrayMesh:
	var key := "panel:%.3f:%.3f:%.3f" % [width, panel_height, depth]
	if not _cache.has(key):
		_cache[key] = prism(pointed_outline(width, panel_height), depth, false)
	return _cache[key]


## Convex outline in local XY extruded from z = 0 to z = depth (front at +Z).
static func prism(outline: PackedVector2Array, depth: float, cache := true) -> ArrayMesh:
	var key := "prism:%s:%.3f" % [outline, depth]
	if cache and _cache.has(key):
		return _cache[key]
	var st := begin()
	var centroid := Vector2.ZERO
	for point in outline:
		centroid += point
	centroid /= float(outline.size())
	var c3 := Vector3(centroid.x, centroid.y, 0.0)
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		tri(
			st,
			Vector3(a.x, a.y, depth),
			Vector3(b.x, b.y, depth),
			c3 + Vector3(0.0, 0.0, depth),
			Vector3.BACK
		)
		tri(st, Vector3(a.x, a.y, 0.0), Vector3(b.x, b.y, 0.0), c3, Vector3.FORWARD)
		var edge := b - a
		var n2 := Vector2(edge.y, -edge.x).normalized()
		if n2.dot((a + b) * 0.5 - centroid) < 0.0:
			n2 = -n2
		quad(
			st,
			Vector3(a.x, a.y, 0.0),
			Vector3(b.x, b.y, 0.0),
			Vector3(b.x, b.y, depth),
			Vector3(a.x, a.y, depth),
			Vector3(n2.x, n2.y, 0.0)
		)
	var mesh := st.commit()
	if cache:
		_cache[key] = mesh
	return mesh


## Pointed arch band (jambs and arch) of `thickness`, front face at z = depth.
static func pointed_ring(
	width: float, ring_height: float, thickness: float, depth: float
) -> ArrayMesh:
	var key := "ring:%.3f:%.3f:%.3f:%.3f" % [width, ring_height, thickness, depth]
	if _cache.has(key):
		return _cache[key]
	var outer := pointed_outline(width, ring_height)
	var inner := pointed_outline(width - thickness * 2.0, ring_height - thickness)
	var opening_center := Vector2(0.0, ring_height * 0.5)
	var st := begin()
	for index in outer.size() - 1:
		var oa := outer[index]
		var ob := outer[index + 1]
		var ia := inner[index]
		var ib := inner[index + 1]
		quad(
			st,
			Vector3(oa.x, oa.y, depth),
			Vector3(ob.x, ob.y, depth),
			Vector3(ib.x, ib.y, depth),
			Vector3(ia.x, ia.y, depth),
			Vector3.BACK
		)
		var out_n := Vector2(ob.y - oa.y, oa.x - ob.x).normalized()
		if out_n.dot((oa + ob) * 0.5 - opening_center) < 0.0:
			out_n = -out_n
		quad(
			st,
			Vector3(oa.x, oa.y, 0.0),
			Vector3(ob.x, ob.y, 0.0),
			Vector3(ob.x, ob.y, depth),
			Vector3(oa.x, oa.y, depth),
			Vector3(out_n.x, out_n.y, 0.0)
		)
		var in_n := Vector2(ib.y - ia.y, ia.x - ib.x).normalized()
		if in_n.dot((ia + ib) * 0.5 - opening_center) > 0.0:
			in_n = -in_n
		quad(
			st,
			Vector3(ia.x, ia.y, 0.0),
			Vector3(ib.x, ib.y, 0.0),
			Vector3(ib.x, ib.y, depth),
			Vector3(ia.x, ia.y, depth),
			Vector3(in_n.x, in_n.y, 0.0)
		)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


static func pyramid(half: float, rise: float) -> ArrayMesh:
	var key := "pyramid:%.3f:%.3f" % [half, rise]
	if _cache.has(key):
		return _cache[key]
	var st := begin()
	var apex := Vector3(0.0, rise, 0.0)
	var corners := [
		Vector3(-half, 0.0, -half),
		Vector3(half, 0.0, -half),
		Vector3(half, 0.0, half),
		Vector3(-half, 0.0, half)
	]
	for index in 4:
		var a: Vector3 = corners[index]
		var b: Vector3 = corners[(index + 1) % 4]
		var n := (b - a).cross(apex - a).normalized()
		if n.dot((a + b) * 0.5) < 0.0:
			n = -n
		tri(st, a, b, apex, n)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


static func begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func commit(
	parent: Node3D, mesh_name: String, st: SurfaceTool, material: Material
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = mesh_name
	instance.mesh = st.commit()
	instance.material_override = material
	parent.add_child(instance)
	return instance


static func append_box(
	st: SurfaceTool, size: Vector3, center: Vector3, basis := Basis.IDENTITY
) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3.RIGHT, Vector3.BACK, Vector3.UP],
		[Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK],
		[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
		[Vector3.FORWARD, Vector3.RIGHT, Vector3.UP],
	]
	for face: Array in faces:
		var n: Vector3 = face[0]
		var u: Vector3 = face[1]
		var v: Vector3 = face[2]
		var c := n * h
		var du := u * h
		var dv := v * h
		var p := [c - du - dv, c + du - dv, c + du + dv, c - du + dv]
		quad(
			st,
			center + basis * p[0],
			center + basis * p[1],
			center + basis * p[2],
			center + basis * p[3],
			basis * n
		)


static func quad(
	st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3
) -> void:
	tri(st, a, b, c, normal)
	tri(st, a, c, d, normal)


## Godot treats clockwise triangles (seen from the front) as front faces, so the
## winding is chosen from the intended normal rather than trusted from callers.
static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	var verts := [a, b, c]
	if (b - a).cross(c - a).dot(normal) > 0.0:
		verts = [a, c, b]
	var axis := normal.abs()
	for vert: Vector3 in verts:
		st.set_normal(normal)
		if axis.x >= axis.y and axis.x >= axis.z:
			st.set_uv(Vector2(vert.z, -vert.y))
		elif axis.y >= axis.z:
			st.set_uv(Vector2(vert.x, vert.z))
		else:
			st.set_uv(Vector2(vert.x, -vert.y))
		st.add_vertex(vert)
