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
## Degrees below ICE_FREEZE_C for full ice: a shallow puddle is solid sooner.
const ICE_FULL_BELOW_C := {ICE_PUDDLE: 2.0, ICE_FRESH: 3.0, ICE_SEA: 3.0}
## Climatological snow lies on the ground when the weeks before were cold.
const SNOW_LAG_DAYS := 18.0
const SNOW_PEAK_DEPTH_M := 0.3

## R-2075 daily weather on top of the climate: a synoptic temperature anomaly per
## calendar day (thaw days, cold snaps, mild spells). Red noise: each day adds a
## hashed shock and keeps ANOMALY_PERSISTENCE of the day before, so spells last
## several days. A pure function of the absolute day (no RNG stream, no saved
## state), so a day is equally warm whenever it is revisited, on any machine.
## Picked so the campaign opening (21 April 1343) is a near-normal spring day
## and mid-January 1343 a plain frost day (canonical test and plate dates).
const ANOMALY_SEED := 24263
const ANOMALY_PERSISTENCE := 0.8
## 0.8^30 < 0.002: older shocks no longer matter.
const ANOMALY_MEMORY_DAYS := 30
## Day-to-day spread (standard deviation, C) of Tallinn daily means: wide in
## winter (Atlantic thaws against Siberian highs), narrow in summer.
const ANOMALY_SD_WINTER_C := 4.5
const ANOMALY_SD_SUMMER_C := 2.2
## Tallinn's spread is lopsided: a winter thaw rarely lifts the daily mean more
## than about 7 C above normal (sea air), while a Siberian high can sink it far
## below. Warm departures saturate softly at this cap, cold ones stretch in winter.
const ANOMALY_WARM_CAP_C := 7.0
const ANOMALY_COLD_STRETCH_WINTER := 1.3
const ANOMALY_SHAPE_BIAS_C := 1.15
## R-2075 ice on the moat (fresh) and the sea shore, stepped day by day from
## 1 September (always ice-free) to the date: ice grows toward the day's target
## (ice_from_temperature of the day's mean) at ICE_GROWTH_PER_DAY, and only
## melts when the air is above freezing, at ICE_MELT_PER_DAY per 3.5 C of thaw.
## So a cold week's ice survives a two-day thaw, a mild week thins it, and the
## sea answers slowest. Deterministic and derivable from the date: nothing saves.
## With the mean climate it peaks like ice_cover_target() and clears in April.
const ICE_GROWTH_PER_DAY := {ICE_FRESH: 1.0 / 7.0, ICE_SEA: 1.0 / 22.0}
const ICE_MELT_PER_DAY := {ICE_FRESH: 0.08, ICE_SEA: 0.05}
const ICE_SEASON_START_DOY := 244.0
## Puddle ice: share of the air of the last hours (the rest is the last day).
const PUDDLE_AIR_SHARE := 0.85
const PUDDLE_MEMORY_DAYS := 1.0
## Half the day's temperature range (C) under a clear sky: about 2.5 in January,
## 4.5 in July. Cloud cover damps it (warm overcast nights, cool overcast days).
const DIURNAL_HALF_RANGE_WINTER_C := 2.5
const DIURNAL_HALF_RANGE_SUMMER_C := 4.5
const WARMEST_HOUR := 14.0
## The coldest hour is about sunrise: 08:30 in January, 04:30 in July.
const COLDEST_HOUR_WINTER := 8.5
const COLDEST_HOUR_SUMMER := 4.5
## Ice and wet ground answer the air a little late.
const PUDDLE_AIR_LAG_HOURS := 1.5
const MELT_AIR_LAG_HOURS := 1.0
## A thaw this recent still leaves meltwater to refreeze into glaze.
const THAW_MEMORY_HOURS := 36.0

## Memos of anomaly_for_day and the stepped ice (pure, so caching never changes
## an answer).
static var _anomaly_memo: Dictionary = {}
static var _ice_memo: Dictionary = {}


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
	return snow_share_at(mean_temperature_c(day_of_year))


## Same split for an air temperature (R-2075: a thaw day rains in January).
static func snow_share_at(temperature_c: float) -> float:
	return 1.0 - smoothstep(-1.0, 2.0, temperature_c)


## Target ice thickness 0..1 for a water kind (ICE_*) in the MEAN climate of the
## day of year. The city uses ice_cover_for(), which adds the day's weather.
static func ice_cover_target(kind: StringName, day_of_year: float) -> float:
	var lag: float = ICE_LAG_DAYS.get(kind, 0.0)
	return _ice_from_temperature(kind, mean_temperature_c(day_of_year - lag))


static func _ice_from_temperature(kind: StringName, temperature_c: float) -> float:
	var freeze: float = ICE_FREEZE_C.get(kind, -1.0)
	return clampf((freeze - temperature_c) / float(ICE_FULL_BELOW_C.get(kind, 3.0)), 0.0, 1.0)


## Absolute day number (Julian Day Number of the date's noon), so anomalies run
## on across New Year and differ between years.
static func day_index(date: Dictionary) -> int:
	return int(floor(SkyAstronomy.julian_day(date) + 0.5))


## R-2075: the day's departure (C) from the mean climate. See ANOMALY_*.
static func temperature_anomaly_c(date: Dictionary) -> float:
	return anomaly_for_day(day_index(date))


static func anomaly_for_day(day: int) -> float:
	if _anomaly_memo.has(day):
		return _anomaly_memo[day]
	var total := 0.0
	var keep := 1.0
	for back in ANOMALY_MEMORY_DAYS + 1:
		total += keep * _day_shock(day - back)
		keep *= ANOMALY_PERSISTENCE
	if total > 0.0:
		total = ANOMALY_WARM_CAP_C * tanh(total / ANOMALY_WARM_CAP_C)
	else:
		var winterness := _winterness(_day_of_year_for_index(day))
		total *= lerpf(1.0, ANOMALY_COLD_STRETCH_WINTER, winterness)
	# The cap and the stretch pull the mean down (measured over 60 winters: -1.1 C
	# in January-February); add it back so the long-run mean stays the climate's.
	total += ANOMALY_SHAPE_BIAS_C * _winterness(_day_of_year_for_index(day))
	if _anomaly_memo.size() > 4096:
		_anomaly_memo.clear()
	_anomaly_memo[day] = total
	return total


## One day's shock: a hashed uniform scaled so the red-noise sum has the day's
## climatological spread (uniform variance 1/3, AR(1) gain 1/(1 - r^2)).
static func _day_shock(day: int) -> float:
	var u := _day_hash(day) * 2.0 - 1.0
	var gain := sqrt(3.0 * (1.0 - ANOMALY_PERSISTENCE * ANOMALY_PERSISTENCE))
	return u * gain * _anomaly_sd_c(_day_of_year_for_index(day))


## Integer avalanche hash to 0..1. Every product stays below 2^63 (32-bit value
## times a 31-bit constant), so GDScript's int64 never overflows.
static func _day_hash(day: int) -> float:
	var h := (day * 0x5BD1E995 + ANOMALY_SEED) & 0xFFFFFFFF
	h ^= h >> 16
	h = (h * 0x7FEB352D) & 0xFFFFFFFF
	h ^= h >> 15
	h = (h * 0x5BD1E995) & 0xFFFFFFFF
	h ^= h >> 16
	return float(h) / 4294967295.0


static func _anomaly_sd_c(day_of_year: float) -> float:
	return lerpf(ANOMALY_SD_SUMMER_C, ANOMALY_SD_WINTER_C, _winterness(day_of_year))


## 1 on the coldest day of the mean year, 0 on the warmest.
static func _winterness(day_of_year: float) -> float:
	return 0.5 + 0.5 * cos(TAU * (day_of_year - COLDEST_DAY) / YEAR_DAYS)


## Approximate day of year for an absolute day (JDN 0 is 1 January in the Julian
## calendar; within a day of the truth, enough to scale the spread by season).
static func _day_of_year_for_index(day: int) -> float:
	return fposmod(float(day), 365.25) + 1.0


## The day's mean temperature: climate plus the synoptic anomaly.
static func day_temperature_c(date: Dictionary) -> float:
	return mean_temperature_c(day_of_year_for(date)) + temperature_anomaly_c(date)


## Anomaly at a time of day: daily values sit at noon and blend into the next
## day, so a thaw does not switch on at midnight. `day_time` = day index + progress.
static func _anomaly_at(day_time: float) -> float:
	var t := day_time - 0.5
	var day := int(floor(t))
	return lerpf(anomaly_for_day(day), anomaly_for_day(day + 1), t - float(day))


## Exponentially weighted anomaly of the days before `day` (e-folding `tau`
## days): what slow water "remembers" of the recent weather.
static func lagged_anomaly_c(day: int, tau: float) -> float:
	var weight_step := exp(-1.0 / maxf(tau, 0.01))
	var weight := 1.0
	var total := 0.0
	var norm := 0.0
	for back in int(ceil(tau * 3.0)) + 1:
		total += weight * anomaly_for_day(day - back)
		norm += weight
		weight *= weight_step
	return total / norm


## R-2075: air temperature (C) at a time of day. `cloud` 0..1 is the weather
## state's cloud cover: a clear sky widens the day's swing (frosty clear nights,
## a sunny thaw at noon), overcast flattens it.
static func air_temperature_c(date: Dictionary, progress: float, cloud: float) -> float:
	var day_time := float(day_index(date)) + progress
	return _air_at(day_time, day_of_year_for(date) + progress - 0.5, cloud)


static func _air_at(day_time: float, day_of_year: float, cloud: float) -> float:
	var half_range := lerpf(
		DIURNAL_HALF_RANGE_SUMMER_C, DIURNAL_HALF_RANGE_WINTER_C, _winterness(day_of_year)
	)
	half_range *= lerpf(1.3, 0.3, clampf(cloud, 0.0, 1.0))
	return mean_temperature_c(day_of_year) + _anomaly_at(day_time) + _diurnal_shape(
		fposmod(day_time, 1.0) * 24.0, day_of_year
	) * half_range


## -1 at sunrise, +1 at WARMEST_HOUR: a half cosine up through the morning and a
## longer one down through the evening and night (a plain cosine would put a
## January minimum at 02:00, hours before the real one).
static func _diurnal_shape(hour: float, day_of_year: float) -> float:
	var coldest := lerpf(COLDEST_HOUR_SUMMER, COLDEST_HOUR_WINTER, _winterness(day_of_year))
	if hour >= coldest and hour <= WARMEST_HOUR:
		return -cos(PI * (hour - coldest) / (WARMEST_HOUR - coldest))
	var since_peak := fposmod(hour - WARMEST_HOUR, 24.0)
	return cos(PI * since_peak / (24.0 - (WARMEST_HOUR - coldest)))


## R-2075: the fast, hourly part of the ice weather, for the city (CityWorld3D
## pushes it every frame; the slow moat and sea ice come from ice_cover_for):
## - `ice_puddle`: mostly the air of the last hours, partly the last day, so
##   puddles skin over on a frosty night and soften on a sunny thaw noon.
## - `melt` 0..1: a wet film on any ice while the air is above freezing.
## - `glaze` 0..1: a thaw within THAW_MEMORY_HOURS followed by frost now, so the
##   meltwater has refrozen into glassy glaze.
## - `air_c`: the air temperature now.
static func ice_weather(date: Dictionary, progress: float, cloud: float) -> Dictionary:
	var day := day_index(date)
	var doy := day_of_year_for(date)
	var day_time := float(day) + progress
	var hour_doy := doy + progress - 0.5
	var air := _air_at(day_time, hour_doy, cloud)
	var puddle_air := _air_at(day_time - PUDDLE_AIR_LAG_HOURS / 24.0, hour_doy, cloud)
	var puddle_temp := lerpf(
		mean_temperature_c(doy) + lagged_anomaly_c(day, PUDDLE_MEMORY_DAYS), puddle_air,
		PUDDLE_AIR_SHARE
	)
	var melt_air := _air_at(day_time - MELT_AIR_LAG_HOURS / 24.0, hour_doy, cloud)
	# Past hours use a half-cloudy sky: the weather state only knows the present.
	var thaw := 0.0
	var steps := int(THAW_MEMORY_HOURS / 3.0)
	for k in steps + 1:
		var back := float(k) * 3.0 / 24.0
		var warm := smoothstep(0.0, 2.0, _air_at(day_time - back, hour_doy - back, 0.5))
		thaw = maxf(thaw, warm * (1.0 - float(k) / float(steps + 2)))
	return {
		"air_c": air,
		"ice_puddle": _ice_from_temperature(ICE_PUDDLE, puddle_temp),
		"melt": smoothstep(-0.3, 2.0, melt_air),
		"glaze": thaw * (1.0 - smoothstep(-1.5, 0.0, air)),
	}


## Puddle ice under lying snow. Snow cover is climatological (it stays through a
## thaw day) while `ice_puddle` follows the hour, so a winter thaw used to cut open
## black water into a snowed field. Lying snow means frozen ground: standing water
## cannot soak away and freezes from below, so a thaw only wets the ice (`melt`
## film) instead of opening it. Bare ground follows `ice_puddle` alone.
static func puddle_ice_with_snow(ice_puddle: float, snow_cover: float) -> float:
	return maxf(ice_puddle, smoothstep(0.15, 0.5, snow_cover))


## R-2075: fresh (moat, stream, lakes) or sea ice 0..1 for the date with its
## weather (see ICE_GROWTH_PER_DAY). One value per day.
static func ice_cover_for(kind: StringName, date: Dictionary) -> float:
	return _stepped_ice(kind, day_index(date))


static func _stepped_ice(kind: StringName, day: int) -> float:
	var key := "%s:%d" % [kind, day]
	if _ice_memo.has(key):
		return _ice_memo[key]
	var since_start := int(fposmod(_day_of_year_for_index(day) - ICE_SEASON_START_DOY, 365.25))
	var growth: float = ICE_GROWTH_PER_DAY.get(kind, 0.1)
	var melt_rate: float = ICE_MELT_PER_DAY.get(kind, 0.05)
	var ice := 0.0
	for step_day in range(day - since_start, day + 1):
		var step_key := "%s:%d" % [kind, step_day]
		if _ice_memo.has(step_key):
			ice = _ice_memo[step_key]
			continue
		var doy := _day_of_year_for_index(step_day)
		var temperature := mean_temperature_c(doy) + anomaly_for_day(step_day)
		var target := _ice_from_temperature(kind, temperature)
		if target > ice:
			ice += (target - ice) * growth
		else:
			# Thaw eats thin ice proportionally faster (the +0.05).
			var thaw := clampf((temperature + 0.5) / 3.5, 0.0, 3.0)
			ice = maxf(ice - (ice + 0.05) * melt_rate * thaw, 0.0)
		if _ice_memo.size() > 8192:
			_ice_memo.clear()
		_ice_memo[step_key] = ice
	return ice


## 0..1 how frozen the topsoil is (soil follows the air like fresh water does):
## rain and meltwater cannot soak into frozen ground and stand in puddles.
static func soil_frost(date: Dictionary) -> float:
	var temp := (
		mean_temperature_c(day_of_year_for(date) - 5.0)
		+ lagged_anomaly_c(day_index(date), 4.0)
	)
	return 1.0 - smoothstep(-1.5, 0.5, temp)


## Floating water plants (lilies, duckweed) and lily flowers: 0 once the water is
## cold, 1 in warm water. Water trails the air by about a week and a half.
static func water_plant_vigour(day_of_year: float) -> float:
	return smoothstep(3.0, 11.0, mean_temperature_c(day_of_year - 8.0))


static func lily_flower_share(day_of_year: float) -> float:
	return smoothstep(12.0, 17.0, mean_temperature_c(day_of_year - 8.0))


## Share of reed and cattail stems still standing: they yellow and lodge through
## autumn and are gone (under ice, cut by frost) once the winter is hard.
static func reed_standing(day_of_year: float) -> float:
	return smoothstep(-3.0, 4.0, mean_temperature_c(day_of_year - 10.0))


## 0 green .. 1 dead straw-brown: autumn and winter weight of the season blend.
static func reed_dead_share(day_of_year: float) -> float:
	var weights := season_weights(day_of_year)
	return clampf(float(weights[AUTUMN]) * 1.4 + float(weights[WINTER]), 0.0, 1.0)


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
		"temperature_anomaly_c": temperature_anomaly_c(date),
		"snow_cover_target_m": snow_cover_target_m(doy),
		"snow_share": snow_share(doy),
		"ice_puddle": ice_cover_target(ICE_PUDDLE, doy),
		"ice_fresh": ice_cover_target(ICE_FRESH, doy),
		"ice_sea": ice_cover_target(ICE_SEA, doy),
		"heating_demand": heating_demand(doy),
		"clothing_warmth": clothing_warmth(doy),
	}
