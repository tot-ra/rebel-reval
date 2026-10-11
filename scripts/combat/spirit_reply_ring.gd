class_name SpiritReplyRing
extends Control
## Countdown ring on the spirit arena reply window (SD-18). Draws the time left as an arc that
## shrinks and warms from calm blue to red. Pressure only: SpiritDuel decides what running out
## means (one hesitation chip), the ring just shows it.

const RING_SIZE := Vector2(64.0, 64.0)
const CALM := Color(0.45, 0.70, 0.90)
const URGENT := Color(0.92, 0.32, 0.26)

## 0 fresh .. 1 run out (SpiritDuel.reply_window_progress).
var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()


func _init() -> void:
	custom_minimum_size = RING_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 5.0
	draw_arc(center, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.12), 6.0, true)
	var left := 1.0 - progress
	if left > 0.0:
		var start := -PI * 0.5
		var color := CALM.lerp(URGENT, progress)
		draw_arc(center, radius, start, start + TAU * left, 48, color, 6.0, true)
