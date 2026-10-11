extends Node

## Centralised custom-cursor management for gameplay hover and focus states.
## Layered requests let world-item hover override interactable proximity focus.

const GRAB_PATH := "res://assets/UI/cursors/cursor_grab.png"
const TALK_PATH := "res://assets/UI/cursors/cursor_talk.png"

const LAYER_INTERACTABLE := 1
const LAYER_WORLD_ITEM := 2

var _grab_tex: Texture2D
var _talk_tex: Texture2D
var _layers: Dictionary = {}
var _applied: StringName = &""
var _hotspot_grab := Vector2(10, 2)
var _hotspot_talk := Vector2(8, 2)


func _ready() -> void:
	_grab_tex = load(GRAB_PATH) as Texture2D
	_talk_tex = load(TALK_PATH) as Texture2D


func set_layer_cursor(layer: int, kind: StringName) -> void:
	if kind == &"":
		_layers.erase(layer)
	else:
		_layers[layer] = kind
	_refresh()


func clear_layer(layer: int) -> void:
	_layers.erase(layer)
	_refresh()


func get_active_kind() -> StringName:
	return _applied


func _refresh() -> void:
	var best_layer := -1
	var kind := &""
	for layer_key in _layers.keys():
		var layer := int(layer_key)
		if layer > best_layer:
			best_layer = layer
			kind = _layers[layer]
	if kind == _applied:
		return
	_applied = kind
	match kind:
		&"grab":
			Input.set_custom_mouse_cursor(_grab_tex, Input.CURSOR_ARROW, _hotspot_grab)
		&"talk":
			Input.set_custom_mouse_cursor(_talk_tex, Input.CURSOR_ARROW, _hotspot_talk)
		_:
			Input.set_custom_mouse_cursor(null)
