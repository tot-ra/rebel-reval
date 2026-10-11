class_name CitizenSchedule
extends RefCounted

## Renderer-agnostic daily routine for Lower Town civilians (LIFE-1, R-1344).
## WHY: the population profile fixes WHO is out per phase; this model decides WHERE
## each civilian is at a given in-game hour, so occupancy and zones change over 24h.
## Pure and deterministic: (occupation, hour, weekday, seed, actor_index) -> activity.

const ACT_SLEEP := &"sleep"  # indoors, not rendered
const ACT_HOME := &"home"
const ACT_WORK := &"work"
const ACT_MARKET := &"market"
const ACT_TAVERN := &"tavern"
const ACT_CHURCH := &"church"

const ACTIVITIES: Array[StringName] = [
	ACT_SLEEP, ACT_HOME, ACT_WORK, ACT_MARKET, ACT_TAVERN, ACT_CHURCH
]

const SUNDAY_WEEKDAY := 6  # GameCalendar.weekday_index: Monday=0
const MARKET_WEEKDAYS: Array[int] = [2, 5]
const MAX_JITTER_HOURS := 1

# Each row: [from_hour, to_hour) -> activity. Hours are whole in-game hours (0..23).
# Tavern/church have no authored anchors in the slice yet, so zone_for maps them
# onto the nearest existing zones; see docs/SYSTEMS/LIVING_WORLD.md "Limits".
const WORKDAY: Dictionary = {
	&"merchant":
	[[0, 5, ACT_SLEEP], [5, 7, ACT_HOME], [7, 18, ACT_MARKET], [18, 21, ACT_TAVERN],
	[21, 22, ACT_HOME], [22, 24, ACT_SLEEP]],
	&"artisan":
	[[0, 5, ACT_SLEEP], [5, 7, ACT_HOME], [7, 17, ACT_WORK], [17, 18, ACT_MARKET],
	[18, 21, ACT_TAVERN], [21, 22, ACT_HOME], [22, 24, ACT_SLEEP]],
	&"laborer":
	[[0, 4, ACT_SLEEP], [4, 6, ACT_HOME], [6, 18, ACT_WORK], [18, 20, ACT_TAVERN],
	[20, 21, ACT_HOME], [21, 24, ACT_SLEEP]],
	&"resident":
	[[0, 6, ACT_SLEEP], [6, 8, ACT_HOME], [8, 11, ACT_MARKET], [11, 16, ACT_HOME],
	[16, 18, ACT_MARKET], [18, 20, ACT_HOME], [20, 24, ACT_SLEEP]],
}

const SUNDAY: Dictionary = {
	&"merchant": [[0, 7, ACT_SLEEP], [7, 8, ACT_HOME], [8, 11, ACT_CHURCH], [11, 17, ACT_HOME],
	[17, 21, ACT_TAVERN], [21, 24, ACT_SLEEP]],
	&"artisan": [[0, 7, ACT_SLEEP], [7, 8, ACT_HOME], [8, 11, ACT_CHURCH], [11, 17, ACT_HOME],
	[17, 21, ACT_TAVERN], [21, 24, ACT_SLEEP]],
	&"laborer": [[0, 7, ACT_SLEEP], [7, 8, ACT_HOME], [8, 11, ACT_CHURCH], [11, 17, ACT_HOME],
	[17, 20, ACT_TAVERN], [20, 24, ACT_SLEEP]],
	&"resident": [[0, 7, ACT_SLEEP], [7, 8, ACT_HOME], [8, 11, ACT_CHURCH], [11, 19, ACT_HOME],
	[19, 24, ACT_SLEEP]],
}

const ZONE_BY_ACTIVITY: Dictionary = {
	ACT_HOME: &"residential_yard",
	ACT_MARKET: &"market_lane",
	ACT_TAVERN: &"street_frontage",
	ACT_CHURCH: &"safe_interior",
}


## Whole in-game hour (0..23) from DayNightCycle progress (0.0 = midnight).
static func hour_from_progress(progress: float) -> int:
	return clampi(int(floor(wrapf(progress, 0.0, 1.0) * 24.0)), 0, 23)


## Activity for one civilian. Sunday is church day; other days use the workday table.
static func activity_for(
	occupation: StringName, hour: int, weekday: int, seed: int, actor_index: int
) -> StringName:
	var table: Dictionary = SUNDAY if weekday == SUNDAY_WEEKDAY else WORKDAY
	var rows: Array = table.get(occupation, table[&"resident"])
	# Per-actor offset staggers departures so a street does not empty on one tick.
	var shifted := posmod(hour + _jitter(seed, actor_index), 24)
	for row: Array in rows:
		if shifted >= int(row[0]) and shifted < int(row[1]):
			return StringName(row[2])
	return ACT_SLEEP


## Zone for an activity. Off-market weekdays merchants trade from the street
## frontage instead of the market lane; other trades only visit the lane to shop.
static func zone_for(activity: StringName, occupation: StringName, weekday: int) -> StringName:
	if activity == ACT_WORK:
		return &"work_yard"
	if (
		activity == ACT_MARKET
		and occupation == &"merchant"
		and not weekday in MARKET_WEEKDAYS
	):
		return &"street_frontage"
	return StringName(ZONE_BY_ACTIVITY.get(activity, &""))


static func is_visible(activity: StringName) -> bool:
	return activity != ACT_SLEEP


## Returns the actor_plan with every civilian routed by hour; sleepers are dropped.
## actor_index and actor_id stay stable so renderer slots never shift between hours.
static func apply_to_plan(
	actor_plan: Array, hour: int, weekday: int, seed: int
) -> Array[Dictionary]:
	var routed: Array[Dictionary] = []
	for entry: Variant in actor_plan:
		if not entry is Dictionary:
			continue
		var record: Dictionary = (entry as Dictionary).duplicate()
		if StringName(record.get("role", &"")) == &"civilian":
			var occupation := StringName(record.get("occupation", &"resident"))
			var activity := activity_for(
				occupation, hour, weekday, seed, int(record.get("actor_index", 0))
			)
			if not is_visible(activity):
				continue
			record["activity"] = activity
			record["zone_id"] = zone_for(activity, occupation, weekday)
		routed.append(record)
	return routed


static func _jitter(seed: int, actor_index: int) -> int:
	var mixed := (seed * 73856093) ^ (actor_index * 19349663)
	return posmod(mixed, MAX_JITTER_HOURS * 2 + 1) - MAX_JITTER_HOURS
