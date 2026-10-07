extends RefCounted

## Shared dimensions, colours and geometry helpers of the council-hall model
## (site.raekoja_plats, ADR 0032): used by raekoja_plats_builder.gd (shell,
## roof, assembly) and raekoja_plats_interior.gd (rooms and furniture).

const LENGTH := 26.0
const DEPTH := 14.8
const WALL := 0.95
const FLOOR := 0.12
const EAVE := 4.9
const SINK := 0.6
const PITCH_DEG := 50.0
const CUT := FLOOR + CityBuildingBuilder.CUT_HEIGHT
const PARAPET := 0.45
const EAVE_OVERHANG := 0.45

const PORTAL_W := 1.4
const PORTAL_H := 2.35
const WIN_W := 0.95
const WIN_H := 1.55
const WIN_SILL := 1.45
## Inward splay of window reveals (each side), metres.
const SPLAY := 0.28

const STONE := Color(0.93, 0.91, 0.86)
const ASHLAR := Color(0.86, 0.84, 0.79)
const OAK := Color(0.58, 0.47, 0.36)
const OAK_DARK := Color(0.4, 0.31, 0.23)
const IRON := Color(0.17, 0.16, 0.15)

const BannerMesh := preload("res://scripts/map/view3d/map_view_town_hall_model.gd")
const LIMEWASH := preload("res://scripts/city/city_limewash.gdshader")
const FLAGSTONE := preload("res://scripts/city/city_flagstone.gdshader")

## Posts under the summer beam (site-local x, z).
const POSTS: Array[Vector2] = [Vector2(-6.6, 0.0), Vector2(-1.6, 0.0)]
## Partition between diele and dornse: west face x, thickness, door span (z).
const PART_X := 4.1
const PART_T := 0.6
const PART_DOOR := Vector2(1.5, 2.9)
const PART_DOOR_H := 2.35
const DAIS := Rect2(-12.05, -3.2, 2.35, 6.4)
const DAIS_H := 0.28

static var _materials: Dictionary = {}


static func _holed_face(
	shell: CityBuildingBuilder.Shell,
	key: String,
	at: Callable,
	s_min: float,
	s_max: float,
	y_min: float,
	y_max: float,
	openings: Array,
	face: Vector3,
	color: Color
) -> void:
	var ss: Array[float] = [s_min, s_max]
	var ys: Array[float] = [y_min, y_max]
	for o: Rect2 in openings:
		ss.append_array([o.position.x, o.end.x])
		ys.append_array([o.position.y, o.end.y])
	ss.sort()
	ys.sort()
	for i in ss.size() - 1:
		for j in ys.size() - 1:
			var s0: float = clampf(ss[i], s_min, s_max)
			var s1: float = clampf(ss[i + 1], s_min, s_max)
			var y0: float = clampf(ys[j], y_min, y_max)
			var y1: float = clampf(ys[j + 1], y_min, y_max)
			if s1 - s0 < 0.001 or y1 - y0 < 0.001:
				continue
			var mid := Vector2((s0 + s1) * 0.5, (y0 + y1) * 0.5)
			var hole := false
			for o: Rect2 in openings:
				hole = hole or o.has_point(mid)
			if hole:
				continue
			shell.quad_out(
				key, at.call(s0, y0), at.call(s1, y0), at.call(s1, y1), at.call(s0, y1), color, face
			)


## Square bar of side `size` from a to b (timber, rope, voussoirs).
static func _bar(
	shell: CityBuildingBuilder.Shell, key: String, a: Vector3, b: Vector3, size: float, color: Color
) -> void:
	var d := (b - a).normalized()
	var ref := Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT
	var u := d.cross(ref).normalized() * size * 0.5
	var v := d.cross(u).normalized() * size * 0.5
	var ring := [u + v, u - v, -u - v, -u + v]
	for k in 4:
		var p: Vector3 = ring[k]
		var q: Vector3 = ring[(k + 1) % 4]
		shell.quad_out(key, a + p, a + q, b + q, b + p, color, p + q)


static func _quad_box(
	shell: CityBuildingBuilder.Shell,
	key: String,
	p0: Vector2,
	p1: Vector2,
	n: Vector2,
	y0: float,
	y1: float,
	o0: float,
	o1: float,
	color: Color
) -> void:
	var v := [
		Vector3(p0.x + n.x * o0, y0, p0.y + n.y * o0),
		Vector3(p1.x + n.x * o0, y0, p1.y + n.y * o0),
		Vector3(p1.x + n.x * o0, y1, p1.y + n.y * o0),
		Vector3(p0.x + n.x * o0, y1, p0.y + n.y * o0),
		Vector3(p0.x + n.x * o1, y0, p0.y + n.y * o1),
		Vector3(p1.x + n.x * o1, y0, p1.y + n.y * o1),
		Vector3(p1.x + n.x * o1, y1, p1.y + n.y * o1),
		Vector3(p0.x + n.x * o1, y1, p0.y + n.y * o1),
	]
	var c: Vector3 = (v[0] + v[6]) * 0.5
	for face: Array in [
		[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [3, 2, 6, 7], [0, 3, 7, 4], [1, 2, 6, 5]
	]:
		var q0: Vector3 = v[face[0]]
		var q1: Vector3 = v[face[1]]
		var q2: Vector3 = v[face[2]]
		var q3: Vector3 = v[face[3]]
		shell.quad_out(key, q0, q1, q2, q3, color, (q0 + q1 + q2 + q3) * 0.25 - c)
