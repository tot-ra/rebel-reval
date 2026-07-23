extends "res://tests/godot/map_view_3d_test_base.gd"

## P0-053: both playable slice maps must render textured procedural surfaces,
## not flat placeholder colors, on ground and authored building meshes.


func test_kalev_smithy_interior_walls_use_weathered_textures() -> void:
	MapViewMaterials.reset()
	var definition := KalevSmithyDefinition.create()
	var textures: Dictionary = {}
	for building in definition.buildings:
		if building.get("kind", &"") != MapTypes.BUILDING_KIND_INTERIOR_WALL:
			continue
		var node := MapViewMeshBuilder.build_building(building, definition.cell_size)
		var walls := node.get_node("Walls") as MeshInstance3D
		var material := walls.material_override as StandardMaterial3D
		assert_true(material != null, "%s: interior wall needs a material override" % building["id"])
		assert_true(
			material.albedo_texture != null,
			"%s: interior wall must use a procedural albedo texture" % building["id"]
		)
		assert_true(material.uv1_triplanar, "%s: interior wall keeps triplanar projection" % building["id"])
		assert_false(
			textures.has(material.albedo_texture),
			"%s: interior walls must not share one baked albedo map" % building["id"]
		)
		textures[material.albedo_texture] = building["id"]
		node.free()
	assert_true(textures.size() >= 3, "smithy interior must expose multiple distinct wall textures")


func test_kalev_smithy_ceiling_uses_textured_planks() -> void:
	MapViewMaterials.reset()
	var definition := KalevSmithyDefinition.create()
	var view := MapView3D.create(definition, MapBuilder.build(definition))
	var ceiling := view.get_node("InteriorShell/Ceiling") as MeshInstance3D
	assert_true(ceiling != null, "smithy needs a first-person ceiling shell")
	var material := ceiling.material_override as StandardMaterial3D
	assert_true(material != null, "ceiling needs a material override")
	assert_true(material.albedo_texture != null, "ceiling planks must use procedural texture detail")
	view.free()


func test_slice_maps_ground_uses_textured_splat_shader() -> void:
	for definition in [KalevSmithyDefinition.create(), LowerTownSlice.create()]:
		var view := MapView3D.create(definition, MapBuilder.build(definition))
		var ground := view.get_node("Terrain/Terrain_Ground") as MeshInstance3D
		assert_true(ground != null, "%s: playable slice needs a ground mesh" % definition.map_id)
		assert_true(
			ground.material_override is ShaderMaterial,
			"%s: ground must use the blended terrain splat shader" % definition.map_id
		)
		var shader_mat := ground.material_override as ShaderMaterial
		assert_true(
			shader_mat.get_shader_parameter("cobble_surface") != null,
			"%s: ground shader must bind the high-resolution cobble texture" % definition.map_id
		)
		view.free()


func test_slice_maps_have_no_untextured_building_walls() -> void:
	MapViewMaterials.reset()
	for definition in [KalevSmithyDefinition.create(), LowerTownSlice.create()]:
		for building in definition.buildings:
			var kind: StringName = building.get("kind", MapTypes.BUILDING_KIND_HOUSE)
			if kind not in [
				MapTypes.BUILDING_KIND_HOUSE,
				MapTypes.BUILDING_KIND_INTERIOR_WALL,
				MapTypes.BUILDING_KIND_WALL,
			]:
				continue
			var node := MapViewMeshBuilder.build_building(building, definition.cell_size)
			var walls := node.get_node_or_null("Walls") as MeshInstance3D
			if walls == null:
				node.free()
				continue
			var material := walls.material_override
			if material is StandardMaterial3D:
				assert_true(
					(material as StandardMaterial3D).albedo_texture != null,
					"%s/%s: wall surface must carry procedural albedo detail" % [definition.map_id, building["id"]]
				)
			node.free()
