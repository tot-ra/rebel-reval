class_name CityPuddleStepVfx
extends Node3D

## Small, transient view-only response to a boot landing in a rain-filled city puddle.
## Audio/surface classification remains in FootstepAudio; this node only draws.

const RippleShader := preload("res://scripts/city/city_puddle_ripple.gdshader")
const SprayShader := preload("res://scripts/city/city_spray.gdshader")

const MAX_ACTIVE := 8
const RING_LIFETIME := 0.8
const RING_RADIUS := 0.06
const RING_RADIUS_END := 0.55
const SPLASH_LIFETIME := 0.34

## Same layered recipe as the sea breakers (CityShoreSpray): velocity-streaked fine
## droplets plus a faint spume puff, drawn with the shared lit spray shader. WHY: the
## old 7 round unshaded spheres read as bubbles; streaked, lit, tiny drops read as water.
var _effects: Array[Dictionary] = []
var _ripple_material: ShaderMaterial
var _ring_mesh: QuadMesh
var _drop_mesh: QuadMesh
var _spume_mesh: QuadMesh
var _drop_ramp: Gradient
var _spume_ramp: Gradient


func _ready() -> void:
	_ripple_material = ShaderMaterial.new()
	_ripple_material.shader = RippleShader
	_ring_mesh = QuadMesh.new()
	_ring_mesh.size = Vector2(2.0, 2.0)
	_drop_mesh = _spray_quad(0.02, 5.0, 2.0, true, 0.5)
	_spume_mesh = _spray_quad(0.12, 1.0, 0.0, false, 1.0)
	_drop_ramp = _ramp([[0.0, 0.0], [0.06, 0.55], [0.65, 0.4], [1.0, 0.0]])
	_spume_ramp = _ramp([[0.0, 0.0], [0.15, 0.08], [1.0, 0.0]])


static func _spray_quad(
	size: float, stretch: float, decay: float, aligned: bool, softness: float
) -> QuadMesh:
	var material := ShaderMaterial.new()
	material.shader = SprayShader
	material.set_shader_parameter("stretch", stretch)
	material.set_shader_parameter("stretch_decay", decay)
	material.set_shader_parameter("velocity_aligned", 1.0 if aligned else 0.0)
	material.set_shader_parameter("softness", softness)
	# Muddy grey-blue, not the sea spray's near-white: puddle water is dull and dark.
	material.set_shader_parameter("tint", Vector3(0.5, 0.56, 0.6))
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = material
	return quad


static func _ramp(points: Array) -> Gradient:
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for point: Array in points:
		offsets.append(float(point[0]))
		colors.append(Color(1.0, 1.0, 1.0, float(point[1])))
	gradient.offsets = offsets
	gradient.colors = colors
	return gradient


func play_step(world_position: Vector3, heading: Vector2 = Vector2.ZERO) -> bool:
	if not is_inside_tree():
		return false
	while _effects.size() >= MAX_ACTIVE:
		_remove_effect(0)
	var effect := Node3D.new()
	effect.name = "PuddleStep"
	effect.position = world_position + Vector3.UP * 0.012
	add_child(effect)
	var ring := MeshInstance3D.new()
	ring.name = "RippleRing"
	ring.mesh = _ring_mesh
	ring.material_override = _ripple_material.duplicate()
	ring.rotation.x = -PI * 0.5
	ring.scale = Vector3.ONE * RING_RADIUS
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effect.add_child(ring)
	# The boot kicks water forward along the heading, so the fan leans that way.
	var lean := Vector3(heading.x * 0.45, 1.0, heading.y * 0.45).normalized()
	var drops := _make_particles("Splash", 14, SPLASH_LIFETIME + 0.2, _drop_mesh, _drop_ramp)
	drops.direction = lean
	drops.spread = 42.0
	drops.initial_velocity_min = 0.7
	drops.initial_velocity_max = 1.7
	drops.gravity = Vector3(0.0, -9.8, 0.0)
	drops.damping_min = 0.3
	drops.damping_max = 0.8
	drops.scale_amount_min = 0.5
	drops.scale_amount_max = 1.4
	drops.particle_flag_align_y = true
	drops.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	drops.emission_sphere_radius = 0.05
	effect.add_child(drops)
	var spume := _make_particles("Spume", 4, 0.5, _spume_mesh, _spume_ramp)
	spume.direction = lean
	spume.spread = 70.0
	spume.initial_velocity_min = 0.2
	spume.initial_velocity_max = 0.6
	spume.gravity = Vector3(0.0, -0.2, 0.0)
	spume.damping_min = 2.0
	spume.damping_max = 3.0
	spume.scale_amount_min = 0.5
	spume.scale_amount_max = 1.0
	effect.add_child(spume)
	_effects.append({"root": effect, "ring": ring, "age": 0.0})
	return true


func _make_particles(
	node_name: String, amount: int, lifetime: float, mesh: Mesh, ramp: Gradient
) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = node_name
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.local_coords = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.mesh = mesh
	particles.color_ramp = ramp
	particles.emitting = true
	return particles


func _process(delta: float) -> void:
	for i in range(_effects.size() - 1, -1, -1):
		var effect: Dictionary = _effects[i]
		var age := float(effect["age"]) + delta
		effect["age"] = age
		var root := effect["root"] as Node3D
		var ring := effect["ring"] as MeshInstance3D
		if age >= RING_LIFETIME:
			_remove_effect(i)
			continue
		var t := clampf(age / RING_LIFETIME, 0.0, 1.0)
		# Ease-out: the ripple front is fast at first and slows as it spreads.
		ring.scale = Vector3.ONE * lerpf(RING_RADIUS, RING_RADIUS_END, 1.0 - pow(1.0 - t, 2.2))
		var ring_material := ring.material_override as ShaderMaterial
		if ring_material != null:
			ring_material.set_shader_parameter("progress", t)
		if age >= SPLASH_LIFETIME:
			var splash := root.get_node_or_null("Splash") as CPUParticles3D
			if splash != null:
				splash.emitting = false


func active_effect_count() -> int:
	return _effects.size()


func _remove_effect(index: int) -> void:
	if index < 0 or index >= _effects.size():
		return
	var effect: Dictionary = _effects[index]
	var root := effect["root"] as Node3D
	_effects.remove_at(index)
	if is_instance_valid(root):
		root.queue_free()
