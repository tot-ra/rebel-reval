class_name MapPrototypePlayer
extends CharacterBody2D

## Four-direction comparison character with a target-independent footprint and pivot.

const MOVE_SPEED := 220.0

var visual_target: StringName = MapVisualStyle.TARGET_CLEAN_PAINTED
var time_of_day: StringName = MapVisualStyle.TIME_DAY
var _facing := Vector2.DOWN
var _visuals: Node2D
var _label: Label


func configure_style(target: StringName, day_phase: StringName) -> void:
	visual_target = target
	time_of_day = day_phase
	if is_node_ready():
		_rebuild_visuals()


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	set_meta("pivot", MapVisualStyle.CHARACTER_PIVOT_PX)
	set_meta("character_height", MapVisualStyle.CHARACTER_HEIGHT_PX)

	var shape := RectangleShape2D.new()
	shape.size = MapVisualStyle.CHARACTER_FOOTPRINT_PX
	var collision := CollisionShape2D.new()
	collision.name = "Collision"
	collision.shape = shape
	collision.position = Vector2(0.0, 8.0)
	add_child(collision)
	_rebuild_visuals()


func _physics_process(_delta: float) -> void:
	var input := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if input != Vector2.ZERO:
		_facing = _resolve_cardinal(input)
		velocity = _facing * MOVE_SPEED
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	_update_facing_label()


func _resolve_cardinal(input: Vector2) -> Vector2:
	if absf(input.x) > absf(input.y):
		return Vector2(signf(input.x), 0.0)
	return Vector2(0.0, signf(input.y))


func _rebuild_visuals() -> void:
	if _visuals != null:
		_visuals.queue_free()
	_visuals = Node2D.new()
	_visuals.name = "Visuals"
	add_child(_visuals)

	var ink := MapVisualStyle.role_color(&"ink", visual_target, time_of_day)
	var shadow := Polygon2D.new()
	shadow.name = "Shadow"
	shadow.polygon = PackedVector2Array([Vector2(-17, 13), Vector2(17, 13), Vector2(13, 22), Vector2(-13, 22)])
	shadow.color = Color(ink, MapVisualStyle.shadow_alpha(visual_target, time_of_day))
	_visuals.add_child(shadow)

	_add_rect("Boots", Vector2(-11, 8), Vector2(22, 10), MapVisualStyle.role_color(&"timber", visual_target, time_of_day), 1)
	_add_rect("Body", Vector2(-14, -22), Vector2(28, 34), MapVisualStyle.role_color(&"character_cloth", visual_target, time_of_day), 2)
	_add_rect("Apron", Vector2(-9, -12), Vector2(18, 26), MapVisualStyle.role_color(&"character_apron", visual_target, time_of_day), 3)
	_add_rect("Head", Vector2(-10, -38), Vector2(20, 18), MapVisualStyle.role_color(&"character_skin", visual_target, time_of_day), 4)
	_add_rect("Hair", Vector2(-11, -41), Vector2(22, 7), MapVisualStyle.role_color(&"timber", visual_target, time_of_day), 5)

	_label = Label.new()
	_label.name = "FacingLabel"
	_label.text = "S"
	_label.position = Vector2(-5.0, -57.0)
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", ink)
	_visuals.add_child(_label)


func _add_rect(node_name: String, position: Vector2, size: Vector2, color: Color, layer: int) -> void:
	var polygon := Polygon2D.new()
	polygon.name = node_name
	polygon.polygon = PackedVector2Array([position, position + Vector2(size.x, 0), position + size, position + Vector2(0, size.y)])
	polygon.color = color
	polygon.z_index = layer
	_visuals.add_child(polygon)
	var outline := Line2D.new()
	outline.name = "%sOutline" % node_name
	outline.points = polygon.polygon
	outline.closed = true
	outline.width = MapVisualStyle.outline_width(visual_target)
	outline.default_color = MapVisualStyle.role_color(&"ink", visual_target, time_of_day)
	outline.z_index = layer + 1
	_visuals.add_child(outline)


func _update_facing_label() -> void:
	if _label == null:
		return
	if _facing == Vector2.UP:
		_label.text = "N"
	elif _facing == Vector2.DOWN:
		_label.text = "S"
	elif _facing == Vector2.LEFT:
		_label.text = "W"
	else:
		_label.text = "E"
