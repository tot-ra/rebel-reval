class_name GuiltLedger
extends RefCounted
## Per-school guilt (ADR 0033): Christian sin, folk blood-debt and civic standing
## are separate levels, never one morality score. Pure data, deterministic, saved
## through GameState. Weight depends on the circumstance of the act.

const SCHOOL_CHURCH := &"guilt.church"
const SCHOOL_FOLK := &"guilt.folk"
const SCHOOL_CIVIC := &"guilt.civic"
const SCHOOLS: Array[StringName] = [SCHOOL_CHURCH, SCHOOL_FOLK, SCHOOL_CIVIC]
const MAX_LEVEL := 10
const VERSION := 1

## Circumstance -> weight added to each school. A lethal blow adds LETHAL_WEIGHT.
const CIRCUMSTANCE_WEIGHTS: Dictionary = {
	&"act.self_defence": {SCHOOL_CHURCH: 1, SCHOOL_FOLK: 0, SCHOOL_CIVIC: 0},
	&"act.defend_other": {SCHOOL_CHURCH: 1, SCHOOL_FOLK: 0, SCHOOL_CIVIC: 0},
	&"act.provoked": {SCHOOL_CHURCH: 2, SCHOOL_FOLK: 1, SCHOOL_CIVIC: 1},
	&"act.unarmed_victim": {SCHOOL_CHURCH: 4, SCHOOL_FOLK: 3, SCHOOL_CIVIC: 3},
}
const LETHAL_WEIGHT: Dictionary = {SCHOOL_CHURCH: 3, SCHOOL_FOLK: 4, SCHOOL_CIVIC: 2}
## Spirit-layer debuff tier by level: 0 none, 1 minor (1-2), 2 heavy (3-5), 3 crushing (6+).
const TIER_THRESHOLDS: Array[int] = [1, 3, 6]

var _levels: Dictionary = {}
var _recorded_acts: Dictionary = {}
var _absolutions: Dictionary = {}


func _init() -> void:
	reset()


func reset() -> void:
	_levels.clear()
	_recorded_acts.clear()
	_absolutions.clear()
	for school in SCHOOLS:
		_levels[school] = 0


static func has_school(school: StringName) -> bool:
	return SCHOOLS.has(school)


static func has_circumstance(circumstance: StringName) -> bool:
	return CIRCUMSTANCE_WEIGHTS.has(circumstance)


## Weight each school would gain; empty for an unknown circumstance.
static func weights_for(circumstance: StringName, lethal: bool) -> Dictionary:
	if not CIRCUMSTANCE_WEIGHTS.has(circumstance):
		return {}
	var base: Dictionary = CIRCUMSTANCE_WEIGHTS[circumstance]
	var result: Dictionary = {}
	for school in SCHOOLS:
		result[school] = int(base[school]) + (int(LETHAL_WEIGHT[school]) if lethal else 0)
	return result


func level(school: StringName) -> int:
	return int(_levels.get(school, 0))


func levels() -> Dictionary:
	return _levels.duplicate()


func debuff_tier(school: StringName) -> int:
	var tier := 0
	for threshold in TIER_THRESHOLDS:
		if level(school) >= threshold:
			tier += 1
	return tier


## Record one act once (`act_id` makes replays and reloads idempotent). Returns the
## weights applied, or {} when the circumstance is unknown or the act was already recorded.
func record_act(act_id: StringName, circumstance: StringName, lethal: bool = false) -> Dictionary:
	if act_id == &"" or _recorded_acts.has(act_id):
		return {}
	var weights := weights_for(circumstance, lethal)
	if weights.is_empty():
		return {}
	for school in SCHOOLS:
		_levels[school] = mini(MAX_LEVEL, level(school) + int(weights[school]))
	_recorded_acts[act_id] = String(circumstance) + (":lethal" if lethal else "")
	return weights


## Lower one school by `amount` through an authored rite (`rite_id` fires once). Returns the
## amount removed (0 when nothing to absolve, the rite was already used, or the school is unknown).
func absolve(school: StringName, amount: int, rite_id: StringName) -> int:
	if not has_school(school) or amount < 1 or rite_id == &"" or _absolutions.has(rite_id):
		return 0
	var removed := mini(amount, level(school))
	_levels[school] = level(school) - removed
	_absolutions[rite_id] = String(school)
	return removed


func to_dict() -> Dictionary:
	var levels_out: Dictionary = {}
	for school in SCHOOLS:
		levels_out[String(school)] = level(school)
	return {
		"version": VERSION,
		"levels": levels_out,
		"acts": _recorded_acts.duplicate(),
		"absolutions": _absolutions.duplicate(),
	}


## Replace this ledger from a saved dictionary; returns validation errors (state is reset first).
func from_dict(source: Variant) -> Array[String]:
	reset()
	var errors: Array[String] = []
	if typeof(source) != TYPE_DICTIONARY:
		errors.append("guilt must be a dictionary")
		return errors
	var data: Dictionary = source
	if data.is_empty():
		return errors
	if int(data.get("version", VERSION)) != VERSION:
		errors.append("unsupported guilt version %d" % int(data.get("version", 0)))
		return errors
	var saved_levels: Variant = data.get("levels", {})
	if typeof(saved_levels) != TYPE_DICTIONARY:
		errors.append("guilt.levels must be a dictionary")
	else:
		for key: Variant in (saved_levels as Dictionary):
			var school := StringName(String(key))
			if not has_school(school):
				errors.append("unknown guilt school %s" % String(key))
				continue
			_levels[school] = clampi(int((saved_levels as Dictionary)[key]), 0, MAX_LEVEL)
	_recorded_acts = _string_map(data.get("acts", {}), "guilt.acts", errors)
	_absolutions = _string_map(data.get("absolutions", {}), "guilt.absolutions", errors)
	return errors


static func _string_map(source: Variant, label: String, errors: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	if typeof(source) != TYPE_DICTIONARY:
		errors.append("%s must be a dictionary" % label)
		return result
	for key: Variant in (source as Dictionary):
		result[StringName(String(key))] = String((source as Dictionary)[key])
	return result
