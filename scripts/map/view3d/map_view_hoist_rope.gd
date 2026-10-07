class_name MapViewHoistRope
extends RefCounted

## Hemp hoist rope with a forged iron hook that swings in the world wind (R-1200).
##
## WHY: kit houses, the town hall and the hoist_beam prop baked the rope as a
## rigid cylinder and the hook as a box, so they stood frozen next to flags that
## fly. The rope is now built here as a smooth tube (the three-strand lay is
## drawn per pixel by the shader, so it never aliases along a long rope) with a
## swept J hook, and map_view_hoist_rope.gdshader poses it as a pendulum on the
## GPU. Mesh contract and motion model: see the shader header and
## docs/SYSTEMS/HOIST_ROPE.md.

const NODE_NAME := "HoistRope"
## Kit GLBs mark the sheave (rope top) and the hook eye (rope bottom) with these
## empties; see House.hoist() in tools/burgher_house_kit_common.py.
const ANCHOR_MARKER := "HoistRopeAnchor"
const END_MARKER := "HoistRopeEnd"

const ROPE_RADIUS := 0.018
const ROPE_SIDES := 10
## Ring spacing along the rope; bending is smooth, lay detail is per pixel.
const ROPE_RING_STEP := 0.1
const MIN_LENGTH := 0.3
## Rope and hook drift up to ~0.5 m from the rest pose in a gale; the rest AABB
## would otherwise cull a hook that has swung into view.
const CULL_MARGIN := 1.0

const HOOK_TUBE_SIDES := 8

static var _mesh_cache: Dictionary = {}


## A ready-to-place rope node: the anchor is its origin, the rope hangs along -Y
## for `length` metres and the hook below it. Do not scale the node.
static func create(length: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = NODE_NAME
	instance.mesh = build_mesh(length)
	# Materials live in the wind cache (reset with MapViewMaterials), so bind
	# them per instance instead of baking them into the shared cached mesh.
	instance.set_surface_override_material(0, MapViewMaterials.hoist_rope_hemp())
	instance.set_surface_override_material(1, MapViewMaterials.hoist_rope_iron())
	instance.extra_cull_margin = CULL_MARGIN
	instance.set_meta(&"hoist_rope", true)
	instance.set_meta(&"rope_length", maxf(length, MIN_LENGTH))
	return instance


## Replaces kit GLB markers with live ropes. `model` must already be a child of
## `root`; the rope is parented to `root` so the model's non-uniform footprint
## fit does not stretch the rope or squash the hook. Returns ropes added.
static func attach_at_markers(root: Node3D, model: Node3D) -> int:
	var added := 0
	for anchor: Node in model.find_children("%s*" % ANCHOR_MARKER, "", true, false):
		var anchor_node := anchor as Node3D
		if anchor_node == null:
			continue
		var end_name := String(anchor_node.name).replace(ANCHOR_MARKER, END_MARKER)
		var end_node := anchor_node.get_parent().get_node_or_null(end_name) as Node3D
		if end_node == null:
			continue
		var top := _origin_in(root, anchor_node)
		var bottom := _origin_in(root, end_node)
		# The kit beam protrudes toward the street (+Z in model space); turn the
		# hook so its bill points along the beam, like a hook hung off a sheave.
		var facing := Basis(Vector3.UP, model.rotation.y) * Basis(Vector3.UP, -PI * 0.5)
		root.add_child(_placed(top, bottom, facing))
		added += 1
	return added


## Swaps a baked rope cylinder and hook (hoist_beam plot-dressing component)
## for a live rope. Rope top and hook eye come from the baked meshes' bounds
## in `component` space. Returns true when a rope was attached. Names are
## patterns: Blender exports the prop rope as "Rope.001".
static func replace_baked(component: Node3D, rope_name := "Rope*", hook_name := "Hook") -> bool:
	var rope := component.find_child(rope_name, true, false) as MeshInstance3D
	var hook := component.find_child(hook_name, true, false) as MeshInstance3D
	if rope == null or hook == null or rope.mesh == null or hook.mesh == null:
		return false
	var rope_box := _transform_in(component, rope) * rope.mesh.get_aabb()
	var hook_box := _transform_in(component, hook) * hook.mesh.get_aabb()
	var centre := rope_box.get_center()
	var top := Vector3(centre.x, rope_box.end.y, centre.z)
	var bottom := Vector3(centre.x, hook_box.end.y, centre.z)
	rope.get_parent().remove_child(rope)
	rope.free()
	hook.get_parent().remove_child(hook)
	hook.free()
	# The prop beam runs along local X, the axis the hook bill is built on.
	component.add_child(_placed(top, bottom, Basis.IDENTITY))
	return true


static func _placed(top: Vector3, bottom: Vector3, facing: Basis) -> MeshInstance3D:
	var rope := create(top.y - bottom.y)
	rope.transform = Transform3D(facing, top)
	return rope


static func _transform_in(ancestor: Node3D, node: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		var spatial := current as Node3D
		if spatial != null:
			xf = spatial.transform * xf
		current = current.get_parent()
	return xf


static func _origin_in(ancestor: Node3D, node: Node3D) -> Vector3:
	return _transform_in(ancestor, node).origin


## Two surfaces: 0 = hemp rope, 1 = iron hook. Cached per centimetre of length.
static func build_mesh(length: float) -> ArrayMesh:
	var rope_length := snappedf(maxf(length, MIN_LENGTH), 0.01)
	var key := int(round(rope_length * 100.0))
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var mesh := ArrayMesh.new()
	_rope_surface(rope_length).commit(mesh)
	_hook_surface(rope_length).commit(mesh)
	_mesh_cache[key] = mesh
	return mesh


static func _rope_surface(length: float) -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := maxi(int(ceil(length / ROPE_RING_STEP)), 4)
	var hemp := Color(1.0, 1.0, 1.0)
	_add_tube_rings(st, length, rings, 0.0, length, ROPE_RADIUS, hemp, 0)
	# Tarred whipping where the rope is spliced through the hook eye; it rides
	# the rope end, so it shares the rope surface and bends with it.
	var whipping := Color(0.55, 0.5, 0.44)
	var base := (rings + 1) * (ROPE_SIDES + 1)
	_add_tube_rings(st, length, 3, length - 0.07, length + 0.012, ROPE_RADIUS * 1.25, whipping, base)
	st.generate_tangents()
	return st


## Rings of a straight tube along -Y from depth `s0` to `s1`. UV.x runs around
## the rope and UV.y = s / L (shader contract); UV2 = (0, L).
static func _add_tube_rings(
	st: SurfaceTool,
	length: float,
	segments: int,
	s0: float,
	s1: float,
	radius: float,
	color: Color,
	base: int
) -> void:
	for ring in range(segments + 1):
		var s := lerpf(s0, s1, float(ring) / float(segments))
		for side in range(ROPE_SIDES + 1):
			var a := TAU * float(side) / float(ROPE_SIDES)
			var normal := Vector3(cos(a), 0.0, sin(a))
			st.set_normal(normal)
			st.set_color(color)
			st.set_uv(Vector2(float(side) / float(ROPE_SIDES), s / length))
			st.set_uv2(Vector2(0.0, length))
			st.add_vertex(Vector3(0.0, -s, 0.0) + normal * radius)
	var row := ROPE_SIDES + 1
	for ring in range(segments):
		for side in range(ROPE_SIDES):
			var a := base + ring * row + side
			var b := a + row
			# Godot treats clockwise triangles as front faces.
			st.add_index(a)
			st.add_index(b)
			st.add_index(a + 1)
			st.add_index(b)
			st.add_index(b + 1)
			st.add_index(a + 1)


## Forged J hook in the local XY plane, hung below the rope end: a round eye the
## rope is spliced through, a shank, the bowl, and a tapered bill turned in.
static func _hook_surface(length: float) -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(0.0, -length, 0.0)
	var vertex_count := 0
	# Eye: a closed ring.
	var eye: PackedVector3Array = []
	var eye_radii: PackedFloat32Array = []
	for i in range(17):
		var a := TAU * float(i) / 16.0
		eye.append(top + Vector3(0.026 * sin(a), -0.03 + 0.026 * cos(a), 0.0))
		eye_radii.append(0.008)
	vertex_count = _sweep(st, eye, eye_radii, length, vertex_count)
	# Shank, bowl and bill as one swept bar that thins toward the point.
	var bar: PackedVector3Array = []
	var bar_radii: PackedFloat32Array = []
	bar.append(top + Vector3(0.0, -0.05, 0.0))
	bar_radii.append(0.011)
	bar.append(top + Vector3(0.0, -0.17, 0.0))
	bar_radii.append(0.013)
	var bowl_centre := top + Vector3(0.046, -0.17, 0.0)
	for i in range(1, 13):
		var a := PI + (PI + 0.55) * float(i) / 12.0
		bar.append(bowl_centre + Vector3(cos(a), sin(a), 0.0) * 0.046)
		bar_radii.append(lerpf(0.013, 0.008, float(i) / 12.0))
	bar.append(top + Vector3(0.078, -0.112, 0.0))
	bar_radii.append(0.0035)
	vertex_count = _sweep(st, bar, bar_radii, length, vertex_count)
	st.generate_tangents()
	return st


## Sweeps a circle along a polyline in the XY plane (plane normal +Z).
static func _sweep(
	st: SurfaceTool,
	path: PackedVector3Array,
	radii: PackedFloat32Array,
	length: float,
	base: int
) -> int:
	var count := path.size()
	var row := HOOK_TUBE_SIDES + 1
	for i in range(count):
		var tangent := (path[mini(i + 1, count - 1)] - path[maxi(i - 1, 0)]).normalized()
		var side_axis := tangent.cross(Vector3.BACK).normalized()
		for side in range(row):
			var a := TAU * float(side) / float(HOOK_TUBE_SIDES)
			var normal := side_axis * cos(a) + Vector3.BACK * sin(a)
			st.set_normal(normal)
			st.set_color(Color(1.0, 1.0, 1.0))
			st.set_uv(Vector2(float(side) / float(HOOK_TUBE_SIDES), float(i) / float(count - 1)))
			st.set_uv2(Vector2(1.0, length))
			st.add_vertex(path[i] + normal * radii[i])
	for i in range(count - 1):
		for side in range(HOOK_TUBE_SIDES):
			var a := base + i * row + side
			var b := a + row
			# Opposite handedness to the rope rings (normal = side x plane).
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(b)
			st.add_index(b)
			st.add_index(a + 1)
			st.add_index(b + 1)
	return base + count * row
