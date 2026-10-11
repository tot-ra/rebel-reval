class_name CogParts
extends RefCounted

## Accumulates oriented boxes, tubes and lathe solids into ONE vertex-coloured mesh,
## so a whole cog costs a handful of draw calls instead of hundreds of nodes.
## All geometry is in metres. Godot front faces are clockwise, so every helper
## takes corners counter-clockwise seen from outside and emits them reversed.

## Grain repeats every GRAIN_U metres along a timber and every GRAIN_V across it
## (the beam-wood texture is one plank wide).
const GRAIN_U := 1.6
const GRAIN_V := 0.32

var _st := SurfaceTool.new()
var _vertices := 0


func _init() -> void:
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)


func vertex_count() -> int:
	return _vertices


func commit() -> ArrayMesh:
	if _vertices == 0:
		return null
	return _st.commit()


## Counter-clockwise (seen from the side `normal` points to) quad.
func quad(
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	normal: Vector3,
	color: Color,
	uv_a := Vector2(0, 0),
	uv_b := Vector2(1, 0),
	uv_c := Vector2(1, 1),
	uv_d := Vector2(0, 1)
) -> void:
	_tri(a, c, b, normal, color, uv_a, uv_c, uv_b)
	_tri(a, d, c, normal, color, uv_a, uv_d, uv_c)


## Quad with a normal per corner (lofted hull), counter-clockwise from outside.
func smooth_quad(p: Array[Vector3], n: Array[Vector3], uv: Array[Vector2], color: Color) -> void:
	for idx: int in [0, 2, 1, 0, 3, 2]:
		_st.set_color(color)
		_st.set_normal(n[idx])
		_st.set_uv(uv[idx])
		_st.add_vertex(p[idx])
		_vertices += 1


func _tri(
	a: Vector3,
	b: Vector3,
	c: Vector3,
	normal: Vector3,
	color: Color,
	uv_a: Vector2,
	uv_b: Vector2,
	uv_c: Vector2
) -> void:
	for pair: Array in [[a, uv_a], [b, uv_b], [c, uv_c]]:
		_st.set_color(color)
		_st.set_normal(normal)
		_st.set_uv(pair[1])
		_st.add_vertex(pair[0])
		_vertices += 1


## Oriented box. `basis` columns are the local axes; the grain runs along the
## longest side of each face.
func box(center: Vector3, size: Vector3, color: Color, basis := Basis.IDENTITY) -> void:
	var half := size * 0.5
	var salt := fposmod(center.x * 12.9898 + center.y * 78.233 + center.z * 37.719, 1.0)
	for axis in 3:
		var u_i := (axis + 1) % 3
		var v_i := (axis + 2) % 3
		if size[v_i] > size[u_i]:
			var swap := u_i
			u_i = v_i
			v_i = swap
		var u_axis := basis[u_i]
		var v_axis := basis[v_i]
		for sign_n: float in [1.0, -1.0]:
			var n_axis := basis[axis] * sign_n
			var c := center + n_axis * half[axis]
			var hu := u_axis * half[u_i]
			var hv := v_axis * half[v_i]
			var corners: Array[Vector3] = [c - hu - hv, c + hu - hv, c + hu + hv, c - hu + hv]
			if u_axis.cross(v_axis).dot(n_axis) < 0.0:
				corners.reverse()
				# Reversing mirrors u; the uv rectangle below stays consistent.
			var du := size[u_i] / GRAIN_U
			var dv := size[v_i] / GRAIN_V
			var o := Vector2(salt * 5.0, salt * 3.0)
			quad(
				corners[0],
				corners[1],
				corners[2],
				corners[3],
				n_axis.normalized(),
				color,
				o,
				o + Vector2(du, 0),
				o + Vector2(du, dv),
				o + Vector2(0, dv)
			)


## Box between two points (beam, plank, post), `up` fixes the roll.
func beam(
	a: Vector3, b: Vector3, width: float, depth: float, color: Color, up := Vector3.UP
) -> void:
	var dir := b - a
	if dir.length() < 0.001:
		return
	var x_axis := dir.normalized()
	var z_axis := x_axis.cross(up)
	if z_axis.length() < 0.01:
		z_axis = x_axis.cross(Vector3.RIGHT)
	z_axis = z_axis.normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	box((a + b) * 0.5, Vector3(dir.length(), depth, width), color, Basis(x_axis, y_axis, z_axis))


## Round rod from a to b, optionally tapered. `sides` radial segments; uv.x runs
## along the rod, uv.y around it.
func tube(
	a: Vector3, b: Vector3, r_a: float, r_b: float, sides: int, color: Color, caps := true
) -> void:
	var dir := b - a
	if dir.length() < 0.001:
		return
	var axis := dir.normalized()
	var ref := Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT
	var side_axis := axis.cross(ref).normalized()
	var up_axis := side_axis.cross(axis).normalized()
	var length := dir.length()
	for i in sides:
		var a0 := TAU * float(i) / sides
		var a1 := TAU * float(i + 1) / sides
		var d0 := side_axis * cos(a0) + up_axis * sin(a0)
		var d1 := side_axis * cos(a1) + up_axis * sin(a1)
		var p: Array[Vector3] = [a + d0 * r_a, b + d0 * r_b, b + d1 * r_b, a + d1 * r_a]
		var n: Array[Vector3] = [d0, d0, d1, d1]
		var uv: Array[Vector2] = [
			Vector2(0, float(i) / sides * 0.3),
			Vector2(length / GRAIN_U, float(i) / sides * 0.3),
			Vector2(length / GRAIN_U, float(i + 1) / sides * 0.3),
			Vector2(0, float(i + 1) / sides * 0.3)
		]
		# a -> b is the "ds" direction, around is "da": ds x da points outwards when
		# the ring runs counter-clockwise about the axis, which is how a0 -> a1 runs.
		smooth_quad(p, n, uv, color)
	if caps:
		_cap(a, -axis, side_axis, up_axis, r_a, sides, color)
		_cap(b, axis, side_axis, up_axis, r_b, sides, color)


func _cap(
	center: Vector3,
	normal: Vector3,
	s_axis: Vector3,
	u_axis: Vector3,
	radius: float,
	sides: int,
	color: Color
) -> void:
	for i in sides:
		var a0 := TAU * float(i) / sides
		var a1 := TAU * float(i + 1) / sides
		var p0 := center + (s_axis * cos(a0) + u_axis * sin(a0)) * radius
		var p1 := center + (s_axis * cos(a1) + u_axis * sin(a1)) * radius
		var uv_c := Vector2(0.5, 0.5)
		if normal.dot(s_axis.cross(u_axis)) > 0.0:
			_tri(center, p1, p0, normal, color, uv_c, uv_c, uv_c)
		else:
			_tri(center, p0, p1, normal, color, uv_c, uv_c, uv_c)


## Solid of revolution about the +Y axis through `origin`: profile is (radius, height)
## pairs bottom to top. Used for barrels, bollards, deadeyes, blocks.
func lathe(
	origin: Vector3, profile: Array[Vector2], sides: int, color: Color, basis := Basis.IDENTITY
) -> void:
	for k in profile.size() - 1:
		var lo := profile[k]
		var hi := profile[k + 1]
		for i in sides:
			var a0 := TAU * float(i) / sides
			var a1 := TAU * float(i + 1) / sides
			var d0 := Vector3(cos(a0), 0.0, sin(a0))
			var d1 := Vector3(cos(a1), 0.0, sin(a1))
			var slope := Vector3(0.0, lo.x - hi.x, 0.0)  # outward lean of the wall
			var p: Array[Vector3] = [
				origin + basis * (d0 * lo.x + Vector3(0, lo.y, 0)),
				origin + basis * (d0 * hi.x + Vector3(0, hi.y, 0)),
				origin + basis * (d1 * hi.x + Vector3(0, hi.y, 0)),
				origin + basis * (d1 * lo.x + Vector3(0, lo.y, 0)),
			]
			var n0 := (
				(basis * (d0 * (hi.y - lo.y) + Vector3(0, lo.x - hi.x, 0) + slope * 0.0))
				. normalized()
			)
			var n1 := (basis * (d1 * (hi.y - lo.y) + Vector3(0, lo.x - hi.x, 0))).normalized()
			var n: Array[Vector3] = [n0, n0, n1, n1]
			var uv: Array[Vector2] = [
				Vector2(float(i) / sides, lo.y),
				Vector2(float(i) / sides, hi.y),
				Vector2(float(i + 1) / sides, hi.y),
				Vector2(float(i + 1) / sides, lo.y)
			]
			smooth_quad(p, n, uv, color)
	# Flat top and bottom discs.
	var top := profile[profile.size() - 1]
	var bottom := profile[0]
	for i in sides:
		var a0 := TAU * float(i) / sides
		var a1 := TAU * float(i + 1) / sides
		var tc := origin + basis * Vector3(0, top.y, 0)
		var t0 := origin + basis * (Vector3(cos(a0), 0, sin(a0)) * top.x + Vector3(0, top.y, 0))
		var t1 := origin + basis * (Vector3(cos(a1), 0, sin(a1)) * top.x + Vector3(0, top.y, 0))
		_tri(
			tc,
			t0,
			t1,
			basis * Vector3.UP,
			color,
			Vector2(0.5, 0.5),
			Vector2(0.5, 0.5),
			Vector2(0.5, 0.5)
		)
		var bc := origin + basis * Vector3(0, bottom.y, 0)
		var b0 := (
			origin + basis * (Vector3(cos(a0), 0, sin(a0)) * bottom.x + Vector3(0, bottom.y, 0))
		)
		var b1 := (
			origin + basis * (Vector3(cos(a1), 0, sin(a1)) * bottom.x + Vector3(0, bottom.y, 0))
		)
		_tri(
			bc,
			b1,
			b0,
			basis * Vector3.DOWN,
			color,
			Vector2(0.5, 0.5),
			Vector2(0.5, 0.5),
			Vector2(0.5, 0.5)
		)


## Rope segment chain from a to b for the rig shader. uv.x = 0..1 along the rope,
## uv.y = slack: the largest sag in metres at mid span. Ends stay pinned.
func rope(a: Vector3, b: Vector3, radius: float, slack: float, color: Color) -> void:
	var length := a.distance_to(b)
	if length < 0.01:
		return
	var segments := clampi(ceili(length / 0.9), 2, 18)
	var axis := (b - a) / length
	var ref := Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT
	var side_axis := axis.cross(ref).normalized()
	var up_axis := side_axis.cross(axis).normalized()
	for seg in segments:
		var t0 := float(seg) / segments
		var t1 := float(seg + 1) / segments
		for i in 4:
			var a0 := TAU * float(i) / 4.0
			var a1 := TAU * float(i + 1) / 4.0
			var d0 := side_axis * cos(a0) + up_axis * sin(a0)
			var d1 := side_axis * cos(a1) + up_axis * sin(a1)
			var p: Array[Vector3] = [
				a.lerp(b, t0) + d0 * radius,
				a.lerp(b, t1) + d0 * radius,
				a.lerp(b, t1) + d1 * radius,
				a.lerp(b, t0) + d1 * radius,
			]
			var n: Array[Vector3] = [d0, d0, d1, d1]
			var uv: Array[Vector2] = [
				Vector2(t0, slack), Vector2(t1, slack), Vector2(t1, slack), Vector2(t0, slack)
			]
			smooth_quad(p, n, uv, color)
