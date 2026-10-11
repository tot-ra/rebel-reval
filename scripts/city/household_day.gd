class_name HouseholdDay
extends RefCounted

## The rhythm of a household's day indoors (docs/SYSTEMS/HOUSEHOLDS.md), as pure
## functions of the clock hour, like CitizenRoster: the fire is lit for the
## morning porridge, the midday meal and the evening, and banked to embers in
## between and overnight; the firewood pile by the hearth burns down through the
## day and is full again once someone has carried an armful home from the
## woodyard; the light is lit on dark evenings while anyone is awake; and each
## resident at home sleeps, eats, tends the fire, works or sits.

## Hours the fire burns (start, end), before the per-house shift.
const FIRE_WINDOWS := [[5.4, 8.6], [11.0, 13.0], [16.6, 21.4]]
const MEALS := [[6.7, 7.3], [11.9, 12.6], [17.9, 18.7]]
const BEDTIME := 21.2
const CHILD_BEDTIME := 19.6
const RISE := 5.2
## When the household's firewood comes home if no one fetches it (domestic
## timetable: out at 10.2, home by about 10.7).
const DEFAULT_REFILL := 10.7
## Indoor walking speed from the door to a resident's place (m/s).
const INDOOR_WALK := 1.0


static func house_shift(building_id: String) -> float:
	return float(absi(hash(building_id + ":fire")) % 61 - 30) / 100.0


## `lit`, `embers` (banked under the ash) for the hearth at `hour`.
static func hearth_state(building_id: String, hour: float) -> StringName:
	var h := hour - house_shift(building_id)
	for w: Array in FIRE_WINDOWS:
		if h >= float(w[0]) and h < float(w[1]):
			return &"lit"
	return &"embers"


## `full`, `half` or `low`: the pile by the hearth, refilled at `refill_hour`.
static func firewood_state(hour: float, refill_hour: float) -> StringName:
	var since := fposmod(hour - refill_hour, 24.0)
	if since < 7.0:
		return &"full"
	if since < 15.0:
		return &"half"
	return &"low"


## The table light burns on dark evenings and mornings while people are up.
static func light_lit(hour: float, dark: bool) -> bool:
	return dark and hour >= RISE - 0.3 and hour < BEDTIME + 0.3


static func is_meal(hour: float, jitter: float) -> bool:
	var h := hour - jitter * 0.3
	for m: Array in MEALS:
		if h >= float(m[0]) and h < float(m[1]):
			return true
	return false


static func asleep(resident: Dictionary, hour: float) -> bool:
	var jitter := float(resident["jitter"]) * 0.5
	var bed := (CHILD_BEDTIME if int(resident["age"]) < 12 else BEDTIME) + jitter
	return hour >= bed or hour < RISE + jitter


## What resident `r` (at home at `hour`) does, as a pose and a slot kind:
## {pose: sleep|sit|stand|hearth|work, slot: kind in HouseholdLayout}.
## `role` is the resident's place in the household: the cook tends the fire.
static func activity(r: Dictionary, hour: float, is_cook: bool, has_work: bool) -> Dictionary:
	if asleep(r, hour):
		return {"pose": &"sleep", "slot": &"sleep"}
	if is_meal(hour, float(r["jitter"])):
		return {"pose": &"sit", "slot": &"sit"}
	if is_cook:
		return {"pose": &"hearth", "slot": &"hearth"}
	if has_work and String(r["pattern"]) == "craft" and hour >= 7.0 and hour < 18.5:
		return {"pose": &"work", "slot": &"work"}
	# Elders and small children sit; the rest are up and about.
	if int(r["age"]) >= 60 or int(r["age"]) < 7:
		return {"pose": &"sit", "slot": &"sit"}
	return {"pose": &"stand", "slot": &"stand"}
