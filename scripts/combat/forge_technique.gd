class_name ForgeTechnique
extends RefCounted

## Equipped forge techniques layer onto AttackProfile / CombatVitals contracts.
## They are not a parallel action state machine and must not branch on enemy IDs.
##
## Authored Iron combat use (P1-024d): jam a braced defense. A guarding foe
## outside the parry window takes an open hit (guard pierce). Timed parries,
## dodge, and post-hit invulnerability still win.

const ID_IRON := &"Iron"
const ID_EMBER := &"Ember"
const ID_ROOT := &"Root"

const ALLOWED_IDS: Array[StringName] = [ID_IRON, ID_EMBER, ID_ROOT]

## Extra stamina spent when Iron is layered onto a resolved attack profile.
const IRON_STAMINA_COST_BONUS := 6.0


static func is_allowed(technique_id: StringName) -> bool:
	return ALLOWED_IDS.has(technique_id)


## Returns a copy of profile with the equipped technique applied. Unknown or
## empty techniques leave the profile unchanged.
static func apply_equipped(profile: AttackProfile, technique_id: StringName) -> AttackProfile:
	if profile == null:
		return AttackProfile.unarmed()
	var layered := profile.duplicate_profile()
	if technique_id.is_empty() or not is_allowed(technique_id):
		return layered
	layered.technique = technique_id
	if technique_id == ID_IRON:
		# WHY: Iron is the smith's jam/brace craft - force through a held guard
		# without inventing a second attack state machine.
		layered.pierces_guard = true
		layered.stamina_cost = maxf(0.0, layered.stamina_cost + IRON_STAMINA_COST_BONUS)
	return layered
