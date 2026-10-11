class_name PhysicalBlowGuilt
extends RefCounted
## Hybrid combat (ADR 0033, SD-07): a physical blow opens guilt in the spirit layer.
## The circumstance of the blow decides the weight (GuiltLedger); the guilt then
## weakens the hero's spirit-duel replies by school and sharpens the opponent's blows.
## Deterministic; targets describe themselves with `guilt_context()`.

const REPLY_PENALTY_PER_TIER := 0.15
const REPLY_MULTIPLIER_FLOOR := 0.4
const INCOMING_BONUS_PER_TIER := 0.1
const INCOMING_MULTIPLIER_CAP := 1.6


## Circumstance id for a target context, or &"" when the blow carries no guilt.
## Context keys: `animal`, `aggressor` (it was attacking the hero), `defending_other`
## (the hero was protecting someone), `armed`.
static func classify(context: Dictionary) -> StringName:
	if bool(context.get("animal", false)):
		return &""
	if bool(context.get("aggressor", false)):
		if bool(context.get("defending_other", false)):
			return &"act.defend_other"
		return &"act.self_defence"
	if not bool(context.get("armed", true)):
		return &"act.unarmed_victim"
	return &"act.provoked"


## Record guilt for the targets a player strike hit. Returns one event per guilty blow.
## Each target counts once per act (`act.<id>.blow`, plus `act.<id>.kill` when it died).
static func record_hits(state: GameState, targets: Array) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if state == null:
		return events
	for target_value: Variant in targets:
		var target := target_value as Object
		if target == null or not target.has_method("guilt_context"):
			continue
		var context: Dictionary = target.call("guilt_context")
		var circumstance := classify(context)
		var actor := StringName(String(context.get("id", "")))
		if circumstance == &"" or actor == &"":
			continue
		var blow := state.guilt.record_act(StringName("act.%s.blow" % actor), circumstance, false)
		var died: bool = target.has_method("is_combat_dead") and bool(target.call("is_combat_dead"))
		var kill := {}
		if died:
			kill = state.guilt.record_kill(StringName("act.%s.kill" % actor))
		if not blow.is_empty() or not kill.is_empty():
			events.append(
				{"actor": String(actor), "circumstance": String(circumstance), "lethal": died}
			)
	return events


## Spirit-duel reply damage multiplier for a reply of `element` (1.0 with no guilt).
static func reply_multiplier(state: GameState, element: StringName) -> float:
	if state == null:
		return 1.0
	var school := state.guilt.school_for_element(element)
	if school == &"":
		return 1.0
	return maxf(
		REPLY_MULTIPLIER_FLOOR, 1.0 - REPLY_PENALTY_PER_TIER * float(state.guilt.debuff_tier(school))
	)


## Spirit-duel incoming blow multiplier: every tier of guilt in any school sharpens the opponent.
static func incoming_multiplier(state: GameState) -> float:
	if state == null:
		return 1.0
	var tiers := 0
	for school in GuiltLedger.SCHOOLS:
		tiers += state.guilt.debuff_tier(school)
	return minf(INCOMING_MULTIPLIER_CAP, 1.0 + INCOMING_BONUS_PER_TIER * float(tiers))
