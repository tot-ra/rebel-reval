extends "res://tests/godot/test_case.gd"

## burgher_house_kit_v2 fit contract: variant tables stay in sync with the
## generator reports, bodies are centred on the footprint, storeys keep true
## proportions, and east/west frontages face the lane they are authored on.

const BurgherHouseModels := preload("res://scripts/map/view3d/map_view_burgher_house_models.gd")
const StoneModels := preload("res://scripts/map/view3d/map_view_burgher_house_stone_models.gd")
const BodaModels := preload("res://scripts/map/view3d/map_view_burgher_house_craft_boda_models.gd")
const ServiceModels := preload("res://scripts/map/view3d/map_view_service_building_models.gd")
const LowerTownSliceDefinition := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const SERVICE_REPORT := "res://generated/blender/lower_town_service_buildings_v1/report.json"
const SERVICE_STATE := "res://generated/blender/lower_town_service_buildings_v1/state.json"

const TIERS := {
	&"merchant_stone":
	{
		"report": "res://generated/blender/burgher_house_merchant_stone_v1/report.json",
		"asset_prefix": "prop.architecture.house.merchant_stone",
		"node": "ProductionMerchantStone",
	},
	&"merchant_timber":
	{
		"report": "res://generated/blender/burgher_house_merchant_timber_v1/report.json",
		"asset_prefix": "prop.architecture.house.merchant_timber",
		"node": "ProductionMerchantTimber",
	},
	&"craft_boda":
	{
		"report": "res://generated/blender/burgher_house_craft_boda_v1/report.json",
		"asset_prefix": "prop.architecture.house.craft_boda",
		"node": "ProductionCraftBoda",
	},
}


func test_variant_tables_match_generator_body_dimensions() -> void:
	for tier: StringName in TIERS:
		var report := _read_json(String(TIERS[tier]["report"]))
		var assets: Dictionary = report.get("assets", {})
		var variants := _variants(tier)
		assert_eq(variants.size(), assets.size(), "%s variant table must list every generated GLB" % tier)
		for variant: Dictionary in variants:
			var matched := false
			for asset_id: String in assets:
				var asset: Dictionary = assets[asset_id]
				if StringName(String(asset.get("variant", ""))) != variant["id"]:
					continue
				matched = true
				var body_m: Array = asset.get("body_m", [])
				var body: Vector3 = variant["body"]
				assert_eq(body_m.size(), 3, "%s must report body_m" % asset_id)
				if body_m.size() == 3:
					assert_true(
						body.distance_to(Vector3(body_m[0], body_m[1], body_m[2])) < 0.01,
						"%s body %s drifted from report %s" % [asset_id, body, body_m]
					)
				assert_true(
					String(asset_id).begins_with(String(TIERS[tier]["asset_prefix"])),
					"%s must stay inside the tier asset namespace" % asset_id
				)
				var outlet = asset.get("smoke_outlet_m")
				if outlet is Array:
					assert_true(variant.has("smoke"), "%s has a flue but no smoke outlet" % asset_id)
					if variant.has("smoke"):
						var smoke: Vector3 = variant["smoke"]
						assert_true(
							smoke.distance_to(Vector3(outlet[0], outlet[1], outlet[2])) < 0.01,
							"%s smoke outlet drifted from report %s" % [asset_id, outlet]
						)
				else:
					assert_false(variant.has("smoke"), "%s reports no flue" % asset_id)
				var checks: Dictionary = asset.get("checks", {})
				assert_true(bool(checks.get("body_centred", false)), "%s body must be centred" % asset_id)
				assert_true(
					bool(checks.get("wear_vertex_colours", false)),
					"%s must ship baked wear colours" % asset_id
				)
			assert_true(matched, "%s variant %s has no generated asset" % [tier, variant["id"]])


func test_models_sit_centred_with_true_storey_proportions() -> void:
	for tier: StringName in TIERS:
		var building := {
			"id": StringName("fit_%s" % tier),
			"kind": MapTypes.BUILDING_KIND_HOUSE,
			"house_tier": tier,
			"footprint": Rect2(0.0, 0.0, 9.0 * 32.0, 8.0 * 32.0),
			"wall_height": 112.0,
			"door_side": &"south",
		}
		var node := MapViewMeshBuilder.build_building(building, MapTypes.DEFAULT_CELL_SIZE)
		var model := node.get_node_or_null(String(TIERS[tier]["node"])) as Node3D
		assert_true(model != null, "%s must instantiate its production model" % tier)
		if model != null:
			assert_eq(model.position, Vector3.ZERO, "%s model must be centred on the footprint" % tier)
			assert_true(
				model.scale.y >= BurgherHouseModels.MIN_VERTICAL_SCALE - 0.001
				and model.scale.y <= BurgherHouseModels.MAX_VERTICAL_SCALE + 0.001,
				"%s storeys must keep true proportions, got %s" % [tier, model.scale]
			)
			var body: Vector3 = _variant_by_id(tier, model.get_meta(&"house_variant"))["body"]
			assert_true(
				absf(model.scale.x * body.x - 9.0) < 0.01,
				"%s frontage must fill the 9 m footprint" % tier
			)
			assert_true(absf(model.scale.z * body.z - 8.0) < 0.01, "%s depth must fill the plot" % tier)
			_assert_wear_enabled(model, tier)
		node.free()


func test_east_frontage_fits_footprint_depth_axis_and_faces_east() -> void:
	var building := {
		"id": &"fit_east_stone",
		"kind": MapTypes.BUILDING_KIND_HOUSE,
		"house_tier": &"merchant_stone",
		"footprint": Rect2(0.0, 0.0, 8.0 * 32.0, 10.0 * 32.0),
		"wall_height": 112.0,
		"door_side": &"east",
	}
	var node := MapViewMeshBuilder.build_building(building, MapTypes.DEFAULT_CELL_SIZE)
	var model := node.get_node("ProductionMerchantStone") as Node3D
	var body: Vector3 = _variant_by_id(&"merchant_stone", model.get_meta(&"house_variant"))["body"]
	assert_true(absf(model.scale.x * body.x - 10.0) < 0.01, "east frontage runs along the 10 m side")
	assert_true(absf(model.scale.z * body.z - 8.0) < 0.01, "east plot depth runs along the 8 m side")
	# The kit gable faces model +Z; after the frontage rotation it must face +X.
	var gable_normal := model.transform.basis * Vector3.BACK
	assert_true(gable_normal.normalized().dot(Vector3.RIGHT) > 0.99, "east gable must face +X")
	node.free()


func test_variant_choice_follows_frontage() -> void:
	var narrow := BurgherHouseModels.variant_fit(
		{"id": &"narrow", "door_side": &"south"},
		Vector2(8.0, 8.0),
		StoneModels.MERCHANT_STONE_VARIANTS
	)
	var wide := BurgherHouseModels.variant_fit(
		{"id": &"wide", "door_side": &"north"},
		Vector2(12.0, 8.0),
		StoneModels.MERCHANT_STONE_VARIANTS
	)
	assert_eq(narrow["variant"]["id"], &"coursed_rubble")
	assert_eq(wide["variant"]["id"], &"lime_rendered_wide")
	var boda_wide := BurgherHouseModels.variant_fit(
		{"id": &"boda", "door_side": &"south"}, Vector2(10.0, 6.0), BodaModels.CRAFT_BODA_VARIANTS
	)
	assert_eq(boda_wide["variant"]["id"], &"log_shingle_pentice")
	assert_eq(
		BurgherHouseModels.variant_fit(
			{"id": &"narrow", "door_side": &"south"},
			Vector2(8.0, 8.0),
			StoneModels.MERCHANT_STONE_VARIANTS
		)["variant"]["id"],
		narrow["variant"]["id"],
		"variant choice must be deterministic"
	)


func test_service_building_tables_match_generator_report() -> void:
	var report := _read_json(SERVICE_REPORT)
	var assets: Dictionary = report.get("assets", {})
	var tables := [
		ServiceModels.STONE_STOREHOUSE,
		ServiceModels.BREWHOUSE,
		ServiceModels.PUBLIC_BATH,
		ServiceModels.LOG_BARN,
	]
	assert_eq(tables.size(), assets.size(), "every generated service building needs a table entry")
	for table: Dictionary in tables:
		var asset: Dictionary = assets.get("prop.architecture.building.%s" % table["id"], {})
		assert_false(asset.is_empty(), "%s missing from service report" % table["id"])
		var body_m: Array = asset.get("body_m", [0, 0, 0])
		var body: Vector3 = table["body"]
		assert_true(
			body.distance_to(Vector3(body_m[0], body_m[1], body_m[2])) < 0.01,
			"%s body drifted from report" % table["id"]
		)
		var outlet = asset.get("smoke_outlet_m")
		assert_eq(outlet is Array, table.has("smoke"), "%s smoke outlet presence drifted" % table["id"])
		if outlet is Array and table.has("smoke"):
			var smoke: Vector3 = table["smoke"]
			assert_true(smoke.distance_to(Vector3(outlet[0], outlet[1], outlet[2])) < 0.01)
	assert_true(bool(_read_json(SERVICE_STATE).get("complete", false)), "service kit checks must pass")


func test_lower_town_service_plots_use_production_models_without_tiers() -> void:
	var definition := LowerTownSliceDefinition.create()
	var expected := {
		&"guild_storehouse": &"stone_storehouse",
		&"foaming_mug_brewery": &"brewhouse",
		&"public_bathhouse": &"public_bath",
		&"monastery_barn": &"log_barn",
		&"karja_gate_house": &"log_thatch",
		&"south_apron_wall_walk_hut": &"log_thatch",
		&"muurivahe_house_north": &"log_shingle_pentice",
	}
	var seen := {}
	for building in definition.buildings:
		var building_id := StringName(String(building["id"]))
		if not expected.has(building_id):
			continue
		seen[building_id] = true
		assert_eq(
			building.get("house_tier", &""),
			&"",
			"%s must stay outside the tier allowlist" % building_id
		)
		var node := MapViewMeshBuilder.build_building(building, definition.cell_size)
		var model := node.get_node_or_null(ServiceModels.NODE_NAME) as Node3D
		assert_true(model != null, "%s must use a production exterior" % building_id)
		if model != null:
			assert_eq(model.get_meta(&"house_variant"), expected[building_id])
			assert_false(node.get_node("Walls").visible, "%s placeholder walls must hide" % building_id)
		node.free()
	assert_eq(
		seen.size(),
		expected.size(),
		"every mapped service id must exist in the Lower Town slice"
	)


func _assert_wear_enabled(model: Node, tier: StringName) -> void:
	var instance := model as MeshInstance3D
	if instance != null and instance.mesh != null:
		for surface in instance.mesh.get_surface_count():
			var material := instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if material != null:
				assert_true(
					material.vertex_color_use_as_albedo,
					"%s %s must multiply baked wear into albedo" % [tier, instance.name]
				)
	for child in model.get_children():
		_assert_wear_enabled(child, tier)


func _variants(tier: StringName) -> Array[Dictionary]:
	match tier:
		&"merchant_stone":
			return StoneModels.MERCHANT_STONE_VARIANTS
		&"craft_boda":
			return BodaModels.CRAFT_BODA_VARIANTS
	return BurgherHouseModels.MERCHANT_TIMBER_VARIANTS


func _variant_by_id(tier: StringName, variant_id: Variant) -> Dictionary:
	for variant: Dictionary in _variants(tier):
		if variant["id"] == variant_id:
			return variant
	assert_true(false, "%s has no variant %s" % [tier, variant_id])
	return {"body": Vector3.ONE}


func _read_json(path: String) -> Dictionary:
	# WHY: generated/ is .gdignored so ResourceLoader cannot see rebuild reports;
	# tests still read those JSON files from the project filesystem.
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.READ)
	assert_true(file != null, "missing %s" % path)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	assert_true(parsed is Dictionary, "%s must contain a JSON object" % path)
	return parsed if parsed is Dictionary else {}
