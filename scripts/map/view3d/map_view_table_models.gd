class_name MapViewTableModels
extends RefCounted

## Runtime composition for medieval furniture and independent tabletop contents.
##
## One imported kit owns the textured rigid geometry. The map selects exactly one
## base through style_variant and any unique tabletop modules through table_items.
## Legacy fish_splitting_table props call the same path with a documented preset.

const MedievalLightingModels := preload("res://scripts/map/view3d/map_view_medieval_lighting_models.gd")

const TABLE_KIT_SCENE_PATH := "res://assets/props/furniture/tables/medieval_table_kit.glb"
const BASE_ROOT_NAMES: Dictionary = {
	MapPropStyleVariants.TABLE_COMMON_HOUSEHOLD: &"CommonHouseholdTable",
	MapPropStyleVariants.TABLE_TRESTLE_WORK: &"TrestleWorkTable",
	MapPropStyleVariants.TABLE_LONG_BOARD: &"LongBoardTable",
}
const ITEM_ROOT_NAMES: Dictionary = {
	MapTypes.TABLE_ITEM_CUTTING_BOARD: &"CuttingBoardModule",
	MapTypes.TABLE_ITEM_FISH: &"FishModule",
	MapTypes.TABLE_ITEM_KNIFE: &"KnifeModule",
}
const TABLETOP_HEIGHTS: Dictionary = {
	MapPropStyleVariants.TABLE_COMMON_HOUSEHOLD: 0.77,
	MapPropStyleVariants.TABLE_TRESTLE_WORK: 0.82,
	MapPropStyleVariants.TABLE_LONG_BOARD: 0.79,
}
const ITEM_OFFSETS: Dictionary = {
	# Fish and board intentionally share X/Z: their independent modules combine
	# into a convincing work arrangement instead of unrelated countertop clutter.
	MapTypes.TABLE_ITEM_CUTTING_BOARD: Vector3(-0.12, 0.004, 0.0),
	MapTypes.TABLE_ITEM_FISH: Vector3(-0.12, 0.052, 0.0),
	MapTypes.TABLE_ITEM_KNIFE: Vector3(0.36, 0.01, -0.16),
	MapTypes.TABLE_ITEM_CANDLE: Vector3(0.48, 0.004, 0.20),
}
const FISH_SPLITTING_ITEMS := &"cutting_board+fish+knife"


static func add_model(parent: Node3D, prop: Dictionary = {}) -> Node3D:
	var variant := table_variant_for_prop(prop)
	var item_kinds := MapTypes.parse_table_items(
		StringName(prop.get("table_items", MapTypes.TABLE_ITEMS_NONE))
	)
	var scene := load(TABLE_KIT_SCENE_PATH) as PackedScene
	assert(scene != null, "Medieval table GLB must be imported before map assembly")
	var model := scene.instantiate() as Node3D
	assert(model != null, "Medieval table GLB root must be Node3D")
	model.name = "TableModel"
	parent.add_child(model)

	var selected_base_name: StringName = BASE_ROOT_NAMES[variant]
	var selected_items: Array[StringName] = []
	for item_kind in item_kinds:
		if ITEM_ROOT_NAMES.has(item_kind):
			selected_items.append(ITEM_ROOT_NAMES[item_kind])
	_remove_unused_components(model, selected_base_name, selected_items)

	var selected_base := model.find_child(String(selected_base_name), true, false) as Node3D
	assert(selected_base != null, "Medieval table base is missing: %s" % String(selected_base_name))
	selected_base.set_meta(&"table_style_variant", variant)
	var tabletop_height := float(TABLETOP_HEIGHTS[variant])
	for item_kind in item_kinds:
		if item_kind == MapTypes.TABLE_ITEM_CANDLE:
			_add_candle_module(model, tabletop_height)
		else:
			_place_geometry_module(model, item_kind, tabletop_height)

	model.set_meta(&"production_table_model", true)
	model.set_meta(&"table_style_variant", variant)
	model.set_meta(&"table_items", item_kinds.duplicate())
	return model


static func add_fish_splitting_preset(parent: Node3D, prop: Dictionary = {}) -> Node3D:
	var preset := prop.duplicate()
	preset["style_variant"] = prop.get("style_variant", MapPropStyleVariants.TABLE_TRESTLE_WORK)
	preset["table_items"] = prop.get("table_items", FISH_SPLITTING_ITEMS)
	var model := add_model(parent, preset)
	model.set_meta(&"legacy_fish_splitting_preset", true)
	return model


static func table_variant_for_prop(prop: Dictionary) -> StringName:
	var variant := StringName(prop.get("style_variant", MapPropStyleVariants.TABLE_COMMON_HOUSEHOLD))
	return variant if variant in MapPropStyleVariants.TABLE_VARIANTS else MapPropStyleVariants.TABLE_COMMON_HOUSEHOLD


static func _remove_unused_components(
	model: Node3D,
	selected_base_name: StringName,
	selected_item_names: Array[StringName]
) -> void:
	for root_name in BASE_ROOT_NAMES.values():
		if root_name != selected_base_name:
			_remove_component(model, root_name)
	for root_name in ITEM_ROOT_NAMES.values():
		if root_name not in selected_item_names:
			_remove_component(model, root_name)


static func _remove_component(model: Node3D, root_name: StringName) -> void:
	var unused := model.find_child(String(root_name), true, false) as Node3D
	if unused == null:
		return
	unused.get_parent().remove_child(unused)
	unused.free()


static func _place_geometry_module(model: Node3D, item_kind: StringName, tabletop_height: float) -> void:
	assert(ITEM_ROOT_NAMES.has(item_kind), "Unknown geometry table item: %s" % String(item_kind))
	var module_name: StringName = ITEM_ROOT_NAMES[item_kind]
	var module := model.find_child(String(module_name), true, false) as Node3D
	assert(module != null, "Medieval table item root is missing: %s" % String(module_name))
	module.position = Vector3(0.0, tabletop_height, 0.0) + ITEM_OFFSETS[item_kind]
	if item_kind == MapTypes.TABLE_ITEM_KNIFE:
		module.rotation.y = -0.16
	elif item_kind == MapTypes.TABLE_ITEM_FISH:
		module.rotation.y = 0.08
	module.set_meta(&"table_item_kind", item_kind)


static func _add_candle_module(model: Node3D, tabletop_height: float) -> void:
	var slot := Node3D.new()
	slot.name = "CandleModule"
	slot.position = Vector3(0.0, tabletop_height, 0.0) + ITEM_OFFSETS[MapTypes.TABLE_ITEM_CANDLE]
	slot.set_meta(&"table_item_kind", MapTypes.TABLE_ITEM_CANDLE)
	model.add_child(slot)
	# The existing authored tallow model keeps wax, holder, flame, and day/night
	# behavior consistent whether the candle is a standalone prop or table content.
	MedievalLightingModels.add_model(slot, {
		"kind": MapTypes.PROP_KIND_CANDLE,
		"style_variant": MapTypes.DEFAULT_LIGHTING_VARIANT,
	})
