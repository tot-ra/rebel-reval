extends "res://tests/godot/test_case.gd"

## 1343 Reval gate-leaf and portcullis kit: deterministic Blender GLBs at gate_arch landmarks.

const LowerTownSlice := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")

const GATE_PATHS := {
	&"oak": "res://assets/props/architecture/gates/oak_double_gate.glb",
	&"ironbound": "res://assets/props/architecture/gates/ironbound_double_gate.glb",
	&"portcullis": "res://assets/props/architecture/gates/raised_portcullis.glb",
}


func test_gate_glbs_load_with_embedded_albedo_and_triangle_budget() -> void:
	for variant in GATE_PATHS:
		var scene := load(GATE_PATHS[variant]) as PackedScene
		assert_true(scene != null, "%s gate GLB must import" % String(variant))
		var instance := scene.instantiate() as Node3D
		assert_true(instance != null, "%s gate root must be Node3D" % String(variant))
		var triangle_count := 0
		var textured_surfaces := 0
		for mesh_instance in instance.find_children("*", "MeshInstance3D", true, false):
			var mi := mesh_instance as MeshInstance3D
			if mi.mesh == null:
				continue
			for surface_index in mi.mesh.get_surface_count():
				triangle_count += mi.mesh.surface_get_array_index_len(surface_index) / 3
				var material := mi.mesh.surface_get_material(surface_index) as StandardMaterial3D
				if material != null and material.albedo_texture != null:
					textured_surfaces += 1
		assert_true(
			triangle_count >= 1500 and triangle_count <= 6000,
			"%s triangle budget (%d)" % [String(variant), triangle_count]
		)
		assert_true(textured_surfaces >= 1, "%s needs embedded albedo surfaces" % String(variant))
		instance.free()


func test_viru_gate_arch_uses_authored_gate_assets() -> void:
	var definition := LowerTownSlice.create()
	var arch_def: Dictionary = {}
	for landmark in definition.view_landmarks:
		if landmark["id"] == &"viru_gate_arch":
			arch_def = landmark
	assert_false(arch_def.is_empty(), "Viru Gate arch landmark must exist")
	assert_eq(arch_def.get("gate_variant", &""), &"ironbound")
	assert_eq(arch_def.get("grille_variant", &""), &"portcullis")
	var arch := MapViewMeshBuilder.build_landmark(arch_def, definition.cell_size)
	assert_true(arch.has_node("GateLeaves"), "Viru Gate needs generated open gate leaves")
	assert_true(arch.has_node("GatePortcullis"), "Viru Gate needs its raised grille")
	arch.free()
