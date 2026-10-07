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
## Reply kind -> the incoming kind it counters (defense > attack > feint > defense; appeal <> pressure).
const COUNTERS: Dictionary = {
	&"defense": &"attack",
	&"attack": &"feint",
	&"feint": &"defense",
	&"appeal": &"pressure",
	&"pressure": &"appeal",
}
const REPLY_NEUTRAL := 12.0
const REPLY_COUNTER := 30.0
const REPLY_COUNTERED := 4.0
const REPLY_RESONANCE := 8.0

var hero_id: StringName = &"char.apprentice"
var telegraph_sec := TELEGRAPH_SEC
## Hero composure is `health`, resolve is `stamina`; the opponent's pressure is `health`.
var hero := CombatVitals.new()
var opponent := CombatVitals.new()
var checkpoint := EncounterCheckpoint.new()
var phase: StringName = PHASE_IDLE
var last_outcome: Dictionary = {}

var _runner: Node
var _state: GameState
var _content_db: ContentDB
var _dialogue_id: StringName = &""
var _incoming: Dictionary = {}
var _choices: Array = []
var _telegraph_left := 0.0
var _guard_elapsed := -1.0
var _dodged := false
var _swing_id := 0
var _finished := true


## Start `dialogue_id` (a record with a `duel`) on `runner`. False when it is not a duel.
func begin(runner: Node, content_db: ContentDB, state: GameState, dialogue_id: StringName) -> bool:
	_runner = runner
	_content_db = content_db
	_state = state
	_dialogue_id = dialogue_id
	return _start_run()


func is_over() -> bool:
	return _finished


func tick(delta: float) -> void:
	if phase != PHASE_TELEGRAPH or delta <= 0.0:
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
	if phase != PHASE_TELEGRAPH or _dodged or hero.stamina < DODGE_RESOLVE_COST:
		return false
	hero.stamina -= DODGE_RESOLVE_COST
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
	var reply_move: Dictionary = chosen.get("move", {})
	var damage := reply_damage(reply_move, _incoming) * PhysicalBlowGuilt.reply_multiplier(
		_state, StringName(String(reply_move.get("element", "")))
	)
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


## What an unreadable (foreign, not understood) move reveals: the kind of blow, not its element or stakes.
static func kind_only(move: Dictionary) -> Dictionary:
	return {} if move.is_empty() else {"kind": move.get("kind", "")}


func present_choices(choices: Array) -> void:
	_choices = choices.duplicate(true)
	_set_phase(PHASE_ANSWER)
	choices_ready.emit(_choices)


func close() -> void:
	if not _finished:
		_finish(PHASE_IDLE, &"")


func consume_line_advance() -> bool:
	return false


func _start_run() -> bool:
	hero.configure(COMPOSURE_MAX, COMPOSURE_MAX, RESOLVE_MAX, RESOLVE_MAX)
	opponent.configure(PRESSURE_MAX, PRESSURE_MAX, 0.0, 0.0)
	opponent.hit_invulnerability_sec = 0.0
	_incoming = {}
	_choices.clear()
	last_outcome = {}
	_finished = false
	_runner.configure(_content_db, _state, self)
	if _content_db == null or _content_db.get_dialogue(_dialogue_id).get("duel", {}).is_empty():
		_finished = true
		return false
	checkpoint.arm(_state, _dialogue_id)
	if not _runner.start(_dialogue_id):
		_finished = true
		return false
	return true


func _land_incoming() -> void:
	var pose := CombatDefensePose.new()
	pose.is_action_invulnerable = _dodged
	pose.is_guarding = _guard_elapsed >= 0.0
	pose.guard_elapsed_sec = maxf(0.0, _guard_elapsed)
	var amount: float = (
		float(INCOMING_DAMAGE[StringName(String(_incoming.get("kind", "")))])
		* PhysicalBlowGuilt.incoming_multiplier(_state)
	)
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
