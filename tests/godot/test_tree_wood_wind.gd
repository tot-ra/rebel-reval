extends "res://tests/godot/test_case.gd"

## Trunks and branches sway with the crown; thin limbs carry more flex than the bole.


func test_wood_alpha_stores_limb_flexibility_thin_over_thick() -> void:
	var scale := CityVegetationBuilder.species_scale(&"oak", 1.0)
	var wood := MapViewTreeMeshes.city_wood_mesh(&"oak", scale, 0.6)
	var arrays := wood.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var min_flex := 1.0
	var max_flex := 0.0
	var low_flex_sum := 0.0
	var low_count := 0
	for i in colors.size():
		min_flex = minf(min_flex, colors[i].a)
		max_flex = maxf(max_flex, colors[i].a)
		if vertices[i].y < 0.3:
			low_flex_sum += colors[i].a
			low_count += 1
	assert_true(min_flex < 0.2, "trunk base is stiff (min %.2f)" % min_flex)
	assert_true(max_flex > 0.8, "twig tips are flexible (max %.2f)" % max_flex)
	assert_true(low_count > 0 and low_flex_sum / low_count < 0.3, "the bole near the ground is stiff")


## Where two trunk sections meet, the bark must not jump: each vertex of the
## joint ring has a twin on the other section's ring with the same UV (the user
## saw a bark ring seam on the pine bole).
func test_bark_uv_is_continuous_across_trunk_joints() -> void:
	for species: StringName in [&"pine", &"pine_tall"]:
		var scale := CityVegetationBuilder.species_scale(species, 1.0)
		var factor := CityVegetationBuilder.trunk_factor(species, scale)
		var arrays := MapViewTreeMeshes.city_wood_mesh(species, scale, factor).surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var trunk: Array = MapViewTreeMeshes._skeleton_for(species)["segments"].filter(
			func(s: Dictionary) -> bool: return int(s["depth"]) == 0
		)
		var joints := 0
		for i in trunk.size() - 1:
			var joint: Vector3 = trunk[i]["end"]
			var radius := float(trunk[i]["end_radius"]) * factor
			var axis: Vector3 = ((trunk[i]["end"] as Vector3) - trunk[i]["start"]).normalized()
			var ring: Array[int] = []
			for v in vertices.size():
				var offset := vertices[v] - joint
				if absf(offset.dot(axis)) < radius * 0.2 and absf(offset.length() - radius) < radius * 0.1:
					ring.append(v)
			# Branch collars can graze a thin joint; keep only the trunk's joint v.
			var v_counts := {}
			for v in ring:
				var key := snappedf(uvs[v].y, 0.001)
				v_counts[key] = int(v_counts.get(key, 0)) + 1
			var joint_v: float = v_counts.keys().reduce(
				func(best: float, key: float) -> float: return key if v_counts[key] > v_counts[best] else best
			)
			ring = ring.filter(
				func(v: int) -> bool: return is_equal_approx(snappedf(uvs[v].y, 0.001), joint_v)
			)
			assert_true(ring.size() >= 10, "%s joint %d has both rings" % [species, i])
			for a in ring:
				var twin := -1
				for b in ring:
					var gap := vertices[a].distance_to(vertices[b])
					if gap > radius * 0.0001 and (twin < 0 or gap < vertices[a].distance_to(vertices[twin])):
						twin = b
				var du := absf(fposmod(uvs[a].x, 1.0) - fposmod(uvs[twin].x, 1.0))
				assert_true(
					minf(du, 1.0 - du) < 0.15 and absf(uvs[a].y - uvs[twin].y) < 0.05,
					"%s joint %d bark UV continuous (%s vs %s)" % [species, i, uvs[a], uvs[twin]]
				)
			joints += 1
		assert_true(joints >= 2, "%s trunk has joints" % species)


func test_limb_flex_falls_with_radius() -> void:
	assert_true(MapViewTreeMeshes.limb_flex(0.003) > 0.99)
	assert_true(MapViewTreeMeshes.limb_flex(0.03) < MapViewTreeMeshes.limb_flex(0.01))
	assert_true(MapViewTreeMeshes.limb_flex(0.15) < 0.01)


func test_swaying_bark_material_uses_wind_shader_and_plate_textures() -> void:
	var material := MapViewMaterials.bark_plate_wind(&"grey")
	assert_true(material.shader != null)
	assert_true(material.get_shader_parameter("albedo_tex") != null, "plate albedo bound")
	assert_true(material.get_shader_parameter("normal_tex") != null, "plate normal bound")
	assert_eq(MapViewMaterials.bark_plate_wind(&"grey"), material, "cached per plate")
