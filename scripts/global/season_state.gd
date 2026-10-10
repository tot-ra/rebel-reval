class_name SeasonState
extends RefCounted

## R-SEASONS core (ADR 0045). Deterministic climate of northern Estonia (Tallinn)
## as a pure function of the campaign date: no RNG, no node, no saved state, so
## foliage, snow, ice, smoke, clothing and the HUD all read the same answer on
## reload and across seam crossings. Stateful things (settled snow depth, ice
## thickness, footprints) belong to their own systems; they use the targets here.
##
## The temperature curve is a sinusoid fitted to Tallinn normals: coldest around
## doy 30 (-4 C), warmest around doy 212 (+17 C), annual mean 6.4 C.

const WINTER := &"winter"
const SPRING := &"spring"
const SUMMER := &"summer"
const AUTUMN := &"autumn"
const SEASONS: Array[StringName] = [WINTER, SPRING, SUMMER, AUTUMN]

const MEAN_TEMPERATURE_C := 6.4
const TEMPERATURE_AMPLITUDE_C := 10.8
const COLDEST_DAY := 30.0
const WARMEST_DAY := 212.0
const YEAR_DAYS := 365.0

## Ice kinds freeze at different speeds: a puddle skins over in one cold night, a
## pond or river needs a cold fortnight, the sea shore a cold month.
const ICE_PUDDLE := &"puddle"
const ICE_FRESH := &"fresh"
const ICE_SEA := &"sea"
const ICE_LAG_DAYS := {ICE_PUDDLE: 0.0, ICE_FRESH: 10.0, ICE_SEA: 28.0}
const ICE_FREEZE_C := {ICE_PUDDLE: -0.5, ICE_FRESH: -2.0, ICE_SEA: -3.0}
## Climatological snow lies on the ground when the weeks before were cold.
const SNOW_LAG_DAYS := 18.0
const SNOW_PEAK_DEPTH_M := 0.3


static func mean_temperature_c(day_of_year: float) -> float:
	var phase := TAU * (day_of_year - COLDEST_DAY) / YEAR_DAYS
	return MEAN_TEMPERATURE_C - TEMPERATURE_AMPLITUDE_C * cos(phase)


## Smooth 0..1 weight per season. Winter and summer come from temperature;
## the shoulder is spring while the year warms and autumn while it cools.
static func season_weights(day_of_year: float) -> Dictionary:
	var temperature := mean_temperature_c(day_of_year)
	var winter := 1.0 - smoothstep(-2.0, 2.0, temperature)
	var summer := smoothstep(8.0, 12.0, temperature)
	var shoulder := maxf(1.0 - winter - summer, 0.0)
	var warming := day_of_year < WARMEST_DAY and day_of_year > COLDEST_DAY
	return {
		WINTER: winter,
		SPRING: shoulder if warming else 0.0,
		SUMMER: summer,
		AUTUMN: 0.0 if warming else shoulder,
	}


static func season_for_day(day_of_year: float) -> StringName:
	var weights := season_weights(day_of_year)
	var best := WINTER
	var best_weight := -1.0
	for season in SEASONS:
		if float(weights[season]) > best_weight:
			best_weight = float(weights[season])
			best = season
	return best


## Climatological settled snow depth in metres; weather adds to it and thaws it.
static func snow_cover_target_m(day_of_year: float) -> float:
	var lagged := mean_temperature_c(day_of_year - SNOW_LAG_DAYS)
	return SNOW_PEAK_DEPTH_M * clampf((1.0 - lagged) / 6.0, 0.0, 1.0)


## Share of precipitation that falls as snow, 1 well below freezing, 0 above +2.
static func snow_share(day_of_year: float) -> float:
	return 1.0 - smoothstep(-1.0, 2.0, mean_temperature_c(day_of_year))


## Target ice thickness 0..1 for a water kind (ICE_*).
static func ice_cover_target(kind: StringName, day_of_year: float) -> float:
	var lag: float = ICE_LAG_DAYS.get(kind, 0.0)
	var freeze: float = ICE_FREEZE_C.get(kind, -1.0)
	var cold := freeze - mean_temperature_c(day_of_year - lag)
	return clampf(cold / 6.0, 0.0, 1.0)


## 0.15 in midsummer (cooking fires only) up to 1 in deep winter: scales chimney smoke.
static func heating_demand(day_of_year: float) -> float:
	return clampf((16.0 - mean_temperature_c(day_of_year)) / 20.0, 0.15, 1.0)


## 0 light linen to 1 furs and heavy wool, for citizen wardrobes.
static func clothing_warmth(day_of_year: float) -> float:
	return clampf((18.0 - mean_temperature_c(day_of_year)) / 22.0, 0.0, 1.0)


static func day_of_year_for(date: Dictionary) -> float:
	return float(GameCalendar.day_of_year(date))


## Everything the presentation systems need for one date, in one dictionary.
static func snapshot(date: Dictionary) -> Dictionary:
	var doy := day_of_year_for(date)
	return {
		"day_of_year": int(doy),
		"season": season_for_day(doy),
		"weights": season_weights(doy),
		"temperature_c": mean_temperature_c(doy),
		"snow_cover_target_m": snow_cover_target_m(doy),
		"snow_share": snow_share(doy),
		"ice_puddle": ice_cover_target(ICE_PUDDLE, doy),
		"ice_fresh": ice_cover_target(ICE_FRESH, doy),
		"ice_sea": ice_cover_target(ICE_SEA, doy),
		"heating_demand": heating_demand(doy),
		"clothing_warmth": clothing_warmth(doy),
	}
