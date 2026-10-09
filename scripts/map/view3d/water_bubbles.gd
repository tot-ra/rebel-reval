extends Node3D

## Short entrained-air burst on camera immersion. One draw, 24 spheres, no
## particles simulation, textures, GPU readback or work after the burst expires.
const COUNT := 24
const LIFETIME := 2.4
var _age := LIFETIME
var _origin := Transform3D.IDENTITY
var _batch: MultiMeshInstance3D


func _ready() -> void:
	name = "ImmersionBubbles"
	# Poses are world-space, including streamed district views with an offset.
	top_level = true
	global_transform = Transform3D.IDENTITY
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/map/view3d/water_bubbles.gdshader")
	mesh.material = material
	_batch = MultiMeshInstance3D.new()
	_batch.multimesh = MultiMesh.new()
	_batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_batch.multimesh.instance_count = COUNT
	_batch.multimesh.mesh = mesh
	_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_batch)
	visible = false


func start(pose: Transform3D) -> void:
	_origin = pose
	_age = 0.0


func advance(delta: float, surface_y: float, immersed: bool) -> void:
	if _batch == null:
		return
	_age = minf(_age + maxf(delta, 0.0), LIFETIME)
	visible = immersed and _age < LIFETIME
	if not visible:
		return
	var count := 0
	for i in COUNT:
		var radius := 0.012 + float(i % 5) * 0.004
		var p := bubble_position(i, _origin, _age)
		if p.y + radius >= surface_y:
			continue
		var fade := minf(_age * 8.0, 1.0) * clampf((LIFETIME - _age) * 2.0, 0.0, 1.0)
		_batch.multimesh.set_instance_transform(
			count, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * radius * fade), p)
		)
		count += 1
	_batch.multimesh.visible_instance_count = count


static func bubble_position(index: int, pose: Transform3D, age: float) -> Vector3:
	var phase := float(index) * 2.399963
	var radius := 0.012 + float(index % 5) * 0.004
	var p := (
		pose
		* Vector3(cos(phase) * 0.38, -0.3 - float(index % 6) * 0.09, -0.6 - float(index % 4) * 0.14)
	)
	return p + Vector3(sin(phase + age * 3.0) * 0.035, age * (0.28 + radius * 7.0), 0.0)
