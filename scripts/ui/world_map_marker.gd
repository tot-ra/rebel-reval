extends Button

## Round ink-and-gold map marker for the Estonia map. It carries no text: the
## owning view shows the place name while the marker is hovered or focused.

enum Kind { TRAVELABLE, CURRENT, HUB, PLANNED }

const INK := Color(0.20, 0.13, 0.07, 1.0)
const PARCHMENT := Color(0.93, 0.84, 0.62, 1.0)
const GOLD := Color(1.0, 0.78, 0.28, 1.0)

var kind: Kind = Kind.TRAVELABLE

var _pulse := 0.0


func _ready() -> void:
	for style_name in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	set_process(kind == Kind.CURRENT)


func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta * 0.9, 1.0)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var lit := is_hovered() or has_focus()
	match kind:
		Kind.PLANNED:
			# Uncharted place: hollow faded ring, never reads as clickable.
			draw_arc(center, 7.0, 0.0, TAU, 24, Color(INK, 0.55), 2.0, true)
			draw_circle(center, 2.5, Color(INK, 0.35))
			if lit:
				draw_arc(center, 11.0, 0.0, TAU, 28, Color(INK, 0.45), 1.5, true)
		Kind.CURRENT:
			draw_circle(center, 9.0, GOLD)
			draw_arc(center, 9.0, 0.0, TAU, 28, INK, 2.5, true)
			var ring := 11.0 + 12.0 * _pulse
			draw_arc(center, ring, 0.0, TAU, 32, Color(GOLD, 1.0 - _pulse), 2.0, true)
		Kind.HUB:
			draw_circle(center, 11.0, PARCHMENT)
			draw_arc(center, 11.0, 0.0, TAU, 32, INK, 3.0, true)
			draw_circle(center, 5.0, INK)
			if lit:
				draw_arc(center, 16.0, 0.0, TAU, 32, GOLD, 3.0, true)
		_:
			draw_circle(center, 8.0, PARCHMENT)
			draw_arc(center, 8.0, 0.0, TAU, 28, INK, 2.5, true)
			draw_circle(center, 3.0, INK)
			if lit:
				draw_circle(center, 8.0, Color(GOLD, 0.55))
				draw_arc(center, 14.0, 0.0, TAU, 32, GOLD, 3.0, true)
