class_name AttackProfileResolver
extends RefCounted

const HAND_SLOTS: Array[StringName] = [&"right_hand", &"left_hand"]


## Picks the first equipped hand with a content attack profile, otherwise unarmed.
static func resolve_for_state(state: GameState, content_db: ContentDB) -> AttackProfile:
	if state == null:
		return AttackProfile.unarmed()
	for slot: StringName in HAND_SLOTS:
		var item_id := state.equipped_item(slot)
		if item_id.is_empty():
			continue
		if item_has_attack_profile(item_id, content_db):
			return profile_for_item(item_id, content_db)
	return AttackProfile.unarmed()


static func item_has_attack_profile(item_id: StringName, content_db: ContentDB) -> bool:
	return not _attack_profile_data(item_id, content_db).is_empty()


static func profile_for_item(item_id: StringName, content_db: ContentDB) -> AttackProfile:
	return AttackProfile.from_content(_attack_profile_data(item_id, content_db))


static func _attack_profile_data(item_id: StringName, content_db: ContentDB) -> Dictionary:
	if item_id.is_empty():
		return {}
	var record: Dictionary = {}
	if content_db != null and content_db.is_loaded():
		record = content_db.get_item(item_id)
	if record.is_empty():
		return {}
	var gameplay: Dictionary = record.get("gameplay", {})
	return gameplay.get("attack_profile", {})
