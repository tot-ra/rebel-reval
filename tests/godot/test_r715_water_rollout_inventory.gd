extends "res://tests/godot/test_case.gd"

const MapTypesContract := preload("res://scripts/map/map_types.gd")
const MapAudit := preload("res://scripts/map/map_audit_registry.gd")
const MapBuilderContract := preload("res://scripts/map/map_builder.gd")
const WaterMaterials := preload("res://scripts/map/view3d/map_view_water_materials.gd")
const MaterialsFacade := preload("res://scripts/map/view3d/map_view_materials.gd")
const WaterMesh := preload("res://scripts/map/view3d/map_view_mesh_builder_terrain_water.gd")
const Shoreline := preload("res://scripts/map/view3d/map_view_shoreline_3d.gd")
const ShaderSources := preload("res://scripts/map/view3d/map_view_material_shaders.gd")

const INVENTORY_REPORT := "res://docs/reports/r715_water_rollout_inventory.md"
const EXPECTED_WATER_MAPS := {
	&"smithy_courtyard": [&"water"],
	&"lower_town_slice": [&"water"],
	&"monastery_quarter": [&"water"],
	&"south_quarter": [&"water"],
	&"viru_gate_foreland": [&"river_water"],
	&"reval_harbor_north": [&"shallow_water", &"deep_water"],
	&"reval_harbor_east": [&"shallow_water", &"deep_water"],
	&"prototype.paldiski_coastal_outpost": [&"shallow_water", &"deep_water"],
	&"prototype.sacred_grove": [&"shallow_water"],
	&"prototype.saaremaa": [&"shallow_water", &"deep_water"],
	&"prototype.swedish_arrival": [&"shallow_water", &"deep_water"],
	&"world.sacred_grove": [&"shallow_water"],
	&"world.padise": [&"water", &"river_water", &"shallow_water"],
	&"world.saaremaa": [&"shallow_water", &"deep_water"],
}


func test_water_terrain_vocabulary_is_closed_and_shared() -> void:
	assert_eq(
		MapTypesContract.WATER_TERRAINS,
		[
			MapTypesContract.TERRAIN_WATER,
			MapTypesContract.TERRAIN_RIVER_WATER,
			MapTypesContract.TERRAIN_SHALLOW_WATER,
			MapTypesContract.TERRAIN_DEEP_WATER,
		],
		"MapTypes must expose the four stable water terrain IDs",
	)
	assert_eq(
		MaterialsFacade.WATER_TERRAINS,
		MapTypesContract.WATER_TERRAINS,
		"the public material facade must mirror MapTypes.WATER_TERRAINS",
	)


func test_every_inventoried_water_map_contains_only_expected_water_ids() -> void:
	var found: Dictionary = {}
	for definition: MapDefinition in MapAudit.all():
		if definition.map_id.is_empty():
			continue
		var grid := MapBuilderContract.build(definition)
		var water_ids: Array[StringName] = []
		for terrain_id: StringName in MapTypesContract.WATER_TERRAINS:
			if grid.used_terrain_ids().has(terrain_id):
				water_ids.append(terrain_id)
		if water_ids.is_empty():
			continue
		assert_true(
			definition.map_id != &"",
			"a water-bearing definition must retain a stable map ID",
		)
		found[definition.map_id] = water_ids
	assert_eq(found, EXPECTED_WATER_MAPS, "water map inventory drifted")


func test_every_inventoried_water_map_is_listed_in_report() -> void:
	var report := FileAccess.get_file_as_string(INVENTORY_REPORT)
	for map_id: StringName in EXPECTED_WATER_MAPS:
		var row_prefix := "| `%s` |" % String(map_id)
		var inventory_row := ""
		for line: String in report.split("\n"):
			if line.begins_with(row_prefix):
				inventory_row = line
				break
		assert_true(
			inventory_row != "",
			"inventory report must list the compiled water map %s" % map_id,
		)
		for terrain_id: StringName in EXPECTED_WATER_MAPS[map_id]:
			assert_true(
				inventory_row.contains("`%s`" % String(terrain_id)),
				"inventory row for %s must list terrain %s" % [map_id, terrain_id],
			)


func test_external_water_row_is_explicitly_documented() -> void:
	var report := FileAccess.get_file_as_string(INVENTORY_REPORT)
	assert_true(
		report.contains("14 definitions"),
		"the report must state the complete water-bearing inventory size",
	)
	assert_true(
		report.contains("| `monastery_quarter` |"),
		"the report must list the Monastery water-bearing definition",
	)
	assert_true(
		report.contains("excluded from the 13-row rollout matrix"),
		"the Monastery exception must remain outside the rollout matrix",
	)
	assert_true(
		report.contains("R-529"),
		"the excluded Monastery row must retain its external owner",
	)


func test_report_names_shared_water_owner_paths() -> void:
	var report := FileAccess.get_file_as_string(INVENTORY_REPORT)
	for owner_path in [
		"../../scripts/map/view3d/map_view_water_materials.gd)",
		"../../scripts/map/view3d/map_view_mesh_builder_terrain_water.gd)",
		"../../scripts/map/view3d/map_view_shoreline_3d.gd)",
	]:
		assert_true(
			report.contains(owner_path),
			"inventory report must link the shared owner %s" % owner_path,
		)


func test_water_owner_modules_and_shader_contract_are_present() -> void:
	var water_materials := WaterMaterials.new()
	var water_mesh := WaterMesh.new()
	var shoreline := Shoreline.new()
	assert_true(water_materials.has_method("water_surface"))
	assert_true(water_materials.has_method("apply_sea_weather"))
	assert_true(water_materials.has_method("apply_coastal_tide"))
	assert_true(water_mesh.has_method("bake_water_contour"))
	assert_true(water_mesh.has_method("add_water_cell_quad"))
	assert_true(shoreline.has_method("build"))
	for feature in ["fresnel", "sky", "TIME", "depth_absorption", "flow_direction", "tide_level"]:
		assert_true(feature in ShaderSources.WATER_SHADER_CODE, "water shader must retain %s" % feature)
