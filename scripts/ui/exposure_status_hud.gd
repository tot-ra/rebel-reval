extends CanvasLayer

## ADR 0061 (R-2184): what the cold and the wet do to the hero, on screen. Status icons sit just
## above the vitals bars (PlayerVitalsHud, bottom left): a droplet while damp or soaked, a
## snowflake while chilled, freezing or freezing to death. Each worsening stage prints one short
## line once; while freezing, frost creeps in from the screen edges. Icons are drawn in code (asset
## freeze P0-040): no image files. Presentation only: HeroExposureHazard owns the numbers.

const HeroExposure := preload("res://scripts/player/hero_exposure.gd")

## Matches PlayerVitalsHud: its block is HEIGHT 108 at MARGIN 24 from the bottom-left corner.
const VITALS_TOP := 108.0 + 24.0
const MARGIN := 24.0
const ICON := 44.0
const GAP := 8.0
## A line stays this long, then fades.
const MESSAGE_SEC := 4.5
const MESSAGE_FADE_SEC := 0.8
## Frost vignette strength while freezing (body heat below FREEZING_BELOW) and at zero heat.
const VIGNETTE_FREEZING := 0.35
const VIGNETTE_DYING := 0.6

const WET_LABELS := {&"damp": "Damp", &"soaked": "Soaked"}
const COLD_LABELS := {&"chilled": "Chilled", &"freezing": "Freezing", &"dying": "Freezing!"}
## One line per worsening stage, worst last within each meter.
const MESSAGES := {
	&"damp": "Your clothes are getting wet.",
	&"soaked": "Soaked to the skin. Dry off by a fire.",
	&"chilled": "You are getting cold.",
	&"freezing": "Freezing. Find a fire or go indoors.",
	&"dying": "You are freezing to death!",
}
const WARMING_MESSAGE := "The fire's warmth seeps in."
const WET_ORDER: Array[StringName] = [&"", &"damp", &"soaked"]
const COLD_ORDER: Array[StringName] = [&"", &"chilled", &"freezing", &"dying"]


class StatusIcon:
	extends Control

	var kind := &"wet"  # &"wet" droplet or &"cold" snowflake
	var severity := 0  # 1 mild .. 3 worst
	var pulse := 0.0

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		var rim := Color(0.86, 0.36, 0.3) if severity >= 3 else Color("eee0c5")
		rim.a = 0.75 + 0.25 * pulse
		draw_circle(c, r, Color(0.07, 0.06, 0.05, 0.78))
		draw_arc(c, r - 1.5, 0.0, TAU, 32, rim, 2.0, true)
		if kind == &"wet":
			_droplet(c, r * 0.58)
		else:
			_snowflake(c, r * 0.6)

	func _droplet(c: Vector2, r: float) -> void:
		var fill := Color(0.42, 0.66, 0.92) if severity >= 2 else Color(0.62, 0.8, 0.95)
		var pts := PackedVector2Array()
		pts.append(c + Vector2(0, -r * 1.25))
		for i in range(0, 13):
			var a := PI * float(i) / 12.0
			pts.append(c + Vector2(cos(a) * r * 0.78, r * 0.25 + sin(a) * r * 0.78))
		draw_colored_polygon(pts, fill)
		if severity >= 2:
			# Soaked: water drips off.
			draw_circle(c + Vector2(r * 0.95, r * 1.05), r * 0.16, fill)

	func _snowflake(c: Vector2, r: float) -> void:
		var col := Color(0.8, 0.9, 1.0)
		if severity >= 2:
			col = Color(0.62, 0.82, 1.0)
		for i in range(6):
			var d := Vector2.from_angle(TAU * float(i) / 6.0 - PI * 0.5)
			draw_line(c, c + d * r, col, 2.2, true)
			var tip := c + d * r * 0.62
			draw_line(tip, tip + d.rotated(0.75) * r * 0.3, col, 1.6, true)
			draw_line(tip, tip + d.rotated(-0.75) * r * 0.3, col, 1.6, true)


## Tests and captures set this; in game it follows Settings > Reduced motion.
var reduced_motion := false
var follow_settings := true
var wet_stage := &""
var cold_stage := &""
var message := ""

var _root: Control
var _wet_icon: StatusIcon
var _cold_icon: StatusIcon
var _wet_label: Label
var _cold_label: Label
var _message_label: Label
var _vignette: TextureRect
var _message_left := 0.0
var _time := 0.0
var _near_fire := false


func _ready() -> void:
	layer = 21
	_vignette = TextureRect.new()
	_vignette.name = "FrostVignette"
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.texture = _frost_texture()
	_vignette.modulate.a = 0.0
	add_child(_vignette)
	_root = Control.new()
	_root.name = "ExposureRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_root.offset_left = MARGIN
	_root.offset_top = -VITALS_TOP - GAP - ICON - 18.0
	_root.offset_right = MARGIN + 420.0
	_root.offset_bottom = -VITALS_TOP - GAP
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_wet_icon = _icon("WetIcon", &"wet")
	_cold_icon = _icon("ColdIcon", &"cold")
	_wet_label = _small_label("WetLabel")
	_cold_label = _small_label("ColdLabel")
	_message_label = Label.new()
	_message_label.name = "ExposureMessage"
	_message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_message_label.offset_top = -VITALS_TOP - 120.0
	_message_label.offset_bottom = -VITALS_TOP - 80.0
	_message_label.offset_left = -360.0
	_message_label.offset_right = 360.0
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 20)
	_message_label.add_theme_color_override("font_color", Color("eee0c5"))
	_message_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_message_label.add_theme_constant_override("outline_size", 6)
	_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_label.modulate.a = 0.0
	add_child(_message_label)
	_layout()


func _process(delta: float) -> void:
	_time += delta
	if follow_settings:
		var settings := get_node_or_null("/root/UserSettings")
		if settings != null:
			reduced_motion = settings.dialogue.reduced_motion
	if _message_left > 0.0:
		_message_left -= delta
		var a := clampf(_message_left / MESSAGE_FADE_SEC, 0.0, 1.0)
		_message_label.modulate.a = 1.0 if reduced_motion and _message_left > 0.0 else a
	var pulse := 0.0 if reduced_motion else 0.5 + 0.5 * sin(_time * 4.0)
	for icon: StatusIcon in [_wet_icon, _cold_icon]:
		if icon.visible and icon.severity >= 3:
			icon.pulse = pulse
			icon.queue_redraw()


## Called every frame by HeroExposureHazard with the saved meters and the nearest fire (metres).
func show_exposure(wetness: float, body_heat: float, fire_m: float = INF) -> void:
	var wet := HeroExposure.wet_stage(wetness)
	var cold := HeroExposure.cold_stage(body_heat)
	if WET_ORDER.find(wet) > WET_ORDER.find(wet_stage):
		_say(MESSAGES[wet])
	if COLD_ORDER.find(cold) > COLD_ORDER.find(cold_stage):
		_say(MESSAGES[cold])
	# Once, when a cold hero reaches a fire.
	var near_fire := HeroExposure.fire_factor(fire_m) > 0.0
	if near_fire and not _near_fire and cold != &"":
		_say(WARMING_MESSAGE)
	_near_fire = near_fire
	wet_stage = wet
	cold_stage = cold
	_wet_icon.visible = wet != &""
	_wet_icon.severity = WET_ORDER.find(wet)
	_wet_label.visible = _wet_icon.visible
	_wet_label.text = String(WET_LABELS.get(wet, ""))
	_cold_icon.visible = cold != &""
	_cold_icon.severity = COLD_ORDER.find(cold)
	_cold_label.visible = _cold_icon.visible
	_cold_label.text = String(COLD_LABELS.get(cold, ""))
	_wet_icon.queue_redraw()
	_cold_icon.queue_redraw()
	_vignette.modulate.a = vignette_alpha(body_heat)
	_layout()


## Frost at the screen edges: none above FREEZING_BELOW, rising to VIGNETTE_DYING at zero heat.
static func vignette_alpha(body_heat: float) -> float:
	if body_heat >= HeroExposure.FREEZING_BELOW:
		return 0.0
	if body_heat <= 0.0:
		return VIGNETTE_DYING
	var t := 1.0 - body_heat / HeroExposure.FREEZING_BELOW
	return lerpf(0.08, VIGNETTE_FREEZING, t)


func _say(text: String) -> void:
	message = text
	_message_label.text = text
	_message_label.modulate.a = 1.0
	_message_left = MESSAGE_SEC


## Visible icons sit in a row, each with its word under it.
func _layout() -> void:
	var x := 0.0
	for pair: Array in [[_wet_icon, _wet_label], [_cold_icon, _cold_label]]:
		var icon: StatusIcon = pair[0]
		var label: Label = pair[1]
		if not icon.visible:
			continue
		icon.position = Vector2(x, 0.0)
		label.position = Vector2(x - 18.0, ICON)
		x += ICON + 40.0


func _icon(node_name: String, kind: StringName) -> StatusIcon:
	var icon := StatusIcon.new()
	icon.name = node_name
	icon.kind = kind
	icon.size = Vector2(ICON, ICON)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.visible = false
	_root.add_child(icon)
	return icon


func _small_label(node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.size = Vector2(ICON + 36.0, 18.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("eee0c5"))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.visible = false
	_root.add_child(label)
	return label


## Radial gradient: clear centre, icy pale blue at the edges and corners.
static func _frost_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, Color(0.85, 0.93, 1.0, 0.0))
	gradient.set_offset(1, 1.0)
	gradient.set_color(1, Color(0.88, 0.95, 1.0, 1.0))
	gradient.add_point(0.55, Color(0.85, 0.93, 1.0, 0.0))
	gradient.add_point(0.82, Color(0.8, 0.9, 1.0, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 1.0)
	tex.width = 256
	tex.height = 256
	return tex
