# gdlint:disable=class-definitions-order
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
## Days after the crown is bare until this year's coloured litter has browned.
const LITTER_BROWNING_DAYS := 45.0

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

## Shrub flowers and fruit by day of year (R-2125), inclusive [from, to]. A window
## with from > to wraps the new year (rosehips and guelder berries hang into winter).
const SHRUB_BLOOM_DAYS := {
	&"elder": [152, 186],
	&"guelder_rose": [152, 186],
	&"willow_shrub": [91, 125],
	&"alder_shrub": [79, 115],
	&"dog_rose": [156, 196],
	&"raspberry": [150, 175],
}
const SHRUB_FRUIT_DAYS := {
	&"elder": [222, 293],
	&"guelder_rose": [232, 59],
	&"spindle": [244, 334],
	&"sea_buckthorn": [232, 74],
	&"juniper_shrub": [200, 59],
	&"dog_rose": [227, 59],
	&"raspberry": [182, 243],
}


## True when this shrub carries `kind` (&"flower" or &"fruit") on the date.
static func shrub_adornment_visible(
	species: StringName, kind: StringName, date: Dictionary
) -> bool:
	var table: Dictionary = SHRUB_BLOOM_DAYS if kind == &"flower" else SHRUB_FRUIT_DAYS
	if not table.has(species):
		return false
	var day := GameCalendar.day_of_year(GameCalendar.normalize_date(date))
	var window: Array = table[species]
	var from := int(window[0])
	var to := int(window[1])
	return (day >= from and day <= to) if from <= to else (day >= from or day <= to)


## Wild-plant (forb) phases for CityForbs (R-1557), by species. Tallinn-area
## timings: rosettes show from mid April and die back under the November frost
## and snow; dandelion flowers May-June and seeds in June; clover flowers June-
## August; plantain spikes June-September; second-year burdock carries green
## burrs July-August that dry brown in September-October; oxeye daisy flowers
## June-July, before and after the hay cut a leaf rosette (R-1807).
const FORB_NONE := &"none"
const FORB_LEAVES := &"leaves"
const FORB_FLOWER := &"flower"
## Dandelion in June: flowers, seed clocks and rosettes together.
const FORB_FLOWER_SEED := &"flower_seed"
## Burdock: green burrs with purple tufts.
const FORB_BURRS := &"burrs"
const FORB_DRY_BURRS := &"dry_burrs"
## Day-of-year span (non-leap numbering, inclusive) in which forbs are above ground.
const FORB_GROWING := [105, 319]
## Species -> [first day, last day, phase] windows inside the growing season;
## days outside every window are FORB_LEAVES.
const FORB_WINDOWS := {
	&"dandelion": [[121, 151, FORB_FLOWER], [152, 181, FORB_FLOWER_SEED]],
	&"plantain": [[152, 273, FORB_FLOWER]],
	&"white_clover": [[152, 243, FORB_FLOWER]],
	&"red_clover": [[152, 243, FORB_FLOWER]],
	&"burdock": [[182, 243, FORB_BURRS], [244, 304, FORB_DRY_BURRS]],
	&"oxeye_daisy": [[152, 212, FORB_FLOWER]],
}


## Phase of a forb species on a day of the year (GameCalendar.day_of_year).
## Pure: the same day always gives the same phase.
static func forb_phase(species: StringName, day: int) -> StringName:
	if day < int(FORB_GROWING[0]) or day > int(FORB_GROWING[1]):
		return FORB_NONE
	for window: Array in FORB_WINDOWS.get(species, []):
		if day >= int(window[0]) and day <= int(window[1]):
			return window[2]
	return FORB_LEAVES


## R-2129 wetland and water-edge plants (CityMoatPlants), Tallinn-area dates.
## Emergent and bank plants follow the calendar; the floating lilies and
## duckweed keep SeasonState's water-temperature curves.
##   reed (Phragmites)  shoots green the bed mid May-June; plumes from August,
##                      purple-brown, silver-buff seed plumes by October; the
##                      stand dies straw-brown in October and stays standing
##                      through winter (in the moat ice), a third lodged by May
##   cattail (Typha)    green spikes late June, brown by August; the heads
##                      stand all winter and break into fluff from December
##   sedge (Carex)      tussocks green in May, straw from October, standing
##   marsh marigold     yellow cups mid April-May, leaves until mid August
##   meadowsweet        cream plumes late June-mid August, then brown heads
##   purple loosestrife magenta spikes July-mid September, then dry stalks
##   fern               croziers in May, fronds open late May, brown in
##                      October, collapsed brown litter through winter
## Dry seed heads and stalks after flowering.
const FORB_SEED := &"seed"
const FERN_CROZIER := &"crozier"
const FERN_OPEN := &"open"
const FERN_BROWN := &"brown"
const FERN_LITTER := &"litter"
## Species -> [first day, last day, phase]; outside every window FORB_NONE
## (fern: FERN_LITTER, its dead fronds lie on the ground until the croziers).
const WETLAND_WINDOWS := {
	&"marsh_marigold": [[105, 151, FORB_FLOWER], [152, 228, FORB_LEAVES]],
	&"meadowsweet": [[121, 175, FORB_LEAVES], [176, 228, FORB_FLOWER], [229, 300, FORB_SEED]],
	&"purple_loosestrife":
	[[135, 190, FORB_LEAVES], [191, 258, FORB_FLOWER], [259, 340, FORB_SEED]],
	&"fern": [[125, 145, FERN_CROZIER], [146, 272, FERN_OPEN], [273, 305, FERN_BROWN]],
}


## Phase of a wetland bank plant on a day of the year. Pure.
static func wetland_phase(species: StringName, day: int) -> StringName:
	for window: Array in WETLAND_WINDOWS.get(species, []):
		if day >= int(window[0]) and day <= int(window[1]):
			return window[2]
	return FERN_LITTER if species == &"fern" else FORB_NONE


## 0 dead straw .. 1 green for the reed bed and the cattail leaves: the old
## stand is straw until the new shoots overtop it (mid May-June), and it ripens
## from September to straw by late October.
static func reed_green(day: int) -> float:
	return _plateau(float(day), 135.0, 178.0, 250.0, 298.0)


## Share of reed and cattail stems still standing. Dead canes stand through the
## winter, in the moat ice too; storms and snow lodge about a third by spring,
## then the new growth fills the stand again by late June.
static func reed_standing(day: int) -> float:
	if day >= 178 and day < 305:
		return 1.0
	# Days since 1 November (day 305): 0 .. 238 on 26 June.
	var since := float((day - 305 + 365) % 365)
	if since <= 185.0:
		return 1.0 - 0.35 * _smooth(since / 185.0)
	return 0.65 + 0.35 * _smooth((since - 185.0) / 53.0)


## Reed plumes (panicles): share shown and ripeness (0 purple-brown flowering
## plume in August, 1 silver-buff seed plume from October). Old plumes stay on
## the dead canes over winter and break off through spring.
static func reed_plume(day: int) -> Vector2:
	var ripe := _smooth((float(day) - 236.0) / 46.0)
	if day >= 205:
		return Vector2(_smooth((float(day) - 205.0) / 20.0), ripe)
	return Vector2(1.0 - _smooth((float(day) - 60.0) / 100.0), 1.0)


## Cattail spikes: share shown, ripeness (0 green female spike, 1 dark brown)
## and fluff (0 velvet, 1 broken into seed wool). Heads stand all winter and
## shed into fluff from December; the last are gone by mid May.
static func cattail_head(day: int) -> Vector3:
	if day >= 172:
		return Vector3(
			_smooth((float(day) - 172.0) / 14.0),
			_smooth((float(day) - 190.0) / 35.0),
			0.5 * _smooth((float(day) - 335.0) / 30.0)
		)
	return Vector3(
		1.0 - _smooth((float(day) - 100.0) / 35.0), 1.0, 0.5 + 0.5 * _smooth(float(day) / 90.0)
	)


## 0 straw .. 1 green for sedge tussocks: green in May, straw from October; the
## old leaves keep a pale mound through winter.
static func sedge_green(day: int) -> float:
	return _plateau(float(day), 110.0, 150.0, 262.0, 300.0)


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


## Share (0..1) of the litter under this species that shows this year's autumn
## colour rather than weathered brown: it grows as the crown drops its leaves,
## then browns out over the following weeks. Evergreens: always 0. Pure.
static func fresh_litter_share(species: StringName, date: Dictionary) -> float:
	if is_evergreen(species):
		return 0.0
	var timing: Dictionary = TIMINGS[category_for(species)]
	var day := float(GameCalendar.day_of_year(GameCalendar.normalize_date(date)))
	var fall_end := float(timing["fall_end"])
	if day < float(timing["colour"]):
		return 0.0
	if day < fall_end:
		return clampf(1.0 - float(state_for(species, date)["leaf_density"]), 0.0, 1.0)
	return 1.0 - _smooth(clampf((day - fall_end) / LITTER_BROWNING_DAYS, 0.0, 1.0))


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
	# Tuned on gameplay-scale captures: a summer hit drops ~12 leaves, so the
	# burst still reads at the shipped camera crop; autumn stays the loosest.
	var base := 34.0 * clampf(strength, 0.2, 2.0) * density * looseness
	return clampi(int(round(base)), 1, 64)


static func _fruit_visible(species: StringName, month: int) -> bool:
	if not FRUIT_MONTHS.has(species):
		return false
	var window: Array = FRUIT_MONTHS[species]
	return month >= int(window[0]) and month <= int(window[1])


## Snow lying on the ground, 0..1 (R-1327). Tallinn-area timings: first settled
## snow mid-December, deepest February, gone by early April. Pure date curve, no
## weather input, so a mild spell never un-snows a saved game differently.
static func snow_cover_for(date: Dictionary) -> float:
	var day := float(GameCalendar.day_of_year(GameCalendar.normalize_date(date)))
	if day > 200.0:
		return _smooth((day - 335.0) / 30.0)
	return 1.0 - _smooth((day - 60.0) / 35.0)


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


## 0 before rise_start, smooth up to 1 at rise_end, 1 until fall_start, smooth
## down to 0 at fall_end (a growing season with a plateau).
static func _plateau(
	day: float, rise_start: float, rise_end: float, fall_start: float, fall_end: float
) -> float:
	if day < rise_end:
		return _smooth((day - rise_start) / (rise_end - rise_start))
	return 1.0 - _smooth((day - fall_start) / (fall_end - fall_start))


static func _smooth(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
