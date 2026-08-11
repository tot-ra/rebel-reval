class_name DistrictPressureModel
extends RefCounted

## Resolves per-district patrol density, trade price tier, and bark pools from
## explicit district flags plus faction ledger standing. No aggregate morality.

const TIER_RELAXED := 0
const TIER_NORMAL := 1
const TIER_TENSE := 2
const TIER_CRACKDOWN := 3

const LOC_LOWER_TOWN := &"loc.lower_town_slice"
const LOC_SMITHY := &"loc.kalev_smithy"
const MAP_NORTH_QUARTER := &"north_quarter"

const DISTRICT_LOWER_TOWN := &"district.lower_town"
const DISTRICT_NORTH_MERCHANT := &"district.north_merchant"

const FLAG_UNREST_SUFFIX := &"unrest"
const FLAG_MARTIAL_LAW_SUFFIX := &"martial_law"

const PATROL_SPEED_BY_TIER: Array[float] = [0.75, 1.0, 1.25, 1.5]
const PRICE_MULTIPLIER_BY_TIER: Array[float] = [0.9, 1.0, 1.15, 1.3]

const TIER_NAMES: Array[StringName] = [
	&"relaxed",
	&"normal",
	&"tense",
	&"crackdown",
]

const LOCATION_TO_DISTRICT: Dictionary = {
	LOC_LOWER_TOWN: DISTRICT_LOWER_TOWN,
	LOC_SMITHY: DISTRICT_LOWER_TOWN,
}

const MAP_TO_DISTRICT: Dictionary = {
	MAP_NORTH_QUARTER: DISTRICT_NORTH_MERCHANT,
	&"lower_town_slice": DISTRICT_LOWER_TOWN,
}

const DISTRICT_PROFILES: Dictionary = {
	DISTRICT_LOWER_TOWN:
	{
		"controlling_faction": FactionLedger.LIVONIAN_ORDER,
		"trade_faction": FactionLedger.HANSEATIC,
		"opposition_faction": FactionLedger.HARJU_KINGS,
	},
	DISTRICT_NORTH_MERCHANT:
	{
		"controlling_faction": FactionLedger.HANSEATIC,
		"trade_faction": FactionLedger.HANSEATIC,
		"opposition_faction": FactionLedger.BLACK_CLOAKS,
	},
}


static func district_for_location(location_id: StringName) -> StringName:
	return LOCATION_TO_DISTRICT.get(location_id, &"") as StringName


static func district_for_map(map_id: StringName) -> StringName:
	return MAP_TO_DISTRICT.get(map_id, &"") as StringName


static func resolve_for_location(location_id: StringName, state: GameState) -> Dictionary:
	return resolve(district_for_location(location_id), state)


static func resolve_for_map(map_id: StringName, state: GameState) -> Dictionary:
	return resolve(district_for_map(map_id), state)


static func resolve(district_id: StringName, state: GameState) -> Dictionary:
	var empty := _empty_snapshot()
	if district_id.is_empty() or state == null:
		return empty
	if not DISTRICT_PROFILES.has(district_id):
		return empty

	var profile: Dictionary = DISTRICT_PROFILES[district_id]
	var tier := _resolve_tier(district_id, state, profile)
	var tier_name := tier_name_for(tier)
	return {
		"district_id": district_id,
		"pressure_tier": tier,
		"price_tier": tier,
		"tier_name": tier_name,
		"patrol_speed_scale": PATROL_SPEED_BY_TIER[tier],
		"price_multiplier": PRICE_MULTIPLIER_BY_TIER[tier],
		"bark_pool_id": bark_pool_id(district_id, tier),
		"secondary_patrol_enabled": tier >= TIER_TENSE,
	}


static func tier_name_for(tier: int) -> StringName:
	var clamped := clampi(tier, TIER_RELAXED, TIER_CRACKDOWN)
	return TIER_NAMES[clamped]


static func bark_pool_id(district_id: StringName, tier: int) -> StringName:
	if district_id.is_empty():
		return &""
	return StringName(
		(
			"bark.district.%s.%s"
			% [String(district_id).trim_prefix("district."), String(tier_name_for(tier))]
		)
	)


static func district_flag(district_id: StringName, suffix: StringName) -> StringName:
	return StringName("flag.%s.%s" % [String(district_id), String(suffix)])


static func _resolve_tier(district_id: StringName, state: GameState, profile: Dictionary) -> int:
	var tier := TIER_NORMAL
	var controlling := profile.get("controlling_faction", &"") as StringName
	var opposition := profile.get("opposition_faction", &"") as StringName

	if state.get_flag(district_flag(district_id, FLAG_UNREST_SUFFIX)):
		tier += 1
	if state.get_flag(district_flag(district_id, FLAG_MARTIAL_LAW_SUFFIX)):
		tier += 1

	var controlling_standing := state.get_faction_standing(controlling)
	if controlling_standing >= 2:
		tier -= 1
	elif controlling_standing <= -2:
		tier += 1

	if not opposition.is_empty() and state.get_faction_standing(opposition) >= 2:
		tier += 1

	return clampi(tier, TIER_RELAXED, TIER_CRACKDOWN)


static func _empty_snapshot() -> Dictionary:
	return {
		"district_id": &"",
		"pressure_tier": TIER_NORMAL,
		"price_tier": TIER_NORMAL,
		"tier_name": &"normal",
		"patrol_speed_scale": 1.0,
		"price_multiplier": 1.0,
		"bark_pool_id": &"",
		"secondary_patrol_enabled": false,
	}
