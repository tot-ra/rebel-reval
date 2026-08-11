class_name MapViewMarketStallModels
extends RefCounted

## Shared access to the authored portable market stall. Every `stall` prop keeps
## its map-owned footprint and gameplay behavior while reusing one coherent model.
## Countertop goods are independent modules selected by the rrmap `display_goods`
## field, so the frame never needs trade-specific duplicate GLBs.

const DisplayGoods := preload("res://scripts/map/view3d/map_view_market_stall_display_goods.gd")

const MARKET_STALL_SCENE_PATH := "res://assets/props/market/market_stall.glb"
const MODEL_SCALE := 1.5
const COUNTERTOP_HEIGHT := 0.84 * MODEL_SCALE
const SLOT_POSITIONS: Array[Vector3] = [
	Vector3(-0.66, COUNTERTOP_HEIGHT + 0.025, -0.15),
	Vector3(0.0, COUNTERTOP_HEIGHT + 0.025, -0.15),
	Vector3(0.66, COUNTERTOP_HEIGHT + 0.025, -0.15),
]
const MODULE_SCALES: Dictionary = {
	1: 1.0,
	2: 0.86,
	3: 0.72,
}


static func add_model(parent: Node3D, prop: Dictionary = {}) -> Node3D:
	var scene := load(MARKET_STALL_SCENE_PATH) as PackedScene
	assert(scene != null, "Market stall GLB must be imported before map assembly")
	var model := scene.instantiate() as Node3D
	assert(model != null, "Market stall GLB root must be Node3D")
	model.name = "MarketStallModel"
	model.scale = Vector3.ONE * MODEL_SCALE
	model.set_meta(&"production_market_stall_model", true)
	model.set_meta(&"market_stall_model_scale", MODEL_SCALE)
	parent.add_child(model)

	var goods_kinds := MapTypes.parse_market_stall_goods(
		StringName(prop.get("display_goods", MapTypes.MARKET_STALL_GOODS_NONE))
	)
	_add_display_modules(model, goods_kinds)
	return model


static func _add_display_modules(model: Node3D, goods_kinds: Array[StringName]) -> void:
	var display := Node3D.new()
	display.name = "CountertopDisplay"
	# WHY: goods are real-size swappable modules while the frame alone is enlarged.
	display.scale = Vector3.ONE / MODEL_SCALE
	display.set_meta(&"display_goods", goods_kinds.duplicate())
	model.add_child(display)
	if goods_kinds.is_empty():
		return

	var count := goods_kinds.size()
	var slot_indices: Array[int]
	match count:
		1:
			slot_indices = [1]
		2:
			slot_indices = [0, 2]
		_:
			slot_indices = [0, 1, 2]
	var module_scale := float(
		MODULE_SCALES.get(count, MODULE_SCALES[MapTypes.MARKET_STALL_MAX_DISPLAY_MODULES])
	)
	for index in count:
		var slot := Node3D.new()
		slot.name = "Slot%d" % index
		slot.position = SLOT_POSITIONS[slot_indices[index]]
		slot.set_meta(&"market_stall_slot_index", index)
		display.add_child(slot)
		var module := DisplayGoods.add_module(slot, goods_kinds[index])
		module.scale = Vector3.ONE * module_scale
