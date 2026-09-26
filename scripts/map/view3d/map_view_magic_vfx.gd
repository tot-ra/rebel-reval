class_name MapViewMagicVfx
extends Node3D

## View-only mirror for authored magic deliveries. Gameplay stays on the 2D
## executor nodes; this node only draws a wind cone, a ground pulse ring, and a
## following projectile orb so casts read in the 3D map view.

const DEFAULT_CELL_SIZE := 32
const BURST_DURATION_SEC := 0.55
const PULSE_DURATION_SEC := 0.4
const WEDGE_HEIGHT := 1.35
const WEDGE_SEGMENTS := 10
const SMOKE_AMOUNT := 36
const PROJECTILE_HEIGHT := 0.62
const PROJECTILE_RADIUS := 0.2

var _cell_size: int = DEFAULT_CELL_SIZE
var _watch_tree: SceneTree
var _bursts: Array[Node3D] = []
var _projectile_orbs: Array[Node3D] = []


func bind(cell_size: int, watch_root: Node) -> void:
	if cell_size > 0:
		_cell_size = cell_size
	if watch_root == null:
		return
	_unbind_watch()
	_watch_tree = watch_root.get_tree()
	if _watch_tree == null:
		return
	if not _watch_tree.node_added.is_connected(_on_node_added):
		_watch_tree.node_added.connect(_on_node_added)
	if not tree_exiting.is_connected(_unbind_watch):
		tree_exiting.connect(_unbind_watch)


func play_knockback_cone(
	logic_origin: Vector2,
	logic_direction: Vector2,
	radius_px: float,
	arc_deg: float,
	cell_size: int = 0
) -> Node3D:
	var used_cell := cell_size if cell_size > 0 else _cell_size
	if used_cell <= 0 or radius_px <= 0.0 or arc_deg <= 0.0 or arc_deg > 360.0:
		return null
	var heading := logic_direction
	if heading.is_zero_approx():
		heading = Vector2.RIGHT
	heading = heading.normalized()
	var scale := MapViewBridge.world_scale(used_cell)
	var radius_world := radius_px * scale
	var origin := MapViewBridge.logic_to_world(logic_origin, used_cell, 0.0)
	var burst := Node3D.new()
	burst.name = "AirGustBurst"
	burst.position = origin
	burst.rotation.y = atan2(heading.x, heading.y)
	burst.set_meta(&"age", 0.0)
	burst.set_meta(&"duration", BURST_DURATION_SEC)
	add_child(burst)
	_add_wedge(burst, radius_world, arc_deg)
	_add_smoke(burst, radius_world, arc_deg)
	_bursts.append(burst)
	return burst


func play_area_pulse_ring(logic_origin: Vector2, radius_px: float, cell_size: int = 0) -> Node3D:
	var used_cell := cell_size if cell_size > 0 else _cell_size
	if used_cell <= 0 or radius_px <= 0.0:
		return null
	var scale := MapViewBridge.world_scale(used_cell)
	var burst := Node3D.new()
	burst.name = "AreaPulseBurst"
	burst.position = MapViewBridge.logic_to_world(logic_origin, used_cell, 0.04)
	burst.set_meta(&"age", 0.0)
	burst.set_meta(&"duration", PULSE_DURATION_SEC)
	burst.set_meta(&"base_alpha", 0.42)
	add_child(burst)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "PulseRing"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius_px * scale
	cylinder.bottom_radius = radius_px * scale
	cylinder.height = 0.08
	cylinder.radial_segments = 20
	mesh_instance.mesh = cylinder
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Dusty ground flash, not a school-element colour and not a wind wedge.
	material.albedo_color = Color(0.62, 0.48, 0.28, 0.42)
	mesh_instance.material_override = material
	burst.add_child(mesh_instance)
	_bursts.append(burst)
	return burst


func play_projectile_orb(projectile: MagicProjectile2D) -> Node3D:
	if projectile == null:
		return null
	var orb := Node3D.new()
	orb.name = "MagicProjectileOrb"
	orb.set_meta(&"source", projectile)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "OrbMesh"
	var sphere := SphereMesh.new()
	sphere.radius = PROJECTILE_RADIUS
	sphere.height = PROJECTILE_RADIUS * 2.0
	mesh_instance.mesh = sphere
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Ember orb, not an element icon. P0-040 forbids new element art.
	material.albedo_color = Color(1.0, 0.48, 0.14, 0.92)
	mesh_instance.material_override = material
	orb.add_child(mesh_instance)
	add_child(orb)
	_projectile_orbs.append(orb)
	_sync_projectile_orb(orb)
	return orb


func active_burst_count() -> int:
	_prune_bursts()
	return _bursts.size()


func active_projectile_count() -> int:
	sync_tracked_projectiles(0.0)
	return _projectile_orbs.size()


func sync_tracked_projectiles(_delta: float = 0.0) -> void:
	for orb: Node3D in _projectile_orbs.duplicate():
		if not is_instance_valid(orb):
			_projectile_orbs.erase(orb)
			continue
		if not _sync_projectile_orb(orb):
			_projectile_orbs.erase(orb)
			orb.queue_free()


func _process(delta: float) -> void:
	sync_tracked_projectiles(delta)
	if delta <= 0.0 or _bursts.is_empty():
		return
	for burst: Node3D in _bursts.duplicate():
		if not is_instance_valid(burst):
			_bursts.erase(burst)
			continue
		var age := float(burst.get_meta(&"age", 0.0)) + delta
		var duration := float(burst.get_meta(&"duration", BURST_DURATION_SEC))
		burst.set_meta(&"age", age)
		var fade := 1.0 - clampf(age / duration, 0.0, 1.0)
		_apply_burst_fade(burst, fade)
		if age >= duration:
			_bursts.erase(burst)
			burst.queue_free()


func _on_node_added(node: Node) -> void:
	var projectile := node as MagicProjectile2D
	if projectile != null:
		play_projectile_orb(projectile)
		return
	var pulse := node as MagicAreaPulse2D
	if pulse == null or pulse.radius <= 0.0:
		return
	# Knockback cones stay the Air Gust wind volume. Other pulses get a short
	# ground ring so Earth Tremor is visible without a false wind wedge.
	if String(pulse.effect.get("kind", "")) == "knockback" and pulse.arc_deg < 360.0:
		play_knockback_cone(pulse.global_position, pulse.direction, pulse.radius, pulse.arc_deg)
		return
	play_area_pulse_ring(pulse.global_position, pulse.radius)


func _unbind_watch() -> void:
	if _watch_tree != null and _watch_tree.node_added.is_connected(_on_node_added):
		_watch_tree.node_added.disconnect(_on_node_added)
	_watch_tree = null


func _add_wedge(burst: Node3D, radius_world: float, arc_deg: float) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "WindWedge"
	mesh_instance.mesh = _wedge_mesh(radius_world, arc_deg)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	# Pale dust, not a school-element colour. P0-040 forbids new element art.
	material.albedo_color = Color(0.90, 0.95, 0.98, 0.58)
	mesh_instance.material_override = material
	burst.add_child(mesh_instance)


func _add_smoke(burst: Node3D, radius_world: float, arc_deg: float) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "WindSmoke"
	particles.amount = SMOKE_AMOUNT
	particles.lifetime = 0.48
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = 0.35
	particles.local_coords = true
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(
		Vector3(-radius_world, -0.2, -0.2),
		Vector3(radius_world * 2.0, WEDGE_HEIGHT + 0.8, radius_world + 0.6)
	)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.12
	# Mesh forward is +Z after the burst yaw; particles travel down the cone.
	process.direction = Vector3(0.0, 0.18, 1.0)
	process.spread = arc_deg * 0.5
	process.initial_velocity_min = radius_world * 1.4
	process.initial_velocity_max = radius_world * 2.3
	process.gravity = Vector3(0.0, 0.35, 0.0)
	process.damping_min = 1.2
	process.damping_max = 2.4
	process.scale_min = 0.12
	process.scale_max = 0.28
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.55))
	scale_curve.add_point(Vector2(0.35, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.15))
	var scale_texture := CurveTexture.new()
	scale_texture.curve = scale_curve
	process.scale_curve = scale_texture
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.86, 0.90, 0.93, 0.55))
	ramp.set_color(1, Color(0.74, 0.80, 0.84, 0.0))
	ramp.add_point(0.45, Color(0.80, 0.86, 0.90, 0.28))
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	process.color_ramp = ramp_texture
	particles.process_material = process
	var draw := QuadMesh.new()
	draw.size = Vector2(0.55, 0.55)
	particles.draw_pass_1 = draw
	# Shared chimney-smoke billboard; tint lives on the particle COLOR ramp.
	particles.material_override = MapViewMaterials.smoke()
	burst.add_child(particles)
	particles.emitting = true


func _wedge_mesh(radius_world: float, arc_deg: float) -> ArrayMesh:
	var half := deg_to_rad(arc_deg * 0.5)
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var top_radius := radius_world * 1.06
	# WHY: a flat floor fan disappears in the dimetric camera. A low prism
	# (ground fan, lifted fan, two sides) reads as a volume of shoved air.
	var origin_bottom := Vector3(0.0, 0.03, 0.0)
	var origin_top := Vector3(0.0, WEDGE_HEIGHT, 0.0)
	var bottom_ring: Array[Vector3] = []
	var top_ring: Array[Vector3] = []
	for index: int in range(WEDGE_SEGMENTS + 1):
		var t := float(index) / float(WEDGE_SEGMENTS)
		var angle := -half + t * half * 2.0
		var heading := Vector3(sin(angle), 0.0, cos(angle))
		bottom_ring.append(heading * radius_world + Vector3(0.0, 0.03, 0.0))
		top_ring.append(heading * top_radius + Vector3(0.0, WEDGE_HEIGHT, 0.0))
	_append_fan(verts, colors, indices, origin_bottom, bottom_ring, Color(1.0, 1.0, 1.0, 0.55))
	_append_fan(verts, colors, indices, origin_top, top_ring, Color(1.0, 1.0, 1.0, 0.22))
	_append_quad(
		verts, colors, indices,
		origin_bottom, bottom_ring[0], top_ring[0], origin_top,
		Color(1.0, 1.0, 1.0, 0.38)
	)
	_append_quad(
		verts, colors, indices,
		origin_bottom, origin_top, top_ring[top_ring.size() - 1], bottom_ring[bottom_ring.size() - 1],
		Color(1.0, 1.0, 1.0, 0.38)
	)
	for index: int in range(WEDGE_SEGMENTS):
		_append_quad(
			verts, colors, indices,
			bottom_ring[index], bottom_ring[index + 1], top_ring[index + 1], top_ring[index],
			Color(1.0, 1.0, 1.0, 0.20)
		)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _append_fan(
	verts: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	origin: Vector3,
	ring: Array[Vector3],
	color: Color
) -> void:
	var origin_index := verts.size()
	verts.append(origin)
	colors.append(color)
	var first_ring := verts.size()
	for point: Vector3 in ring:
		verts.append(point)
		colors.append(color)
	for index: int in range(ring.size() - 1):
		indices.append(origin_index)
		indices.append(first_ring + index)
		indices.append(first_ring + index + 1)


static func _append_quad(
	verts: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	color: Color
) -> void:
	var start := verts.size()
	verts.append(a)
	verts.append(b)
	verts.append(c)
	verts.append(d)
	for _i: int in range(4):
		colors.append(color)
	indices.append(start)
	indices.append(start + 1)
	indices.append(start + 2)
	indices.append(start)
	indices.append(start + 2)
	indices.append(start + 3)


func _sync_projectile_orb(orb: Node3D) -> bool:
	var source := orb.get_meta(&"source") as MagicProjectile2D
	if source == null or not is_instance_valid(source) or not source.active:
		return false
	orb.position = MapViewBridge.logic_to_world(source.global_position, _cell_size, PROJECTILE_HEIGHT)
	return true


func _apply_burst_fade(burst: Node3D, fade: float) -> void:
	var base_alpha := float(burst.get_meta(&"base_alpha", 0.58))
	for child in burst.get_children():
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null:
			continue
		var material := mesh_instance.material_override as StandardMaterial3D
		if material == null:
			continue
		var color := material.albedo_color
		color.a = base_alpha * fade
		material.albedo_color = color


func _prune_bursts() -> void:
	for burst: Node3D in _bursts.duplicate():
		if not is_instance_valid(burst):
			_bursts.erase(burst)
