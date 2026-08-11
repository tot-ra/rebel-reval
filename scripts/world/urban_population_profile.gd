class_name UrbanPopulationProfile
extends RefCounted

## Renderer-agnostic population contract for the Lower Town activity controller.
## WHY: profile resolution must be replayable without loading a scene or mutating
## GameState. The controller can consume the returned actor_plan later.

const GameCalendarScript := preload("res://scripts/global/game_calendar.gd")

const PROFILE_DAY := &"day"
const PROFILE_NIGHT := &"night"
const PROFILE_MARKET_DAY := &"market_day"
const PROFILE_CRACKDOWN := &"crackdown"
const PROFILE_TENSE := PROFILE_CRACKDOWN
const PROFILE_IDS: Array[StringName] = [
	PROFILE_DAY,
	PROFILE_NIGHT,
	PROFILE_MARKET_DAY,
	PROFILE_CRACKDOWN,
]

const MOVEMENT_WANDER := &"wander"
const MOVEMENT_RETURN_TO_ANCHOR := &"return_to_anchor"
const MOVEMENT_ROUTE_BETWEEN_ZONES := &"route_between_zones"
const MOVEMENT_CAUTIOUS := &"cautious"

const ANCHOR_ZONE := &"zone"
const ANCHOR_AUTHORED := &"authored"
const ANCHOR_NEAREST := &"nearest"

const ZONE_STREET := &"street_frontage"
const ZONE_MARKET := &"market_lane"
const ZONE_WORK_YARD := &"work_yard"
const ZONE_RESIDENTIAL := &"residential_yard"
const ZONE_CHECKPOINT := &"checkpoint"
const ZONE_SAFE_INTERIOR := &"safe_interior"

const OCCUPATIONS: Array[StringName] = [
	&"merchant",
	&"artisan",
	&"laborer",
	&"resident",
]

# Counts and caps are authored contract values. Seed changes assignment order,
# not density, so performance and acceptance budgets remain stable across replays.
const PROFILE_RULES: Dictionary = {
	PROFILE_DAY:
	{
		"civilian_count": 18,
		"watch_count": 3,
		"civilian_cap": 24,
		"watch_cap": 8,
		"zones": [ZONE_STREET, ZONE_WORK_YARD, ZONE_RESIDENTIAL],
		"movement_mode": MOVEMENT_WANDER,
		"anchor_mode": ANCHOR_ZONE,
		"watch_policy": &"routine_watch",
		"civilian_policy": &"normal_day_trade_and_work",
		"occupation_counts": {&"merchant": 4, &"artisan": 5, &"laborer": 5, &"resident": 4},
	},
	PROFILE_MARKET_DAY:
	{
		"civilian_count": 28,
		"watch_count": 5,
		"civilian_cap": 34,
		"watch_cap": 10,
		"zones": [ZONE_MARKET, ZONE_STREET, ZONE_WORK_YARD, ZONE_RESIDENTIAL],
		"movement_mode": MOVEMENT_ROUTE_BETWEEN_ZONES,
		"anchor_mode": ANCHOR_AUTHORED,
		"watch_policy": &"market_lane_watch",
		"civilian_policy": &"market_day_trade_and_delivery",
		"occupation_counts": {&"merchant": 10, &"artisan": 6, &"laborer": 8, &"resident": 4},
	},
	PROFILE_NIGHT:
	{
		"civilian_count": 6,
		"watch_count": 6,
		"civilian_cap": 8,
		"watch_cap": 8,
		"zones": [ZONE_RESIDENTIAL, ZONE_SAFE_INTERIOR, ZONE_CHECKPOINT],
		"movement_mode": MOVEMENT_RETURN_TO_ANCHOR,
		"anchor_mode": ANCHOR_AUTHORED,
		"watch_policy": &"curfew_watch",
		"civilian_policy": &"night_shelter_or_essential_work",
		"occupation_counts": {&"merchant": 0, &"artisan": 1, &"laborer": 1, &"resident": 4},
	},
	PROFILE_CRACKDOWN:
	{
		"civilian_count": 10,
		"watch_count": 10,
		"civilian_cap": 14,
		"watch_cap": 12,
		"zones": [ZONE_CHECKPOINT, ZONE_STREET, ZONE_SAFE_INTERIOR],
		"movement_mode": MOVEMENT_CAUTIOUS,
		"anchor_mode": ANCHOR_AUTHORED,
		"watch_policy": &"reinforced_crackdown_watch",
		"civilian_policy": &"reduced_visible_civilians",
		"occupation_counts": {&"merchant": 2, &"artisan": 2, &"laborer": 2, &"resident": 4},
	},
}


static func is_known_profile(profile_id: StringName) -> bool:
	return PROFILE_RULES.has(profile_id)


## Selects the renderer-agnostic profile from current world inputs without reading
## or mutating GameState. Explicit context flags are useful to the controller when
## a phase overlay has already resolved market/crackdown state; omitted flags fall
## back to the deterministic campaign date and phase. Precedence is crackdown,
## night, market-day, then ordinary day so a tense night never presents as trade.
static func profile_id_for_context(
	phase_id: StringName, date: Dictionary, context: Dictionary = {}
) -> StringName:
	var is_crackdown := _context_bool(context, &"crackdown", false)
	is_crackdown = is_crackdown or _context_bool(context, &"tense", false)
	if is_crackdown:
		return PROFILE_CRACKDOWN

	var time_band := _phase_time_band(phase_id)
	if context.has(&"time_band"):
		var requested_band := StringName(String(context.get(&"time_band", &"")))
		# Unknown explicit bands use the safe daytime profile rather than guessing
		# that an unrecognised phase is a curfew or consequence state.
		if requested_band == &"night" or requested_band == &"day":
			time_band = requested_band
		else:
			time_band = &"day"
	if time_band == &"night":
		return PROFILE_NIGHT

	var calendar_market_day := _is_market_day(_normalized_date(date))
	var market_day := _context_bool(context, &"market_day", calendar_market_day)
	if market_day:
		return PROFILE_MARKET_DAY
	return PROFILE_DAY


## Resolves the selected context profile through the canonical profile builder so
## actor plans, seed, date, and replay_inputs remain identical to direct profiles.
static func resolve_for_context(
	phase_id: StringName, date: Dictionary, seed: int = 0, context: Dictionary = {}
) -> Dictionary:
	return resolve(profile_id_for_context(phase_id, date, context), phase_id, date, seed)


static func _context_bool(context: Dictionary, key: StringName, fallback: bool) -> bool:
	if not context.has(key) or typeof(context[key]) != TYPE_BOOL:
		return fallback
	return bool(context[key])


static func resolve(
	profile_id: StringName, phase_id: StringName, date: Dictionary, seed: int = 0
) -> Dictionary:
	var selected_id := profile_id if is_known_profile(profile_id) else PROFILE_DAY
	var rules: Dictionary = PROFILE_RULES[selected_id]
	var resolved_date := _normalized_date(date)
	var calendar_market_day := _is_market_day(resolved_date)
	var civilians := int(rules["civilian_count"])
	var watch := int(rules["watch_count"])
	var civilian_cap := int(rules["civilian_cap"])
	var watch_cap := int(rules["watch_cap"])
	var occupation_counts: Dictionary = _copy_int_dictionary(rules["occupation_counts"])
	var zones: Array[StringName] = _shuffled_string_names(rules["zones"], seed)
	var actor_plan: Array[Dictionary] = _build_actor_plan(
		civilians,
		watch,
		occupation_counts,
		zones,
		StringName(rules["movement_mode"]),
		StringName(rules["anchor_mode"]),
		seed
	)
	var rules_snapshot := {
		"watch_vs_civilian": StringName(rules["watch_policy"]),
		"civilian_visibility": StringName(rules["civilian_policy"]),
		"profile_is_market_day": selected_id == PROFILE_MARKET_DAY,
		"calendar_is_market_day": calendar_market_day,
	}
	var snapshot := {
		"profile_id": selected_id,
		"phase_id": phase_id,
		"phase_time_band": _phase_time_band(phase_id),
		"date": resolved_date,
		"weekday_index": GameCalendarScript.weekday_index(resolved_date),
		"market_day": selected_id == PROFILE_MARKET_DAY,
		"calendar_market_day": calendar_market_day,
		"seed": seed,
		"civilian_count": civilians,
		"watch_count": watch,
		"total_count": civilians + watch,
		"civilian_cap": civilian_cap,
		"watch_cap": watch_cap,
		"actor_cap": civilian_cap + watch_cap,
		"occupation_mix": occupation_counts,
		"zone_ids": zones,
		"zone_selection": zones.duplicate(),
		"movement_mode": StringName(rules["movement_mode"]),
		"anchor_mode": StringName(rules["anchor_mode"]),
		"watch_policy": StringName(rules["watch_policy"]),
		"civilian_policy": StringName(rules["civilian_policy"]),
		"rules": rules_snapshot,
		"actor_plan": actor_plan,
		"replay_inputs":
		{
			"profile_id": selected_id,
			"phase_id": phase_id,
			"date": resolved_date.duplicate(),
			"seed": seed,
		},
	}
	# Keep the resolved snapshot as the sole source of actor records so every
	# renderer receives stable IDs and the exact replay seed used for resolution.
	snapshot["actor_plan"] = actor_records(snapshot)
	return snapshot


## Converts a resolved profile plan into renderer-agnostic crowd actor records.
## WHY: renderers need stable identities and replay metadata, while profile rules
## remain concerned only with deterministic population composition.
static func actor_records(profile: Dictionary) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var profile_id := StringName(profile.get("profile_id", PROFILE_DAY))
	var replay_seed := int(profile.get("seed", 0))
	var raw_plan: Variant = profile.get("actor_plan", [])
	if not raw_plan is Array:
		return records
	for plan_index in (raw_plan as Array).size():
		var raw_actor: Variant = (raw_plan as Array)[plan_index]
		if not raw_actor is Dictionary:
			continue
		var actor: Dictionary = raw_actor
		var actor_index := int(actor.get("actor_index", plan_index))
		var actor_id := StringName(actor.get("actor_id", &""))
		if actor_id.is_empty():
			actor_id = StringName("crowd.%s.%03d" % [String(profile_id), actor_index])
		(
			records
			. append(
				{
					"actor_id": actor_id,
					"actor_index": actor_index,
					"role": StringName(actor.get("role", &"")),
					"occupation": StringName(actor.get("occupation", &"")),
					"zone_id": StringName(actor.get("zone_id", &"")),
					"movement_mode": StringName(actor.get("movement_mode", &"")),
					"anchor_mode": StringName(actor.get("anchor_mode", &"")),
					"replay_seed": replay_seed,
				}
			)
		)
	return records


static func day(phase_id: StringName, date: Dictionary, seed: int = 0) -> Dictionary:
	return resolve(PROFILE_DAY, phase_id, date, seed)


static func night(phase_id: StringName, date: Dictionary, seed: int = 0) -> Dictionary:
	return resolve(PROFILE_NIGHT, phase_id, date, seed)


static func market_day(phase_id: StringName, date: Dictionary, seed: int = 0) -> Dictionary:
	return resolve(PROFILE_MARKET_DAY, phase_id, date, seed)


static func crackdown(phase_id: StringName, date: Dictionary, seed: int = 0) -> Dictionary:
	return resolve(PROFILE_CRACKDOWN, phase_id, date, seed)


static func _normalized_date(date: Dictionary) -> Dictionary:
	return {
		"day": int(date.get("day", GameCalendarScript.DEFAULT_DATE["day"])),
		"month": int(date.get("month", GameCalendarScript.DEFAULT_DATE["month"])),
		"year": int(date.get("year", GameCalendarScript.DEFAULT_DATE["year"])),
	}


static func _is_market_day(date: Dictionary) -> bool:
	return GameCalendarScript.weekday_index(date) in [2, 5]


static func _phase_time_band(phase_id: StringName) -> StringName:
	if (
		phase_id == GameState.PHASE_INVESTIGATION_NIGHT
		or phase_id == GameState.PHASE_CONSEQUENCE_NIGHT
	):
		return &"night"
	if (
		phase_id == GameState.PHASE_PROLOGUE_DAY
		or phase_id == GameState.PHASE_INVESTIGATION_MORNING
		or phase_id == GameState.PHASE_REFLECTION_MORNING
	):
		return &"day"
	return &"unspecified"


static func _copy_int_dictionary(source: Dictionary) -> Dictionary:
	var copied := {}
	for key in source:
		copied[key] = int(source[key])
	return copied


static func _shuffled_string_names(source: Array, seed: int) -> Array[StringName]:
	var values: Array[StringName] = []
	for value in source:
		values.append(StringName(value))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary: StringName = values[index]
		values[index] = values[swap_index]
		values[swap_index] = temporary
	return values


static func _build_actor_plan(
	civilian_count: int,
	watch_count: int,
	occupation_counts: Dictionary,
	zones: Array[StringName],
	movement_mode: StringName,
	anchor_mode: StringName,
	seed: int
) -> Array[Dictionary]:
	var occupations: Array[StringName] = []
	for occupation in OCCUPATIONS:
		for _index in range(int(occupation_counts.get(occupation, 0))):
			occupations.append(occupation)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed ^ 0x51ED
	for index in range(occupations.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary: StringName = occupations[index]
		occupations[index] = occupations[swap_index]
		occupations[swap_index] = temporary

	var plan: Array[Dictionary] = []
	for index in civilian_count:
		(
			plan
			. append(
				{
					"actor_index": index,
					"role": &"civilian",
					"occupation": occupations[index],
					"zone_id": zones[index % zones.size()],
					"movement_mode": movement_mode,
					"anchor_mode": anchor_mode,
				}
			)
		)
	for index in watch_count:
		(
			plan
			. append(
				{
					"actor_index": civilian_count + index,
					"role": &"watch",
					"occupation": &"watch",
					"zone_id": zones[(civilian_count + index) % zones.size()],
					"movement_mode": movement_mode,
					"anchor_mode": anchor_mode,
				}
			)
		)
	return plan
