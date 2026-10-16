extends RefCounted

## ADR 0061 (R-2183): the hero's wetness and body heat as pure, testable maths.
##
## Wetness 0..1: rain soaks the hero outdoors and off a roof (snow slower), a puddle barely, wading
## by depth and swimming at once; it dries by a fire fast, indoors slowly, outdoors very slowly.
## Body heat 1..0 (1 = comfortable): cold air drains it, wind and wet clothes faster. While it
## drains the body shivers, which burns stamina and halves the loss as long as stamina lasts - the
## maintainer's order "the body spends its strength first, then the temperature falls". At 0 the
## hero takes `cold` damage until he warms up or dies. Interiors and lit fires warm him.
##
## The model owns no state of its own: `step()` reads and writes the PlayerState fields, so
## GameState stays the only campaign store and the meters save with the game. Times are seconds of
## play (the caller scales debug clock speed).

## Below this felt temperature (C) the body loses heat; above it, it slowly recovers.
const COMFORT_C := 10.0
## Wet clothes feel this many degrees colder when soaked through.
const WET_CHILL_C := 8.0
## Heat lost per second per degree below comfort (scaled over 20 C). Dry at -5 C with no wind and
## no stamina left this empties full body heat in about 15 minutes; soaked at -10 C in full wind,
## in about 2.5 minutes.
const BASE_LOSS_PER_SEC := 0.0015
const LOSS_SCALE_C := 20.0
## Soaked clothes multiply the loss by up to 1 + WET_LOSS_MULT (on top of feeling WET_CHILL_C
## colder).
const WET_LOSS_MULT := 1.0
## Full wind adds this share to the loss outdoors.
const WIND_LOSS_MULT := 0.6
## The body starts shivering below this body heat.
const SHIVER_BELOW := 0.9
## While shivering and stamina lasts, the body holds this share of the loss back.
const SHIVER_HOLD := 0.5
## Stamina burnt per second by shivering.
const SHIVER_STAMINA_PER_SEC := 0.5
## Warming: by a fire, indoors, outdoors in warm air (per second, of full heat).
const FIRE_WARM_PER_SEC := 1.0 / 45.0
const INDOOR_WARM_PER_SEC := 1.0 / 240.0
const WARM_AIR_PER_SEC := 1.0 / 300.0
## An interior holds at least this temperature (C): thick walls, people, a banked fire.
const INTERIOR_MIN_C := 12.0
## Soaked clothes halve the indoor warming rate.
const INDOOR_WET_SLOWDOWN := 0.5
## A fire warms fully within FIRE_FULL_M and not at all past FIRE_REACH_M (metres).
const FIRE_FULL_M := 2.5
const FIRE_REACH_M := 5.0
## Wetness: heavy rain soaks through in about 3 minutes; snow sticks less.
const RAIN_SOAK_PER_SEC := 1.0 / 180.0
const SNOW_SOAK_SHARE := 0.35
## A puddle only wets the feet: slow, and never more than this.
const PUDDLE_SOAK_PER_SEC := 1.0 / 400.0
const PUDDLE_CAP := 0.2
## Water reaches the clothes almost at once.
const IMMERSION_SOAK_PER_SEC := 1.0
## Drying per second: by a fire, indoors, outdoors (outdoors faster in warm air and wind).
const FIRE_DRY_PER_SEC := 1.0 / 90.0
const INDOOR_DRY_PER_SEC := 1.0 / 600.0
const OUTDOOR_DRY_PER_SEC := 1.0 / 1200.0
## Below this body heat the legs stiffen and the hero walks slower, down to SLOW_FLOOR at 0.
const SLOW_BELOW := 0.35
const SLOW_FLOOR := 0.6
## At zero heat the cold takes this share of max health per second (about 75 s from full health).
const COLD_DAMAGE_SHARE_PER_SEC := 1.0 / 75.0

## HUD thresholds (COLD-2): wet and cold stages, worst last.
const DAMP_AT := 0.15
const SOAKED_AT := 0.6
const CHILLED_BELOW := 0.75
const FREEZING_BELOW := SLOW_BELOW


## Felt temperature (C): the room's temperature indoors, the air outdoors, colder when wet.
static func felt_temperature_c(env: Dictionary, wetness: float) -> float:
	var air := float(env.get("air_temp_c", 15.0))
	var t := maxf(air, INTERIOR_MIN_C) if bool(env.get("interior", false)) else air
	return t - WET_CHILL_C * clampf(wetness, 0.0, 1.0)


## 0..1 strength of the nearest lit fire at `distance_m`.
static func fire_factor(distance_m: float) -> float:
	if distance_m >= FIRE_REACH_M:
		return 0.0
	return 1.0 - smoothstep(FIRE_FULL_M, FIRE_REACH_M, distance_m)


## Advances `player_state` (PlayerState: wetness, body_heat) by `dt` seconds.
##
## env keys: air_temp_c, rain (0..1, weather-wide), snow_share (0..1), wind (0..1),
## rain_shelter (bool: indoors or under a roof), interior (bool: inside a room), fire_m (metres to
## the nearest lit fire, INF none), immersion (0..1: 0 dry land, wading depth share, 1 swimming),
## puddle (0..1 wetness of the ground underfoot while walking), stamina (current hero stamina).
##
## Returns {stamina_cost, damage_share (of max health), shivering}.
static func step(player_state: Object, dt: float, env: Dictionary) -> Dictionary:
	var out := {"stamina_cost": 0.0, "damage_share": 0.0, "shivering": false}
	if dt <= 0.0:
		return out
	var wet := clampf(float(player_state.wetness), 0.0, 1.0)
	var heat := clampf(float(player_state.body_heat), 0.0, 1.0)
	var fire := fire_factor(float(env.get("fire_m", INF)))
	var interior := bool(env.get("interior", false))
	var sheltered := bool(env.get("rain_shelter", false)) or interior

	wet = _step_wetness(wet, dt, env, fire, interior, sheltered)

	var felt := felt_temperature_c(env, wet)
	if fire > 0.0:
		heat = minf(1.0, heat + FIRE_WARM_PER_SEC * fire * dt)
	elif interior:
		# A room is always a refuge (ADR 0061): even soaked clothes only slow the warming, so a
		# freezing hero who gets indoors stops sliding toward death.
		heat = minf(1.0, heat + INDOOR_WARM_PER_SEC * (1.0 - INDOOR_WET_SLOWDOWN * wet) * dt)
	elif felt >= COMFORT_C:
		heat = minf(1.0, heat + WARM_AIR_PER_SEC * dt)
	else:
		var loss := BASE_LOSS_PER_SEC * (COMFORT_C - felt) / LOSS_SCALE_C
		loss *= 1.0 + WET_LOSS_MULT * wet
		# Only walls stop the wind; a porch roof keeps rain off but not the draught.
		if not interior:
			loss *= 1.0 + WIND_LOSS_MULT * clampf(float(env.get("wind", 0.0)), 0.0, 1.0)
		# A brief cool spell is felt but not fought; shivering starts once heat really drops.
		var shivering := heat < SHIVER_BELOW
		out["shivering"] = shivering
		var stamina_left := float(env.get("stamina", 0.0))
		if shivering and stamina_left > 0.0:
			out["stamina_cost"] = minf(stamina_left, SHIVER_STAMINA_PER_SEC * dt)
			loss *= 1.0 - SHIVER_HOLD
		heat = maxf(0.0, heat - loss * dt)
	if heat <= 0.0 and fire <= 0.0:
		out["damage_share"] = COLD_DAMAGE_SHARE_PER_SEC * dt

	player_state.wetness = wet
	player_state.body_heat = heat
	return out


static func _step_wetness(
	wet: float, dt: float, env: Dictionary, fire: float, interior: bool, sheltered: bool
) -> float:
	var immersion := clampf(float(env.get("immersion", 0.0)), 0.0, 1.0)
	if immersion > wet:
		return move_toward(wet, immersion, IMMERSION_SOAK_PER_SEC * dt)
	var rain := 0.0 if sheltered else clampf(float(env.get("rain", 0.0)), 0.0, 1.0)
	if rain > 0.01:
		var snow := clampf(float(env.get("snow_share", 0.0)), 0.0, 1.0)
		return minf(1.0, wet + RAIN_SOAK_PER_SEC * rain * lerpf(1.0, SNOW_SOAK_SHARE, snow) * dt)
	var puddle := clampf(float(env.get("puddle", 0.0)), 0.0, 1.0)
	if puddle > 0.05 and wet < PUDDLE_CAP:
		return minf(PUDDLE_CAP, wet + PUDDLE_SOAK_PER_SEC * puddle * dt)
	if immersion > 0.0:
		return wet  # standing in water: no drying
	var dry := OUTDOOR_DRY_PER_SEC
	if fire > 0.0:
		dry = FIRE_DRY_PER_SEC * fire
	elif interior:
		dry = INDOOR_DRY_PER_SEC
	else:
		var air := float(env.get("air_temp_c", 15.0))
		var wind := clampf(float(env.get("wind", 0.0)), 0.0, 1.0)
		dry *= (1.0 + maxf(air, 0.0) / 15.0) * (1.0 + wind)
	return maxf(0.0, wet - dry * dt)


## Walk speed multiplier: 1 when warm enough, down to SLOW_FLOOR at zero body heat.
static func speed_multiplier(body_heat: float) -> float:
	if body_heat >= SLOW_BELOW:
		return 1.0
	return lerpf(SLOW_FLOOR, 1.0, clampf(body_heat / SLOW_BELOW, 0.0, 1.0))


## The meters as motion-style body channels (ADR 0051), so the hero hunches and shivers (R-2185).
static func motion_channels(player_state: Object) -> Dictionary:
	return {"wet": float(player_state.wetness), "core_cold": 1.0 - float(player_state.body_heat)}


## &"" dry, &"damp" or &"soaked".
static func wet_stage(wetness: float) -> StringName:
	if wetness >= SOAKED_AT:
		return &"soaked"
	if wetness >= DAMP_AT:
		return &"damp"
	return &""


## &"" warm, &"chilled", &"freezing" or &"dying" (no heat left, health draining).
static func cold_stage(body_heat: float) -> StringName:
	if body_heat <= 0.0:
		return &"dying"
	if body_heat < FREEZING_BELOW:
		return &"freezing"
	if body_heat < CHILLED_BELOW:
		return &"chilled"
	return &""
