extends "res://tests/godot/test_case.gd"

const CONTRACT_PATH := "res://docs/data/lower_town_authoring_contract.json"
const RRMAP_PATH := "res://content/maps/lower_town_slice.rrmap"
const LowerTownSliceDefinition := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")

func test_lower_town_authoring_contract_is_resolved_against_runtime() -> void:
	var contract := _load_json(CONTRACT_PATH)
	assert_eq(contract.get("contract_version"), 1)
	assert_eq(contract.get("map_id"), "lower_town_slice")
	assert_eq(contract.get("source"), "content/maps/lower_town_slice.rrmap")
	var thresholds: Dictionary = contract.get("composition_thresholds", {})
	assert_eq(thresholds.get("map_id"), "lower_town_slice")
	assert_false(bool(thresholds.get("enforce", true)), "lower_town_slice composition enforcement must remain advisory")

	var definition: MapDefinition = LowerTownSliceDefinition.create()
	assert_eq(definition.map_id, &"lower_town_slice")
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	assert_true(parsed.is_ok(), "RRMap source must parse before resolving the authoring contract")
	var source_ids := _source_ids()
	var runtime_ids := _runtime_ids(definition)

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
		assert_true(not String(sector.get("frontage_rule", "")).is_empty(), "%s needs a frontage rule" % sector.get("id"))

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

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	assert_true(file != null, "Missing authoring contract: %s" % path)
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
	if kind == "patrols" or kind == "patrol_routes":
		return source_ids["patrol"]
	if kind == "landmarks" or kind == "required_landmarks":
		return runtime_ids["landmarks"]
	if kind == "transitions":
		return runtime_ids["transitions"]
	if kind == "buildings" or kind == "props" or kind == "anchors":
		return runtime_ids[kind]
	return source_ids.get(kind, {})
