class_name MapViewHayMeshes
extends RefCounted

## Cached loose-hay geometry shared by yard ricks and wagon loads. The broad body
## stays cheap, while a second mesh carries silhouette-breaking stems and litter.

const RADIAL_SEGMENTS := 14
const VARIANT_COUNT := 3
const SIZE_SMALL := &"hay_stack.small"
const SIZE_MEDIUM := &"hay_stack.medium"
const SIZE_TALL := &"hay_stack.tall"
const DEFAULT_SIZE := SIZE_MEDIUM
const SIZE_SCALES := {
	SIZE_SMALL: Vector3(0.72, 0.68, 0.72),
	SIZE_MEDIUM: Vector3.ONE,
	# A 2.3 m crown clears the project's 2.0 m visible character-height contract.
	SIZE_TALL: Vector3(1.08, 2.04, 1.06),
}

static var _body_cache: Dictionary = {}
static var _loose_straw_cache: Dictionary = {}


static func add_rick(
	parent: Node3D,
	node_name: String,
	variation_seed: int,
	position: Vector3 = Vector3.ZERO,
	scale: Vector3 = Vector3.ONE,
	size_variant: StringName = DEFAULT_SIZE
) -> Node3D:
	var rick := Node3D.new()
	rick.name = node_name
	rick.position = position
	rick.scale = scale * size_scale(size_variant)
	rick.set_meta(&"hay_size_variant", resolved_size_variant(size_variant))
	# Stable rotation and one of three contour variants prevent repeated Pirita
	# stacks from presenting the same lopsided crown to the camera.
	var variant := posmod(variation_seed, VARIANT_COUNT)
	rick.rotation.y = float(posmod(variation_seed / VARIANT_COUNT, 17)) / 17.0 * TAU
	parent.add_child(rick)

	var body := MeshInstance3D.new()
	body.name = "HayBody"
	body.mesh = body_mesh(variant)
	body.material_override = MapViewMaterials.role(&"hay")
	rick.add_child(body)

	var loose_straw := MeshInstance3D.new()
	loose_straw.name = "LooseStraw"
	loose_straw.mesh = loose_straw_mesh(variant)
	loose_straw.material_override = MapViewMaterials.role(&"hay")
	loose_straw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rick.add_child(loose_straw)
	return rick


static func resolved_size_variant(size_variant: StringName) -> StringName:
	return size_variant if SIZE_SCALES.has(size_variant) else DEFAULT_SIZE


static func size_scale(size_variant: StringName = DEFAULT_SIZE) -> Vector3:
	return SIZE_SCALES[resolved_size_variant(size_variant)]


static func size_bounds(size_variant: StringName = DEFAULT_SIZE, contour_variant: int = 0) -> AABB:
	var bounds: AABB = geometry_stats(contour_variant)["aabb"]
	var resolved_scale := size_scale(size_variant)
	return AABB(bounds.position * resolved_scale, bounds.size * resolved_scale)


static func body_mesh(variant: int = 0) -> ArrayMesh:
	variant = posmod(variant, VARIANT_COUNT)
	if _body_cache.has(variant):
		return _body_cache[variant]
	var rings := _rings_for(variant)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring_index in rings.size() - 1:
		for segment in RADIAL_SEGMENTS:
			var next_segment := (segment + 1) % RADIAL_SEGMENTS
			var a := _body_vertex(rings, ring_index, segment, variant)
			var b := _body_vertex(rings, ring_index, next_segment, variant)
			var c := _body_vertex(rings, ring_index + 1, next_segment, variant)
			var d := _body_vertex(rings, ring_index + 1, segment, variant)
			_add_body_triangle(surface, a, b, c)
			_add_body_triangle(surface, a, c, d)

	# Close the tiny crown and the hidden underside so the stack remains a solid,
	# portable mesh instead of intersecting transparent sphere shells.
	var top_ring := rings.size() - 1
	var top_center := Vector3(
		float(rings[top_ring]["ox"]),
		float(rings[top_ring]["y"]) + 0.018,
		float(rings[top_ring]["oz"])
	)
	for segment in RADIAL_SEGMENTS:
		var next_segment := (segment + 1) % RADIAL_SEGMENTS
		var edge_a := _body_vertex(rings, top_ring, segment, variant)
		var edge_b := _body_vertex(rings, top_ring, next_segment, variant)
		var center := {
			"position": top_center,
			"normal": Vector3.UP,
			"uv": Vector2(1.5, 2.2),
			"color": Color(0.96, 0.96, 0.96)
		}
		_add_body_triangle(surface, edge_a, edge_b, center)
	var bottom_center := {
		"position": Vector3.ZERO,
		"normal": Vector3.DOWN,
		"uv": Vector2(1.5, 0.0),
		"color": Color(0.72, 0.72, 0.72)
	}
	for segment in RADIAL_SEGMENTS:
		var next_segment := (segment + 1) % RADIAL_SEGMENTS
		var edge_a := _body_vertex(rings, 0, segment, variant)
		var edge_b := _body_vertex(rings, 0, next_segment, variant)
		_add_body_triangle(surface, bottom_center, edge_b, edge_a)

	var mesh := surface.commit()
	_body_cache[variant] = mesh
	return mesh


static func loose_straw_mesh(variant: int = 0) -> ArrayMesh:
	variant = posmod(variant, VARIANT_COUNT)
	if _loose_straw_cache.has(variant):
		return _loose_straw_cache[variant]
	var rings := _rings_for(variant)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Long fibers sit just above the body and break the former smooth-pumpkin read.
	# They are ribbons rather than cylinders to keep the shared prop inexpensive.
	for fiber_index in 32:
		var ring_index := 1 + posmod(fiber_index * 5 + variant, rings.size() - 2)
		var ring: Dictionary = rings[ring_index]
		var angle := TAU * _hash01(fiber_index, variant, 701)
		var radius_scale := 0.96 + _hash01(fiber_index, variant, 709) * 0.07
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		var base := Vector3(
			float(ring["ox"]) + cos(angle) * float(ring["rx"]) * radius_scale,
			float(ring["y"]) + (_hash01(fiber_index, variant, 719) - 0.5) * 0.08,
			float(ring["oz"]) + sin(angle) * float(ring["rz"]) * radius_scale
		)
		var normal := Vector3(radial.x, 0.28 + float(ring_index) * 0.055, radial.z).normalized()
		var tangent := Vector3(-sin(angle), 0.0, cos(angle))
		var length := 0.10 + _hash01(fiber_index, variant, 727) * 0.17
		var tip := (
			base + normal * length + tangent * (_hash01(fiber_index, variant, 733) - 0.5) * 0.15
		)
		tip.y += 0.025 + _hash01(fiber_index, variant, 739) * 0.055
		var width := 0.007 + _hash01(fiber_index, variant, 743) * 0.009
		_add_ribbon(
			surface,
			base,
			tip,
			tangent * width,
			normal,
			0.78 + _hash01(fiber_index, variant, 751) * 0.24
		)

	# A modest skirt of fallen stems grounds yard stacks. It scales with wagon loads,
	# so the same mesh also adds a few overhanging pieces without a second asset.
	for litter_index in 14:
		var angle := TAU * _hash01(litter_index, variant, 809)
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		var tangent := Vector3(-sin(angle), 0.0, cos(angle))
		var start_radius := 0.69 + _hash01(litter_index, variant, 811) * 0.12
		var base := radial * start_radius + Vector3(0.0, 0.012, 0.0)
		var length := 0.08 + _hash01(litter_index, variant, 821) * 0.13
		var tip := (
			base + radial * length + tangent * (_hash01(litter_index, variant, 823) - 0.5) * 0.12
		)
		tip.y = 0.018 + _hash01(litter_index, variant, 827) * 0.018
		_add_ribbon(
			surface,
			base,
			tip,
			tangent * 0.009,
			Vector3.UP,
			0.68 + _hash01(litter_index, variant, 829) * 0.18
		)

	var mesh := surface.commit()
	_loose_straw_cache[variant] = mesh
	return mesh


static func geometry_stats(variant: int = 0) -> Dictionary:
	var body := body_mesh(variant)
	var loose := loose_straw_mesh(variant)
	var body_vertices: PackedVector3Array = body.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var loose_vertices: PackedVector3Array = loose.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	return {
		"body_vertices": body_vertices.size(),
		"loose_straw_vertices": loose_vertices.size(),
		"triangles": (body_vertices.size() + loose_vertices.size()) / 3,
		"aabb": body.get_aabb().merge(loose.get_aabb()),
		"materials": 1,
	}


static func _rings_for(variant: int) -> Array[Dictionary]:
	var crown_x: float = [-0.04, 0.08, 0.02][variant]
	var crown_z: float = [0.05, -0.06, 0.09][variant]
	return [
		{"y": 0.0, "rx": 0.62, "rz": 0.59, "ox": 0.0, "oz": 0.0},
		{"y": 0.10, "rx": 0.82, "rz": 0.76, "ox": -crown_x * 0.12, "oz": -crown_z * 0.10},
		{"y": 0.31, "rx": 0.88, "rz": 0.82, "ox": -crown_x * 0.08, "oz": -crown_z * 0.04},
		{"y": 0.53, "rx": 0.84, "rz": 0.79, "ox": crown_x * 0.15, "oz": crown_z * 0.10},
		{"y": 0.72, "rx": 0.71, "rz": 0.68, "ox": crown_x * 0.35, "oz": crown_z * 0.30},
		{"y": 0.90, "rx": 0.49, "rz": 0.46, "ox": crown_x * 0.68, "oz": crown_z * 0.65},
		{"y": 1.05, "rx": 0.27, "rz": 0.24, "ox": crown_x * 0.88, "oz": crown_z * 0.90},
		{"y": 1.13, "rx": 0.065, "rz": 0.055, "ox": crown_x, "oz": crown_z},
	]


static func _body_vertex(
	rings: Array[Dictionary], ring_index: int, segment: int, variant: int
) -> Dictionary:
	var ring: Dictionary = rings[ring_index]
	var angle := TAU * float(segment) / float(RADIAL_SEGMENTS)
	var wobble := 0.94 + _hash01(segment, ring_index, 101 + variant * 47) * 0.12
	var position := Vector3(
		float(ring["ox"]) + cos(angle) * float(ring["rx"]) * wobble,
		float(ring["y"]),
		float(ring["oz"]) + sin(angle) * float(ring["rz"]) * wobble
	)
	var vertical := lerpf(-0.18, 0.72, float(ring_index) / float(rings.size() - 1))
	var normal := Vector3(cos(angle), vertical, sin(angle)).normalized()
	var tone := 0.84 + _hash01(segment, ring_index, 337 + variant * 61) * 0.18
	return {
		"position": position,
		"normal": normal,
		"uv": Vector2(float(segment) / float(RADIAL_SEGMENTS) * 3.0, float(ring["y"]) * 1.9),
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


static func _add_ribbon(
	surface: SurfaceTool,
	base: Vector3,
	tip: Vector3,
	half_width: Vector3,
	normal: Vector3,
	tone: float
) -> void:
	var points := [
		[base - half_width, Vector2(0.0, 0.0)],
		[base + half_width, Vector2(1.0, 0.0)],
		[tip + half_width * 0.42, Vector2(1.0, 1.0)],
		[tip - half_width * 0.42, Vector2(0.0, 1.0)],
	]
	for index in [0, 1, 2, 0, 2, 3]:
		surface.set_normal(normal)
		surface.set_uv(points[index][1])
		surface.set_color(Color(tone, tone * 0.98, tone * 0.90))
		surface.add_vertex(points[index][0])


static func _hash01(x: int, y: int, seed_value: int) -> float:
	var hashed := ((x * 374761393) + (y * 668265263) + seed_value * 69069) & 0x7fffffff
	hashed = (hashed ^ (hashed >> 13)) * 1274126177 & 0x7fffffff
	return float(hashed % 100000) / 99999.0
