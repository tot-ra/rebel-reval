extends "res://tests/godot/test_case.gd"

const EnvironmentKit := preload("res://scripts/map/view3d/map_view_environment_kit.gd")


func test_catalog_accepts_complete_synthetic_contracts() -> void:
	var smithy := _definition_for(EnvironmentKit.MODULE_FORGE_INTERIOR)
	var lower_town_modules := [
		EnvironmentKit.MODULE_FORGE_YARD,
		EnvironmentKit.MODULE_STREET_WELL,
		EnvironmentKit.MODULE_BREWERY,
		EnvironmentKit.MODULE_CHECKPOINT,
	]
	assert_eq(EnvironmentKit.validate_module(smithy, EnvironmentKit.MODULE_FORGE_INTERIOR), [])
	for module_id in lower_town_modules:
		assert_eq(
			EnvironmentKit.validate_module(_definition_for(module_id), module_id),
			[],
			"%s synthetic contract should be complete" % String(module_id)
		)


func test_catalog_reports_missing_and_duplicate_records_deterministically() -> void:
	var yard := _definition_for(EnvironmentKit.MODULE_FORGE_YARD)
	var without_firewood := func(record: Dictionary) -> bool:
		return record["id"] != &"courtyard_firewood"
	yard.props = yard.props.filter(without_firewood)
	assert_array_contains(
		EnvironmentKit.validate_module(yard, EnvironmentKit.MODULE_FORGE_YARD),
		"missing prop: courtyard_firewood"
	)

	var checkpoint := _definition_for(EnvironmentKit.MODULE_CHECKPOINT)
	checkpoint.view_landmarks.append({"id": &"viru_gate_arch"})
	assert_array_contains(
		EnvironmentKit.validate_module(checkpoint, EnvironmentKit.MODULE_CHECKPOINT),
		"duplicate landmark: viru_gate_arch"
	)
	assert_eq(
		EnvironmentKit.validate_module(checkpoint, &"unknown"),
		["unknown environment module: unknown"]
	)


func _definition_for(module_id: StringName) -> MapDefinition:
	var definition := MapDefinition.new()
	var catalog: Dictionary = {
		EnvironmentKit.MODULE_FORGE_INTERIOR: {
			"buildings": [&"wall.north_forge/segment.000", &"wall.south_forge", &"wall.divider/segment.000"],
			"props": [
				&"forge_anvil", &"forge_furnace", &"forge_bellows", &"forge_tongs",
				&"forge_hammer", &"forge_punch", &"quench", &"coal_store", &"iron_scrap_store",
			],
			"landmarks": [],
		},
		EnvironmentKit.MODULE_FORGE_YARD: {
			"buildings": [&"kalev_smithy", &"smithy_yard_fence_north", &"smithy_yard_fence_east"],
			"props": [&"courtyard_firewood", &"courtyard_quench", &"hay_store"],
			"landmarks": [],
		},
		EnvironmentKit.MODULE_STREET_WELL: {
			"buildings": [],
			"props": [&"cistern", &"cistern_wash_tub", &"monastery_well"],
			"landmarks": [],
		},
		EnvironmentKit.MODULE_BREWERY: {
			"buildings": [&"foaming_mug_brewery"],
			"props": [&"brewery_keg_stack", &"brewery_malt_sacks", &"evidence_barrels"],
			"landmarks": [],
		},
		EnvironmentKit.MODULE_CHECKPOINT: {
			"buildings": [&"viru_gate_north_tower", &"viru_gate_south_tower"],
			"props": [&"market_stall_gate", &"gate_cart"],
			"landmarks": [&"viru_gate_arch", &"viru_foregate_arch"],
		},
	}
	var records: Dictionary = catalog[module_id]
	for record_id in records["buildings"]:
		definition.buildings.append({"id": record_id})
	for record_id in records["props"]:
		definition.props.append({"id": record_id})
	for record_id in records["landmarks"]:
		definition.view_landmarks.append({"id": record_id})
	return definition
