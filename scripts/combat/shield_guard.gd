class_name ShieldGuard
extends RefCounted

## A shield in the off hand (item gameplay.shield_guard, task R-1755) replaces the
## bearer's guard numbers: a cheaper braced guard and a wider parry window. Without
## one the CombatVitals defaults apply. Applied right before an incoming hit
## resolves, so equipping or dropping the shield needs no extra bookkeeping.

const SHIELD_SLOT := &"left_hand"


static func apply(vitals: CombatVitals, state: GameState, content_db: ContentDB) -> void:
	if vitals == null:
		return
	var guard := guard_for_state(state, content_db)
	vitals.guard_stamina_per_damage = float(
		guard.get("guard_stamina_per_damage", CombatVitals.DEFAULT_GUARD_STAMINA_PER_DAMAGE)
	)
	vitals.parry_window_sec = float(
		guard.get("parry_window_sec", CombatVitals.DEFAULT_PARRY_WINDOW_SEC)
	)


## The equipped shield's guard numbers, or {} when the off hand holds no shield.
static func guard_for_state(state: GameState, content_db: ContentDB) -> Dictionary:
	if state == null or content_db == null or not content_db.is_loaded():
		return {}
	var item_id := state.equipped_item(SHIELD_SLOT)
	if item_id.is_empty():
		return {}
	var gameplay: Dictionary = content_db.get_item(item_id).get("gameplay", {})
	return gameplay.get("shield_guard", {})
