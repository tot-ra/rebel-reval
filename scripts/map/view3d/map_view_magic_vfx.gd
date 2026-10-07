class_name MapViewMagicVfx
extends Node3D

## View-only mirror for authored magic deliveries. Gameplay stays on the 2D
## executor nodes; this node only draws what they do so casts read in the 3D
## map view: a wind cone (knockback), a ground shock with cracks and debris
## (other area pulses), a burning projectile with an impact explosion (fire
## damage), and an iron overlay on the bound actor while a damage-reduction
## modifier is active. It never names a spell; looks follow delivery kind,
## damage type, and modifier stat (R-1198).

const Parts := preload("res://scripts/map/view3d/map_view_magic_vfx_parts.gd")
const DEFAULT_CELL_SIZE := 32
const BURST_DURATION_SEC := 0.55
const PULSE_DURATION_SEC := 2.4
const FIRE_BURST_DURATION_SEC := 2.6
const FIZZLE_DURATION_SEC := 1.0
const TRAIL_LINGER_SEC := 0.9
const WARD_CAST_DURATION_SEC := 1.4
const WEDGE_HEIGHT := 1.35
const WEDGE_SEGMENTS := 10
const SMOKE_AMOUNT := 36
const PROJECTILE_HEIGHT := 0.62
const PROJECTILE_RADIUS := 0.2
const FIRE_CORE_RADIUS := 0.13
## Splash radius used for a fire impact whose content has no `area` block.
const FIRE_MIN_RADIUS_PX := 24.0
const WARD_STAT := &"damage_reduction"
const WARD_SWEEP_SEC := 0.45
const WARD_FADE_SEC := 0.35
## The ward flickers over its last seconds so the player sees it running out.
const WARD_WARNING_SEC := 1.5

var _cell_size: int = DEFAULT_CELL_SIZE
var _definition: MapDefinition
var _watch_tree: SceneTree
var _bursts: Array[Node3D] = []
var _projectile_orbs: Array[Node3D] = []
var _ward_actor: Node
var _ward_rig: Node3D
var _ward_strength := 0.0
var _ward_coverage := 0.0
var _ward_remaining := 0.0
var _ward_clock := 0.0
## base overlay instance id (0 = none) -> iron ShaderMaterial chaining to it.
var _ward_materials: Dictionary = {}


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


## Optional world context: the map (ground height under effects) and the actor
## whose damage-reduction modifiers draw an iron overlay on `rig`.
func bind_world(definition: MapDefinition, ward_actor: Node = null, rig: Node3D = null) -> void:
	_definition = definition
	if definition != null and definition.cell_size > 0:
		_cell_size = definition.cell_size
	_ward_actor = ward_actor
	_ward_rig = rig


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
	var radius := radius_px * MapViewBridge.world_scale(used_cell)
	var burst := _new_burst("AreaPulseBurst", logic_origin, used_cell, PULSE_DURATION_SEC, 0.02)
	# WHY: a flat brown disc read as a UI marker. A real tremor shows as a
	# shock rolling over the paving, cracks racing out, dust kicked up along
	# the front, and stones jumping, then the cracks linger and fade.
	var ring := _ground_mesh(
		burst, "PulseRing", Parts.soft_ring_mesh(radius, radius * 0.22, Color(0.42, 0.34, 0.24, 1.0))
	)
	ring.position.y = 0.03
	_animate(ring, 0.5, 0.0, 0.3)
	ring.set_meta(&"grow_from", 0.12)
	ring.set_meta(&"grow_sec", 0.42)
	var seed_value := int(logic_origin.x * 7.0) * 92821 + int(logic_origin.y * 7.0)
	var cracks := _ground_mesh(
		burst, "GroundCracks", Parts.crack_mesh(radius * 0.85, seed_value), Color.WHITE
	)
	cracks.position.y = 0.025
	_animate(cracks, 1.0, 0.55, 1.0)
	cracks.set_meta(&"grow_from", 0.25)
	cracks.set_meta(&"grow_sec", 0.16)
	burst.add_child(_dust_wave(radius))
	burst.add_child(_rim_dust(radius))
	burst.add_child(_debris(radius))
	return burst


## Fire impact: white flash, rolling fireball, soot column, falling embers and
## a scorch mark that outlives the smoke. `radius_px` is the authored splash.
func play_fire_burst(logic_origin: Vector2, radius_px: float, cell_size: int = 0) -> Node3D:
	var used_cell := cell_size if cell_size > 0 else _cell_size
	if used_cell <= 0:
		return null
	var radius := maxf(radius_px, FIRE_MIN_RADIUS_PX) * MapViewBridge.world_scale(used_cell)
	var burst := _new_burst("FireBurst", logic_origin, used_cell, FIRE_BURST_DURATION_SEC, 0.0)
	var scorch := _ground_mesh(
		burst, "Scorch", Parts.soft_disk_mesh(radius * 0.7, Color(0.05, 0.035, 0.025, 0.78))
	)
	scorch.position.y = 0.02
	_animate(scorch, 1.0, 0.6, 1.0)
	scorch.set_meta(&"grow_from", 0.4)
	scorch.set_meta(&"grow_sec", 0.2)
	var flash := OmniLight3D.new()
	flash.name = "Flash"
	flash.position.y = 0.8
	flash.light_color = Color(1.0, 0.62, 0.28)
	flash.omni_range = radius * 2.4
	flash.shadow_enabled = false
	flash.set_meta(&"base_energy", 4.5)
	flash.set_meta(&"light_sec", 0.55)
	flash.light_energy = 4.5
	burst.add_child(flash)
	var fireball_process := Parts.burst_process(
		Vector2(radius * 1.6, radius * 3.2), 1.2, Vector2(0.9, 1.6), Parts.explosion_ramp()
	)
	fireball_process.damping_min = radius * 5.0
	fireball_process.damping_max = radius * 7.0
	fireball_process.scale_curve = Parts.curve_texture(
		[Vector2(0.0, 0.35), Vector2(0.25, 1.0), Vector2(1.0, 1.25)]
	)
	var fireball := Parts.particles(
		"Fireball", 30, 0.55, fireball_process, radius * 0.75, Parts.glow_material()
	)
	# Centre the billow above the paving so its quads do not slice into it.
	fireball.position.y = 0.3 + radius * 0.45
	_one_shot(fireball, 0.0)
	burst.add_child(fireball)
	var soot_process := Parts.burst_process(
		Vector2(0.4, 1.2), 1.4, Vector2(0.8, 1.5), Parts.soot_ramp(0.62)
	)
	soot_process.emission_sphere_radius = radius * 0.4
	soot_process.damping_min = 0.6
	soot_process.damping_max = 1.2
	soot_process.scale_curve = Parts.curve_texture([Vector2(0.0, 0.5), Vector2(1.0, 1.8)])
	var soot := Parts.particles(
		"Soot", 18, 1.7, soot_process, radius * 0.8, Parts.soft_smoke_material()
	)
	soot.position.y = 0.5
	_one_shot(soot, 0.0)
	soot.explosiveness = 0.8
	burst.add_child(soot)
	var embers_process := Parts.burst_process(
		Vector2(2.5, 6.0), -9.8, Vector2(0.5, 1.0), Parts.ember_ramp()
	)
	embers_process.spread = 70.0
	var embers := Parts.particles(
		"Embers", 40, 0.95, embers_process, 0.07, Parts.glow_material()
	)
	embers.position.y = 0.4
	_one_shot(embers, 0.0)
	burst.add_child(embers)
	return burst


func play_projectile_orb(projectile: MagicProjectile2D) -> Node3D:
	if projectile == null:
		return null
	var orb := Node3D.new()
	orb.name = "MagicProjectileOrb"
	orb.set_meta(&"source", projectile)
	var fire := _is_fire(projectile.impact_effect)
	orb.set_meta(&"fire", fire)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "OrbMesh"
	var sphere := SphereMesh.new()
	sphere.radius = FIRE_CORE_RADIUS if fire else PROJECTILE_RADIUS
	sphere.height = sphere.radius * 2.0
	mesh_instance.mesh = sphere
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Ember orb, not an element icon. P0-040 forbids new element art.
	material.albedo_color = Color(1.0, 0.48, 0.14, 0.92)
	if fire:
		# White-hot core; the visible body of the fireball is the flame trail.
		material.albedo_color = Color(1.0, 0.93, 0.7, 1.0)
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mesh_instance.material_override = material
	orb.add_child(mesh_instance)
	if fire:
		_add_fire_trail(orb)
	add_child(orb)
	_projectile_orbs.append(orb)
	projectile.impacted.connect(_on_projectile_impacted.bind(orb))
	projectile.expired.connect(_on_projectile_expired.bind(orb))
	_sync_projectile_orb(orb)
	return orb


## Damage-reduction overlay level on the bound rig (0 = off). For tests and
## captures that cannot read shader uniforms on the dummy renderer.
func ward_strength() -> float:
	return _ward_strength


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
			_retire_orb(orb)


func _process(delta: float) -> void:
	sync_tracked_projectiles(delta)
	sync_ward(delta)
	if delta <= 0.0 or _bursts.is_empty():
		return
	for burst: Node3D in _bursts.duplicate():
		if not is_instance_valid(burst):
			_bursts.erase(burst)
			continue
		var age := float(burst.get_meta(&"age", 0.0)) + delta
		var duration := float(burst.get_meta(&"duration", BURST_DURATION_SEC))
		burst.set_meta(&"age", age)
		_animate_burst(burst, age, duration)
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
	# Knockback cones stay the Air Gust wind volume. Other pulses get a ground
	# shock so Earth Tremor is visible without a false wind wedge.
	if String(pulse.effect.get("kind", "")) == "knockback" and pulse.arc_deg < 360.0:
		play_knockback_cone(pulse.global_position, pulse.direction, pulse.radius, pulse.arc_deg)
		return
	play_area_pulse_ring(pulse.global_position, pulse.radius)


func _on_projectile_impacted(
	logic_position: Vector2, _targets: Array[Node2D], orb: Node3D
) -> void:
	if not is_instance_valid(orb) or not bool(orb.get_meta(&"fire", false)):
		return
	var projectile: Variant = orb.get_meta(&"source", null)
	var radius := FIRE_MIN_RADIUS_PX
	if is_instance_valid(projectile):
		var area := (projectile as MagicProjectile2D).area_effect
		radius = maxf(radius, float(area.get("radius", 0.0)))
	play_fire_burst(logic_position, radius)


func _on_projectile_expired(orb: Node3D) -> void:
	if not is_instance_valid(orb) or not bool(orb.get_meta(&"fire", false)):
		return
	# Out of range: the flame gutters into a small smoke puff, no explosion.
	var burst := Node3D.new()
	burst.name = "FireFizzle"
	burst.position = orb.position
	burst.set_meta(&"age", 0.0)
	burst.set_meta(&"duration", FIZZLE_DURATION_SEC)
	add_child(burst)
	var process := Parts.burst_process(
		Vector2(0.2, 0.6), 0.9, Vector2(0.6, 1.1), Parts.soot_ramp(0.35)
	)
	var puff := Parts.particles("Puff", 8, 0.9, process, 0.5, Parts.soft_smoke_material())
	_one_shot(puff, 0.0)
	burst.add_child(puff)
	_bursts.append(burst)


func _unbind_watch() -> void:
	if _watch_tree != null and _watch_tree.node_added.is_connected(_on_node_added):
		_watch_tree.node_added.disconnect(_on_node_added)
	_watch_tree = null
	_restore_ward_overlays()


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
	# Impact and expire queue_free the 2D projectile. `as MagicProjectile2D` on
	# that freed Object errors ("Trying to cast a freed object"), so validate
	# the stored Variant first and only then cast.
	var raw: Variant = orb.get_meta(&"source", null)
	if not is_instance_valid(raw):
		return false
	var source := raw as MagicProjectile2D
	if source == null or not source.active:
		return false
	var flat := MapViewBridge.logic_to_world(source.global_position, _cell_size, 0.0)
	orb.position = flat + Vector3(0.0, _ground_y(flat) + PROJECTILE_HEIGHT, 0.0)
	var glow := orb.get_node_or_null("Glow") as OmniLight3D
	if glow != null:
		# Cheap flame flicker; deterministic enough for a view-only light.
		var t := Time.get_ticks_msec() * 0.001
		glow.light_energy = 2.2 + 0.5 * sin(t * 31.0) + 0.3 * sin(t * 17.0 + 1.7)
	return true


## A spent projectile keeps its world-space trail alive until the last flame
## and smoke particles die, instead of cutting the trail off mid-air.
func _retire_orb(orb: Node3D) -> void:
	if not bool(orb.get_meta(&"fire", false)):
		orb.queue_free()
		return
	orb.name = "MagicProjectileTrail"
	orb.remove_meta(&"source")
	for child in orb.get_children():
		if child is GPUParticles3D:
			(child as GPUParticles3D).emitting = false
		elif child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
		elif child is OmniLight3D:
			(child as OmniLight3D).visible = false
	orb.set_meta(&"age", 0.0)
	orb.set_meta(&"duration", TRAIL_LINGER_SEC)
	_bursts.append(orb)


func _add_fire_trail(orb: Node3D) -> void:
	# World-space particles so the flame streams behind the moving core.
	var flame_process := Parts.burst_process(
		Vector2(0.1, 0.5), 1.1, Vector2(0.7, 1.3), Parts.flame_ramp()
	)
	flame_process.emission_sphere_radius = FIRE_CORE_RADIUS
	flame_process.scale_curve = Parts.curve_texture(
		[Vector2(0.0, 1.0), Vector2(0.5, 0.75), Vector2(1.0, 0.1)]
	)
	flame_process.turbulence_enabled = true
	flame_process.turbulence_noise_strength = 0.6
	flame_process.turbulence_noise_scale = 2.0
	var flames := Parts.particles(
		# Dense enough that the stream reads as one tongue, not a bead chain.
		"FlameTrail", 120, 0.34, flame_process, 0.36, Parts.glow_material(), true
	)
	# WHY: at the default fixed 30 fps a fast core drops flames in separate
	# clumps along its path; emitting every rendered frame keeps one tongue.
	flames.fixed_fps = 0
	flames.emitting = true
	orb.add_child(flames)
	var smoke_process := Parts.burst_process(
		Vector2(0.05, 0.3), 0.8, Vector2(0.6, 1.2), Parts.soot_ramp(0.4)
	)
	smoke_process.scale_curve = Parts.curve_texture([Vector2(0.0, 0.5), Vector2(1.0, 1.6)])
	var smoke := Parts.particles(
		"SmokeTrail", 24, 0.85, smoke_process, 0.45, Parts.soft_smoke_material(), true
	)
	smoke.emitting = true
	orb.add_child(smoke)
	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.light_color = Color(1.0, 0.55, 0.22)
	glow.light_energy = 2.2
	glow.omni_range = 3.6
	glow.shadow_enabled = false
	orb.add_child(glow)


static func _is_fire(effect: Dictionary) -> bool:
	return String(effect.get("damage_type", "")) == "fire"


func _new_burst(
	burst_name: String, logic_origin: Vector2, cell_size: int, duration: float, lift: float
) -> Node3D:
	var burst := Node3D.new()
	burst.name = burst_name
	var flat := MapViewBridge.logic_to_world(logic_origin, cell_size, 0.0)
	burst.position = flat + Vector3(0.0, _ground_y(flat) + lift, 0.0)
	burst.set_meta(&"age", 0.0)
	burst.set_meta(&"duration", duration)
	add_child(burst)
	_bursts.append(burst)
	return burst


func _ground_y(world: Vector3) -> float:
	if _definition == null:
		return 0.0
	return MapViewMeshBuilder.ground_height(_definition, Vector2(world.x, world.z))


static func _ground_mesh(
	burst: Node3D, mesh_name: String, mesh: Mesh, tint: Color = Color.WHITE
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = mesh_name
	mesh_instance.mesh = mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.material_override = Parts.ground_material(tint)
	burst.add_child(mesh_instance)
	return mesh_instance


## Per-child fade window as fractions of the burst duration.
static func _animate(node: Node3D, base_alpha: float, fade_start: float, fade_end: float) -> void:
	node.set_meta(&"base_alpha", base_alpha)
	node.set_meta(&"fade_start", fade_start)
	node.set_meta(&"fade_end", fade_end)


## One-shot emitters start at `emit_at` seconds into the burst.
static func _one_shot(emitter: GPUParticles3D, emit_at: float) -> void:
	emitter.one_shot = true
	emitter.explosiveness = 1.0
	emitter.emitting = emit_at <= 0.0
	emitter.set_meta(&"emit_at", emit_at)


func _dust_wave(radius: float) -> GPUParticles3D:
	# Flat radial spray: dust thrown outward along the ground by the shock.
	var process := Parts.burst_process(
		Vector2(radius * 1.8, radius * 3.0), 0.5, Vector2(0.7, 1.4), Parts.dust_ramp(0.55)
	)
	process.direction = Vector3(1.0, 0.0, 0.0)
	process.spread = 180.0
	process.flatness = 1.0
	process.emission_sphere_radius = radius * 0.15
	process.damping_min = radius * 2.5
	process.damping_max = radius * 3.5
	process.scale_curve = Parts.curve_texture([Vector2(0.0, 0.4), Vector2(1.0, 1.7)])
	var dust := Parts.particles(
		"DustWave", 64, 1.1, process, radius * 0.5, Parts.soft_smoke_material()
	)
	dust.position.y = 0.15
	_one_shot(dust, 0.0)
	return dust


func _rim_dust(radius: float) -> GPUParticles3D:
	# Dust jumping up where the shock front arrives at the edge of the area.
	var process := Parts.burst_process(
		Vector2(0.8, 1.8), -1.2, Vector2(0.6, 1.2), Parts.dust_ramp(0.45)
	)
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3.UP
	process.emission_ring_radius = radius * 0.9
	process.emission_ring_inner_radius = radius * 0.7
	process.emission_ring_height = 0.05
	process.spread = 25.0
	process.scale_curve = Parts.curve_texture([Vector2(0.0, 0.5), Vector2(1.0, 1.5)])
	var dust := Parts.particles(
		"RimDust", 40, 1.0, process, radius * 0.35, Parts.soft_smoke_material()
	)
	_one_shot(dust, 0.3)
	return dust


func _debris(radius: float) -> GPUParticles3D:
	var process := Parts.burst_process(
		Vector2(2.0, 4.2), -14.0, Vector2(0.6, 1.4), null
	)
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(radius * 0.6, 0.02, radius * 0.6)
	process.spread = 30.0
	process.angular_velocity_min = -540.0
	process.angular_velocity_max = 540.0
	process.particle_flag_rotate_y = true
	process.scale_curve = Parts.curve_texture(
		[Vector2(0.0, 1.0), Vector2(0.8, 1.0), Vector2(1.0, 0.0)]
	)
	var debris := GPUParticles3D.new()
	debris.name = "Debris"
	debris.amount = 26
	debris.lifetime = 0.75
	debris.local_coords = true
	debris.process_material = process
	debris.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	debris.visibility_aabb = AABB(Vector3(-6.0, -1.0, -6.0), Vector3(12.0, 6.0, 12.0))
	var chip := BoxMesh.new()
	chip.size = Vector3(0.09, 0.06, 0.07)
	chip.material = Parts.debris_material()
	debris.draw_pass_1 = chip
	_one_shot(debris, 0.0)
	return debris


func _animate_burst(burst: Node3D, age: float, duration: float) -> void:
	var t := clampf(age / duration, 0.0, 1.0)
	for child in burst.get_children():
		var emitter := child as GPUParticles3D
		if emitter != null:
			if (
				not emitter.emitting
				and emitter.has_meta(&"emit_at")
				and age >= float(emitter.get_meta(&"emit_at"))
			):
				emitter.remove_meta(&"emit_at")
				emitter.restart()
			continue
		var light := child as OmniLight3D
		if light != null and light.has_meta(&"base_energy"):
			var light_t := clampf(age / float(light.get_meta(&"light_sec", duration)), 0.0, 1.0)
			light.light_energy = float(light.get_meta(&"base_energy")) * pow(1.0 - light_t, 2.0)
			continue
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null:
			continue
		if mesh_instance.has_meta(&"grow_sec"):
			var grow_t := clampf(age / float(mesh_instance.get_meta(&"grow_sec")), 0.0, 1.0)
			var eased := 1.0 - pow(1.0 - grow_t, 3.0)
			var grow_scale := lerpf(float(mesh_instance.get_meta(&"grow_from", 1.0)), 1.0, eased)
			mesh_instance.scale = Vector3(grow_scale, 1.0, grow_scale)
		var material := mesh_instance.material_override as StandardMaterial3D
		if material == null:
			continue
		var fade_start := float(mesh_instance.get_meta(&"fade_start", 0.0))
		var fade_end := float(mesh_instance.get_meta(&"fade_end", 1.0))
		var fade := 1.0 - clampf((t - fade_start) / maxf(fade_end - fade_start, 0.001), 0.0, 1.0)
		var base_alpha := float(
			mesh_instance.get_meta(&"base_alpha", burst.get_meta(&"base_alpha", 0.58))
		)
		var color := material.albedo_color
		color.a = base_alpha * fade
		material.albedo_color = color


func sync_ward(delta: float) -> void:
	var remaining := _ward_remaining_sec()
	var target := 1.0 if remaining > 0.0 else 0.0
	# A recast restarts the timer: replay the sweep and the sparks.
	if remaining > 0.0 and remaining > _ward_remaining + 0.25:
		_ward_coverage = 0.0
		_play_ward_cast()
	_ward_remaining = remaining
	if target == 0.0 and _ward_strength <= 0.0:
		return
	if delta > 0.0:
		_ward_clock += delta
		_ward_coverage = minf(_ward_coverage + delta / WARD_SWEEP_SEC, 1.0)
		_ward_strength = move_toward(_ward_strength, target, delta / WARD_FADE_SEC)
	if _ward_strength <= 0.0:
		_restore_ward_overlays()
		return
	var strength := _ward_strength
	if remaining > 0.0 and remaining < WARD_WARNING_SEC:
		strength *= 0.55 + 0.45 * absf(cos(_ward_clock * 9.0))
	_apply_ward_overlays(strength)


func _ward_remaining_sec() -> float:
	if _ward_actor == null or not is_instance_valid(_ward_actor):
		return 0.0
	if _ward_rig == null or not is_instance_valid(_ward_rig):
		return 0.0
	var vitals: Variant = _ward_actor.get("combat_vitals")
	if not vitals is Object:
		return 0.0
	var modifiers: Variant = (vitals as Object).get("modifiers")
	if not modifiers is CombatTimedModifiers:
		return 0.0
	return (modifiers as CombatTimedModifiers).remaining_sec_for_stat(WARD_STAT)


func _apply_ward_overlays(strength: float) -> void:
	for material: ShaderMaterial in _ward_materials.values():
		material.set_shader_parameter(&"coverage", _ward_coverage)
		material.set_shader_parameter(&"strength", strength)
	_wrap_overlays(_ward_rig)
	# Uniforms for materials created during this wrap pass.
	for material: ShaderMaterial in _ward_materials.values():
		material.set_shader_parameter(&"coverage", _ward_coverage)
		material.set_shader_parameter(&"strength", strength)
		material.set_shader_parameter(&"body_height", CharacterScale.VISIBLE_HEIGHT_WORLD)


func _wrap_overlays(node: Node) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null:
		var current := mesh_instance.material_overlay
		# The rig swaps its occlusion silhouette in and out at runtime, so
		# re-wrap whatever overlay it holds now instead of caching per mesh.
		if not _is_ward_material(current):
			mesh_instance.material_overlay = _ward_material_for(current)
	for child in node.get_children():
		_wrap_overlays(child)


func _restore_ward_overlays() -> void:
	if _ward_rig != null and is_instance_valid(_ward_rig):
		_unwrap_overlays(_ward_rig)
	_ward_strength = 0.0


func _unwrap_overlays(node: Node) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and _is_ward_material(mesh_instance.material_overlay):
		mesh_instance.material_overlay = mesh_instance.material_overlay.next_pass
	for child in node.get_children():
		_unwrap_overlays(child)


func _is_ward_material(material: Material) -> bool:
	return material != null and _ward_materials.values().has(material)


func _ward_material_for(base_overlay: Material) -> ShaderMaterial:
	var key := 0 if base_overlay == null else base_overlay.get_instance_id()
	if not _ward_materials.has(key):
		_ward_materials[key] = Parts.iron_ward_material(base_overlay)
	return _ward_materials[key]


func _play_ward_cast() -> void:
	if _ward_rig == null or not is_instance_valid(_ward_rig):
		return
	# Hammer-on-hot-iron sparks and a short forge glow at the moment the skin
	# hardens, then a wisp of quench steam.
	var burst := Node3D.new()
	burst.name = "WardCastBurst"
	burst.set_meta(&"age", 0.0)
	burst.set_meta(&"duration", WARD_CAST_DURATION_SEC)
	add_child(burst)
	burst.global_position = _ward_rig.global_position
	var sparks_process := Parts.burst_process(
		Vector2(2.0, 4.5), -9.8, Vector2(0.4, 0.9), Parts.ember_ramp()
	)
	sparks_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	sparks_process.emission_box_extents = Vector3(0.25, 0.8, 0.25)
	sparks_process.spread = 75.0
	var sparks := Parts.particles(
		"IronSparks", 48, 0.7, sparks_process, 0.06, Parts.glow_material()
	)
	sparks.position.y = 1.0
	_one_shot(sparks, 0.0)
	burst.add_child(sparks)
	var steam_process := Parts.burst_process(
		Vector2(0.3, 0.8), 1.0, Vector2(0.7, 1.3), Parts.ramp(
			[0.0, 0.3, 1.0],
			[Color(0.9, 0.9, 0.9, 0.0), Color(0.9, 0.91, 0.92, 0.28), Color(0.95, 0.95, 0.95, 0.0)]
		)
	)
	steam_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	steam_process.emission_box_extents = Vector3(0.3, 0.7, 0.3)
	steam_process.spread = 20.0
	var steam := Parts.particles(
		"QuenchSteam", 14, 1.0, steam_process, 0.6, Parts.soft_smoke_material()
	)
	steam.position.y = 1.0
	_one_shot(steam, 0.3)
	burst.add_child(steam)
	var glow := OmniLight3D.new()
	glow.name = "Flash"
	glow.position.y = 1.1
	glow.light_color = Color(1.0, 0.6, 0.3)
	glow.omni_range = 3.0
	glow.light_energy = 3.0
	glow.set_meta(&"base_energy", 3.0)
	glow.set_meta(&"light_sec", 0.5)
	burst.add_child(glow)
	_bursts.append(burst)


func _prune_bursts() -> void:
	for burst: Node3D in _bursts.duplicate():
		if not is_instance_valid(burst):
			_bursts.erase(burst)
