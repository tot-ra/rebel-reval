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


static func build_forge_interior(definition: MapDefinition) -> Node3D:
	return _build_module(
		definition,
		MODULE_FORGE_INTERIOR,
		[&"wall.north_forge", &"wall.south_forge", &"wall.divider"],
		[
			&"forge_anvil",
			&"forge_furnace",
			&"forge_bellows",
			&"forge_tongs",
			&"forge_hammer",
			&"forge_punch",
			&"quench",
			&"coal_store",
			&"iron_scrap_store",
		]
	)


static func build_forge_yard(definition: MapDefinition) -> Node3D:
	return _build_module(
		definition,
		MODULE_FORGE_YARD,
		[&"kalev_smithy", &"smithy_yard_fence_north", &"smithy_yard_fence_east"],
		[&"courtyard_firewood", &"courtyard_quench", &"hay_store"]
	)


static func build_street_well(definition: MapDefinition) -> Node3D:
	return _build_module(
		definition,
		MODULE_STREET_WELL,
		[],
		[&"cistern", &"cistern_wash_tub", &"monastery_well"]
	)


static func _build_module(
	definition: MapDefinition,
	module_id: StringName,
	building_selectors: Array[StringName],
	prop_ids: Array[StringName]
) -> Node3D:
	var root := Node3D.new()
	root.name = "EnvironmentKit_%s" % String(module_id)
	root.set_meta(&"environment_module", module_id)
	root.set_meta(&"view_only", true)

	var buildings := Node3D.new()
	buildings.name = "Buildings"
	root.add_child(buildings)
	for building in definition.buildings:
		if not _matches_building(building, building_selectors):
			continue
		buildings.add_child(
			MeshBuilder.build_building(
				building,
				definition.cell_size,
				[],
				Rect2(Vector2.ZERO, definition.world_size())
			)
		)

	var props := Node3D.new()
	props.name = "Props"
	root.add_child(props)
	for prop_id in prop_ids:
		var prop := _record_by_id(definition.props, prop_id)
		if prop.is_empty():
			continue
		props.add_child(MeshBuilder.build_prop(prop, definition.cell_size, definition))
	return root


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
