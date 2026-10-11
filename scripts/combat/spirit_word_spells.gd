class_name SpiritWordSpells
extends RefCounted
## Word spells of the real-time 3D arena (ADR 0038, SA3D-3). Slots 1..5 are emotional elements;
## a cast at any time speaks the duel's authored topic line for the element
## (SpiritDuel.topic_line_for) and throws it as a bolt at the opponent. When the opponent is
## waiting for a reply and one of the replies has the slot's element, the word **is** that reply:
## the dialogue follows it at once (SpiritDuel.answer, spoken_word) and the bolt only shows it.
## Otherwise it is a free strike: it costs willpower and lands its pressure when the bolt arrives
## (SpiritDuel.land_word, so the topic multiplier applies). Each slot has a short cooldown.
## Deterministic: no randomness, time advances only through tick(delta).

const SLOT_COUNT := 5
## Slot elements when the duel has no topic (the topic's own element order wins otherwise).
const DEFAULT_ELEMENTS: Array[StringName] = [&"fear", &"shame", &"duty", &"love", &"faith"]
const WORD_COST := 1
const COOLDOWN_SEC := 1.5
## Pressure of a free strike before guilt, traits, topic (x1.5 on topic) and buffs.
const WORD_DAMAGE := 6.0
const BOLT_SPEED := 9.0
const MIN_FLIGHT_SEC := 0.15
const REASON_NOT_NOW := "The duel is not listening now."
const REASON_COOLDOWN := "Still catching your breath."

var duel: SpiritDuel
var state: GameState
var elements: Array[StringName] = []
## Bolts in flight: {id, from, to, element, tags, damage, flight, left, answered}.
var bolts: Array[Dictionary] = []

var _cooldown_left: Array[float] = []
var _next_bolt_id := 1


func _init(for_duel: SpiritDuel = null, game_state: GameState = null) -> void:
	duel = for_duel
	state = game_state
	elements.clear()
	if duel != null:
		var lines: Dictionary = duel.topic().get("lines", {})
		for key: Variant in lines.keys():
			if elements.size() < SLOT_COUNT:
				elements.append(StringName(String(key)))
	if elements.is_empty():
		elements = DEFAULT_ELEMENTS.duplicate()
	_cooldown_left.resize(elements.size())
	_cooldown_left.fill(0.0)


func slot_count() -> int:
	return elements.size()


## Remaining cooldown of `slot` as a share of COOLDOWN_SEC (1 just cast .. 0 ready).
func cooldown_fraction(slot: int) -> float:
	if slot < 0 or slot >= _cooldown_left.size():
		return 0.0
	return clampf(_cooldown_left[slot] / COOLDOWN_SEC, 0.0, 1.0)


## The reply the word in `slot` would speak now, {} when it would be a free strike. Spell replies
## come before plain ones so a gesture (a shove, silence) is taken only when nothing else fits.
func answering_choice(slot: int) -> Dictionary:
	if duel == null or duel.phase != SpiritDuel.PHASE_ANSWER or slot < 0 or slot >= elements.size():
		return {}
	var fallback: Dictionary = {}
	for choice_value: Variant in duel.current_choices():
		var choice: Dictionary = choice_value
		if not bool(choice.get("enabled", false)):
			continue
		var move: Dictionary = choice.get("move", {})
		if StringName(String(move.get("element", ""))) != elements[slot]:
			continue
		if not String(choice.get("spell_id", "")).is_empty():
			return choice
		if fallback.is_empty():
			fallback = choice
	return fallback


## Why `slot` cannot be cast now, empty when it can.
func block_reason(slot: int) -> String:
	if duel == null or duel.is_over() or slot < 0 or slot >= elements.size():
		return REASON_NOT_NOW
	if _cooldown_left[slot] > 0.0:
		return REASON_COOLDOWN
	if answering_choice(slot).is_empty():
		var have := state.get_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER) if state != null else 0
		if have < WORD_COST:
			return "Not enough willpower (%d needed, %d left)." % [WORD_COST, have]
	return ""


## Speak the word in `slot`, thrown from `from` at `to`. Returns {ok, reason} on refusal, else
## {ok, element, text, tags, answered_choice_id, bolt}. An answering word never costs willpower,
## so a short purse cannot stall the dispute; a free strike costs WORD_COST.
func cast(slot: int, from: Vector3, to: Vector3) -> Dictionary:
	var reason := block_reason(slot)
	if not reason.is_empty():
		return {"ok": false, "reason": reason}
	var element := elements[slot]
	var choice := answering_choice(slot)
	var choice_move: Dictionary = choice.get("move", {})
	# An answer names what its reply names; a free strike reaches for the dispute as a whole.
	var tags: Array = choice_move.get("topic_tags", []) if not choice.is_empty() else duel.topic().get("tags", [])  # gdlint: ignore=max-line-length
	var line := duel.topic_line_for(element, tags)
	var text := String(line.get("text", ""))
	if text.is_empty() and not choice.is_empty():
		text = String(choice.get("text", ""))
	var answered := ""
	if not choice.is_empty():
		answered = String(choice.get("id", ""))
		if not duel.answer(answered, true):
			return {"ok": false, "reason": REASON_NOT_NOW}
	else:
		state.spend_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, WORD_COST)
	_cooldown_left[slot] = COOLDOWN_SEC
	var flight := maxf(MIN_FLIGHT_SEC, from.distance_to(to) / BOLT_SPEED)
	var bolt := {
		"id": _next_bolt_id,
		"from": from,
		"to": to,
		"element": element,
		"tags": line.get("relevance", []),
		"damage": 0.0 if not answered.is_empty() else WORD_DAMAGE,
		"flight": flight,
		"left": flight,
		"answered": not answered.is_empty(),
	}
	_next_bolt_id += 1
	bolts.append(bolt)
	return {
		"ok": true,
		"element": element,
		"text": text,
		"tags": line.get("relevance", []),
		"answered_choice_id": answered,
		"bolt": bolt.duplicate(),
	}


## How far `bolt` has flown (0 thrown .. 1 arrived).
static func bolt_progress(bolt: Dictionary) -> float:
	var flight := float(bolt.get("flight", 0.0))
	return 1.0 if flight <= 0.0 else clampf(1.0 - float(bolt.get("left", 0.0)) / flight, 0.0, 1.0)


## Advance cooldowns and bolts; returns the bolts that arrived this tick (their pressure landed).
func tick(delta: float) -> Array[Dictionary]:
	var landed: Array[Dictionary] = []
	if delta <= 0.0:
		return landed
	for index in _cooldown_left.size():
		_cooldown_left[index] = maxf(0.0, _cooldown_left[index] - delta)
	var flying: Array[Dictionary] = []
	for bolt: Dictionary in bolts:
		bolt["left"] = float(bolt["left"]) - delta
		if float(bolt["left"]) > 0.0:
			flying.append(bolt)
			continue
		bolt["left"] = 0.0
		if float(bolt["damage"]) > 0.0:
			bolt["dealt"] = duel.land_word(StringName(bolt["element"]), bolt["tags"], float(bolt["damage"]))
		landed.append(bolt)
	bolts = flying
	return landed
