extends "res://tests/godot/test_case.gd"

## World-unit shingle and thatch densities for gabled roof meshes.


const LowerTownSlice := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const MapViewMeshBuilder := preload("res://scripts/map/view3d/map_view_mesh_builder.gd")


func test_roof_cover_world_densities_match_real_cover_sizes() -> void:
	MapViewMaterials.reset()
	var plate := float(MapViewMaterials.TEXTURE_SIZE)
	var shingle_columns := plate / float(MapViewMaterialPatterns.SHINGLE_WIDTH_PX)
	var shingle_courses := plate / float(MapViewMaterialPatterns.SHINGLE_COURSE_PX)
	var thatch_courses := plate / float(MapViewMaterialPatterns.THATCH_COURSE_PX)
	var shingle := MapViewMaterials.ROOF_SHINGLE_WORLD_DENSITY
	var thatch := MapViewMaterials.ROOF_THATCH_WORLD_DENSITY
	var metres := MapViewMaterials.METERS_PER_WORLD_UNIT

	assert_eq(
		MapViewMaterials.TEXTURE_SIZE % MapViewMaterialPatterns.SHINGLE_WIDTH_PX,
		0,
		"shingle width must divide the plate so the wrap is seamless"
	)
	assert_eq(
		MapViewMaterials.TEXTURE_SIZE % MapViewMaterialPatterns.SHINGLE_COURSE_PX,
		0,
		"shingle courses must divide the plate so the wrap is seamless"
	)
	assert_true(
		shingle.x < 1.0 and shingle.y < 1.0,
		"world-unit shingle UVs need under one plate per unit, not ~90 boards per metre"
	)
	assert_true(
		thatch.x < 1.0 and thatch.y < 1.0,
		"world-unit thatch UVs need under one plate per unit, not ~5 plates per unit"
	)

	var shingle_width_m := metres / (shingle.x * shingle_columns)
	var shingle_course_m := metres / (shingle.y * shingle_courses)
	var thatch_course_m := metres / (thatch.y * thatch_courses)
	assert_true(
		shingle_width_m >= 0.10 and shingle_width_m <= 0.15,
		"shingles should read ~0.1-0.15 m wide, got %.3f m" % shingle_width_m
	)
	assert_true(
		shingle_course_m >= 0.18 and shingle_course_m <= 0.22,
		"shingle courses should read ~0.2 m, got %.3f m" % shingle_course_m
	)
	assert_true(
		thatch_course_m >= 0.25 and thatch_course_m <= 0.30,
		"thatch courses should read ~0.25-0.3 m, got %.3f m" % thatch_course_m
	)


func test_roof_surface_callers_use_world_unit_cover_density() -> void:
	MapViewMaterials.reset()
	var color := Color8(112, 83, 56)
	var families: Array[StringName] = [&"tile", &"shingle", &"thatch"]
	for family in families:
		var shared := MapViewMaterials.roof_surface(family, color)
		var building := MapViewMaterials.roof_surface_for_building(
			StringName("roof.density.%s" % String(family)), family, color
		)
		var expected := MapViewMaterials.roof_cover_world_density(
			_pattern_for_family(family)
		)
		assert_true(
			shared.uv1_scale.is_equal_approx(_expected_cover_density(shared, expected)),
			"%s roof_surface must use world-unit cover density" % family
		)
		assert_true(
			building.uv1_scale.is_equal_approx(_expected_cover_density(building, expected)),
			"%s roof_surface_for_building must use world-unit cover density" % family
		)
	var tile_world := MapViewMaterials.roof_tile_world(color)
	assert_true(
		tile_world.uv1_scale.is_equal_approx(
			_expected_cover_density(tile_world, MapViewMaterials.ROOF_TILE_WORLD_DENSITY)
		),
		"tile world helper must keep the monk/nun density"
	)
	# BoxMesh / CylinderMesh tile callers still use the per-face reference scale.
	assert_true(
		MapViewMaterials.roof(color).uv1_scale.is_equal_approx(
			MapViewMaterials.building_uv_scale(
				MapViewMaterials.PATTERN_ROOF_TILE,
				MapViewMaterials.BUILDING_UV_REFERENCE_SIZE
			)
		),
		"roof() stays on the BoxMesh per-face scale"
	)


func test_authored_house_roofs_use_world_unit_cover_density() -> void:
	MapViewMaterials.reset()
	var definition := LowerTownSlice.create()
	var checked_shingle := 0
	var checked_thatch := 0
	for building in definition.buildings:
		if building.get("kind", &"") != MapTypes.BUILDING_KIND_HOUSE:
			continue
		var family := StringName(building.get("roof_material", &""))
		if family != &"shingle" and family != &"thatch":
			continue
		var node := MapViewMeshBuilder.build_building(building, definition.cell_size)
		var roof := node.get_node_or_null("Roof") as MeshInstance3D
		assert_true(roof != null, "%s: house needs a Roof node" % building["id"])
		var roof_mat := roof.material_override as StandardMaterial3D
		var expected := MapViewMaterials.roof_cover_world_density(_pattern_for_family(family))
		assert_true(
			roof_mat.uv1_scale.is_equal_approx(_expected_cover_density(roof_mat, expected)),
			"%s: gabled cover must use world-unit density" % building["id"]
		)
		if family == &"thatch":
			var ridge := node.get_node("ThatchRidge") as MeshInstance3D
			var fringe := node.get_node("ThatchEavesFringe_-1") as MeshInstance3D
			var dressing_uv := MapViewMaterials.building_uv_scale(
				MapViewMaterials.PATTERN_THATCH,
				MapViewMaterials.BUILDING_UV_REFERENCE_SIZE
			)
			assert_true(
				(ridge.material_override as StandardMaterial3D).uv1_scale.is_equal_approx(
					dressing_uv
				),
				"%s: thatch ridge dressing must keep the 0-1 plate scale" % building["id"]
			)
			assert_true(
				(fringe.material_override as StandardMaterial3D).uv1_scale.is_equal_approx(
					dressing_uv
				),
				"%s: thatch eaves dressing must keep the 0-1 plate scale" % building["id"]
			)
			checked_thatch += 1
		else:
			checked_shingle += 1
		node.free()
		if checked_shingle >= 2 and checked_thatch >= 2:
			break
	assert_true(checked_shingle >= 2, "Lower Town slice must expose authored shingle roofs")
	assert_true(checked_thatch >= 2, "Lower Town slice must expose authored thatch roofs")


func _pattern_for_family(family: StringName) -> StringName:
	match family:
		&"shingle":
			return MapViewMaterials.PATTERN_SHINGLE
		&"thatch":
			return MapViewMaterials.PATTERN_THATCH
		_:
			return MapViewMaterials.PATTERN_ROOF_TILE


## AR-03 (R-961): library surfaces are sized from their plate in metres, so the
## expected density follows the stem; the procedural fallback keeps its constant.
func _expected_cover_density(material: StandardMaterial3D, fallback: Vector3) -> Vector3:
	var materials: Variant = MapViewMaterials.BUILDING_MATERIALS
	if material.has_meta(materials.LIBRARY_STEM_META):
		return materials.library_world_uv_density(String(material.get_meta(materials.LIBRARY_STEM_META)))
	return fallback
