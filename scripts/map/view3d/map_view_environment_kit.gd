class_name MapViewEnvironmentKit
extends RefCounted

## Reusable view-only assemblies for the P0-102b forge and street/well kit.
##
## WHY: these spaces already have stable RRMap records and individual prop/building
## builders. Keeping the composition here makes the shared family explicit without
## inventing a semantic RRMap primitive or moving collision/navigation ownership
## out of MapDefinition and MapBuilder.

const MeshBuilder := preload("res://scripts/map/view3d/map_view_mesh_builder.gd")

const MODULE_FORGE_INTERIOR := &"forge_interior"
const MODULE_FORGE_YARD := &"forge_yard"
const MODULE_STREET_WELL := &"street_well"
const MODULE_BREWERY := &"brewery"
const MODULE_CHECKPOINT := &"checkpoint"
const MODULE_IDS: Array[StringName] = [
	MODULE_FORGE_INTERIOR,
	MODULE_FORGE_YARD,
	MODULE_STREET_WELL,
	MODULE_BREWERY,
	MODULE_CHECKPOINT,
]


## Returns deterministic authoring errors before a module reaches mesh assembly.
## WHY: silently skipping a renamed or duplicated RRMap record produces a plausible
## but incomplete acceptance capture. The shared kit therefore fails closed at its
## authored-record boundary while gameplay collision/navigation remain map-owned.
static func validate_module(definition: MapDefinition, module_id: StringName) -> Array[String]:
	var errors: Array[String] = []
	if not MODULE_IDS.has(module_id):
		return ["unknown environment module: %s" % String(module_id)]
	var contract := _module_contract(module_id)
	_validate_selectors(definition.buildings, contract["buildings"], "building", errors)
	_validate_ids(definition.props, contract["props"], "prop", errors)
	_validate_ids(definition.view_landmarks, contract["landmarks"], "landmark", errors)
	return errors


static func build_forge_interior(definition: MapDefinition) -> Node3D:
	return _build_catalog_module(definition, MODULE_FORGE_INTERIOR)


static func build_forge_yard(definition: MapDefinition) -> Node3D:
	return _build_catalog_module(definition, MODULE_FORGE_YARD)


static func build_street_well(definition: MapDefinition) -> Node3D:
	return _build_catalog_module(definition, MODULE_STREET_WELL)


static func build_brewery(definition: MapDefinition) -> Node3D:
	return _build_catalog_module(definition, MODULE_BREWERY)


static func build_checkpoint(definition: MapDefinition) -> Node3D:
	var root := _build_catalog_module(definition, MODULE_CHECKPOINT)
	var landmarks := Node3D.new()
	landmarks.name = "Landmarks"
	_build_group_metadata(landmarks, &"landmarks")
	root.add_child(landmarks)
	for landmark in definition.view_landmarks:
		if landmark.get("id", &"") not in [&"viru_gate_arch", &"viru_foregate_arch"]:
			continue
		landmarks.add_child(MeshBuilder.build_landmark(landmark, definition.cell_size))
	return root


static func _build_catalog_module(definition: MapDefinition, module_id: StringName) -> Node3D:
	var contract := _module_contract(module_id)
	return _build_module(definition, module_id, contract["buildings"], contract["props"])


static func _build_module(
	definition: MapDefinition,
	module_id: StringName,
	building_selectors: Array[StringName],
	prop_ids: Array[StringName]
) -> Node3D:
	var contract_errors := validate_module(definition, module_id)
	assert(
		contract_errors.is_empty(),
		"Environment kit contract failed for %s: %s" % [String(module_id), "; ".join(contract_errors)]
	)
	var root := Node3D.new()
	root.name = "EnvironmentKit_%s" % String(module_id)
	root.set_meta(&"environment_module", module_id)
	root.set_meta(&"view_only", true)

	var buildings := Node3D.new()
	buildings.name = "Buildings"
	# WHY: child groups are reusable assembly boundaries. Keeping the view-only
	# contract on each group prevents future callers from treating a subtree as
	# gameplay geometry when modules are embedded into larger previews.
	_build_group_metadata(buildings, &"buildings")
	root.add_child(buildings)
	for building in definition.buildings:
		if not _matches_building(building, building_selectors):
			continue
		buildings.add_child(
			MeshBuilder.build_building(
				building, definition.cell_size, [], Rect2(Vector2.ZERO, definition.world_size())
			)
		)

	var props := Node3D.new()
	props.name = "Props"
	_build_group_metadata(props, &"props")
	root.add_child(props)
	for prop_id in prop_ids:
		var prop := _record_by_id(definition.props, prop_id)
		if prop.is_empty():
			continue
		props.add_child(MeshBuilder.build_prop(prop, definition.cell_size, definition))
	return root


static func _build_group_metadata(group: Node3D, group_id: StringName) -> void:
	# WHY: each reusable subtree must carry the same boundary contract as its
	# module root, so consumers can inspect a group without guessing ownership.
	group.set_meta(&"view_only", true)
	group.set_meta(&"environment_group", group_id)


static func _module_contract(module_id: StringName) -> Dictionary:
	match module_id:
		MODULE_FORGE_INTERIOR:
			return {
				"buildings": [&"wall.north_forge", &"wall.south_forge", &"wall.divider"],
				"props": [
					&"forge_anvil", &"forge_furnace", &"forge_bellows", &"forge_tongs",
					&"forge_hammer", &"forge_punch", &"quench", &"coal_store", &"iron_scrap_store",
				],
				"landmarks": [],
			}
		MODULE_FORGE_YARD:
			return {
				"buildings": [&"kalev_smithy", &"smithy_yard_fence_north", &"smithy_yard_fence_east"],
				"props": [&"courtyard_firewood", &"courtyard_quench", &"hay_store"],
				"landmarks": [],
			}
		MODULE_STREET_WELL:
			return {
				"buildings": [],
				"props": [&"cistern", &"cistern_wash_tub", &"monastery_well"],
				"landmarks": [],
			}
		MODULE_BREWERY:
			return {
				"buildings": [&"foaming_mug_brewery"],
				"props": [&"brewery_keg_stack", &"brewery_malt_sacks", &"evidence_barrels"],
				"landmarks": [],
			}
		MODULE_CHECKPOINT:
			return {
				"buildings": [&"viru_gate_north_tower", &"viru_gate_south_tower"],
				"props": [&"market_stall_gate", &"gate_cart"],
				"landmarks": [&"viru_gate_arch", &"viru_foregate_arch"],
			}
	return {}


static func _validate_selectors(
	records: Array[Dictionary], selectors: Array, record_kind: String, errors: Array[String]
) -> void:
	for selector_value in selectors:
		var selector := StringName(selector_value)
		var matches := 0
		for record in records:
			var record_id := StringName(record.get("id", &""))
			if record_id == selector or String(record_id).begins_with("%s/" % String(selector)):
				matches += 1
		if matches == 0:
			errors.append("missing %s selector: %s" % [record_kind, String(selector)])


static func _validate_ids(
	records: Array[Dictionary], required_ids: Array, record_kind: String, errors: Array[String]
) -> void:
	for required_value in required_ids:
		var required_id := StringName(required_value)
		var matches := 0
		for record in records:
			if StringName(record.get("id", &"")) == required_id:
				matches += 1
		if matches == 0:
			errors.append("missing %s: %s" % [record_kind, String(required_id)])
		elif matches > 1:
			errors.append("duplicate %s: %s" % [record_kind, String(required_id)])


static func _matches_building(building: Dictionary, selectors: Array[StringName]) -> bool:
	var building_id := StringName(building.get("id", &""))
	for selector in selectors:
		if building_id == selector or String(building_id).begins_with("%s/" % String(selector)):
			return true
	return false


static func _record_by_id(records: Array, record_id: StringName) -> Dictionary:
	for record in records:
		if record.get("id", &"") == record_id:
			return record
	return {}
