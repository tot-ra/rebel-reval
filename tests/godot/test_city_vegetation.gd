extends "res://tests/godot/test_case.gd"

## Seamless-city vegetation (R-712 VEG pass): real-scale trees, near/far crown
## LOD, bark plates on city trunks, seamless grass ground plates, tuft size.

const KALEV_HEIGHT := 1.83


const TreeSkeletonWeber := preload("res://scripts/map/view3d/tree_skeleton_weber_penn.gd")


func _world_height(species: StringName) -> float:
	var scale := CityVegetationBuilder.species_scale(species, 1.0)
	return MapViewTreeMeshes.city_canopy_far_mesh(species).get_aabb().end.y * scale


func test_tree_heights_are_normalised_to_kalev() -> void:
	for species: StringName in [&"spruce", &"pine", &"oak", &"birch", &"linden"]:
		var height := _world_height(species)
		assert_almost_eq(
			height, float(CityVegetationBuilder.HEIGHT_M[species]), 0.05, "%s height" % species
		)
		# The plan's largest size factor (1.35) must not make giants.
		var tallest := height * CityVegetationBuilder.size_factor(1.35)
		assert_true(
			tallest < KALEV_HEIGHT * 7.0, "%s at most ~7 Kalevs tall (%.1f m)" % [species, tallest]
		)


func test_city_trunks_are_thinned_to_real_diameters() -> void:
	for species: StringName in [&"spruce", &"oak", &"birch"]:
		var scale := CityVegetationBuilder.species_scale(species, 1.0)
		var factor := CityVegetationBuilder.trunk_factor(species, scale)
		var radii: Array = MapViewTreeMeshes.geometry_stats(species)["trunk_radii"]
		var diameter := float(radii[0]) * 2.0 * scale * factor
		assert_almost_eq(
			diameter,
			float(CityVegetationBuilder.TRUNK_DIAMETER_M[species]),
			0.02,
			"%s trunk" % species
		)
		var wood := MapViewTreeMeshes.city_wood_mesh(species, scale, factor).get_aabb()
		var crown := MapViewTreeMeshes.city_canopy_far_mesh(species).get_aabb().grow(0.05)
		var wood_xz := Rect2(wood.position.x, wood.position.z, wood.size.x, wood.size.z)
		var crown_xz := Rect2(crown.position.x, crown.position.z, crown.size.x, crown.size.z)
		assert_true(crown_xz.encloses(wood_xz), "%s limbs stay inside the crown spread" % species)


func test_city_wood_has_bark_tile_uvs_and_tangents() -> void:
	var scale := CityVegetationBuilder.species_scale(&"oak", 1.0)
	var wood := MapViewTreeMeshes.city_wood_mesh(&"oak", scale, 0.6)
	var arrays := wood.surface_get_arrays(0)
	assert_true(arrays[Mesh.ARRAY_TANGENT] != null, "tangents for the bark normal map")
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var max_v := 0.0
	for uv in uvs:
		max_v = maxf(max_v, uv.y)
	# A ~10 m oak with 0.55 m bark tiles runs several tiles up the bole; the
	# legacy UVs stopped at 1 per segment (blurry stretched bark).
	assert_true(max_v > 6.0, "bark tiles repeat up the trunk (max v %.1f)" % max_v)


func test_bark_plates_load_for_every_species_plate() -> void:
	for plate: StringName in MapViewMaterials.PROP_MATERIALS.BARK_PLATES:
		var material := MapViewMaterials.bark_plate(plate)
		assert_true(material.albedo_texture != null, "%s albedo" % plate)
		assert_true(material.normal_texture != null, "%s normal" % plate)
	assert_eq(MapViewTreeSpecies.bark_plate_for(&"spruce"), &"spruce")
	assert_eq(MapViewTreeSpecies.bark_plate_for(&"birch"), &"birch")
	assert_eq(MapViewTreeSpecies.bark_plate_for(&"linden"), &"grey")


func test_near_crown_cards_are_real_size_and_denser() -> void:
	for species: StringName in [&"oak", &"spruce", &"birch"]:
		var scale := CityVegetationBuilder.species_scale(species, 1.0)
		var near := MapViewTreeMeshes.city_canopy_near_stats(species, scale)
		var conifer := species in MapViewTreeMeshes.CONIFERS
		var base := (
			float(MapViewTreeMeshes.city_profile(species)["leaf_length"])
			* (MapViewTreeMeshes.CONIFER_CARD_SCALE if conifer else MapViewTreeMeshes.CARD_SCALE)
		)
		var card_metres := base * float(near["size_factor"]) * scale
		assert_true(card_metres < 0.75, "%s near card %.2f m" % [species, card_metres])
		assert_true(float(near["count_factor"]) >= 1.0, "%s near crown is not sparser" % species)
		assert_true(
			int(near["canopy_triangles"]) <= MapViewTreeMeshes.NEAR_TRIANGLE_CAP * 1.25,
			"%s near triangles %d" % [species, near["canopy_triangles"]]
		)


func test_city_spruce_keeps_all_whorls() -> void:
	var skeleton: Dictionary = MapViewTreeMeshes._skeleton_for(&"spruce")
	var heights: Array = skeleton["primary_attachment_heights"]
	assert_eq(
		heights.size(), int(MapViewTreeMeshes.CITY_PROFILE_OVERRIDES[&"spruce"]["primary_count"])
	)
	var top := float(MapViewTreeMeshes.city_profile(&"spruce")["crown_end"])
	assert_true(float(heights.max()) > top * 0.85, "whorls reach the top of the crown")


func test_shared_meshes_unchanged_for_district_maps() -> void:
	# The city variants must not leak into the district maps' cached geometry.
	var stats := MapViewTreeMeshes.geometry_stats(&"spruce")
	# Limb smoothing subdivides every coarse piece, so the budget scales with it.
	var budget := MapViewTreeMeshes.MAX_WOOD_SEGMENTS * TreeSkeletonWeber.BRANCH_SMOOTH_SUBDIV
	assert_true(int(stats["wood_segments"]) <= budget, "district spruce wood budget")
	assert_true(int(stats["canopy_triangles"]) <= 26000, "district spruce canopy unchanged")


func test_tree_lod_swaps_far_instances_with_hysteresis() -> void:
	var lod := CityTreeLod.new()
	var far := MultiMesh.new()
	far.transform_format = MultiMesh.TRANSFORM_3D
	far.use_colors = true
	far.instance_count = 2
	var near_xf := Transform3D(Basis(), Vector3(10, 0, 0))
	var far_xf := Transform3D(Basis(), Vector3(200, 0, 0))
	far.set_instance_transform(0, near_xf)
	far.set_instance_transform(1, far_xf)
	var transforms: Array[Transform3D] = [near_xf, far_xf]
	var colors: Array[Color] = [Color.WHITE, Color.WHITE]
	lod.register(
		&"oak", CityVegetationBuilder.species_scale(&"oak", 1.0), far, transforms, colors, false
	)
	assert_true(lod.update_for(Vector3.ZERO), "first update swaps the close tree in")
	assert_true(lod.is_near(0) and not lod.is_near(1))
	# MultiMesh transforms live in the RenderingServer (not readable headless);
	# the swap itself is covered by the GPU plates (tools/capture_city_vegetation.gd).
	assert_eq(lod.get_child_count(), 1, "one near MultiMesh for the species")
	# Between ENTER and EXIT the tree stays near (no flicker at the edge).
	assert_false(lod.update_for(Vector3(-(CityTreeLod.NEAR_ENTER + 2.0) + 10.0, 0, 0)))
	assert_true(lod.is_near(0))
	lod.update_for(Vector3(-CityTreeLod.NEAR_EXIT - 5.0 + 10.0, 0, 0))
	assert_false(lod.is_near(0), "leaving the exit radius restores the far crown")
	assert_eq(lod.near_count(), 0)
	lod.free()


func test_grass_ground_plates_are_a_twelve_layer_array() -> void:
	# VRAM-compressed arrays do not load on the headless dummy renderer, so the
	# import contract is checked instead (GPU plates show the result).
	for kind in ["albedo", "normal"]:
		var path := "res://assets/materials/pbr/grass_ground/grass_ground_%s_array.jpg" % kind
		var config := ConfigFile.new()
		assert_eq(config.load(path + ".import"), OK, "%s import sidecar" % kind)
		assert_eq(config.get_value("remap", "importer"), "2d_array_texture")
		var slices := (
			int(config.get_value("params", "slices/horizontal"))
			* int(config.get_value("params", "slices/vertical"))
		)
		assert_eq(slices, 12, "%s has twelve plates" % kind)
	var shader := load("res://scripts/city/city_ground.gdshader") as Shader
	assert_true(
		shader.code.contains("city_grass_ground.gdshaderinc"), "ground shader uses the plates"
	)


func test_grass_clumps_are_real_size() -> void:
	var clump := MapViewMeshBuilderPrimitives.grass_blade_clump_mesh().get_aabb().size
	var tallest := CityGrass.MID_CLUMP_SCALE.y * 1.3  # instance Y stretch tops out at 1.3
	assert_true(clump.y * tallest < 1.2, "tallest mid clump under 1.2 m")
	var widest := maxf(clump.x, clump.z) * CityGrass.MID_CLUMP_SCALE.y
	assert_true(widest < 0.9, "widest mid clump under 0.9 m")
	assert_true(clump.y * CityGrass.NEAR_CLUMP_SCALE.y * 1.3 < 0.8, "near blades stay knee-high")


## Longest leaf-cluster card in a mesh, times the instance scale, in metres.
## Card length is measured along its spine (UV.x = 0.5, from UV.y = 0 to 1);
## each card is 12 consecutive UV2 = (1, 1) vertices.
func _max_card_metres(mesh: ArrayMesh, scale: float) -> float:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var largest := 0.0
	var index := 0
	while index < vertices.size():
		if uv2[index].y < 0.5:
			index += 1
			continue
		var twig := Vector3.INF
		var tip := Vector3.INF
		for v in range(index, mini(index + 12, vertices.size())):
			if absf(uv[v].x - 0.5) < 0.01:
				if uv[v].y < 0.01:
					twig = vertices[v]
				elif uv[v].y > 0.99:
					tip = vertices[v]
		if twig != Vector3.INF and tip != Vector3.INF:
			largest = maxf(largest, twig.distance_to(tip) * scale)
		index += 12
	return largest


func test_city_bush_leaf_cards_are_real_size() -> void:
	# The plan scales shrubs by up to ~1.35; leaves must stay hand-sized.
	for species: StringName in [&"dog_rose", &"raspberry"]:
		var mesh := CityVegetationBuilder.bush_mesh(species)
		var scale := CityVegetationBuilder.bush_scale(species, 1.0, 1.0)
		var card := _max_card_metres(mesh, scale * 1.35)
		assert_true(card > 0.1 and card < 0.4, "%s leaf card %.2f m" % [species, card])
		var size_m: Vector2 = CityVegetationBuilder.BUSH_SIZE_M[species]
		var box := mesh.get_aabb()
		assert_almost_eq(box.end.y * scale, size_m.x, size_m.x * 0.2, "%s height" % species)
		assert_true(
			maxf(box.size.x, box.size.z) * scale > size_m.y * 0.6, "%s keeps its spread" % species
		)
		# Mass from many small cards instead of a few blown-up blobs.
		var cards := 0
		var uv2: PackedVector2Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
		for uv in uv2:
			cards += 1 if uv.y > 0.5 else 0
		assert_true(cards / 12 >= 150, "%s has %d cards" % [species, cards / 12])
	# Shrubs drawn with the tree meshes (elder, guelder rose, willow/alder scrub...)
	# swap to a near crown with hand-sized cards beside Kalev.
	for species: StringName in MapViewTreeMeshes.CITY_SHRUBS:
		var scale := CityVegetationBuilder.species_scale(species, 1.0)
		var near := MapViewTreeMeshes.city_canopy_near_mesh(species, scale)
		var card := _max_card_metres(near, scale * CityVegetationBuilder.size_factor(1.35))
		assert_true(card < 0.4, "%s near card %.2f m" % [species, card])
		var far := _max_card_metres(MapViewTreeMeshes.city_canopy_far_mesh(species), scale)
		assert_true(card < far, "%s near cards smaller than far (%.2f m)" % [species, far])
		var stats := MapViewTreeMeshes.city_canopy_near_stats(species, scale)
		assert_true(float(stats["count_factor"]) > 1.1, "%s near crown keeps its mass" % species)
		assert_true(int(stats["canopy_triangles"]) <= MapViewTreeMeshes.NEAR_TRIANGLE_CAP)


func test_district_bush_meshes_unchanged() -> void:
	# The city variants must not leak into the district maps' bush geometry.
	for species: StringName in [&"dog_rose", &"raspberry"]:
		var stats := MapViewBushMeshes.geometry_stats(species)
		assert_eq(int(stats["triangles"]), 320, "%s district mesh" % species)
		assert_true((stats["aabb"] as AABB).size.y < 1.2, "%s district mesh ~1 unit" % species)
