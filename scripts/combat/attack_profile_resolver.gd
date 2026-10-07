class_name AttackProfileResolver
extends RefCounted

const HAND_SLOTS: Array[StringName] = [&"right_hand", &"left_hand"]
const DEFAULT_CHARGE_THRESHOLD_SEC := 0.35
## Legacy items without `gameplay.weapon_class` keep their class through the
## animation id they already author (`hammer_attack` -> hammer).
const CLASS_BY_ANIMATION_PREFIX: Dictionary = {
	"hammer": CombatMoveCatalog.CLASS_HAMMER,
	"sword": CombatMoveCatalog.CLASS_SWORD,
	"spear": CombatMoveCatalog.CLASS_SPEAR,
}


## Light step 0 (or the heavy move) of the equipped weapon's move set.
## Equipped forge techniques layer onto the resolved profile (P1-024d).
static func resolve_for_state(
	state: GameState,
	content_db: ContentDB,
	use_charged: bool = false,
	build: StringName = CombatMoveCatalog.BUILD_ADULT
) -> AttackProfile:
	return resolve_move(state, content_db, use_charged, 0, build)


## The profile of one move in the equipped weapon's chain (COMBAT_ANIMATION.md):
## the item owns base damage/reach/stamina/type, the move owns clip, timing and
## per-step multipliers. A heavy move starts from the item's charged profile
## when it authors one.
static func resolve_move(
	state: GameState,
	content_db: ContentDB,
	heavy: bool,
	combo_step: int,
	build: StringName = CombatMoveCatalog.BUILD_ADULT
) -> AttackProfile:
	var item_id := equipped_attack_item_id(state, content_db)
	var weapon_class := weapon_class_for_item(item_id, content_db)
	var move := (
		CombatMoveCatalog.heavy_move(weapon_class, build)
		if heavy
		else CombatMoveCatalog.light_move(weapon_class, combo_step, build)
	)
	var base := _base_profile(item_id, content_db, heavy)
	var authored_heavy := heavy and item_has_charged_attack_profile(item_id, content_db)
	var profile := base.duplicate_profile()
	profile.animation = move.id
	profile.impact_timing_sec = move.impact_sec
	profile.attack_duration_sec = move.duration_sec
	profile.cancel_sec = move.cancel_sec
	profile.lunge_px = move.lunge_px
	profile.weapon_class = weapon_class
	profile.combo_step = (
		0 if heavy else posmod(combo_step, CombatMoveCatalog.combo_length(weapon_class))
	)
	profile.is_heavy = heavy
	# An authored charged profile already carries the heavy numbers.
	if not authored_heavy:
		profile.damage = base.damage * move.damage_mult
		profile.reach_px = base.reach_px * move.reach_mult
		profile.stamina_cost = base.stamina_cost * move.stamina_mult
	# Body build scales the finished numbers, also an authored charged profile (SD-11).
	profile.damage *= CombatMoveCatalog.build_factor(build, "damage")
	profile.reach_px *= CombatMoveCatalog.build_factor(build, "reach")
	profile.stamina_cost *= CombatMoveCatalog.build_factor(build, "stamina")
	if not is_nan(move.facing_dot):
		profile.facing_dot = move.facing_dot
	profile.pierces_guard = profile.pierces_guard or move.pierces_guard
	var technique_id := &""
	if state != null:
		technique_id = state.equipped_forge_technique()
	return ForgeTechnique.apply_equipped(profile, technique_id)


static func weapon_class_for_state(state: GameState, content_db: ContentDB) -> StringName:
	return weapon_class_for_item(equipped_attack_item_id(state, content_db), content_db)


static func weapon_class_for_item(item_id: StringName, content_db: ContentDB) -> StringName:
	if item_id.is_empty():
		return CombatMoveCatalog.CLASS_UNARMED
	var gameplay := _gameplay_data(item_id, content_db)
	var authored := StringName(String(gameplay.get("weapon_class", "")))
	if CombatMoveCatalog.is_weapon_class(authored):
		return authored
	var animation := String(_attack_profile_data(item_id, content_db).get("animation", ""))
	for prefix: String in CLASS_BY_ANIMATION_PREFIX:
		if animation.begins_with(prefix):
			return CLASS_BY_ANIMATION_PREFIX[prefix]
	return CombatMoveCatalog.CLASS_UNARMED


static func _base_profile(item_id: StringName, content_db: ContentDB, heavy: bool) -> AttackProfile:
	if item_id.is_empty():
		return AttackProfile.unarmed()
	if heavy and item_has_charged_attack_profile(item_id, content_db):
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
		if (
			item_has_attack_profile(item_id, content_db)
			or item_has_charged_attack_profile(item_id, content_db)
		):
			return item_id
	return &""


## Every move set has a heavy strike (COMBAT_ANIMATION.md), so holding the
## attack input always charges. Kept as a query so callers stay data-driven.
static func state_supports_charged_attack(state: GameState, content_db: ContentDB) -> bool:
	return CombatMoveCatalog.is_weapon_class(weapon_class_for_state(state, content_db))


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
	return maxf(0.01, float(gameplay.get("charge_threshold_sec", DEFAULT_CHARGE_THRESHOLD_SEC)))


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
