class_name MapViewHayMeshes
extends RefCounted

## Cached hay stack geometry shared by yard ricks and wagon loads. The stack is the
## tall field "heinakuhi" of the Baltic hayfield: forked up around a central pole,
## taller than a man, bellied above a narrower foot, shouldered into a tight crown
## and combed down by rake and hand so the sides read as one dense, homogeneous mass
## of vertical strands (no stalks bristling out of it). A second mesh lays the hay
## that fell while it was being carried and forked up on the ground round the foot.

const RADIAL_SEGMENTS := 36
const RING_COUNT := 24
const VARIANT_COUNT := 3
const SIZE_SMALL := &"hay_stack.small"
const SIZE_MEDIUM := &"hay_stack.medium"
const SIZE_TALL := &"hay_stack.tall"
const DEFAULT_SIZE := SIZE_MEDIUM
## The canonical mesh is 2.8 m high and about 2.2 m across the belly: clearly
## taller than the 2.0 m character, and narrower than it is tall.
const SIZE_SCALES := {
	SIZE_SMALL: Vector3(0.80, 0.80, 0.80),
	SIZE_MEDIUM: Vector3.ONE,
	SIZE_TALL: Vector3(1.10, 1.25, 1.10),
}
## Belly radius of the canonical stack. The blocking footprint is a little inside it
## because the lower flank tucks in toward the foot.
const BELLY_RADIUS := 1.08
const COLLISION_RADIUS := 0.98
const HEIGHT := 2.8
## Ground-litter reach beyond the belly, in canonical metres.
const LITTER_RADIUS := 2.6
## Loose strands per stack that the wind can lift off (map_view_hay_wisps.gdshader).
const WISP_COUNT := 28

## (height fraction, radius in metres): narrow foot, belly at about a third of the
## height, long convex shoulder, rounded crown. Linear between points; the noise
## in `_body_vertex` rounds the joins.
const PROFILE: Array[Vector2] = [
	Vector2(0.00, 0.80),
	Vector2(0.04, 0.92),
	Vector2(0.14, 1.02),
	Vector2(0.30, 1.08),
	Vector2(0.44, 1.06),
	Vector2(0.58, 0.96),
	Vector2(0.70, 0.80),
	Vector2(0.80, 0.60),
	Vector2(0.89, 0.38),
	Vector2(0.95, 0.20),
	Vector2(0.985, 0.08),
	Vector2(1.00, 0.00),
]

static var _body_cache: Dictionary = {}
static var _litter_cache: Dictionary = {}
static var _wisp_cache: Dictionary = {}


static func add_rick(
	parent: Node3D,
	node_name: String,
	variation_seed: int,
	position: Vector3 = Vector3.ZERO,
	scale: Vector3 = Vector3.ONE,
	size_variant: StringName = DEFAULT_SIZE,
	as_load: bool = false
) -> Node3D:
	var rick := HayRickReaction.new()
	rick.name = node_name
	rick.position = position
	rick.scale = scale * size_scale(size_variant)
	rick.set_meta(&"hay_size_variant", resolved_size_variant(size_variant))
	# Stable rotation and one of three contour variants prevent repeated stacks
	# from presenting the same lopsided crown to the camera.
	var variant := posmod(variation_seed, VARIANT_COUNT)
	rick.rotation.y = float(posmod(variation_seed / VARIANT_COUNT, 17)) / 17.0 * TAU
	rick.collision_radius = collision_radius(size_variant) * maxf(scale.x, scale.z)
	# A wagon load rides on the cart: it neither yields to the walker nor sheds litter.
	rick.set_process(not as_load)
	parent.add_child(rick)

	var body := MeshInstance3D.new()
	body.name = "HayBody"
	body.mesh = body_mesh(variant)
	body.material_override = MapViewMaterials.hay_stack(0)
	rick.add_child(body)
	rick.body = body
	# Fur shells ride on the body, so a yielding flank deforms them with it. They
	# never cast shadows (the solid body does) and are what makes the stack hairy.
	for layer in range(1, MapViewMaterials.HAY_STACK_SHELL_COUNT):
		var fur := MeshInstance3D.new()
		fur.name = "Fur%d" % layer
		fur.mesh = body.mesh
		fur.material_override = MapViewMaterials.hay_stack(layer)
		fur.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(fur)

	if not as_load:
		var litter := MeshInstance3D.new()
		litter.name = "GroundLitter"
		litter.mesh = litter_mesh(variant)
		litter.material_override = MapViewMaterials.role(&"hay")
		litter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The litter lies flat on the ground, so it cancels the stack's vertical
		# stretch and keeps one horizontal scale instead of following x/z separately.
		var s := rick.scale
		var flat := (s.x + s.z) * 0.5
		litter.scale = Vector3(flat / s.x, 1.0 / s.y, flat / s.z)
		rick.add_child(litter)

		# Strands the wind works loose and carries off (shader-driven, no script).
		var wisps := MeshInstance3D.new()
		wisps.name = "Wisps"
		wisps.mesh = wisp_mesh(variant)
		wisps.material_override = MapViewMaterials.hay_wisps()
		wisps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Wisps fly well outside the stack's own bounds.
		wisps.extra_cull_margin = 8.0
		rick.add_child(wisps)
	return rick


static func resolved_size_variant(size_variant: StringName) -> StringName:
	return size_variant if SIZE_SCALES.has(size_variant) else DEFAULT_SIZE


static func size_scale(size_variant: StringName = DEFAULT_SIZE) -> Vector3:
	return SIZE_SCALES[resolved_size_variant(size_variant)]


## Blocking radius in world metres of an unscaled stack of this size.
static func collision_radius(size_variant: StringName = DEFAULT_SIZE) -> float:
	var s := size_scale(size_variant)
	return COLLISION_RADIUS * maxf(s.x, s.z)


## Bounds of the stack itself (ground litter excluded: it is not part of the volume).
static func size_bounds(size_variant: StringName = DEFAULT_SIZE, contour_variant: int = 0) -> AABB:
	var bounds := body_mesh(contour_variant).get_aabb()
	var resolved_scale := size_scale(size_variant)
	return AABB(bounds.position * resolved_scale, bounds.size * resolved_scale)


static func body_mesh(variant: int = 0) -> ArrayMesh:
	variant = posmod(variant, VARIANT_COUNT)
	if _body_cache.has(variant):
		return _body_cache[variant]
	# Positions first, so normals can come from neighbours on the displaced surface.
	var grid: Array = []
	for ring_index in RING_COUNT:
		var row: Array[Vector3] = []
		for segment in RADIAL_SEGMENTS:
			row.append(_body_position(ring_index, segment, variant))
		grid.append(row)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring_index in RING_COUNT - 1:
		for segment in RADIAL_SEGMENTS:
			var next_segment := (segment + 1) % RADIAL_SEGMENTS
			var a := _body_vertex(grid, ring_index, segment)
			var b := _body_vertex(grid, ring_index, next_segment)
			var c := _body_vertex(grid, ring_index + 1, next_segment)
			var d := _body_vertex(grid, ring_index + 1, segment)
			_add_body_triangle(surface, a, b, c)
			_add_body_triangle(surface, a, c, d)

	# The crown ring is a point, so only the hidden underside needs closing.
	var bottom_center := {
		"position": Vector3.ZERO,
		"normal": Vector3.DOWN,
		"uv": Vector2(0.5, 0.5),
		"color": Color(0.55, 0.55, 0.55),
	}
	for segment in RADIAL_SEGMENTS:
		var next_segment := (segment + 1) % RADIAL_SEGMENTS
		var edge_a := _body_vertex(grid, 0, segment)
		var edge_b := _body_vertex(grid, 0, next_segment)
		_add_body_triangle(surface, bottom_center, edge_b, edge_a)

	var mesh := surface.commit()
	_body_cache[variant] = mesh
	return mesh


## Hay lying on the ground round the foot: a drag fan on the side the hay was brought
## from, scattered single strands, and loose forkfuls where a load dropped.
static func litter_mesh(variant: int = 0) -> ArrayMesh:
	variant = posmod(variant, VARIANT_COUNT)
	if _litter_cache.has(variant):
		return _litter_cache[variant]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var drag_angle := TAU * _hash01(variant, 3, 601)

	# Individual strands thin out with distance; a third of them fall in the drag fan.
	for index in 130:
		var in_fan := _hash01(index, variant, 603) < 0.38
		var angle := TAU * _hash01(index, variant, 607)
		if in_fan:
			angle = drag_angle + (_hash01(index, variant, 609) - 0.5) * 1.1
		var reach := (
			0.85 + pow(_hash01(index, variant, 611), 1.7) * (LITTER_RADIUS - 0.85)
		)
		if in_fan:
			reach *= 1.0 + 0.35 * _hash01(index, variant, 613)
		var centre := Vector3(cos(angle), 0.0, sin(angle)) * reach
		var lay := TAU * _hash01(index, variant, 617)
		# Strands near the foot point away from it (slid down the flank).
		if _hash01(index, variant, 619) < 0.5:
			lay = angle + (_hash01(index, variant, 621) - 0.5) * 1.2
		_add_strand(surface, centre, lay, 0.30 + _hash01(index, variant, 623) * 0.40, index, variant)

	# Forkfuls: eight to eleven overlapping strands splayed round one point.
	for clump in 9:
		var angle := TAU * _hash01(clump, variant, 631)
		if clump % 2 == 0:
			angle = drag_angle + (_hash01(clump, variant, 633) - 0.5) * 1.5
		var reach := 1.15 + _hash01(clump, variant, 637) * 1.1
		var centre := Vector3(cos(angle), 0.0, sin(angle)) * reach
		var strands := 8 + int(_hash01(clump, variant, 641) * 4.0)
		var base_lay := TAU * _hash01(clump, variant, 643)
		for strand in strands:
			var spread := (_hash01(clump * 17 + strand, variant, 647) - 0.5) * 1.5
			var jitter := Vector3(
				(_hash01(clump * 17 + strand, variant, 649) - 0.5) * 0.28,
				0.0,
				(_hash01(clump * 17 + strand, variant, 653) - 0.5) * 0.28
			)
			_add_strand(
				surface,
				centre + jitter,
				base_lay + spread,
				0.35 + _hash01(clump * 17 + strand, variant, 659) * 0.35,
				clump * 31 + strand,
				variant
			)

	var mesh := surface.commit()
	_litter_cache[variant] = mesh
	return mesh


## Loose strands tucked on the stack surface, each a two-triangle ribbon. The
## wisp shader reads: CUSTOM0 = attachment point (xyz) + seed (w), COLOR = release
## threshold / length in metres / tone, UV = (along -0.5..0.5, across -1..1).
## The ribbon itself is built in the shader, so every vertex sits at the point.
static func wisp_mesh(variant: int = 0) -> ArrayMesh:
	variant = posmod(variant, VARIANT_COUNT)
	if _wisp_cache.has(variant):
		return _wisp_cache[variant]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var corners := [Vector2(-0.5, -1), Vector2(0.5, -1), Vector2(0.5, 1), Vector2(-0.5, 1)]
	for index in WISP_COUNT:
		# Upper two thirds: the crown and shoulder are what the wind actually strips.
		var t := 0.30 + _hash01(index, variant, 801) * 0.62
		var segment := int(_hash01(index, variant, 803) * RADIAL_SEGMENTS) % RADIAL_SEGMENTS
		var ring := clampi(roundi(t * float(RING_COUNT - 1)), 1, RING_COUNT - 2)
		var point := _body_position(ring, segment, variant)
		var normal := Vector3(point.x, 0.0, point.z).normalized()
		# Thresholds spread over the breeze-to-storm drive range (see the shader).
		var threshold := 0.16 + pow(_hash01(index, variant, 807), 1.5) * 0.9
		var length := 0.16 + _hash01(index, variant, 809) * 0.2
		var tone := 0.82 + _hash01(index, variant, 811) * 0.3
		for corner_index: int in [0, 1, 2, 0, 2, 3]:
			var corner: Vector2 = corners[corner_index]
			surface.set_normal(normal)
			surface.set_uv(corner)
			surface.set_color(Color(threshold, length, tone, 1.0))
			surface.set_custom(
				0, Color(point.x, point.y, point.z, _hash01(index, variant, 813))
			)
			surface.add_vertex(point)
	var mesh := surface.commit()
	_wisp_cache[variant] = mesh
	return mesh


static func geometry_stats(variant: int = 0) -> Dictionary:
	var body := body_mesh(variant)
	var litter := litter_mesh(variant)
	var body_vertices: PackedVector3Array = body.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var litter_vertices: PackedVector3Array = litter.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	return {
		"body_vertices": body_vertices.size(),
		"litter_vertices": litter_vertices.size(),
		"triangles": (body_vertices.size() + litter_vertices.size()) / 3,
		"aabb": body.get_aabb().merge(litter.get_aabb()),
		"materials": 1,
	}


## Radius of the undisplaced profile at a height fraction.
static func profile_radius(height_fraction: float) -> float:
	var t := clampf(height_fraction, 0.0, 1.0)
	for i in PROFILE.size() - 1:
		var lo := PROFILE[i]
		var hi := PROFILE[i + 1]
		if t <= hi.x:
			return lerpf(lo.y, hi.y, (t - lo.x) / maxf(hi.x - lo.x, 0.0001))
	return 0.0


static func _body_position(ring_index: int, segment: int, variant: int) -> Vector3:
	var t := float(ring_index) / float(RING_COUNT - 1)
	var y := t * HEIGHT
	var u := float(segment) / float(RADIAL_SEGMENTS)
	var angle := TAU * u
	var radius := profile_radius(t)
	# Surface relief, all of it low and soft so the mass stays homogeneous:
	# broad lumps where a forkful settled, vertical combed streaks, and faint
	# horizontal courses from the layers being trodden down as the stack rose.
	var lumps := (_periodic_noise(u, y * 1.4, 5, 11 + variant * 7) - 0.5) * 0.17
	var streaks := (_periodic_noise(u, y * 0.55, 18, 23 + variant * 5) - 0.5) * 0.06
	var courses := (_periodic_noise(u, y * 4.5, 3, 37 + variant * 3) - 0.5) * 0.035
	# Relief dies out at the foot (trodden flat) and at the crown (a tight point).
	var envelope := smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.86, 1.0, t))
	radius = maxf(radius + (lumps + streaks + courses) * envelope, 0.0)
	# Slightly oval plan and a crown that leans, different per contour variant.
	var oval: float = [0.07, -0.05, 0.03][variant]
	var lean_x: float = [-0.10, 0.14, 0.04][variant]
	var lean_z: float = [0.12, -0.09, 0.16][variant]
	var lean := t * t
	return Vector3(
		cos(angle) * radius * (1.0 + oval) + lean_x * lean,
		y,
		sin(angle) * radius * (1.0 - oval) + lean_z * lean
	)


static func _body_vertex(grid: Array, ring_index: int, segment: int) -> Dictionary:
	var rings: int = grid.size()
	var next_segment := (segment + 1) % RADIAL_SEGMENTS
	var prev_segment := (segment + RADIAL_SEGMENTS - 1) % RADIAL_SEGMENTS
	var below: int = maxi(ring_index - 1, 0)
	var above: int = mini(ring_index + 1, rings - 1)
	var around: Vector3 = grid[ring_index][next_segment] - grid[ring_index][prev_segment]
	var up: Vector3 = grid[above][segment] - grid[below][segment]
	var normal := up.cross(around)
	if normal.length_squared() < 0.000001:
		normal = Vector3.UP
	normal = normal.normalized()
	var position: Vector3 = grid[ring_index][segment]
	var u := float(segment) / float(RADIAL_SEGMENTS)
	var t := float(ring_index) / float(rings - 1)
	# Vertex tone: damp, dark foot; sun-bleached grey-gold crown; streak variation.
	var streak := _periodic_noise(u, position.y * 0.5, 18, 71)
	var tone := lerpf(0.66, 0.96, smoothstep(0.0, 0.25, t)) * (0.9 + streak * 0.14)
	tone *= lerpf(1.0, 0.93, smoothstep(0.8, 1.0, t))
	return {
		"position": position,
		"normal": normal,
		"uv": Vector2(u * 3.0, position.y * 0.6),
		"color": Color(tone, tone, tone),
	}


static func _add_body_triangle(
	surface: SurfaceTool, a: Dictionary, b: Dictionary, c: Dictionary
) -> void:
	for point: Dictionary in [a, b, c]:
		surface.set_normal(point["normal"])
		surface.set_uv(point["uv"])
		surface.set_color(point["color"])
		surface.add_vertex(point["position"])


## One flat strand lying on the ground, centred on `centre`, slightly bowed.
static func _add_strand(
	surface: SurfaceTool,
	centre: Vector3,
	lay_angle: float,
	length: float,
	index: int,
	variant: int
) -> void:
	var along := Vector3(cos(lay_angle), 0.0, sin(lay_angle))
	var side := Vector3(-along.z, 0.0, along.x)
	var half_width := 0.016 + _hash01(index, variant, 661) * 0.014
	var lift := 0.035 + _hash01(index, variant, 663) * 0.03
	var bow := (_hash01(index, variant, 667) - 0.5) * 0.10
	var tone := 0.72 + _hash01(index, variant, 671) * 0.30
	var colour := Color(tone, tone * 0.98, tone * 0.88)
	# Three segments give a gentle arc instead of a ruler-straight stick.
	var previous_mid := centre - along * length * 0.5
	previous_mid.y = lift
	for step in range(1, 4):
		var f := float(step) / 3.0
		var next_mid := centre + along * length * (f - 0.5) + side * bow * sin(f * PI)
		next_mid.y = lift + 0.012 * sin(f * PI)
		var taper := 1.0 - 0.45 * f
		var prev_taper := 1.0 - 0.45 * float(step - 1) / 3.0
		_add_flat_quad(
			surface,
			previous_mid - side * half_width * prev_taper,
			previous_mid + side * half_width * prev_taper,
			next_mid + side * half_width * taper,
			next_mid - side * half_width * taper,
			colour
		)
		previous_mid = next_mid


## Quad facing up. Godot front faces are clockwise, so the triangle normal must
## point down for the top side to render; swap the pair when it does not.
static func _add_flat_quad(
	surface: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, colour: Color
) -> void:
	var order := [0, 1, 2, 0, 2, 3]
	var points := [p0, p1, p2, p3]
	var facing := (p1 - p0).cross(p2 - p0)
	if facing.y > 0.0:
		order = [0, 2, 1, 0, 3, 2]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for index: int in order:
		surface.set_normal(Vector3.UP)
		surface.set_uv(uvs[index])
		surface.set_color(colour)
		surface.add_vertex(points[index])


## Smooth value noise in 0..1, periodic in `u` (0..1 wraps) so the seam is invisible.
static func _periodic_noise(u: float, v: float, period: int, seed_value: int) -> float:
	var x := u * float(period)
	var x0 := floori(x)
	var y0 := floori(v)
	var fx := smoothstep(0.0, 1.0, x - float(x0))
	var fy := smoothstep(0.0, 1.0, v - float(y0))
	var a := _hash01(posmod(x0, period), y0, seed_value)
	var b := _hash01(posmod(x0 + 1, period), y0, seed_value)
	var c := _hash01(posmod(x0, period), y0 + 1, seed_value)
	var d := _hash01(posmod(x0 + 1, period), y0 + 1, seed_value)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


static func _hash01(x: int, y: int, seed_value: int) -> float:
	var hashed := ((x * 374761393) + (y * 668265263) + seed_value * 69069) & 0x7fffffff
	hashed = (hashed ^ (hashed >> 13)) * 1274126177 & 0x7fffffff
	return float(hashed % 100000) / 99999.0
