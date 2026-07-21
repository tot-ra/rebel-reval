class_name GameCalendar
extends RefCounted

## The vertical slice leads into St. George's Night in late April 1343.
## Story phases provide the base campaign date. While an outdoor cycle remains
## active, each completed solar cycle advances that date so every date-driven
## world system observes the same day as the moving sun and local clock.

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


## Adds signed whole days using the campaign's Julian leap-year rules. Keeping
## date arithmetic centralized prevents HUD, solar seasons, and lunar phases
## from disagreeing at month or year boundaries.
static func add_days(date: Dictionary, day_offset: int) -> Dictionary:
	var year := int(date.get("year", DEFAULT_DATE["year"]))
	var month := clampi(int(date.get("month", DEFAULT_DATE["month"])), 1, 12)
	var day := clampi(
		int(date.get("day", DEFAULT_DATE["day"])),
		1,
		days_in_month(month, year)
	)

	if day_offset > 0:
		for _step in day_offset:
			day += 1
			if day <= days_in_month(month, year):
				continue
			day = 1
			month += 1
			if month > 12:
				month = 1
				year += 1
	elif day_offset < 0:
		for _step in -day_offset:
			day -= 1
			if day >= 1:
				continue
			month -= 1
			if month < 1:
				month = 12
				year -= 1
			day = days_in_month(month, year)

	return {"day": day, "month": month, "year": year}


static func date_for_phase_and_elapsed_days(phase_id: StringName, elapsed_days: int) -> Dictionary:
	return add_days(date_for_phase(phase_id), maxi(elapsed_days, 0))


static func format_date(date: Dictionary) -> String:
	return "%02d.%02d.%04d" % [
		int(date.get("day", DEFAULT_DATE["day"])),
		int(date.get("month", DEFAULT_DATE["month"])),
		int(date.get("year", DEFAULT_DATE["year"])),
	]


## Campaign date plus the accelerated local solar clock. Callers pass the date
## after completed solar-day offsets have been applied, keeping the badge aligned
## with the sky without coupling formatting to clock ownership.
static func format_date_and_local_time(date: Dictionary, cycle_progress: float) -> String:
	return "%s %s" % [format_date(date), DayNightCycle.format_clock(cycle_progress)]


static func formatted_date_for_phase(phase_id: StringName) -> String:
	return format_date(date_for_phase(phase_id))
