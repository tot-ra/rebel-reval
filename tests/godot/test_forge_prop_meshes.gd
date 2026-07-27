extends "res://tests/godot/test_case.gd"

## Smithy forge props: elegant anvil, open firebox furnace, bellows, charcoal.


func test_smithy_chair_uses_detailed_glb_without_replacing_town_hall_fallback() -> void:
	var smithy := MapViewMeshBuilder.build_prop(
		{"id": &"work_chair", "kind": MapTypes.PROP_KIND_CHAIR, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(smithy.has_node("SmithyChairModel"), "smithy chair must instantiate the authored GLB")
	assert_false(smithy.has_node("Seat"), "smithy chair must not keep the four-box placeholder")
	var model := smithy.get_node("SmithyChairModel") as Node3D
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	assert_true(meshes.size() > 0, "authored chair GLB needs renderable mesh geometry")
	var bounds := AABB()
	var first := true
	var surface_count := 0
	var triangle_count := 0
	var has_embedded_albedo := false
	for child in meshes:
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var child_bounds := mesh_instance.transform * mesh_instance.get_aabb()
		bounds = child_bounds if first else bounds.merge(child_bounds)
		first = false
		surface_count += mesh_instance.mesh.get_surface_count()
		for surface_index in mesh_instance.mesh.get_surface_count():
			triangle_count += mesh_instance.mesh.surface_get_array_index_len(surface_index) / 3
			var material := mesh_instance.mesh.surface_get_material(surface_index) as StandardMaterial3D
			if material != null and material.albedo_texture != null:
				has_embedded_albedo = true
	assert_false(first, "chair GLB must expose a non-empty AABB")
	assert_true(bounds.size.y >= 1.0 and bounds.size.y <= 1.1, "chair must import at believable metric height")
	assert_true(bounds.position.y >= -0.001, "chair feet must rest on the prop ground plane")
	assert_eq(surface_count, 3, "chair detail pass keeps wood, worn wood, and peg surfaces")
	assert_true(triangle_count >= 1500 and triangle_count <= 3000, "chair detail must stay readable and lightweight")
	assert_true(has_embedded_albedo, "chair's painted oak grain must survive GLB import")
	smithy.free()

	var formal := MapViewMeshBuilder.build_prop(
		{"id": &"burgomaster_chair", "kind": MapTypes.PROP_KIND_CHAIR, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(formal.has_node("Seat"), "non-smithy chairs keep their generic fallback")
	assert_false(formal.has_node("SmithyChairModel"), "smithy model must not leak into Town Hall")
	formal.free()


func test_smithy_anvil_uses_detailed_glb_without_replacing_courtyard_fallback() -> void:
	var smithy := MapViewMeshBuilder.build_prop(
		{"id": &"forge_anvil", "kind": MapTypes.PROP_KIND_ANVIL, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(smithy.has_node("SmithyAnvilModel"), "smithy anvil must instantiate the authored GLB")
	assert_false(smithy.has_node("Body"), "smithy anvil must not keep the procedural body")
	var model := smithy.get_node("SmithyAnvilModel") as Node3D
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	assert_true(meshes.size() >= 3, "authored anvil needs separate stump, body, and face meshes")
	var bounds := AABB()
	var first := true
	var material_names: Dictionary = {}
	var triangle_count := 0
	var has_embedded_albedo := false
	for child in meshes:
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var child_bounds := mesh_instance.transform * mesh_instance.get_aabb()
		bounds = child_bounds if first else bounds.merge(child_bounds)
		first = false
		for surface_index in mesh_instance.mesh.get_surface_count():
			triangle_count += mesh_instance.mesh.surface_get_array_index_len(surface_index) / 3
			var material := mesh_instance.mesh.surface_get_material(surface_index) as StandardMaterial3D
			if material != null:
				material_names[material.resource_name] = true
				if material.albedo_texture != null:
					has_embedded_albedo = true
	assert_false(first, "anvil GLB must expose a non-empty AABB")
	assert_true(bounds.size.x >= 1.45 and bounds.size.x <= 1.52, "anvil needs a long metric horn-to-heel silhouette")
	assert_true(bounds.size.y >= 0.98 and bounds.size.y <= 1.03, "anvil and stump need a believable metric height")
	assert_true(bounds.size.z >= 0.68 and bounds.size.z <= 0.72, "anvil face needs a broad working width")
	assert_true(bounds.position.y >= -0.001, "stump must rest on the prop ground plane")
	assert_true(triangle_count >= 1800 and triangle_count <= 4000, "anvil detail must stay readable and lightweight")
	assert_true(material_names.size() == 3, "anvil keeps iron, polished face, and oak material identities")
	assert_true(has_embedded_albedo, "anvil's painted wear textures must survive GLB import")
	smithy.free()

	var courtyard := MapViewMeshBuilder.build_prop(
		{"id": &"courtyard_anvil", "kind": MapTypes.PROP_KIND_ANVIL, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(courtyard.has_node("Stump"), "outdoor anvil keeps the lightweight procedural stump")
	assert_true(courtyard.has_node("Body"), "outdoor anvil keeps the custom procedural body")
	assert_false(courtyard.has_node("SmithyAnvilModel"), "smithy model must not leak into the courtyard")
	var body := courtyard.get_node("Body") as MeshInstance3D
	assert_true(body.mesh is ArrayMesh, "courtyard fallback must remain a custom ArrayMesh")
	courtyard.free()


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
