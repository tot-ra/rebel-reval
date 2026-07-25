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
