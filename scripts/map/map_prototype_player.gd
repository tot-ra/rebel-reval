class_name MapPrototypePlayer
extends CharacterBody2D

## Simple four-direction greybox walker for map prototype inspection.

const MOVE_SPEED := 220.0

var _facing := Vector2.DOWN
var _body_rect: ColorRect
var _head_rect: ColorRect
var _shadow_rect: ColorRect
var _label: Label


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1

	var shape := RectangleShape2D.new()
	shape.size = Vector2(28.0, 20.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, 8.0)
	add_child(collision)

	_shadow_rect = _make_rect("Shadow", Vector2(-16.0, 14.0), Vector2(32.0, 10.0), Color(0.0, 0.0, 0.0, 0.25), -1)
	_body_rect = _make_rect("Body", Vector2(-14.0, -18.0), Vector2(28.0, 32.0), Color(0.24, 0.56, 0.90, 1.0), 1)
	_head_rect = _make_rect("Head", Vector2(-10.0, -30.0), Vector2(20.0, 16.0), Color(0.34, 0.66, 0.96, 1.0), 2)

	_label = Label.new()
	_label.name = "FacingLabel"
	_label.text = "S"
	_label.position = Vector2(-6.0, -44.0)
	_label.add_theme_font_size_override("font_size", 12)
	add_child(_label)


func _physics_process(_delta: float) -> void:
	var input := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
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


func _update_facing_label() -> void:
	if _facing == Vector2.UP:
		_label.text = "N"
	elif _facing == Vector2.DOWN:
		_label.text = "S"
	elif _facing == Vector2.LEFT:
		_label.text = "W"
	else:
		_label.text = "E"


func _make_rect(node_name: String, position: Vector2, size: Vector2, color: Color, layer: int) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = node_name
	rect.position = position
	rect.size = size
	rect.color = color
	rect.z_index = layer
	add_child(rect)
	return rect
