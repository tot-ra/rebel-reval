class_name SpiritArena3D
extends Node3D
## Bounded 3D spirit-duel arena (ADR 0038 SA3D-1, amended by ADR 0041 section 5, SS-6): a ring
## on the ground around the place where the hero stands. Fighters are clamped inside it. The
## building stays: walls, floor, pillars, stairs and shells are never touched, so any wall inside
## the radius keeps its collision and bounds the fight. What vanishes is the node groups in
## HIDE_GROUPS (furniture, props, loose items, clutter) and every being outside the duel. The
## duel grade (spirit_sight.gd) turns the world nearly monochrome indigo, every other light is
## switched off in favour of the arena's own key and fill, and only the two fighters keep an aura.
## The map is hidden, never unloaded: everything this class changes is restored on close().
## Presentation only, no rules.

const SpiritSightScript := preload("res://scripts/combat/spirit_sight.gd")
const AuraManagerScript := preload("res://scripts/combat/spirit_aura_manager.gd")

## The one hide list. Spawners tag their nodes with these groups (HouseholdLayout items, map
## props, stage kits); the arena never knows a map by name.
const GROUP_FURNITURE := &"spirit_hide_furniture"
const GROUP_PROP := &"spirit_hide_prop"
const GROUP_ITEM := &"spirit_hide_item"
const GROUP_CLUTTER := &"spirit_hide_clutter"
const HIDE_GROUPS: Array[StringName] = [GROUP_FURNITURE, GROUP_PROP, GROUP_ITEM, GROUP_CLUTTER]
const DEFAULT_RADIUS := 9.0
const RING_THICKNESS := 0.08
const RING_COLOR := Color(0.55, 0.65, 1.0, 0.8)
## Arena key and fill: the only lights that survive the duel grade.
const KEY_COLOR := Color(0.78, 0.82, 1.0)
const FILL_COLOR := Color(0.42, 0.5, 1.0)

var radius := DEFAULT_RADIUS
var center := Vector3.ZERO
## Informational since SS-6: indoors and outdoors strip the same HIDE_GROUPS.
var indoors := false

var _open := false
var _hidden: Array[Dictionary] = []
var _ring: MeshInstance3D
var _key: OmniLight3D
var _fill: OmniLight3D
var _sight: Node
var _auras: Node
var _own_auras := false
## Fallback grade for stages without a spirit-sight controller (the almshouse hall).
var _env: Environment
var _env_base: Dictionary = {}
var _suns: Array[Dictionary] = []


func is_open() -> bool:
	return _open


## Mount the arena under `world_root` around `at`. `keep` are the fighters (and anything else
## that must stay visible); a kept node's ancestors and descendants are never hidden.
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
	_build_ring_and_lights()
	_hide_groups(world_root, keep)
	_hide_outsiders(world_root, keep)
	_switch_off_other_lights(world_root, keep)
	_apply_grade(world_root)
	_show_fighter_auras(keep)
	_open = true
	return true


## Restore everything that was hidden or graded and remove the arena nodes. The hero stays in
## spirit sight (the sight controller keeps its own blend); only the duel layer goes away.
func close() -> void:
	if not _open:
		return
	for index in range(_hidden.size() - 1, -1, -1):
		var node: Variant = _hidden[index]["node"]
		if is_instance_valid(node):
			(node as Node3D).visible = bool(_hidden[index]["was_visible"])
	_hidden.clear()
	if is_instance_valid(_sight):
		_sight.set(&"duel_amount", 0.0)
	_restore_grade()
	if is_instance_valid(_auras):
		if _own_auras:
			_auras.call(&"release_views")
			_auras.queue_free()
		else:
			_auras.call(&"set_duel_fighters", [] as Array[Node3D])
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


## The aura view of a fighter while the duel layer shows it (null when none).
func aura_view_for(body: Node3D) -> SpiritAuraView:
	if not is_instance_valid(_auras):
		return null
	return _auras.call(&"view_for", body) as SpiritAuraView


func _build_ring_and_lights() -> void:
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
	# Key from above and to the side, fill low and cold from the other: the fighters read
	# against the indigo room once its own lamps are off.
	_key = OmniLight3D.new()
	_key.name = "SpiritKey"
	_key.light_color = KEY_COLOR
	_key.light_energy = 1.6
	_key.omni_range = radius * 1.8
	_key.position = Vector3(radius * 0.3, 4.5, radius * 0.4)
	add_child(_key)
	_fill = OmniLight3D.new()
	_fill.name = "SpiritFill"
	_fill.light_color = FILL_COLOR
	_fill.light_energy = 0.8
	_fill.omni_range = radius * 1.6
	_fill.position = Vector3(-radius * 0.4, 2.0, -radius * 0.3)
	add_child(_fill)


## Hide every node of the HIDE_GROUPS under `world_root` that is not a fighter, holds a fighter,
## or lives inside one. Walls, floor, terrain and shells are in no group and so stay.
func _hide_groups(world_root: Node, keep: Array[Node3D]) -> void:
	if not world_root.is_inside_tree():
		return
	for group in HIDE_GROUPS:
		for node in world_root.get_tree().get_nodes_in_group(group):
			if node is Node3D and world_root.is_ancestor_of(node):
				_hide(node as Node3D, keep)


## People and animals outside the duel vanish (the aura-bearer group is every rig).
func _hide_outsiders(world_root: Node, keep: Array[Node3D]) -> void:
	if not world_root.is_inside_tree():
		return
	for node in world_root.get_tree().get_nodes_in_group(SharedCharacterRig.SPIRIT_AURA_GROUP):
		if node is Node3D and world_root.is_ancestor_of(node):
			_hide(node as Node3D, keep)


## Every light but the arena's own goes off. A sun is graded, not switched off: the sight
## controller does it when there is one, `_apply_grade` otherwise.
func _switch_off_other_lights(world_root: Node, keep: Array[Node3D]) -> void:
	for node in world_root.find_children("*", "Light3D", true, false):
		if node is DirectionalLight3D or is_ancestor_of(node):
			continue
		_hide(node as Node3D, keep)


func _hide(node: Node3D, keep: Array[Node3D]) -> void:
	if node == self or is_ancestor_of(node) or not node.visible:
		return
	# A fighter, its ancestors and everything it carries (its own lights, aura) stay.
	for kept in keep:
		if kept == node or node.is_ancestor_of(kept) or kept.is_ancestor_of(node):
			return
	_hidden.append({"node": node, "was_visible": node.visible})
	node.visible = false


func _apply_grade(world_root: Node) -> void:
	if not world_root.is_inside_tree():
		return
	_sight = world_root.get_tree().get_first_node_in_group(SpiritSightScript.SIGHT_GROUP)
	if _sight != null:
		_sight.set(&"duel_amount", 1.0)
		return
	_env = _find_environment(world_root)
	if _env != null:
		for field in SpiritSightScript.FIELDS:
			_env_base[field] = _env.get(field)
		SpiritSightScript.grade_environment(_env, _env_base, 0.0, 1.0)
	for node in world_root.find_children("*", "DirectionalLight3D", true, false):
		var sun := node as DirectionalLight3D
		_suns.append({"node": sun, "energy": sun.light_energy})
		sun.light_energy = SpiritSightScript.sun_energy_for(sun.light_energy, 0.0, 1.0)


func _restore_grade() -> void:
	if is_instance_valid(_env) and not _env_base.is_empty():
		for field in SpiritSightScript.FIELDS:
			_env.set(field, _env_base[field])
	_env_base.clear()
	for entry in _suns:
		if is_instance_valid(entry["node"]):
			(entry["node"] as DirectionalLight3D).light_energy = float(entry["energy"])
	_suns.clear()
	_env = null
	_sight = null


func _find_environment(world_root: Node) -> Environment:
	for node in world_root.find_children("*", "WorldEnvironment", true, false):
		var world_env := node as WorldEnvironment
		if world_env.environment != null:
			return world_env.environment
	var camera := world_root.get_viewport().get_camera_3d() if world_root.is_inside_tree() else null
	if camera != null and camera.environment != null:
		return camera.environment
	return world_root.get_viewport().find_world_3d().environment


## Only the fighters keep an aura. The scene's aura manager (under the sight controller) is
## switched to fighters-only; a stage without one gets a private manager for the duel.
func _show_fighter_auras(keep: Array[Node3D]) -> void:
	var fighters: Array[Node3D] = []
	for node in keep:
		if node.is_in_group(SharedCharacterRig.SPIRIT_AURA_GROUP):
			fighters.append(node)
	if fighters.is_empty() or not is_inside_tree():
		return
	_auras = get_tree().get_first_node_in_group(AuraManagerScript.GROUP)
	if _auras == null:
		_auras = AuraManagerScript.new()
		_auras.set(&"follow_session", false)
		add_child(_auras)
		_own_auras = true
	_auras.call(&"set_duel_fighters", fighters)
