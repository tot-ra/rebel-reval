class_name TreeLeafFall3D
extends Node3D

## R-1187 living vegetation, presentation only. Three effects share one node:
## - strike(): a melee swing that reaches a tree shakes that crown (MultiMesh
##   INSTANCE_CUSTOM, read by map_view_canopy.gdshader) and knocks loose a burst
##   of leaves coloured for the current season (none from a bare winter tree);
## - update_ambient(): leaves drifting down around the player in autumn, and a
##   few in storms during any leafed season, only where trees actually stand;
## - per-frame decay of active shakes.
## Nothing here touches gameplay or save state; the season comes from the
## campaign date via VegetationPhenology, so it is deterministic.

const CANOPY_MULTIMESH_GROUP := &"tree_canopy_multimesh"
const CANOPY_MESH_GROUP := &"tree_canopy_mesh"
## Trunks are a radius away from the instance origin; a swing that grazes the
## bark should still count.
const TRUNK_TOLERANCE := 0.45
## Slack on the attack cone: a tree is a big target compared to an enemy.
const FACING_SLACK := 0.2
const BURST_POOL_SIZE := 6
const SHAKE_DURATION := 1.8
const SHAKE_AMPLITUDE := 0.16
const AMBIENT_AMOUNT := 40
const AMBIENT_SAMPLE_INTERVAL := 1.5
const AMBIENT_TREE_RADIUS := 22.0
const AMBIENT_BOX := Vector3(9.0, 1.5, 9.0)

var _bursts: Array[CPUParticles3D] = []
var _next_burst := 0
var _ambient: CPUParticles3D
var _ambient_amount := 0
var _ambient_timer := 0.0
var _ambient_species: StringName = &""
var _ambient_tree_count := 0
var _ambient_ramp_key := ""
## Active shakes: {node, index, direction(Vector2), strength, age}.
var _shakes: Array[Dictionary] = []
var _leaf_mesh: QuadMesh


## Marks a tree crown MultiMesh as strikeable. Instance transforms are kept as
## node meta because MultiMesh buffers are GPU-side: reading them back is a
## RenderingServer sync in real renderers and returns nothing on the headless
## dummy renderer, so queries would be both slow and untestable.
static func tag_canopy(
	instance: MultiMeshInstance3D, species: StringName, transforms: Array[Transform3D]
) -> void:
	instance.set_meta(&"tree_species", species)
	instance.set_meta(&"tree_transforms", transforms.duplicate())
	instance.add_to_group(CANOPY_MULTIMESH_GROUP)


static func _instance_transforms(instance: MultiMeshInstance3D) -> Array:
	if instance.has_meta(&"tree_transforms"):
		return instance.get_meta(&"tree_transforms")
	var result: Array = []
	if instance.multimesh != null:
		for index in instance.multimesh.instance_count:
			result.append(instance.multimesh.get_instance_transform(index))
	return result


func _ready() -> void:
	_leaf_mesh = _make_leaf_mesh()
	for index in BURST_POOL_SIZE:
		var burst := _make_emitter("LeafBurst%d" % index)
		burst.one_shot = true
		burst.explosiveness = 0.82
		burst.emitting = false
		_bursts.append(burst)
		add_child(burst)
	_ambient = _make_emitter("AmbientLeaves")
	_ambient.amount = AMBIENT_AMOUNT
	_ambient.lifetime = 6.0
	_ambient.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_ambient.emission_box_extents = AMBIENT_BOX
	_ambient.emitting = false
	add_child(_ambient)


func _process(delta: float) -> void:
	_advance_shakes(delta)


## Finds the tree a swing reaches. `origin` is the attacker in world space,
## `facing_xz` the world XZ swing direction, `reach` in world units. Returns the
## nearest hit as {node, index, species, trunk, crown_center, crown_radius,
## distance} or an empty Dictionary. Static and scene-agnostic for tests.
static func find_struck_tree(
	candidates: Array[Node], origin: Vector3, facing_xz: Vector2, reach: float, facing_dot: float
) -> Dictionary:
	var best: Dictionary = {}
	if facing_xz.is_zero_approx():
		return best
	var facing := facing_xz.normalized()
	var max_distance := reach + TRUNK_TOLERANCE
	for node in candidates:
		if not is_instance_valid(node) or not node.has_meta(&"tree_species"):
			continue
		var species: StringName = node.get_meta(&"tree_species")
		if node is MultiMeshInstance3D:
			var instance := node as MultiMeshInstance3D
			var multi := instance.multimesh
			if multi == null or multi.mesh == null:
				continue
			var crown_aabb := multi.mesh.get_aabb()
			var base := _world_transform(instance)
			var transforms := _instance_transforms(instance)
			for index in transforms.size():
				var tree_transform := base * (transforms[index] as Transform3D)
				var hit := _evaluate(
					tree_transform, crown_aabb, origin, facing, max_distance, facing_dot
				)
				if hit.is_empty():
					continue
				if best.is_empty() or float(hit["distance"]) < float(best["distance"]):
					hit["node"] = instance
					hit["index"] = index
					hit["species"] = species
					best = hit
		elif node is MeshInstance3D:
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.mesh == null:
				continue
			var hit_single := _evaluate(
				_world_transform(mesh_instance),
				mesh_instance.mesh.get_aabb(),
				origin,
				facing,
				max_distance,
				facing_dot
			)
			if hit_single.is_empty():
				continue
			if best.is_empty() or float(hit_single["distance"]) < float(best["distance"]):
				hit_single["node"] = mesh_instance
				hit_single["index"] = -1
				hit_single["species"] = species
				best = hit_single
	return best


static func _world_transform(node: Node3D) -> Transform3D:
	return node.global_transform if node.is_inside_tree() else node.transform


static func _evaluate(
	tree_transform: Transform3D,
	crown_aabb: AABB,
	origin: Vector3,
	facing: Vector2,
	max_distance: float,
	facing_dot: float
) -> Dictionary:
	var trunk := tree_transform.origin
	var offset := Vector2(trunk.x - origin.x, trunk.z - origin.z)
	var distance := offset.length()
	if distance > max_distance:
		return {}
	# Standing inside the trunk radius counts as a hit regardless of facing.
	if distance > TRUNK_TOLERANCE and facing.dot(offset / distance) < facing_dot - FACING_SLACK:
		return {}
	var centre := tree_transform * crown_aabb.get_center()
	var scaled := crown_aabb.size * tree_transform.basis.get_scale()
	return {
		"trunk": trunk,
		"crown_center": centre,
		"crown_radius": maxf(0.3, minf(scaled.x, scaled.z) * 0.5),
		"crown_height": maxf(0.5, centre.y - trunk.y),
		"distance": distance,
	}


## Resolves one swing against the trees of this view. Returns the hit info (see
## find_struck_tree) with an added "leaves" count, or {} when nothing was struck.
func strike(
	origin: Vector3,
	facing_xz: Vector2,
	reach: float,
	facing_dot: float,
	strength: float,
	date: Dictionary
) -> Dictionary:
	var hit := find_struck_tree(_owned_canopies(), origin, facing_xz, reach, facing_dot)
	if hit.is_empty():
		return hit
	var species: StringName = hit["species"]
	var leaves := VegetationPhenology.hit_leaf_count(species, date, strength)
	hit["leaves"] = leaves
	if int(hit["index"]) >= 0:
		start_shake(hit["node"], int(hit["index"]), facing_xz.normalized(), strength)
	if leaves > 0:
		_emit_burst(hit, VegetationPhenology.falling_leaf_colors(species, date), leaves)
	return hit


## Begins (or restarts) a damped crown shake on one MultiMesh instance.
func start_shake(
	instance: MultiMeshInstance3D, index: int, direction: Vector2, strength: float
) -> void:
	if instance == null or instance.multimesh == null:
		return
	if not instance.multimesh.use_custom_data:
		return
	for shake in _shakes:
		if shake["node"] == instance and int(shake["index"]) == index:
			shake["age"] = 0.0
			shake["strength"] = maxf(float(shake["strength"]), strength)
			shake["direction"] = direction
			return
	_shakes.append(
		{"node": instance, "index": index, "direction": direction, "strength": strength, "age": 0.0}
	)
	_advance_shakes(0.0)


func active_shake_count() -> int:
	return _shakes.size()


## Damped two-axis sway written into INSTANCE_CUSTOM. Pushed away from the
## blow first, then rings down; z drives extra leaf flutter in the shader.
static func shake_custom(direction: Vector2, strength: float, age: float) -> Color:
	if age >= SHAKE_DURATION:
		return Color(0.0, 0.0, 0.0, 0.0)
	var dir := direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	var across := Vector2(-dir.y, dir.x)
	var envelope := exp(-age * 3.2) * clampf(strength, 0.2, 2.0) * SHAKE_AMPLITUDE
	var sway := dir * cos(age * 10.5) * envelope + across * sin(age * 7.3) * envelope * 0.35
	return Color(sway.x, sway.y, clampf(exp(-age * 2.2) * strength, 0.0, 1.0), 0.0)


func _advance_shakes(delta: float) -> void:
	for i in range(_shakes.size() - 1, -1, -1):
		var shake: Dictionary = _shakes[i]
		var node: Variant = shake["node"]
		# Streamed scatter chunks can be freed mid-shake.
		if not is_instance_valid(node):
			_shakes.remove_at(i)
			continue
		var multi := (node as MultiMeshInstance3D).multimesh
		var index := int(shake["index"])
		if multi == null or index >= multi.instance_count:
			_shakes.remove_at(i)
			continue
		shake["age"] = float(shake["age"]) + delta
		var custom := shake_custom(shake["direction"], float(shake["strength"]), shake["age"])
		multi.set_instance_custom_data(index, custom)
		if float(shake["age"]) >= SHAKE_DURATION:
			_shakes.remove_at(i)


## Ambient leaf fall around `focus` (the player). Samples nearby trees every
## AMBIENT_SAMPLE_INTERVAL so open streets stay clean and woods drop leaves.
func update_ambient(
	focus: Vector3, date: Dictionary, wind_direction: Vector2, wind_strength: float, delta: float
) -> void:
	if _ambient == null:
		return
	_ambient_timer -= delta
	if _ambient_timer <= 0.0:
		_ambient_timer = AMBIENT_SAMPLE_INTERVAL
		_sample_nearby_trees(focus)
	var rate := 0.0
	if not _ambient_species.is_empty():
		rate = ambient_rate(_ambient_species, date, wind_strength, _ambient_tree_count)
	var amount := int(round(rate * AMBIENT_AMOUNT / 8.0)) * 8
	if amount <= 0:
		_ambient.emitting = false
		_ambient_amount = 0
		return
	_ambient.global_position = focus + Vector3(0.0, 5.5, 0.0)
	var wind := wind_direction.normalized() if not wind_direction.is_zero_approx() else Vector2.ZERO
	# R-1321: drifting leaves speed up as the shared gust front passes overhead.
	var gust := WindField.pressure(Vector2(focus.x, focus.z), WindField.clock()) / 0.8
	var drift := 0.4 + wind_strength * gust * 1.6
	_ambient.gravity = Vector3(wind.x * drift, -0.95, wind.y * drift)
	if amount != _ambient_amount:
		# Quantised in steps of 8 because changing amount restarts the emitter.
		_ambient_amount = amount
		_ambient.amount = amount
	var ramp_key := "%s:%s" % [_ambient_species, GameCalendar.format_date(date)]
	if ramp_key != _ambient_ramp_key:
		_ambient_ramp_key = ramp_key
		_ambient.color_initial_ramp = _gradient(
			VegetationPhenology.falling_leaf_colors(_ambient_species, date)
		)
	_ambient.emitting = true


## 0..1 share of the ambient particle budget. Autumn fall rate dominates;
## strong wind adds a little in any season that has leaves on the trees.
static func ambient_rate(
	species: StringName, date: Dictionary, wind_strength: float, tree_count: int
) -> float:
	if tree_count <= 0:
		return 0.0
	var state := VegetationPhenology.state_for(species, date)
	var density := float(state["leaf_density"])
	if density <= 0.02:
		return 0.0
	var storm := smoothstep(0.55, 0.9, wind_strength)
	var rate := float(state["fall_rate"]) * (0.35 + wind_strength) + storm * 0.25 * density
	var woods := clampf(float(tree_count) / 6.0, 0.25, 1.0)
	return clampf(rate * woods, 0.0, 1.0)


func ambient_amount() -> int:
	return _ambient_amount


func _sample_nearby_trees(focus: Vector3) -> void:
	var counts: Dictionary = {}
	var radius_squared := AMBIENT_TREE_RADIUS * AMBIENT_TREE_RADIUS
	for node in _owned_canopies():
		var species: StringName = node.get_meta(&"tree_species")
		if node is MultiMeshInstance3D:
			var instance := node as MultiMeshInstance3D
			var base := _world_transform(instance)
			for tree_transform: Transform3D in _instance_transforms(instance):
				var position := base * tree_transform.origin
				var tree_offset := Vector2(position.x - focus.x, position.z - focus.z)
				if tree_offset.length_squared() <= radius_squared:
					counts[species] = int(counts.get(species, 0)) + 1
		elif node is Node3D:
			var position_single := (node as Node3D).global_position
			var offset := Vector2(position_single.x - focus.x, position_single.z - focus.z)
			if offset.length_squared() <= radius_squared:
				counts[species] = int(counts.get(species, 0)) + 1
	_ambient_species = &""
	_ambient_tree_count = 0
	var best_count := 0
	for species: StringName in counts.keys():
		_ambient_tree_count += int(counts[species])
		# Deciduous trees drive leaf fall; conifers only win when alone.
		var weight := int(counts[species]) * (1 if VegetationPhenology.is_evergreen(species) else 4)
		if weight > best_count:
			best_count = weight
			_ambient_species = species


func _owned_canopies() -> Array[Node]:
	var result: Array[Node] = []
	if not is_inside_tree():
		return result
	var owner_view := get_parent()
	for group in [CANOPY_MULTIMESH_GROUP, CANOPY_MESH_GROUP]:
		for node in get_tree().get_nodes_in_group(group):
			# Seamless streaming can mount several views; each only owns its trees.
			if owner_view != null and owner_view.is_ancestor_of(node):
				result.append(node)
	return result


func _emit_burst(hit: Dictionary, colors: Array[Color], amount: int) -> void:
	# The pool is built in _ready; a strike on a view still being assembled
	# outside the scene tree only shakes the crown.
	if _bursts.is_empty():
		return
	var burst := _bursts[_next_burst]
	_next_burst = (_next_burst + 1) % _bursts.size()
	var radius := float(hit["crown_radius"])
	var height := float(hit["crown_height"])
	# Emit from the lower crown shell, not its centre: under the gameplay camera
	# leaves born inside the crown fall behind its own foliage and never read.
	var crown_center: Vector3 = hit["crown_center"]
	burst.global_position = crown_center - Vector3(0.0, minf(radius * 0.6, height * 0.5), 0.0)
	burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = radius
	burst.amount = maxi(amount, 1)
	# Net fall acceleration ~0.9 m/s^2 after damping: leaves need roughly
	# sqrt(2h/a) seconds to reach the ground from the crown centre.
	burst.lifetime = clampf(sqrt(2.0 * maxf(height - radius * 0.3, 0.5) / 0.9), 1.6, 5.5)
	var wind := MapViewMaterials.WIND_MATERIALS.world_wind_direction()
	var wind_strength := WindField.local_strength(
		Vector2(crown_center.x, crown_center.z), WindField.clock()
	)
	burst.gravity = Vector3(wind.x * wind_strength * 1.4, -1.25, wind.y * wind_strength * 1.4)
	burst.color_initial_ramp = _gradient(colors)
	burst.restart()
	burst.emitting = true


func _make_emitter(emitter_name: String) -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	emitter.name = emitter_name
	emitter.mesh = _leaf_mesh
	emitter.local_coords = false
	emitter.direction = Vector3.UP
	emitter.spread = 180.0
	emitter.initial_velocity_min = 0.15
	emitter.initial_velocity_max = 0.9
	emitter.damping_min = 0.25
	emitter.damping_max = 0.6
	# Swirl plus velocity alignment makes each leaf tumble and side-slip while
	# it falls instead of dropping like a stone.
	emitter.tangential_accel_min = -1.6
	emitter.tangential_accel_max = 1.6
	emitter.angular_velocity_min = -260.0
	emitter.angular_velocity_max = 260.0
	emitter.angle_min = 0.0
	emitter.angle_max = 360.0
	emitter.particle_flag_align_y = true
	emitter.scale_amount_min = 0.7
	emitter.scale_amount_max = 1.25
	# Shrink out at the end of life instead of blending, keeping the material opaque.
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.85, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	emitter.scale_amount_curve = curve
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return emitter


static func _make_leaf_mesh() -> QuadMesh:
	var mesh := QuadMesh.new()
	# Larger than a real 7 cm leaf on purpose: the gameplay camera shows about
	# 21 px per metre, so true-size leaves were ~1.5 px and the burst vanished
	# in GPU captures. 14 cm reads as a tumbling leaf without looking like a card.
	mesh.size = Vector2(0.14, 0.10)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.8
	material.backlight_enabled = true
	material.backlight = Color(0.35, 0.3, 0.15)
	mesh.material = material
	return mesh


static func _gradient(colors: Array[Color]) -> Gradient:
	var gradient := Gradient.new()
	if colors.is_empty():
		return gradient
	var offsets := PackedFloat32Array()
	var packed := PackedColorArray()
	for index in colors.size():
		offsets.append(float(index) / maxf(float(colors.size() - 1), 1.0))
		packed.append(colors[index])
	gradient.offsets = offsets
	gradient.colors = packed
	return gradient
