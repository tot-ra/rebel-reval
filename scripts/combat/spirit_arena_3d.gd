class_name SpiritArena3D
extends Node3D
## Bounded 3D spirit-duel arena (ADR 0038, SA3D-1): a floor disc around the place where the
## hero stands. Fighters are clamped inside it. Indoors the real room is hidden (walls, roof,
## furniture, props) so only the floor and the fighters remain; outdoors the street stays
## visible and only the boundary ring is added. The map is hidden, never unloaded: every node
## this class hides is restored to its prior visibility on close(). Presentation only, no rules.

const DEFAULT_RADIUS := 9.0
const FLOOR_THICKNESS := 0.2
const RING_THICKNESS := 0.08
const FLOOR_COLOR := Color(0.07, 0.08, 0.13)
const RING_COLOR := Color(0.55, 0.65, 1.0, 0.8)

var radius := DEFAULT_RADIUS
var center := Vector3.ZERO
var indoors := false

var _open := false
var _hidden: Array[Dictionary] = []
var _floor: MeshInstance3D
var _ring: MeshInstance3D
var _light: OmniLight3D


func is_open() -> bool:
	return _open


## Mount the arena under `world_root` around `at`. `keep` are the fighters (and anything else
## that must stay visible); a kept node's ancestors are never hidden, only their other children.
func open(
	world_root: Node, at: Vector3, keep: Array[Node3D] = [], is_indoors := false, arena_radius := DEFAULT_RADIUS  # gdlint: ignore=max-line-length
) -> bool:
	if _open or world_root == null or arena_radius <= 0.0:
		return false
	center = at
	radius = arena_radius
	indoors = is_indoors
	world_root.add_child(self)
	global_position = Vector3(at.x, at.y, at.z)
	_build_floor()
	if indoors:
		_hide_room(world_root, keep)
	_open = true
	return true


## Restore everything that was hidden and remove the arena nodes.
func close() -> void:
	if not _open:
		return
	for entry: Dictionary in _hidden:
		var node: Variant = entry["node"]
		if is_instance_valid(node):
			(node as Node3D).visible = bool(entry["was_visible"])
	_hidden.clear()
	_open = false
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()


## `position` pulled back onto the disc (planar distance from the centre; height is kept).
func clamp_position(position: Vector3) -> Vector3:
	var flat := Vector2(position.x - center.x, position.z - center.z)
	if flat.length() <= radius:
		return position
	flat = flat.normalized() * radius
	return Vector3(center.x + flat.x, position.y, center.z + flat.y)


func contains(position: Vector3) -> bool:
	return Vector2(position.x - center.x, position.z - center.z).length() <= radius


## Nodes this arena has hidden, for tests and the capture tool.
func hidden_nodes() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for entry: Dictionary in _hidden:
		if is_instance_valid(entry["node"]):
			out.append(entry["node"] as Node3D)
	return out


func _build_floor() -> void:
	_floor = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = FLOOR_THICKNESS
	disc.radial_segments = 64
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = FLOOR_COLOR
	floor_mat.roughness = 0.9
	disc.material = floor_mat
	_floor.mesh = disc
	# Top face flush with the hero's feet so he does not sink into the disc.
	_floor.position = Vector3(0.0, -FLOOR_THICKNESS * 0.5 - 0.01, 0.0)
	_floor.name = "SpiritFloor"
	add_child(_floor)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - RING_THICKNESS
	torus.outer_radius = radius + RING_THICKNESS
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = RING_COLOR
	ring_mat.emission_enabled = true
	ring_mat.emission = RING_COLOR
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	torus.material = ring_mat
	_ring.mesh = torus
	_ring.position = Vector3(0.0, 0.05, 0.0)
	_ring.name = "SpiritRing"
	add_child(_ring)
	# A cold fill light so the bare floor and the fighters read once the room's lamps are gone.
	_light = OmniLight3D.new()
	_light.light_color = Color(0.6, 0.7, 1.0)
	_light.light_energy = 1.2
	_light.omni_range = radius * 1.6
	_light.position = Vector3(0.0, 4.0, 0.0)
	_light.name = "SpiritFill"
	add_child(_light)


## Hide every sibling subtree that holds no kept node. Lights, cameras and the environment stay
## so the scene keeps its mood; the arena's own nodes are never touched.
func _hide_room(node: Node, keep: Array[Node3D]) -> void:
	for child: Node in node.get_children():
		if child == self or not child is Node3D:
			continue
		if child is Light3D or child is Camera3D:
			continue
		var holds_keep := false
		for kept: Node3D in keep:
			if kept == child or child.is_ancestor_of(kept):
				holds_keep = true
				break
		if holds_keep:
			if not keep.has(child):
				_hide_room(child, keep)
			continue
		var as_3d := child as Node3D
		_hidden.append({"node": as_3d, "was_visible": as_3d.visible})
		as_3d.visible = false
