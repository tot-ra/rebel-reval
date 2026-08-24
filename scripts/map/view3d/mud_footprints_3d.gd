class_name MudFootprints3D
extends Node3D

## Lightweight view-only impressions. The logic terrain stays immutable while a
## bounded decal trail communicates how soft the rain-soaked mud is underfoot.

const STEP_DISTANCE_WORLD := 0.42
const MAX_PRINTS := 48
const DRY_LIFETIME_SECONDS := 22.0
const WET_LIFETIME_SECONDS := 80.0
const FOOT_LATERAL_OFFSET := 0.115
const FOOT_LENGTH := 0.34
const FOOT_WIDTH := 0.14

var _last_position := Vector3(INF, INF, INF)
var _left_step := true
var _prints: Array[MeshInstance3D] = []


func _process(delta: float) -> void:
	for footprint in _prints.duplicate():
		if not is_instance_valid(footprint):
			_prints.erase(footprint)
			continue
		var age := float(footprint.get_meta(&"age", 0.0)) + delta
		var lifetime := float(footprint.get_meta(&"lifetime", DRY_LIFETIME_SECONDS))
		footprint.set_meta(&"age", age)
		var fade := 1.0 - smoothstep(lifetime * 0.62, lifetime, age)
		var material := footprint.material_override as StandardMaterial3D
		if material != null:
			var color := material.albedo_color
			color.a = float(footprint.get_meta(&"alpha", 0.45)) * fade
			material.albedo_color = color
		if age >= lifetime:
			_prints.erase(footprint)
			footprint.queue_free()


func try_add(world_position: Vector3, movement: Vector2, wetness: float) -> bool:
	if movement.length_squared() < 0.0001:
		return false
	if (
		not is_inf(_last_position.x)
		and _last_position.distance_to(world_position) < STEP_DISTANCE_WORLD
	):
		return false
	var forward := Vector3(movement.x, 0.0, movement.y).normalized()
	var side := Vector3(-forward.z, 0.0, forward.x)
	var lateral := FOOT_LATERAL_OFFSET if _left_step else -FOOT_LATERAL_OFFSET
	var saturation := clampf(wetness, 0.0, 1.0)
	var footprint := MeshInstance3D.new()
	footprint.name = "MudPrint_%02d" % _prints.size()
	footprint.mesh = _foot_mesh()
	footprint.position = world_position + side * lateral + Vector3.UP * (0.004 - saturation * 0.002)
	footprint.rotation.y = atan2(forward.x, forward.z)
	# A saturated print spreads and darkens; dry mud leaves a smaller sandy scuff.
	footprint.scale = Vector3(1.0 + saturation * 0.18, 1.0, 1.0 + saturation * 0.10)
	footprint.material_override = _foot_material(saturation)
	footprint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	footprint.set_meta(&"age", 0.0)
	footprint.set_meta(
		&"lifetime", lerpf(DRY_LIFETIME_SECONDS, WET_LIFETIME_SECONDS, saturation)
	)
	footprint.set_meta(&"alpha", lerpf(0.26, 0.62, saturation))
	add_child(footprint)
	_prints.append(footprint)
	_last_position = world_position
	_left_step = not _left_step
	while _prints.size() > MAX_PRINTS:
		var oldest: MeshInstance3D = _prints.pop_front()
		oldest.queue_free()
	return true


static func _foot_mesh() -> ArrayMesh:
	# An asymmetric eight-point sole reads as a boot, not a circular puddle decal.
	var half_width := FOOT_WIDTH * 0.5
	var half_length := FOOT_LENGTH * 0.5
	var vertices := PackedVector3Array([
		Vector3(-half_width * 0.78, 0.0, -half_length),
		Vector3(half_width * 0.78, 0.0, -half_length),
		Vector3(half_width, 0.0, -half_length * 0.38),
		Vector3(half_width * 0.86, 0.0, half_length * 0.46),
		Vector3(half_width * 0.58, 0.0, half_length),
		Vector3(-half_width * 0.58, 0.0, half_length),
		Vector3(-half_width * 0.86, 0.0, half_length * 0.46),
		Vector3(-half_width, 0.0, -half_length * 0.38),
	])
	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3, 0, 3, 4, 0, 4, 5, 0, 5, 6, 0, 6, 7])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _foot_material(saturation: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.albedo_color = Color(0.105, 0.075, 0.045, lerpf(0.26, 0.62, saturation))
	material.roughness = lerpf(0.96, 0.48, saturation)
	material.metallic_specular = lerpf(0.08, 0.22, saturation)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
