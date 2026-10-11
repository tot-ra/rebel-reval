class_name SpiritTelegraphArc
extends Control
## Incoming-blow telegraph for the spirit arena (SD-18): a half-circle the blow sweeps along
## from wind-up (left) to impact (right). The last stretch is the parry window, marked gold, so
## the player can see when raising guard parries instead of only blocking.

const ARC_SIZE := Vector2(260.0, 120.0)
const TRACK := Color(1, 1, 1, 0.14)
const SWEEP := Color(0.90, 0.75, 0.35)
const PARRY := Color(1.0, 0.86, 0.30)
const IMPACT := Color(0.92, 0.30, 0.26)

## 0 wind-up .. 1 impact (SpiritDuel.telegraph_progress).
var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()
## Share of the telegraph that is the parry window (parry_window_sec / telegraph_sec).
var parry_fraction := 0.15:
	set(value):
		parry_fraction = clampf(value, 0.0, 1.0)
		queue_redraw()


func _init() -> void:
	custom_minimum_size = ARC_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center := Vector2(size.x * 0.5, size.y - 8.0)
	var radius := minf(size.x * 0.5, size.y) - 12.0
	# Angles run from PI (left, wind-up) to TAU (right, impact) across the top.
	draw_arc(center, radius, PI, TAU, 48, TRACK, 8.0, true)
	var parry_start := PI + PI * (1.0 - parry_fraction)
	draw_arc(center, radius, parry_start, TAU, 16, PARRY.darkened(0.45), 8.0, true)
	if progress > 0.0:
		var head := PI + PI * progress
		var color := PARRY if head >= parry_start else SWEEP
		draw_arc(center, radius, PI, head, 48, color, 8.0, true)
		draw_circle(center + Vector2.from_angle(head) * radius, 9.0, color.lightened(0.2))
	draw_circle(center + Vector2.from_angle(TAU) * radius, 6.0, IMPACT)
