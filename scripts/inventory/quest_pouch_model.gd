class_name QuestPouchModel
extends RefCounted

## Resolves the capped quest-tool strip shown beside the satchel (P2-015).
## Content marks eligible tools with `gameplay.visible_in_pouch`; possession covers
## bag cells, equipped slots, quest ownership flags, and forged commission objects.

const MAX_VISIBLE_SLOTS := 3


static func visible_item_ids(state: GameState, content_db: ContentDB) -> Array[StringName]:
	if state == null or content_db == null:
		return []

	var visible: Array[StringName] = []
	var seen: Dictionary = {}

	for item_id: StringName in state.get_owned_item_ids_in_order():
		_append_visible(visible, seen, state, content_db, item_id)

	for slot: StringName in state.equipped_slots():
		_append_visible(visible, seen, state, content_db, state.equipped_item(slot))

	for placement in state.bag.placements:
		_append_visible(visible, seen, state, content_db, placement.item_id)

	for record in state.get_forged_records():
		_append_visible(visible, seen, state, content_db, record.item_id)

	if visible.size() > MAX_VISIBLE_SLOTS:
		return visible.slice(0, MAX_VISIBLE_SLOTS)
	return visible


static func _append_visible(
	visible: Array[StringName],
	seen: Dictionary,
	state: GameState,
	content_db: ContentDB,
	item_id: StringName
) -> void:
	if item_id.is_empty() or seen.has(item_id):
		return
	if not _is_visible_in_pouch(content_db, item_id):
		return
	if not _player_carries_quest_tool(state, item_id):
		return
	seen[item_id] = true
	visible.append(item_id)


static func _is_visible_in_pouch(content_db: ContentDB, item_id: StringName) -> bool:
	var record: Dictionary = content_db.get_item(item_id)
	if record.is_empty():
		return false
	var gameplay: Variant = record.get("gameplay", {})
	if not gameplay is Dictionary:
		return false
	return bool((gameplay as Dictionary).get("visible_in_pouch", false))


static func _player_carries_quest_tool(state: GameState, item_id: StringName) -> bool:
	if state.possesses_item(item_id):
		return true
	for record in state.get_forged_records():
		if record.item_id == item_id:
			return true
	return false
