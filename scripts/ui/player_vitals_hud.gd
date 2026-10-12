extends CanvasLayer

## Screen-space presentation only: Player remains the owner of both resources.
const WIDTH := 420.0
const HEIGHT := 108.0
const MARGIN := 24.0
const FRAME_TEXTURE := preload("res://assets/UI/vitals/vitals_bar_frame.png")
## 9-slice margins of FRAME_TEXTURE in texture pixels (left, top, right, bottom):
## studs plus bronze rim plus rope. The plate is painted at 2x and drawn at half.
const FRAME_MARGINS := Vector4(32, 16, 33, 17)
const FRAME_SCALE := 0.5
## Damage trail: the pale bar holds where health was, then drains to the new value.
const TRAIL_HOLD := 0.6
const TRAIL_DRAIN_PER_SECOND := 0.5
const TRAIL_COLOR := Color(0.93, 0.85, 0.68, 0.85)
## Idle fade: the block hides after this long at full health and stamina.
const FADE_DELAY := 4.0
const FADE_OUT_SECONDS := 0.8
const FADE_IN_SECONDS := 0.15
## R-1872: while a real-time spirit duel is open (its host sits in this group), the health frame
## shows the hero's composure instead: the duel's "health" reads exactly like normal play.
const DUEL_OPEN_GROUP := &"spirit_duel_open"
const HEALTH_TITLE := "HEALTH"
const COMPOSURE_TITLE := "COMPOSURE"

class ResourceBar:
	extends Control

	var ratio := 1.0
	var trail_ratio := 1.0
	var fill_color := Color("9d2926")
	var _frame := StyleBoxTexture.new()

	func _init() -> void:
		_frame.texture = FRAME_TEXTURE
		_frame.texture_margin_left = FRAME_MARGINS.x
		_frame.texture_margin_top = FRAME_MARGINS.y
		_frame.texture_margin_right = FRAME_MARGINS.z
		_frame.texture_margin_bottom = FRAME_MARGINS.w
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	func _draw() -> void:
		# Bed and fills sit one pixel under the rope so no seam shows at the opening.
		var inset := FRAME_MARGINS * FRAME_SCALE - Vector4.ONE
		var inner := Rect2(Vector2(inset.x, inset.y),
			size - Vector2(inset.x + inset.z, inset.y + inset.w))
		draw_rect(inner, Color("221815"))
		if trail_ratio > ratio:
			draw_rect(Rect2(inner.position, Vector2(inner.size.x * trail_ratio, inner.size.y)),
				TRAIL_COLOR)
		if ratio > 0.0:
			var filled := Rect2(inner.position, Vector2(inner.size.x * ratio, inner.size.y))
			draw_rect(filled, fill_color)
			draw_line(filled.position + Vector2(0, 1), filled.position + Vector2(filled.size.x, 1),
				fill_color.lightened(0.3), 2.0)
			draw_rect(Rect2(filled.position + Vector2(0, filled.size.y * 0.55),
				Vector2(filled.size.x, filled.size.y * 0.45)), Color(0, 0, 0, 0.22))
		# StyleBoxTexture margins are in texture pixels, so draw the frame in a
		# scaled space to keep the 2x plate crisp at its intended display size.
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * FRAME_SCALE)
		draw_style_box(_frame, Rect2(Vector2.ZERO, size / FRAME_SCALE))
		draw_set_transform(Vector2.ZERO)

## Tests and captures set this; in game it follows Settings > Reduced motion.
var reduced_motion := false
var follow_settings := true
var _source: Node
var _root: Control
var _health: ResourceBar
var _stamina: ResourceBar
var _health_label: Label
var _stamina_label: Label
var _last_values := Vector4(-1, -1, -1, -1)
var _trail_hold := 0.0
var _full_for := 0.0
var _health_title := HEALTH_TITLE


func _ready() -> void:
	layer = 21
	_source = get_parent()
	_root = Control.new()
	_root.name = "VitalsRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_root.offset_left = MARGIN
	_root.offset_top = -HEIGHT - MARGIN
	_root.offset_right = WIDTH + MARGIN
	_root.offset_bottom = -MARGIN
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_health_label = _label(_root, "HealthValue", 0)
	_health = _bar(_root, "Health", 20, 38, Color("9d2926"))
	_stamina_label = _label(_root, "StaminaValue", 60)
	_stamina = _bar(_root, "Stamina", 80, 28, Color("b39843"))
	set_vitals(0, 0, 0, 0)
	_health.trail_ratio = _health.ratio
	_process(0.0)


func _process(delta: float) -> void:
	if follow_settings:
		var settings := get_node_or_null("/root/UserSettings")
		if settings != null:
			reduced_motion = settings.dialogue.reduced_motion
	if is_instance_valid(_source) and ("health" in _source and "stamina" in _source):
		# Poll the live owner so regeneration, restore and direct vitals sync all agree.
		var composure := _duel_composure()
		var title := COMPOSURE_TITLE if composure != Vector2.ZERO else HEALTH_TITLE
		if title != _health_title:
			_health_title = title
			_last_values = Vector4(-1, -1, -1, -1)
		if composure != Vector2.ZERO:
			set_vitals(composure.x, composure.y, float(_source.stamina), float(_source.max_stamina))
		else:
			set_vitals(float(_source.health), float(_source.max_health),
				float(_source.stamina), float(_source.max_stamina))
	_advance(delta)


func set_vitals(health: float, max_health: float, stamina: float, max_stamina: float) -> void:
	var values := Vector4(health, max_health, stamina, max_stamina)
	if values == _last_values or _health == null:
		return
	var previous_ratio := _health.ratio
	_last_values = values
	_update_bar(_health, _health_label, _health_title, health, max_health)
	_update_bar(_stamina, _stamina_label, "STAMINA", stamina, max_stamina)
	if _health.ratio < previous_ratio:
		# Keep the trail at its highest unspent value so rapid hits stack into one drain.
		_health.trail_ratio = maxf(_health.trail_ratio, previous_ratio)
		_trail_hold = TRAIL_HOLD
	else:
		_health.trail_ratio = _health.ratio
	_stamina.trail_ratio = _stamina.ratio


## (current, maximum) composure of an open real-time duel, Vector2.ZERO when none is open.
func _duel_composure() -> Vector2:
	if not is_inside_tree():
		return Vector2.ZERO
	for host in get_tree().get_nodes_in_group(DUEL_OPEN_GROUP):
		if host.has_method(&"hero_composure"):
			var composure: Vector2 = host.call(&"hero_composure")
			if composure != Vector2.ZERO:
				return composure
	return Vector2.ZERO


func health_title() -> String:
	return _health_title


func _advance(delta: float) -> void:
	if _health.trail_ratio > _health.ratio:
		_trail_hold -= delta
		if _trail_hold <= 0.0:
			# Reduced motion skips the animated drain; the pale chunk just clears.
			var step := INF if reduced_motion else TRAIL_DRAIN_PER_SECOND * delta
			_health.trail_ratio = maxf(_health.ratio, _health.trail_ratio - step)
			_health.queue_redraw()
	# A duel keeps the block up even at full composure: it is the fight's health bar.
	var at_rest := (
		_health.ratio >= 1.0 and _stamina.ratio >= 1.0 and _health_title == HEALTH_TITLE
	)
	_full_for = _full_for + delta if at_rest else 0.0
	var target := 0.0 if _full_for >= FADE_DELAY else 1.0
	var alpha := _root.modulate.a
	if reduced_motion:
		alpha = target
	elif target < alpha:
		alpha = maxf(target, alpha - delta / FADE_OUT_SECONDS)
	else:
		alpha = minf(target, alpha + delta / FADE_IN_SECONDS)
	_root.modulate.a = alpha


func _update_bar(bar: ResourceBar, label: Label, title: String,
		current: float, maximum: float) -> void:
	bar.ratio = clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0
	label.text = "%s   %d / %d" % [title, clampf(current, 0, maxf(maximum, 0)), maxf(maximum, 0)]
	bar.queue_redraw()


func _bar(parent: Control, title: String, y: float, height: float, color: Color) -> ResourceBar:
	var bar := ResourceBar.new()
	bar.name = title
	bar.position = Vector2(0, y)
	bar.size = Vector2(WIDTH, height)
	bar.fill_color = color
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	return bar


func _label(parent: Control, title: String, y: float) -> Label:
	var label := Label.new()
	label.name = title
	label.position = Vector2(18, y)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("eee0c5"))
	label.add_theme_color_override("font_outline_color", Color("161412"))
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
