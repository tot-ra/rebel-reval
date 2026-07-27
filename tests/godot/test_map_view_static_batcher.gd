extends "res://tests/godot/test_case.gd"

const Batcher := preload("res://scripts/map/view3d/map_view_static_batcher.gd")


func test_merge_skips_object_space_triplanar_masonry() -> void:
	var root := Node3D.new()
	var limestone := MapViewMaterials.wall_surface_triplanar(&"limestone", Color(0.7, 0.68, 0.62))
	for index in 2:
		var wall := MeshInstance3D.new()
		wall.name = "TriplanarWall%d" % index
		var box := BoxMesh.new()
		box.size = Vector3(2.0, 3.0, 0.4)
		wall.mesh = box
		wall.material_override = limestone
		wall.position = Vector3(float(index) * 3.0, 1.5, 0.0)
		root.add_child(wall)
	var removed := Batcher.merge(root, {})
	assert_eq(removed, 0, "object-space triplanar walls must stay separate instances")
	assert_eq(root.get_child_count(), 2, "triplanar masonry must not be replaced by batched meshes")
	root.free()


func test_merge_combines_shared_non_triplanar_trim() -> void:
	var root := Node3D.new()
	var stone := MapViewMaterials.role(&"stone")
	for index in 3:
		var quoin := MeshInstance3D.new()
		quoin.name = "Quoin%d" % index
		var box := BoxMesh.new()
		box.size = Vector3(0.3, 0.3, 0.2)
		quoin.mesh = box
		quoin.material_override = stone
		quoin.position = Vector3(float(index), 0.15, 0.0)
		root.add_child(quoin)
	var removed := Batcher.merge(root, {})
	assert_eq(removed, 3, "shared trim should collapse into one batched mesh")
	assert_true(root.has_node("Batched00"), "trim batch must replace the source leaves")
	assert_eq(root.get_child_count(), 1, "only the merged trim mesh should remain")
	root.free()


## Regression: a thatch ridge pole (indexed CylinderMesh) shares its material with
## the vertex-coloured, non-indexed slope shells. Merging both formats into one
## surface dropped the slope triangles and painted the pole black.
func test_merge_keeps_mixed_vertex_formats_apart() -> void:
	var root := Node3D.new()
	var thatch := MapViewMaterials.role(&"hay")
	for index in 2:
		var slope := MeshInstance3D.new()
		slope.name = "Slope%d" % index
		slope.mesh = _colored_quad_mesh()
		slope.material_override = thatch
		slope.position = Vector3(float(index) * 2.0, 0.0, 0.0)
		root.add_child(slope)
	var ridge := MeshInstance3D.new()
	ridge.name = "Ridge"
	var cylinder := CylinderMesh.new()
	cylinder.height = 4.0
	cylinder.top_radius = 0.2
	cylinder.bottom_radius = 0.2
	ridge.mesh = cylinder
	ridge.material_override = thatch
	root.add_child(ridge)

	Batcher.merge(root, {})

	assert_true(root.has_node("Ridge"), "an unpaired primitive must keep its own instance")
	assert_true(root.has_node("Batched00"), "the two coloured slopes must still batch together")
	var batched := root.get_node("Batched00") as MeshInstance3D
	var arrays: Array = (batched.mesh as ArrayMesh).surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	assert_eq(vertices.size(), 12, "both slope quads must survive the merge")
	assert_eq(colors.size(), 12, "merged slopes must keep their vertex colours")
	for color in colors:
		assert_true(color.r > 0.5, "no slope vertex may inherit a primitive's black default")
	root.free()


## Non-indexed, vertex-coloured quad, matching how the thatch slopes are authored.
func _colored_quad_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [
		Vector3(0.0, 0.0, 0.0),
		Vector3(1.0, 0.0, 0.0),
		Vector3(1.0, 0.0, 1.0),
		Vector3(0.0, 0.0, 0.0),
		Vector3(1.0, 0.0, 1.0),
		Vector3(0.0, 0.0, 1.0),
	]
	for corner in corners:
		surface.set_normal(Vector3.UP)
		surface.set_color(Color(0.9, 0.9, 0.9))
		surface.set_uv(Vector2.ZERO)
		surface.add_vertex(corner)
	return surface.commit()


func test_gate_arch_keeps_triplanar_mass_after_merge() -> void:
	var landmark := {
		"id": &"gate.test",
		"kind": &"gate_arch",
		"rect": Rect2(0.0, 0.0, 6.0, 2.0),
		"wall_color": Color(0.72, 0.7, 0.66),
		"passage_axis": &"z",
	}
	var gate := MapViewMeshBuilder.build_landmark(landmark, 32)
	Batcher.merge(gate, {})
	assert_true(gate.has_node("Bridge"), "gate bridge must survive batching")
	assert_true(gate.has_node("Jamb0"), "gate jambs must survive batching")
	var bridge := gate.get_node("Bridge") as MeshInstance3D
	var jamb := gate.get_node("Jamb0") as MeshInstance3D
	assert_true(bridge.mesh != null, "gate bridge must keep its masonry mesh")
	assert_true(jamb.mesh != null, "gate jambs must keep their masonry mesh")
	gate.free()
