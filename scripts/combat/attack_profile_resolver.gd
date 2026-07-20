class_name AttackProfileResolver
extends RefCounted

const HAND_SLOTS: Array[StringName] = [&"right_hand", &"left_hand"]
const DEFAULT_CHARGE_THRESHOLD_SEC := 0.35


## Picks the first equipped hand with a content attack profile, otherwise unarmed.
## Equipped forge techniques layer onto the resolved profile (P1-024d).
static func resolve_for_state(
	state: GameState,
	content_db: ContentDB,
	use_charged: bool = false
) -> AttackProfile:
	var profile := _resolve_item_profile(state, content_db, use_charged)
	var technique_id := &""
	if state != null:
		technique_id = state.equipped_forge_technique()
	return ForgeTechnique.apply_equipped(profile, technique_id)


static func _resolve_item_profile(
	state: GameState,
	content_db: ContentDB,
	use_charged: bool
) -> AttackProfile:
	var item_id := equipped_attack_item_id(state, content_db)
	if item_id.is_empty():
		return AttackProfile.unarmed()
	if use_charged and item_has_charged_attack_profile(item_id, content_db):
		return charged_profile_for_item(item_id, content_db)
	if item_has_attack_profile(item_id, content_db):
		return profile_for_item(item_id, content_db)
	return AttackProfile.unarmed()


static func equipped_attack_item_id(state: GameState, content_db: ContentDB) -> StringName:
	if state == null:
		return &""
	for slot: StringName in HAND_SLOTS:
		var item_id := state.equipped_item(slot)
		if item_id.is_empty():
			continue
		if item_has_attack_profile(item_id, content_db) or item_has_charged_attack_profile(item_id, content_db):
			return item_id
	return &""


static func state_supports_charged_attack(state: GameState, content_db: ContentDB) -> bool:
	var item_id := equipped_attack_item_id(state, content_db)
	return item_has_charged_attack_profile(item_id, content_db)


static func charge_threshold_sec_for_state(state: GameState, content_db: ContentDB) -> float:
	var item_id := equipped_attack_item_id(state, content_db)
	return charge_threshold_sec_for_item(item_id, content_db)


static func item_has_attack_profile(item_id: StringName, content_db: ContentDB) -> bool:
	return not _attack_profile_data(item_id, content_db).is_empty()


static func item_has_charged_attack_profile(item_id: StringName, content_db: ContentDB) -> bool:
	return not _charged_attack_profile_data(item_id, content_db).is_empty()


static func profile_for_item(item_id: StringName, content_db: ContentDB) -> AttackProfile:
	return AttackProfile.from_content(_attack_profile_data(item_id, content_db))


static func charged_profile_for_item(item_id: StringName, content_db: ContentDB) -> AttackProfile:
	return AttackProfile.from_content(_charged_attack_profile_data(item_id, content_db))


static func charge_threshold_sec_for_item(item_id: StringName, content_db: ContentDB) -> float:
	var gameplay := _gameplay_data(item_id, content_db)
	return maxf(
		0.01,
		float(gameplay.get("charge_threshold_sec", DEFAULT_CHARGE_THRESHOLD_SEC))
	)


static func _attack_profile_data(item_id: StringName, content_db: ContentDB) -> Dictionary:
	var gameplay := _gameplay_data(item_id, content_db)
	return gameplay.get("attack_profile", {})


static func _charged_attack_profile_data(item_id: StringName, content_db: ContentDB) -> Dictionary:
	var gameplay := _gameplay_data(item_id, content_db)
	return gameplay.get("charged_attack_profile", {})


static func _gameplay_data(item_id: StringName, content_db: ContentDB) -> Dictionary:
	if item_id.is_empty():
		return {}
	var record: Dictionary = {}
	if content_db != null and content_db.is_loaded():
		record = content_db.get_item(item_id)
	if record.is_empty():
		return {}
	return record.get("gameplay", {})
