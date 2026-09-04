extends "res://tests/godot/test_case.gd"

const GLB_PATH := "res://assets/props/architecture/houses/craft_boda/craft_boda.glb"
const BRIEF_PATH := "res://generated/blender/burgher_house_craft_boda_v1/brief.json"
const REPORT_PATH := "res://generated/blender/burgher_house_craft_boda_v1/report.json"
const STATE_PATH := "res://generated/blender/burgher_house_craft_boda_v1/state.json"
const HOUSE_STYLES := preload("res://scripts/map/view3d/map_view_mesh_builder_house_styles.gd")


func test_craft_boda_production_kit_has_compact_profile_and_budget_evidence() -> void:
	var glb := load(GLB_PATH) as PackedScene
	assert_true(glb != null, "craft_boda production GLB must import as a PackedScene")
	var brief := _read_json(BRIEF_PATH)
	var report := _read_json(REPORT_PATH)
	var state := _read_json(STATE_PATH)
	assert_eq(brief.get("tier"), "craft_boda")
	assert_eq(brief.get("dimensions_m", {}).get("typical_storeys"), 1)
	var features: Dictionary = brief.get("features", {})
	assert_true(bool(features.get("compact_two_room_workshop_dwelling", false)))
	assert_true(bool(features.get("single_hearth_implication", false)))
	assert_true(bool(features.get("modest_street_openings", false)))
	assert_true(bool(features.get("thatch_or_shingle_roof", false)))
	assert_false(bool(features.get("hypocaust", true)))
	assert_false(bool(features.get("hoist_beam", true)))
	assert_false(bool(features.get("granary_crane", true)))
	assert_false(bool(features.get("late_gothic_facade", true)))
	assert_eq(report.get("generator"), "burgher_house_kit_v1")
	assert_true(
		bool(state.get("complete", false)), "generated kit evidence must pass all mesh checks"
	)
	var asset: Dictionary = report.get("assets", {}).get("prop.architecture.house.craft_boda", {})
	assert_true(asset.get("triangles", 10000) < 9000)
	assert_false(bool(asset.get("hoist_default", true)))
	assert_eq(asset.get("roof_default"), "thatch")


func test_craft_boda_runtime_style_contract_is_log_and_thatch() -> void:
	var building := {
		"id": &"craft_boda_contract",
		"house_tier": &"craft_boda",
	}
	assert_eq(HOUSE_STYLES.house_style(building), MapViewMeshBuilderConfig.HOUSE_STYLE_LOG)
	assert_eq(HOUSE_STYLES.roof_style(building), MapViewMeshBuilderConfig.ROOF_STYLE_THATCH)


func test_craft_boda_mesh_builder_uses_imported_production_model() -> void:
	var building := {
		"id": &"craft_boda_runtime",
		"kind": MapTypes.BUILDING_KIND_HOUSE,
		"house_tier": &"craft_boda",
		"footprint": Rect2(0.0, 0.0, 6.5 * 32.0, 7.0 * 32.0),
		"wall_height": 96.0,
		"door_side": &"south",
	}
	var node := MapViewMeshBuilder.build_building(building, MapTypes.DEFAULT_CELL_SIZE)
	var model := node.get_node_or_null("ProductionCraftBoda") as Node3D
	assert_true(model != null, "craft_boda tier must use the imported production GLB")
	if model != null:
		assert_true(model.get_meta(&"production_house_model", false))
		assert_eq(model.get_meta(&"house_tier"), &"craft_boda")
	assert_false(
		node.get_node("Walls").visible, "placeholder walls must be hidden behind the production GLB"
	)
	assert_false(
		node.get_node("Roof").visible, "placeholder roof must be hidden behind the production GLB"
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
