class_name CharacterHealthRing
extends Node2D

## Overhead horizontal health bar for 2D logic actors. Depletes left-to-right.
## Stays green until critical; no yellow mid-band (that read as skeleton tint).

const COLOR_HEALTHY := Color(0.278431, 0.74902, 0.27451, 1.0)
const COLOR_CRITICAL := Color(0.85, 0.22, 0.22, 1.0)
const COLOR_BACKGROUND := Color(0.05, 0.05, 0.05, 0.82)

const BAR_WIDTH := 42.0
const BAR_HEIGHT := 5.0

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
	if ratio > 0.25:
		return COLOR_HEALTHY
	return COLOR_CRITICAL


func _draw() -> void:
	var ratio := get_health_ratio()
	var background := Rect2(-BAR_WIDTH * 0.5, -BAR_HEIGHT * 0.5, BAR_WIDTH, BAR_HEIGHT)
	draw_rect(background, COLOR_BACKGROUND, true)
	if ratio <= 0.0:
		return
	var fill := Rect2(-BAR_WIDTH * 0.5, -BAR_HEIGHT * 0.5, BAR_WIDTH * ratio, BAR_HEIGHT)
	draw_rect(fill, color_for_ratio(ratio), true)
