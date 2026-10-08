class_name CityFences
extends RefCounted

## Fences of the country round Reval (docs/SYSTEMS/FARMLAND.md). A 1343 village
## did not buy sawn boards: timber was dear and every plank was hand-riven. Most
## enclosures were woven wattle (hazel and willow withies between stakes), the
## next commonest were rough pole fences (round or riven poles lashed to stakes),
## and where the field gave stones, a low dry-stone wall. Sawn board fences are
## deliberately absent. Visual only: no collision.

const KIND_WATTLE := &"wattle"
const KIND_POLE := &"pole"
const KIND_STONE := &"stone"

## Cumulative thresholds of the deterministic per-enclosure roll (id hash).
const WATTLE_SHARE := 0.62
const POLE_SHARE := 0.86

const WATTLE_HEIGHT := 1.05
const STAKE_STEP := 0.3
const WITHY_LAYERS := 13
const POLE_POST_STEP := 2.3
const SAMPLE_STEP := 0.1

## Weathered, silvered wood: the bridge board textures tinted grey.
const BOARD_STEM := "res://assets/materials/pbr/bridge_timber/bridge_timber_1"
const GREY_STAKE := Color(0.62, 0.6, 0.56)
const GREY_WITHY := Color(0.66, 0.6, 0.5)

static var _wood_material: StandardMaterial3D


## Fence kind of an enclosure. Pure and stable per id, so tests can audit it.
static func kind_for(feature_id: String) -> StringName:
	var roll := float(absi(hash(feature_id + "/fence")) % 1000) / 1000.0
	if roll < WATTLE_SHARE:
		return KIND_WATTLE
	if roll < POLE_SHARE:
		return KIND_POLE
	return KIND_STONE


## Builds the fence round `poly` under `parent`. `ground` maps xz to terrain height.
static func build(
	parent: Node3D, feature_id: String, poly: PackedVector2Array, ground: Callable, draw_range: float
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(feature_id + "/fence")
	var kind := kind_for(feature_id)
	if kind == KIND_STONE:
		_stone_wall(parent, poly, ground, rng, draw_range)
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		if kind == KIND_WATTLE:
			_wattle_run(st, a, b, ground, rng)
		else:
			_pole_run(st, a, b, ground, rng)
	st.generate_tangents()
	var inst := MeshInstance3D.new()
	inst.name = "Fence_%s" % kind
	inst.mesh = st.commit()
	inst.material_override = _wood()
	inst.visibility_range_end = draw_range
	parent.add_child(inst)


## A run of woven wattle: upright stakes every STAKE_STEP, withies passing in
## front of one stake and behind the next, each layer offset by one stake so the
## weave locks. Stakes differ in height, a few withies are broken or missing.
static func _wattle_run(
	st: SurfaceTool, a: Vector2, b: Vector2, ground: Callable, rng: RandomNumberGenerator
) -> void:
	var span := a.distance_to(b)
	var dir := (b - a) / maxf(span, 0.001)
	var side := Vector2(-dir.y, dir.x)
	var stakes := maxi(int(span / STAKE_STEP), 1)
	var step := span / stakes
	for k in stakes + 1:
		var along := k * step
		var p := a + dir * along
		var top := WATTLE_HEIGHT + rng.randf_range(0.0, 0.16)
		var lean := Vector2(rng.randf_range(-0.02, 0.02), rng.randf_range(-0.02, 0.02))
		var foot := Vector3(p.x, float(ground.call(p)) - 0.1, p.y)
		var head := Vector3(p.x + lean.x, foot.y + top + 0.1, p.y + lean.y)
		var radius := rng.randf_range(0.03, 0.042)
		_tube(st, PackedVector3Array([foot, head]), radius, 4, _grey(GREY_STAKE, rng))
	for layer in WITHY_LAYERS:
		var height := 0.1 + layer * ((WATTLE_HEIGHT - 0.2) / (WITHY_LAYERS - 1))
		var points := PackedVector3Array()
		var samples := maxi(int(span / SAMPLE_STEP), 2)
		var broken := rng.randf() < 0.05 and layer >= 3
		var cut_at := rng.randf_range(0.3, 0.7) * span if broken else -1.0
		for s in samples + 1:
			var along := span * float(s) / samples
			if cut_at >= 0.0 and along > cut_at and along < cut_at + 1.4:
				if points.size() >= 2:
					_tube(st, points, 0.026, 4, _grey(GREY_WITHY, rng))
				points = PackedVector3Array()
				continue
			# Over one stake, under the next; odd layers swap sides.
			var phase := PI * (along / step + float(layer % 2))
			var weave: float = 0.045 * signf(sin(phase)) * minf(absf(sin(phase)) * 3.0, 1.0)
			var p := a + dir * along + side * weave
			var wobble := rng.randf_range(-0.012, 0.012)
			points.append(Vector3(p.x, float(ground.call(p)) + height + wobble, p.y))
		if points.size() >= 2:
			_tube(st, points, rng.randf_range(0.024, 0.03), 4, _grey(GREY_WITHY, rng))


## Rough pole fence: crooked round stakes every ~2.3 m, three poles lashed on
## alternating faces so each pole's end passes its stake and overlaps the next.
static func _pole_run(
	st: SurfaceTool, a: Vector2, b: Vector2, ground: Callable, rng: RandomNumberGenerator
) -> void:
	var span := a.distance_to(b)
	var dir := (b - a) / maxf(span, 0.001)
	var side := Vector2(-dir.y, dir.x)
	var bays := maxi(int(round(span / POLE_POST_STEP)), 1)
	var step := span / bays
	for k in bays + 1:
		var p := a + dir * (k * step) + side * rng.randf_range(-0.04, 0.04)
		var foot := Vector3(p.x, float(ground.call(p)) - 0.25, p.y)
		var top := rng.randf_range(1.05, 1.25)
		var head := Vector3(p.x + rng.randf_range(-0.03, 0.03), foot.y + top + 0.25, p.y)
		var radius := rng.randf_range(0.05, 0.07)
		_tube(st, PackedVector3Array([foot, head]), radius, 5, _grey(GREY_STAKE, rng))
	for k in bays:
		var face := 1.0 if (k % 2) == 0 else -1.0
		for h: float in [0.38, 0.7, 1.0]:
			var from := a + dir * (k * step - 0.12) + side * (0.07 * face)
			var to := a + dir * ((k + 1) * step + 0.12) + side * (0.07 * face)
			var pts := PackedVector3Array()
			var samples := maxi(int(from.distance_to(to) / 0.6), 2)
			var droop := rng.randf_range(0.0, 0.05)
			var jitter := rng.randf_range(-0.05, 0.05)
			for s in samples + 1:
				var t := float(s) / samples
				var q := from.lerp(to, t)
				var sag := droop * sin(t * PI)
				pts.append(Vector3(q.x, float(ground.call(q)) + h + jitter - sag, q.y))
			_tube(st, pts, rng.randf_range(0.032, 0.045), 5, _grey(GREY_STAKE, rng))


## Low field-stone wall, two to three staggered courses of rounded stones.
static func _stone_wall(
	parent: Node3D,
	poly: PackedVector2Array,
	ground: Callable,
	rng: RandomNumberGenerator,
	draw_range: float
) -> void:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var span := a.distance_to(b)
		var dir := (b - a) / maxf(span, 0.001)
		var side := Vector2(-dir.y, dir.x)
		var yaw := atan2(-dir.y, dir.x)
		var count := int(span / 0.38)
		for course in 3:
			var y := 0.13 + course * 0.2
			for n in count:
				var along := (n + (0.5 if course % 2 == 1 else 0.0)) * (span / count)
				if course == 2 and rng.randf() < 0.3:
					continue
				var p := a + dir * along + side * rng.randf_range(-0.07, 0.07)
				var size := Vector3(
					rng.randf_range(0.34, 0.52), rng.randf_range(0.17, 0.25), rng.randf_range(0.34, 0.5)
				)
				var basis := Basis(Vector3.UP, yaw + rng.randf_range(-0.25, 0.25)).scaled(size)
				transforms.append(Transform3D(basis, Vector3(p.x, float(ground.call(p)) + y, p.y)))
				var shade := rng.randf_range(0.7, 1.05)
				colors.append(Color(shade, shade * 0.98, shade * 0.93))
	if transforms.is_empty():
		return
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var material := MapViewMaterials.role(&"stone").duplicate() as StandardMaterial3D
	material.albedo_color = Color(0.62, 0.61, 0.57)
	material.vertex_color_use_as_albedo = true
	var inst := MapViewMeshBuilderPrimitives.multi_mesh(
		"Fence_stone", box, transforms, colors, material, Vector3.ZERO
	)
	inst.visibility_range_end = draw_range
	parent.add_child(inst)


## A round rod along `points`, UV u along the length so the board grain follows it.
static func _tube(
	st: SurfaceTool, points: PackedVector3Array, radius: float, sides: int, color: Color
) -> void:
	var count := points.size()
	if count < 2:
		return
	var rings: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	var lengths := PackedFloat32Array()
	var run := 0.0
	for i in count:
		if i > 0:
			run += points[i].distance_to(points[i - 1])
		lengths.append(run)
		var tangent := (points[mini(i + 1, count - 1)] - points[maxi(i - 1, 0)]).normalized()
		var ref := Vector3.UP if absf(tangent.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		var n1 := ref.cross(tangent).normalized()
		var n2 := tangent.cross(n1)
		var ring := PackedVector3Array()
		var ring_n := PackedVector3Array()
		for k in sides + 1:
			var ang := TAU * float(k) / sides
			var n := n1 * cos(ang) + n2 * sin(ang)
			ring.append(points[i] + n * radius)
			ring_n.append(n)
		rings.append(ring)
		normals.append(ring_n)
	# Non-indexed triangles: SurfaceTool indices are global to the surface, and
	# these rods are small enough that the duplicated vertices cost nothing.
	for i in count - 1:
		for k in sides:
			for corner: Vector2i in [
				Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1),
				Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1)
			]:
				var ring := i + corner.x
				var seg := k + corner.y
				st.set_color(color)
				st.set_normal(normals[ring][seg])
				st.set_uv(Vector2(lengths[ring] * 0.7, 0.5 * float(seg) / sides))
				st.add_vertex(rings[ring][seg])


static func _grey(base: Color, rng: RandomNumberGenerator) -> Color:
	var shade := rng.randf_range(0.82, 1.1)
	return Color(base.r * shade, base.g * shade, base.b * shade)


static func _wood() -> StandardMaterial3D:
	if _wood_material != null:
		return _wood_material
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = load(BOARD_STEM + "_albedo.png")
	material.normal_enabled = true
	material.normal_texture = load(BOARD_STEM + "_normal.png")
	material.roughness = 0.95
	# Thin rods are seen from both sides at grazing angles.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_wood_material = material
	return material
