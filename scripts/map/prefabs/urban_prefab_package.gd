class_name UrbanPrefabPackage
extends RefCounted

## Small reviewed examples for new maps. Lower Town remains on its existing
## definition until a separate parity migration is approved.

const PACKAGE_ID := &"urban"
const HOUSE_ROW := &"urban.house_row"
const WALL_TOWER_SEGMENT := &"urban.wall_tower_segment"
const GATE_COMPOSITION := &"urban.gate_composition"


static func create() -> MapPrefabPackage:
	var package := MapPrefabPackage.new(PACKAGE_ID, 1)
	package.add_prefab(_house_row())
	package.add_prefab(_wall_tower_segment())
	package.add_prefab(_gate_composition())
	return package

static func _house_row() -> MapPrefab:
	var prefab := MapPrefab.new(&"house_row", 1)
	prefab.declare_parameter(&"wall_color", MapPrefab.TYPE_COLOR, Color(0.44, 0.40, 0.34))
	prefab.declare_parameter(&"roof_color", MapPrefab.TYPE_COLOR, Color(0.24, 0.18, 0.14))
	var appearance := {
		"wall_color": MapPrefab.parameter(&"wall_color"),
		"roof_color": MapPrefab.parameter(&"roof_color"),
		"door_side": &"south",
		"ridge_axis": &"z",
	}
	prefab.structure_rect(&"house.west", MapTypes.BUILDING_KIND_HOUSE, Rect2i(0, 0, 4, 3), &"", appearance)
	prefab.structure_rect(&"house.middle", MapTypes.BUILDING_KIND_HOUSE, Rect2i(5, 0, 4, 3), &"", appearance)
	prefab.structure_rect(&"house.east", MapTypes.BUILDING_KIND_HOUSE, Rect2i(10, 0, 4, 3), &"", appearance)
	return prefab


static func _wall_tower_segment() -> MapPrefab:
	var prefab := MapPrefab.new(&"wall_tower_segment", 1)
	prefab.declare_parameter(&"wall_color", MapPrefab.TYPE_COLOR, Color(0.55, 0.54, 0.50))
	prefab.structure_rect(&"wall", MapTypes.BUILDING_KIND_WALL, Rect2i(0, 1, 7, 1), &"", {
		"wall_height": 176.0,
		"wall_color": MapPrefab.parameter(&"wall_color"),
	})
	prefab.structure_rect(&"tower", MapTypes.BUILDING_KIND_WALL, Rect2i(7, 0, 3, 3), &"", {
		"wall_height": 224.0,
		"wall_color": MapPrefab.parameter(&"wall_color"),
	})
	return prefab


static func _gate_composition() -> MapPrefab:
	var prefab := MapPrefab.new(&"gate_composition", 1)
	prefab.declare_parameter(&"wall_color", MapPrefab.TYPE_COLOR, Color(0.55, 0.54, 0.50))
	prefab.instance(&"west", WALL_TOWER_SEGMENT, Vector2i(-9, 0), MapTransform.new(0, true), {
		&"wall_color": MapPrefab.parameter(&"wall_color"),
	})
	prefab.instance(&"east", WALL_TOWER_SEGMENT, Vector2i(9, 0), MapTransform.new(), {
		&"wall_color": MapPrefab.parameter(&"wall_color"),
	})
	prefab.view_landmark(&"arch", &"gate_arch", Rect2i(-1, 1, 3, 1), &"", {
		"wall_color": MapPrefab.parameter(&"wall_color"),
		"passage_axis": &"z",
	})
	return prefab
