class_name CombatMoveCatalog
extends RefCounted

## Player move sets per weapon class plus the evade, cast and hit actions.
## Design authority: docs/SYSTEMS/COMBAT_ANIMATION.md (task R-1161).
##
## WHY code, not content JSON: every row is tied to a specific source clip in
## the shared 76-clip library and its measured contact frame, so it changes
## with the rig, not with item balance. Items keep owning base damage, reach,
## stamina and damage type (`gameplay.attack_profile`); a move only scales them.
## Light step 1 and the heavy move of the hammer and sword deliberately repeat
## the item JSON timing so existing balance and tests keep one answer.

const CLASS_UNARMED := &"unarmed"
const CLASS_HAMMER := &"hammer"
const CLASS_SWORD := &"sword"
const CLASS_SPEAR := &"spear"
const WEAPON_CLASSES: Array[StringName] = [CLASS_UNARMED, CLASS_HAMMER, CLASS_SWORD, CLASS_SPEAR]

## Grace after recovery during which a new light attack still continues the
## chain instead of restarting it (Witcher-style rhythm, not button mashing).
const COMBO_GRACE_SEC := 0.3
## A dodge or roll may cut a swing's follow-through this long after impact.
const EVADE_CANCEL_AFTER_IMPACT_SEC := 0.06

## Body builds (ADR 0033, SD-11). The adult master smith is the baseline every move row was
## measured for; the teen apprentice reuses the same clips, quicker, lighter and shorter.
const BUILD_ADULT := &"adult"
const BUILD_TEEN := &"teen"
const BUILD_ADJUST: Dictionary = {
	BUILD_ADULT: {"timing": 1.0, "lunge": 1.0, "damage": 1.0, "reach": 1.0, "stamina": 1.0},
	BUILD_TEEN: {"timing": 0.92, "lunge": 0.85, "damage": 0.8, "reach": 0.93, "stamina": 1.15},
}
const TEEN_CHARACTER_IDS: Array[StringName] = [&"char.apprentice"]

const ROLL_FORWARD := &"roll_forward"
const ROLL_BACKWARD := &"roll_backward"
const CAST_PROJECTILE := &"cast_projectile"
const CAST_SELF := &"cast_self"
const CAST_AREA := &"cast_area"

## Source contact seconds were measured on the shared skeleton (peak hand.r
## speed / furthest reach; foot.r for the kick). See COMBAT_ANIMATION.md §4.
const MOVE_SETS: Dictionary = {
	CLASS_UNARMED: {
		"light": [
			{"id": &"unarmed_attack", "impact_sec": 0.22, "duration_sec": 0.55, "cancel_sec": 0.36,
				"hit_stop_sec": 0.03, "source_contact_sec": 0.48, "lunge_px": 8.0},
			{"id": &"unarmed_attack_2", "impact_sec": 0.24, "duration_sec": 0.58, "cancel_sec": 0.38,
				"hit_stop_sec": 0.03, "source_contact_sec": 0.52, "lunge_px": 10.0},
			{"id": &"unarmed_attack_3", "impact_sec": 0.28, "duration_sec": 0.68, "cancel_sec": 0.50,
				"hit_stop_sec": 0.05, "source_contact_sec": 0.36, "damage_mult": 1.4,
				"stamina_mult": 1.3, "lunge_px": 14.0},
		],
		"heavy": {"id": &"unarmed_heavy_attack", "impact_sec": 0.42, "duration_sec": 0.88,
			"cancel_sec": 0.70, "hit_stop_sec": 0.07, "source_contact_sec": 0.36,
			"damage_mult": 1.8, "stamina_mult": 1.6, "reach_mult": 1.1, "lunge_px": 18.0},
	},
	CLASS_HAMMER: {
		"light": [
			{"id": &"hammer_attack", "impact_sec": 0.34, "duration_sec": 0.76, "cancel_sec": 0.52,
				"hit_stop_sec": 0.055, "source_contact_sec": 0.68, "lunge_px": 12.0},
			{"id": &"hammer_attack_2", "impact_sec": 0.28, "duration_sec": 0.70, "cancel_sec": 0.48,
				"hit_stop_sec": 0.05, "source_contact_sec": 0.28, "damage_mult": 0.9,
				"stamina_mult": 0.9, "facing_dot": 0.1, "lunge_px": 10.0},
			{"id": &"hammer_attack_3", "impact_sec": 0.42, "duration_sec": 0.94, "cancel_sec": 0.72,
				"hit_stop_sec": 0.08, "source_contact_sec": 0.40, "damage_mult": 1.4,
				"stamina_mult": 1.2, "reach_mult": 1.1, "lunge_px": 22.0},
		],
		# Damage/reach/stamina come from the item's charged_attack_profile.
		"heavy": {"id": &"hammer_charged_attack", "impact_sec": 0.50, "duration_sec": 1.02,
			"cancel_sec": 0.80, "hit_stop_sec": 0.10, "source_contact_sec": 0.88, "lunge_px": 16.0},
	},
	CLASS_SWORD: {
		"light": [
			{"id": &"sword_attack", "impact_sec": 0.27, "duration_sec": 0.64, "cancel_sec": 0.42,
				"hit_stop_sec": 0.035, "source_contact_sec": 0.40, "lunge_px": 12.0},
			{"id": &"sword_attack_2", "impact_sec": 0.22, "duration_sec": 0.58, "cancel_sec": 0.38,
				"hit_stop_sec": 0.035, "source_contact_sec": 0.28, "facing_dot": 0.1,
				"lunge_px": 10.0},
			{"id": &"sword_attack_3", "impact_sec": 0.30, "duration_sec": 0.74, "cancel_sec": 0.54,
				"hit_stop_sec": 0.05, "source_contact_sec": 0.45, "damage_mult": 1.3,
				"stamina_mult": 1.2, "reach_mult": 1.15, "lunge_px": 26.0},
		],
		"heavy": {"id": &"sword_heavy_attack", "impact_sec": 0.42, "duration_sec": 0.92,
			"cancel_sec": 0.70, "hit_stop_sec": 0.07, "source_contact_sec": 0.40,
			"damage_mult": 1.8, "stamina_mult": 1.6, "reach_mult": 1.1, "facing_dot": 0.0,
			"lunge_px": 18.0},
	},
	CLASS_SPEAR: {
		"light": [
			{"id": &"spear_attack", "impact_sec": 0.30, "duration_sec": 0.70, "cancel_sec": 0.48,
				"hit_stop_sec": 0.04, "source_contact_sec": 0.45, "lunge_px": 16.0},
			{"id": &"spear_attack_2", "impact_sec": 0.28, "duration_sec": 0.66, "cancel_sec": 0.46,
				"hit_stop_sec": 0.04, "source_contact_sec": 0.45, "lunge_px": 14.0},
			{"id": &"spear_attack_3", "impact_sec": 0.34, "duration_sec": 0.84, "cancel_sec": 0.62,
				"hit_stop_sec": 0.06, "source_contact_sec": 0.40, "damage_mult": 1.25,
				"stamina_mult": 1.2, "facing_dot": -0.1, "lunge_px": 8.0},
		],
		"heavy": {"id": &"spear_heavy_attack", "impact_sec": 0.48, "duration_sec": 0.98,
			"cancel_sec": 0.76, "hit_stop_sec": 0.08, "source_contact_sec": 0.45,
			"damage_mult": 1.9, "stamina_mult": 1.6, "reach_mult": 1.25, "lunge_px": 34.0,
			"pierces_guard": true},
	},
}

## Non-attack actions. Rolls play the procedural clip 1:1 (no contact frame);
## casts warp the authored Spellcast clips so the release lands on impact_sec.
const ACTION_MOVES: Dictionary = {
	ROLL_FORWARD: {"id": ROLL_FORWARD, "duration_sec": 0.62},
	ROLL_BACKWARD: {"id": ROLL_BACKWARD, "duration_sec": 0.62},
	CAST_PROJECTILE: {"id": CAST_PROJECTILE, "impact_sec": 0.18, "duration_sec": 0.50,
		"source_contact_sec": 0.30},
	CAST_SELF: {"id": CAST_SELF, "impact_sec": 0.30, "duration_sec": 0.62,
		"source_contact_sec": 0.67},
	CAST_AREA: {"id": CAST_AREA, "impact_sec": 0.36, "duration_sec": 0.70,
		"source_contact_sec": 1.40},
}

## Clip-scaled actions whose logic length lives in PlayerActionStateMachine.
const SCALED_ACTIONS: Array[StringName] = [
	&"dodge_left", &"dodge_right", &"dodge_forward", &"dodge_backward", &"hit",
]


## Body build for a character id: the apprentice is a teen, everyone else adult.
static func build_for_character(character_id: StringName) -> StringName:
	return BUILD_TEEN if TEEN_CHARACTER_IDS.has(character_id) else BUILD_ADULT


static func build_factor(build: StringName, key: String) -> float:
	return float((BUILD_ADJUST.get(build, BUILD_ADJUST[BUILD_ADULT]) as Dictionary)[key])


static func is_weapon_class(weapon_class: StringName) -> bool:
	return weapon_class in WEAPON_CLASSES


static func combo_length(weapon_class: StringName) -> int:
	return (_move_set(weapon_class)["light"] as Array).size()


## step is 0-based and wraps, so a fourth press restarts the chain.
static func light_move(
	weapon_class: StringName, step: int, build: StringName = BUILD_ADULT
) -> CombatMove:
	var light := _move_set(weapon_class)["light"] as Array
	return _for_build(CombatMove.make(light[posmod(step, light.size())] as Dictionary), build)


static func heavy_move(weapon_class: StringName, build: StringName = BUILD_ADULT) -> CombatMove:
	return _for_build(CombatMove.make(_move_set(weapon_class)["heavy"] as Dictionary), build)


static func action_move(id: StringName) -> CombatMove:
	if not ACTION_MOVES.has(id):
		return null
	return CombatMove.make(ACTION_MOVES[id] as Dictionary)


## Every move whose clip time is warped against its logic clock, keyed by
## canonical animation id. The rig uses this for presentation.
static func presentation_move(id: StringName, build: StringName = BUILD_ADULT) -> CombatMove:
	if ACTION_MOVES.has(id):
		return action_move(id)
	for weapon_class: StringName in WEAPON_CLASSES:
		var move_set := _move_set(weapon_class)
		if StringName((move_set["heavy"] as Dictionary)["id"]) == id:
			return _for_build(CombatMove.make(move_set["heavy"] as Dictionary), build)
		for row: Dictionary in move_set["light"]:
			if StringName(row["id"]) == id:
				return _for_build(CombatMove.make(row), build)
	return null


## Delivery kind from a resolved spell effect -> cast gesture.
static func cast_move_for_delivery(delivery_kind: String) -> StringName:
	match delivery_kind:
		"projectile":
			return CAST_PROJECTILE
		"area_pulse", "persistent_area":
			return CAST_AREA
		_:
			return CAST_SELF


static func _for_build(move: CombatMove, build: StringName) -> CombatMove:
	if build == BUILD_ADULT or not BUILD_ADJUST.has(build):
		return move
	return move.scaled_for_build(build_factor(build, "timing"), build_factor(build, "lunge"))


static func _move_set(weapon_class: StringName) -> Dictionary:
	return MOVE_SETS.get(weapon_class, MOVE_SETS[CLASS_UNARMED]) as Dictionary
