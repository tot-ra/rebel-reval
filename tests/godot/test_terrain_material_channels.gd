extends "res://tests/godot/test_case.gd"

## CO-01 (R-948): the coastal ground families ship full PBR sets and the blend
## shader samples them per fragment, not per subdivision vertex.

const TerrainMaterials := preload("res://scripts/map/view3d/map_view_terrain_materials.gd")
const FAMILIES: Array[StringName] = [&"sand", &"coast_sand", &"mud", &"grass", &"shore_shingle"]


func after_each() -> void:
	MapViewMaterials.reset()
	super.after_each()


func test_every_ground_family_resolves_albedo_normal_and_roughness() -> void:
	for family in FAMILIES:
		assert_true(TerrainMaterials.has_ground_family(family), "%s ships all maps" % family)
		var albedo := _texture(family, &"albedo")
		assert_true(
			albedo.get_width() >= TerrainMaterials.GROUND_ALBEDO_TEXTURE_SIZE,
			"%s albedo is at least 2048 px" % family
		)
		assert_eq(albedo.get_width(), albedo.get_height(), "%s albedo is square" % family)
		for map_type: StringName in [&"normal", &"roughness"]:
			var texture := _texture(family, map_type)
			assert_true(
				texture.get_width() >= TerrainMaterials.GROUND_SURFACE_TEXTURE_SIZE,
				"%s %s is at least 1024 px" % [family, map_type]
			)


func test_ground_arrays_have_one_layer_per_family_in_stable_order() -> void:
	assert_eq(
		TerrainMaterials.GROUND_FAMILIES,
		[&"grass", &"mud", &"sand", &"coast_sand", &"shore_shingle"] as Array[StringName],
		"shader layer indices 0..4 depend on this order"
	)
	for map_type in TerrainMaterials.GROUND_MAP_TYPES:
		var array := TerrainMaterials.ground_texture_array(map_type)
		assert_true(array != null, "%s array builds" % map_type)
		assert_eq(array.get_layers(), TerrainMaterials.GROUND_FAMILIES.size(), String(map_type))
	assert_eq(
		TerrainMaterials.ground_texture_array(&"albedo").get_width(),
		TerrainMaterials.GROUND_ALBEDO_TEXTURE_SIZE
	)
	assert_eq(
		TerrainMaterials.ground_texture_array(&"normal").get_width(),
		TerrainMaterials.GROUND_SURFACE_TEXTURE_SIZE
	)


func test_ground_imports_share_one_format_per_map_type() -> void:
	# Texture2DArray needs matching layers; a sidecar edited to another format
	# would push every map load onto the slow conversion path.
	for map_type in TerrainMaterials.GROUND_MAP_TYPES:
		var first := _texture(FAMILIES[0], map_type).get_image()
		for family in FAMILIES:
			var image := _texture(family, map_type).get_image()
			assert_eq(image.get_format(), first.get_format(), "%s %s format" % [family, map_type])
			assert_eq(image.get_size(), first.get_size(), "%s %s size" % [family, map_type])
			assert_true(image.has_mipmaps(), "%s %s has mipmaps" % [family, map_type])


func test_sand_terrains_no_longer_resolve_to_the_speckle_pattern() -> void:
	for terrain_id: StringName in [MapTypes.TERRAIN_SAND, MapTypes.TERRAIN_COAST_SAND]:
		assert_true(
			TerrainMaterials.TERRAIN_PATTERN[terrain_id] != MapViewMaterials.PATTERN_SPECKLE,
			"%s must not fall back to the procedural speckle" % terrain_id
		)
		var material := MapViewMaterials.terrain(terrain_id, 17)
		assert_true(material.albedo_texture is CompressedTexture2D, "%s binds its plate" % terrain_id)
		assert_true(material.normal_enabled and material.normal_texture != null, String(terrain_id))
		assert_true(material.roughness_texture != null, String(terrain_id))
		assert_true(
			TerrainMaterials.terrain_bake_requests(terrain_id, 17).is_empty(),
			"authored sand needs no procedural bake"
		)


func test_blended_ground_binds_arrays_and_enables_authored_families() -> void:
	var material := MapViewMaterials.blended_ground(731)
	for map_type: String in ["albedo", "normal", "roughness"]:
		assert_true(
			material.get_shader_parameter("ground_%s" % map_type) is Texture2DArray,
			"ground_%s array is bound" % map_type
		)
	for flag: String in [
		"use_authored_mud", "use_authored_sand", "use_authored_coast_sand", "use_authored_shingle"
	]:
		assert_eq(material.get_shader_parameter(flag), 1.0, flag)
	assert_eq(
		material.get_shader_parameter("sand_layer"),
		MapViewMaterials.terrain_blend_index(MapTypes.TERRAIN_SAND),
		"WS-08 wet sand still targets the sand layer"
	)


func test_authored_plates_are_sampled_per_fragment() -> void:
	var code := MapViewMaterialShaders.TERRAIN_BLEND_SHADER.code
	var vertex_start := code.find("void vertex()")
	var vertex_body := code.substr(vertex_start, code.find("void fragment()") - vertex_start)
	var fragment_body := code.substr(code.find("void fragment()"))
	for sampler: String in ["sample_natural_ground", "sample_ground_family", "sample_coast_sand"]:
		assert_true(fragment_body.contains(sampler), "%s runs in fragment()" % sampler)
		assert_false(vertex_body.contains(sampler), "%s must not run per vertex" % sampler)
	assert_true(
		code.contains("ground_detail_strength"), "two-scale anti-tiling keeps an art control"
	)


func test_ground_plates_stay_off_the_threaded_prefetch() -> void:
	# A cancelled staged assembly can drop a threaded plate load before its queued
	# RenderingServer initialize runs; the arrays load plates on the main thread.
	var paths := TerrainMaterials.blended_ground_resource_paths()
	paths.append_array(TerrainMaterials.terrain_resource_paths(MapTypes.TERRAIN_COAST_SAND))
	for family in FAMILIES:
		for map_type in TerrainMaterials.GROUND_MAP_TYPES:
			var path := TerrainMaterials.ground_plate_path(family, map_type)
			assert_false(paths.has(path), "%s must not be prefetched on a worker" % path)


func _texture(family: StringName, map_type: StringName) -> Texture2D:
	var path := TerrainMaterials.ground_plate_path(family, map_type)
	var texture := load(path) as Texture2D
	assert_true(texture != null, path)
	return texture



func test_sand_renormalisation_reads_the_mean_through_the_plate_sampler() -> void:
	# The mean must come from the same source_color sampler as the plate, or the
	# gain mixes colour spaces (Compatibility decodes the array, Mobile does not).
	var code := MapViewMaterialShaders.TERRAIN_BLEND_SHADER.code
	assert_true(code.contains("uniform sampler2DArray ground_albedo : source_color"))
	assert_true(code.contains("textureLod(ground_albedo"), "plate mean uses the plate sampler")
