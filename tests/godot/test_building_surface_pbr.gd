extends "res://tests/godot/test_case.gd"

## AR-03 (R-961): building wall and roof surfaces use the shared PBR library
## (albedo + normal + packed ORM roughness/AO) with a toggleable anti-tiling
## detail blend, instead of a tint over a procedural pattern at roughness 1.0.

const BuildingMaterials := preload("res://scripts/map/view3d/map_view_building_materials.gd")
const SurfaceLibrary := preload(
	"res://scripts/map/view3d/map_view_burgher_house_surface_variety.gd"
)
const LowerTownSlice := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const MapViewMeshBuilder := preload("res://scripts/map/view3d/map_view_mesh_builder.gd")
const MAPS_DIR := "res://content/maps"

## Distinct Walls/Roof override materials on lower_town_slice, measured as 113
## both before and after AR-03 (the library shares textures, not materials).
## AR-02 has not set an ADR budget yet, so hold the pre-AR-03 count.
const LOWER_TOWN_BUILDING_MATERIAL_BUDGET := 113


func after_each() -> void:
	super()
	BuildingMaterials.set_anti_tiling_enabled(true)
	BuildingMaterials.set_map_seed(0)
	MapViewMaterials.reset()


func test_every_authored_material_key_resolves_to_a_full_surface_set() -> void:
	var keys := _authored_material_keys()
	assert_true(keys["wall"].size() >= 5, "authored maps must expose wall_material keys")
	assert_true(keys["roof"].size() >= 3, "authored maps must expose roof_material keys")
	for is_roof in [false, true]:
		var bucket: String = "roof" if is_roof else "wall"
		for key in keys[bucket]:
			var stem: String = SurfaceLibrary.library_stem(StringName(key), is_roof, &"probe", 0)
			assert_false(stem.is_empty(), "%s_material=%s has no library surface set" % [bucket, key])
			if stem.is_empty():
				continue
			var paths: Dictionary = SurfaceLibrary.stem_paths(stem)
			for channel in ["albedo", "normal", "orm"]:
				assert_true(
					ResourceLoader.exists(paths[channel]),
					"%s is missing its %s map" % [stem, channel]
				)


func test_every_library_family_ships_three_complete_stems() -> void:
	for family in SurfaceLibrary.FAMILY_PLATE_METRES:
		var stems: Array[String] = SurfaceLibrary.stems_for(family)
		assert_eq(stems.size(), 3, "%s must ship three stems" % family)
		for stem in stems:
			var paths: Dictionary = SurfaceLibrary.stem_paths(stem)
			for channel in ["albedo", "normal", "orm"]:
				assert_true(ResourceLoader.exists(paths[channel]), "%s %s" % [stem, channel])


func test_building_materials_carry_roughness_and_ao_maps_not_constant_roughness() -> void:
	MapViewMaterials.reset()
	var size := Vector3(4.0, 3.0, 5.0)
	var color := Color8(180, 157, 119)
	for family in [&"limestone", &"plaster", &"log", &"plank", &"brick", &"timber", &"smoked_plaster"]:
		var wall := MapViewMaterials.wall_surface_for_building(
			StringName("pbr.%s" % family), family, color, size
		)
		_assert_library_material(wall, "wall %s" % family)
	for family in [&"tile", &"shingle", &"thatch", &"straw"]:
		var roof := MapViewMaterials.roof_surface_for_building(
			StringName("pbr.%s" % family), family, Color8(112, 83, 56)
		)
		_assert_library_material(roof, "roof %s" % family)


func test_lower_town_buildings_never_fall_back_to_flat_procedural_surfaces() -> void:
	MapViewMaterials.reset()
	var definition := LowerTownSlice.create()
	var checked := 0
	var materials: Dictionary = {}
	for building in definition.buildings:
		var node := MapViewMeshBuilder.build_building(building, definition.cell_size)
		for part in ["Walls", "Roof"]:
			var mesh := node.get_node_or_null(part) as MeshInstance3D
			if mesh == null:
				continue
			var material := mesh.material_override as StandardMaterial3D
			if material == null:
				continue
			materials[material] = true
			var authored_key := "wall_material" if part == "Walls" else "roof_material"
			if not building.has(authored_key):
				continue
			checked += 1
			_assert_library_material(material, "%s %s" % [building["id"], part])
		node.free()
	assert_true(checked >= 50, "Lower Town must exercise authored wall/roof keys (%d)" % checked)
	assert_true(
		materials.size() <= LOWER_TOWN_BUILDING_MATERIAL_BUDGET,
		"lower_town_slice building materials %d exceed budget %d"
		% [materials.size(), LOWER_TOWN_BUILDING_MATERIAL_BUDGET]
	)


func test_stem_selection_is_deterministic_per_map_seed_and_building() -> void:
	var ids: Array[StringName] = []
	for index in 24:
		ids.append(StringName("house.%02d" % index))
	var changed := 0
	for id in ids:
		var first: String = SurfaceLibrary.library_stem(&"plaster", false, id, 7)
		assert_eq(first, SurfaceLibrary.library_stem(&"plaster", false, id, 7), "%s stem stable" % id)
		if first != SurfaceLibrary.library_stem(&"plaster", false, id, 8):
			changed += 1
	assert_true(changed > 0, "a different map seed must reshuffle some stems")


func test_map_seed_reaches_building_materials() -> void:
	var size := Vector3(4.0, 3.0, 5.0)
	var id := &"seeded.house"
	BuildingMaterials.set_map_seed(3)
	var material := MapViewMaterials.wall_surface_for_building(id, &"plaster", Color.WHITE, size)
	assert_eq(
		String(material.get_meta(BuildingMaterials.LIBRARY_STEM_META)),
		SurfaceLibrary.library_stem(&"plaster", false, id, 3)
	)


func test_limestone_ecclesiastical_fabric_is_ashlar_and_houses_are_rubble() -> void:
	var church: String = SurfaceLibrary.library_stem(&"limestone", false, &"st_catherines_church", 0)
	var house: String = SurfaceLibrary.library_stem(&"limestone", false, &"viru_house_stone", 0)
	assert_eq(SurfaceLibrary.family_of_stem(church), SurfaceLibrary.FAMILY_ASHLAR)
	assert_eq(SurfaceLibrary.family_of_stem(house), SurfaceLibrary.FAMILY_RUBBLE)


func test_anti_tiling_detail_blend_toggles() -> void:
	MapViewMaterials.reset()
	var material := MapViewMaterials.wall_surface_for_building(
		&"tiling.house", &"limestone", Color.WHITE, Vector3(12.0, 4.0, 6.0)
	)
	assert_true(material.detail_enabled, "anti-tiling is on by default")
	assert_true(material.detail_albedo != null, "anti-tiling needs the macro plate")
	assert_eq(material.detail_uv_layer, BaseMaterial3D.DETAIL_UV_2)
	assert_true(material.uv2_world_triplanar, "macro plate must be world-space")
	var lifted := material.albedo_color
	BuildingMaterials.set_anti_tiling_enabled(false)
	assert_false(material.detail_enabled, "toggle must reach cached materials")
	assert_true(material.albedo_color.r < lifted.r, "exposure lift must drop with the blend")
	BuildingMaterials.set_anti_tiling_enabled(true)
	assert_true(material.detail_enabled)
	assert_true(material.albedo_color.is_equal_approx(lifted))


func test_box_uv_scale_matches_plate_metres_through_the_box_atlas() -> void:
	# A 1.2 m brick plate on a wall 12 m wide should repeat 10 times per face;
	# BoxMesh gives each face a third of U, so uv1_scale.x must be 30.
	var width_units := 12.0 / BuildingMaterials.METERS_PER_WORLD_UNIT
	var scale := BuildingMaterials.library_box_uv_scale(
		"brick_red", Vector3(width_units, width_units, width_units)
	)
	assert_almost_eq(scale.x, 30.0, 0.01)
	assert_almost_eq(scale.y, 20.0, 0.01)


func test_interior_wall_triplanar_density_is_independent_of_wall_length() -> void:
	MapViewMaterials.reset()
	var building := {"id": &"r997.interior", "wall_material": &"plaster"}
	var color := Color8(180, 157, 119)
	var short := MapViewMeshBuilderBuildingInteriorWalls.interior_wall_material(
		building, color, Vector3(2.0, 2.4, 0.2)
	)
	var long := MapViewMeshBuilderBuildingInteriorWalls.interior_wall_material(
		building, color, Vector3(18.0, 2.4, 0.2)
	)
	assert_true(short.uv1_triplanar, "interior walls stay triplanar")
	assert_true(
		short.has_meta(BuildingMaterials.LIBRARY_STEM_META),
		"plaster interior walls use the AR-03 library"
	)
	var stem := String(short.get_meta(BuildingMaterials.LIBRARY_STEM_META))
	var expected := BuildingMaterials.library_world_uv_density(stem)
	assert_true(
		short.uv1_scale.is_equal_approx(expected),
		"short interior wall must use plate-metre triplanar density"
	)
	assert_true(
		long.uv1_scale.is_equal_approx(short.uv1_scale),
		"interior wall density must not grow with wall length"
	)
	var box_scale := BuildingMaterials.library_box_uv_scale(stem, Vector3(18.0, 2.4, 0.2))
	assert_false(
		long.uv1_scale.is_equal_approx(box_scale),
		"triplanar interiors must drop the BoxMesh 3x2 atlas scale"
	)


func test_interior_wall_fallback_density_ignores_wall_length() -> void:
	MapViewMaterials.reset()
	var building := {"id": &"r997.fallback", "wall_material": &"unknown_interior_family"}
	var color := Color8(180, 157, 119)
	var short := MapViewMeshBuilderBuildingInteriorWalls.interior_wall_material(
		building, color, Vector3(2.0, 2.4, 0.2)
	)
	var long := MapViewMeshBuilderBuildingInteriorWalls.interior_wall_material(
		building, color, Vector3(18.0, 2.4, 0.2)
	)
	assert_false(
		short.has_meta(BuildingMaterials.LIBRARY_STEM_META),
		"unknown families stay on the procedural fallback"
	)
	var expected := MapViewMaterials.building_uv_density(BuildingMaterials.PATTERN_PLASTER)
	assert_true(short.uv1_scale.is_equal_approx(expected), "fallback uses plaster density")
	assert_true(
		long.uv1_scale.is_equal_approx(short.uv1_scale),
		"fallback density must not grow with wall length"
	)


func _assert_library_material(material: StandardMaterial3D, label: String) -> void:
	assert_true(material != null, "%s needs a material" % label)
	if material == null:
		return
	assert_true(
		material.has_meta(BuildingMaterials.LIBRARY_STEM_META),
		"%s fell back to the flat procedural surface" % label
	)
	assert_true(
		material.albedo_texture != null
		and material.albedo_texture.resource_path.contains("building_variants"),
		"%s needs a library albedo" % label
	)
	assert_true(material.normal_enabled and material.normal_texture != null, "%s normal" % label)
	assert_true(material.roughness_texture != null, "%s needs a roughness map" % label)
	assert_eq(
		material.roughness_texture_channel,
		BaseMaterial3D.TEXTURE_CHANNEL_GREEN,
		"%s roughness reads ORM green" % label
	)
	assert_true(material.ao_enabled and material.ao_texture != null, "%s needs AO" % label)


func _authored_material_keys() -> Dictionary:
	var keys := {"wall": {}, "roof": {}}
	var pattern := RegEx.new()
	pattern.compile("(wall|roof)_material=([a-z_]+)")
	for file_name in DirAccess.get_files_at(MAPS_DIR):
		if not file_name.ends_with(".rrmap"):
			continue
		var text := FileAccess.get_file_as_string("%s/%s" % [MAPS_DIR, file_name])
		for match_result in pattern.search_all(text):
			keys[match_result.get_string(1)][match_result.get_string(2)] = true
	return {"wall": keys["wall"].keys(), "roof": keys["roof"].keys()}


func test_library_roof_plates_keep_real_cover_sizes() -> void:
	# Painter counts per plate: shingle 7 x 10, tile 8 lanes x 9 courses, reed
	# thatch 6 courses, straw 8 courses (tools/burgher_house_kit_common.py).
	var plates := SurfaceLibrary.FAMILY_PLATE_METRES
	var shingle: Vector2 = plates[SurfaceLibrary.FAMILY_SHINGLE]
	var tile: Vector2 = plates[SurfaceLibrary.FAMILY_TILE]
	var thatch: Vector2 = plates[SurfaceLibrary.FAMILY_THATCH]
	var straw: Vector2 = plates[SurfaceLibrary.FAMILY_STRAW]
	assert_true(shingle.x / 7.0 >= 0.10 and shingle.x / 7.0 <= 0.15, "shingle width")
	assert_true(shingle.y / 10.0 >= 0.18 and shingle.y / 10.0 <= 0.22, "shingle course")
	assert_true(tile.x / 8.0 >= 0.15 and tile.x / 8.0 <= 0.22, "tile lane width")
	assert_true(tile.y / 9.0 >= 0.22 and tile.y / 9.0 <= 0.28, "tile course")
	assert_true(thatch.y / 6.0 >= 0.25 and thatch.y / 6.0 <= 0.30, "reed thatch course")
	assert_true(straw.y / 8.0 >= 0.2 and straw.y / 8.0 <= 0.3, "straw thatch course")
