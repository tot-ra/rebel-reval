extends "res://tests/godot/test_case.gd"

## Cloned production houses must not keep one shared wall/roof albedo.

const SurfaceVariety := preload(
	"res://scripts/map/view3d/map_view_burgher_house_surface_variety.gd"
)
const StoneModels := preload("res://scripts/map/view3d/map_view_burgher_house_stone_models.gd")


func test_surface_recipes_are_stable_and_diverge_across_ids() -> void:
	var first := SurfaceVariety.recipe_for(&"vene_row_house")
	var again := SurfaceVariety.recipe_for(&"vene_row_house")
	var neighbor := SurfaceVariety.recipe_for(&"market_row_house")
	assert_eq(first["seed"], again["seed"], "recipe must be stable for one building id")
	assert_eq(first["wall_roll"], again["wall_roll"])
	assert_eq(first["roof_roll"], again["roof_roll"])
	assert_true(
		first["wall_roll"] != neighbor["wall_roll"]
		or first["roof_roll"] != neighbor["roof_roll"]
		or first["wall_tint"] != neighbor["wall_tint"]
		or first["roof_tint"] != neighbor["roof_tint"]
		or first["uv_offset"] != neighbor["uv_offset"],
		"adjacent ordinary ids must not share one wall/roof recipe"
	)


func test_variant_texture_paths_exist_for_every_family() -> void:
	var families: Array[StringName] = [
		SurfaceVariety.FAMILY_TILE,
		SurfaceVariety.FAMILY_SHINGLE,
		SurfaceVariety.FAMILY_THATCH,
		SurfaceVariety.FAMILY_RUBBLE,
		SurfaceVariety.FAMILY_RENDER,
		SurfaceVariety.FAMILY_LIMEWASH,
		SurfaceVariety.FAMILY_LOG,
	]
	for family in families:
		for roll in 3:
			var albedo := SurfaceVariety.albedo_path(family, roll)
			var normal := SurfaceVariety.normal_path(family, roll)
			assert_true(ResourceLoader.exists(albedo), "missing wall/roof albedo %s" % albedo)
			assert_true(ResourceLoader.exists(normal), "missing wall/roof normal %s" % normal)


func test_cloned_stone_houses_override_shared_roof_and_wall_maps() -> void:
	var left := _build_stone(&"cloned_stone_left")
	var right := _build_stone(&"cloned_stone_right")
	var left_model := left.get_node("ProductionMerchantStone") as Node3D
	var right_model := right.get_node("ProductionMerchantStone") as Node3D
	assert_eq(left_model.get_meta(&"house_variant"), right_model.get_meta(&"house_variant"))
	var left_maps := _collect_overridden_maps(left_model)
	var right_maps := _collect_overridden_maps(right_model)
	assert_true(left_maps["wall"].size() >= 1, "stone walls must receive a surface override")
	assert_true(left_maps["roof"].size() >= 1, "stone roofs must receive a surface override")
	var left_recipe: Dictionary = left_model.get_meta(&"house_surface_recipe")
	var right_recipe: Dictionary = right_model.get_meta(&"house_surface_recipe")
	assert_true(
		left_maps["wall"] != right_maps["wall"]
		or left_maps["roof"] != right_maps["roof"]
		or left_recipe["wall_tint"] != right_recipe["wall_tint"]
		or left_recipe["roof_tint"] != right_recipe["roof_tint"]
		or left_recipe["uv_offset"] != right_recipe["uv_offset"],
		"same-mesh stone clones must not share one wall/roof treatment"
	)
	var imported := (
		(load(String(StoneModels.MERCHANT_STONE_VARIANTS[0]["path"])) as PackedScene)
		.instantiate() as Node3D
	)
	_assert_imported_materials_untinted(imported)
	imported.free()
	left.free()
	right.free()


func test_classify_reads_kit_material_names() -> void:
	var tile := StandardMaterial3D.new()
	tile.resource_name = "MerchantStoneClayTile"
	assert_eq(SurfaceVariety.classify(tile), SurfaceVariety.FAMILY_TILE)
	var thatch := StandardMaterial3D.new()
	thatch.resource_name = "CraftBodaReedThatch"
	assert_eq(SurfaceVariety.classify(thatch), SurfaceVariety.FAMILY_THATCH)
	var log_wall := StandardMaterial3D.new()
	log_wall.resource_name = "CraftBodaLog"
	assert_eq(SurfaceVariety.classify(log_wall), SurfaceVariety.FAMILY_LOG)
	var iron := StandardMaterial3D.new()
	iron.resource_name = "MerchantTimberWroughtIron"
	assert_eq(SurfaceVariety.classify(iron), &"")


func _build_stone(building_id: StringName) -> Node3D:
	return MapViewMeshBuilder.build_building(
		{
			"id": building_id,
			"kind": MapTypes.BUILDING_KIND_HOUSE,
			"house_tier": &"merchant_stone",
			"footprint": Rect2(0.0, 0.0, 9.0 * 32.0, 8.0 * 32.0),
			"wall_height": 112.0,
			"door_side": &"south",
		},
		MapTypes.DEFAULT_CELL_SIZE
	)


func _collect_overridden_maps(model: Node) -> Dictionary:
	var maps := {"wall": {}, "roof": {}}
	_walk_overrides(model, maps)
	return maps


func _walk_overrides(model: Node, maps: Dictionary) -> void:
	var mesh_instance := model as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_surface_override_material(surface)
			var standard := material as StandardMaterial3D
			if standard == null or standard.albedo_texture == null:
				continue
			var family := SurfaceVariety.classify(standard)
			if family == &"":
				family = SurfaceVariety.classify(
					mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
				)
			if family == &"":
				continue
			var bucket: String = "roof" if SurfaceVariety.is_roof_family(family) else "wall"
			maps[bucket][standard.albedo_texture] = true
	for child in model.get_children():
		_walk_overrides(child, maps)


func _assert_imported_materials_untinted(model: Node) -> void:
	var mesh_instance := model as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if material != null:
				assert_eq(
					mesh_instance.get_surface_override_material(surface),
					null,
					"fresh kit instance must keep shared materials until dressed"
				)
				assert_true(
					material.albedo_color.is_equal_approx(Color.WHITE)
					or material.albedo_color.a > 0.0,
					"shared kit albedo must stay on the imported material"
				)
	for child in model.get_children():
		_assert_imported_materials_untinted(child)
