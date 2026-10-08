class_name SpiritDuel
extends "res://scripts/dialogue/dialogue_presenter.gd"
## Spirit-world duel (ADR 0033, SD-04): a tagged dialogue record played as combat.
## The DialogueRunner owns text, choices and effects; this presenter adds the fight.
## An opponent line with an attacking move is a telegraphed blow the hero can guard,
## parry or dodge (CombatVitals/CombatDefensePose); the hero's reply choices are moves
## that counter or lose to it. Reaching a `duel.resolution_node_ids` node wins; composure
## (hero health) reaching zero loses and the EncounterCheckpoint restores state for a retry.
## Deterministic: no randomness, fixed tables.

signal phase_changed(phase: StringName)
signal line_presented(speaker_id: StringName, text: String, move: Dictionary)
signal choices_ready(choices: Array)
signal exchange_resolved(result: Dictionary)
signal finished(outcome: Dictionary)

const PHASE_IDLE := &"idle"
const PHASE_TELEGRAPH := &"telegraph"
const PHASE_LINE := &"line"
const PHASE_ANSWER := &"answer"
const PHASE_WON := &"won"
const PHASE_LOST := &"lost"

const TELEGRAPH_SEC := 1.2
const COMPOSURE_MAX := 100.0
const RESOLVE_MAX := 100.0
const PRESSURE_MAX := 60.0
const DODGE_RESOLVE_COST := 25.0
const RESOLVE_RECOVERY_PER_EXCHANGE := 25.0
const PARRY_RETURN_PRESSURE := 15.0
## Blows that land on the hero's composure; other kinds are spoken without a telegraph.
const INCOMING_DAMAGE: Dictionary = {&"attack": 20.0, &"pressure": 14.0, &"feint": 10.0}
## Reply kind -> the incoming kind it counters (defense > attack > feint > defense; appeal <> pressure).  # gdlint: ignore=max-line-length
const COUNTERS: Dictionary = {
	&"defense": &"attack",
	&"attack": &"feint",
	&"feint": &"defense",
	&"appeal": &"pressure",
	&"pressure": &"appeal",
}
## Spell pressure = authored impact damage x this; a staggering spell halves the next blow;
## healing restores this much composure.
const SPELL_DAMAGE_SCALE := 1.5
const SPELL_STAGGER_BLOW_FACTOR := 0.5
const SPELL_HEAL_COMPOSURE := 12.0
const REPLY_NEUTRAL := 12.0
const REPLY_COUNTER := 30.0
const REPLY_COUNTERED := 4.0
const REPLY_RESONANCE := 8.0
## Reply window pressure (SD-18): mild, not a timeout. When the window runs out the hero
## hesitates once and loses a little composure; the replies stay open.
const REPLY_WINDOW_SEC := 6.0
const HESITATION_COMPOSURE := 6.0

var hero_id: StringName = &"char.apprentice"
var telegraph_sec := TELEGRAPH_SEC
var reply_window_sec := REPLY_WINDOW_SEC
## Off through Settings -> Gameplay accessibility -> "Reply timer pressure".
var reply_pressure_enabled := true
## Hero composure is `health`, resolve is `stamina`; the opponent's pressure is `health`.
var hero := CombatVitals.new()
var opponent := CombatVitals.new()
var checkpoint := EncounterCheckpoint.new()
var phase: StringName = PHASE_IDLE
var last_outcome: Dictionary = {}
## Why the last spell reply failed (a MagicResolver failure id), empty after a clean cast.
var last_cast_failure: StringName = &""

var _runner: Node
var _state: GameState
var _content_db: ContentDB
var _dialogue_id: StringName = &""
var _incoming: Dictionary = {}
var _choices: Array = []
var _telegraph_left := 0.0
var _reply_left := 0.0
var _hesitated := false
var _guard_elapsed := -1.0
var _dodged := false
var _swing_id := 0
var _finished := true
var _trait_mods: Dictionary = {}
var _next_blow_factor := 1.0
var _temperament: Array = []


## Start `dialogue_id` (a record with a `duel`) on `runner`. False when it is not a duel.
func begin(runner: Node, content_db: ContentDB, state: GameState, dialogue_id: StringName) -> bool:
	_runner = runner
	_content_db = content_db
	_state = state
	_dialogue_id = dialogue_id
	return _start_run()


func content_db() -> ContentDB:
	return _content_db


func is_over() -> bool:
	return _finished


func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	if phase == PHASE_ANSWER:
		_tick_reply_window(delta)
		return
	if phase != PHASE_TELEGRAPH:
		return
	hero.tick(delta)
	if _guard_elapsed >= 0.0:
		_guard_elapsed += delta
	_telegraph_left -= delta
	if _telegraph_left <= 0.0:
		_land_incoming()


func telegraph_progress() -> float:
	if phase != PHASE_TELEGRAPH or telegraph_sec <= 0.0:
		return 0.0
	return clampf(1.0 - _telegraph_left / telegraph_sec, 0.0, 1.0)


## How much of the reply window has run (0 fresh .. 1 run out); 0 when pressure is off.
func reply_window_progress() -> float:
	if phase != PHASE_ANSWER or not reply_pressure_enabled or reply_window_sec <= 0.0:
		return 0.0
	return clampf(1.0 - _reply_left / reply_window_sec, 0.0, 1.0)


## Why `choice` cannot be picked now, empty when it can. A disabled choice keeps its authored
## reason; a spell reply is pre-checked for its grant and resource so the card can say why
## before the hero tries (the cast itself still goes through MagicResolver).
func reply_block_reason(choice: Dictionary) -> String:
	if not bool(choice.get("enabled", false)):
		var authored := String(choice.get("disabled_reason", ""))
		return authored if not authored.is_empty() else "Not available."
	var spell_id := StringName(String(choice.get("spell_id", "")))
	if spell_id.is_empty() or _state == null or _content_db == null:
		return ""
	if not _state.has_magic_grant(spell_id):
		return SpellforgeModel.failure_text(MagicResolver.FAILURE_LOCKED)
	var record := (
		_content_db.get_spell(spell_id)
		if String(spell_id).begins_with("spell.")
		else _content_db.get_rite(spell_id)
	)
	var cost: Dictionary = record.get("cost", {})
	var resource_id := StringName(String(cost.get("resource", "")))
	var amount := int(cost.get("amount", 0))
	var have := _state.get_magic_resource(resource_id)
	if amount > 0 and have < amount:
		return "Not enough %s (%d needed, %d left)." % [
			String(resource_id).trim_prefix("resource."), amount, have
		]
	return ""


func incoming_move() -> Dictionary:
	return _incoming.duplicate(true)


## Raise or lower the guard. A guard raised within the parry window of impact parries.
func set_guard(raised: bool) -> void:
	if phase != PHASE_TELEGRAPH:
		return
	if raised and _guard_elapsed < 0.0:
		_guard_elapsed = 0.0
	elif not raised:
		_guard_elapsed = -1.0


## Dodge the telegraphed blow once, at a resolve cost.
func dodge() -> bool:
	var cost := DODGE_RESOLVE_COST + float(_trait_mods.get("dodge_cost_delta", 0.0))
	if phase != PHASE_TELEGRAPH or _dodged or hero.stamina < cost:
		return false
	hero.stamina -= cost
	hero.stamina_changed.emit(hero.stamina, hero.max_stamina)
	_dodged = true
	return true


## Continue after a spoken line (or close a finished duel).
func acknowledge() -> bool:
	if _runner == null or (phase != PHASE_LINE and phase != PHASE_WON):
		return false
	return _runner.advance()


## Pick a reply: its move strikes the opponent, then the dialogue follows the choice.
func answer(choice_id: String) -> bool:
	if phase != PHASE_ANSWER:
		return false
	var chosen: Dictionary = {}
	for choice_value: Variant in _choices:
		var choice: Dictionary = choice_value
		if String(choice.get("id", "")) == choice_id and bool(choice.get("enabled", false)):
			chosen = choice
			break
	if chosen.is_empty():
		return false
	# A spell reply is the magic itself: the cast resolves first and a failed cast (locked,
	# no willpower) leaves the choice open so the hero can pick another reply.
	var reply_spell := StringName(String(chosen.get("spell_id", "")))
	if not reply_spell.is_empty():
		var cast := cast_spell(reply_spell)
		last_cast_failure = StringName(String(cast.get("reason", ""))) if not bool(cast.get("ok", false)) else &""  # gdlint: ignore=max-line-length
		if not last_cast_failure.is_empty():
			return false
	var reply_move: Dictionary = chosen.get("move", {})
	var reply_element := StringName(String(reply_move.get("element", "")))
	var damage := reply_damage(reply_move, _incoming) * PhysicalBlowGuilt.reply_multiplier(
		_state, reply_element
	)
	damage *= SpiritTraits.reply_multiplier(_trait_mods, reply_element)
	damage *= SpiritTraits.temperament_multiplier(
		_temperament, StringName(String(reply_move.get("kind", "")))
	)
	damage = hero.modifiers.scale_outgoing_damage(damage)
	if damage > 0.0:
		opponent.resolve_hit(damage)
	hero.stamina = minf(hero.max_stamina, hero.stamina + RESOLVE_RECOVERY_PER_EXCHANGE)
	exchange_resolved.emit(
		{
			"kind": "reply",
			"choice_id": choice_id,
			"damage": damage,
			"pressure_left": opponent.health,
		}
	)
	_incoming = {}
	_choices.clear()
	_set_phase(PHASE_LINE)
	return _runner.select_choice(choice_id)


## Pressure a reply deals to the opponent (0 for an untagged reply).
static func reply_damage(reply_move: Dictionary, incoming: Dictionary) -> float:
	if reply_move.is_empty():
		return 0.0
	var damage := REPLY_NEUTRAL
	if not incoming.is_empty():
		var reply_kind := StringName(String(reply_move.get("kind", "")))
		var incoming_kind := StringName(String(incoming.get("kind", "")))
		if COUNTERS.get(reply_kind, &"") == incoming_kind:
			damage = REPLY_COUNTER
		elif COUNTERS.get(incoming_kind, &"") == reply_kind:
			damage = REPLY_COUNTERED
		if String(reply_move.get("element", "")) == String(incoming.get("element", "")):
			damage += REPLY_RESONANCE
	return damage


## Cast a granted spell or rite in the arena through the same MagicResolver as the world
## cookbook (cost, grant and conduit rules unchanged). Allowed while a blow is telegraphed or
## a reply is being chosen. Effects: damage -> pressure, stagger/knockback -> the next blow
## is halved, heal_over_time -> composure, a self modifier -> the hero's timed buffs.
func cast_spell(target_id: StringName) -> Dictionary:
	if phase != PHASE_TELEGRAPH and phase != PHASE_ANSWER:
		return {"ok": false, "reason": &"magic.fail.not_now"}
	var result := MagicResolver.cast(_state, _content_db, target_id)
	if not bool(result.get("ok", false)):
		return result
	var effect: Dictionary = result.get("effect", {})
	var impact: Dictionary = effect.get("impact", {})
	var arena_effect := &"none"
	match String(impact.get("kind", "")):
		"damage":
			opponent.resolve_hit(float(impact.get("amount", 0.0)) * SPELL_DAMAGE_SCALE)
			arena_effect = &"pressure"
		"stagger", "knockback":
			_next_blow_factor = SPELL_STAGGER_BLOW_FACTOR
			arena_effect = &"stagger"
		"heal_over_time":
			hero.heal(SPELL_HEAL_COMPOSURE)
			arena_effect = &"heal"
	var modifier: Dictionary = effect.get("modifier", {})
	if not modifier.is_empty():
		hero.modifiers.apply(
			StringName(String(modifier.get("modifier_id", ""))),
			StringName(String(modifier.get("kind", ""))),
			float(modifier.get("amount", 0.0)),
			float(modifier.get("duration_sec", 0.0)),
			StringName(String(modifier.get("stacking", "replace"))),
			int(modifier.get("max_stacks", 1)),
			target_id
		)
		arena_effect = &"buff"
	result["arena_effect"] = arena_effect
	exchange_resolved.emit(
		{"kind": "spell", "spell_id": String(target_id), "arena_effect": String(arena_effect), "pressure_left": opponent.health}  # gdlint: ignore=max-line-length
	)
	return result


## After a loss: restore the checkpoint and restart the duel with fresh vitals.
func retry() -> bool:
	if phase != PHASE_LOST or not checkpoint.restore(_state):
		return false
	return _start_run()


func present_line(
	speaker_id: StringName, _speaker_name: String, text: String, node_id: String
) -> void:
	var move: Dictionary = _runner.get_current_move()
	var shown := move if _runner.current_speech_readable() else kind_only(move)
	line_presented.emit(speaker_id, text, shown)
	if _resolution_ids().has(node_id):
		_finish(PHASE_WON, node_id)
		return
	var kind := StringName(String(move.get("kind", "")))
	if speaker_id != hero_id and INCOMING_DAMAGE.has(kind):
		_incoming = move
		_telegraph_left = telegraph_sec
		_guard_elapsed = -1.0
		_dodged = false
		_set_phase(PHASE_TELEGRAPH)
	else:
		_incoming = {}
		_set_phase(PHASE_LINE)


## What an unreadable (foreign, not understood) move reveals: the kind of blow, not its element or stakes.  # gdlint: ignore=max-line-length
static func kind_only(move: Dictionary) -> Dictionary:
	return {} if move.is_empty() else {"kind": move.get("kind", "")}


func present_choices(choices: Array) -> void:
	_choices = choices.duplicate(true)
	_reply_left = reply_window_sec
	_hesitated = false
	_set_phase(PHASE_ANSWER)
	choices_ready.emit(_choices)


func close() -> void:
	if not _finished:
		_finish(PHASE_IDLE, &"")


func consume_line_advance() -> bool:
	return false


func _start_run() -> bool:
	_trait_mods = SpiritTraits.modifiers_for(_state)
	var composure := COMPOSURE_MAX + float(_trait_mods.get("composure_delta", 0.0))
	hero.configure(composure, composure, RESOLVE_MAX, RESOLVE_MAX)
	hero.parry_window_sec = CombatVitals.DEFAULT_PARRY_WINDOW_SEC + float(
		_trait_mods.get("parry_window_delta", 0.0)
	)
	opponent.configure(PRESSURE_MAX, PRESSURE_MAX, 0.0, 0.0)
	opponent.hit_invulnerability_sec = 0.0
	_incoming = {}
	_choices.clear()
	_next_blow_factor = 1.0
	last_outcome = {}
	_finished = false
	_runner.configure(_content_db, _state, self)
	if _content_db == null or _content_db.get_dialogue(_dialogue_id).get("duel", {}).is_empty():
		_finished = true
		return false
	_temperament = (_content_db.get_dialogue(_dialogue_id).get("duel", {}) as Dictionary).get(
		"temperament", []
	)
	checkpoint.arm(_state, _dialogue_id)
	_state.in_spirit_world = true
	if not _runner.start(_dialogue_id):
		_finished = true
		_state.in_spirit_world = false
		return false
	return true


func _tick_reply_window(delta: float) -> void:
	if not reply_pressure_enabled or _hesitated:
		return
	_reply_left -= delta
	if _reply_left > 0.0:
		return
	_hesitated = true
	# Hesitation stings but never breaks composure on its own, so it cannot lose the duel.
	var chip := clampf(HESITATION_COMPOSURE, 0.0, maxf(0.0, hero.health - 1.0))
	if chip > 0.0:
		hero.health -= chip
		hero.health_changed.emit(hero.health, hero.max_health)
	exchange_resolved.emit({"kind": "hesitation", "composure_lost": chip})


func _land_incoming() -> void:
	var pose := CombatDefensePose.new()
	pose.is_action_invulnerable = _dodged
	pose.is_guarding = _guard_elapsed >= 0.0
	pose.guard_elapsed_sec = maxf(0.0, _guard_elapsed)
	pose.parry_window_sec = hero.parry_window_sec
	var incoming_kind := StringName(String(_incoming.get("kind", "")))
	var amount: float = (
		float(INCOMING_DAMAGE[incoming_kind])
		* PhysicalBlowGuilt.incoming_multiplier(_state)
		* SpiritTraits.incoming_multiplier(_trait_mods, incoming_kind)
		* _next_blow_factor
	)
	_next_blow_factor = 1.0
	_swing_id += 1
	var result := hero.resolve_hit(amount, pose, _swing_id)
	if result.outcome == CombatHitResult.OUTCOME_PARRIED:
		opponent.resolve_hit(PARRY_RETURN_PRESSURE)
	exchange_resolved.emit(
		{
			"kind": "incoming",
			"outcome": result.outcome,
			"composure_lost": result.health_damage,
			"resolve_lost": result.stamina_damage,
			"pressure_left": opponent.health,
		}
	)
	_guard_elapsed = -1.0
	if hero.is_dead():
		_finish(PHASE_LOST, &"")
		return
	_set_phase(PHASE_LINE)
	_runner.advance()


func _finish(result_phase: StringName, node_id: StringName) -> void:
	_finished = true
	if _state != null:
		_state.in_spirit_world = false
	last_outcome = {
		"result": String(result_phase),
		"resolution_node_id": String(node_id),
		"composure": hero.health,
		"pressure_left": opponent.health,
		"broken": opponent.health <= 0.0,
	}
	if result_phase == PHASE_WON:
		checkpoint.clear()
	elif result_phase == PHASE_LOST:
		checkpoint.mark_failed()
	_set_phase(result_phase)
	finished.emit(last_outcome)


func _resolution_ids() -> Array:
	return _runner.get_duel().get("resolution_node_ids", [])


func _set_phase(next: StringName) -> void:
	if phase == next:
		return
	phase = next
	phase_changed.emit(next)
