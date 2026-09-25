class_name CombatTimedModifiers
extends RefCounted

## Reusable timed stat modifiers for one combat actor (R-725).
## Magic and future items/techniques apply authored modifier records here; the
## actor's CombatVitals reads the combined result. Nothing here knows a spell ID.
##
## Save boundary: modifiers are transient combat state. They are never written
## to GameState or save payloads; a save/load or scene transition that rebuilds
## the actor ends them. Resources spent to create them stay spent.

signal applied(modifier_id: StringName, stacks: int, remaining_sec: float)
signal expired(modifier_id: StringName)

const STAT_DAMAGE_REDUCTION := &"damage_reduction"
const STACKING_REPLACE := &"replace"
const STACKING_STACK := &"stack"
## Combined incoming-damage reduction never reaches invulnerability.
const MAX_TOTAL_DAMAGE_REDUCTION := 0.8
const MAX_STACKS_CAP := 5

## modifier_id -> {stat, amount, stacks: Array[float] remaining seconds, source_id}
var _active: Dictionary = {}


## Applies one authored modifier.
## - `replace`: a re-application replaces the magnitude and restarts the timer.
## - `stack`: each application adds an independently timed stack up to
##   `max_stacks`; at the cap the stack closest to expiry is refreshed.
## Returns false (and changes nothing) for malformed input.
func apply(
	modifier_id: StringName,
	stat: StringName,
	amount: float,
	duration_sec: float,
	stacking: StringName = STACKING_REPLACE,
	max_stacks: int = 1,
	source_id: StringName = &""
) -> bool:
	if modifier_id.is_empty() or stat.is_empty():
		return false
	if amount <= 0.0 or duration_sec <= 0.0:
		return false
	if stacking != STACKING_REPLACE and stacking != STACKING_STACK:
		return false
	var stack_cap := clampi(max_stacks, 1, MAX_STACKS_CAP) if stacking == STACKING_STACK else 1
	var entry: Dictionary = _active.get(modifier_id, {})
	var stacks: Array[float] = []
	if not entry.is_empty() and entry["stat"] == stat and stacking == STACKING_STACK:
		stacks = entry["stacks"]
	if stacks.size() >= stack_cap:
		stacks.sort()
		stacks[0] = duration_sec
	else:
		stacks.append(duration_sec)
	_active[modifier_id] = {
		"stat": stat,
		"amount": amount,
		"stacks": stacks,
		"source_id": source_id,
	}
	applied.emit(modifier_id, stacks.size(), remaining_sec(modifier_id))
	return true


func tick(delta: float) -> void:
	if delta <= 0.0 or _active.is_empty():
		return
	var ended: Array[StringName] = []
	for modifier_id in _active:
		var stacks: Array[float] = _active[modifier_id]["stacks"]
		var kept: Array[float] = []
		for remaining in stacks:
			var next := remaining - delta
			if next > 0.0 and not is_zero_approx(next):
				kept.append(next)
		_active[modifier_id]["stacks"] = kept
		if kept.is_empty():
			ended.append(modifier_id)
	# Sorted so expiry signals fire in a deterministic order.
	ended.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for modifier_id in ended:
		_active.erase(modifier_id)
		expired.emit(modifier_id)


func clear() -> void:
	_active.clear()


func is_active(modifier_id: StringName) -> bool:
	return _active.has(modifier_id)


func stack_count(modifier_id: StringName) -> int:
	if not _active.has(modifier_id):
		return 0
	return (_active[modifier_id]["stacks"] as Array).size()


## Longest remaining stack, 0 when inactive.
func remaining_sec(modifier_id: StringName) -> float:
	if not _active.has(modifier_id):
		return 0.0
	var longest := 0.0
	for remaining in _active[modifier_id]["stacks"]:
		longest = maxf(longest, remaining)
	return longest


func active_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for modifier_id in _active:
		ids.append(modifier_id)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


## Combined fraction of incoming damage removed. Each stack multiplies the
## remaining damage, so reductions never add past 100%, and the total is capped.
func damage_reduction() -> float:
	var remaining := 1.0
	for modifier_id in _active:
		var entry: Dictionary = _active[modifier_id]
		if entry["stat"] != STAT_DAMAGE_REDUCTION:
			continue
		var per_stack := clampf(float(entry["amount"]), 0.0, MAX_TOTAL_DAMAGE_REDUCTION)
		remaining *= pow(1.0 - per_stack, (entry["stacks"] as Array).size())
	return minf(1.0 - remaining, MAX_TOTAL_DAMAGE_REDUCTION)


func reduce_incoming_damage(amount: float) -> float:
	if amount <= 0.0:
		return amount
	return amount * (1.0 - damage_reduction())


## Adapter for authored effect modules. Any actor exposing a `combat_vitals`
## property (player, combat room enemies, test dummies) can receive modifiers.
static func apply_module_to(target: Node, module: Dictionary, source_id: StringName = &"") -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var vitals: Variant = target.get("combat_vitals")
	if not vitals is Object:
		return false
	# Duck-typed to avoid a CombatVitals <-> CombatTimedModifiers class load cycle.
	var modifiers: Variant = (vitals as Object).get("modifiers")
	if not modifiers is CombatTimedModifiers:
		return false
	var stat := StringName(String(module.get("kind", "")))
	if stat != STAT_DAMAGE_REDUCTION:
		return false
	return (modifiers as CombatTimedModifiers).apply(
		StringName(String(module.get("modifier_id", ""))),
		stat,
		float(module.get("amount", 0.0)),
		float(module.get("duration_sec", 0.0)),
		StringName(String(module.get("stacking", String(STACKING_REPLACE)))),
		int(module.get("max_stacks", 1)),
		source_id
	)
