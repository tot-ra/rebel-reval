class_name SkyAstronomy
extends RefCounted

## Deterministic solar, lunar, sidereal, and tide calculations for medieval
## Reval. This scene-tree-free module lets rendering and gameplay share the same
## physical sky without making either depend on the weather state machine.

const GAME_CALENDAR := preload("res://scripts/global/game_calendar.gd")

## Approximate solar orbit for Reval. World +X is east, -Z north, and +Y zenith.
const EARTH_AXIAL_TILT_DEGREES := 23.44
## In 1343 the Julian calendar was about eight days behind the seasonal equinox.
const CAMPAIGN_VERNAL_EQUINOX_DAY_OF_YEAR := 72.0

## Mean lunar orbit and phase reference. The epoch preserves the historical
## 1343-04-25 new moon and 1343-05-10 full moon in the campaign calendar.
const SYNODIC_MONTH_DAYS := 29.530588853
const NEW_MOON_EPOCH_JULIAN_DAY := 2451550.25972
const LUNAR_APPARENT_ROTATIONS_PER_SOLAR_DAY := 1.0 - 1.0 / SYNODIC_MONTH_DAYS
const LUNAR_ORBITAL_INCLINATION_DEGREES := 5.14
const DRACONIC_MONTH_DAYS := 27.212220817

## Restrained Baltic equilibrium-tide approximation. Rendering supplies its own
## visual scale because Reval's real tidal range is small.
const SOLAR_TIDE_FORCE_RATIO := 0.46
const TIDE_BASIN_LAG_PROGRESS := 1.5 / 24.0

## Astronomical reference for Reval (Tallinn) on St George's Night.
const OBSERVER_LATITUDE_DEGREES := 59.437
const SKY_EPOCH_YEAR := 1343.0
const REFERENCE_DATE := "1343-04-23"
const MIDNIGHT_SIDEREAL_DEGREES := 218.31
const SIDEREAL_ROTATIONS_PER_SOLAR_DAY := 1.00273790935

## Solar declination follows the campaign's Julian calendar. The approximation is
## intentionally deterministic and is accurate enough to reproduce Reval's long
## summer days, short winter days, and east-to-west daily traversal.
static func solar_declination_degrees(date: Dictionary) -> float:
	var year := int(date.get("year", GAME_CALENDAR.DEFAULT_DATE["year"]))
	var year_length := float(GAME_CALENDAR.days_in_year(year))
	var ordinal := float(GAME_CALENDAR.day_of_year(date))
	return EARTH_AXIAL_TILT_DEGREES * sin(TAU * (ordinal - CAMPAIGN_VERNAL_EQUINOX_DAY_OF_YEAR) / year_length)


## Local ENU direction for a body with the given equatorial declination.
## +X east, -Z north, and +Y up. Progress 0.5 is local meridian transit.
static func celestial_direction(progress: float, declination_degrees: float) -> Vector3:
	var latitude := deg_to_rad(OBSERVER_LATITUDE_DEGREES)
	var declination := deg_to_rad(declination_degrees)
	var hour_angle := (wrapf(progress, 0.0, 1.0) - 0.5) * TAU
	var east := -cos(declination) * sin(hour_angle)
	var north := (
		cos(latitude) * sin(declination)
		- sin(latitude) * cos(declination) * cos(hour_angle)
	)
	var up := (
		sin(latitude) * sin(declination)
		+ cos(latitude) * cos(declination) * cos(hour_angle)
	)
	return Vector3(east, up, -north).normalized()


## Sky and water use the same sidereal rotation. The small excess over one turn
## per solar day keeps stars moving faster than the sun instead of locked to it.
static func sidereal_angle_for_progress(progress: float) -> float:
	return (
		deg_to_rad(MIDNIGHT_SIDEREAL_DEGREES)
		+ wrapf(progress, 0.0, 1.0) * TAU * SIDEREAL_ROTATIONS_PER_SOLAR_DAY
	)


## Returns the observer-to-sun direction in the sky shader's ENU world frame:
## +X east, -Z north, and +Y up. Local solar noon is progress 0.5.
static func solar_direction(progress: float, date: Dictionary = {}) -> Vector3:
	var effective_date := GAME_CALENDAR.DEFAULT_DATE if date.is_empty() else date
	return celestial_direction(progress, solar_declination_degrees(effective_date))


static func solar_elevation_degrees(progress: float, date: Dictionary = {}) -> float:
	return rad_to_deg(asin(clampf(solar_direction(progress, date).y, -1.0, 1.0)))


## Matches `sun_visibility` in sky_weather_3d.gdshader. Water specular uses the
## same fade so open water cannot keep a sun glint after the disk has set.
const SUN_DISK_FADE_START := -0.05
const SUN_DISK_FADE_END := 0.05


static func sun_disk_visibility(sun_direction: Vector3) -> float:
	return smoothstep(SUN_DISK_FADE_START, SUN_DISK_FADE_END, sun_direction.y)


static func sunrise_sunset_hours(date: Dictionary = {}) -> Dictionary:
	var effective_date := GAME_CALENDAR.DEFAULT_DATE if date.is_empty() else date
	var latitude := deg_to_rad(OBSERVER_LATITUDE_DEGREES)
	var declination := deg_to_rad(solar_declination_degrees(effective_date))
	var horizon_hour_angle := acos(clampf(-tan(latitude) * tan(declination), -1.0, 1.0))
	var half_day_hours := rad_to_deg(horizon_hour_angle) / 15.0
	return {
		"sunrise": 12.0 - half_day_hours,
		"sunset": 12.0 + half_day_hours,
		"day_length": half_day_hours * 2.0,
	}


static func daylight_blend(progress: float, date: Dictionary = {}) -> float:
	# Civil twilight keeps dawn/dusk gradual while 0.5 still marks the geometric
	# horizon, so the day bucket spans exactly the date-dependent daylight hours.
	return smoothstep(-6.0, 6.0, solar_elevation_degrees(progress, date))


## Converts a Julian-calendar campaign date to astronomical Julian day at
## midnight for the deterministic lunar-phase calculation below.
static func julian_day(date: Dictionary) -> float:
	var year := int(date.get("year", GAME_CALENDAR.DEFAULT_DATE["year"]))
	var month := clampi(int(date.get("month", GAME_CALENDAR.DEFAULT_DATE["month"])), 1, 12)
	var day := clampi(
		int(date.get("day", GAME_CALENDAR.DEFAULT_DATE["day"])),
		1,
		GAME_CALENDAR.days_in_month(month, year)
	)
	if month <= 2:
		year -= 1
		month += 12
	return (
		floor(365.25 * float(year + 4716))
		+ floor(30.6001 * float(month + 1))
		+ float(day)
		- 1524.5
	)


## 0 is new moon, 0.25 first quarter, 0.5 full moon, and 0.75 last
## quarter. The campaign date owns the phase because the accelerated visual day
## intentionally loops without advancing story time.
static func lunar_phase(date: Dictionary = {}) -> float:
	var effective_date := GAME_CALENDAR.DEFAULT_DATE if date.is_empty() else date
	var days_since_epoch := julian_day(effective_date) - NEW_MOON_EPOCH_JULIAN_DAY
	return fposmod(days_since_epoch / SYNODIC_MONTH_DAYS, 1.0)


static func lunar_illumination(phase: float) -> float:
	return (1.0 - cos(wrapf(phase, 0.0, 1.0) * TAU)) * 0.5


## Whether the pre-dawn air is primed for radiation fog on a given date: a
## deterministic per-day stand-in for the humidity and overnight temperature drop
## that morning mist needs. 0 is a dry, well-mixed night; 1 is damp, still, and
## fog-prone. Only some mornings clear the bar in MapView3D, so fog stays an
## occasional event rather than a daily one, and repeats identically per the
## deterministic-state rule since it is keyed to the calendar day.
static func morning_fog_potential(date: Dictionary = {}) -> float:
	var effective_date := GAME_CALENDAR.DEFAULT_DATE if date.is_empty() else date
	var day := julian_day(effective_date)
	return fposmod(sin(day * 12.9898 + 4.1) * 43758.5453, 1.0)


static func moonlight_strength(progress: float, date: Dictionary = {}) -> float:
	var effective_date := GAME_CALENDAR.DEFAULT_DATE if date.is_empty() else date
	var horizon_visibility := smoothstep(-0.04, 0.03, lunar_direction(progress, effective_date).y)
	return lunar_illumination(lunar_phase(effective_date)) * horizon_visibility


## Lunar declination = solar seasonal declination plus the ~5.14° orbital tilt.
## The draconic sine keeps the moon on a path that is never identical to the sun.
static func lunar_declination_degrees(date: Dictionary = {}) -> float:
	var effective_date := GAME_CALENDAR.DEFAULT_DATE if date.is_empty() else date
	var days_since_epoch := julian_day(effective_date) - NEW_MOON_EPOCH_JULIAN_DAY
	var orbital_latitude := sin(TAU * days_since_epoch / DRACONIC_MONTH_DAYS)
	return (
		solar_declination_degrees(effective_date)
		+ LUNAR_ORBITAL_INCLINATION_DEGREES * orbital_latitude
	)


## Uses the same local horizon frame as the sun, but a phase-shifted hour angle
## and a tilted declination. New moon stays near the sun, full moon opposite it,
## and the inclination keeps the daily arcs from stacking on one path.
static func lunar_direction(progress: float, date: Dictionary = {}) -> Vector3:
	var effective_date := GAME_CALENDAR.DEFAULT_DATE if date.is_empty() else date
	var wrapped_progress := wrapf(progress, 0.0, 1.0)
	var phase := lunar_phase(effective_date)
	var lunar_progress := wrapf(
		wrapped_progress * LUNAR_APPARENT_ROTATIONS_PER_SOLAR_DAY - phase,
		0.0,
		1.0
	)
	return celestial_direction(lunar_progress, lunar_declination_degrees(effective_date))


static func lunar_elevation_degrees(progress: float, date: Dictionary = {}) -> float:
	return rad_to_deg(asin(clampf(lunar_direction(progress, date).y, -1.0, 1.0)))


## Angular separation between the live sun and moon disks, in degrees.
static func sun_moon_separation_degrees(progress: float, date: Dictionary = {}) -> float:
	var effective_date := GAME_CALENDAR.DEFAULT_DATE if date.is_empty() else date
	var sun_direction := solar_direction(progress, effective_date)
	var moon_direction := lunar_direction(progress, effective_date)
	return rad_to_deg(acos(clampf(sun_direction.dot(moon_direction), -1.0, 1.0)))


## Normalized equilibrium tide in [-1, 1]. Using the sub-lunar and sub-solar
## longitudes produces two highs per day. Their relative phase makes spring tides
## stronger near new/full moon and neap tides weaker near the quarter moons.
static func tide_level(progress: float, date: Dictionary = {}) -> float:
	var effective_date := GAME_CALENDAR.DEFAULT_DATE if date.is_empty() else date
	var delayed_progress := wrapf(progress - TIDE_BASIN_LAG_PROGRESS, 0.0, 1.0)
	var lunar_transit := wrapf(
		delayed_progress * LUNAR_APPARENT_ROTATIONS_PER_SOLAR_DAY
		- lunar_phase(effective_date),
		0.0,
		1.0
	)
	var solar_transit := wrapf(delayed_progress - 0.5, 0.0, 1.0)
	var lunar_tide := cos(lunar_transit * TAU * 2.0)
	var solar_tide := cos(solar_transit * TAU * 2.0)
	return clampf(
		(lunar_tide + solar_tide * SOLAR_TIDE_FORCE_RATIO)
		/ (1.0 + SOLAR_TIDE_FORCE_RATIO),
		-1.0,
		1.0
	)
