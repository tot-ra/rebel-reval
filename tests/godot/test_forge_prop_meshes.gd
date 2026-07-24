extends "res://tests/godot/test_case.gd"

## Smithy forge props: elegant anvil, larger furnace with coal/fire, charcoal pile.


func test_anvil_uses_custom_horned_body_on_stump() -> void:
	var node := MapViewMeshBuilder.build_prop(
		{"id": &"forge_anvil", "kind": MapTypes.PROP_KIND_ANVIL, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(node.has_node("Stump"), "anvil needs a timber stump")
	assert_true(node.has_node("Body"), "anvil needs a custom metal body")
	assert_false(node.has_node("Face"), "legacy three-box Face must be gone")
	var body := node.get_node("Body") as MeshInstance3D
	assert_true(body.mesh is ArrayMesh, "anvil body must be a custom ArrayMesh")
	var arrays := body.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var min_x := 999.0
	var max_x := -999.0
	for vertex in vertices:
		min_x = minf(min_x, vertex.x)
		max_x = maxf(max_x, vertex.x)
	assert_true(min_x < -0.55, "anvil needs a projecting horn")
	assert_true(max_x > 0.35, "anvil needs a heel mass")
	assert_true(max_x - min_x > 1.0, "anvil silhouette must be longer than the old box stack")
	node.free()


func test_furnace_is_larger_with_coal_bed_and_fire() -> void:
	var node := MapViewMeshBuilder.build_prop(
		{"id": &"forge_furnace", "kind": MapTypes.PROP_KIND_FURNACE, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(node.has_node("Mass"), "furnace needs a masonry mass")
	assert_true(node.has_node("Firebox"), "furnace needs a recessed firebox")
	assert_true(node.has_node("CoalA"), "furnace needs a coal bed")
	assert_true(node.has_node("FlameCore"), "furnace needs flame volumes")
	assert_true(node.has_node("FireSparks"), "furnace needs fire particles")
	assert_true(node.has_node("ForgeFireLight"), "furnace needs a day/night fire light controller")
	assert_true(node.has_node("Chimney"), "furnace keeps an integrated chimney")
	var mass := node.get_node("Mass") as MeshInstance3D
	var mass_mesh := mass.mesh as BoxMesh
	assert_true(mass_mesh.size.x >= 2.0, "furnace mass must be wider than the old 1.35 m block")
	assert_true(mass_mesh.size.y >= 1.45, "furnace mass must be taller than the old block")
	assert_false(node.has_node("Mouth"), "flat orange Mouth stand-in must be gone")
	node.free()


func test_charcoal_pile_uses_charcoal_not_limestone_rock() -> void:
	var node := MapViewMeshBuilder.build_prop(
		{"id": &"coal_store", "kind": MapTypes.PROP_KIND_CHARCOAL_PILE, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(node.has_node("ChunkA"), "charcoal pile needs chunky lumps")
	assert_false(node.has_node("MoundA"), "legacy limestone rock mound must be gone")
	var chunk := node.get_node("ChunkA") as MeshInstance3D
	var material := chunk.material_override as StandardMaterial3D
	assert_true(material != null, "charcoal chunk needs a material")
	assert_true(material.albedo_color.v < 0.25, "charcoal must stay near-black, not limestone grey")
	node.free()


func test_enclosed_interior_skips_outdoor_scatter() -> void:
	var definition := KalevSmithyDefinition.create()
	assert_true(definition.suppresses_exterior_surroundings(), "smithy must be an enclosed interior")
	var grid := MapBuilder.build(definition)
	var scatter := MapViewMeshBuilder.build_scatter(definition, grid)
	assert_eq(scatter.get_child_count(), 0, "smithy floors must not grow grass or stone clutter")
	scatter.free()
