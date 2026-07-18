class_name CharacterHealthRing3D
extends Node3D

## Ground ring health indicator for shared character rigs in the 3D map view.

const INNER_RADIUS := 0.30
const OUTER_RADIUS := 0.36
const ARC_SEGMENTS := 64
const ARC_START := 0.0

var _background: MeshInstance3D
var _fill: MeshInstance3D
var _fill_material: StandardMaterial3D

var current_health := 100.0
var max_health := 100.0


func _ready() -> void:
	_build_nodes()
	set_health(current_health, max_health)


func set_health(current: float, maximum: float) -> void:
	current_health = maxf(current, 0.0)
	max_health = maxf(maximum, 0.0)
	_update_fill_mesh()


func get_health_ratio() -> float:
	if max_health <= 0.0:
		return 0.0
	return clampf(current_health / max_health, 0.0, 1.0)


func _build_nodes() -> void:
	position = Vector3(0.0, 0.04, 0.0)

	_background = MeshInstance3D.new()
	_background.name = "Background"
	var background_mesh := CylinderMesh.new()
	background_mesh.top_radius = OUTER_RADIUS
	background_mesh.bottom_radius = OUTER_RADIUS
	background_mesh.height = 0.035
	background_mesh.radial_segments = 48
	_background.mesh = background_mesh
	var background_material := StandardMaterial3D.new()
	background_material.albedo_color = CharacterHealthRing.COLOR_BACKGROUND
	background_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	background_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	background_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_background.material_override = background_material
	add_child(_background)

	_fill = MeshInstance3D.new()
	_fill.name = "Fill"
	_fill_material = StandardMaterial3D.new()
	_fill_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fill_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_fill.material_override = _fill_material
	add_child(_fill)


func _update_fill_mesh() -> void:
	var ratio := get_health_ratio()
	_fill_material.albedo_color = CharacterHealthRing.color_for_ratio(ratio)
	if ratio <= 0.0:
		_fill.mesh = null
		return
	_fill.mesh = _build_arc_mesh(ratio)


static func _build_arc_mesh(ratio: float) -> ArrayMesh:
	var end_angle := ARC_START + TAU * ratio
	var segment_count := maxi(3, int(float(ARC_SEGMENTS) * ratio))
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	for index in segment_count + 1:
		var t := float(index) / float(segment_count)
		var angle := lerpf(ARC_START, end_angle, t)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		vertices.append(direction * INNER_RADIUS)
		vertices.append(direction * OUTER_RADIUS)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)

	for index in segment_count:
		var base := index * 2
		indices.append_array([base, base + 1, base + 2, base + 1, base + 3, base + 2])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
