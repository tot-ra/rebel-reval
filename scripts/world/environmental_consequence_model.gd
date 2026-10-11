class_name EnvironmentalConsequenceModel
extends RefCounted

## Resolves district consequence overlays from ledger standing, district flags,
## and supply-chain state. WHY: P4-036 makes major player choices readable in the
## world without new combat or collection mechanics.

const PressureScript := preload("res://scripts/faction/district_pressure_model.gd")
const SupplyScript := preload("res://scripts/world/supply_chain_model.gd")

const STATE_BASELINE := &"baseline"
const STATE_UNREST := &"unrest"
const STATE_CRACKDOWN := &"crackdown"

const DISTRICT_LOWER_TOWN := PressureScript.DISTRICT_LOWER_TOWN

const PROP_REBEL_GRAFFITI := &"consequence_rebel_graffiti"
const PROP_ORDER_NOTICE := &"consequence_order_notice"
const PROP_WATCH_BARRICADE := &"consequence_watch_barricade"
const PROP_SUPPLY_SCATTER := &"consequence_supply_scatter"
const PROP_WALL_REPAIR := &"consequence_wall_repair"
const PROP_MARKET_GOODS := &"evidence_barrels"

const OVERLAY_PROPS_BY_DISTRICT: Dictionary = {
	DISTRICT_LOWER_TOWN:
	[
		PROP_REBEL_GRAFFITI,
		PROP_ORDER_NOTICE,
		PROP_WATCH_BARRICADE,
		PROP_SUPPLY_SCATTER,
		PROP_WALL_REPAIR,
	],
}

const DYNAMIC_PROPS_BY_DISTRICT: Dictionary = {
	DISTRICT_LOWER_TOWN: [PROP_MARKET_GOODS],
}

const STATE_VISIBLE_OVERLAYS: Dictionary = {
	STATE_BASELINE: [],
	STATE_UNREST: [PROP_REBEL_GRAFFITI],
	STATE_CRACKDOWN: [PROP_ORDER_NOTICE, PROP_WATCH_BARRICADE, PROP_WALL_REPAIR],
}

const FLAG_REBEL_TRUSTED := &"flag.reputation.harju_kings_trusted"


static func district_for_location(location_id: StringName) -> StringName:
	return PressureScript.district_for_location(location_id)


static func resolve_state(district_id: StringName, state: GameState) -> StringName:
	if district_id.is_empty() or state == null:
		return STATE_BASELINE
	var pressure := PressureScript.resolve(district_id, state)
	var tier: int = int(pressure.get("pressure_tier", PressureScript.TIER_NORMAL))
	if tier >= PressureScript.TIER_CRACKDOWN:
		return STATE_CRACKDOWN
	if tier >= PressureScript.TIER_TENSE or state.get_flag(FLAG_REBEL_TRUSTED):
		return STATE_UNREST
	return STATE_BASELINE


static func resolve_snapshot(district_id: StringName, state: GameState) -> Dictionary:
	var consequence_state := resolve_state(district_id, state)
	var visible_overlays: Array[StringName] = []
	for prop_id: StringName in STATE_VISIBLE_OVERLAYS.get(consequence_state, []):
		visible_overlays.append(prop_id)
	if _supply_disrupted(district_id, state):
		if not visible_overlays.has(PROP_SUPPLY_SCATTER):
			visible_overlays.append(PROP_SUPPLY_SCATTER)

	var dynamic_visibility := {}
	for prop_id: StringName in DYNAMIC_PROPS_BY_DISTRICT.get(district_id, []):
		dynamic_visibility[prop_id] = _dynamic_prop_visible(
			prop_id, consequence_state, state, district_id
		)

	return {
		"district_id": district_id,
		"consequence_state": consequence_state,
		"visible_overlays": visible_overlays,
		"dynamic_visibility": dynamic_visibility,
		"supply_disrupted": _supply_disrupted(district_id, state),
	}


static func all_managed_prop_ids(district_id: StringName) -> Array[StringName]:
	var props: Array[StringName] = []
	for prop_id: StringName in OVERLAY_PROPS_BY_DISTRICT.get(district_id, []):
		props.append(prop_id)
	for prop_id: StringName in DYNAMIC_PROPS_BY_DISTRICT.get(district_id, []):
		if not props.has(prop_id):
			props.append(prop_id)
	return props


static func prop_visible(snapshot: Dictionary, prop_id: StringName) -> bool:
	if snapshot.get("dynamic_visibility", {}).has(prop_id):
		return bool(snapshot["dynamic_visibility"][prop_id])
	return (snapshot.get("visible_overlays", []) as Array).has(prop_id)


static func _supply_disrupted(district_id: StringName, state: GameState) -> bool:
	if district_id != DISTRICT_LOWER_TOWN or state == null:
		return false
	return SupplyScript.is_route_disrupted(state)


static func _dynamic_prop_visible(
	prop_id: StringName, consequence_state: StringName, state: GameState, district_id: StringName
) -> bool:
	if prop_id == PROP_MARKET_GOODS and district_id == DISTRICT_LOWER_TOWN:
		if _supply_disrupted(district_id, state):
			return false
		return consequence_state != STATE_CRACKDOWN
	return true
