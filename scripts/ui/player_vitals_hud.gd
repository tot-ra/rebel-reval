extends CanvasLayer

## Screen-space presentation only: Player remains the owner of both resources.
const WIDTH := 420.0
const HEIGHT := 106.0
const MARGIN := 24.0

class ResourceBar:
	extends Control

	var ratio := 1.0
	var fill_color := Color("9d2926")

	func _draw() -> void:
		var outline := _shape(Rect2(Vector2.ZERO, size))
		draw_colored_polygon(outline, Color("191714"))
		outline.append(outline[0])
		draw_polyline(outline, Color("ad9060"), 2.0, true)
		var inner := Rect2(Vector2(7, 5), size - Vector2(14, 10))
		draw_style_box(_bed(), inner)
		if ratio > 0.0:
			var filled := Rect2(inner.position, Vector2(inner.size.x * ratio, inner.size.y))
			draw_rect(filled, fill_color)
			draw_line(filled.position, filled.position + Vector2(filled.size.x, 0),
				fill_color.lightened(0.3), 2.0)
			draw_rect(Rect2(filled.position + Vector2(0, filled.size.y * 0.55),
				Vector2(filled.size.x, filled.size.y * 0.45)), Color(0, 0, 0, 0.22))

	func _shape(rect: Rect2) -> PackedVector2Array:
		var x := rect.position.x
		var y := rect.position.y
		var w := rect.size.x
		var h := rect.size.y
		return PackedVector2Array([Vector2(x, y + h / 2), Vector2(x + 8, y),
			Vector2(x + w - 8, y), Vector2(x + w, y + h / 2),
			Vector2(x + w - 8, y + h), Vector2(x + 8, y + h)])

	func _bed() -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("30201c")
		return style

var _source: Node
var _health: ResourceBar
var _stamina: ResourceBar
var _health_label: Label
var _stamina_label: Label
var _last_values := Vector4(-1, -1, -1, -1)


func _ready() -> void:
	layer = 21
	_source = get_parent()
	var root := Control.new()
	root.name = "VitalsRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	root.offset_left = MARGIN
	root.offset_top = -HEIGHT - MARGIN
	root.offset_right = WIDTH + MARGIN
	root.offset_bottom = -MARGIN
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_health_label = _label(root, "HealthValue", 0)
	_health = _bar(root, "Health", 25, 30, Color("9d2926"))
	_stamina_label = _label(root, "StaminaValue", 59)
	_stamina = _bar(root, "Stamina", 84, 20, Color("b39843"))
	set_vitals(0, 0, 0, 0)
	_process(0.0)


func _process(_delta: float) -> void:
	if not is_instance_valid(_source) or not ("health" in _source and "stamina" in _source):
		return
	# Poll the live owner so regeneration, restore and direct vitals sync all agree.
	set_vitals(float(_source.health), float(_source.max_health),
		float(_source.stamina), float(_source.max_stamina))


func set_vitals(health: float, max_health: float, stamina: float, max_stamina: float) -> void:
	var values := Vector4(health, max_health, stamina, max_stamina)
	if values == _last_values or _health == null:
		return
	_last_values = values
	_update_bar(_health, _health_label, "HEALTH", health, max_health)
	_update_bar(_stamina, _stamina_label, "STAMINA", stamina, max_stamina)


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
	label.position = Vector2(10, y)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("eee0c5"))
	label.add_theme_color_override("font_outline_color", Color("161412"))
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
