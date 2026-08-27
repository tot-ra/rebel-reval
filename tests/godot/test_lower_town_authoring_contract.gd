extends "res://tests/godot/test_case.gd"

const CONTRACT_PATH := "res://docs/data/lower_town_authoring_contract.json"
const RRMAP_PATH := "res://content/maps/lower_town_slice.rrmap"
const LowerTownSliceDefinition := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")

const REQUIRED_STABLE_ANCHOR_IDS: Array[StringName] = [
	&"street_start",
	&"smithy_door",
	&"brewery_door",
	&"checkpoint_west",
	&"checkpoint_east",
]
const REQUIRED_STABLE_PROP_IDS: Array[StringName] = [&"cistern"]

func test_lower_town_authoring_contract_is_resolved_against_runtime() -> void:
	var contract := _load_json(CONTRACT_PATH)
	assert_eq(contract.get("contract_version"), 1)
	assert_eq(contract.get("map_id"), "lower_town_slice")
	assert_eq(contract.get("source"), "content/maps/lower_town_slice.rrmap")
	var thresholds: Dictionary = contract.get("composition_thresholds", {})
	assert_eq(thresholds.get("map_id"), "lower_town_slice")
	assert_true(bool(thresholds.get("enforce", false)), "lower_town_slice composition enforcement must be explicit")
	assert_eq(thresholds.get("enforcement_state"), "enforced")

	var definition: MapDefinition = LowerTownSliceDefinition.create()
	assert_eq(definition.map_id, &"lower_town_slice")
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	assert_true(parsed.is_ok(), "RRMap source must parse before resolving the authoring contract")
	var source_ids := _source_ids()
	var runtime_ids := _runtime_ids(definition)
	var frontage_rules: Dictionary = contract.get("frontage_rules", {})
	var default_frontage: Dictionary = frontage_rules.get("default", {})
	var frontage_rule_ids: Dictionary = {"default_frontage_m": true}
	assert_eq(default_frontage.get("target_range_m"), [7.0, 11.0])
	assert_eq(default_frontage.get("median_m"), 9)
	for exception in frontage_rules.get("exceptions", []):
		var exception_dict: Dictionary = exception
		frontage_rule_ids[String(exception_dict.get("rule_id", ""))] = true
		assert_eq(exception_dict.get("target_range_m", []).size(), 2)

	for anchor_id in REQUIRED_STABLE_ANCHOR_IDS:
		var anchor_name := String(anchor_id)
		assert_true(
			source_ids["anchor"].has(anchor_name),
			"Stable anchor missing from RRMap source: %s" % anchor_name
		)
		assert_true(
			runtime_ids["anchors"].has(anchor_name),
			"Stable anchor missing from compiled runtime: %s" % anchor_name
		)
	for prop_id in REQUIRED_STABLE_PROP_IDS:
		var prop_name := String(prop_id)
		assert_true(
			source_ids["prop"].has(prop_name),
			"Stable prop missing from RRMap source: %s" % prop_name
		)
		assert_true(
			runtime_ids["props"].has(prop_name),
			"Stable prop missing from compiled runtime: %s" % prop_name
		)

	for sector in contract.get("sectors", []):
		assert_true(sector is Dictionary and not String(sector.get("id", "")).is_empty(), "Every sector needs an id")
		var bounds: Array = sector.get("bounds_cells", [])
		assert_eq(bounds.size(), 4, "Sector bounds must be x,y,width,height")
		assert_true(int(bounds[2]) > 0 and int(bounds[3]) > 0, "Sector bounds must have positive size")
		assert_true(Rect2i(int(bounds[0]), int(bounds[1]), int(bounds[2]), int(bounds[3])).encloses(Rect2i(int(bounds[0]), int(bounds[1]), 1, 1)), "Sector bounds must be valid")
		var ownership: Dictionary = sector.get("ownership", {})
		assert_true(ownership.has("terrain") and ownership.has("buildings") and ownership.has("props"), "Sector ownership must declare terrain/buildings/props")
		for kind in ownership.keys():
			for ref in ownership[kind]:
				assert_true(_kind_ids(kind, source_ids, runtime_ids).has(String(ref)), "%s references unknown %s id %s" % [sector.get("id"), kind, ref])
		var frontage_rule_id := String(sector.get("frontage_rule", ""))
		assert_true(
			frontage_rule_ids.has(frontage_rule_id),
			"%s references unknown frontage rule" % sector.get("id")
		)

	for region in contract.get("open_regions", []):
		assert_true(bool(region.get("exclude_from_unowned_empty_region", false)), "%s must explicitly exclude intentional open space" % region.get("id"))
		assert_true(not String(region.get("reason", "")).is_empty(), "%s needs an open-space reason" % region.get("id"))
		var bounds: Array = region.get("bounds_cells", [])
		assert_eq(bounds.size(), 4, "Open-region bounds must be x,y,width,height")

	for key in ["required_landmarks", "work_anchors", "route_anchors", "patrol_routes", "transitions"]:
		for ref in contract.get(key, []):
			assert_true(_kind_ids(key, source_ids, runtime_ids).has(String(ref)), "%s references unknown %s" % [key, ref])
	for landmark in contract.get("required_landmarks", []):
		assert_true(runtime_ids["landmarks"].has(String(landmark)), "Required landmark is not compiled: %s" % landmark)


func test_lower_town_frontage_rules_and_overrides_are_explicit() -> void:
	var contract := _load_json(CONTRACT_PATH)
	var expected_ranges: Dictionary = {
		"default_frontage_m": [7.0, 11.0],
		"artisan_frontage_m": [5.0, 9.0],
		"institutional_frontage_m": [10.0, 18.0],
		"edge_frontage_m": [4.0, 8.0],
		"harbour_frontage_m": [6.0, 10.0],
		"merchant_irregular_frontage_m": [12.0, 14.0],
	}
	for rule_id_variant in expected_ranges:
		var rule_id := String(rule_id_variant)
		var rule := _frontage_rule(contract, rule_id)
		assert_false(rule.is_empty(), "Missing frontage rule: %s" % rule_id)
		if rule.is_empty():
			continue
		assert_eq(
			rule.get("target_range_m", []),
			expected_ranges[rule_id_variant],
			"Frontage range changed without updating the acceptance contract: %s" % rule_id,
		)
		assert_false(
			String(rule.get("use_for", "")).is_empty(),
			"Frontage rule needs a semantic use: %s" % rule_id,
		)

	var audit: Dictionary = contract.get("frontage_audit", {})
	var rear_service: Dictionary = _string_set(audit.get("rear_service_buildings", []))
	var non_frontage: Dictionary = audit.get("non_frontage_buildings", {})
	assert_true(
		non_frontage.size() > 0,
		"Institutional and service buildings need explicit non-frontage categories",
	)
	for building_id_variant in non_frontage:
		var building_id := String(building_id_variant)
		assert_false(
			rear_service.has(building_id),
			"A building cannot be both rear/service and an explicit non-frontage category: %s" % building_id,
		)
		assert_false(
			String(non_frontage[building_id_variant]).is_empty(),
			"Non-frontage building needs a semantic category: %s" % building_id,
		)
	var source_by_id: Dictionary = {}
	for building in _source_buildings():
		source_by_id[String(building.get("id", ""))] = building
	var overrides: Dictionary = audit.get("rule_overrides", {})
	assert_true(overrides.size() > 0, "Out-of-default public rows need explicit frontage overrides")
	for building_id_variant in overrides:
		var building_id := String(building_id_variant)
		assert_true(
			source_by_id.has(building_id),
			"Frontage override names unknown building: %s" % building_id,
		)
		var override: Dictionary = overrides[building_id_variant]
		var rule_id := String(override.get("rule_id", ""))
		var rule := _frontage_rule(contract, rule_id)
		assert_false(rule.is_empty(), "%s references an undeclared frontage rule" % building_id)
		assert_false(
			String(override.get("reason", "")).is_empty(),
			"%s needs an override reason" % building_id,
		)
		if rule.is_empty():
			continue
		var target: Array = rule.get("target_range_m", [])
		assert_eq(target.size(), 2, "%s override rule needs a two-value range" % building_id)
		if target.size() != 2:
			continue
		var frontage_m := _source_frontage_width(source_by_id[building_id])
		assert_true(frontage_m > 0, "%s override needs a directional house style" % building_id)
		assert_true(
			frontage_m >= float(target[0]) and frontage_m <= float(target[1]),
			"%s width must fit its explicit frontage exception" % building_id,
		)


func test_lower_town_frontage_width_report_is_deterministic() -> void:
	var contract := _load_json(CONTRACT_PATH)
	var audit: Dictionary = contract.get("frontage_audit", {})
	assert_eq(audit.get("cell_to_m"), 1, "Frontage audit uses authored cells as metres")
	var default_rule_id := String(audit.get("default_rule_id", ""))
	assert_eq(default_rule_id, "default_frontage_m")
	var rear_service: Dictionary = _string_set(audit.get("rear_service_buildings", []))
	var non_frontage: Dictionary = audit.get("non_frontage_buildings", {})
	var overrides: Dictionary = audit.get("rule_overrides", {})
	var source_buildings := _source_buildings()
	var source_by_id: Dictionary = {}
	for building in source_buildings:
		source_by_id[String(building.get("id", ""))] = building
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var runtime_ids := _runtime_ids(definition)
	for building_id in rear_service:
		assert_true(
			source_by_id.has(building_id),
			"Rear/service building is missing from RRMap: %s" % building_id
		)
		assert_true(
			runtime_ids["buildings"].has(building_id),
			"Rear/service building is not compiled: %s" % building_id
		)
	for building_id in non_frontage:
		assert_true(
			source_by_id.has(building_id),
			"Non-frontage building is missing from RRMap: %s" % building_id
		)
		assert_true(
			runtime_ids["buildings"].has(building_id),
			"Non-frontage building is not compiled: %s" % building_id
		)

	var tier_counts := {"merchant_stone": 0, "merchant_timber": 0, "craft_boda": 0}
	var public_tier_counts := {"merchant_stone": 0, "merchant_timber": 0, "craft_boda": 0}
	var report: Array[String] = []
	for building in source_buildings:
		var building_id := String(building.get("id", ""))
		var tier := String(building.get("house_tier", ""))
		if tier.is_empty() or non_frontage.has(building_id):
			continue
		assert_true(tier_counts.has(tier), "Unexpected Lower Town house tier: %s" % tier)
		if not tier_counts.has(tier):
			continue
		tier_counts[tier] += 1
		var frontage_m := _source_frontage_width(building)
		assert_true(frontage_m > 0, "%s needs a directional house style for frontage audit" % building_id)
		var override: Dictionary = overrides.get(building_id, {})
		var rule_id := String(override.get("rule_id", default_rule_id))
		var rule := _frontage_rule(contract, rule_id)
		assert_false(rule.is_empty(), "%s references an undeclared frontage rule" % building_id)
		if rule.is_empty():
			continue
		var target: Array = rule.get("target_range_m", [])
		assert_eq(target.size(), 2, "%s frontage rule needs a two-value range" % building_id)
		if target.size() != 2:
			continue
		var in_range := frontage_m >= float(target[0]) and frontage_m <= float(target[1])
		var is_rear_service := rear_service.has(building_id)
		if not is_rear_service:
			public_tier_counts[tier] += 1
		var is_explicit_exception := overrides.has(building_id)
		if is_rear_service:
			if frontage_m < 7 or frontage_m > 11:
				report.append(
					"%s: %dm -> rear_service_non_public (%s)" % [
						building_id,
						frontage_m,
						"rear/service space is excluded from public frontage",
					]
				)
			continue
		if not in_range:
			assert_true(
				is_explicit_exception,
				"%s is outside %s without a documented exception" % [
					building_id,
					default_rule_id,
				]
			)
			if is_explicit_exception:
				report.append(
					"%s: %dm -> %s (%s)" % [
						building_id,
						frontage_m,
						rule_id,
						String(override.get("reason", "")),
					]
				)
		elif is_explicit_exception:
			report.append(
				"%s: %dm -> %s (%s)" % [
					building_id,
					frontage_m,
					rule_id,
					String(override.get("reason", "")),
				]
			)

	for tier_id in tier_counts:
		assert_true(
			int(tier_counts[tier_id]) > 0,
			"Lower Town frontage is missing house tier: %s" % tier_id
		)
		assert_true(
			int(public_tier_counts[tier_id]) > 0,
			"Lower Town public frontage is missing house tier: %s" % tier_id
		)
	assert_true(
		report.size() >= 3,
		"Width report must list rear/service and irregular frontage exceptions"
	)
	for row in report:
		print("LOWER_TOWN_FRONTAGE %s" % row)


func _source_buildings() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var file := FileAccess.open(RRMAP_PATH, FileAccess.READ)
	assert_true(file != null, "Lower Town RRMap source must be readable")
	if file == null:
		return result
	for raw in file.get_as_text().split("\n"):
		var tokens := String(raw).strip_edges().split(" ", false)
		if tokens.size() < 7 or tokens[0] != "building":
			continue
		var building: Dictionary = {
			"id": String(tokens[1]),
			"kind": String(tokens[2]),
			"x": int(tokens[3]),
			"y": int(tokens[4]),
			"w": int(tokens[5]),
			"h": int(tokens[6]),
		}
		for token in tokens.slice(7):
			var pair := String(token).split("=", true, 1)
			if pair.size() == 2:
				building[pair[0]] = pair[1]
		result.append(building)
	return result


func _source_frontage_width(building: Dictionary) -> int:
	var style_tokens := String(building.get("style", "")).split(".")
	if style_tokens.size() < 2:
		return 0
	match style_tokens[1]:
		"north", "south":
			return int(building.get("w", 0))
		"east", "west":
			return int(building.get("h", 0))
	return 0


func _frontage_rule(contract: Dictionary, rule_id: String) -> Dictionary:
	var rules: Dictionary = contract.get("frontage_rules", {})
	if rule_id == "default_frontage_m":
		return rules.get("default", {})
	for exception in rules.get("exceptions", []):
		var candidate: Dictionary = exception
		if String(candidate.get("rule_id", "")) == rule_id:
			return candidate
	return {}


func _string_set(values: Array) -> Dictionary:
	var result := {}
	for value in values:
		result[String(value)] = true
	return result

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	assert_true(file != null, "Missing authoring contract: %s" % path)
	if file == null:
		return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	assert_true(value is Dictionary, "Authoring contract must be a JSON object")
	return value if value is Dictionary else {}



func _source_ids() -> Dictionary:
	var result := {}
	for kind in ["terrain", "building", "prop", "anchor", "landmark", "transition", "patrol"]:
		result[kind] = {}
	var file := FileAccess.open(RRMAP_PATH, FileAccess.READ)
	for raw in file.get_as_text().split("\n"):
		var line := String(raw).strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var tokens := line.split(" ", false)
		if tokens.size() >= 2 and result.has(tokens[0]):
			result[tokens[0]][String(tokens[1])] = true
	return result

func _runtime_ids(definition: MapDefinition) -> Dictionary:
	var result := {"buildings": {}, "props": {}, "anchors": {}, "transitions": {}, "landmarks": {}}
	for row in definition.buildings:
		result["buildings"][String(row.get("id", ""))] = true
	for row in definition.props:
		result["props"][String(row.get("id", ""))] = true
	for row in definition.interaction_anchors:
		result["anchors"][String(row.get("id", ""))] = true
	for row in definition.transitions:
		result["transitions"][String(row.get("id", ""))] = true
	for row in definition.view_landmarks:
		result["landmarks"][String(row.get("id", ""))] = true
	return result

func _kind_ids(kind: String, source_ids: Dictionary, runtime_ids: Dictionary) -> Dictionary:
	if kind == "terrain":
		return source_ids["terrain"]
	if kind == "work_anchors" or kind == "route_anchors":
		return runtime_ids["anchors"]
	if kind == "patrols" or kind == "patrol_routes":
		return source_ids["patrol"]
	if kind == "landmarks" or kind == "required_landmarks":
		return runtime_ids["landmarks"]
	if kind == "transitions":
		return runtime_ids["transitions"]
	if kind == "buildings" or kind == "props" or kind == "anchors":
		return runtime_ids[kind]
	return source_ids.get(kind, {})
