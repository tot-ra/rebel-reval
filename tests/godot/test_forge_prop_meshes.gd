extends "res://tests/godot/test_case.gd"

## Smithy forge props: elegant anvil, open firebox furnace, bellows, charcoal.


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
	var max_y := -999.0
	for vertex in vertices:
		min_x = minf(min_x, vertex.x)
		max_x = maxf(max_x, vertex.x)
		max_y = maxf(max_y, vertex.y)
	assert_true(min_x < -0.5, "anvil needs a projecting horn")
	assert_true(max_x > 0.4, "anvil needs a heel mass")
	assert_true(max_x - min_x > 0.95, "anvil silhouette must stay longer than a cube stack")
	assert_true(max_y > 0.38, "anvil needs a raised flat face")
	node.free()


func test_furnace_has_open_mouth_with_visible_hot_coal() -> void:
	var node := MapViewMeshBuilder.build_prop(
		{"id": &"forge_furnace", "kind": MapTypes.PROP_KIND_FURNACE, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(node.has_node("Mass"), "furnace needs a masonry mass")
	assert_true(node.has_node("LeftCheek"), "furnace needs open-mouth left cheek")
	assert_true(node.has_node("RightCheek"), "furnace needs open-mouth right cheek")
	assert_true(node.has_node("Lintel"), "furnace needs a lintel over the mouth")
	assert_true(node.has_node("Firebox"), "furnace needs a recessed soot back wall")
	assert_true(node.has_node("EmberBed"), "furnace needs a glowing ember bed")
	assert_true(node.has_node("CoalA"), "furnace needs a coal bed")
	assert_true(node.has_node("FlameCore"), "furnace needs flame volumes")
	assert_true(node.has_node("FireSparks"), "furnace needs fire particles")
	assert_true(node.has_node("ForgeFireLight"), "furnace needs a day/night fire light controller")
	assert_true(node.has_node("Tuyere"), "furnace needs a tuyere for the bellows")
	assert_true(node.has_node("Chimney"), "furnace keeps an integrated chimney")
	var mass := node.get_node("Mass") as MeshInstance3D
	var mass_mesh := mass.mesh as BoxMesh
	assert_true(mass_mesh.size.x >= 2.0, "furnace mass must be wider than the old 1.35 m block")
	assert_true(mass_mesh.size.y >= 1.45, "furnace mass must be taller than the old block")
	var firebox := node.get_node("Firebox") as MeshInstance3D
	var firebox_mesh := firebox.mesh as BoxMesh
	# Firebox is a thin rear wall inside the cavity, not a front-facing black plug.
	assert_true(firebox_mesh.size.z <= 0.25, "firebox must be a thin cavity back, not a solid mouth plug")
	var ember := node.get_node("EmberBed") as MeshInstance3D
	var ember_mat := ember.material_override as StandardMaterial3D
	assert_true(ember_mat != null and ember_mat.emission_enabled, "ember bed must glow")
	assert_false(node.has_node("Mouth"), "flat orange Mouth stand-in must be gone")
	node.free()


func test_bellows_has_leather_bag_and_nozzle() -> void:
	var node := MapViewMeshBuilder.build_prop(
		{"id": &"forge_bellows", "kind": MapTypes.PROP_KIND_BELLOWS, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(node.has_node("BoardBottom"), "bellows need a bottom board")
	assert_true(node.has_node("BoardTop"), "bellows need a top board")
	assert_true(node.has_node("Leather0"), "bellows need leather folds")
	assert_true(node.has_node("Nozzle"), "bellows need a nozzle aimed at the forge")
	assert_true(node.has_node("Lever"), "bellows need a pump lever")
	var leather := node.get_node("Leather0") as MeshInstance3D
	var material := leather.material_override as StandardMaterial3D
	assert_true(material != null, "leather fold needs a material")
	assert_true(material.albedo_color.r > 0.25, "leather should read warm brown, not charcoal black")
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
