class_name InventoryEquipmentInteraction
extends RefCounted

## Keeps equipment-slot rules separate from InventoryOverlay's packed-grid state.
## The overlay remains the UI facade so existing scene callbacks stay stable.

const EquipmentSilhouetteScene := preload("res://scripts/inventory/equipment_silhouette.gd")

const DRAG_KIND_BAG := &"bag"
const DRAG_KIND_EQUIPPED := &"equipped"

const DROP_NOOP := 0
const DROP_REFRESH := 1
const DROP_CLEAR_SELECTION := 2

var _state: GameState
var _item_record_provider: Callable = Callable()
var _item_icon_provider: Callable = Callable()
var _short_label_provider: Callable = Callable()


func configure(
	state: GameState,
	item_record_provider: Callable,
	item_icon_provider: Callable,
	short_label_provider: Callable
) -> void:
	_state = state
	_item_record_provider = item_record_provider
	_item_icon_provider = item_icon_provider
	_short_label_provider = short_label_provider


func configure_state(state: GameState) -> void:
	_state = state


func refresh(silhouette: Control, equip_button: Button, selected: InventoryPlacement) -> void:
	equip_button.visible = false
	if silhouette == null:
		return

	var equipped: Dictionary[StringName, StringName] = {}
	if _state != null:
		for slot: StringName in EquipmentSilhouetteScene.SLOT_ORDER:
			var item_id := _state.equipped_item(slot)
			if not String(item_id).is_empty():
				equipped[slot] = item_id
	silhouette.set_equipped(equipped)

	var highlight: Array[StringName] = []
	if selected != null:
		var equip_info := equip_info(selected.item_id)
		if not equip_info.is_empty():
			var slot := StringName(String(equip_info.get("slot", "")))
			if not slot.is_empty():
				highlight.append(slot)
			equip_button.visible = true
			equip_button.text = "Equip to %s" % String(equip_info.get("slot", "")).replace("_", " ")
	silhouette.set_highlight_slots(highlight)


func can_drop_on_slot(slot: StringName, data: Dictionary) -> bool:
	if _state == null:
		return false
	var kind: StringName = data.get("kind", &"")
	if kind == DRAG_KIND_BAG:
		var placement: InventoryPlacement = data.get("placement")
		return placement != null and slot_accepts_item(slot, placement.item_id)
	if kind == DRAG_KIND_EQUIPPED:
		var from_slot: StringName = data.get("slot", &"")
		var item_id: StringName = data.get("item_id", &"")
		return (
			from_slot != slot
			and not String(item_id).is_empty()
			and slot_accepts_item(slot, item_id)
		)
	return false


## Returns an outcome so the UI facade preserves its current refresh behavior.
func drop_on_slot(slot: StringName, data: Dictionary) -> int:
	if _state == null:
		return DROP_NOOP
	var kind: StringName = data.get("kind", &"")
	if kind == DRAG_KIND_BAG:
		var placement: InventoryPlacement = data.get("placement")
		if placement != null and _state.equip_from_bag(slot, placement.item_id):
			return DROP_CLEAR_SELECTION
		return DROP_REFRESH
	if kind == DRAG_KIND_EQUIPPED:
		var from_slot: StringName = data.get("slot", &"")
		var item_id: StringName = data.get("item_id", &"")
		if from_slot.is_empty() or from_slot == slot:
			return DROP_NOOP
		if not _state.unequip_to_bag(from_slot):
			return DROP_NOOP
		if not _state.equip_from_bag(slot, item_id):
			_state.equip_from_bag(from_slot, item_id)
		return DROP_CLEAR_SELECTION
	return DROP_REFRESH


func try_equip_selected(slot: StringName, selected: InventoryPlacement) -> bool:
	return (
		selected != null
		and slot_accepts_item(slot, selected.item_id)
		and _state != null
		and _state.equip_from_bag(slot, selected.item_id)
	)


func has_equipped_item(slot: StringName) -> bool:
	return _state != null and not String(_state.equipped_item(slot)).is_empty()


func unequip_to_bag(slot: StringName) -> void:
	if _state != null:
		_state.unequip_to_bag(slot)


func equip_selected(selected: InventoryPlacement) -> bool:
	if _state == null or selected == null:
		return false
	var equip_info := equip_info(selected.item_id)
	if equip_info.is_empty():
		return false
	var slot := StringName(String(equip_info.get("slot", "")))
	return _state.equip_from_bag(slot, selected.item_id)


func equip_info(item_id: StringName) -> Dictionary:
	var record := _item_record(item_id)
	var gameplay: Dictionary = record.get("gameplay", {})
	return gameplay.get("equip", {})


func slot_accepts_item(slot: StringName, item_id: StringName) -> bool:
	var item_equip_info := equip_info(item_id)
	return (
		not item_equip_info.is_empty()
		and StringName(String(item_equip_info.get("slot", ""))) == slot
	)


func equipped_item_label(item_id: StringName) -> String:
	var record := _item_record(item_id)
	return String(record.get("name", String(item_id)))


func equipped_item_icon(item_id: StringName) -> Texture2D:
	if not _item_icon_provider.is_valid():
		return null
	return _item_icon_provider.call(_item_record(item_id)) as Texture2D


func equipped_slot_short_label(item_id: StringName) -> String:
	if not _short_label_provider.is_valid():
		return String(item_id)
	return String(_short_label_provider.call(_item_record(item_id), 1))


func _item_record(item_id: StringName) -> Dictionary:
	if not _item_record_provider.is_valid():
		return {"name": String(item_id), "category": "supply"}
	return _item_record_provider.call(item_id) as Dictionary
