extends "res://tests/godot/test_case.gd"

const GLB_PATH := "res://assets/props/architecture/houses/merchant_stone/merchant_stone.glb"
const BRIEF_PATH := "res://generated/blender/burgher_house_merchant_stone_v1/brief.json"
const REPORT_PATH := "res://generated/blender/burgher_house_merchant_stone_v1/report.json"
const STATE_PATH := "res://generated/blender/burgher_house_merchant_stone_v1/state.json"
const HOUSE_STYLES := preload("res://scripts/map/view3d/map_view_mesh_builder_house_styles.gd")


func test_merchant_stone_production_kit_has_profile_and_budget_evidence() -> void:
	var glb := load(GLB_PATH) as PackedScene
	assert_true(glb != null, "merchant_stone production GLB must import as a PackedScene")
	var brief := _read_json(BRIEF_PATH)
	var report := _read_json(REPORT_PATH)
	var state := _read_json(STATE_PATH)
	assert_eq(brief.get("tier"), "merchant_stone")
	var features: Dictionary = brief.get("features", {})
	assert_true(bool(features.get("steep_gable_to_street", false)))
	assert_true(bool(features.get("limestone_or_mixed_front", false)))
	assert_true(bool(features.get("street_portal", false)))
	assert_true(bool(features.get("large_ground_opening", false)))
	assert_true(bool(features.get("upper_loading_hatches", false)))
	assert_true(bool(features.get("protruding_hoist_beam", false)))
	assert_true(bool(features.get("raised_cellar_neck", false)))
	assert_true(bool(features.get("tile_roof_band", false)))
	assert_false(bool(features.get("late_gothic_facade", true)))
	assert_eq(report.get("generator"), "burgher_house_kit_v1")
	assert_true(bool(state.get("complete", false)), "generated kit evidence must pass all mesh checks")
	assert_true(report.get("assets", {}).has("prop.architecture.house.merchant_stone"))


func test_merchant_stone_runtime_style_contract_is_stone_and_tile() -> void:
	var building := {
		"id": &"merchant_stone_contract",
		"house_tier": &"merchant_stone",
	}
	assert_eq(HOUSE_STYLES.house_style(building), MapViewMeshBuilderConfig.HOUSE_STYLE_STONE)
	assert_eq(HOUSE_STYLES.roof_style(building), MapViewMeshBuilderConfig.ROOF_STYLE_TILE)


func test_merchant_stone_mesh_builder_uses_imported_production_model() -> void:
	var building := {
		"id": &"merchant_stone_runtime",
		"kind": MapTypes.BUILDING_KIND_HOUSE,
		"house_tier": &"merchant_stone",
		"footprint": Rect2(0.0, 0.0, 9.0 * 32.0, 10.0 * 32.0),
		"wall_height": 144.0,
		"door_side": &"south",
	}
	var node := MapViewMeshBuilder.build_building(building, MapTypes.DEFAULT_CELL_SIZE)
	var model := node.get_node_or_null("ProductionMerchantStone") as Node3D
	assert_true(model != null, "merchant_stone tier must use the imported production GLB")
	if model != null:
		assert_true(model.get_meta(&"production_house_model", false))
		assert_eq(model.get_meta(&"house_tier"), &"merchant_stone")
	assert_false(
		node.get_node("Walls").visible,
		"placeholder walls must be hidden behind the production GLB"
	)
	assert_false(
		node.get_node("Roof").visible,
		"placeholder roof must be hidden behind the production GLB"
	)
	node.free()


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	assert_true(file != null, "missing %s" % path)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	assert_true(parsed is Dictionary, "%s must contain a JSON object" % path)
	return parsed if parsed is Dictionary else {}
