extends RefCounted
## Line-of-sight test for cinematic shots (R-1888). The city has no 3D physics colliders (its
## bodies live on the 2D logic plane), so a camera ray is tested against what is drawn: the
## meshes near the conversation are collected once, a segment is first checked against each
## mesh's world bounds and then against its real triangles. A beam, a post or a wall between the
## lens and a face blocks the shot; meshes of the people being framed are ignored, and a
## passer-by in the way can be told apart from scenery (`people_between`) so the shot hides them.
## (RenderingServer.instances_cull_ray would be cheaper but returns nothing under --headless, so
## the tests could never see a blocked shot.)

const CACHE_LIMIT := 256
const CROWD_MARGIN := 3.0

## Triangle meshes per Mesh resource (instance id -> TriangleMesh). Building one walks the whole
## surface, so the cache stays for the session; it only ever holds meshes that stood near a
## conversation.
static var _triangles: Dictionary = {}

## Every visible mesh whose bounds reached the sphere given to `collect`. Bounds are read
## again at each test: passers-by keep walking while the conversation runs.
var _occluders: Array = []


## Gathers the visible meshes of `world` within `radius` of `center`, except those under any of
## `ignore` (the subjects' rigs).
## Passers-by are collected too, with a margin of a few steps (CROWD_MARGIN) so someone
## walking into the line of sight later is still tested.
func collect(world: Node3D, center: Vector3, radius: float, ignore: Array = []) -> void:
	_occluders.clear()
	if world == null:
		return
	var reach := AABB(center - Vector3.ONE * radius, Vector3.ONE * radius * 2.0).grow(CROWD_MARGIN)
	for node in world.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree():
			continue
		if mesh_instance.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		if _under_any(mesh_instance, ignore):
			continue
		var bounds := mesh_instance.global_transform * mesh_instance.get_aabb()
		if bounds.intersects(reach):
			_occluders.append(mesh_instance)


func occluder_count() -> int:
	return _occluders.size()


## True when a collected mesh crosses the segment `from` -> `to`. With `scenery_only`, people
## (meshes under a Skeleton3D) do not count: a shot may hide a passer-by, never a wall.
func blocked(from: Vector3, to: Vector3, scenery_only: bool = false) -> bool:
	return not _crossing(from, to, scenery_only, true).is_empty()


## The rigs of the people standing across `from` -> `to` (each once).
func people_between(from: Vector3, to: Vector3) -> Array[Node3D]:
	var people: Array[Node3D] = []
	for mesh_instance: MeshInstance3D in _crossing(from, to, false, false):
		var person := person_root(mesh_instance)
		if person != null and not people.has(person):
			people.append(person)
	return people


## The whole figure a person mesh belongs to: the SharedCharacterRig above it, else the
## skeleton's parent. Null for scenery.
static func person_root(mesh_instance: Node) -> Node3D:
	var skeleton: Node = mesh_instance.get_parent()
	while skeleton != null and not (skeleton is Skeleton3D):
		skeleton = skeleton.get_parent()
	if skeleton == null:
		return null
	var node: Node = skeleton
	while node != null:
		if node is SharedCharacterRig:
			return node
		node = node.get_parent()
	return skeleton.get_parent() as Node3D


func _crossing(from: Vector3, to: Vector3, scenery_only: bool, first_only: bool) -> Array:
	var found: Array = []
	for entry in _occluders:
		# Untyped: a passer-by's rig may be freed (streamed out) mid-conversation.
		if not is_instance_valid(entry):
			continue
		var mesh_instance := entry as MeshInstance3D
		if not mesh_instance.is_visible_in_tree():
			continue
		var bounds := mesh_instance.global_transform * mesh_instance.get_aabb()
		if not bounds.grow(0.01).intersects_segment(from, to):
			continue
		var triangles := _triangles_for(mesh_instance.mesh)
		if triangles == null:
			continue
		if scenery_only and person_root(mesh_instance) != null:
			continue
		var local := mesh_instance.global_transform.affine_inverse()
		if not triangles.intersect_segment(local * from, local * to).is_empty():
			found.append(mesh_instance)
			if first_only:
				return found
	return found


## How many of `targets` are visible from `eye` (`scenery_only`: ignoring people).
func visible_count(eye: Vector3, targets: Array, scenery_only: bool = false) -> int:
	var count := 0
	for target: Vector3 in targets:
		if not blocked(eye, target, scenery_only):
			count += 1
	return count


static func _triangles_for(mesh: Mesh) -> TriangleMesh:
	var key := mesh.get_instance_id()
	if _triangles.has(key):
		return _triangles[key]
	if _triangles.size() >= CACHE_LIMIT:
		_triangles.clear()
	var triangles := mesh.generate_triangle_mesh()
	_triangles[key] = triangles
	return triangles


static func _under_any(node: Node, roots: Array) -> bool:
	for root in roots:
		if not (root is Node) or not is_instance_valid(root):
			continue
		if root == node or (root as Node).is_ancestor_of(node):
			return true
	return false
