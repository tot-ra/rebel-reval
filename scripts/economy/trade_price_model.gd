class_name TradePriceModel
extends RefCounted

## Resolves district-local trade prices for essential goods from district pressure,
## faction standing, and explicit supply flags. No aggregate morality or wallet sim.

const DistrictPressureModelScript := preload("res://scripts/faction/district_pressure_model.gd")

const TRADE_IRON := &"trade.iron"
const TRADE_BREAD := &"trade.bread"

const ESSENTIAL_GOODS: Array[StringName] = [TRADE_IRON, TRADE_BREAD]

const TIER_LOW := 0
const TIER_NORMAL := 1
const TIER_HIGH := 2
const TIER_SCARCE := 3

const TIER_NAMES: Array[StringName] = [&"low", &"normal", &"high", &"scarce"]

const MATERIAL_GRADE_MULTIPLIER: Dictionary = {
	"poor": 0.8,
	"common": 1.0,
	"fine": 1.4,
	"none": 1.0,
}

const GOODS: Dictionary = {
	TRADE_IRON: {
		"label": "iron bar",
		"base_pfennigs": 24,
		"supply_faction": FactionLedger.LIVONIAN_ORDER,
		"hostile_multiplier": 1.25,
		"friendly_multiplier": 0.9,
		"restriction_flag_suffix": &"iron_restricted",
	},
	TRADE_BREAD: {
		"label": "loaf",
		"base_pfennigs": 4,
		"supply_faction": FactionLedger.HARJU_KINGS,
		"hostile_multiplier": 1.2,
		"friendly_multiplier": 0.8,
		"relief_flag_suffix": &"market_open",
	},
}


static func resolve(good_id: StringName, district_id: StringName, state: GameState) -> Dictionary:
	var empty := _empty_quote(good_id)
	if good_id.is_empty() or state == null or not GOODS.has(good_id):
		return empty
	if district_id.is_empty() or not DistrictPressureModelScript.DISTRICT_PROFILES.has(district_id):
		return empty

	var profile: Dictionary = GOODS[good_id]
	var base_price := int(profile.get("base_pfennigs", 0))
	if base_price <= 0:
		return empty

	var pressure := DistrictPressureModelScript.resolve(district_id, state)
	var multiplier := float(pressure.get("price_multiplier", 1.0))
	multiplier *= _good_supply_multiplier(good_id, profile, district_id, state)

	var price_pfennigs := maxi(1, int(round(float(base_price) * multiplier)))
	var tier := _tier_for_ratio(float(price_pfennigs) / float(base_price))
	return {
		"good_id": good_id,
		"district_id": district_id,
		"label": String(profile.get("label", good_id)),
		"base_pfennigs": base_price,
		"price_pfennigs": price_pfennigs,
		"price_tier": tier,
		"tier_name": tier_name_for(tier),
		"price_multiplier": multiplier,
	}


static func resolve_for_location(good_id: StringName, location_id: StringName, state: GameState) -> Dictionary:
	return resolve(good_id, DistrictPressureModelScript.district_for_location(location_id), state)


static func material_cost_pfennigs(
	material_grade: String,
	location_id: StringName,
	state: GameState
) -> int:
	var grade_multiplier := float(MATERIAL_GRADE_MULTIPLIER.get(material_grade, 1.0))
	var iron_quote := resolve_for_location(TRADE_IRON, location_id, state)
	var iron_price := int(iron_quote.get("price_pfennigs", GOODS[TRADE_IRON]["base_pfennigs"]))
	return maxi(1, int(round(float(iron_price) * grade_multiplier)))


static func format_pfennigs(amount: int) -> String:
	return str(maxi(0, amount))


static func tier_name_for(tier: int) -> StringName:
	var clamped := clampi(tier, TIER_LOW, TIER_SCARCE)
	return TIER_NAMES[clamped]


static func is_valid_good_id(good_id: StringName) -> bool:
	return GOODS.has(good_id)


static func _good_supply_multiplier(
	good_id: StringName,
	profile: Dictionary,
	district_id: StringName,
	state: GameState
) -> float:
	var multiplier := 1.0
	var supply_faction := profile.get("supply_faction", &"") as StringName
	if not supply_faction.is_empty():
		var standing := state.get_faction_standing(supply_faction)
		if standing >= 2:
			multiplier *= float(profile.get("friendly_multiplier", 1.0))
		elif standing <= -2:
			multiplier *= float(profile.get("hostile_multiplier", 1.0))

	var restriction_suffix := profile.get("restriction_flag_suffix", &"") as StringName
	if not restriction_suffix.is_empty():
		if state.get_flag(DistrictPressureModelScript.district_flag(district_id, restriction_suffix)):
			multiplier *= float(profile.get("hostile_multiplier", 1.0))

	var relief_suffix := profile.get("relief_flag_suffix", &"") as StringName
	if not relief_suffix.is_empty():
		if state.get_flag(DistrictPressureModelScript.district_flag(district_id, relief_suffix)):
			multiplier *= float(profile.get("friendly_multiplier", 1.0))

	if good_id == TRADE_IRON:
		if state.get_flag(DistrictPressureModelScript.district_flag(district_id, &"martial_law")):
			multiplier *= 1.15
	elif good_id == TRADE_BREAD:
		if state.get_flag(DistrictPressureModelScript.district_flag(district_id, &"unrest")):
			if state.get_faction_standing(FactionLedger.HARJU_KINGS) >= 2:
				multiplier *= 0.85

	return multiplier


static func _tier_for_ratio(ratio: float) -> int:
	if ratio < 0.95:
		return TIER_LOW
	if ratio < 1.08:
		return TIER_NORMAL
	if ratio < 1.25:
		return TIER_HIGH
	return TIER_SCARCE


static func _empty_quote(good_id: StringName) -> Dictionary:
	return {
		"good_id": good_id,
		"district_id": &"",
		"label": "",
		"base_pfennigs": 0,
		"price_pfennigs": 0,
		"price_tier": TIER_NORMAL,
		"tier_name": &"normal",
		"price_multiplier": 1.0,
	}
