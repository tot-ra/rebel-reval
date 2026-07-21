class_name DayNightCycle
extends RefCounted

## Development pacing for the world clock. A full in-game day advances in
## CYCLE_DURATION_SECONDS of real time so lighting and shadow motion are easy
## to review while playtesting.

const CYCLE_DURATION_SECONDS := 60.0
const HOURS_PER_REAL_SECOND := 24.0 / CYCLE_DURATION_SECONDS

## Morning start so the first visible transition is toward noon, not midnight.
const DEFAULT_PROGRESS := 0.25


static func advance(progress: float, delta_seconds: float) -> float:
	return float(advance_clock(progress, delta_seconds)["progress"])


## Returns both the wrapped local time and every midnight crossed by this tick.
## Rendering needs the fraction, while calendar and lunar systems need the whole
## day count that wrapf alone would otherwise discard.
static func advance_clock(progress: float, delta_seconds: float) -> Dictionary:
	var unwrapped_progress := wrapf(progress, 0.0, 1.0) + maxf(delta_seconds, 0.0) / CYCLE_DURATION_SECONDS
	return {
		"progress": wrapf(unwrapped_progress, 0.0, 1.0),
		"completed_days": int(floor(unwrapped_progress)),
	}


static func day_blend(progress: float) -> float:
	var wrapped := wrapf(progress, 0.0, 1.0)
	return clampf((sin(wrapped * TAU - PI * 0.5) + 1.0) * 0.5, 0.0, 1.0)


static func progress_to_hour(progress: float) -> float:
	return wrapf(progress, 0.0, 1.0) * 24.0


## Local solar clock for the shared day/night loop. Progress 0.0 is midnight,
## 0.5 is noon; minutes are floored so the HUD does not jitter every frame.
static func format_clock(progress: float) -> String:
	var total_minutes := int(floor(progress_to_hour(progress) * 60.0)) % (24 * 60)
	var hour := total_minutes / 60
	var minute := total_minutes % 60
	return "%02d:%02d" % [hour, minute]


## Soft on/off ramp for evening window glow. fade_hours is in-game hours.
static func evening_glow_strength(
	hour: float,
	start_hour: float,
	end_hour: float,
	fade_hours: float = 0.5
) -> float:
	if hour < start_hour - fade_hours or hour > end_hour + fade_hours:
		return 0.0
	if hour < start_hour:
		return smoothstep(start_hour - fade_hours, start_hour, hour)
	if hour > end_hour:
		return 1.0 - smoothstep(end_hour, end_hour + fade_hours, hour)
	return 1.0
