class_name SelfTalk
extends RefCounted
## The hero talks himself through it (ADR 0033, SD-09): a short damage-reduction buff
## in exchange for being seen. Every NEW witness within earshot reacts by faction from a
## fixed table: some pull away (city suspicion rises, a faction thinks less of him), some
## read it as a gift (standing rises). Each witness reacts once per save; there is no
## randomness. Witnesses are nodes in `WITNESS_GROUP` that implement `witness_info()`.

const WITNESS_GROUP := &"self_talk_witnesses"
const WITNESS_RADIUS_PX := 420.0
const BUFF_ID := &"self_talk"
const BUFF_REDUCTION := 0.2
const BUFF_SECONDS := 12.0
const COOLDOWN_SEC := 20.0
const MODIFIER_SOURCE := &"self_talk"

## faction id -> {reaction, standing (ledger delta, 0 for none), suspicion (city pressure delta)}
const REACTIONS: Dictionary = {
	&"livonian_order": {"reaction": "suspicion", "standing": -1, "suspicion": 1},
	&"danish_crown": {"reaction": "contempt", "standing": 0, "suspicion": 1},
	&"hanseatic": {"reaction": "contempt", "standing": 0, "suspicion": 1},
	&"pskov_novgorod": {"reaction": "unease", "standing": 0, "suspicion": 1},
	&"harju_kings": {"reaction": "awe", "standing": 1, "suspicion": 0},
	&"black_cloaks": {"reaction": "awe", "standing": 1, "suspicion": 0},
	&"cult_metsik": {"reaction": "recognition", "standing": 1, "suspicion": 0},
	&"vitalienbruder": {"reaction": "amusement", "standing": 0, "suspicion": 0},
}
const UNAFFILIATED := {"reaction": "unease", "standing": 0, "suspicion": 1}

var _cooldown_left := 0.0


func tick(delta: float) -> void:
	_cooldown_left = maxf(0.0, _cooldown_left - maxf(delta, 0.0))


func cooldown_left() -> float:
	return _cooldown_left


## Witness info dictionaries of `witness_info()` nodes within `radius_px` of `origin`.
static func witnesses_near(
	tree: SceneTree, origin: Vector2, radius_px: float = WITNESS_RADIUS_PX
) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if tree == null:
		return found
	for node in tree.get_nodes_in_group(WITNESS_GROUP):
		if not node is Node2D or not node.has_method("witness_info"):
			continue
		if (node as Node2D).global_position.distance_to(origin) > radius_px:
			continue
		found.append(node.call("witness_info"))
	return found


## Talk to himself. `witnesses` are {id, faction} dictionaries. Returns
## {ok, reason, reactions[]}; each reaction is {witness, faction, reaction}.
func perform(state: GameState, vitals: CombatVitals, witnesses: Array) -> Dictionary:
	if _cooldown_left > 0.0:
		return {"ok": false, "reason": "cooldown", "reactions": []}
	if vitals != null:
		vitals.modifiers.apply(
			BUFF_ID,
			CombatTimedModifiers.STAT_DAMAGE_REDUCTION,
			BUFF_REDUCTION,
			BUFF_SECONDS,
			CombatTimedModifiers.STACKING_REPLACE,
			1,
			MODIFIER_SOURCE
		)
	_cooldown_left = COOLDOWN_SEC
	var reactions: Array[Dictionary] = []
	for witness_value: Variant in witnesses:
		var witness: Dictionary = witness_value
		var reaction := _react(state, witness)
		if not reaction.is_empty():
			reactions.append(reaction)
	return {"ok": true, "reason": "", "reactions": reactions}


func _react(state: GameState, witness: Dictionary) -> Dictionary:
	var witness_id := StringName(String(witness.get("id", "")))
	if state == null or witness_id == &"":
		return {}
	# One reaction per witness per save: the memory key doubles as the "already saw" mark.
	var memory_key := StringName("memory.%s.saw_self_talk" % String(witness_id).replace(".", "_"))
	if state.has_relationship_memory(memory_key) or not state.record_relationship_memory(memory_key):
		return {}
	var faction := StringName(String(witness.get("faction", "")))
	var rule: Dictionary = REACTIONS.get(faction, UNAFFILIATED)
	if int(rule["standing"]) != 0 and faction != &"":
		state.record_faction_event(
			StringName("faction.event.self_talk.%s" % witness_id),
			faction,
			int(rule["standing"]),
			"%s saw the apprentice talking to himself (%s)." % [witness_id, rule["reaction"]]
		)
	if int(rule["suspicion"]) != 0:
		state.adjust_pressure(
			GameState.PRESSURE_SUSPICION, int(rule["suspicion"])
		)
	return {
		"witness": String(witness_id),
		"faction": String(faction),
		"reaction": String(rule["reaction"]),
	}
