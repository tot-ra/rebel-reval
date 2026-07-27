extends "res://tests/godot/test_case.gd"

## Smithy forge props: authored furniture, elegant anvil, open firebox furnace, bellows, charcoal.


func test_smithy_bed_uses_detailed_glb_and_keeps_generic_fallback() -> void:
	var smithy := MapViewMeshBuilder.build_prop(
			{"id": &"bed", "kind": MapTypes.PROP_KIND_BED, "position": Vector2.ZERO},
			MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(smithy.has_node("SmithyBedModel"), "smithy bed must instantiate the authored GLB")
	assert_false(smithy.has_node("Frame"), "smithy bed must not keep the stacked-box placeholder")
	var model := smithy.get_node("SmithyBedModel") as Node3D
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	assert_true(meshes.size() > 0, "authored bed GLB needs renderable mesh geometry")
	var bounds := AABB()
	var first := true
	var surface_count := 0
	var triangle_count := 0
	var textured_surface_count := 0
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
				textured_surface_count += 1
	assert_false(first, "bed GLB must expose a non-empty AABB")
	assert_true(bounds.size.x >= 2.3 and bounds.size.x <= 2.45, "bed must preserve the smithy footprint length")
	assert_true(bounds.size.z >= 1.25 and bounds.size.z <= 1.4, "bed must preserve the smithy footprint width")
	assert_true(bounds.size.y >= 1.05 and bounds.size.y <= 1.2, "headboard must have a believable metric height")
	assert_true(bounds.position.y >= -0.001, "bed feet must rest on the prop ground plane")
	assert_eq(surface_count, 5, "bed keeps oak, dark oak, linen, wool, and rope surfaces")
	assert_true(triangle_count >= 3500 and triangle_count <= 6000, "bed detail must stay readable and lightweight")
	assert_true(textured_surface_count >= 3, "oak, linen, and wool albedos must survive GLB import")
	smithy.free()

	var generic := MapViewMeshBuilder.build_prop(
			{"id": &"guest_bed", "kind": MapTypes.PROP_KIND_BED, "position": Vector2.ZERO},
			MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(generic.has_node("Frame"), "non-smithy beds keep their generic fallback")
	assert_false(generic.has_node("SmithyBedModel"), "smithy model must not leak into other maps")
	generic.free()


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


func test_smithy_quench_uses_detailed_metal_glb_without_replacing_generic_fallback() -> void:
	var smithy := MapViewMeshBuilder.build_prop(
			{"id": &"quench", "kind": MapTypes.PROP_KIND_QUENCH, "position": Vector2.ZERO},
			MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(smithy.has_node("SmithyQuenchBucketModel"), "smithy quench must instantiate the authored metal GLB")
	assert_false(smithy.has_node("Bucket"), "smithy quench must not keep the wooden cylinder placeholder")
	var model := smithy.get_node("SmithyQuenchBucketModel") as Node3D
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	assert_true(meshes.size() >= 5, "authored quench bucket needs vessel, fittings, handle, rim, and water geometry")
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
	assert_false(first, "quench bucket GLB must expose a non-empty AABB")
	assert_true(bounds.size.x >= 0.75 and bounds.size.x <= 0.82, "forged ears need a believable bucket width")
	assert_true(bounds.size.y >= 0.84 and bounds.size.y <= 0.90, "raised bail needs a readable metric height")
	assert_true(bounds.size.z >= 0.64 and bounds.size.z <= 0.70, "bucket body needs a believable depth")
	assert_true(bounds.position.y >= -0.001, "quench bucket must rest on the prop ground plane")
	assert_true(triangle_count >= 1800 and triangle_count <= 4000, "quench bucket detail must stay readable and lightweight")
	assert_eq(material_names.size(), 3, "quench bucket keeps aged iron, dark inner iron, and water identities")
	assert_true(has_embedded_albedo, "quench bucket's painted metal wear must survive GLB import")
	smithy.free()

	var generic := MapViewMeshBuilder.build_prop(
			{"id": &"courtyard_quench", "kind": MapTypes.PROP_KIND_QUENCH, "position": Vector2.ZERO},
			MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(generic.has_node("Bucket"), "non-smithy quench props keep their generic fallback")
	assert_true(generic.has_node("Water"), "generic fallback keeps visible water")
	assert_false(generic.has_node("SmithyQuenchBucketModel"), "smithy model must not leak into other maps")
	generic.free()


func test_smithy_furnace_uses_authored_masonry_and_keeps_live_fire() -> void:
	var node := MapViewMeshBuilder.build_prop(
		{"id": &"forge_furnace", "kind": MapTypes.PROP_KIND_FURNACE, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(node.has_node("SmithyFurnaceModel"), "smithy furnace must instantiate the authored GLB")
	assert_false(node.has_node("Mass"), "smithy furnace must not keep the stacked-box masonry")
	for live_node in ["EmberBed", "CoalA", "FlameCore", "FireSparks", "ForgeFireLight"]:
		assert_true(node.has_node(live_node), "authored furnace must retain dynamic %s" % live_node)
	var ember := node.get_node("EmberBed") as MeshInstance3D
	var ember_mat := ember.material_override as StandardMaterial3D
	assert_true(ember_mat != null and ember_mat.emission_enabled, "ember bed must glow")

	var model := node.get_node("SmithyFurnaceModel") as Node3D
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	assert_true(meshes.size() >= 4, "furnace needs masonry, lining, soot, and iron meshes")
	var bounds := AABB()
	var first := true
	var material_names: Dictionary = {}
	var triangle_count := 0
	var textured_surface_count := 0
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
					textured_surface_count += 1
	assert_false(first, "furnace GLB must expose a non-empty AABB")
	assert_true(bounds.size.x >= 2.55 and bounds.size.x <= 2.65, "forge needs a broad masonry front")
	assert_true(bounds.size.y >= 4.0 and bounds.size.y <= 4.15, "chimney needs believable metric height")
	assert_true(bounds.size.z >= 1.65 and bounds.size.z <= 1.75, "forge needs a deep open firebox")
	assert_true(bounds.position.y >= -0.001, "masonry base must rest on the prop ground plane")
	assert_true(triangle_count >= 2400 and triangle_count <= 8000, "furnace detail must stay lightweight")
	assert_eq(material_names.size(), 4, "furnace keeps limestone, firebrick, soot, and iron identities")
	assert_true(textured_surface_count >= 4, "painted furnace albedos must survive GLB import")
	node.free()

	var generic := MapViewMeshBuilder.build_prop(
		{"id": &"courtyard_furnace", "kind": MapTypes.PROP_KIND_FURNACE, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(generic.has_node("Mass"), "non-smithy furnaces keep the procedural fallback")
	assert_false(generic.has_node("SmithyFurnaceModel"), "smithy masonry must not leak to other locations")
	generic.free()


func test_smithy_bellows_uses_authored_leather_mechanism() -> void:
	var node := MapViewMeshBuilder.build_prop(
		{"id": &"forge_bellows", "kind": MapTypes.PROP_KIND_BELLOWS, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(node.has_node("SmithyBellowsModel"), "smithy bellows must instantiate the authored GLB")
	assert_false(node.has_node("BoardBottom"), "smithy bellows must not keep box-fold placeholders")
	var model := node.get_node("SmithyBellowsModel") as Node3D
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	assert_true(meshes.size() >= 3, "bellows need oak, leather, and iron mesh groups")
	var bounds := AABB()
	var first := true
	var material_names: Dictionary = {}
	var triangle_count := 0
	var textured_surface_count := 0
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
					textured_surface_count += 1
	assert_false(first, "bellows GLB must expose a non-empty AABB")
	assert_true(bounds.size.x >= 1.95 and bounds.size.x <= 2.05, "bellows need a long nozzle-to-handle silhouette")
	assert_true(bounds.size.y >= 1.50 and bounds.size.y <= 1.60, "pump lever needs believable working height")
	assert_true(bounds.size.z >= 0.74 and bounds.size.z <= 0.80, "leather chamber needs a broad working width")
	assert_true(bounds.position.y >= -0.001, "bellows stand must rest on the prop ground plane")
	assert_true(triangle_count >= 5000 and triangle_count <= 6500, "leather folds and tacks must stay within budget")
	assert_eq(material_names.size(), 3, "bellows keep oak, leather, and iron identities")
	assert_true(textured_surface_count >= 3, "painted bellows albedos must survive GLB import")
	node.free()

	var generic := MapViewMeshBuilder.build_prop(
		{"id": &"courtyard_bellows", "kind": MapTypes.PROP_KIND_BELLOWS, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(generic.has_node("BoardBottom"), "non-smithy bellows keep the procedural fallback")
	assert_false(generic.has_node("SmithyBellowsModel"), "smithy bellows must not leak to other locations")
	generic.free()


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
