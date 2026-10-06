class_name VegetationPhenology
extends RefCounted

## Deterministic seasonal state of tree foliage for one species on one campaign
## date. Pure function of the Julian day-of-year: no RNG, no saved state, so the
## crown a player sees always agrees with the HUD date, a reload, and a seam
## crossing. Timings follow northern Estonian phenology (Tallinn area):
## bud-burst in early-to-mid May, full leaf June-August, colouring from mid
## September, bare by early November. The vertical slice opens on 21 April, so
## deciduous crowns there read as early spring: sparse, small, light green.

const EVERGREEN := &"evergreen"
## Birch, willow, aspen, alder, rowan, hawthorn and the orchard trees leaf first.
const EARLY_DECIDUOUS := &"early_deciduous"
## Oak and ash are the classic late flushers; elm/linden/maple sit in between.
const LATE_DECIDUOUS := &"late_deciduous"

const EVERGREEN_SPECIES: Array[StringName] = [&"spruce", &"pine", &"juniper"]
const LATE_SPECIES: Array[StringName] = [&"oak", &"ash", &"linden", &"elm", &"maple"]

## Day-of-year anchors (non-leap year numbering; leap years shift by one day
## after February through GameCalendar.day_of_year, close enough for foliage).
## bud: first swelling buds; flush: leaves fully expanded; colour: autumn
## colouring starts; fall_end: crown is bare.
const TIMINGS := {
	EARLY_DECIDUOUS: {"bud": 100, "flush": 150, "colour": 255, "fall_end": 305},
	LATE_DECIDUOUS: {"bud": 106, "flush": 160, "colour": 262, "fall_end": 308},
}
## Late-April "spring look": crowns hold this share of leaves at bud-burst so the
## slice is never a winter scene, while still clearly not summer.
const BUDBURST_DENSITY := 0.18

## Per-species autumn palette (linear-ish albedo multipliers). Two colours per
## species; the canopy shader mixes them by a per-leaf hash and browns the
## oldest leaves, so one crown carries several hues like real autumn trees.
const AUTUMN_COLORS := {
	&"birch": [Color(1.00, 0.78, 0.18), Color(0.96, 0.62, 0.12)],
	&"aspen": [Color(1.00, 0.72, 0.14), Color(0.92, 0.36, 0.10)],
	&"maple": [Color(0.95, 0.30, 0.08), Color(0.98, 0.62, 0.10)],
	&"rowan": [Color(0.88, 0.22, 0.08), Color(0.96, 0.48, 0.10)],
	&"hawthorn": [Color(0.84, 0.30, 0.10), Color(0.70, 0.40, 0.12)],
	&"cherry": [Color(0.90, 0.28, 0.10), Color(0.96, 0.58, 0.16)],
	&"oak": [Color(0.66, 0.42, 0.14), Color(0.52, 0.32, 0.12)],
	&"linden": [Color(0.96, 0.80, 0.22), Color(0.80, 0.70, 0.22)],
	&"elm": [Color(0.92, 0.76, 0.20), Color(0.74, 0.60, 0.20)],
	&"alder": [Color(0.56, 0.52, 0.20), Color(0.46, 0.40, 0.18)],
}
const DEFAULT_AUTUMN_COLORS := [Color(0.94, 0.70, 0.18), Color(0.80, 0.44, 0.12)]
const SUMMER_LEAF_COLOR := Color(0.30, 0.42, 0.20)
const FRESH_LEAF_COLOR := Color(0.58, 0.74, 0.26)
const NEEDLE_COLOR := Color(0.20, 0.30, 0.18)

## Month windows (inclusive) in which the fruit mesh is shown.
const FRUIT_MONTHS := {
	&"cherry": [7, 7],
	&"plum": [8, 9],
	&"apple": [8, 10],
	&"pear": [8, 10],
	&"rowan": [8, 11],
	&"hawthorn": [8, 11],
	&"blackthorn": [9, 11],
}


static func category_for(species: StringName) -> StringName:
	if species in EVERGREEN_SPECIES:
		return EVERGREEN
	if species in LATE_SPECIES:
		return LATE_DECIDUOUS
	return EARLY_DECIDUOUS


static func is_evergreen(species: StringName) -> bool:
	return category_for(species) == EVERGREEN


## Returns the foliage state for one species on one date:
## - leaf_density: share of leaves present (0 bare .. 1 full crown)
## - leaf_scale: leaf size relative to mature (young leaves are small)
## - freshness: young-leaf yellow-green tint strength (0..1)
## - autumn: colouring progress (0 green .. 1 fully coloured)
## - fall_rate: how readily leaves drop right now (0..1); drives ambient leaf fall
## - fruit_visible: fruit mesh shown in this month
static func state_for(species: StringName, date: Dictionary) -> Dictionary:
	var normalized := GameCalendar.normalize_date(date)
	var day := float(GameCalendar.day_of_year(normalized))
	var month := int(normalized["month"])
	var fruit_visible := _fruit_visible(species, month)
	if is_evergreen(species):
		# Needles stay; winter crowns dull slightly and shed a trickle in storms.
		var winter := _winter_weight(day)
		return {
			"leaf_density": 1.0,
			"leaf_scale": 1.0,
			"freshness": _smooth_window(day, 140.0, 160.0, 185.0) * 0.35,
			"autumn": 0.0,
			"winter_dull": winter,
			"fall_rate": 0.04,
			"fruit_visible": fruit_visible,
		}
	var timing: Dictionary = TIMINGS[category_for(species)]
	var bud := float(timing["bud"])
	var flush := float(timing["flush"])
	var colour := float(timing["colour"])
	var fall_end := float(timing["fall_end"])
	var density := 0.0
	var leaf_scale := 1.0
	var freshness := 0.0
	var autumn := 0.0
	var fall_rate := 0.0
	if day < bud or day >= fall_end:
		density = 0.0
		leaf_scale = 0.3
	elif day < flush:
		# Spring: a visible bud-burst share at once, then smooth expansion.
		var t := _smooth((day - bud) / (flush - bud))
		density = lerpf(BUDBURST_DENSITY, 1.0, t)
		leaf_scale = lerpf(0.42, 1.0, t)
		freshness = 1.0 - t * 0.55
	elif day < colour:
		density = 1.0
		# Fresh green fades during June into the darker summer leaf.
		freshness = 0.45 * (1.0 - _smooth((day - flush) / 25.0))
	else:
		var t := clampf((day - colour) / (fall_end - colour), 0.0, 1.0)
		autumn = _smooth(minf(t * 1.6, 1.0))
		# Leaves hang on while colouring, then drop fast in October storms.
		density = 1.0 - _smooth(clampf((t - 0.30) / 0.70, 0.0, 1.0))
		fall_rate = clampf(sin(PI * clampf((t - 0.15) / 0.85, 0.0, 1.0)), 0.0, 1.0)
	return {
		"leaf_density": density,
		"leaf_scale": leaf_scale,
		"freshness": freshness,
		"autumn": autumn,
		"winter_dull": 0.0,
		"fall_rate": fall_rate,
		"fruit_visible": fruit_visible,
	}


static func autumn_colors(species: StringName) -> Array:
	return AUTUMN_COLORS.get(species, DEFAULT_AUTUMN_COLORS)


## Representative colours of leaves that fall off this species today. Used by
## hit bursts and ambient leaf fall so particles match the crown above them.
static func falling_leaf_colors(species: StringName, date: Dictionary) -> Array[Color]:
	var state := state_for(species, date)
	var colors: Array[Color] = []
	if is_evergreen(species):
		colors.append(NEEDLE_COLOR)
		colors.append(NEEDLE_COLOR.lerp(Color(0.48, 0.36, 0.18), 0.6))
		return colors
	var green := SUMMER_LEAF_COLOR.lerp(FRESH_LEAF_COLOR, float(state["freshness"]))
	var autumn := float(state["autumn"])
	for color: Color in autumn_colors(species):
		colors.append(green.lerp(color, autumn))
	# Some loose leaves are always older/browner than the crown average.
	colors.append(green.lerp(Color(0.46, 0.32, 0.14), clampf(0.25 + autumn, 0.0, 1.0)))
	return colors


## How many leaves a melee hit knocks loose. Bare trees drop nothing; a loaded
## autumn crown drops the most; conifers shed a few needles.
static func hit_leaf_count(species: StringName, date: Dictionary, strength: float) -> int:
	var state := state_for(species, date)
	var density := float(state["leaf_density"])
	if density <= 0.02:
		return 0
	var looseness := 0.35 + float(state["fall_rate"]) * 1.4 + float(state["autumn"]) * 0.4
	if is_evergreen(species):
		looseness = 0.18
	var base := 26.0 * clampf(strength, 0.2, 2.0) * density * looseness
	return clampi(int(round(base)), 1, 64)


static func _fruit_visible(species: StringName, month: int) -> bool:
	if not FRUIT_MONTHS.has(species):
		return false
	var window: Array = FRUIT_MONTHS[species]
	return month >= int(window[0]) and month <= int(window[1])


static func _winter_weight(day: float) -> float:
	# 1 in deep winter (Dec-Feb), 0 from May to September.
	var distance := minf(absf(day - 15.0), absf(day - 380.0))
	return 1.0 - _smooth(clampf((distance - 30.0) / 90.0, 0.0, 1.0))


static func _smooth_window(
	day: float, rise_start: float, rise_end: float, fall_end: float
) -> float:
	if day < rise_start or day > fall_end:
		return 0.0
	if day < rise_end:
		return _smooth((day - rise_start) / (rise_end - rise_start))
	return 1.0 - _smooth((day - rise_end) / (fall_end - rise_end))


static func _smooth(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
