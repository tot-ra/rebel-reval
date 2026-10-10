class_name CityFish
extends Node3D

## Schools of Baltic herring and the odd perch over the shallows (kalamaja-fishing-
## shore-1343.md: the shore lives off spring herring). Deterministic school
## centres on 0.35 to 1.1 m of water; a school is only alive while Kalev is within
## RANGE of it, then its fish circle and dart in a tight shoal just under the
## surface. Visual only: nothing here is caught, hit or saved.

const CELL := 14.0
const RANGE := 70.0
const FREE_RANGE := 95.0
const MAX_SCHOOLS := 7
const FISH_PER_SCHOOL := 11
const SEED := 4141
## Preserve deterministic school IDs in the clear shallows.
const MIN_DEPTH := 0.35
const MAX_DEPTH := 1.1
## Mesh part ids (UV2.y) and body loft, shared with city_fish.gdshader.
const PART_BODY := 0.0
const PART_CAUDAL := 1.0
const PART_DORSAL := 2.0
const PART_PECTORAL := 3.0
const PART_PELVIC := 4.0
const PART_ANAL := 5.0
const PART_SOFT_DORSAL := 6.0
const BODY_NOSE := 0.49
const BODY_LENGTH := 0.91
const BODY_RINGS := 22
const BODY_SIDES := 16

var plan: CityPlan
var player: Node2D
var _centres: Array[Dictionary] = []
var _live: Dictionary = {}
var _fish_mesh: Mesh
var _perch_mesh: Mesh
var _since := 1.0
var _time := 0.0


static func create(city_plan: CityPlan, kalev: Node2D) -> CityFish:
	var node := CityFish.new()
	node.name = "Fish"
	node.plan = city_plan
	node.player = kalev
	node._centres = school_centres(city_plan)
	node._prepare()
	return node


## Deterministic schools: {id, at: Vector2, depth, species}. Pure data for tests.
static func school_centres(city_plan: CityPlan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var r := city_plan.bounds
	for j in int(r.size.y / CELL):
		for i in int(r.size.x / CELL):
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(Vector2i(i, j)) ^ SEED
			if rng.randf() > 0.3:
				continue
			var at := r.position + (Vector2(i, j) + Vector2(rng.randf(), rng.randf())) * CELL
			var depth := -city_plan.ground_height(at)
			if depth < MIN_DEPTH or depth > MAX_DEPTH:
				continue
			(
				out
				. append(
					{
						"id": "school.%d.%d" % [i, j],
						"at": at,
						"depth": depth,
						"species": &"perch" if rng.randf() < 0.18 else &"herring",
					}
				)
			)
	return out


func _prepare() -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/city/city_fish.gdshader")
	_fish_mesh = build_mesh(false)
	_perch_mesh = build_mesh(true)
	_fish_mesh.surface_set_material(0, material)
	_perch_mesh.surface_set_material(0, material)


## One fish in mesh space: +X forward, nose at x 0.5, tail tips at x -0.78, every
## fin inside y -0.24..0.29 and z +-0.24 (the bounds fish_transform fits to the
## water column). UV2 = (ring height -1 belly .. 1 back, part id) drives the
## painted look in city_fish.gdshader; UV is (along, around) on the body and
## (base-to-edge, along-the-base) on fins.
static func build_mesh(perch: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_body(st, perch)
	# Fins are flat membranes: their own smooth group keeps body normals rounded.
	st.set_smooth_group(-1)
	_add_tail(st, perch)
	var dorsal_top := 0.12 if perch else 0.095
	if perch:
		# Spiny first dorsal (zigzag of spines) and the soft second dorsal behind it.
		_add_dorsal(st, perch, 0.27, 0.02, dorsal_top, 9, PART_DORSAL)
		_add_dorsal(st, perch, -0.02, -0.27, 0.085, 5, PART_SOFT_DORSAL)
	else:
		_add_dorsal(st, perch, 0.08, -0.12, dorsal_top, 5, PART_DORSAL)
	for side: float in [-1.0, 1.0]:
		_add_paired_fin(st, perch, side, 0.31, Vector2(-0.03, -0.05), PART_PECTORAL)
		_add_paired_fin(st, perch, side, 0.12 if perch else 0.06, Vector2(-0.10, -0.12), PART_PELVIC)
	_add_anal(st, perch)
	st.generate_normals()
	return st.commit()


## Half-extents of the body ring at u (0 nose .. 1 tail stalk): (top, bottom, width).
static func _profile(u: float, perch: bool) -> Vector3:
	# Blunt head, deepest a third back, a thin caudal stalk that never closes.
	var s := sin(PI * (0.05 + 0.9 * pow(clampf(u, 0.0, 1.0), 0.62)))
	if perch:
		var hump := 1.0 + 0.22 * exp(-pow((u - 0.32) / 0.18, 2.0))
		return Vector3(0.125 * s * hump, 0.11 * s, 0.062 * s)
	return Vector3(0.115 * s, 0.105 * s, 0.056 * s)


static func _body_x(u: float) -> float:
	return BODY_NOSE - BODY_LENGTH * u


static func _u_at(x: float) -> float:
	return (BODY_NOSE - x) / BODY_LENGTH


static func _ring_point(u: float, a: float, perch: bool) -> Vector3:
	var p := _profile(u, perch)
	var up := sin(a)
	var y := up * (p.x if up > 0.0 else p.y)
	# Teardrop section: a narrower back and, on herring, the keeled belly.
	var z := cos(a) * p.z * (1.0 - 0.3 * maxf(up, 0.0))
	if not perch:
		z *= 1.0 - 0.35 * pow(maxf(-up, 0.0), 2.0)
	return Vector3(_body_x(u), y, z)


static func _add_body(st: SurfaceTool, perch: bool) -> void:
	var nose := Vector3(0.5, -0.004, 0.0)
	var stalk := Vector3(_body_x(1.0) - 0.004, 0.0, 0.0)
	for i in BODY_RINGS - 1:
		# Denser rings at the head, where the outline curves fastest.
		var u0 := pow(float(i) / float(BODY_RINGS - 1), 1.35)
		var u1 := pow(float(i + 1) / float(BODY_RINGS - 1), 1.35)
		for j in BODY_SIDES:
			var v0 := float(j) / float(BODY_SIDES)
			var v1 := float(j + 1) / float(BODY_SIDES)
			var quad := [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]
			for k: int in [0, 1, 2, 0, 2, 3]:
				var uv: Vector2 = quad[k]
				_body_vertex(st, uv, _ring_point(uv.x, uv.y * TAU, perch))
			if i == 0:
				var a0 := _ring_point(0.0, v0 * TAU, perch)
				for point: Vector3 in [nose, a0, _ring_point(0.0, v1 * TAU, perch)]:
					_body_vertex(st, Vector2(0.0, v0), point)
			if i == BODY_RINGS - 2:
				var b1 := _ring_point(1.0, v1 * TAU, perch)
				for point: Vector3 in [stalk, b1, _ring_point(1.0, v0 * TAU, perch)]:
					_body_vertex(st, Vector2(1.0, v0), point)


static func _body_vertex(st: SurfaceTool, uv: Vector2, point: Vector3) -> void:
	st.set_uv(uv)
	st.set_uv2(Vector2(sin(uv.y * TAU), PART_BODY))
	st.add_vertex(point)


## A flat fin strip: quads between base[k] and edge[k], rays run base to edge.
static func _add_fin(
	st: SurfaceTool, base: PackedVector3Array, edge: PackedVector3Array, part: float
) -> void:
	var n := base.size() - 1
	for k in n:
		var span0 := float(k) / float(n)
		var span1 := float(k + 1) / float(n)
		var corners := [
			[base[k], Vector2(0.0, span0)],
			[edge[k], Vector2(1.0, span0)],
			[edge[k + 1], Vector2(1.0, span1)],
			[base[k + 1], Vector2(0.0, span1)],
		]
		for c: int in [0, 1, 2, 0, 2, 3]:
			st.set_uv(corners[c][1])
			st.set_uv2(Vector2(0.0, part))
			st.add_vertex(corners[c][0])


static func _add_tail(st: SurfaceTool, perch: bool) -> void:
	# Herring: deeply forked; perch: shallower fork with rounder lobes.
	var root_x := _body_x(1.0) + 0.03
	var notch := -0.63 if perch else -0.6
	var base := PackedVector3Array()
	var edge := PackedVector3Array()
	var steps := 12
	for k in steps + 1:
		var t := float(k) / float(steps) * 2.0 - 1.0
		var lobe := pow(absf(t), 0.75 if perch else 0.6)
		base.append(Vector3(root_x, t * 0.022, 0.0))
		var tip_x := lerpf(notch, -0.78, lobe)
		if perch:
			tip_x += 0.02 * (1.0 - pow(absf(t), 6.0)) * absf(t)
		edge.append(Vector3(tip_x, t * (0.22 if perch else 0.235), 0.0))
	_add_fin(st, base, edge, PART_CAUDAL)


static func _add_dorsal(
	st: SurfaceTool, perch: bool, front: float, back: float, height: float, rays: int, part: float
) -> void:
	var base := PackedVector3Array()
	var edge := PackedVector3Array()
	for k in rays + 1:
		var f := float(k) / float(rays)
		var x := lerpf(front, back, f)
		var top := _profile(_u_at(x), perch).x * 0.95
		# Tall at the front, sloping back; spines stand proud of the membrane.
		var h := height * (0.35 + 0.65 * sin(PI * pow(f, 0.55) * 0.92))
		if part == PART_DORSAL and perch and k % 2 == 1:
			h *= 0.72
		base.append(Vector3(x, top, 0.0))
		edge.append(Vector3(x - 0.045 * h / height, minf(top + h, 0.28), 0.0))
	_add_fin(st, base, edge, part)


## Pectoral (behind the gill) and pelvic (under the belly) fins, swept back and out.
static func _add_paired_fin(
	st: SurfaceTool, perch: bool, side: float, at_x: float, drop: Vector2, part: float
) -> void:
	var p := _profile(_u_at(at_x), perch)
	var y := -p.y * (0.25 if part == PART_PECTORAL else 0.85)
	var z := p.z * (0.9 if part == PART_PECTORAL else 0.4) * side
	var length := 0.15 if part == PART_PECTORAL else 0.12
	var base := PackedVector3Array(
		[Vector3(at_x, y + 0.012, z), Vector3(at_x - 0.035, y - 0.012, z)]
	)
	var spread := (0.075 if part == PART_PECTORAL else 0.055) * side
	var edge := PackedVector3Array(
		[
			Vector3(at_x - length, y + drop.x * 0.4, z + spread),
			Vector3(at_x - length * 0.8, y + drop.y * 0.5, z + spread * 0.7)
		]
	)
	_add_fin(st, base, edge, part)


static func _add_anal(st: SurfaceTool, perch: bool) -> void:
	var front := -0.1 if perch else -0.14
	var back := -0.3 if perch else -0.36
	var base := PackedVector3Array()
	var edge := PackedVector3Array()
	for k in 7:
		var f := float(k) / 6.0
		var x := lerpf(front, back, f)
		var bottom := -_profile(_u_at(x), perch).y * 0.95
		var h := (0.07 if perch else 0.045) * (1.0 - 0.6 * f)
		base.append(Vector3(x, bottom, 0.0))
		edge.append(Vector3(x - 0.03, bottom - h, 0.0))
	_add_fin(st, base, edge, PART_ANAL)


func live_count() -> int:
	return _live.size()


func _process(delta: float) -> void:
	_time += delta
	if player == null:
		return
	var me := CityPlan.to_world_xz(player.global_position)
	_since += delta
	if _since >= 0.6:
		_since = 0.0
		_stream(me)
	for id: String in _live:
		_animate(_live[id])


func _stream(me: Vector2) -> void:
	for id: String in _live.keys():
		if (_live[id]["centre"] as Vector2).distance_to(me) > FREE_RANGE:
			(_live[id]["node"] as Node).queue_free()
			_live.erase(id)
	for c in _centres:
		if _live.size() >= MAX_SCHOOLS:
			break
		if _live.has(c["id"]) or (c["at"] as Vector2).distance_to(me) > RANGE:
			continue
		_live[c["id"]] = _spawn(c)


func _spawn(c: Dictionary) -> Dictionary:
	var node := MultiMeshInstance3D.new()
	node.name = String(c["id"]).replace(".", "_")
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	node.multimesh.use_custom_data = true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c["id"])
	var perch: bool = c["species"] == &"perch"
	var count := 5 if perch else FISH_PER_SCHOOL
	node.multimesh.instance_count = count
	node.multimesh.mesh = _perch_mesh if perch else _fish_mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	var fish: Array[Dictionary] = []
	for k in count:
		var phase := rng.randf() * TAU
		node.multimesh.set_instance_custom_data(k, Color(phase, float(perch), 0, 0))
		fish.append(
			{
				"phase": phase,
				"r": rng.randf_range(0.4, 1.5),
				"dy": rng.randf_range(0.12, 0.27),
				"speed": rng.randf_range(0.25, 0.5),
				"scale": Vector3(0.30, 0.42, 0.38) if perch else Vector3(0.29, 0.23, 0.25)
			}
		)
	return {"node": node, "centre": c["at"], "fish": fish, "swing": rng.randf() * TAU}


## Reject a wander into the bank instead of letting fish orbit through dry sand.
static func wet_position(city_plan: CityPlan, centre: Vector2, candidate: Vector2) -> Vector2:
	var p := candidate
	for _attempt in 4:
		if city_plan.ground_height(p) < -0.22:
			return p
		p = p.lerp(centre, 0.5)
	return centre


func _animate(school: Dictionary) -> void:
	var node: MultiMeshInstance3D = school["node"]
	var fish: Array = school["fish"]
	for i in fish.size():
		node.multimesh.set_instance_transform(i, fish_transform(plan, school, fish[i], _time))


static func fish_transform(
	city_plan: CityPlan, school: Dictionary, fish: Dictionary, time: float
) -> Transform3D:
	var centre: Vector2 = school["centre"]
	var drift := (
		Vector2(
			cos(time * 0.15 + float(school["swing"])), sin(time * 0.12 + float(school["swing"]))
		)
		* 0.65
	)
	var a: float = time * float(fish["speed"]) + float(fish["phase"])
	var candidate := centre + drift + Vector2(cos(a), sin(a)) * float(fish["r"])
	var p := wet_position(city_plan, centre, candidate)
	var basis := Basis(Vector3.UP, -atan2(cos(a), -sin(a))).scaled(fish["scale"])
	# Fit the full fins/tail, not just the origin, between the sloping bed and
	# the rest surface. Four footprint corners bound the small body conservatively.
	var bed := city_plan.ground_height(p)
	for x: float in [-0.78, 0.5]:
		for z: float in [-0.24, 0.24]:
			var corner := basis * Vector3(x, 0.0, z)
			bed = maxf(bed, city_plan.ground_height(p + Vector2(corner.x, corner.z)))
	var scale_y: float = fish["scale"].y
	var fit := clampf((-bed - 0.10) / (0.53 * scale_y), 0.0, 1.0)
	basis = basis.scaled(Vector3.ONE * fit)
	var floor_y := bed + 0.05 + 0.24 * scale_y * fit
	var ceiling_y := -0.05 - 0.29 * scale_y * fit
	var preferred := -float(fish["dy"]) + 0.025 * sin(time * 2.0 + float(fish["phase"]))
	var y := clampf(preferred, minf(floor_y, ceiling_y), ceiling_y)
	return Transform3D(basis, Vector3(p.x, y, p.y))
