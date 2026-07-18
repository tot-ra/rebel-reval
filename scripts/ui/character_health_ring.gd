class_name CharacterHealthRing
extends Node2D

## Floor-level circular health indicator for 2D logic actors. The arc depletes
## clockwise from the top and shifts green -> yellow -> red by percentage.

const COLOR_HEALTHY := Color(0.278431, 0.74902, 0.27451, 1.0)
const COLOR_WARN := Color(0.95, 0.78, 0.2, 1.0)
const COLOR_CRITICAL := Color(0.85, 0.22, 0.22, 1.0)
const COLOR_BACKGROUND := Color(0.05, 0.05, 0.05, 0.82)

const RING_RADIUS := 14.0
const RING_WIDTH := 3.5
const ARC_SEGMENTS := 64
const ARC_START := -PI * 0.5

var current_health := 100.0
var max_health := 100.0


func set_health(current: float, maximum: float) -> void:
	current_health = maxf(current, 0.0)
	max_health = maxf(maximum, 0.0)
	queue_redraw()


func get_health_ratio() -> float:
	if max_health <= 0.0:
		return 0.0
	return clampf(current_health / max_health, 0.0, 1.0)


static func color_for_ratio(ratio: float) -> Color:
	if ratio > 0.5:
		return COLOR_HEALTHY
	if ratio > 0.25:
		return COLOR_WARN
	return COLOR_CRITICAL


func _draw() -> void:
	var ratio := get_health_ratio()
	draw_arc(Vector2.ZERO, RING_RADIUS, 0.0, TAU, ARC_SEGMENTS, COLOR_BACKGROUND, RING_WIDTH, true)
	if ratio <= 0.0:
		return
	var end_angle := ARC_START + TAU * ratio
	var segment_count := maxi(3, int(float(ARC_SEGMENTS) * ratio))
	draw_arc(
		Vector2.ZERO,
		RING_RADIUS,
		ARC_START,
		end_angle,
		segment_count,
		color_for_ratio(ratio),
		RING_WIDTH,
		true
	)
