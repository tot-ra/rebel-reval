class_name GuiltPhantoms
extends RefCounted
## SW-2 (ADR 0033): unresolved guilt takes shape in the Hingepuu as one phantom per guilt
## school. Pure and deterministic: the phantoms are derived from GameState.guilt every time,
## so nothing about them is saved except the ledger itself (levels, rites, victory counts).

const DIALOGUE_PREFIX := "dialogue.spirit.phantom."
const ID_PREFIX := "phantom.guilt."
## Ends where the hero turns away: the duel is won but nothing is absolved.
const RESOLUTION_TURNED_AWAY := "resolved_turned_away"
const RESULT_WON := "won"

## Debuff tier (GuiltLedger.debuff_tier) -> phantom stats. `pressure` is the opponent pool
## before soul-light scaling (SpiritDuel.PRESSURE_MAX is 60), `blow` scales incoming blows.
const TIER_STATS: Dictionary = {
	1: {"word": "minor", "pressure": 40.0, "blow": 1.0},
	2: {"word": "heavy", "pressure": 60.0, "blow": 1.15},
	3: {"word": "crushing", "pressure": 85.0, "blow": 1.3},
}
## Folklore labels (invented, ADR 0033); never a clinical name.
const NAMES: Dictionary = {
	GuiltLedger.SCHOOL_CHURCH: "Shade of Sin",
	GuiltLedger.SCHOOL_FOLK: "Blood-debt Shade",
	GuiltLedger.SCHOOL_CIVIC: "Shade of Dishonour",
}


## One phantom per school with guilt, in GuiltLedger.SCHOOLS order; [] for no ledger.
static func phantoms_for(ledger: GuiltLedger) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if ledger == null:
		return result
	for school in GuiltLedger.SCHOOLS:
		var tier := ledger.debuff_tier(school)
		if tier < 1:
			continue
		var stats: Dictionary = TIER_STATS[tier]
		result.append(
			{
				"id": StringName(ID_PREFIX + _suffix(school)),
				"school": school,
				"tier": tier,
				"tier_word": String(stats["word"]),
				"level": ledger.level(school),
				"dialogue_id": dialogue_id_for(school),
				"pressure_max": float(stats["pressure"]),
				"blow_factor": float(stats["blow"]),
				"name": String(NAMES[school]),
			}
		)
	return result


static func dialogue_id_for(school: StringName) -> StringName:
	return StringName(DIALOGUE_PREFIX + _suffix(school))


## Configure `duel` for `phantom` before it begins (the pool scale is relative to PRESSURE_MAX).
static func configure_duel(duel: SpiritDuel, phantom: Dictionary) -> void:
	duel.opponent_pressure_scale = float(phantom.get("pressure_max", SpiritDuel.PRESSURE_MAX)) / (
		SpiritDuel.PRESSURE_MAX
	)
	duel.opponent_blow_scale = float(phantom.get("blow_factor", 1.0))


## Guilt a won duel would lift: the whole level when the phantom was broken, tier + 1 when it
## was faced to a resolution, 0 when lost, abandoned or the hero turned away.
static func absolution_for(ledger: GuiltLedger, school: StringName, outcome: Dictionary) -> int:
	if ledger == null or not GuiltLedger.has_school(school):
		return 0
	if String(outcome.get("result", "")) != RESULT_WON:
		return 0
	if String(outcome.get("resolution_node_id", "")) == RESOLUTION_TURNED_AWAY:
		return 0
	if bool(outcome.get("broken", false)):
		return ledger.level(school)
	return ledger.debuff_tier(school) + 1


## Apply a duel outcome to the ledger. A loss changes nothing, so the debuff tier stays.
## Each victory spends its own numbered rite (`rite.phantom.<school>.<n>`). Returns the
## guilt removed.
static func apply_outcome(ledger: GuiltLedger, school: StringName, outcome: Dictionary) -> int:
	var amount := absolution_for(ledger, school, outcome)
	if amount < 1:
		return 0
	var rite_id := StringName(
		"rite.phantom.%s.%d" % [_suffix(school), ledger.phantom_victories(school) + 1]
	)
	var removed := ledger.absolve(school, amount, rite_id)
	if removed > 0:
		ledger.record_phantom_victory(school)
	return removed


static func _suffix(school: StringName) -> String:
	return String(school).trim_prefix("guilt.")
