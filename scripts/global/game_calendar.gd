class_name GameCalendar
extends RefCounted

## The vertical slice leads into St. George's Night in late April 1343.
## Dates belong to authored story phases rather than the accelerated lighting
## loop, so a one-minute visual day never advances campaign time by accident.

const DEFAULT_DATE := {"day": 21, "month": 4, "year": 1343}
const PHASE_DATES := {
	GameState.PHASE_PROLOGUE_DAY: {"day": 21, "month": 4, "year": 1343},
	GameState.PHASE_INVESTIGATION_MORNING: {"day": 22, "month": 4, "year": 1343},
	GameState.PHASE_INVESTIGATION_NIGHT: {"day": 22, "month": 4, "year": 1343},
	GameState.PHASE_CONSEQUENCE_NIGHT: {"day": 22, "month": 4, "year": 1343},
	GameState.PHASE_REFLECTION_MORNING: {"day": 23, "month": 4, "year": 1343},
}
const MONTH_LENGTHS: Array[int] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]


## Reval still used the Julian calendar in 1343, where every fourth year is a
## leap year. Keeping this here lets all date-driven world systems share one rule.
static func is_leap_year(year: int) -> bool:
	return posmod(year, 4) == 0


static func days_in_year(year: int) -> int:
	return 366 if is_leap_year(year) else 365


static func days_in_month(month: int, year: int) -> int:
	var valid_month := clampi(month, 1, 12)
	if valid_month == 2 and is_leap_year(year):
		return 29
	return MONTH_LENGTHS[valid_month - 1]


static func day_of_year(date: Dictionary) -> int:
	var year := int(date.get("year", DEFAULT_DATE["year"]))
	var month := clampi(int(date.get("month", DEFAULT_DATE["month"])), 1, 12)
	var day := clampi(
		int(date.get("day", DEFAULT_DATE["day"])),
		1,
		days_in_month(month, year)
	)
	var ordinal := day
	for preceding_month in range(1, month):
		ordinal += days_in_month(preceding_month, year)
	return ordinal


static func date_for_phase(phase_id: StringName) -> Dictionary:
	var date: Dictionary = PHASE_DATES.get(phase_id, DEFAULT_DATE)
	return date.duplicate()


static func format_date(date: Dictionary) -> String:
	return "%02d.%02d.%04d" % [
		int(date.get("day", DEFAULT_DATE["day"])),
		int(date.get("month", DEFAULT_DATE["month"])),
		int(date.get("year", DEFAULT_DATE["year"])),
	]


## Story date plus the accelerated local solar clock. Campaign day still comes
## from phases; HH:MM follows DayNightCycle progress so the minimap stays in
## sync with the moving sun without advancing story time.
static func format_date_and_local_time(date: Dictionary, cycle_progress: float) -> String:
	return "%s %s" % [format_date(date), DayNightCycle.format_clock(cycle_progress)]


static func formatted_date_for_phase(phase_id: StringName) -> String:
	return format_date(date_for_phase(phase_id))
