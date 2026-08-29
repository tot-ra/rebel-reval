extends "res://tests/godot/map_view_3d_test_base.gd"

## Regression contract for the exceptional South Quarter gate landmark.


func test_karja_gate_exposes_open_metal_leaf_state() -> void:
	var definition: MapDefinition = SouthQuarterDefinition.create()
	var landmark: Dictionary = {}
	for candidate in definition.view_landmarks:
		if candidate.get("id", &"") == &"karja_gate_arch":
			landmark = candidate
			break
	assert_false(landmark.is_empty(), "South Quarter must define the Karja Gate landmark")
	assert_eq(landmark.get("door_material", &""), &"metal")

	var gate := MapViewMeshBuilder.build_landmark(landmark, definition.cell_size)
	var leaves := gate.get_node_or_null("GateLeaves") as Node3D
	assert_true(leaves != null, "Karja Gate must instantiate its authored leaf container")
	assert_eq(leaves.get_meta(&"gate_state"), &"open")
	assert_eq(leaves.get_meta(&"gate_material"), &"metal")
	assert_eq(
		leaves.get_meta(&"source_asset"),
		"res://assets/props/architecture/gates/ironbound_double_gate.glb",
	)

	for leaf_index in 2:
		var leaf := gate.get_node_or_null("GateDoor%d" % leaf_index) as MeshInstance3D
		assert_true(leaf != null, "Karja Gate must expose GateDoor%d" % leaf_index)
		assert_eq(leaf.get_meta(&"gate_state"), &"open")
		assert_eq(leaf.get_meta(&"gate_material"), &"metal")
		assert_true(leaf.has_meta(&"authored_source_node"))
		var material := leaf.material_override as StandardMaterial3D
		assert_true(material != null, "GateDoor%d needs an explicit material" % leaf_index)
		assert_eq(material.albedo_color, MapViewMaterials.role(&"metal").albedo_color)
	gate.free()
