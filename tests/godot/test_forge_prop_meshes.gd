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
			var material := (
				mesh_instance.mesh.surface_get_material(surface_index) as StandardMaterial3D
			)
			if material != null and material.albedo_texture != null:
				textured_surface_count += 1
	assert_false(first, "bed GLB must expose a non-empty AABB")
	assert_true(
		bounds.size.x >= 2.3 and bounds.size.x <= 2.45,
		"bed must preserve the smithy footprint length"
	)
	assert_true(
		bounds.size.z >= 1.25 and bounds.size.z <= 1.4,
		"bed must preserve the smithy footprint width"
	)
	assert_true(
		bounds.size.y >= 1.05 and bounds.size.y <= 1.2,
		"headboard must have a believable metric height"
	)
	assert_true(bounds.position.y >= -0.001, "bed feet must rest on the prop ground plane")
	assert_eq(surface_count, 5, "bed keeps oak, dark oak, linen, wool, and rope surfaces")
	assert_true(
		triangle_count >= 3500 and triangle_count <= 6000,
		"bed detail must stay readable and lightweight"
	)
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
	assert_true(
		smithy.has_node("SmithyChairModel"), "smithy chair must instantiate the authored GLB"
	)
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
			var material := (
				mesh_instance.mesh.surface_get_material(surface_index) as StandardMaterial3D
			)
			if material != null and material.albedo_texture != null:
				has_embedded_albedo = true
	assert_false(first, "chair GLB must expose a non-empty AABB")
	assert_true(
		bounds.size.y >= 1.0 and bounds.size.y <= 1.1,
		"chair must import at believable metric height"
	)
	assert_true(bounds.position.y >= -0.001, "chair feet must rest on the prop ground plane")
	assert_eq(surface_count, 3, "chair detail pass keeps wood, worn wood, and peg surfaces")
	assert_true(
		triangle_count >= 1500 and triangle_count <= 3000,
		"chair detail must stay readable and lightweight"
	)
	assert_true(has_embedded_albedo, "chair's painted oak grain must survive GLB import")
	smithy.free()

	var formal := MapViewMeshBuilder.build_prop(
		{"id": &"burgomaster_chair", "kind": MapTypes.PROP_KIND_CHAIR, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(formal.has_node("Seat"), "non-smithy chairs keep their generic fallback")
	assert_false(formal.has_node("SmithyChairModel"), "smithy model must not leak into Town Hall")
	formal.free()


func test_blacksmith_tongs_use_authored_grounded_pbr_glb() -> void:
	var node := MapViewMeshBuilder.build_prop(
		{
			"id": &"forge_tongs",
			"kind": MapTypes.PROP_KIND_BLACKSMITH_TONGS,
			"position": Vector2.ZERO
		},
		MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(
		node.has_node("BlacksmithTongsModel"), "forge needs independently placeable authored tongs"
	)
	var model := node.get_node("BlacksmithTongsModel") as Node3D
	assert_true(model.get_meta(&"production_medieval_hand_tool", false))
	var bounds := AABB()
	var first := true
	var triangles := 0
	var materials: Dictionary = {}
	var pbr_materials: Dictionary = {}
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var child_bounds := mesh_instance.transform * mesh_instance.get_aabb()
		bounds = child_bounds if first else bounds.merge(child_bounds)
		first = false
		for surface_index in mesh_instance.mesh.get_surface_count():
			triangles += mesh_instance.mesh.surface_get_array_index_len(surface_index) / 3
			var material := (
				mesh_instance.mesh.surface_get_material(surface_index) as StandardMaterial3D
			)
			if material == null:
				continue
			materials[material.resource_name] = true
			if (
				material.albedo_texture != null
				and material.normal_enabled
				and material.normal_texture != null
				and material.roughness_texture != null
			):
				pbr_materials[material.resource_name] = true
	assert_false(first, "tongs GLB must expose render geometry")
	assert_true(
		bounds.size.y >= 0.77 and bounds.size.y <= 0.80, "tongs need long heat-safe handles"
	)
	assert_true(bounds.position.y >= -0.001, "tongs must rest on the prop ground plane")
	assert_eq(triangles, 660, "tongs geometry must stay deterministic and lightweight")
	assert_eq(materials.size(), 2, "tongs keep hammered and polished iron identities")
	assert_eq(pbr_materials.size(), 2, "both iron surfaces need albedo, normal, and roughness maps")
	node.free()


func test_blacksmith_hammer_and_punch_use_independent_grounded_pbr_glbs() -> void:
	var expected := {
		MapTypes.PROP_KIND_BLACKSMITH_HAMMER:
		{
			"node": "BlacksmithHammerModel",
			"height": Vector2(0.34, 0.36),
			"triangles": 368,
			"materials": 3
		},
		MapTypes.PROP_KIND_BLACKSMITH_PUNCH:
		{
			"node": "BlacksmithPunchModel",
			"height": Vector2(0.22, 0.24),
			"triangles": 108,
			"materials": 2
		},
	}
	for kind in expected:
		var node := MapViewMeshBuilder.build_prop(
			{"id": StringName("forge.%s" % kind), "kind": kind, "position": Vector2.ZERO},
			MapTypes.DEFAULT_CELL_SIZE
		)
		var spec: Dictionary = expected[kind]
		var model := node.get_node(String(spec["node"])) as Node3D
		assert_true(model.get_meta(&"production_medieval_hand_tool", false))
		var bounds := AABB()
		var first := true
		var triangles := 0
		var materials: Dictionary = {}
		var pbr_materials: Dictionary = {}
		for child in model.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := child as MeshInstance3D
			if mesh_instance == null or mesh_instance.mesh == null:
				continue
			var child_bounds := mesh_instance.transform * mesh_instance.get_aabb()
			bounds = child_bounds if first else bounds.merge(child_bounds)
			first = false
			for surface_index in mesh_instance.mesh.get_surface_count():
				triangles += mesh_instance.mesh.surface_get_array_index_len(surface_index) / 3
				var material := (
					mesh_instance.mesh.surface_get_material(surface_index) as StandardMaterial3D
				)
				if material != null:
					materials[material.resource_name] = true
					if (
						material.albedo_texture != null
						and material.normal_enabled
						and material.normal_texture != null
						and material.roughness_texture != null
					):
						pbr_materials[material.resource_name] = true
		var height: Vector2 = spec["height"]
		assert_false(first, "%s GLB must expose render geometry" % kind)
		assert_true(
			bounds.size.y >= height.x and bounds.size.y <= height.y,
			"%s needs a plausible metric height" % kind
		)
		assert_true(bounds.position.y >= -0.001, "%s must rest on the ground plane" % kind)
		assert_eq(triangles, spec["triangles"], "%s geometry must stay deterministic" % kind)
		assert_eq(
			materials.size(), spec["materials"], "%s material identities must stay stable" % kind
		)
		assert_eq(
			pbr_materials.size(),
			spec["materials"],
			"%s needs albedo, normal, and roughness on every material" % kind
		)
		var icon := MapPropRenderer.create_prop(
			{"id": StringName("icon.%s" % kind), "kind": kind, "position": Vector2.ZERO}
		)
		assert_true(icon.get_child_count() > 2, "%s needs a readable 2D renderer" % kind)
		icon.free()
		node.free()


func test_smithy_charcoal_uses_authored_dry_sack_storage() -> void:
	var node := MapViewMeshBuilder.build_prop(
		{"id": &"coal_store", "kind": MapTypes.PROP_KIND_CHARCOAL_PILE, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(
		node.has_node("SmithyCharcoalStorageModel"),
		"indoor stock must instantiate the authored GLB"
	)
	assert_false(
		node.has_node("ChunkA"),
		"ambiguous black-lump placeholder must stay retired inside the smithy"
	)
	var model := node.get_node("SmithyCharcoalStorageModel") as Node3D
	assert_true(model.get_meta(&"production_smithy_charcoal_storage_model", false))
	assert_true(
		model.has_node("SmithyCharcoalStorage/Sacks"), "storage needs closed delivery sacks"
	)
	assert_true(
		model.has_node("SmithyCharcoalStorage/OpenSack"), "storage needs one open working sack"
	)
	assert_true(
		model.has_node("SmithyCharcoalStorage/Charcoal"), "open sack needs visible angular charcoal"
	)
	assert_true(model.has_node("SmithyCharcoalStorage/OakDunnage"), "sacks need dry timber dunnage")

	var bounds := AABB()
	var first := true
	var triangle_count := 0
	var material_names: Dictionary = {}
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var child_bounds := mesh_instance.transform * mesh_instance.get_aabb()
		bounds = child_bounds if first else bounds.merge(child_bounds)
		first = false
		for surface_index in mesh_instance.mesh.get_surface_count():
			triangle_count += mesh_instance.mesh.surface_get_array_index_len(surface_index) / 3
			var material := (
				mesh_instance.mesh.surface_get_material(surface_index) as StandardMaterial3D
			)
			if material != null:
				material_names[material.resource_name] = true
				assert_true(
					material.albedo_texture != null, "charcoal storage material needs albedo"
				)
				assert_true(
					material.normal_enabled and material.normal_texture != null,
					"charcoal storage material needs normals"
				)
				assert_true(
					material.roughness_texture != null, "charcoal storage material needs roughness"
				)
	assert_false(first, "charcoal storage GLB must expose render geometry")
	assert_true(
		bounds.size.x >= 1.07 and bounds.size.x <= 1.09, "sacks must fit the one-cell visual width"
	)
	assert_true(
		bounds.size.y >= 0.75 and bounds.size.y <= 0.77, "sacks need believable filled height"
	)
	assert_true(
		bounds.size.z >= 0.77 and bounds.size.z <= 0.79,
		"storage must remain compact in the forge corner"
	)
	assert_true(bounds.position.y >= -0.001, "storage must rest on the ground plane")
	assert_eq(triangle_count, 1392, "authored sack and charcoal cues must stay deterministic")
	assert_eq(material_names.size(), 4, "storage keeps linen, hemp, charcoal, and oak identities")
	node.free()

	var yard := MapViewMeshBuilder.build_prop(
		{
			"id": &"yard_charcoal",
			"kind": MapTypes.PROP_KIND_CHARCOAL_PILE,
			"position": Vector2.ZERO
		},
		MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(
		yard.has_node("ChunkA"), "outdoor service yards keep the procedural bulk-charcoal fallback"
	)
	assert_false(
		yard.has_node("SmithyCharcoalStorageModel"),
		"Kalev's indoor sack model must not leak into yards"
	)
	yard.free()


func test_smithy_anvil_is_a_block_anvil_in_a_hooped_stump() -> void:
	var smithy := _build(&"forge_anvil", MapTypes.PROP_KIND_ANVIL)
	assert_true(
		smithy.has_node("SmithyAnvilModel"), "smithy anvil must instantiate the authored kit GLB"
	)
	assert_false(smithy.has_node("Body"), "smithy anvil must not keep the procedural body")
	var stats := _kit_stats(smithy.get_node("SmithyAnvilModel") as Node3D)
	var bounds: AABB = stats["bounds"]
	# A 14th-century block anvil stands at knuckle height (face ~0.8 m) in its
	# stump; the horned London pattern of the previous model is post-medieval.
	assert_true(
		bounds.end.y >= 0.79 and bounds.end.y <= 0.82, "anvil face sits at working knuckle height"
	)
	assert_true(bounds.position.y >= -0.001, "stump must rest on the prop ground plane")
	assert_true(
		bounds.size.x <= 1.3 and bounds.size.z <= 1.3, "anvil kit stays inside its 3x2 footprint"
	)
	assert_true(
		stats["triangles"] >= 300 and stats["triangles"] <= 1500, "anvil kit stays lightweight"
	)
	for key in ["ksi_iron", "ksi_iron_bright", "ksi_oak"]:
		assert_true(stats["materials"].has(key), "anvil needs %s (block, steel face, stump)" % key)
	_assert_kit_materials(stats, "anvil")
	smithy.free()

	var courtyard := _build(&"courtyard_anvil", MapTypes.PROP_KIND_ANVIL)
	assert_true(courtyard.has_node("Stump"), "outdoor anvil keeps the lightweight procedural stump")
	assert_true(courtyard.has_node("Body"), "outdoor anvil keeps the custom procedural body")
	assert_false(
		courtyard.has_node("SmithyAnvilModel"), "smithy model must not leak into the courtyard"
	)
	assert_true((courtyard.get_node("Body") as MeshInstance3D).mesh is ArrayMesh)
	courtyard.free()


func test_smithy_quench_is_a_coopered_slack_tub() -> void:
	var smithy := _build(&"quench", MapTypes.PROP_KIND_QUENCH)
	assert_true(
		smithy.has_node("SmithyQuenchBucketModel"), "smithy quench must instantiate the slack tub"
	)
	assert_false(
		smithy.has_node("Bucket"), "smithy quench must not keep the wooden cylinder placeholder"
	)
	var stats := _kit_stats(smithy.get_node("SmithyQuenchBucketModel") as Node3D)
	var bounds: AABB = stats["bounds"]
	assert_true(bounds.position.y >= -0.001, "tub must rest on the prop ground plane")
	assert_true(
		bounds.size.x <= 2.0 and bounds.size.z <= 2.0, "tub kit stays inside its 2x2 footprint"
	)
	assert_true(stats["materials"].has("ksi_water"), "slack tub holds visible quench water")
	assert_true(stats["materials"].has("ksi_oak"), "coopered staves are oak")
	assert_true(
		stats["triangles"] >= 400 and stats["triangles"] <= 2000, "tub kit stays lightweight"
	)
	_assert_kit_materials(stats, "slack tub")
	smithy.free()

	var generic := _build(&"courtyard_quench", MapTypes.PROP_KIND_QUENCH)
	assert_true(generic.has_node("Bucket"), "non-smithy quench props keep their generic fallback")
	assert_false(
		generic.has_node("SmithyQuenchBucketModel"), "smithy model must not leak into other maps"
	)
	generic.free()


func test_smithy_furnace_is_a_raised_hearth_under_a_hood_with_live_fire() -> void:
	var node := _build(&"forge_furnace", MapTypes.PROP_KIND_FURNACE)
	assert_true(
		node.has_node("SmithyFurnaceModel"), "smithy furnace must instantiate the raised hearth"
	)
	assert_false(node.has_node("Mass"), "smithy furnace must not keep the stacked-box masonry")
	for live_node in [
		"EmberBed", "CoalA", "ForgeFlames", "FireSparks", "FireSmoke", "ForgeFireLight"
	]:
		assert_true(node.has_node(live_node), "authored hearth must retain dynamic %s" % live_node)
	var ember := node.get_node("EmberBed") as MeshInstance3D
	var ember_mat := ember.material_override as StandardMaterial3D
	assert_true(ember_mat != null and ember_mat.emission_enabled, "ember bed must glow")
	# The fire burns on the waist-high hearth (Haapsalu raised forge), not at
	# floor level: embers, flames and sparks all start in the fire pot.
	var fire := MapViewKalevSmithyInterior.FIRE_POT
	assert_true(ember.position.distance_to(fire) < 0.05, "ember bed sits in the hearth fire pot")
	assert_true(ember.position.y > 0.6, "raised hearth keeps the fire at working height")
	var flames := node.get_node("ForgeFlames") as Node3D
	assert_true(flames.position.y > fire.y, "flames rise from the fire pot")
	var outer := flames.get_node("OuterFlames") as GPUParticles3D
	assert_true(
		outer != null and outer.emitting, "hearth flame must be an emitting particle system"
	)
	var smoke := node.get_node("FireSmoke") as GPUParticles3D
	assert_true(
		smoke != null and smoke.emitting, "hearth needs a rising smoke column into the hood"
	)

	var stats := _kit_stats(node.get_node("SmithyFurnaceModel") as Node3D)
	var bounds: AABB = stats["bounds"]
	assert_true(bounds.position.y >= -0.001, "hearth must rest on the prop ground plane")
	assert_true(
		bounds.size.x >= 2.0 and bounds.size.x <= 3.0,
		"hearth is ~2 m wide (dossier 1.6-2.0 m plus hood)"
	)
	assert_true(
		(
			bounds.end.y
			> MapViewMeshBuilder.interior_shell_wall_height_world(KalevSmithyDefinition.create())
		),
		"flue must pass through the loft"
	)
	assert_true(bounds.position.z >= -1.51, "hearth backs onto the north wall face, not into it")
	for key in ["ksi_limestone", "ksi_clay", "ksi_oak", "ksi_iron"]:
		assert_true(stats["materials"].has(key), "hearth needs %s" % key)
	assert_true(
		stats["triangles"] >= 1000 and stats["triangles"] <= 5000,
		"hearth detail must stay lightweight"
	)
	_assert_kit_materials(stats, "hearth")
	node.free()

	var generic := _build(&"courtyard_furnace", MapTypes.PROP_KIND_FURNACE)
	assert_true(generic.has_node("Mass"), "non-smithy furnaces keep the procedural fallback")
	assert_false(
		generic.has_node("SmithyFurnaceModel"), "smithy hearth must not leak to other locations"
	)
	generic.free()


func test_smithy_bellows_are_great_bellows_aimed_at_the_tuyere() -> void:
	var node := _build(&"forge_bellows", MapTypes.PROP_KIND_BELLOWS)
	assert_true(
		node.has_node("SmithyBellowsModel"), "smithy bellows must instantiate the authored kit GLB"
	)
	assert_false(node.has_node("BoardBottom"), "smithy bellows must not keep box-fold placeholders")
	var stats := _kit_stats(node.get_node("SmithyBellowsModel") as Node3D)
	var bounds: AABB = stats["bounds"]
	assert_true(bounds.position.y >= -0.001, "trestle must rest on the prop ground plane")
	assert_true(bounds.size.y >= 1.7 and bounds.size.y <= 2.1, "rocker pole needs working height")
	# The nozzle reaches the hearth's west-cheek tuyere, 1.85 m east of the
	# 3x2 bellows footprint centre (rrmap forge_bellows at 16,2).
	assert_true(bounds.end.x >= 1.8 and bounds.end.x <= 1.9, "nozzle must meet the hearth tuyere")
	for key in ["ksi_oak", "ksi_leather", "ksi_iron"]:
		assert_true(stats["materials"].has(key), "bellows need %s" % key)
	assert_true(
		stats["triangles"] >= 1200 and stats["triangles"] <= 4000,
		"pleats and tacks stay within budget"
	)
	_assert_kit_materials(stats, "bellows")
	node.free()

	var generic := _build(&"courtyard_bellows", MapTypes.PROP_KIND_BELLOWS)
	assert_true(generic.has_node("BoardBottom"), "non-smithy bellows keep the procedural fallback")
	assert_false(
		generic.has_node("SmithyBellowsModel"), "smithy bellows must not leak to other locations"
	)
	generic.free()


func test_smithy_stock_rack_and_scrap_heap_replace_generic_storage() -> void:
	var rack := _build(&"tool_shelf", MapTypes.PROP_KIND_SHELF)
	assert_true(rack.has_node("SmithyStockRackModel"), "tool_shelf becomes the iron stock rack")
	var rack_stats := _kit_stats(rack.get_node("SmithyStockRackModel") as Node3D)
	assert_true((rack_stats["bounds"] as AABB).position.y >= -0.001, "rack stands on the floor")
	assert_true(rack_stats["materials"].has("ksi_iron"), "rack carries bar iron")
	_assert_kit_materials(rack_stats, "stock rack")
	rack.free()
	var scrap := _build(&"iron_scrap_store", MapTypes.PROP_KIND_IRON_SCRAP_PILE)
	assert_true(scrap.has_node("SmithyScrapHeapModel"), "iron_scrap_store becomes the scrap crate")
	assert_false(scrap.has_node("PlateA"), "scrap crate retires the primitive plates")
	var scrap_stats := _kit_stats(scrap.get_node("SmithyScrapHeapModel") as Node3D)
	var scrap_bounds: AABB = scrap_stats["bounds"]
	assert_true(
		scrap_bounds.size.x <= 1.0 and scrap_bounds.size.z <= 1.0, "scrap crate fits its one cell"
	)
	_assert_kit_materials(scrap_stats, "scrap heap")
	scrap.free()
	for generic_spec in [
		[&"market_shelf", MapTypes.PROP_KIND_SHELF, "SmithyStockRackModel"],
		[&"yard_scrap", MapTypes.PROP_KIND_IRON_SCRAP_PILE, "SmithyScrapHeapModel"]
	]:
		var generic := _build(generic_spec[0], generic_spec[1])
		assert_false(
			generic.has_node(String(generic_spec[2])),
			"smithy kit must not leak into %s" % generic_spec[0]
		)
		generic.free()


func _build(prop_id: StringName, kind: StringName) -> Node3D:
	return MapViewMeshBuilder.build_prop(
		{"id": prop_id, "kind": kind, "position": Vector2.ZERO}, MapTypes.DEFAULT_CELL_SIZE
	)


## Bounds, triangle count and applied `ksi_*` override materials of a kit model.
func _kit_stats(model: Node3D) -> Dictionary:
	var bounds := AABB()
	var first := true
	var triangles := 0
	var materials: Dictionary = {}
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var child_bounds := mesh_instance.transform * mesh_instance.get_aabb()
		bounds = child_bounds if first else bounds.merge(child_bounds)
		first = false
		for surface in mesh_instance.mesh.get_surface_count():
			triangles += mesh_instance.mesh.surface_get_array_index_len(surface) / 3
			var material := mesh_instance.get_surface_override_material(surface)
			if material != null:
				materials[String(material.resource_name)] = material
	assert_false(first, "kit model must expose render geometry")
	return {"bounds": bounds, "triangles": triangles, "materials": materials}


## Every surface is remapped to a shared smithy material that reads COLOR_0
## soot/wear; wood and masonry carry photoreal plates with normal maps.
func _assert_kit_materials(stats: Dictionary, label: String) -> void:
	var materials: Dictionary = stats["materials"]
	assert_true(materials.size() >= 2, "%s needs several material identities" % label)
	for key in materials:
		var material := materials[key] as StandardMaterial3D
		assert_true(
			String(key).begins_with("ksi_"),
			"%s surface %s must use the smithy kit material" % [label, key]
		)
		assert_true(
			material.vertex_color_use_as_albedo,
			"%s %s must read baked soot and wear" % [label, key]
		)
		assert_ne(
			material.shading_mode,
			BaseMaterial3D.SHADING_MODE_UNSHADED,
			"%s %s must react to light" % [label, key]
		)
		if key in ["ksi_oak", "ksi_limestone", "ksi_boards", "ksi_clay"]:
			assert_true(
				material.albedo_texture != null, "%s %s needs a photoreal plate" % [label, key]
			)
			assert_true(
				material.normal_enabled and material.normal_texture != null,
				"%s %s needs relief" % [label, key]
			)


func test_enclosed_interior_skips_outdoor_scatter() -> void:
	var definition := KalevSmithyDefinition.create()
	assert_true(
		definition.suppresses_exterior_surroundings(), "smithy must be an enclosed interior"
	)
	var grid := MapBuilder.build(definition)
	var scatter := MapViewMeshBuilder.build_scatter(definition, grid)
	assert_eq(scatter.get_child_count(), 0, "smithy floors must not grow grass or stone clutter")
	scatter.free()
