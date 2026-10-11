class_name MarketDayModel
extends RefCounted

## Calendar-driven market-day schedule for Lower Town trade stalls.
## The weekday is unresolved in the Reval 1340-1343 evidence; this schedule is
## an explicit gameplay fallback and must not be presented as canon.

const FLAG_MARKET_DAY := &"flag.market_day_active"
const MARKET_WEEKDAY_SOURCE_STATUS := &"implementation_fallback"

## ISO weekday indices (Monday=0). Wednesday and Saturday are the current
## implementation fallback, not an attested Reval market schedule.
const MARKET_WEEKDAYS: Array[int] = [2, 5]

const EXPANDED_STALL_PROP_IDS: Array[StringName] = [
	&"market_stall_turg_north",
	&"market_stall_turg_south",
]

const MERCHANT_INTERACTABLE_ID := &"interact.market_day.merchant_stall"
const MERCHANT_DIALOGUE_ID := &"dialogue.merchant.market_day"
const MERCHANT_PROP_ID := &"market_stall_gate"


static func is_market_day(date: Dictionary) -> bool:
	return MARKET_WEEKDAYS.has(GameCalendar.weekday_index(date))


static func resolve_date(phase_id: StringName, elapsed_days: int) -> Dictionary:
	return GameCalendar.add_days(GameCalendar.date_for_phase(phase_id), maxi(elapsed_days, 0))


static func sync_flag(state: GameState, phase_id: StringName, elapsed_days: int) -> bool:
	if state == null:
		return false
	var active := is_market_day(resolve_date(phase_id, elapsed_days))
	state.set_flag(FLAG_MARKET_DAY, active)
	return active
