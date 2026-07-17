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
	return wrapf(progress + delta_seconds / CYCLE_DURATION_SECONDS, 0.0, 1.0)


static func day_blend(progress: float) -> float:
	var wrapped := wrapf(progress, 0.0, 1.0)
	return clampf((sin(wrapped * TAU - PI * 0.5) + 1.0) * 0.5, 0.0, 1.0)
