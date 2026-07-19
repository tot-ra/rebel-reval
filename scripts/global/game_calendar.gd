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


static func date_for_phase(phase_id: StringName) -> Dictionary:
	var date: Dictionary = PHASE_DATES.get(phase_id, DEFAULT_DATE)
	return date.duplicate()


static func format_date(date: Dictionary) -> String:
	return "%02d.%02d.%04d" % [
		int(date.get("day", DEFAULT_DATE["day"])),
		int(date.get("month", DEFAULT_DATE["month"])),
		int(date.get("year", DEFAULT_DATE["year"])),
	]


static func formatted_date_for_phase(phase_id: StringName) -> String:
	return format_date(date_for_phase(phase_id))
